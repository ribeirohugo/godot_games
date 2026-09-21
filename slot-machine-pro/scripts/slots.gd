extends RefCounted
## Slot rules shared by the game: reel strips, pay tables and how a screen of symbols pays.

const Machines := preload("res://scripts/machines.gd")

const ROWS := 3


## A ready-to-play copy of a machine: pays scaled, lines picked and reel strips built.
static func build(index: int) -> Dictionary:
	var source: Dictionary = Machines.LIST[index]
	var machine := source.duplicate(true)
	var pays := {}
	var weights := {}
	for entry in source.symbols:
		var scaled := []
		for value in entry[2]:
			scaled.append(maxi(1, roundi(value * source.scale)))
		pays[entry[0]] = scaled
		weights[entry[0]] = entry[1]
	machine["pays"] = pays
	machine["weights"] = weights
	machine["paylines"] = (Machines.LINES_5 if source.reels == 5 else Machines.LINES_3).slice(0, source.lines)
	var strips := []
	for reel in source.reels:
		strips.append(_strip(weights, hash(source.id) + reel * 7919))
	machine["strips"] = strips
	return machine


## One reel: every symbol `weight` times, shuffled, with scatters kept apart so that at most one
## shows on a reel at a time.
static func _strip(weights: Dictionary, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var others := []
	var scatters := 0
	for id in weights:
		if id == "scatter":
			scatters = weights[id]
		else:
			for i in weights[id]:
				others.append(id)
	for i in range(others.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = others[i]
		others[i] = others[j]
		others[j] = tmp
	# Spread the scatters evenly.
	var strip := others.duplicate()
	for s in scatters:
		var at := int(float(s) * strip.size() / scatters + rng.randi() % 3)
		strip.insert(at + s, "scatter")
	# Avoid three equal symbols in a row, which looks rigged.
	for i in strip.size():
		var a = strip[i]
		if a == strip[(i + 1) % strip.size()] and a == strip[(i + 2) % strip.size()]:
			var k := (i + 5) % strip.size()
			if strip[k] != "scatter":
				var tmp = strip[(i + 2) % strip.size()]
				strip[(i + 2) % strip.size()] = strip[k]
				strip[k] = tmp
	return strip


## The symbols showing for these reel stops: grid[reel][row].
static func grid_for(machine: Dictionary, stops: Array) -> Array:
	var grid := []
	for reel in machine.reels:
		var strip: Array = machine.strips[reel]
		var column := []
		for row in ROWS:
			column.append(strip[(stops[reel] + row) % strip.size()])
		grid.append(column)
	return grid


## Every win on the screen. Line pays are in line bets, scatter pays in total bets.
## Returns {"lines": [{"line", "symbol", "count", "units", "cells"}], "scatters": [cells], "scatter_units", "jackpot"}.
static func evaluate(machine: Dictionary, grid: Array) -> Dictionary:
	var wins := []
	var jackpot := false
	var paylines: Array = machine.paylines
	for li in paylines.size():
		var rows: Array = paylines[li]
		var symbols := []
		for reel in rows.size():
			symbols.append(grid[reel][rows[reel]])
		var win := line_win(machine, symbols)
		if win.units > 0:
			var cells := []
			for reel in win.count:
				cells.append(Vector2i(reel, rows[reel]))
			wins.append({"line": li, "symbol": win.symbol, "count": win.count, "units": win.units, "cells": cells})
			if win.symbol == "wild" and win.count == machine.reels:
				jackpot = true
	var scatters := []
	for reel in grid.size():
		for row in ROWS:
			if grid[reel][row] == "scatter":
				scatters.append(Vector2i(reel, row))
	var scatter_units := 0
	if scatters.size() >= 3 and not machine.scatter.is_empty():
		scatter_units = machine.scatter[mini(scatters.size(), 5) - 3]
	return {"lines": wins, "scatters": scatters, "scatter_units": scatter_units, "jackpot": jackpot}


## Best win on one line, read from the left: {"symbol", "count", "units"}.
static func line_win(machine: Dictionary, symbols: Array) -> Dictionary:
	var pays: Dictionary = machine.pays
	var wild_run := 0
	while wild_run < symbols.size() and symbols[wild_run] == "wild":
		wild_run += 1
	var target := ""
	for s in symbols:
		if s != "wild":
			target = s
			break
	var best := {"symbol": "", "count": 0, "units": 0}
	if target != "" and target != "scatter":
		var count := 0
		while count < symbols.size() and (symbols[count] == target or symbols[count] == "wild"):
			count += 1
		if count >= 3:
			best = {"symbol": target, "count": count, "units": pays[target][count - 3]}
	if wild_run >= 3 and pays["wild"][wild_run - 3] > best.units:
		best = {"symbol": "wild", "count": wild_run, "units": pays["wild"][wild_run - 3]}
	return best
