extends Node2D
## Temple Defender: guard the Temple of Lightning and Fire from waves of alien creatures.
## Build towers beside the path, traps on it, and sacred towers right next to the temple.
## Mouse: click or drag a tower from the panel onto the map. Right click / Esc cancels.
## Keys: 1-6 pick a tower, Space sends the next wave, F toggles speed, U upgrades, S sells, P pauses.

const SfxScript := preload("res://scripts/sfx.gd")

const SCREEN := Vector2(1100, 700)
const CELL := 40.0
const COLS := 20
const ROWS := 15
const BOARD_POS := Vector2(16, 76)
const BOARD_SIZE := Vector2(COLS * CELL, ROWS * CELL)
const PANEL_X := 840.0
const SAVE_PATH := "user://temple_defender.cfg"

const TOTAL_WAVES := 30
const START_LIVES := 50
const WAVE_BREAK := 20.0  # seconds between the end of one wave's spawns and the next wave
const SELL_RATE := 0.7
const SACRED_RANGE := 2  # temple-only towers must be this many cells from the temple, at most

enum State { MENU, PLAY, PAUSED, OVER }
enum Tile { GRASS, PATH, TEMPLE }

# Colors.
const TEXT := Color("f4ead5")
const MUTED := Color("b3a58a")
const GOLD := Color("f2c14e")
const RED := Color("e05a47")
const GREEN := Color("7bc96f")
const BLUE := Color("6fc3ff")
const INK := Color(0.07, 0.05, 0.03)
const PANEL := Color("2a241c")
const PANEL_LIGHT := Color("3b3326")
const PANEL_EDGE := Color("5a4b35")
const GRASS_A := Color("4f7f3a")
const GRASS_B := Color("4a7836")
const SAND := Color("c9a86b")
const SAND_DARK := Color("9c7c47")
const STONE := Color("a39a88")
const STONE_DARK := Color("6e665a")
const WOOD := Color("8a5a2b")
const WOOD_DARK := Color("5c3a1a")

# --- Game data -------------------------------------------------------------------
# cost: [build, first upgrade, second upgrade]. Other stats: one value per level.
const TOWER_ORDER := ["arrow", "catapult", "spikes", "lightning", "fire", "bell"]
const TOWERS := {
	"arrow": {
		"name": "Arrow Tower", "cost": [40, 45, 80], "range": [115.0, 130.0, 145.0],
		"cooldown": [0.62, 0.5, 0.4], "damage": [10.0, 17.0, 28.0], "air": true, "ground": true,
		"desc": "Quick single arrows. Hits flying enemies.",
	},
	"catapult": {
		"name": "Catapult", "cost": [90, 85, 140], "range": [150.0, 165.0, 180.0],
		"cooldown": [2.3, 2.05, 1.8], "damage": [34.0, 58.0, 95.0], "splash": [46.0, 52.0, 60.0],
		"air": false, "ground": true,
		"desc": "Slow boulders that crush groups. Ground only.",
	},
	"spikes": {
		"name": "Spike Trap", "cost": [60, 55, 95], "range": [22.0, 22.0, 22.0],
		"cooldown": [1.0, 0.85, 0.7], "damage": [16.0, 27.0, 42.0], "air": false, "ground": true,
		"trap": true,
		"desc": "Goes on the path. Stabs everything walking over it, even burrowed enemies.",
	},
	"lightning": {
		"name": "Lightning Shrine", "cost": [150, 120, 190], "range": [155.0, 170.0, 185.0],
		"cooldown": [1.6, 1.4, 1.2], "damage": [42.0, 68.0, 105.0], "chains": [3, 4, 6],
		"air": true, "ground": true, "sacred": true,
		"desc": "Temple only. Lightning jumps between enemies and ignores armor.",
	},
	"fire": {
		"name": "Fire Altar", "cost": [140, 110, 175], "range": [100.0, 110.0, 120.0],
		"cooldown": [0.95, 0.85, 0.75], "damage": [16.0, 26.0, 40.0], "burn": [6.0, 10.0, 15.0],
		"air": true, "ground": true, "sacred": true,
		"desc": "Temple only. Flame bursts hit all nearby and burn, stopping regeneration.",
	},
	"bell": {
		"name": "Guardian Bell", "cost": [110, 90, 140], "range": [135.0, 155.0, 175.0],
		"cooldown": [0.45, 0.45, 0.45], "slow": [0.35, 0.45, 0.55], "armor_break": [3.0, 5.0, 8.0],
		"air": true, "ground": true, "sacred": true,
		"desc": "Temple only. Slows enemies, cracks armor and forces burrowers up.",
	},
}

const ENEMIES := {
	"glorp": {"name": "Glorp", "hp": 42.0, "speed": 44.0, "armor": 0.0, "lives": 1, "gold": 6, "size": 13.0},
	"skitter": {"name": "Skitter", "hp": 24.0, "speed": 86.0, "armor": 0.0, "lives": 1, "gold": 5, "size": 10.0},
	"shellback": {"name": "Shellback", "hp": 95.0, "speed": 31.0, "armor": 5.0, "lives": 2, "gold": 12, "size": 15.0},
	"burrower": {"name": "Burrower", "hp": 62.0, "speed": 48.0, "armor": 1.0, "lives": 2, "gold": 10, "size": 13.0, "burrows": true},
	"eye": {"name": "Floating Eye", "hp": 52.0, "speed": 54.0, "armor": 0.0, "lives": 2, "gold": 9, "size": 12.0, "flying": true},
	"blobule": {"name": "Blobule", "hp": 115.0, "speed": 37.0, "armor": 0.0, "lives": 2, "gold": 12, "size": 15.0, "regen": 0.05},
	"brute": {"name": "Brute", "hp": 700.0, "speed": 25.0, "armor": 4.0, "lives": 15, "gold": 90, "size": 24.0, "regen": 0.008},
}
const UNLOCKS := {"glorp": 1, "skitter": 2, "shellback": 4, "burrower": 6, "eye": 8, "blobule": 11}
const GROUP_SIZE := {"glorp": 10, "skitter": 14, "shellback": 5, "burrower": 8, "eye": 8, "blobule": 6}
const SPACING := {"glorp": 0.9, "skitter": 0.45, "shellback": 1.25, "burrower": 1.0, "eye": 0.9, "blobule": 1.2, "brute": 3.0}
const HP_CURVE := 0.012  # how steeply enemy health climbs in later waves
const GOLD_GROWTH := 0.02  # extra kill gold per wave
const BURROW_UP_TIME := 2.2
const BURROW_DOWN_TIME := 2.8

const DIFFICULTIES := [
	{"name": "Easy", "hp": 0.75, "gold": 260},
	{"name": "Normal", "hp": 1.0, "gold": 200},
	{"name": "Hard", "hp": 1.35, "gold": 160},
]

# Paths are cell waypoints (the first may be just off the board); each ends next to the temple.
# toughness scales enemy health, so long paths (more time under fire) stay as hard as short ones.
const MAPS := [
	{
		"name": "Serpent Valley", "temple": Vector2i(17, 10), "seed": 11, "toughness": 1.0,
		"paths": [[Vector2i(-1, 3), Vector2i(6, 3), Vector2i(6, 11), Vector2i(12, 11), Vector2i(12, 3), Vector2i(17, 3), Vector2i(17, 9)]],
	},
	{
		"name": "Canyon Run", "temple": Vector2i(3, 11), "seed": 23, "toughness": 1.1,
		"paths": [[Vector2i(9, -1), Vector2i(9, 2), Vector2i(2, 2), Vector2i(2, 7), Vector2i(16, 7), Vector2i(16, 12), Vector2i(5, 12)]],
	},
	{
		"name": "The Spiral", "temple": Vector2i(8, 6), "seed": 37, "toughness": 1.5,
		"paths": [[Vector2i(-1, 1), Vector2i(18, 1), Vector2i(18, 13), Vector2i(1, 13), Vector2i(1, 4), Vector2i(15, 4), Vector2i(15, 10), Vector2i(5, 10), Vector2i(5, 7), Vector2i(7, 7)]],
	},
	{
		"name": "Two Gates", "temple": Vector2i(9, 6), "seed": 41, "toughness": 0.8,
		"paths": [
			[Vector2i(-1, 2), Vector2i(4, 2), Vector2i(4, 7), Vector2i(8, 7)],
			[Vector2i(20, 12), Vector2i(15, 12), Vector2i(15, 7), Vector2i(11, 7)],
		],
	},
]

# --- State -------------------------------------------------------------------------
var state := State.MENU
var map_index := 0
var difficulty := 1
var best := {}  # "map_difficulty" -> best wave survived (TOTAL_WAVES + 1 when won)

var grid: Array[int] = []
var sacred := {}  # Vector2i -> true
var obstacles := {}  # Vector2i -> {"kind", "anim"}
var towers := {}  # Vector2i -> tower dictionary
var path_points: Array[PackedVector2Array] = []
var path_cum: Array[PackedFloat32Array] = []
var decor := []

var gold := 0
var lives := START_LIVES
var wave := 0
var spawn_queue := []
var wave_clock := 0.0
var next_timer := -1.0  # counting down to the next wave, or -1
var wave_cleared := true
var won := false
var speed := 1
var clock := 0.0

var enemies := []
var projectiles := []
var effects := []
var particles := []
var popups := []
var shake := 0.0
var temple_flash := 0.0

var build_kind := ""  # tower picked in the panel, waiting to be placed
var dragging := false
var selected_cell := Vector2i(-1, -1)  # a tower or obstacle picked on the board
var hover_cell := Vector2i(-1, -1)
var hover_card := -1
var hover_button := ""
var mouse := Vector2.ZERO
var message := ""
var message_time := 0.0

var board_layer: Node2D
var game_layer: Node2D
var hud_layer: Node2D
var font: Font
var sfx


func _ready() -> void:
	font = ThemeDB.fallback_font
	sfx = SfxScript.new()
	add_child(sfx)
	board_layer = _layer(_draw_board)
	board_layer.position = BOARD_POS
	game_layer = _layer(_draw_game)
	game_layer.position = BOARD_POS
	hud_layer = _layer(_draw_hud)
	_load_best()
	_load_map()


func _layer(painter: Callable) -> Node2D:
	var layer := Node2D.new()
	add_child(layer)
	layer.draw.connect(painter.bind(layer))
	return layer


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAY:
		state = State.PAUSED


# --- Map setup ---------------------------------------------------------------------

func _load_map() -> void:
	var map: Dictionary = MAPS[map_index]
	grid.clear()
	grid.resize(COLS * ROWS)
	grid.fill(Tile.GRASS)
	sacred.clear()
	obstacles.clear()
	towers.clear()
	path_points.clear()
	path_cum.clear()
	decor.clear()

	var temple: Vector2i = map.temple
	for dy in 2:
		for dx in 2:
			_set_tile(temple + Vector2i(dx, dy), Tile.TEMPLE)
	var temple_center := Vector2(temple) * CELL + Vector2(CELL, CELL)

	for waypoints in map.paths:
		var points := PackedVector2Array()
		var cells: Array = waypoints
		for i in cells.size():
			var cell: Vector2i = cells[i]
			if i > 0:
				var from: Vector2i = cells[i - 1]
				var step := Vector2i(signi(cell.x - from.x), signi(cell.y - from.y))
				var at := from
				while at != cell:
					_set_tile(at, Tile.PATH)
					at += step
			_set_tile(cell, Tile.PATH)
			points.append((Vector2(cell) + Vector2(0.5, 0.5)) * CELL)
		points.append(temple_center)
		var cum := PackedFloat32Array([0.0])
		for i in range(1, points.size()):
			cum.append(cum[i - 1] + points[i - 1].distance_to(points[i]))
		path_points.append(points)
		path_cum.append(cum)

	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if _tile(cell) != Tile.GRASS:
				continue
			var near_x := maxi(0, maxi(temple.x - x, x - (temple.x + 1)))
			var near_y := maxi(0, maxi(temple.y - y, y - (temple.y + 1)))
			if maxi(near_x, near_y) <= SACRED_RANGE:
				sacred[cell] = true

	var rng := RandomNumberGenerator.new()
	rng.seed = map.seed
	var tries := 0
	while obstacles.size() < 24 and tries < 500:
		tries += 1
		var cell := Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(0, ROWS - 1))
		if _tile(cell) != Tile.GRASS or obstacles.has(cell) or sacred.has(cell):
			continue
		obstacles[cell] = {"kind": "tree" if rng.randf() < 0.62 else "rock", "anim": rng.randf() * TAU}
	for i in 140:
		decor.append([Vector2(rng.randf() * BOARD_SIZE.x, rng.randf() * BOARD_SIZE.y), rng.randi_range(0, 2), rng.randf()])


func _set_tile(cell: Vector2i, tile: int) -> void:
	if _inside(cell):
		grid[cell.y * COLS + cell.x] = tile


func _tile(cell: Vector2i) -> int:
	return grid[cell.y * COLS + cell.x] if _inside(cell) else -1


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func _start_game() -> void:
	_load_map()
	gold = DIFFICULTIES[difficulty].gold
	lives = START_LIVES
	wave = 0
	spawn_queue.clear()
	enemies.clear()
	projectiles.clear()
	effects.clear()
	particles.clear()
	popups.clear()
	next_timer = -1.0
	wave_cleared = true
	won = false
	speed = 1
	build_kind = ""
	selected_cell = Vector2i(-1, -1)
	state = State.PLAY
	sfx.play("select")


# --- Waves ---------------------------------------------------------------------------

func _wave_spawns(n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 7919 + map_index * 131
	var pool: Array[String] = []
	var newest := ""
	for kind: String in UNLOCKS:
		if n >= UNLOCKS[kind]:
			pool.append(kind)
			if UNLOCKS[kind] == n:
				newest = kind
	var growth := 1.0 + n * 0.05
	var main_kind: String = newest if newest != "" else pool[rng.randi() % pool.size()]
	var groups := [[main_kind, ceili(GROUP_SIZE[main_kind] * growth)]]
	if n >= 3 and pool.size() > 1:
		var second: String = pool[rng.randi() % pool.size()]
		if second != main_kind:
			groups.append([second, ceili(GROUP_SIZE[second] * 0.5 * growth)])
	# Brutes lead every fifth wave from wave 10 on, more of them every tenth.
	if n >= 10 and n % 5 == 0:
		groups.append(["brute", n / 10 if n % 10 == 0 else 1])

	var spawns := []
	var time := 0.0
	var path_i := 0
	for group in groups:
		var kind: String = group[0]
		for i in int(group[1]):
			spawns.append({"kind": kind, "time": time, "path": path_i % path_points.size()})
			path_i += 1
			time += SPACING[kind]
		time += 2.0
	return spawns


func _send_wave() -> void:
	if wave >= TOTAL_WAVES or not spawn_queue.is_empty():
		return
	if next_timer > 0.0:
		var bonus := int(next_timer)
		if bonus > 0:
			gold += bonus
			_popup(Vector2(PANEL_X - 130, 40), "+%d early" % bonus, GOLD, true)
	wave += 1
	spawn_queue = _wave_spawns(wave)
	wave_clock = 0.0
	next_timer = -1.0
	wave_cleared = false
	_show_message("Wave %d" % wave)
	sfx.play("wave")


func _spawn_enemy(kind: String, path: int) -> void:
	var data: Dictionary = ENEMIES[kind]
	# Map toughness phases in over the first 10 waves, once there are towers for it to matter.
	var toughness: float = lerpf(1.0, MAPS[map_index].toughness, minf(1.0, wave / 10.0))
	var hp_mult: float = (1.0 + 0.12 * (wave - 1) + HP_CURVE * pow(wave - 1, 2.0)) * DIFFICULTIES[difficulty].hp * toughness
	var max_hp: float = data.hp * hp_mult
	enemies.append({
		"kind": kind, "hp": max_hp, "max_hp": max_hp, "speed": data.speed, "armor": data.armor,
		"lives": data.lives, "gold": int(round(data.gold * (1.0 + wave * GOLD_GROWTH))), "size": data.size,
		"flying": data.get("flying", false), "regen": data.get("regen", 0.0), "burrows": data.get("burrows", false),
		"path": path, "dist": 0.0, "pos": path_points[path][0], "dir": Vector2.RIGHT,
		"slow": 0.0, "slow_time": 0.0, "burn": 0.0, "burn_time": 0.0, "break": 0.0, "break_time": 0.0,
		"under": false, "burrow_timer": 1.6, "reveal_time": 0.0, "hit": 0.0, "anim": randf() * TAU, "dead": false,
	})


# --- Update ------------------------------------------------------------------------

func _process(delta: float) -> void:
	clock += delta
	message_time = maxf(0.0, message_time - delta)
	if state == State.PLAY:
		for i in speed:
			_step(minf(delta, 0.05))
	_update_fx(delta)
	board_layer.queue_redraw()
	game_layer.queue_redraw()
	hud_layer.queue_redraw()
	var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 6.0
	board_layer.position = BOARD_POS + offset
	game_layer.position = BOARD_POS + offset


func _step(dt: float) -> void:
	# Spawning and the countdown between waves.
	if not spawn_queue.is_empty():
		wave_clock += dt
		while not spawn_queue.is_empty() and spawn_queue[0].time <= wave_clock:
			var spawn: Dictionary = spawn_queue.pop_front()
			_spawn_enemy(spawn.kind, spawn.path)
		if spawn_queue.is_empty() and wave < TOTAL_WAVES:
			next_timer = WAVE_BREAK
	elif next_timer > 0.0:
		next_timer -= dt
		if next_timer <= 0.0:
			next_timer = -1.0
			_send_wave()

	_update_enemies(dt)
	if state != State.PLAY:
		return  # the temple fell this step; don't let the wave-cleared check below undo it
	_update_towers(dt)
	_update_projectiles(dt)
	enemies = enemies.filter(func(e: Dictionary) -> bool: return not e.dead)

	if spawn_queue.is_empty() and enemies.is_empty() and not wave_cleared and wave > 0:
		wave_cleared = true
		var bonus := 10 + wave * 2
		gold += bonus
		_popup(Vector2(PANEL_X - 130, 40), "Wave cleared +%d" % bonus, GOLD, true)
		sfx.play("coin")
		if wave >= TOTAL_WAVES:
			_end_game(true)


func _update_enemies(dt: float) -> void:
	for e: Dictionary in enemies:
		e.anim += dt
		e.hit = maxf(0.0, e.hit - dt)
		e.slow_time -= dt
		if e.slow_time <= 0.0:
			e.slow = 0.0
		e.break_time -= dt
		if e.break_time <= 0.0:
			e.break = 0.0
		e.reveal_time -= dt

		if e.burn_time > 0.0:
			e.burn_time -= dt
			_damage(e, e.burn * dt, true, false)
			if e.dead:
				continue
		elif e.regen > 0.0 and e.hp < e.max_hp:
			e.hp = minf(e.max_hp, e.hp + e.max_hp * e.regen * dt)

		if e.burrows:
			e.burrow_timer -= dt
			if e.burrow_timer <= 0.0:
				if e.under:
					e.under = false
					e.burrow_timer = BURROW_UP_TIME
					_dust(e.pos, 8)
				elif e.reveal_time <= 0.0:
					e.under = true
					e.burrow_timer = BURROW_DOWN_TIME
					_dust(e.pos, 8)
				else:
					e.burrow_timer = 0.3

		var move: float = e.speed * (1.0 - e.slow) * (1.35 if e.under else 1.0) * dt
		e.dist += move
		var path: int = e.path
		var total: float = path_cum[path][path_cum[path].size() - 1]
		if e.dist >= total:
			e.dead = true
			lives = maxi(0, lives - int(e.lives))
			temple_flash = 1.0
			shake = maxf(shake, 0.6)
			_popup(_temple_center(), "-%d" % e.lives, RED)
			sfx.play("leak")
			if lives <= 0 and state == State.PLAY:
				_end_game(false)
			continue
		var new_pos := _path_pos(path, e.dist)
		if new_pos.distance_squared_to(e.pos) > 0.0001:
			e.dir = (new_pos - e.pos).normalized()
		e.pos = new_pos


func _update_towers(dt: float) -> void:
	for cell: Vector2i in towers:
		var t: Dictionary = towers[cell]
		t.anim = maxf(0.0, t.anim - dt)
		t.cooldown -= dt
		if t.cooldown > 0.0:
			continue
		var data: Dictionary = TOWERS[t.kind]
		var level: int = t.level
		var center := _cell_center(cell)
		var reach: float = data.range[level]
		match t.kind:
			"arrow":
				var target := _first_target(center, reach, data)
				if target.is_empty():
					continue
				t.aim = (target.pos - center).angle()
				projectiles.append({"kind": "arrow", "pos": center + Vector2(0, -22), "target": target,
						"last": target.pos, "damage": data.damage[level]})
				t.cooldown = data.cooldown[level]
				sfx.play("arrow")
			"catapult":
				var target := _first_target(center, reach, data)
				if target.is_empty():
					continue
				var flight := 0.8
				var lead: float = target.speed * (1.0 - target.slow) * flight
				var landing := _path_pos(target.path, target.dist + lead)
				t.aim = (landing - center).angle()
				t.anim = 0.5
				projectiles.append({"kind": "boulder", "from": center + Vector2(0, -14), "to": landing, "time": 0.0,
						"flight": flight, "damage": data.damage[level], "splash": data.splash[level]})
				t.cooldown = data.cooldown[level]
				sfx.play("catapult")
			"spikes":
				var hit := false
				for e: Dictionary in enemies:
					if not e.flying and not e.dead and e.pos.distance_to(center) < reach + e.size * 0.5:
						_damage(e, data.damage[level], false, true)
						hit = true
				if hit:
					t.anim = 0.35
					t.cooldown = data.cooldown[level]
					sfx.play("spikes")
			"lightning":
				var target := _first_target(center, reach, data)
				if target.is_empty():
					continue
				var points := PackedVector2Array([center + Vector2(0, -34)])
				var hit_list := [target]
				var damage: float = data.damage[level]
				var current: Dictionary = target
				for i in int(data.chains[level]):
					points.append(current.pos)
					_damage(current, damage, true, false)
					damage *= 0.8
					var next := {}
					var best_d := 95.0
					for e: Dictionary in enemies:
						if e.dead or e.under or hit_list.has(e):
							continue
						var d: float = e.pos.distance_to(current.pos)
						if d < best_d:
							best_d = d
							next = e
					if next.is_empty():
						break
					hit_list.append(next)
					current = next
				effects.append({"kind": "bolt", "points": _jagged(points), "life": 0.25, "max": 0.25})
				t.anim = 0.3
				t.cooldown = data.cooldown[level]
				sfx.play("zap")
			"fire":
				var any := false
				for e: Dictionary in enemies:
					if not e.dead and not e.under and e.pos.distance_to(center) <= reach:
						any = true
						break
				if not any:
					continue
				for e: Dictionary in enemies:
					if not e.dead and not e.under and e.pos.distance_to(center) <= reach:
						_damage(e, data.damage[level], true, false)
						e.burn = maxf(e.burn, data.burn[level])
						e.burn_time = 3.0
				effects.append({"kind": "ring", "pos": center, "radius": reach, "color": Color("ff8a2a"), "life": 0.45, "max": 0.45})
				t.anim = 0.45
				t.cooldown = data.cooldown[level]
				sfx.play("fire")
			"bell":
				var rung := false
				for e: Dictionary in enemies:
					if e.dead or e.pos.distance_to(center) > reach:
						continue
					rung = true
					e.slow = maxf(e.slow, data.slow[level])
					e.slow_time = 0.6
					e.break = maxf(e.break, data.armor_break[level])
					e.break_time = 0.6
					if e.under:
						e.under = false
						e.burrow_timer = BURROW_UP_TIME
						_dust(e.pos, 6)
					e.reveal_time = 0.8
				t.cooldown = data.cooldown[level]
				if rung and t.anim <= 0.0:
					t.anim = 1.6
					effects.append({"kind": "ring", "pos": center, "radius": reach, "color": GOLD, "life": 0.9, "max": 0.9})
					sfx.play("bell")


## The enemy nearest the temple that this tower can hit.
func _first_target(center: Vector2, reach: float, data: Dictionary) -> Dictionary:
	var target := {}
	var best_left := INF
	for e: Dictionary in enemies:
		if e.dead or e.under:
			continue
		if e.flying and not data.air or not e.flying and not data.ground:
			continue
		if e.pos.distance_to(center) > reach:
			continue
		var path: int = e.path
		var left: float = path_cum[path][path_cum[path].size() - 1] - e.dist
		if left < best_left:
			best_left = left
			target = e
	return target


func _update_projectiles(dt: float) -> void:
	for p: Dictionary in projectiles:
		match p.kind:
			"arrow":
				var target: Dictionary = p.target
				if not target.dead:
					p.last = target.pos
				var to: Vector2 = p.last - p.pos
				var step := 560.0 * dt
				if to.length() <= step:
					if not target.dead:
						_damage(target, p.damage, false, false)
					p.done = true
				else:
					p.pos += to.normalized() * step
					p.angle = to.angle()
			"boulder":
				p.time += dt
				if p.time >= p.flight:
					p.done = true
					for e: Dictionary in enemies:
						if e.dead or e.flying or e.under:
							continue
						var d: float = e.pos.distance_to(p.to)
						if d <= p.splash:
							_damage(e, p.damage * (1.0 - 0.5 * d / p.splash), false, false)
					effects.append({"kind": "crater", "pos": p.to, "radius": p.splash, "life": 0.5, "max": 0.5})
					_dust(p.to, 14)
					shake = maxf(shake, 0.15)
					sfx.play("boom")
	projectiles = projectiles.filter(func(p: Dictionary) -> bool: return not p.get("done", false))


func _damage(e: Dictionary, amount: float, pierce: bool, from_trap: bool) -> void:
	if e.dead or (e.under and not from_trap):
		return
	var armor := maxf(0.0, e.armor - e.break)
	var dealt := amount if pierce else maxf(amount - armor, amount * 0.35)
	e.hp -= dealt
	e.hit = 0.12
	if e.hp <= 0.0:
		e.dead = true
		gold += int(e.gold)
		_popup(e.pos + Vector2(0, -20), "+%d" % e.gold, GOLD)
		_burst(e.pos, _enemy_color(e.kind), 12 if e.kind != "brute" else 36)
		if e.kind == "brute":
			shake = maxf(shake, 0.5)
			sfx.play("boom")
		else:
			sfx.play("coin")


func _end_game(victory: bool) -> void:
	won = victory
	state = State.OVER
	build_kind = ""
	selected_cell = Vector2i(-1, -1)
	var key := "%d_%d" % [map_index, difficulty]
	var score := TOTAL_WAVES + 1 if victory else wave - 1
	if score > int(best.get(key, 0)):
		best[key] = score
		_save_best()
	sfx.play("win" if victory else "lose")


func _update_fx(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	temple_flash = maxf(0.0, temple_flash - delta * 2.0)
	for list in [effects, particles, popups]:
		for item: Dictionary in list:
			item.life -= delta
	for p: Dictionary in particles:
		p.pos += p.vel * delta
		p.vel *= 0.9
	for p: Dictionary in popups:
		p.pos.y -= 26.0 * delta
	effects = effects.filter(func(i: Dictionary) -> bool: return i.life > 0.0)
	particles = particles.filter(func(i: Dictionary) -> bool: return i.life > 0.0)
	popups = popups.filter(func(i: Dictionary) -> bool: return i.life > 0.0)


# --- Helpers ---------------------------------------------------------------------------

func _path_pos(path: int, dist: float) -> Vector2:
	var points := path_points[path]
	var cum := path_cum[path]
	if dist <= 0.0:
		return points[0]
	for i in range(1, points.size()):
		if dist <= cum[i]:
			var segment := cum[i] - cum[i - 1]
			return points[i - 1].lerp(points[i], (dist - cum[i - 1]) / maxf(segment, 0.001))
	return points[points.size() - 1]


func _temple_center() -> Vector2:
	var temple: Vector2i = MAPS[map_index].temple
	return Vector2(temple) * CELL + Vector2(CELL, CELL)


func _jagged(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([points[0]])
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var normal := (b - a).orthogonal().normalized()
		for k in range(1, 5):
			out.append(a.lerp(b, k / 5.0) + normal * randf_range(-9.0, 9.0))
		out.append(b)
	return out


func _dust(pos: Vector2, count: int) -> void:
	for i in count:
		particles.append({"pos": pos + Vector2(randf_range(-6, 6), randf_range(-3, 3)),
				"vel": Vector2.from_angle(randf() * TAU) * randf_range(20, 70), "life": 0.6, "max": 0.6,
				"color": Color(0.55, 0.43, 0.28, 0.8), "size": randf_range(2.5, 5.0)})


func _burst(pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		particles.append({"pos": pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(40, 150),
				"life": 0.5, "max": 0.5, "color": color, "size": randf_range(2.0, 4.5)})


func _popup(pos: Vector2, text: String, color: Color, screen_space := false) -> void:
	popups.append({"pos": pos, "text": text, "color": color, "life": 1.0, "screen": screen_space})


func _show_message(text: String) -> void:
	message = text
	message_time = 2.0


func _enemy_color(kind: String) -> Color:
	match kind:
		"glorp": return Color("8fd14f")
		"skitter": return Color("b05ce0")
		"shellback": return Color("e08a3c")
		"burrower": return Color("a0703f")
		"eye": return Color("f2f2f2")
		"blobule": return Color("f06aa8")
		"brute": return Color("b8322a")
	return Color.WHITE


func _tower_value(t: Dictionary) -> int:
	return int(t.spent * SELL_RATE)


func _can_build(kind: String, cell: Vector2i) -> bool:
	if not _inside(cell) or towers.has(cell) or obstacles.has(cell):
		return false
	var data: Dictionary = TOWERS[kind]
	if data.get("trap", false):
		return _tile(cell) == Tile.PATH
	if _tile(cell) != Tile.GRASS:
		return false
	return sacred.has(cell) or not data.get("sacred", false)


func _build_problem(kind: String, cell: Vector2i) -> String:
	var data: Dictionary = TOWERS[kind]
	if gold < int(data.cost[0]):
		return "Not enough gold"
	if obstacles.has(cell):
		return "Clear this spot first"
	if data.get("trap", false):
		return "Traps go on the path"
	if data.get("sacred", false) and not sacred.has(cell):
		return "Build this next to the temple"
	return "Can't build here"


func _place(kind: String, cell: Vector2i) -> bool:
	var data: Dictionary = TOWERS[kind]
	if not _can_build(kind, cell) or gold < int(data.cost[0]):
		_show_message(_build_problem(kind, cell))
		sfx.play("error")
		return false
	gold -= int(data.cost[0])
	towers[cell] = {"kind": kind, "level": 0, "cooldown": 0.2, "spent": int(data.cost[0]), "anim": 0.0, "aim": -PI / 2.0}
	_dust(_cell_center(cell) + Vector2(0, 12), 10)
	sfx.play("build")
	return true


func _upgrade_selected() -> void:
	if not towers.has(selected_cell):
		return
	var t: Dictionary = towers[selected_cell]
	if t.level >= 2:
		return
	var cost: int = TOWERS[t.kind].cost[t.level + 1]
	if gold < cost:
		_show_message("Not enough gold")
		sfx.play("error")
		return
	gold -= cost
	t.spent += cost
	t.level += 1
	_burst(_cell_center(selected_cell), GOLD, 14)
	sfx.play("upgrade")


func _sell_selected() -> void:
	if not towers.has(selected_cell):
		return
	var value := _tower_value(towers[selected_cell])
	gold += value
	_popup(_cell_center(selected_cell), "+%d" % value, GOLD)
	towers.erase(selected_cell)
	selected_cell = Vector2i(-1, -1)
	sfx.play("sell")


func _clear_cost(cell: Vector2i) -> int:
	return 20 if obstacles[cell].kind == "tree" else 30


func _clear_selected() -> void:
	if not obstacles.has(selected_cell):
		return
	var cost := _clear_cost(selected_cell)
	if gold < cost:
		_show_message("Not enough gold")
		sfx.play("error")
		return
	gold -= cost
	obstacles.erase(selected_cell)
	_dust(_cell_center(selected_cell), 16)
	selected_cell = Vector2i(-1, -1)
	sfx.play("build")


# --- Save ------------------------------------------------------------------------------

func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		for key in config.get_section_keys("best") if config.has_section("best") else []:
			best[key] = int(config.get_value("best", key, 0))
		map_index = clampi(int(config.get_value("settings", "map", 0)), 0, MAPS.size() - 1)
		difficulty = clampi(int(config.get_value("settings", "difficulty", 1)), 0, DIFFICULTIES.size() - 1)


func _save_best() -> void:
	var config := ConfigFile.new()
	for key in best:
		config.set_value("best", key, best[key])
	config.set_value("settings", "map", map_index)
	config.set_value("settings", "difficulty", difficulty)
	config.save(SAVE_PATH)


# --- Input -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		mouse = event.position
		hover_button = _button_at(mouse)
	match state:
		State.MENU, State.PAUSED, State.OVER:
			_overlay_input(event)
		State.PLAY:
			_play_input(event)


func _overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hover_button != "":
			_press(hover_button)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_SPACE, KEY_KP_ENTER:
				_press("play" if state == State.MENU else ("resume" if state == State.PAUSED else "again"))
			KEY_ESCAPE, KEY_P:
				if state == State.PAUSED:
					_press("resume")
			KEY_LEFT, KEY_A:
				if state == State.MENU:
					_press("map_%d" % posmod(map_index - 1, MAPS.size()))
			KEY_RIGHT, KEY_D:
				if state == State.MENU:
					_press("map_%d" % posmod(map_index + 1, MAPS.size()))
			KEY_UP, KEY_W:
				if state == State.MENU:
					_press("diff_%d" % posmod(difficulty - 1, DIFFICULTIES.size()))
			KEY_DOWN, KEY_S:
				if state == State.MENU:
					_press("diff_%d" % posmod(difficulty + 1, DIFFICULTIES.size()))


func _play_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local: Vector2 = event.position - BOARD_POS
		var cell := Vector2i(floori(local.x / CELL), floori(local.y / CELL))
		hover_cell = cell if _inside(cell) and Rect2(Vector2.ZERO, BOARD_SIZE).has_point(local) else Vector2i(-1, -1)
		hover_card = _card_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var card := _card_at(event.position)
		if card >= 0:
			var kind: String = TOWER_ORDER[card]
			build_kind = "" if build_kind == kind and not dragging else kind
			dragging = build_kind != ""
			selected_cell = Vector2i(-1, -1)
			sfx.play("select")
		elif hover_button != "":
			_press(hover_button)
		elif hover_cell != Vector2i(-1, -1):
			if build_kind != "":
				_place(build_kind, hover_cell)
				if not Input.is_key_pressed(KEY_SHIFT) and gold < int(TOWERS[build_kind].cost[0]):
					build_kind = ""
			elif towers.has(hover_cell) or obstacles.has(hover_cell):
				selected_cell = hover_cell if selected_cell != hover_cell else Vector2i(-1, -1)
				sfx.play("select")
			else:
				selected_cell = Vector2i(-1, -1)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Dragging a card onto the map places it on release.
		if dragging and build_kind != "" and hover_cell != Vector2i(-1, -1):
			if _place(build_kind, hover_cell):
				build_kind = ""
		dragging = false
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		build_kind = ""
		selected_cell = Vector2i(-1, -1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				var index: int = event.physical_keycode - KEY_1
				build_kind = "" if build_kind == TOWER_ORDER[index] else TOWER_ORDER[index]
				selected_cell = Vector2i(-1, -1)
				sfx.play("select")
			KEY_SPACE, KEY_N:
				_send_wave()
			KEY_F:
				_press("speed")
			KEY_U:
				_upgrade_selected()
			KEY_S, KEY_DELETE:
				_sell_selected()
			KEY_ESCAPE:
				if build_kind != "" or selected_cell != Vector2i(-1, -1):
					build_kind = ""
					selected_cell = Vector2i(-1, -1)
				else:
					_press("pause")
			KEY_P:
				_press("pause")


func _press(id: String) -> void:
	if id.begins_with("map_"):
		map_index = int(id.substr(4))
		_load_map()
		_save_best()
		sfx.play("select")
		return
	if id.begins_with("diff_"):
		difficulty = int(id.substr(5))
		_save_best()
		sfx.play("select")
		return
	match id:
		"play", "again", "restart":
			_start_game()
		"menu":
			state = State.MENU
			_load_map()
			sfx.play("select")
		"resume":
			state = State.PLAY
			sfx.play("select")
		"pause":
			state = State.PAUSED
			sfx.play("select")
		"speed":
			speed = 2 if speed == 1 else 1
			sfx.play("select")
		"next":
			_send_wave()
		"upgrade":
			_upgrade_selected()
		"sell":
			_sell_selected()
		"clear":
			_clear_selected()


# --- Layout ----------------------------------------------------------------------------

func _card_rect(index: int) -> Rect2:
	return Rect2(PANEL_X + (index % 2) * 124.0, 108.0 + (index / 2) * 96.0, 116.0, 88.0)


func _card_at(pos: Vector2) -> int:
	for i in TOWER_ORDER.size():
		if _card_rect(i).has_point(pos):
			return i
	return -1


## Top bar and side panel buttons, also drawn (inactive) under the pause and game over screens.
func _play_buttons() -> Dictionary:
	var list := {}
	list["next"] = Rect2(624, 14, 206, 46)
	list["speed"] = Rect2(PANEL_X, 14, 116, 46)
	list["pause"] = Rect2(PANEL_X + 124, 14, 120, 46)
	if towers.has(selected_cell):
		if towers[selected_cell].level < 2:
			list["upgrade"] = Rect2(PANEL_X, 620, 116, 50)
		list["sell"] = Rect2(PANEL_X + 124, 620, 120, 50)
	elif obstacles.has(selected_cell):
		list["clear"] = Rect2(PANEL_X, 620, 244, 50)
	return list


## Buttons that react to the mouse in the current state: id -> rect.
func _buttons() -> Dictionary:
	var list := {}
	match state:
		State.PLAY:
			list = _play_buttons()
		State.PAUSED:
			list["resume"] = Rect2(SCREEN.x / 2 - 110, 320, 220, 52)
			list["restart"] = Rect2(SCREEN.x / 2 - 110, 384, 220, 52)
			list["menu"] = Rect2(SCREEN.x / 2 - 110, 448, 220, 52)
		State.OVER:
			list["again"] = Rect2(SCREEN.x / 2 - 110, 384, 220, 52)
			list["menu"] = Rect2(SCREEN.x / 2 - 110, 448, 220, 52)
		State.MENU:
			for i in MAPS.size():
				list["map_%d" % i] = Rect2(70 + i * 245, 210, 225, 200)
			for i in DIFFICULTIES.size():
				list["diff_%d" % i] = Rect2(SCREEN.x / 2 - 255 + i * 175, 470, 160, 50)
			list["play"] = Rect2(SCREEN.x / 2 - 130, 570, 260, 64)
	return list


func _button_at(pos: Vector2) -> String:
	var list := _buttons()
	for id: String in list:
		if list[id].has_point(pos):
			return id
	return ""


# --- Drawing: board --------------------------------------------------------------------

func _draw_board(c: CanvasItem) -> void:
	c.draw_rect(Rect2(Vector2(-6, -6), BOARD_SIZE + Vector2(12, 12)), Color("1c1710"))
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))
			match _tile(cell):
				Tile.PATH:
					c.draw_rect(rect, SAND)
				_:
					c.draw_rect(rect, GRASS_A if (x + y) % 2 == 0 else GRASS_B)
	for item in decor:
		var pos: Vector2 = item[0]
		var cell := Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))
		if _tile(cell) == Tile.GRASS:
			var sway := sin(clock * 1.5 + item[2] * 6.0) * 1.5
			match int(item[1]):
				0, 1:
					for k in 3:
						c.draw_line(pos + Vector2(k * 3 - 3, 0), pos + Vector2(k * 3 - 4 + sway, -6 - k % 2 * 2), Color("3d6a2b"), 1.5)
				2:
					c.draw_circle(pos, 2.2, Color("f5e79e") if item[2] > 0.5 else Color("e9a6c9"))
		elif _tile(cell) == Tile.PATH:
			c.draw_circle(pos, 1.6 + item[2] * 1.5, SAND_DARK)

	# Path borders.
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if _tile(cell) != Tile.PATH:
				continue
			var origin := Vector2(cell) * CELL
			if _tile(cell + Vector2i.UP) != Tile.PATH and cell.y > 0:
				c.draw_rect(Rect2(origin, Vector2(CELL, 4)), SAND_DARK)
			if _tile(cell + Vector2i.DOWN) != Tile.PATH and cell.y < ROWS - 1:
				c.draw_rect(Rect2(origin + Vector2(0, CELL - 4), Vector2(CELL, 4)), SAND_DARK)
			if _tile(cell + Vector2i.LEFT) != Tile.PATH and cell.x > 0:
				c.draw_rect(Rect2(origin, Vector2(4, CELL)), SAND_DARK)
			if _tile(cell + Vector2i.RIGHT) != Tile.PATH and cell.x < COLS - 1:
				c.draw_rect(Rect2(origin + Vector2(CELL - 4, 0), Vector2(4, CELL)), SAND_DARK)

	# Sacred ground next to the temple, where the temple-only towers go.
	var highlight: bool = build_kind != "" and TOWERS[build_kind].get("sacred", false)
	for cell: Vector2i in sacred:
		var center := _cell_center(cell)
		var alpha := 0.35 + 0.25 * sin(clock * 3.0 + cell.x + cell.y) if highlight else 0.16
		c.draw_rect(Rect2(Vector2(cell) * CELL + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), Color(GOLD, alpha * 0.35))
		c.draw_arc(center, 9.0, 0.0, TAU, 16, Color(GOLD, alpha), 1.2, true)
		c.draw_line(center + Vector2(0, -6), center + Vector2(0, 6), Color(GOLD, alpha), 1.2)
		c.draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), Color(GOLD, alpha), 1.2)

	# Entrances.
	for points in path_points:
		var start := points[0]
		var inside := points[1]
		var edge := start.lerp(inside, 0.5)
		c.draw_circle(edge, 13.0, Color(0.1, 0.0, 0.15, 0.55 + 0.15 * sin(clock * 4.0)))
		c.draw_arc(edge, 13.0, clock * 3.0, clock * 3.0 + PI * 1.4, 14, Color("c77dff"), 2.0, true)


# --- Drawing: game objects --------------------------------------------------------------

func _draw_game(c: CanvasItem) -> void:
	# Depth-sorted: obstacles, towers, enemies and the temple, by their base line.
	var items := []
	for cell: Vector2i in obstacles:
		items.append([_cell_center(cell).y + 12.0, 0, cell])
	for cell: Vector2i in towers:
		items.append([_cell_center(cell).y + (0.0 if towers[cell].kind == "spikes" else 12.0), 1, cell])
	for e: Dictionary in enemies:
		items.append([e.pos.y + (0.0 if e.under else 8.0), 2, e])
	var temple: Vector2i = MAPS[map_index].temple
	items.append([(temple.y + 2) * CELL - 6.0, 3, temple])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	for e: Dictionary in enemies:
		if e.flying:
			c.draw_circle(e.pos + Vector2(0, 10), e.size * 0.7, Color(0, 0, 0, 0.22))

	for item in items:
		match int(item[1]):
			0:
				_draw_obstacle(c, item[2])
			1:
				var cell: Vector2i = item[2]
				var t: Dictionary = towers[cell]
				if t.kind == "spikes":
					_draw_tower(c, t.kind, _cell_center(cell), t.level, t.anim, t.aim)
				else:
					c.draw_circle(_cell_center(cell) + Vector2(2, 14), 15.0, Color(0, 0, 0, 0.22))
					_draw_tower(c, t.kind, _cell_center(cell), t.level, t.anim, t.aim)
			2:
				_draw_enemy(c, item[2])
			3:
				_draw_temple(c, item[2])

	for p: Dictionary in projectiles:
		match p.kind:
			"arrow":
				var dir := Vector2.from_angle(p.get("angle", 0.0))
				c.draw_line(p.pos - dir * 9.0, p.pos + dir * 3.0, Color("f3e3c0"), 2.0, true)
				c.draw_line(p.pos + dir * 3.0, p.pos + dir * 6.0, Color("d8d8d8"), 3.0, true)
			"boulder":
				var t: float = p.time / p.flight
				var ground: Vector2 = p.from.lerp(p.to, t)
				var height := sin(PI * t) * 70.0
				c.draw_circle(ground, 5.0 * (1.0 - 0.4 * sin(PI * t)), Color(0, 0, 0, 0.25))
				c.draw_circle(ground + Vector2(0, -height), 7.0, Color("6d6358"))
				c.draw_circle(ground + Vector2(-2, -height - 2), 3.0, Color("948a7d"))

	for fx: Dictionary in effects:
		var k: float = fx.life / fx.max
		match fx.kind:
			"bolt":
				c.draw_polyline(fx.points, Color(0.55, 0.8, 1.0, k * 0.6), 7.0, true)
				c.draw_polyline(fx.points, Color(1, 1, 1, k), 2.5, true)
			"ring":
				var color: Color = fx.color
				c.draw_arc(fx.pos, fx.radius * (1.0 - k * 0.75), 0.0, TAU, 48, Color(color, k * 0.8), 4.0 * k + 1.0, true)
				if color != GOLD:
					c.draw_circle(fx.pos, fx.radius * (1.0 - k * 0.75), Color(color, k * 0.18))
			"crater":
				c.draw_circle(fx.pos, fx.radius * 0.6, Color(0.25, 0.18, 0.1, k * 0.35))

	for p: Dictionary in particles:
		var color: Color = p.color
		c.draw_circle(p.pos, p.size * (p.life / p.max + 0.3), Color(color, color.a * p.life / p.max))

	for p: Dictionary in popups:
		if not p.screen:
			_text(c, p.pos, p.text, 16, Color(p.color, minf(1.0, p.life * 2.0)), true)

	if state == State.PLAY:
		_draw_placement(c)


func _draw_placement(c: CanvasItem) -> void:
	if towers.has(selected_cell):
		var t: Dictionary = towers[selected_cell]
		var center := _cell_center(selected_cell)
		c.draw_circle(center, TOWERS[t.kind].range[t.level], Color(1, 1, 1, 0.08))
		c.draw_arc(center, TOWERS[t.kind].range[t.level], 0.0, TAU, 64, Color(1, 1, 1, 0.5), 1.5, true)
		c.draw_rect(Rect2(Vector2(selected_cell) * CELL, Vector2(CELL, CELL)), Color(GOLD, 0.9), false, 2.0)
	elif obstacles.has(selected_cell):
		c.draw_rect(Rect2(Vector2(selected_cell) * CELL, Vector2(CELL, CELL)), Color(GOLD, 0.9), false, 2.0)
	if build_kind != "" and hover_cell != Vector2i(-1, -1):
		var ok := _can_build(build_kind, hover_cell) and gold >= int(TOWERS[build_kind].cost[0])
		var center := _cell_center(hover_cell)
		var tint := GREEN if ok else RED
		c.draw_circle(center, TOWERS[build_kind].range[0], Color(tint, 0.1))
		c.draw_arc(center, TOWERS[build_kind].range[0], 0.0, TAU, 64, Color(tint, 0.6), 1.5, true)
		c.draw_rect(Rect2(Vector2(hover_cell) * CELL, Vector2(CELL, CELL)), Color(tint, 0.3))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		c.draw_rect(Rect2(Vector2(hover_cell) * CELL, Vector2(CELL, CELL)), tint, false, 2.0)
		_draw_tower(c, build_kind, center, 0, 0.0, -PI / 2.0, 0.6)
	elif hover_cell != Vector2i(-1, -1) and (towers.has(hover_cell) or obstacles.has(hover_cell)):
		c.draw_rect(Rect2(Vector2(hover_cell) * CELL, Vector2(CELL, CELL)), Color(1, 1, 1, 0.5), false, 1.5)


func _draw_obstacle(c: CanvasItem, cell: Vector2i) -> void:
	var o: Dictionary = obstacles[cell]
	var center := _cell_center(cell)
	if o.kind == "tree":
		var sway := sin(clock * 1.2 + o.anim) * 1.5
		c.draw_circle(center + Vector2(3, 13), 14.0, Color(0, 0, 0, 0.22))
		c.draw_rect(Rect2(center + Vector2(-3, 2), Vector2(6, 12)), WOOD_DARK)
		c.draw_circle(center + Vector2(-7 + sway, -2), 10.0, Color("2f5e25"))
		c.draw_circle(center + Vector2(7 + sway, -1), 10.0, Color("2f5e25"))
		c.draw_circle(center + Vector2(sway, -10), 12.0, Color("3a7030"))
		c.draw_circle(center + Vector2(-3 + sway, -14), 5.0, Color("4f8a3f"))
	else:
		c.draw_circle(center + Vector2(3, 10), 15.0, Color(0, 0, 0, 0.22))
		c.draw_colored_polygon(PackedVector2Array([center + Vector2(-15, 10), center + Vector2(-12, -6), center + Vector2(-2, -13),
				center + Vector2(11, -8), center + Vector2(15, 8)]), Color("7d766b"))
		c.draw_colored_polygon(PackedVector2Array([center + Vector2(-12, -6), center + Vector2(-2, -13), center + Vector2(4, -6),
				center + Vector2(-6, 0)]), Color("a19a8e"))


func _draw_temple(c: CanvasItem, cell: Vector2i) -> void:
	var origin := Vector2(cell) * CELL
	var flash := temple_flash
	var tint := func(color: Color) -> Color: return color.lerp(RED, flash * 0.6)
	c.draw_rect(Rect2(origin + Vector2(2, 58), Vector2(80, 20)), Color(0, 0, 0, 0.25))
	# Stepped pyramid.
	var steps := [[Rect2(0, 44, 80, 32), STONE_DARK], [Rect2(8, 24, 64, 24), STONE], [Rect2(16, 6, 48, 22), STONE_DARK], [Rect2(24, -14, 32, 24), STONE]]
	for s in steps:
		var rect: Rect2 = s[0]
		c.draw_rect(Rect2(origin + rect.position, rect.size), tint.call(s[1]))
		c.draw_rect(Rect2(origin + rect.position, Vector2(rect.size.x, 3)), tint.call(Color(s[1]).lightened(0.25)))
	# Stairs and doorway.
	c.draw_rect(Rect2(origin + Vector2(32, 44), Vector2(16, 32)), tint.call(Color("8d8474")))
	for k in 5:
		c.draw_line(origin + Vector2(32, 48 + k * 6), origin + Vector2(48, 48 + k * 6), tint.call(STONE_DARK), 1.0)
	c.draw_rect(Rect2(origin + Vector2(33, -6), Vector2(14, 16)), Color("1a120a"))
	# Lightning crystal on top.
	var glow := 0.6 + 0.4 * sin(clock * 5.0)
	c.draw_circle(origin + Vector2(40, -24), 12.0, Color(0.4, 0.75, 1.0, 0.25 * glow))
	c.draw_colored_polygon(PackedVector2Array([origin + Vector2(40, -38), origin + Vector2(47, -24), origin + Vector2(40, -14), origin + Vector2(33, -24)]), Color("8fd8ff"))
	c.draw_colored_polygon(PackedVector2Array([origin + Vector2(40, -38), origin + Vector2(47, -24), origin + Vector2(40, -24)]), Color("d8f3ff"))
	# Fire braziers.
	for side in [6.0, 74.0]:
		var base := origin + Vector2(side, 44)
		c.draw_rect(Rect2(base + Vector2(-5, -8), Vector2(10, 8)), Color("4a4035"))
		_flame(c, base + Vector2(0, -8), 7.0, clock * 9.0 + side)
	# Lives bar.
	var ratio := float(lives) / START_LIVES
	c.draw_rect(Rect2(origin + Vector2(10, 82), Vector2(60, 6)), Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(origin + Vector2(11, 83), Vector2(58 * ratio, 4)), GREEN.lerp(RED, 1.0 - ratio))


func _flame(c: CanvasItem, base: Vector2, size: float, phase: float) -> void:
	var flicker := 1.0 + 0.2 * sin(phase) + 0.1 * sin(phase * 2.7)
	c.draw_colored_polygon(PackedVector2Array([base + Vector2(-size, 0), base + Vector2(0, -size * 2.2 * flicker), base + Vector2(size, 0)]), Color("ff6a1f"))
	c.draw_colored_polygon(PackedVector2Array([base + Vector2(-size * 0.55, 0), base + Vector2(0, -size * 1.4 * flicker), base + Vector2(size * 0.55, 0)]), Color("ffd24a"))


func _draw_tower(c: CanvasItem, kind: String, center: Vector2, level: int, anim: float, aim: float, alpha := 1.0) -> void:
	var a := func(color: Color) -> Color: return Color(color, color.a * alpha)
	var trim := GOLD if level >= 1 else STONE_DARK
	match kind:
		"arrow":
			c.draw_rect(Rect2(center + Vector2(-13, 6), Vector2(26, 9)), a.call(STONE_DARK))
			c.draw_rect(Rect2(center + Vector2(-9, -16), Vector2(18, 24)), a.call(WOOD))
			for k in 3:
				c.draw_line(center + Vector2(-9, -10 + k * 7), center + Vector2(9, -10 + k * 7), a.call(WOOD_DARK), 1.0)
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-13, -15), center + Vector2(0, -28), center + Vector2(13, -15)]), a.call(Color("a8432e") if level < 2 else Color("c9a227")))
			var tip := center + Vector2(0, -20) + Vector2.from_angle(aim) * 11.0
			c.draw_line(center + Vector2(0, -20), tip, a.call(Color("e8d9b5")), 2.0, true)
			c.draw_rect(Rect2(center + Vector2(-13, 6), Vector2(26, 2)), a.call(trim))
		"catapult":
			c.draw_rect(Rect2(center + Vector2(-15, 2), Vector2(30, 8)), a.call(WOOD))
			c.draw_circle(center + Vector2(-10, 11), 4.5, a.call(WOOD_DARK))
			c.draw_circle(center + Vector2(10, 11), 4.5, a.call(WOOD_DARK))
			c.draw_line(center + Vector2(-6, 2), center + Vector2(0, -10), a.call(WOOD_DARK), 3.0)
			c.draw_line(center + Vector2(6, 2), center + Vector2(0, -10), a.call(WOOD_DARK), 3.0)
			var swing := -1.2 + (anim / 0.5) * 2.2 if anim > 0.0 else -1.2
			var arm_dir := Vector2.from_angle(swing - PI / 2.0 + (0.4 if cos(aim) < 0.0 else -0.4))
			var arm_end := center + Vector2(0, -10) + arm_dir * 17.0
			c.draw_line(center + Vector2(0, -10), arm_end, a.call(Color("b27a42")), 3.0, true)
			c.draw_circle(arm_end, 4.0, a.call(Color("5a4a3a")))
			if anim <= 0.0:
				c.draw_circle(arm_end, 3.0, a.call(Color("8a8074")))
			c.draw_rect(Rect2(center + Vector2(-15, 2), Vector2(30, 2)), a.call(trim))
		"spikes":
			c.draw_rect(Rect2(center + Vector2(-15, -15), Vector2(30, 30)), a.call(Color("4d4a45")))
			c.draw_rect(Rect2(center + Vector2(-15, -15), Vector2(30, 30)), a.call(trim), false, 1.5)
			var up := anim > 0.0
			for gy in 3:
				for gx in 3:
					var p := center + Vector2(-9 + gx * 9, -9 + gy * 9)
					if up:
						c.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 3), p + Vector2(0, -7), p + Vector2(3, 3)]), a.call(Color("d9d6cf")))
					else:
						c.draw_circle(p, 1.8, a.call(Color("24221f")))
		"lightning":
			c.draw_rect(Rect2(center + Vector2(-14, 6), Vector2(28, 9)), a.call(STONE_DARK))
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-9, 7), center + Vector2(-5, -22), center + Vector2(5, -22), center + Vector2(9, 7)]), a.call(STONE))
			c.draw_line(center + Vector2(0, -18), center + Vector2(0, 2), a.call(Color("5fb4e8")), 1.5)
			var glow := 0.5 + 0.5 * sin(clock * 6.0) + anim * 2.0
			c.draw_circle(center + Vector2(0, -32), 9.0 + level * 1.5, a.call(Color(0.45, 0.8, 1.0, 0.25 * glow)))
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -42), center + Vector2(6, -32), center + Vector2(0, -22), center + Vector2(-6, -32)]), a.call(Color("8fd8ff")))
			c.draw_rect(Rect2(center + Vector2(-14, 6), Vector2(28, 2)), a.call(trim))
		"fire":
			c.draw_rect(Rect2(center + Vector2(-7, -2), Vector2(14, 16)), a.call(STONE_DARK))
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-15, -8), center + Vector2(15, -8), center + Vector2(9, 0), center + Vector2(-9, 0)]), a.call(Color("5a4d40")))
			c.draw_line(center + Vector2(-15, -8), center + Vector2(15, -8), a.call(trim), 2.0)
			var size := 8.0 + level * 1.5 + anim * 10.0
			if alpha >= 1.0:
				_flame(c, center + Vector2(-5, -8), size * 0.6, clock * 10.0 + center.x)
				_flame(c, center + Vector2(5, -8), size * 0.6, clock * 11.0 + center.y)
				_flame(c, center + Vector2(0, -8), size, clock * 9.0)
		"bell":
			c.draw_rect(Rect2(center + Vector2(-14, 8), Vector2(28, 7)), a.call(STONE_DARK))
			c.draw_line(center + Vector2(-12, 9), center + Vector2(-12, -22), a.call(WOOD), 3.0)
			c.draw_line(center + Vector2(12, 9), center + Vector2(12, -22), a.call(WOOD), 3.0)
			c.draw_line(center + Vector2(-15, -22), center + Vector2(15, -22), a.call(WOOD_DARK), 4.0)
			var swing := sin(anim * 9.0) * 0.45 * minf(1.0, anim)
			var top := center + Vector2(0, -20)
			var bell := PackedVector2Array()
			for p in [Vector2(-4, 0), Vector2(-6, 7), Vector2(-10, 16), Vector2(10, 16), Vector2(6, 7), Vector2(4, 0)]:
				bell.append(top + p.rotated(swing))
			c.draw_colored_polygon(bell, a.call(GOLD if level < 2 else Color("ffe38a")))
			c.draw_circle(top + Vector2(0, 17).rotated(swing), 2.5, a.call(Color("a57b1f")))
			c.draw_rect(Rect2(center + Vector2(-14, 8), Vector2(28, 2)), a.call(trim))
	# Level pips.
	if kind != "spikes":
		for i in level:
			var p := center + Vector2(-4 + i * 8, 17)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 0), p + Vector2(0, 3), p + Vector2(-3, 0)]), a.call(GOLD))


func _draw_enemy(c: CanvasItem, e: Dictionary) -> void:
	var pos: Vector2 = e.pos
	var s: float = e.size
	var t: float = e.anim
	var fade := clampf((path_cum[e.path][path_cum[e.path].size() - 1] - e.dist) / 30.0, 0.0, 1.0)
	var col := func(color: Color) -> Color:
		var out := color.lerp(Color.WHITE, 0.7) if e.hit > 0.0 else color
		if e.slow > 0.0:
			out = out.lerp(BLUE, 0.35)
		return Color(out, out.a * fade)
	var face: float = signf(e.dir.x) if absf(e.dir.x) > 0.1 else 1.0

	if e.under:
		c.draw_ellipse(pos, s * 1.1, s * 0.55, Color(0.36, 0.26, 0.14, 0.9 * fade))
		for k in 4:
			var p := pos + Vector2(sin(t * 7.0 + k * 1.7) * s * 0.7, cos(t * 5.0 + k) * s * 0.25 - 2)
			c.draw_circle(p, 2.2, Color(0.55, 0.42, 0.26, fade))
		return

	if not e.flying:
		c.draw_ellipse(pos + Vector2(2, s * 0.6), s * 0.95, s * 0.4, Color(0, 0, 0, 0.22 * fade))

	match e.kind:
		"glorp":
			var bob := sin(t * 6.0) * 1.5
			c.draw_ellipse(pos + Vector2(0, bob), s, s * 0.8, col.call(Color("8fd14f")))
			c.draw_ellipse(pos + Vector2(-3, bob - 3), s * 0.45, s * 0.3, col.call(Color("b9ea7c")))
			for side in [-1.0, 1.0]:
				var stalk := pos + Vector2(side * 5, bob - s * 0.6)
				var tip := stalk + Vector2(side * 3 + sin(t * 4.0 + side) * 2.0, -8)
				c.draw_line(stalk, tip, col.call(Color("6aa83a")), 2.0)
				c.draw_circle(tip, 3.5, col.call(Color.WHITE))
				c.draw_circle(tip + Vector2(face, 0), 1.6, col.call(INK))
		"skitter":
			for k in 3:
				var leg := sin(t * 22.0 + k * 2.1) * 3.0
				for side in [-1.0, 1.0]:
					c.draw_line(pos + Vector2(-4 + k * 4, 0), pos + Vector2(-7 + k * 7 + leg, side * (s + 2)), col.call(Color("5a2a78")), 1.5)
			c.draw_ellipse(pos, s * 1.1, s * 0.7, col.call(Color("b05ce0")))
			c.draw_circle(pos + Vector2(face * s * 0.8, 0), s * 0.5, col.call(Color("8a3dbb")))
			c.draw_circle(pos + Vector2(face * s, -2), 1.8, col.call(Color("ff4040")))
			c.draw_circle(pos + Vector2(face * s, 2), 1.8, col.call(Color("ff4040")))
		"shellback":
			var step := sin(t * 5.0) * 2.0
			c.draw_circle(pos + Vector2(face * (s + 2), 2), s * 0.4, col.call(Color("e08a3c")))
			c.draw_circle(pos + Vector2(face * (s + 4), 0), 1.5, col.call(INK))
			for side in [-1.0, 1.0]:
				c.draw_circle(pos + Vector2(-5 + step * side, s * 0.6), 3.5, col.call(Color("b86a2a")))
				c.draw_circle(pos + Vector2(6 - step * side, s * 0.6), 3.5, col.call(Color("b86a2a")))
			c.draw_ellipse(pos + Vector2(0, -2), s, s * 0.8, col.call(Color("6f7f8c")))
			c.draw_arc(pos + Vector2(0, -2), s * 0.6, PI, TAU, 12, col.call(Color("95a5b1")), 2.0)
			c.draw_line(pos + Vector2(0, -2 - s * 0.8), pos + Vector2(0, -2 + s * 0.4), col.call(Color("56636d")), 1.5)
			if e.break > 0.0:
				c.draw_line(pos + Vector2(-5, -8), pos + Vector2(3, 2), Color(GOLD, fade), 1.5)
		"burrower":
			c.draw_circle(pos, s, col.call(Color("a0703f")))
			c.draw_circle(pos + Vector2(-face * 2, 3), s * 0.6, col.call(Color("c89a6a")))
			var nose := pos + Vector2(face * s * 0.8, 0)
			c.draw_colored_polygon(PackedVector2Array([nose + Vector2(0, -5), nose + Vector2(face * 10, 0), nose + Vector2(0, 5)]), col.call(Color("9aa1a8")))
			c.draw_line(nose + Vector2(face * 3, -3), nose + Vector2(face * 3, 3), col.call(Color("6c737a")), 1.0)
			c.draw_circle(pos + Vector2(face * 3, -5), 1.6, col.call(INK))
		"eye":
			var hover := sin(t * 3.0) * 3.0 - 14.0
			var body := pos + Vector2(0, hover)
			for k in 3:
				var base := body + Vector2(-5 + k * 5, s * 0.7)
				c.draw_line(base, base + Vector2(sin(t * 6.0 + k) * 4.0, 10), col.call(Color("c75b8c")), 2.0, true)
			c.draw_circle(body, s, col.call(Color("f2f2f2")))
			c.draw_arc(body, s, 0.0, TAU, 20, col.call(Color("c75b8c")), 1.5, true)
			var look: Vector2 = e.dir * 3.0
			c.draw_circle(body + look, s * 0.5, col.call(Color("3fa06b")))
			c.draw_circle(body + look * 1.3, s * 0.22, col.call(INK))
		"blobule":
			var wob := sin(t * 4.0) * 2.0
			c.draw_ellipse(pos + Vector2(0, -1), s + wob, s - wob * 0.6, col.call(Color(0.94, 0.42, 0.66, 0.85)))
			c.draw_circle(pos + Vector2(sin(t * 2.0) * 3.0, 0), s * 0.35, col.call(Color("a8285f")))
			c.draw_circle(pos + Vector2(-5, -6), 2.5, col.call(Color(1, 1, 1, 0.7)))
			if e.hp < e.max_hp and e.burn_time <= 0.0:
				c.draw_line(pos + Vector2(s, -s), pos + Vector2(s, -s - 6), Color(GREEN, fade), 2.0)
				c.draw_line(pos + Vector2(s - 3, -s - 3), pos + Vector2(s + 3, -s - 3), Color(GREEN, fade), 2.0)
		"brute":
			var stomp := absf(sin(t * 3.0)) * 2.0
			var body := pos + Vector2(0, -stomp)
			for side in [-1.0, 1.0]:
				c.draw_rect(Rect2(pos + Vector2(side * 9 - 4, 8), Vector2(8, 10)), col.call(Color("7a1f1a")))
			c.draw_ellipse(body, s, s * 0.85, col.call(Color("b8322a")))
			for k in 4:
				var spike := body + Vector2(-12 + k * 8, -s * 0.8)
				c.draw_colored_polygon(PackedVector2Array([spike + Vector2(-4, 3), spike + Vector2(0, -7), spike + Vector2(4, 3)]), col.call(Color("5c1510")))
			var head := body + Vector2(face * s * 0.7, -4)
			c.draw_circle(head, s * 0.45, col.call(Color("9a2821")))
			c.draw_line(head + Vector2(-6, -6), head + Vector2(-10, -15), col.call(Color("e8dcc0")), 3.0)
			c.draw_line(head + Vector2(6, -6), head + Vector2(10, -15), col.call(Color("e8dcc0")), 3.0)
			c.draw_circle(head + Vector2(face * 4 - 3, -1), 2.2, Color("ffd23f", fade))
			c.draw_circle(head + Vector2(face * 4 + 3, -1), 2.2, Color("ffd23f", fade))

	if e.burn_time > 0.0:
		_flame(c, pos + Vector2(sin(t * 3.0) * 4.0, -s * 0.3), 4.0, t * 14.0)
	if e.hp < e.max_hp:
		var top := pos + Vector2(-s, -s - (24.0 if e.flying else 10.0))
		c.draw_rect(Rect2(top, Vector2(s * 2, 4)), Color(0, 0, 0, 0.6 * fade))
		c.draw_rect(Rect2(top + Vector2(0.5, 0.5), Vector2((s * 2 - 1) * clampf(e.hp / e.max_hp, 0.0, 1.0), 3)), Color(GREEN.lerp(RED, 1.0 - e.hp / e.max_hp), fade))


# --- Drawing: HUD --------------------------------------------------------------------------

func _draw_hud(c: CanvasItem) -> void:
	if state == State.MENU:
		_draw_menu(c)
		return
	# Top bar.
	c.draw_rect(Rect2(0, 0, SCREEN.x, 70), PANEL)
	c.draw_rect(Rect2(0, 68, SCREEN.x, 2), PANEL_EDGE)
	_coin(c, Vector2(34, 37), 11.0)
	_text(c, Vector2(54, 46), str(gold), 26, GOLD)
	_heart(c, Vector2(180, 36), 10.0)
	_text(c, Vector2(198, 46), str(lives), 26, TEXT)
	_text(c, Vector2(290, 32), "WAVE", 13, MUTED)
	_text(c, Vector2(290, 54), "%d / %d" % [wave, TOTAL_WAVES], 22, TEXT)
	_text(c, Vector2(400, 32), MAPS[map_index].name.to_upper(), 13, MUTED)
	_text(c, Vector2(400, 54), DIFFICULTIES[difficulty].name, 18, TEXT)

	var buttons := _play_buttons()
	buttons.merge(_buttons())
	if buttons.has("next"):
		var label := "Start wave 1"
		var enabled := spawn_queue.is_empty() and wave < TOTAL_WAVES
		if wave > 0:
			if not enabled:
				label = "Wave %d incoming" % wave if wave < TOTAL_WAVES or not spawn_queue.is_empty() else "Final wave"
			elif next_timer > 0.0:
				label = "Next wave  +%d" % int(next_timer)
		_button(c, buttons.next, label, "next", enabled, true)
		if next_timer > 0.0:
			var rect: Rect2 = buttons.next
			c.draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 6), Vector2((rect.size.x - 8) * next_timer / WAVE_BREAK, 3)), Color(GOLD, 0.8))
	_button(c, buttons.speed, "Speed x%d" % speed, "speed", true, speed == 2)
	_button(c, buttons.pause, "Pause", "pause", true)

	# Side panel.
	c.draw_rect(Rect2(PANEL_X - 8, 76, SCREEN.x - PANEL_X + 8, SCREEN.y - 76), PANEL)
	c.draw_rect(Rect2(PANEL_X - 8, 76, 2, SCREEN.y - 76), PANEL_EDGE)
	_text(c, Vector2(PANEL_X, 100), "BUILD", 14, MUTED)
	_text(c, Vector2(PANEL_X + 244, 100), "◆ = next to the temple only", 12, MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in TOWER_ORDER.size():
		_draw_card(c, i)
	_draw_info(c)

	for p: Dictionary in popups:
		if p.screen:
			_text(c, p.pos, p.text, 18, Color(p.color, minf(1.0, p.life * 2.0)), true)
	if message_time > 0.0:
		var alpha := minf(1.0, message_time * 2.0)
		var center := BOARD_POS + Vector2(BOARD_SIZE.x / 2.0, 34)
		var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 40
		c.draw_rect(Rect2(center - Vector2(width / 2.0, 20), Vector2(width, 38)), Color(0, 0, 0, 0.55 * alpha))
		_text(c, center + Vector2(0, 8), message, 22, Color(TEXT, alpha), true)

	if state == State.PAUSED:
		_dim(c)
		_text(c, Vector2(SCREEN.x / 2, 270), "Paused", 44, TEXT, true)
		_button(c, buttons.resume, "Resume", "resume", true, true)
		_button(c, buttons.restart, "Restart", "restart", true)
		_button(c, buttons.menu, "Main menu", "menu", true)
	elif state == State.OVER:
		_dim(c)
		if won:
			_text(c, Vector2(SCREEN.x / 2, 250), "The temple is safe!", 46, GOLD, true)
			_text(c, Vector2(SCREEN.x / 2, 300), "You held back all %d waves with %d lives left." % [TOTAL_WAVES, lives], 20, TEXT, true)
		else:
			_text(c, Vector2(SCREEN.x / 2, 250), "The temple has fallen", 46, RED, true)
			_text(c, Vector2(SCREEN.x / 2, 300), "You survived %d of %d waves." % [maxi(0, wave - 1), TOTAL_WAVES], 20, TEXT, true)
		var record := int(best.get("%d_%d" % [map_index, difficulty], 0))
		_text(c, Vector2(SCREEN.x / 2, 340), _record_text(record), 16, MUTED, true)
		_button(c, buttons.again, "Play again", "again", true, true)
		_button(c, buttons.menu, "Main menu", "menu", true)


func _draw_card(c: CanvasItem, index: int) -> void:
	var kind: String = TOWER_ORDER[index]
	var data: Dictionary = TOWERS[kind]
	var rect := _card_rect(index)
	var cost: int = data.cost[0]
	var affordable := gold >= cost
	var active := build_kind == kind
	var fill := PANEL_LIGHT.lightened(0.12) if hover_card == index else PANEL_LIGHT
	c.draw_rect(rect, fill.darkened(0.25) if not affordable else fill)
	var edge := GOLD if active else (Color("9c7b3c") if data.get("sacred", false) else PANEL_EDGE)
	c.draw_rect(rect, edge, false, 2.0 if active else 1.0)
	_draw_tower(c, kind, rect.position + Vector2(58, 44), 0, 0.0, -PI / 2.0, 1.0 if affordable else 0.45)
	_text(c, rect.position + Vector2(6, 16), str(index + 1), 12, MUTED)
	if data.get("sacred", false):
		_text(c, rect.position + Vector2(rect.size.x - 6, 16), "◆", 12, GOLD, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(c, rect.position + Vector2(58, 76), data.name, 12, TEXT if affordable else MUTED, true)
	var price_width := font.get_string_size(str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_coin(c, rect.position + Vector2(rect.size.x - 13 - price_width, 58), 4.5)
	_text(c, rect.position + Vector2(rect.size.x - 6, 63), str(cost), 13, GOLD if affordable else RED, false, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_info(c: CanvasItem) -> void:
	var box := Rect2(PANEL_X, 400, 244, 212)
	c.draw_rect(box, Color(0, 0, 0, 0.2))
	var x := PANEL_X + 10
	var buttons := _play_buttons()
	var kind := ""
	var level := 0
	if towers.has(selected_cell):
		kind = towers[selected_cell].kind
		level = towers[selected_cell].level
	elif hover_card >= 0:
		kind = TOWER_ORDER[hover_card]
	elif build_kind != "":
		kind = build_kind

	if obstacles.has(selected_cell):
		var what: String = "Tree" if obstacles[selected_cell].kind == "tree" else "Boulder"
		_text(c, Vector2(x, 428), what, 20, TEXT)
		_wrap(c, Vector2(x, 454), "Blocks building. Pay gold to clear the spot.", 14, MUTED, 224)
		_button(c, buttons.clear, "Clear  (%d gold)" % _clear_cost(selected_cell), "clear", gold >= _clear_cost(selected_cell), true)
		return
	if kind == "":
		_text(c, Vector2(x, 428), "How to play", 18, TEXT)
		_wrap(c, Vector2(x, 452), "Pick a tower and click or drag it onto the map. Stop the creatures before they reach the temple. ◆ towers only fit on the glowing ground next to the temple. Click a tower to upgrade or sell it.", 13, MUTED, 224)
		return

	var data: Dictionary = TOWERS[kind]
	_text(c, Vector2(x, 428), data.name, 20, TEXT)
	if towers.has(selected_cell):
		for i in 3:
			var p := Vector2(PANEL_X + 214 - (2 - i) * 14, 422)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), GOLD if i <= level else PANEL_EDGE)
	_wrap(c, Vector2(x, 450), data.desc, 13, MUTED, 224)

	var lines := []
	var next := level + 1 if towers.has(selected_cell) and level < 2 else -1
	var stat := func(label: String, key: String, fmt: String) -> void:
		if data.has(key):
			var now := fmt % data[key][level]
			if next >= 0 and data[key][next] != data[key][level]:
				now += "  →  " + fmt % data[key][next]
			lines.append([label, now])
	stat.call("Damage", "damage", "%d")
	if data.has("cooldown") and kind != "bell":
		lines.append(["Speed", "%.1f/s" % (1.0 / data.cooldown[level]) + ("  →  %.1f/s" % (1.0 / data.cooldown[next]) if next >= 0 else "")])
	if kind != "spikes":
		stat.call("Range", "range", "%d")
	stat.call("Chains", "chains", "%d")
	stat.call("Burn", "burn", "%d/s")
	if kind == "bell":
		lines.append(["Slow", "%d%%" % int(data.slow[level] * 100) + ("  →  %d%%" % int(data.slow[next] * 100) if next >= 0 else "")])
		stat.call("Armor -", "armor_break", "%d")
	var targets := "Ground + air" if data.air else "Ground only"
	lines.append(["Hits", targets])
	for i in lines.size():
		_text(c, Vector2(x, 510 + i * 19), lines[i][0], 13, MUTED)
		_text(c, Vector2(x + 70, 510 + i * 19), lines[i][1], 13, TEXT)

	if towers.has(selected_cell):
		var t: Dictionary = towers[selected_cell]
		if buttons.has("upgrade"):
			var cost: int = data.cost[level + 1]
			_button(c, buttons.upgrade, "Upgrade %d" % cost, "upgrade", gold >= cost, true)
		else:
			_text(c, Vector2(PANEL_X + 58, 652), "Max level", 15, GOLD, true)
		_button(c, buttons.sell, "Sell %d" % _tower_value(t), "sell", true)


func _draw_menu(c: CanvasItem) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("17130d"))
	for i in 40:
		var x := fmod(i * 97.0, SCREEN.x)
		var y := fmod(i * 53.0 + clock * (6.0 + i % 5), SCREEN.y)
		c.draw_circle(Vector2(x, SCREEN.y - y), 1.5, Color(GOLD, 0.15))
	_text(c, Vector2(SCREEN.x / 2 + 3, 113), "TEMPLE DEFENDER", 64, INK, true)
	_text(c, Vector2(SCREEN.x / 2, 110), "TEMPLE DEFENDER", 64, GOLD, true)
	_text(c, Vector2(SCREEN.x / 2, 152), "Guard the Temple of Lightning and Fire from %d waves of alien creatures." % TOTAL_WAVES, 18, MUTED, true)

	var buttons := _buttons()
	for i in MAPS.size():
		var rect: Rect2 = buttons["map_%d" % i]
		var chosen := i == map_index
		c.draw_rect(rect, PANEL_LIGHT if chosen else PANEL)
		c.draw_rect(rect, GOLD if chosen else (PANEL_EDGE.lightened(0.2) if hover_button == "map_%d" % i else PANEL_EDGE), false, 3.0 if chosen else 1.5)
		_draw_minimap(c, i, Rect2(rect.position + Vector2(12, 12), Vector2(rect.size.x - 24, 135)))
		_text(c, rect.position + Vector2(rect.size.x / 2, 170), MAPS[i].name, 18, TEXT, true)
		var record := int(best.get("%d_%d" % [i, difficulty], 0))
		_text(c, rect.position + Vector2(rect.size.x / 2, 190), _record_text(record), 13, GOLD if record > TOTAL_WAVES else MUTED, true)

	_text(c, Vector2(SCREEN.x / 2, 455), "DIFFICULTY", 14, MUTED, true)
	for i in DIFFICULTIES.size():
		_button(c, buttons["diff_%d" % i], DIFFICULTIES[i].name, "diff_%d" % i, true, i == difficulty)
	_button(c, buttons.play, "Play", "play", true, true, 28)
	_text(c, Vector2(SCREEN.x / 2, 672), "Click or drag towers onto the map  ·  Space: next wave  ·  F: speed  ·  P: pause", 14, MUTED, true)


func _draw_minimap(c: CanvasItem, index: int, rect: Rect2) -> void:
	var map: Dictionary = MAPS[index]
	var unit := minf(rect.size.x / COLS, rect.size.y / ROWS)
	var origin := rect.position + (rect.size - Vector2(COLS, ROWS) * unit) / 2.0
	c.draw_rect(Rect2(origin, Vector2(COLS, ROWS) * unit), GRASS_A)
	for waypoints in map.paths:
		var cells: Array = waypoints
		for i in range(1, cells.size()):
			var a: Vector2 = (Vector2(cells[i - 1]) + Vector2(0.5, 0.5)) * unit
			var b: Vector2 = (Vector2(cells[i]) + Vector2(0.5, 0.5)) * unit
			a = a.clamp(Vector2.ONE * unit * 0.5, Vector2(COLS - 0.5, ROWS - 0.5) * unit)
			c.draw_line(origin + a, origin + b, SAND, unit, false)
			c.draw_rect(Rect2(origin + b - Vector2.ONE * unit * 0.5, Vector2.ONE * unit), SAND)
	var temple: Vector2i = map.temple
	c.draw_rect(Rect2(origin + Vector2(temple) * unit, Vector2(2, 2) * unit), STONE)
	c.draw_circle(origin + (Vector2(temple) + Vector2.ONE) * unit, unit * 0.5, BLUE)


func _record_text(record: int) -> String:
	if record > TOTAL_WAVES:
		return "★ Temple saved"
	if record > 0:
		return "Best: wave %d" % record
	return "Not played yet"


# --- Drawing: widgets ----------------------------------------------------------------------

func _button(c: CanvasItem, rect: Rect2, label: String, id: String, enabled: bool, primary := false, size := 17) -> void:
	var hovered := hover_button == id and enabled
	var fill := Color("b8862b") if primary else PANEL_LIGHT
	if not enabled:
		fill = fill.darkened(0.45)
	elif hovered:
		fill = fill.lightened(0.15)
	c.draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.35))
	c.draw_rect(rect, fill)
	c.draw_rect(rect, GOLD.lightened(0.3) if primary and enabled else PANEL_EDGE, false, 1.5)
	var color := INK if primary and enabled else (TEXT if enabled else MUTED)
	_text(c, rect.position + Vector2(rect.size.x / 2, rect.size.y / 2 + size * 0.36), label, size, color, true)


func _text(c: CanvasItem, pos: Vector2, text: String, size: int, color: Color, centered := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var at := pos
	if centered:
		at.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		at.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, color.a * 0.5))
	c.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _wrap(c: CanvasItem, pos: Vector2, text: String, size: int, color: Color, width: float) -> void:
	c.draw_multiline_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, color)


func _dim(c: CanvasItem) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.62))


func _coin(c: CanvasItem, center: Vector2, radius: float) -> void:
	c.draw_circle(center, radius, Color("b8862b"))
	c.draw_circle(center, radius * 0.75, GOLD)
	c.draw_circle(center + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.25, Color("fff1b8"))


func _heart(c: CanvasItem, center: Vector2, size: float) -> void:
	c.draw_circle(center + Vector2(-size * 0.5, -size * 0.2), size * 0.6, RED)
	c.draw_circle(center + Vector2(size * 0.5, -size * 0.2), size * 0.6, RED)
	c.draw_colored_polygon(PackedVector2Array([center + Vector2(-size * 1.08, 0), center + Vector2(size * 1.08, 0), center + Vector2(0, size * 1.1)]), RED)
