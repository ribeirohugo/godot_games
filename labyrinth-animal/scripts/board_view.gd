extends Node2D
## Draws the sea, the 4x4 building area, placed tiles, the start dock and the goal with food.
## Cell (0, 0) of the grid sits at this node's position.

const Art := preload("res://scripts/art.gd")
const Tiles := preload("res://scripts/tiles.gd")

const DROP_TIME := 0.25
const DROP_HEIGHT := 60.0

var main  # the game script; read-only access to its state
var time := 0.0
var drop_started := {}  # slot index -> time the tile was placed
var waves := []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		waves.append(Vector3(rng.randf_range(-520, 520), rng.randf_range(-160, 520), rng.randf_range(0, TAU)))


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func mark_dropped(slot: int) -> void:
	drop_started[slot] = time


func clear_drops() -> void:
	drop_started.clear()


func _draw() -> void:
	_draw_sea()

	var hover: int = main.hover_slot if main.phase == "build" else -1
	for slot in 16:
		if main.board[slot] == 0:
			var outline := Art.slot_outline(Vector2.ZERO, main.slot_cell(slot))
			var fill := Color(1, 1, 1, 0.1 if slot != hover else 0.2)
			draw_colored_polygon(outline.slice(0, 4), fill)
			draw_polyline(outline, Color(1, 1, 1, 0.35), 1.5, true)

	# Cells back to front, so blocks nearer the viewer cover the ones behind.
	for depth in range(-2, 27):
		for x in range(-1, 14):
			var cell := Vector2i(x, depth - x)
			if cell.y < -1 or cell.y > 13:
				continue
			_draw_cell(cell)

	if hover >= 0 and main.board[hover] == 0 and main.current_tile > 0:
		var origin := Art.cell_pos(Vector2(main.slot_cell(hover)))
		var bob := sin(time * 5.0) * 2.0 - 6.0
		Art.draw_tile(self, origin + Vector2(0, bob), main.current_tile, 0.6, Tiles)
		draw_polyline(Art.slot_outline(Vector2(0, bob), main.slot_cell(hover)), Color(1, 0.95, 0.4), 2.5, true)

	var start := Art.cell_pos(Vector2(main.START_CELL))
	Art.draw_flag(self, start + Vector2(-8, -4), Color(0.9, 0.2, 0.25), time)
	var goal := Art.cell_pos(Vector2(main.goal_cell))
	if main.phase != "won":
		Art.draw_goal(self, goal, main.animal_kind, time)
	Art.draw_flag(self, goal + Vector2(10, -2), Color(1.0, 0.8, 0.1), time)


func _draw_cell(cell: Vector2i) -> void:
	var pos := Art.cell_pos(Vector2(cell))
	if cell == main.START_CELL:
		Art.draw_dock(self, pos)
		return

	var slot: int = main.slot_of(cell)
	if cell == main.goal_cell:
		_draw_goal_ring(pos)
	elif slot < 0 or not main.land.has(cell):
		return

	if slot >= 0 and drop_started.has(slot):
		var t := clampf((time - drop_started[slot]) / DROP_TIME, 0.0, 1.0)
		pos.y -= DROP_HEIGHT * (1.0 - t) * (1.0 - t)
	var shore := []
	for d in 4:
		shore.append(not main.land.has(cell + Art.DIRS[d]))
	Art.draw_land(self, pos, shore, Art.hash_cell(cell, main.board[slot] if slot >= 0 else 99))


func _draw_goal_ring(pos: Vector2) -> void:
	var pulse := fmod(time, 1.6) / 1.6
	draw_set_transform(pos + Vector2(0, Art.THICK), 0.0, Vector2(1, 0.5))
	draw_arc(Vector2.ZERO, 30.0 + pulse * 30.0, 0, TAU, 32, Color(1, 1, 0.7, 0.6 * (1.0 - pulse)), 3.0)
	draw_set_transform(Vector2.ZERO)


func _draw_sea() -> void:
	var rect := Rect2(-position - Vector2(400, 300), get_viewport_rect().size + Vector2(800, 600))
	draw_rect(rect, Color(0.12, 0.45, 0.7))

	# Shallows around the building area.
	draw_colored_polygon(PackedVector2Array([
		Art.cell_pos(Vector2(-1.5, -1.5)), Art.cell_pos(Vector2(12.5, -1.5)),
		Art.cell_pos(Vector2(12.5, 12.5)), Art.cell_pos(Vector2(-1.5, 12.5))]),
		Color(0.3, 0.7, 0.85, 0.35))

	for w in waves:
		var p := Vector2(w.x + sin(time * 0.8 + w.z) * 6.0, w.y)
		var alpha := 0.25 + 0.2 * sin(time * 1.5 + w.z)
		draw_arc(p, 7.0, deg_to_rad(20), deg_to_rad(160), 8, Color(1, 1, 1, alpha), 1.5)
