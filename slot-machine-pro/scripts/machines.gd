extends RefCounted
## Every slot machine in the lobby: its reels, symbols, pay table and colors.
## Symbols list [id, weight on each reel, pays]. Pays are in line bets for 3, 4 and 5 of a kind
## (only 3 on three-reel machines) and get multiplied by `scale`, which tunes the machine to
## return about 96% of what is bet. "wild" stands in for every symbol except "scatter".
## Three or more scatters anywhere pay `scatter` times the total bet and start the free spins.

## Paylines as the row (0 top, 2 bottom) the line crosses on each reel.
const LINES_5 := [
	[1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
	[0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0],
	[2, 1, 1, 1, 2], [1, 0, 1, 2, 1], [1, 2, 1, 0, 1], [0, 1, 0, 1, 0], [2, 1, 2, 1, 2],
	[1, 1, 0, 1, 1], [1, 1, 2, 1, 1], [0, 2, 0, 2, 0], [2, 0, 2, 0, 2], [0, 2, 2, 2, 0],
]
const LINES_3 := [[1, 1, 1], [0, 0, 0], [2, 2, 2], [0, 1, 2], [2, 1, 0]]

## Royal letters shared by several machines.
const ROYALS := [["J", 9, [5, 15, 60]], ["Q", 9, [5, 20, 70]], ["K", 8, [8, 25, 90]], ["A", 8, [10, 30, 110]]]

const LIST := [
	{
		"id": "classic", "name": "Classic Sevens", "reels": 3, "lines": 5, "scale": 0.796,
		"colors": {"bg": "3a0612", "bg2": "12020a", "frame": "7d0f22", "trim": "f5c542", "accent": "ff4d5e", "reel": "fff8e8", "reel2": "e9dcc0"},
		"symbols": [["cherry", 8, [10]], ["lemon", 8, [15]], ["plum", 7, [20]], ["bell", 6, [30]], ["bar1", 5, [40]],
				["bar2", 4, [60]], ["bar3", 3, [100]], ["seven_red", 2, [250]], ["wild", 2, [500]]],
		"scatter": [],
	},
	{
		"id": "fruit", "name": "Fruit Party", "reels": 5, "lines": 20, "scale": 1.465,
		"colors": {"bg": "7a0f5c", "bg2": "2a0530", "frame": "c2185b", "trim": "ffd54f", "accent": "ff9800", "reel": "fffdf5", "reel2": "ffe9c7"},
		"symbols": [["cherry", 10, [5, 15, 50]], ["lemon", 10, [5, 15, 50]], ["orange", 9, [8, 20, 75]], ["plum", 8, [10, 25, 100]],
				["grapes", 6, [15, 40, 150]], ["watermelon", 5, [20, 60, 200]], ["bell", 4, [30, 100, 400]],
				["wild", 2, [50, 250, 1000]], ["scatter", 2, []]],
		"scatter": [2, 10, 50],
	},
	{
		"id": "hot", "name": "Hot Sevens", "reels": 5, "lines": 10, "scale": 0.857,
		"colors": {"bg": "8a2100", "bg2": "1a0400", "frame": "b71c1c", "trim": "ffb300", "accent": "ff6d00", "reel": "fff7e6", "reel2": "ffd9a8"},
		"symbols": [["cherry", 10, [5, 15, 60]], ["lemon", 9, [6, 20, 70]], ["bell", 7, [10, 30, 100]], ["bar1", 6, [15, 40, 150]],
				["bar3", 5, [20, 60, 200]], ["seven_blue", 4, [30, 100, 400]], ["seven_red", 3, [50, 200, 750]],
				["wild", 2, [75, 300, 1500]], ["scatter", 2, []]],
		"scatter": [2, 10, 50],
	},
	{
		"id": "diamond", "name": "Diamond Deluxe", "reels": 5, "lines": 20, "scale": 1.527,
		"colors": {"bg": "1a237e", "bg2": "05061c", "frame": "283593", "trim": "b3e5fc", "accent": "40c4ff", "reel": "1c2150", "reel2": "0b0e2a"},
		"symbols": ROYALS + [["gem_green", 6, [15, 40, 150]], ["gem_blue", 5, [20, 60, 200]], ["gem_red", 4, [25, 80, 300]],
				["crown", 3, [40, 120, 500]], ["wild", 2, [50, 250, 1000]], ["scatter", 2, []]],
		"scatter": [2, 10, 50],
	},
	{
		"id": "clover", "name": "Lucky Clover", "reels": 5, "lines": 20, "scale": 1.527,
		"colors": {"bg": "1b5e20", "bg2": "04200a", "frame": "2e7d32", "trim": "ffd54f", "accent": "76ff03", "reel": "f4fbe9", "reel2": "d4ecc0"},
		"symbols": ROYALS + [["horseshoe", 6, [15, 40, 150]], ["coin", 5, [20, 60, 200]], ["clover", 4, [25, 80, 300]],
				["pot", 3, [40, 120, 500]], ["wild", 2, [50, 250, 1000]], ["scatter", 2, []]],
		"scatter": [2, 10, 50],
	},
	{
		"id": "pharaoh", "name": "Pharaoh's Gold", "reels": 5, "lines": 20, "scale": 1.527,
		"colors": {"bg": "6d4c1d", "bg2": "1c1206", "frame": "0d3b66", "trim": "f4c542", "accent": "ffca28", "reel": "13294b", "reel2": "08142a"},
		"symbols": ROYALS + [["ankh", 6, [15, 40, 150]], ["scarab", 5, [20, 60, 200]], ["eye", 4, [25, 80, 300]],
				["pyramid", 3, [40, 120, 500]], ["wild", 2, [50, 250, 1000]], ["scatter", 2, []]],
		"scatter": [2, 10, 50],
	},
	{
		"id": "ocean", "name": "Ocean Treasure", "reels": 5, "lines": 20, "scale": 1.527,
		"colors": {"bg": "006064", "bg2": "001a33", "frame": "00838f", "trim": "ffe082", "accent": "18ffff", "reel": "e6fbff", "reel2": "b8ecf5"},
		"symbols": ROYALS + [["shell", 6, [15, 40, 150]], ["fish", 5, [20, 60, 200]], ["anchor", 4, [25, 80, 300]],
				["chest", 3, [40, 120, 500]], ["wild", 2, [50, 250, 1000]], ["scatter", 2, []]],
		"scatter": [2, 10, 50],
	},
	{
		"id": "space", "name": "Space Spins", "reels": 5, "lines": 20, "scale": 1.527,
		"colors": {"bg": "311b92", "bg2": "05020f", "frame": "4527a0", "trim": "84ffff", "accent": "e040fb", "reel": "1a1238", "reel2": "070414"},
		"symbols": ROYALS + [["moon", 6, [15, 40, 150]], ["rocket", 5, [20, 60, 200]], ["planet", 4, [25, 80, 300]],
				["ufo", 3, [40, 120, 500]], ["wild", 2, [50, 250, 1000]], ["scatter", 2, []]],
		"scatter": [2, 10, 50],
	},
	{
		"id": "candy", "name": "Sweet Candy", "reels": 5, "lines": 20, "scale": 0.638,
		"colors": {"bg": "ad1457", "bg2": "3a0a3f", "frame": "ec407a", "trim": "fff59d", "accent": "ff80ab", "reel": "fff5fa", "reel2": "ffd6ea"},
		"symbols": [["heart", 12, [5, 15, 50]], ["candy", 11, [6, 20, 60]], ["lollipop", 9, [10, 30, 100]], ["donut", 7, [15, 50, 150]],
				["cupcake", 5, [25, 80, 300]], ["wild", 2, [50, 250, 1000]], ["scatter", 2, []]],
		"scatter": [2, 10, 50],
	},
	{
		"id": "royal", "name": "Royal Riches", "reels": 5, "lines": 20, "scale": 1.527,
		"colors": {"bg": "4a148c", "bg2": "12031f", "frame": "6a1b9a", "trim": "ffd740", "accent": "ffd740", "reel": "2a0d33", "reel2": "12040f"},
		"symbols": ROYALS + [["coin", 6, [15, 40, 150]], ["gem_purple", 5, [20, 60, 200]], ["chest", 4, [25, 80, 300]],
				["crown", 3, [40, 120, 500]], ["wild", 2, [50, 250, 1000]], ["scatter", 2, []]],
		"scatter": [2, 10, 50],
	},
]

const FREE_SPINS := 10
const FREE_SPIN_MULTIPLIER := 2
