extends Node2D
## Snake Quest: steer the snake to eat apples and grow, without hitting the walls or yourself.
## Arrows / WASD or a gamepad (D-pad / left stick) steer; P, Esc or Start pauses.
## Behind the menu the snake plays by itself.
##
## Two modes: Classic is the endless original, Campaign is twelve hand-built levels
## (see scripts/levels.gd) with stone walls, patrolling blades, portals and poison
## apples, each cleared by meeting its goal.

const SfxScript := preload("res://scripts/sfx.gd")
const Levels := preload("res://scripts/levels.gd")
const Strings := preload("res://scripts/strings.gd")
const ARABIC_FONT := "res://common/fonts/NotoSansArabic-subset.ttf"
const CHINESE_FONT := "res://common/fonts/NotoSansSC-subset.ttf"

const SCREEN := Vector2(1000, 760)
const COLS := 24
const ROWS := 16
const CELL := 40.0
const BOARD_POS := Vector2(20, 100)
const BOARD_SIZE := Vector2(COLS * CELL, ROWS * CELL)

const START_LENGTH := 4
const STEP_START := 0.13  # seconds per move
const STEP_MIN := 0.06
const STEP_SPEEDUP := 0.002  # per apple eaten
const APPLE_POINTS := 10
const GOLDEN_POINTS := 50
const GOLDEN_CHANCE := 0.25  # chance of a golden apple showing up after each apple
const GOLDEN_TIME := 6.0
const POP_INTERVAL := 0.045  # death animation: seconds between body parts bursting
const SAVE_PATH := "user://snake.cfg"
const SAVE_VERSION := 2  # campaign progress is discarded when the level set changes shape

const POISON_POINTS := 15  # subtracted when a poison apple is swallowed
const POISON_SHRINK := 3  # body segments lost with it
const MIN_LENGTH := 3  # shrink past this and the snake is done for
const POISON_MOVE := 9.0  # poison apples wander to a new cell this often
const PORTAL_JUMP := CELL * 1.6  # a gap this long between body cells is a portal hop

const BODY_RADIUS := 16.0
const TAIL_RADIUS := 3.5
const SAMPLE_SPACING := 4.0  # body is drawn as circles this far apart along its path
const SHADOW_OFFSET := Vector2(5, 7)
const OPTION_HEIGHT := 54.0
const LEVEL_TILE := Vector2(180, 78)  # one level; worlds run across in rows
const LEVEL_GAP := Vector2(16, 12)
const LEVEL_GRID := Vector2(200, 240)  # top-left of the first world's first level
const WORLD_LABEL_X := 34.0
const LANG_COLS := 5  # the ten languages as two rows of five
const LANG_TILE := Vector2(168, 74)
const LANG_GAP := Vector2(14, 14)
const LANG_GRID := Vector2(52, 300)
const HEADINGS := {">": Vector2i.RIGHT, "<": Vector2i.LEFT, "^": Vector2i.UP, "v": Vector2i.DOWN}
const STICK_PRESS := 0.55  # left stick counts as a direction past this
const STICK_RELEASE := 0.35  # and must come back under this before it counts again

const SNAKE_OUTLINE := Color("1d3310")
const SNAKE_BODY := Color("a4d13a")
const SNAKE_STRIPE := Color("73a322")
const SNAKE_SHINE := Color("d4ef82")
const SNAKE_SPOT := Color("3f6414")
const EYE := Color("f7e463")
const TONGUE := Color("e0245e")
const TEXT := Color("f4f1de")
const INK := Color(0.05, 0.08, 0.04)
const GOLD := Color("ffc93c")
const APPLE_RED := Color("e63946")
const POISON := Color("9b59b6")
const POISON_DARK := Color("5b2c6f")
const BLADE := Color("c3cad4")
const BLADE_DARK := Color("4e5666")
const PORTAL_COLORS := [Color("4dd0e1"), Color("ff8a65")]
const LOCKED := Color("7d8878")

enum State { MENU, LEVELS, PLAY, PAUSED, DYING, OVER, CLEARED, SETTINGS }
enum Mode { CLASSIC, CAMPAIGN }

var state := State.MENU
var resume_state := State.PLAY
var settings_return_state := State.MENU  # where "back" in Settings returns to
var option_index := 0
var mode := Mode.CLASSIC
var language := "en"
var lang_cursor := 0  # highlighted tile on the settings screen

# Gamepad: which kind of input was used last, and the left stick's position.
var using_pad := false
var pad_device := 0
var stick := Vector2.ZERO
var stick_dir := Vector2i.ZERO

var body: Array[Vector2i] = []  # head first
var prev_body: Array[Vector2i] = []  # body before the last move, for smooth sliding
var dir := Vector2i.RIGHT
var prev_dir := Vector2i.RIGHT
var input_queue: Array[Vector2i] = []
var step_time := STEP_START
var step_timer := 0.0

var food := Vector2i.ZERO
var food_age := 0.0
var golden := Vector2i.ZERO
var golden_active := false
var golden_timer := 0.0
var golden_age := 0.0

var score := 0
var best := 0
var apples := 0
var new_best := false

# Campaign. `walls`, `portals`, `blades` and `poison` are empty in Classic, which
# keeps every rule below a no-op there.
var world_index := 0  # which of the five worlds
var stage_index := 0  # which level inside it, so 2-3 is world 1, stage 2
var pick_world := 0  # highlighted tile on the level select screen
var pick_stage := 0
var unlocked := 1  # levels opened up so far, counted straight through the worlds
var level_scores := {}  # flat level number -> best score on it
var level: Dictionary = {}  # the level being played, from Levels.get_level()
var theme: Dictionary = {}  # the current world's palette, from Levels.theme()
var theme_world := -1  # which world's theme is painted, so it repaints only on a change
var demo_world := 0  # world whose colours the menu's self-playing demo wears
var walls := {}  # Vector2i -> true
var portals := {}  # Vector2i -> the Vector2i it comes out of
var blades := []  # [{"cell": Vector2i, "prev": Vector2i, "dir": Vector2i}]
var poison := []  # [{"cell": Vector2i, "age": float}]
var poison_timer := 0.0
var death_cause := "crash"
var golden_eaten := 0
var goal_progress := 0
var time_left := 0.0  # counts down on timed levels
var survived := 0.0
var speedup := STEP_SPEEDUP
var golden_chance := GOLDEN_CHANCE
var clear_time := 0.0  # animation clock for the level-cleared banner

var bulges := []  # swallowed apples travelling down the body, in moves since eaten
var particles := []
var popups := []
var decor := []
var shake := 0.0
var flash := 0.0
var flash_color := Color.WHITE
var clock := 0.0
var pop_timer := 0.0
var pop_count := 0
var over_delay := 0.0
var tongue_timer := 1.0
var tongue_phase := -1.0  # -1 while the tongue is in
var blink_timer := 2.0
var blink := 0.0

# Snake shape for this frame, shared by the shadow and body drawing.
var sample_pos := PackedVector2Array()
var sample_radius := PackedFloat32Array()
var sample_dist := PackedFloat32Array()
var head_pos := Vector2.ZERO
var head_angle := 0.0

var world: Node2D
var board_layer: Node2D
var shadow_layer: Node2D
var game_layer: Node2D
var hud_layer: Node2D
var vignette: GradientTexture2D
var font: Font
var sfx


func _ready() -> void:
	Strings.install()
	font = _make_font()
	sfx = SfxScript.new()
	add_child(sfx)

	# Layers: board, shadows, game objects, HUD. Everything but the HUD shakes.
	world = Node2D.new()
	add_child(world)
	board_layer = _layer(world, _draw_board)
	var shadows := CanvasGroup.new()  # merges overlapping shadows into one see-through shape
	shadows.self_modulate = Color(0, 0, 0, 0.28)
	world.add_child(shadows)
	shadow_layer = _layer(shadows, _draw_shadows)
	game_layer = _layer(world, _draw_game)
	hud_layer = _layer(self, _draw_hud)

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, 0.45))
	gradient.add_point(0.6, Color(0, 0, 0, 0))
	vignette = GradientTexture2D.new()
	vignette.gradient = gradient
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.2, 0.5)

	_apply_theme(0)
	_load_save()
	TranslationServer.set_locale(language)
	_reset_game()


## The UI font, with the two scripts Godot's built-in font has no glyphs for wired in
## as fallbacks: a missing character in the main font falls through to these in order.
func _make_font() -> Font:
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	var fallbacks: Array[Font] = []
	for path in [ARABIC_FONT, CHINESE_FONT]:
		var loaded := FontFile.new()
		if loaded.load_dynamic_font(path) == OK:
			fallbacks.append(loaded)
	variation.fallbacks = fallbacks
	return variation


func _layer(parent: Node, painter: Callable) -> Node2D:
	var layer := Node2D.new()
	parent.add_child(layer)
	layer.draw.connect(painter.bind(layer))
	return layer


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAY:
		_pause()


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	_track_device(event)
	if state == State.SETTINGS:
		_settings_input(event)
		return
	if state == State.LEVELS:
		_levels_input(event)
		return
	if state in [State.MENU, State.PAUSED, State.OVER, State.CLEARED]:
		_options_input(event)
		return
	if state != State.PLAY:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var turn := _pad_direction(event)
		if turn != Vector2i.ZERO:
			_queue_turn(turn)
		elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_START, JOY_BUTTON_BACK]:
			_pause()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_queue_turn(Vector2i.UP)
		KEY_DOWN, KEY_S:
			_queue_turn(Vector2i.DOWN)
		KEY_LEFT, KEY_A:
			_queue_turn(Vector2i.LEFT)
		KEY_RIGHT, KEY_D:
			_queue_turn(Vector2i.RIGHT)
		KEY_P, KEY_ESCAPE:
			_pause()


## Remembers whether a gamepad or the keyboard/mouse was used last, for the on-screen hints
## and for rumble.
func _track_device(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > STICK_PRESS):
		using_pad = true
		pad_device = event.device
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false


## A direction from the D-pad, or from the left stick once it's pushed past the deadzone.
## The stick gives one direction per push: it must return toward the center (or swing to
## another direction) before it counts again.
func _pad_direction(event: InputEvent) -> Vector2i:
	if event is InputEventJoypadButton:
		if not event.pressed:
			return Vector2i.ZERO
		match event.button_index:
			JOY_BUTTON_DPAD_UP:
				return Vector2i.UP
			JOY_BUTTON_DPAD_DOWN:
				return Vector2i.DOWN
			JOY_BUTTON_DPAD_LEFT:
				return Vector2i.LEFT
			JOY_BUTTON_DPAD_RIGHT:
				return Vector2i.RIGHT
		return Vector2i.ZERO
	if not (event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]):
		return Vector2i.ZERO
	if event.axis == JOY_AXIS_LEFT_X:
		stick.x = event.axis_value
	else:
		stick.y = event.axis_value
	if stick.length() < STICK_RELEASE:
		stick_dir = Vector2i.ZERO
		return Vector2i.ZERO
	if stick.length() < STICK_PRESS:
		return Vector2i.ZERO
	var dir_now := Vector2i(int(signf(stick.x)), 0) if absf(stick.x) > absf(stick.y) else Vector2i(0, int(signf(stick.y)))
	if dir_now == stick_dir:
		return Vector2i.ZERO
	stick_dir = dir_now
	return dir_now


func _rumble(weak: float, strong: float, duration: float) -> void:
	if using_pad:
		Input.start_joy_vibration(pad_device, weak, strong, duration)


## Remembers up to two turns, so quick key presses between moves aren't lost.
func _queue_turn(turn: Vector2i) -> void:
	var last: Vector2i = dir if input_queue.is_empty() else input_queue.back()
	if turn != last and turn != -last and input_queue.size() < 2:
		input_queue.append(turn)


func _pause() -> void:
	resume_state = state
	state = State.PAUSED
	option_index = 0
	sfx.play("select")


## Picks from the menu / pause / game over options with the keyboard or the mouse.
func _options_input(event: InputEvent) -> void:
	var options := _options()
	if event is InputEventMouseMotion:
		var hovered := _option_at(event.position)
		if hovered >= 0 and hovered != option_index:
			option_index = hovered
			sfx.play("select")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _option_at(event.position)
		if clicked >= 0:
			_choose(options[clicked])
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var move := _pad_direction(event)
		if move.y != 0:
			option_index = posmod(option_index + move.y, options.size())
			sfx.play("select")
		elif event is InputEventJoypadButton and event.pressed:
			match event.button_index:
				JOY_BUTTON_A:
					_choose(options[option_index])
				JOY_BUTTON_START:
					_choose("resume" if state == State.PAUSED else options[option_index])
				JOY_BUTTON_B:
					if state == State.PAUSED:
						_choose("resume")
					elif state == State.CLEARED:
						_choose("level_select")
					elif state == State.OVER:
						_choose("exit_menu")
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_W, KEY_UP:
				option_index = posmod(option_index - 1, options.size())
				sfx.play("select")
			KEY_S, KEY_DOWN:
				option_index = posmod(option_index + 1, options.size())
				sfx.play("select")
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_choose(options[option_index])
			KEY_P:
				if state == State.PAUSED:
					_choose("resume")
			KEY_ESCAPE:
				if state == State.CLEARED:
					_choose("level_select")
				elif state != State.MENU:
					_choose("exit_menu")


## Each entry is both the dispatch key for _choose() and a tr() key for its label.
func _options() -> Array:
	match state:
		State.PAUSED:
			if mode == Mode.CAMPAIGN:
				return ["resume", "restart", "level_select", "exit_menu"]
			return ["resume", "restart", "exit_menu"]
		State.OVER:
			if mode == Mode.CAMPAIGN:
				return ["retry_level", "level_select", "exit_menu"]
			return ["play_again", "exit_menu"]
		State.CLEARED:
			if _flat() + 1 < Levels.total():
				return ["next_level", "replay_level", "level_select"]
			return ["level_select", "exit_menu"]
	return ["campaign", "classic", "settings"]


func _options_top() -> float:
	match state:
		State.PAUSED:
			return 380.0
		State.OVER:
			return 440.0
		State.CLEARED:
			return 480.0
	return 470.0


func _option_rect(index: int) -> Rect2:
	return Rect2(SCREEN.x / 2.0 - 150.0, _options_top() + index * OPTION_HEIGHT, 300.0, OPTION_HEIGHT - 10.0)


func _option_at(point: Vector2) -> int:
	for i in _options().size():
		if _option_rect(i).has_point(point):
			return i
	return -1


func _choose(option: String) -> void:
	match option:
		"classic":
			mode = Mode.CLASSIC
			_start_game()
		"campaign":
			_open_levels(Levels.split(unlocked - 1))
		"settings":
			_open_settings()
		"restart", "play_again", "retry_level", "replay_level":
			_start_game()
		"next_level":
			_goto(_flat() + 1)
			_start_game()
		"resume":
			state = resume_state
			sfx.play("select")
		"level_select":
			_open_levels(Vector2i(world_index, stage_index))
		"exit_menu":
			mode = Mode.CLASSIC
			demo_world = 0
			_reset_game()
			state = State.MENU
			option_index = 0
			sfx.play("select")


## The flat number of the level being played, which is what progress is saved against.
func _flat() -> int:
	return Levels.flat(world_index, stage_index)


func _goto(flat: int) -> void:
	var at := Levels.split(flat)
	world_index = at.x
	stage_index = at.y


## Opens the level select with `at` highlighted. The board behind it wears the colours
## of the furthest world reached, never of one still locked.
func _open_levels(at: Vector2i) -> void:
	pick_world = at.x
	pick_stage = at.y
	mode = Mode.CLASSIC  # the demo behind the grid runs the open board
	demo_world = Levels.split(unlocked - 1).x
	_reset_game()
	state = State.LEVELS
	sfx.play("select")


## Starts (or restarts) the current mode's game from the menus.
func _start_game() -> void:
	_reset_game()
	particles.clear()
	state = State.PLAY
	sfx.play("start")


# --- Level select ------------------------------------------------------------

func _level_tile_rect(world: int, stage: int) -> Rect2:
	var step := LEVEL_TILE + LEVEL_GAP
	return Rect2(LEVEL_GRID + Vector2(stage, world) * step, LEVEL_TILE)


func _level_at(point: Vector2) -> Vector2i:
	for world in Levels.world_count():
		for stage in Levels.stage_count(world):
			if _level_tile_rect(world, stage).has_point(point):
				return Vector2i(world, stage)
	return Vector2i(-1, -1)


## Moves the highlight around the grid: left and right along a world's levels, up and
## down between worlds. Both wrap.
func _move_cursor(step: Vector2i) -> void:
	var worlds := Levels.world_count()
	if step.y != 0:
		pick_world = posmod(pick_world + step.y, worlds)
		pick_stage = mini(pick_stage, Levels.stage_count(pick_world) - 1)
	if step.x != 0:
		pick_stage = posmod(pick_stage + step.x, Levels.stage_count(pick_world))
	sfx.play("select")


## True once a level has been opened up. Locked ones are not just unplayable: their
## name, goal and hint stay hidden until you get there.
func _is_open(world: int, stage: int) -> bool:
	return Levels.flat(world, stage) < unlocked


func _pick_level() -> void:
	if not _is_open(pick_world, pick_stage):
		sfx.play("locked")
		shake = maxf(shake, 0.25)
		return
	mode = Mode.CAMPAIGN
	world_index = pick_world
	stage_index = pick_stage
	_start_game()


# --- Settings ------------------------------------------------------------------

func _lang_tile_rect(index: int) -> Rect2:
	var col := index % LANG_COLS
	var row := index / LANG_COLS
	return Rect2(LANG_GRID + Vector2(col, row) * (LANG_TILE + LANG_GAP), LANG_TILE)


func _lang_at(point: Vector2) -> int:
	for i in Strings.LANGUAGES.size():
		if _lang_tile_rect(i).has_point(point):
			return i
	return -1


func _language_index(code: String) -> int:
	for i in Strings.LANGUAGES.size():
		if Strings.LANGUAGES[i][0] == code:
			return i
	return 0


## Moves the highlight around the two-row language grid, wrapping at both edges.
func _move_lang_cursor(step: Vector2i) -> void:
	var total := Strings.LANGUAGES.size()
	var rows := int(ceil(float(total) / LANG_COLS))
	var col := lang_cursor % LANG_COLS
	var row := lang_cursor / LANG_COLS
	if step.x != 0:
		col = posmod(col + step.x, LANG_COLS)
	if step.y != 0:
		row = posmod(row + step.y, rows)
	lang_cursor = mini(row * LANG_COLS + col, total - 1)
	sfx.play("select")


## Opens Settings on top of whichever menu-like screen called it; "back" returns there.
func _open_settings() -> void:
	settings_return_state = state
	lang_cursor = _language_index(language)
	state = State.SETTINGS
	sfx.play("select")


func _close_settings() -> void:
	state = settings_return_state
	sfx.play("select")


## Switches the game's language immediately and saves it.
func _pick_language(index: int) -> void:
	lang_cursor = index
	language = Strings.LANGUAGES[index][0]
	TranslationServer.set_locale(language)
	_save()
	sfx.play("select")


func _settings_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := _lang_at(event.position)
		if hovered >= 0 and hovered != lang_cursor:
			lang_cursor = hovered
			sfx.play("select")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _lang_at(event.position)
		if clicked >= 0:
			_pick_language(clicked)
		elif _settings_back_rect().has_point(event.position):
			_close_settings()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var move := _pad_direction(event)
		if move != Vector2i.ZERO:
			_move_lang_cursor(move)
		elif event is InputEventJoypadButton and event.pressed:
			match event.button_index:
				JOY_BUTTON_A, JOY_BUTTON_START:
					_pick_language(lang_cursor)
				JOY_BUTTON_B:
					_close_settings()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_W, KEY_UP:
				_move_lang_cursor(Vector2i.UP)
			KEY_S, KEY_DOWN:
				_move_lang_cursor(Vector2i.DOWN)
			KEY_A, KEY_LEFT:
				_move_lang_cursor(Vector2i.LEFT)
			KEY_D, KEY_RIGHT:
				_move_lang_cursor(Vector2i.RIGHT)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_pick_language(lang_cursor)
			KEY_ESCAPE:
				_close_settings()


func _levels_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := _level_at(event.position)
		if hovered.x >= 0 and (hovered.x != pick_world or hovered.y != pick_stage):
			pick_world = hovered.x
			pick_stage = hovered.y
			sfx.play("select")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _level_at(event.position)
		if clicked.x >= 0:
			pick_world = clicked.x
			pick_stage = clicked.y
			_pick_level()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var move := _pad_direction(event)
		if move != Vector2i.ZERO:
			_move_cursor(move)
		elif event is InputEventJoypadButton and event.pressed:
			match event.button_index:
				JOY_BUTTON_A, JOY_BUTTON_START:
					_pick_level()
				JOY_BUTTON_B:
					_choose("exit_menu")
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_W, KEY_UP:
				_move_cursor(Vector2i.UP)
			KEY_S, KEY_DOWN:
				_move_cursor(Vector2i.DOWN)
			KEY_A, KEY_LEFT:
				_move_cursor(Vector2i.LEFT)
			KEY_D, KEY_RIGHT:
				_move_cursor(Vector2i.RIGHT)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_pick_level()
			KEY_ESCAPE:
				_choose("exit_menu")


# --- Game logic --------------------------------------------------------------

## Repaints the board in a world's colours. The scatter is rebuilt from a seed tied
## to the world, so each one looks the same every time you come back to it.
func _apply_theme(world: int) -> void:
	if world == theme_world:
		return
	theme_world = world
	theme = Levels.theme(world)
	_make_decor()
	if board_layer:
		board_layer.queue_redraw()


func _reset_game() -> void:
	walls.clear()
	portals.clear()
	blades.clear()
	poison.clear()
	level = {}
	step_time = STEP_START
	speedup = STEP_SPEEDUP
	golden_chance = GOLDEN_CHANCE
	time_left = 0.0
	var start := Vector2i(6, int(ROWS / 2.0))
	var heading := Vector2i.RIGHT
	_apply_theme(world_index if mode == Mode.CAMPAIGN else demo_world)
	if mode == Mode.CAMPAIGN:
		level = Levels.get_level(world_index, stage_index)
		var spawn := _load_layout(level.rows)
		start = spawn[0]
		heading = spawn[1]
		step_time = level.step
		speedup = level.speedup
		golden_chance = level.golden
		time_left = level.time

	body.clear()
	for i in START_LENGTH:
		body.append(start - heading * i)
	prev_body = body.duplicate()
	dir = heading
	prev_dir = dir
	input_queue.clear()
	step_timer = 0.0
	score = 0
	apples = 0
	golden_eaten = 0
	goal_progress = 0
	survived = 0.0
	clear_time = 0.0
	death_cause = "crash"
	new_best = false
	pop_count = 0
	bulges.clear()
	popups.clear()
	golden_active = false
	food = _free_cell()
	food_age = 0.0
	poison_timer = POISON_MOVE
	for i in int(level.get("poison", 0)):
		_spawn_poison()
	board_layer.queue_redraw()


## Reads a level's character grid into walls, blades and portals, and returns the
## snake's start cell and its heading.
func _load_layout(rows: Array) -> Array:
	var start := Vector2i(6, int(ROWS / 2.0))
	var heading := Vector2i.RIGHT
	var portal_ends := {}
	for y in mini(rows.size(), ROWS):
		var line: String = rows[y]
		for x in mini(line.length(), COLS):
			var cell := Vector2i(x, y)
			var mark := line[x]
			if mark == "#":
				walls[cell] = true
			elif HEADINGS.has(mark):
				start = cell
				heading = HEADINGS[mark]
			elif mark == "H" or mark == "V":
				blades.append({
					"cell": cell,
					"prev": cell,
					"dir": Vector2i.RIGHT if mark == "H" else Vector2i.DOWN,
				})
			elif mark == "A" or mark == "B":
				if portal_ends.has(mark):
					var other: Vector2i = portal_ends[mark]
					portals[cell] = other
					portals[other] = cell
				else:
					portal_ends[mark] = cell
	return [start, heading]


func _process(delta: float) -> void:
	clock += delta
	shake = maxf(shake - delta * 2.0, 0.0)
	flash = maxf(flash - delta * 2.5, 0.0)
	world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 12.0

	if state == State.PLAY or _demo_running():
		_advance(delta)
	elif state == State.DYING:
		_update_dying(delta)
	elif state == State.CLEARED:
		clear_time += delta
	_update_effects(delta)
	_build_samples()

	shadow_layer.queue_redraw()
	game_layer.queue_redraw()
	hud_layer.queue_redraw()


func _advance(delta: float) -> void:
	if body.is_empty():  # nothing to steer: the death animation is still clearing up
		return
	food_age += delta
	if golden_active:
		golden_age += delta
		golden_timer -= delta
		if randf() < delta * 10.0:
			var sparkle := _cell_center(golden) + Vector2(randf_range(-16, 16), randf_range(-16, 16))
			_burst(sparkle, Color(1, 0.95, 0.7), 1, 30.0)
		if golden_timer <= 0.0:
			golden_active = false
			_burst(_cell_center(golden), GOLD, 12, 120.0)
	_update_face(delta)
	if state == State.PLAY and mode == Mode.CAMPAIGN:
		_advance_campaign(delta)
		if state != State.PLAY:
			return

	step_timer += delta
	while step_timer >= step_time and (state == State.PLAY or _demo_running()):
		step_timer -= step_time
		if state != State.PLAY:
			_autopilot()
		_step()


## True on the plain menu / level-select screens, and on Settings when opened from one
## of them - the self-playing demo behind those screens keeps going either way.
func _demo_running() -> bool:
	if state in [State.MENU, State.LEVELS]:
		return true
	return state == State.SETTINGS and settings_return_state in [State.MENU, State.LEVELS]


## Campaign-only clocks: the countdown, the wandering poison, and the goal check.
func _advance_campaign(delta: float) -> void:
	survived += delta
	for rot in poison:
		rot.age += delta
	if not poison.is_empty():
		poison_timer -= delta
		if poison_timer <= 0.0:
			_move_poison()
	if level.time > 0.0:
		time_left = maxf(time_left - delta, 0.0)
		if time_left <= 0.0:
			_die("time")
			return
	_check_goal()


## Updates the goal's progress and clears the level once it is met.
func _check_goal() -> void:
	var goal: Dictionary = level.goal
	match goal.kind:
		"apples":
			goal_progress = apples
		"golden":
			goal_progress = golden_eaten
		"length":
			goal_progress = body.size()
		"survive":
			goal_progress = mini(int(survived), goal.count)
	if goal_progress >= goal.count:
		_clear_level()


func _clear_level() -> void:
	state = State.CLEARED
	clear_time = 0.0
	option_index = 0
	flash = 0.5
	flash_color = Color(0.7, 1.0, 0.6)
	# -1 for a level never cleared, so a first clear always banks a score - even a
	# zero one on a survival level, which is what marks the level as done.
	var flat := _flat()
	new_best = score > int(level_scores.get(flat, -1))
	if new_best:
		level_scores[flat] = score
	if flat + 1 >= unlocked:
		unlocked = mini(flat + 2, Levels.total())
	_save()
	_burst(head_pos, GOLD, 26, 260.0)
	_burst(head_pos, SNAKE_SHINE, 14, 160.0)
	sfx.play("clear")
	_rumble(0.3, 0.6, 0.35)


func _step() -> void:
	prev_dir = dir
	if not input_queue.is_empty():
		dir = input_queue.pop_front()
	var head := body[0] + dir
	if not _inside(head) or walls.has(head):
		_die()
		return
	# A portal drops the head out of its twin; the body follows cell by cell.
	var warped := portals.has(head)
	if warped:
		head = portals[head]
	var eats_food := head == food
	var eats_golden := golden_active and head == golden
	var grows := eats_food or eats_golden
	# The tail moves out of the way this step, unless the snake grows.
	var solid := body.slice(0, body.size() if grows else body.size() - 1)
	if solid.has(head):
		_die()
		return

	prev_body = body.duplicate()
	body.push_front(head)
	if grows:
		prev_body.append(prev_body.back())
	else:
		body.pop_back()
	if warped:
		# Slide the head out of the far portal instead of across the whole board.
		prev_body[0] = head - dir

	for i in bulges.size():
		bulges[i] += 1
	bulges = bulges.filter(func(b: int) -> bool: return b < body.size())

	if eats_food:
		_eat(head, APPLE_POINTS, APPLE_RED)
		food = _free_cell()
		food_age = 0.0
		if not golden_active and randf() < golden_chance:
			golden = _free_cell()
			golden_active = true
			golden_timer = GOLDEN_TIME
			golden_age = 0.0
	if eats_golden:
		_eat(head, GOLDEN_POINTS, GOLD)
		golden_active = false
		golden_eaten += 1
		flash = 0.4
		flash_color = Color(1, 0.9, 0.5)

	var rotten := _poison_at(head)
	if rotten >= 0:
		_eat_poison(rotten)
	if state == State.PLAY and not blades.is_empty():
		_advance_blades()


func _eat(cell: Vector2i, points: int, color: Color) -> void:
	var pos := _cell_center(cell)
	bulges.append(0)
	step_time = maxf(step_time - speedup, STEP_MIN)
	_burst(pos, color, 18, 240.0)
	_burst(pos, SNAKE_SHINE, 6, 120.0)
	if state == State.PLAY:
		score += points
		apples += 1
		popups.append({"pos": pos, "text": "+%d" % points, "color": color, "life": 0.9})
		sfx.play("golden" if points == GOLDEN_POINTS else "eat")
		if points == GOLDEN_POINTS:
			_rumble(0.4, 0.0, 0.12)


# --- Poison apples -----------------------------------------------------------

func _poison_at(cell: Vector2i) -> int:
	for i in poison.size():
		if poison[i].cell == cell:
			return i
	return -1


## Puts one more poison apple on the board, well clear of the head.
func _spawn_poison() -> void:
	var cell := _free_cell(5)
	if cell.x >= 0:
		poison.append({"cell": cell, "age": 0.0})


## Poison does not sit still forever: now and then one rots away and another shows up.
func _move_poison() -> void:
	poison_timer = POISON_MOVE
	var index := randi() % poison.size()
	_burst(_cell_center(poison[index].cell), POISON_DARK, 8, 90.0)
	poison.remove_at(index)
	_spawn_poison()


## Swallowing rot costs points and three segments - and kills outright if there
## are not three to spare.
func _eat_poison(index: int) -> void:
	var pos := _cell_center(poison[index].cell)
	poison.remove_at(index)
	_burst(pos, POISON, 20, 220.0)
	_burst(pos, POISON_DARK, 10, 120.0)
	score = maxi(score - POISON_POINTS, 0)
	popups.append({"pos": pos, "text": "-%d" % POISON_POINTS, "color": POISON, "life": 0.9})
	flash = 0.45
	flash_color = POISON
	shake = maxf(shake, 0.55)
	sfx.play("poison")
	_rumble(0.7, 0.4, 0.25)

	var keep := body.size() - POISON_SHRINK
	if keep < MIN_LENGTH:
		_die("poison")
		return
	for i in range(keep, body.size()):
		_burst(_cell_center(body[i]), POISON, 5, 110.0)
	body.resize(keep)
	prev_body.resize(keep)
	bulges = bulges.filter(func(b: int) -> bool: return b < body.size())
	_spawn_poison()


# --- Blades ------------------------------------------------------------------

## Blades slide one cell per snake step, turning around at stone and at the fence.
## They only threaten the head - the body passes underneath them.
func _advance_blades() -> void:
	for blade in blades:
		var ahead: Vector2i = blade.cell + blade.dir
		if not _inside(ahead) or walls.has(ahead):
			blade.dir = -blade.dir
			ahead = blade.cell + blade.dir
			if not _inside(ahead) or walls.has(ahead):
				ahead = blade.cell  # boxed in on both sides: stay put
		blade.prev = blade.cell
		blade.cell = ahead
	var came_from: Vector2i = body[1] if body.size() > 1 else body[0]
	for blade in blades:
		# Either the blade caught the head, or the two swapped cells passing through.
		if blade.cell == body[0] or (blade.cell == came_from and blade.prev == body[0]):
			_die("blade")
			return


# --- Dying -------------------------------------------------------------------

func _die(cause := "crash") -> void:
	if _demo_running():
		_reset_game()
		return
	state = State.DYING
	death_cause = cause
	prev_body = body.duplicate()
	shake = 1.0
	flash = 0.6
	match cause:
		"poison":
			flash_color = POISON
		"time":
			flash_color = GOLD
		_:
			flash_color = Color(1, 0.15, 0.15)
	pop_timer = 0.35  # short freeze before the body bursts
	over_delay = 0.8
	sfx.play("hit")
	_rumble(0.6, 1.0, 0.4)
	if mode == Mode.CLASSIC and score > best:
		best = score
		new_best = true
		_save()


func _update_dying(delta: float) -> void:
	pop_timer -= delta
	if not body.is_empty():
		if pop_timer <= 0.0:
			pop_timer = POP_INTERVAL
			var cell: Vector2i = body.pop_front()
			prev_body = body.duplicate()
			pop_count += 1
			_burst(_cell_center(cell), SNAKE_BODY, 9, 170.0)
			_burst(_cell_center(cell), SNAKE_SPOT, 4, 110.0)
			shake = maxf(shake, 0.35)
			sfx.play("pop")
	else:
		over_delay -= delta
		if over_delay <= 0.0:
			state = State.OVER
			option_index = 0
			sfx.play("over")


## Menu demo: heads for the nearest apple while avoiding walls, itself and dead ends.
func _autopilot() -> void:
	var target := golden if golden_active else food
	var choice := dir
	var lowest := INF
	for turn in [dir, Vector2i(dir.y, -dir.x), Vector2i(-dir.y, dir.x)]:
		var next: Vector2i = body[0] + turn
		if not _inside(next) or walls.has(next) or body.slice(0, body.size() - 1).has(next):
			continue
		var exits := 0
		for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if _inside(next + side) and not walls.has(next + side) and not body.has(next + side):
				exits += 1
		var cost := absi(next.x - target.x) + absi(next.y - target.y) + randf() * 0.5
		if exits == 0:
			cost += 100.0
		if cost < lowest:
			lowest = cost
			choice = turn
	input_queue = [choice]


func _update_face(delta: float) -> void:
	blink = maxf(blink - delta, 0.0)
	blink_timer -= delta
	if blink_timer <= 0.0:
		blink = 0.13
		blink_timer = randf_range(2.0, 5.0)
	if tongue_phase >= 0.0:
		tongue_phase += delta / 0.35
		if tongue_phase >= 1.0:
			tongue_phase = -1.0
	else:
		tongue_timer -= delta
		if tongue_timer <= 0.0:
			tongue_phase = 0.0
			var near := Vector2(body[0]).distance_to(Vector2(food)) < 4.0
			tongue_timer = randf_range(0.15, 0.4) if near else randf_range(1.2, 3.0)


func _update_effects(delta: float) -> void:
	for p in particles:
		p["life"] -= delta
		p["vel"] *= exp(-3.0 * delta)
		p["pos"] += p["vel"] * delta
	particles = particles.filter(func(p: Dictionary) -> bool: return p["life"] > 0.0)
	for popup in popups:
		popup["life"] -= delta
		popup["pos"] += Vector2(0, -50) * delta
	popups = popups.filter(func(p: Dictionary) -> bool: return p["life"] > 0.0)


func _burst(pos: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		var life := randf_range(0.35, 0.8)
		particles.append({
			"pos": pos,
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * speed,
			"life": life,
			"max": life,
			"color": color,
			"size": randf_range(2.5, 5.5),
		})


## A random empty cell. `clearance` keeps it that many cells away from the head, so
## rot never lands right under the snake; if nowhere is that far off, anywhere free
## will do. The body goes into a lookup first: at forty-odd segments, scanning it for
## every one of the board's cells is slow enough to show as a stutter.
func _free_cell(clearance := 0) -> Vector2i:
	# Everything already on the board goes into one lookup first. At forty-odd segments,
	# rescanning the body for each of the board's cells is slow enough to stutter.
	var taken := {}
	for cell in body:
		taken[cell] = true
	for rot in poison:
		taken[rot.cell] = true
	taken[food] = true
	if golden_active:
		taken[golden] = true

	var cells: Array[Vector2i] = []
	var close: Array[Vector2i] = []
	var head: Vector2i = body[0] if not body.is_empty() else Vector2i(-100, -100)
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if taken.has(cell) or walls.has(cell) or portals.has(cell):
				continue
			if clearance > 0 and absi(cell.x - head.x) + absi(cell.y - head.y) < clearance:
				close.append(cell)
			else:
				cells.append(cell)
	if not cells.is_empty():
		return cells.pick_random()
	# Nowhere with room to spare, so take whichever free cell is furthest from the head.
	var furthest := Vector2i(-100, -100)
	var best := -1
	for cell in close:
		var away := absi(cell.x - head.x) + absi(cell.y - head.y)
		if away > best:
			best = away
			furthest = cell
	return furthest


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS


func _cell_center(cell: Vector2i) -> Vector2:
	return BOARD_POS + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		language = Strings.system_language()
		return
	best = config.get_value("score", "best", 0)
	language = str(config.get_value("settings", "language", Strings.system_language()))
	if _language_index(language) == 0 and language != "en":
		language = "en"  # a language from an older or unrecognized save
	if int(config.get_value("campaign", "version", 0)) != SAVE_VERSION:
		return  # campaign progress from an older, differently numbered set of levels
	unlocked = clampi(config.get_value("campaign", "unlocked", 1), 1, Levels.total())
	level_scores = config.get_value("campaign", "scores", {})


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("score", "best", best)
	config.set_value("campaign", "version", SAVE_VERSION)
	config.set_value("campaign", "unlocked", unlocked)
	config.set_value("campaign", "scores", level_scores)
	config.set_value("settings", "language", language)
	config.save(SAVE_PATH)


# --- Snake shape -------------------------------------------------------------

## Samples the snake's path from head to tail: the head slides between cells and the
## body follows the cell centers, so it bends around corners like a real snake.
func _build_samples() -> void:
	sample_pos.clear()
	sample_radius.clear()
	sample_dist.clear()
	if body.is_empty():
		return
	var t := _step_t()
	var n := body.size()
	var path := PackedVector2Array()
	path.append(_cell_center(prev_body[0]).lerp(_cell_center(body[0]), t))
	for i in range(1, n):
		path.append(_cell_center(body[i]))
	path.append(_cell_center(prev_body[n - 1]).lerp(_cell_center(body[n - 1]), t))
	head_pos = path[0]
	head_angle = lerp_angle(Vector2(prev_dir).angle(), Vector2(dir).angle(), minf(t * 2.5, 1.0))

	# A portal leaves a long gap between two body cells. It still counts as one cell of
	# length, so the taper stays even, but nothing is drawn across it.
	var total := 0.0
	for i in range(1, path.size()):
		var span := path[i - 1].distance_to(path[i])
		total += CELL if span > PORTAL_JUMP else span

	_add_sample(path[0], 0.0, total, t)
	var walked := 0.0
	var next_at := SAMPLE_SPACING
	for i in range(1, path.size()):
		var span := path[i - 1].distance_to(path[i])
		if span > PORTAL_JUMP:
			walked += CELL
			while next_at < walked:
				next_at += SAMPLE_SPACING
			continue
		while next_at <= walked + span and span > 0.001:
			_add_sample(path[i - 1].lerp(path[i], (next_at - walked) / span), next_at, total, t)
			next_at += SAMPLE_SPACING
		walked += span


## One circle of the body, `dist` along it from the head, thinning toward the tail and
## bulging around each swallowed apple.
func _add_sample(pos: Vector2, dist: float, total: float, t: float) -> void:
	var radius := lerpf(BODY_RADIUS, TAIL_RADIUS, pow(dist / maxf(total, 1.0), 2.6))
	for bulge in bulges:
		radius += 5.0 * exp(-pow((dist - (bulge + t) * CELL) / 14.0, 2.0))
	sample_pos.append(pos)
	sample_radius.append(radius)
	sample_dist.append(dist)


func _step_t() -> float:
	return clampf(step_timer / step_time, 0.0, 1.0)


# --- Drawing -----------------------------------------------------------------

func _draw_board(c: CanvasItem) -> void:
	var board := Rect2(BOARD_POS, BOARD_SIZE)
	var frame: Array = theme.frame
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), theme.back)
	# Border, outside in, with a stud in each corner.
	c.draw_rect(board.grow(16), frame[0])
	c.draw_rect(board.grow(13), frame[1])
	c.draw_rect(board.grow(7), frame[2])
	c.draw_rect(board.grow(3), frame[3])
	for corner in [board.position, Vector2(board.end.x, board.position.y), board.end, Vector2(board.position.x, board.end.y)]:
		c.draw_circle(corner + (board.get_center() - corner).sign() * -8.0, 3.0, frame[4], true, -1.0, true)

	var light: Color = theme.light
	var dark: Color = theme.dark
	for y in ROWS:
		for x in COLS:
			var color := light if (x + y) % 2 == 0 else dark
			c.draw_rect(Rect2(BOARD_POS + Vector2(x, y) * CELL, Vector2(CELL, CELL)), color)

	for item in decor:
		var pos: Vector2 = item["pos"]
		if walls.has(Vector2i((pos - BOARD_POS) / CELL)):
			continue
		_draw_scatter(c, item)

	_draw_walls(c)
	c.draw_texture_rect(vignette, board, false)


## One piece of ground scatter. Which kinds a world uses, and in what colours, comes
## from its theme: grass and flowers up top, cracks, embers and bone further down.
func _draw_scatter(c: CanvasItem, item: Dictionary) -> void:
	var pos: Vector2 = item["pos"]
	var wobble: float = item["seed"]
	match item["kind"]:
		"tuft":
			var blade: Color = theme.tuft
			c.draw_line(pos, pos + Vector2(-4, -8), blade, 2.0, true)
			c.draw_line(pos, pos + Vector2(0, -11), blade, 2.0, true)
			c.draw_line(pos, pos + Vector2(4, -8), blade, 2.0, true)
		"flower":
			for i in 5:
				c.draw_circle(pos + Vector2.from_angle(i * TAU / 5.0) * 3.2, 2.4, item["color"], true, -1.0, true)
			c.draw_circle(pos, 1.8, theme.ember, true, -1.0, true)
		"pebble":
			var stone: Array = theme.pebble
			c.draw_set_transform(pos, 0.0, Vector2(1.4, 1.0))
			c.draw_circle(Vector2.ZERO, 3.0, stone[0], true, -1.0, true)
			c.draw_circle(Vector2(-0.8, -0.8), 1.4, stone[1], true, -1.0, true)
			c.draw_set_transform(Vector2.ZERO)
		"crack":
			var split: Color = theme.crack
			var lean := (wobble - 0.5) * 8.0
			c.draw_line(pos + Vector2(-7, 2), pos + Vector2(-1, lean * 0.4), split, 1.6, true)
			c.draw_line(pos + Vector2(-1, lean * 0.4), pos + Vector2(4, -2), split, 1.6, true)
			c.draw_line(pos + Vector2(4, -2), pos + Vector2(8, lean * 0.3 + 2), split, 1.4, true)
		"ember":
			# Embers breathe, so the hot worlds are never quite still.
			var glow: Color = theme.ember
			var beat := 0.55 + 0.45 * sin(clock * 2.2 + wobble * TAU)
			c.draw_circle(pos, 6.0 * beat, Color(glow, 0.16), true, -1.0, true)
			c.draw_circle(pos, 2.6 * beat, Color(glow, 0.85), true, -1.0, true)
			c.draw_circle(pos, 1.2 * beat, Color(1, 1, 1, 0.7 * beat), true, -1.0, true)
		"bone":
			var pale: Color = theme.bone
			var tilt := (wobble - 0.5) * 1.4
			c.draw_set_transform(pos, tilt)
			c.draw_line(Vector2(-6, 0), Vector2(6, 0), pale, 2.0, true)
			for end in [-6.0, 6.0]:
				c.draw_circle(Vector2(end, -1.6), 1.7, pale, true, -1.0, true)
				c.draw_circle(Vector2(end, 1.6), 1.7, pale, true, -1.0, true)
			c.draw_set_transform(Vector2.ZERO)


## Walls. Each cell is a slab with its top edge left bright; the shaded lip is only
## drawn where no wall sits below, so a run of them reads as one solid mass.
func _draw_walls(c: CanvasItem) -> void:
	var stone: Array = theme.wall
	var edge: Color = stone[0]
	var face: Color = stone[1]
	var top: Color = stone[2]
	for wall in walls:
		var cell: Vector2i = wall
		var at := BOARD_POS + Vector2(cell) * CELL
		c.draw_rect(Rect2(at, Vector2(CELL, CELL)), edge)
		c.draw_rect(Rect2(at + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), face)
		c.draw_rect(Rect2(at + Vector2(2, 2), Vector2(CELL - 4, 7)), top)
		if not walls.has(cell + Vector2i.DOWN):
			c.draw_rect(Rect2(at + Vector2(2, CELL - 9), Vector2(CELL - 4, 7)), edge.lerp(face, 0.35))
		# A couple of fixed speckles so the stone is not a flat slab.
		var grain := (cell.x * 7 + cell.y * 13) % 5
		c.draw_circle(at + Vector2(10 + grain * 4, 22.0 + grain), 2.0, top.lerp(face, 0.5), true, -1.0, true)
		c.draw_circle(at + Vector2(28 - grain * 3, 30.0 - grain), 1.5, edge.lerp(face, 0.5), true, -1.0, true)


## Scatters the current world's ground detail. The seed is tied to the world, so a
## world looks the same every time you come back to it.
func _make_decor() -> void:
	decor.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + theme_world * 31
	var table: Array = theme.decor
	var flowers: Array = theme.flowers
	for i in 55:
		var roll := rng.randf()
		var kind: String = table[table.size() - 1][0]
		for entry in table:
			if roll <= float(entry[1]):
				kind = entry[0]
				break
		decor.append({
			"pos": BOARD_POS + Vector2(rng.randf_range(8, BOARD_SIZE.x - 8), rng.randf_range(12, BOARD_SIZE.y - 8)),
			"kind": kind,
			"color": flowers[rng.randi() % flowers.size()],
			"seed": rng.randf(),
		})


func _draw_shadows(c: CanvasItem) -> void:
	for pos in [food, golden] if golden_active else [food]:
		c.draw_set_transform(_cell_center(pos) + Vector2(3, 15), 0.0, Vector2(1.2, 0.45))
		c.draw_circle(Vector2.ZERO, 13.0 * _pop_scale(food_age if pos == food else golden_age), Color.BLACK)
	for rot in poison:
		c.draw_set_transform(_cell_center(rot.cell) + Vector2(3, 15), 0.0, Vector2(1.2, 0.45))
		c.draw_circle(Vector2.ZERO, 12.0 * _pop_scale(rot.age), Color.BLACK)
	for blade in blades:
		c.draw_set_transform(_blade_pos(blade) + Vector2(4, 16), 0.0, Vector2(1.2, 0.5))
		c.draw_circle(Vector2.ZERO, 15.0, Color.BLACK)
	c.draw_set_transform(Vector2.ZERO)
	for wall in walls:
		c.draw_rect(Rect2(BOARD_POS + Vector2(wall) * CELL + SHADOW_OFFSET, Vector2(CELL, CELL)), Color.BLACK)
	for i in sample_pos.size():
		c.draw_circle(sample_pos[i] + SHADOW_OFFSET, sample_radius[i] + 2.0, Color.BLACK)
	if _has_head():
		c.draw_set_transform(head_pos + SHADOW_OFFSET, head_angle, Vector2(1.3, 1.0))
		c.draw_circle(Vector2(3, 0), 17.5, Color.BLACK)
		c.draw_set_transform(Vector2.ZERO)


func _draw_game(c: CanvasItem) -> void:
	_draw_portals(c)
	if state != State.OVER:
		_draw_apple(c, food, food_age, false)
	if golden_active and (golden_timer > 1.5 or fmod(clock, 0.2) < 0.12):
		_draw_apple(c, golden, golden_age, true)
	for rot in poison:
		_draw_poison(c, rot)
	_draw_snake(c)
	if _has_head():
		_draw_head(c)
	_draw_blades(c)

	for p in particles:
		var fade: float = p["life"] / p["max"]
		c.draw_circle(p["pos"], p["size"] * fade, Color(p["color"], minf(fade * 1.5, 1.0)), true, -1.0, true)
	for popup in popups:
		var fade: float = clampf(popup["life"] / 0.5, 0.0, 1.0)
		_text(c, popup["text"], popup["pos"], 26, Color(popup["color"], fade), 6)


func _draw_snake(c: CanvasItem) -> void:
	var count := sample_pos.size()
	if count == 0:
		return
	# Tail to head, so the parts nearer the head are on top.
	for i in range(count - 1, -1, -1):
		c.draw_circle(sample_pos[i], sample_radius[i] + 2.5, SNAKE_OUTLINE, true, -1.0, true)
	for i in range(count - 1, -1, -1):
		var band := smoothstep(0.55, 0.95, 0.5 + 0.5 * sin(sample_dist[i] * 0.22))
		c.draw_circle(sample_pos[i], sample_radius[i], SNAKE_BODY.lerp(SNAKE_STRIPE, band * 0.8), true, -1.0, true)
	for i in range(count - 1, -1, -1):
		var r := sample_radius[i]
		c.draw_circle(sample_pos[i] + Vector2(-0.3, -0.35) * r, r * 0.28, SNAKE_SHINE, true, -1.0, true)
	# Diamond-shaped spots along the back.
	for i in range(1, count - 1):
		if i % 6 != 3:
			continue
		var along := sample_pos[i - 1] - sample_pos[i + 1]
		if along.length() < 0.01:
			continue
		along = along.normalized() * sample_radius[i] * 0.5
		var side := along.orthogonal() * 0.6
		var p := sample_pos[i]
		c.draw_colored_polygon(PackedVector2Array([p + along, p + side, p - along, p - side]), SNAKE_SPOT)


func _draw_head(c: CanvasItem) -> void:
	var dead := state == State.DYING
	c.draw_set_transform(head_pos, head_angle)
	if tongue_phase >= 0.0 and not dead:
		var reach := sin(tongue_phase * PI) * 14.0
		var tip := Vector2(24.0 + reach, sin(clock * 40.0) * reach * 0.08)
		c.draw_line(Vector2(18, 0), tip, TONGUE, 2.5, true)
		c.draw_line(tip, tip + Vector2(5, -3.5) * reach / 14.0, TONGUE, 2.0, true)
		c.draw_line(tip, tip + Vector2(5, 3.5) * reach / 14.0, TONGUE, 2.0, true)

	c.draw_set_transform(head_pos, head_angle, Vector2(1.3, 1.0))
	c.draw_circle(Vector2(3, 0), 17.5, SNAKE_OUTLINE, true, -1.0, true)
	c.draw_circle(Vector2(3, 0), 15.0, SNAKE_BODY, true, -1.0, true)
	c.draw_circle(Vector2(0, -5), 6.0, SNAKE_SHINE, true, -1.0, true)

	c.draw_set_transform(head_pos, head_angle)
	c.draw_circle(Vector2(-5, -3), 2.2, SNAKE_SPOT, true, -1.0, true)
	c.draw_circle(Vector2(-5, 3), 2.2, SNAKE_SPOT, true, -1.0, true)
	var target := golden if golden_active else food
	var look := (_cell_center(target) - head_pos).rotated(-head_angle).normalized() * 1.8
	for side in [-1.0, 1.0]:
		var eye := Vector2(8, 8.5 * side)
		c.draw_circle(eye, 6.8, SNAKE_OUTLINE, true, -1.0, true)
		if dead:
			c.draw_circle(eye, 5.4, Color.WHITE, true, -1.0, true)
			c.draw_line(eye + Vector2(-3, -3), eye + Vector2(3, 3), SNAKE_OUTLINE, 2.0, true)
			c.draw_line(eye + Vector2(-3, 3), eye + Vector2(3, -3), SNAKE_OUTLINE, 2.0, true)
		elif blink > 0.0:
			c.draw_circle(eye, 5.4, SNAKE_STRIPE, true, -1.0, true)
			c.draw_line(eye + Vector2(-4, 0), eye + Vector2(4, 0), SNAKE_OUTLINE, 1.5, true)
		else:
			c.draw_circle(eye, 5.4, EYE, true, -1.0, true)
			c.draw_circle(eye + look, 3.2, INK, true, -1.0, true)
			c.draw_circle(eye + look + Vector2(-1.2, -1.2), 1.2, Color.WHITE, true, -1.0, true)
		c.draw_circle(Vector2(21, 4.0 * side), 1.4, SNAKE_OUTLINE, true, -1.0, true)
	c.draw_set_transform(Vector2.ZERO)


func _draw_apple(c: CanvasItem, cell: Vector2i, age: float, is_golden: bool) -> void:
	var pos := _cell_center(cell) + Vector2(0, sin(clock * 3.0 + cell.x) * 2.0)
	var grow := _pop_scale(age)
	var main := GOLD if is_golden else APPLE_RED
	var dark := Color("a8740b") if is_golden else Color("8d1b24")
	for i in 3:
		c.draw_circle(pos, (28.0 - i * 6.0 + sin(clock * 4.0) * 1.5) * grow, Color(main, 0.08), true, -1.0, true)
	if is_golden:
		c.draw_arc(pos, 24.0, -PI / 2.0, -PI / 2.0 + TAU * golden_timer / GOLDEN_TIME, 40, Color(GOLD, 0.9), 2.5, true)

	c.draw_set_transform(pos, 0.0, Vector2(grow, grow))
	c.draw_line(Vector2(0, -9), Vector2(3, -19), Color("5d3a1a"), 3.0, true)
	c.draw_set_transform(pos + Vector2(9, -16) * grow, -0.5, Vector2(1.0, 0.5) * grow)
	c.draw_circle(Vector2.ZERO, 7.0, Color("6cc04a"), true, -1.0, true)
	c.draw_set_transform(pos, 0.0, Vector2(grow, grow))
	c.draw_circle(Vector2(-4, 1), 13.0, dark, true, -1.0, true)
	c.draw_circle(Vector2(4, 1), 13.0, dark, true, -1.0, true)
	c.draw_circle(Vector2(-4, 1), 11.0, main, true, -1.0, true)
	c.draw_circle(Vector2(4, 1), 11.0, main, true, -1.0, true)
	c.draw_circle(Vector2(-6, -4), 3.5, Color(1, 1, 1, 0.75), true, -1.0, true)
	c.draw_set_transform(Vector2.ZERO)


## Linked portals share a colour: the first pair cyan, the second orange.
func _draw_portals(c: CanvasItem) -> void:
	var pairs := {}
	for end in portals:
		var key: Vector2i = end if end < portals[end] else portals[end]
		if not pairs.has(key):
			pairs[key] = pairs.size()
	for end in portals:
		var cell: Vector2i = end
		var key: Vector2i = cell if cell < portals[cell] else portals[cell]
		var tint: Color = PORTAL_COLORS[int(pairs[key]) % PORTAL_COLORS.size()]
		var pos := _cell_center(cell)
		var spin := clock * 2.2 + (cell.x + cell.y) * 0.3
		c.draw_circle(pos, 21.0, Color(tint, 0.2), true, -1.0, true)
		c.draw_circle(pos, 16.5, Color(0.03, 0.04, 0.08, 0.85), true, -1.0, true)
		c.draw_arc(pos, 16.5, 0.0, TAU, 32, Color(tint, 0.55), 2.0, true)
		for i in 3:
			var from := spin + i * TAU / 3.0
			c.draw_arc(pos, 7.0 + i * 4.0, from, from + 2.1, 18, Color(tint, 1.0 - i * 0.18), 3.0, true)
		c.draw_circle(pos, 3.6 + sin(clock * 4.0) * 0.9, Color(1, 1, 1, 0.9), true, -1.0, true)


func _draw_poison(c: CanvasItem, rot: Dictionary) -> void:
	var pos := _cell_center(rot.cell) + Vector2(0, sin(clock * 2.4 + rot.cell.x) * 2.0)
	var grow := _pop_scale(rot.age)
	c.draw_circle(pos, 22.0 * grow, Color(POISON, 0.10), true, -1.0, true)
	c.draw_set_transform(pos, 0.0, Vector2(grow, grow))
	c.draw_line(Vector2(0, -9), Vector2(-3, -19), Color("4a3a20"), 3.0, true)
	c.draw_circle(Vector2(-4, 1), 13.0, POISON_DARK, true, -1.0, true)
	c.draw_circle(Vector2(4, 1), 13.0, POISON_DARK, true, -1.0, true)
	c.draw_circle(Vector2(-4, 1), 11.0, POISON, true, -1.0, true)
	c.draw_circle(Vector2(4, 1), 11.0, POISON, true, -1.0, true)
	# Sunken eyes and a flat mouth: rotten, and obviously not the red one.
	for side in [-5.0, 5.0]:
		c.draw_circle(Vector2(side, -2), 3.0, POISON_DARK, true, -1.0, true)
	c.draw_line(Vector2(-5, 7), Vector2(5, 7), POISON_DARK, 2.2, true)
	c.draw_circle(Vector2(-6, -6), 3.0, Color(1, 1, 1, 0.35), true, -1.0, true)
	c.draw_set_transform(Vector2.ZERO)
	# Bubbles rising off it.
	for i in 3:
		var rise := fmod(clock * 0.7 + i * 0.33, 1.0)
		c.draw_circle(pos + Vector2(sin(clock * 3.0 + i * 2.0) * 7.0, -14.0 - rise * 16.0),
				2.4 * (1.0 - rise), Color(POISON, (1.0 - rise) * 0.8), true, -1.0, true)


func _blade_pos(blade: Dictionary) -> Vector2:
	return _cell_center(blade.prev).lerp(_cell_center(blade.cell), _step_t())


func _draw_blades(c: CanvasItem) -> void:
	for blade in blades:
		var pos := _blade_pos(blade)
		var cell: Vector2i = blade.cell
		var spin := clock * 9.0 + cell.x
		c.draw_set_transform(pos, spin)
		for i in 6:
			var angle := i * TAU / 6.0
			var tip := Vector2.from_angle(angle) * 20.0
			var left := Vector2.from_angle(angle - 0.46) * 11.0
			var right := Vector2.from_angle(angle + 0.46) * 11.0
			c.draw_colored_polygon(PackedVector2Array([tip, left, right]), INK)
			c.draw_colored_polygon(PackedVector2Array([tip * 0.86, left * 0.82, right * 0.82]), BLADE_DARK)
			c.draw_colored_polygon(PackedVector2Array([tip * 0.7, left * 0.62, right * 0.62]), BLADE)
		c.draw_set_transform(Vector2.ZERO)
		c.draw_circle(pos, 10.0, INK, true, -1.0, true)
		c.draw_circle(pos, 8.0, BLADE_DARK, true, -1.0, true)
		c.draw_circle(pos, 5.0, BLADE, true, -1.0, true)
		c.draw_circle(pos + Vector2(-1.6, -1.6), 2.0, Color(1, 1, 1, 0.9), true, -1.0, true)


func _draw_hud(c: CanvasItem) -> void:
	var campaign := mode == Mode.CAMPAIGN and not level.is_empty()
	if campaign:
		_text(c, "%s  %s" % [Levels.label(world_index, stage_index), tr("world_%d" % (world_index + 1)).to_upper()],
				Vector2(30, 40), 20, Color(TEXT, 0.6), 5, 0.0)
		_text(c, level.name, Vector2(30, 74), 34, theme.accent, 8, 0.0)
	else:
		_text(c, tr("game_name"), Vector2(30, 64), 46, SNAKE_BODY, 10, 0.0, 300.0)
	_text(c, tr("hud_score"), Vector2(SCREEN.x / 2.0, 32), 16, Color(TEXT, 0.6))
	_text(c, str(score), Vector2(SCREEN.x / 2.0, 74), 42, TEXT, 8)
	if campaign:
		_draw_goal(c)
	else:
		# Apples eaten.
		var apple := Vector2(740, 50)
		c.draw_line(apple + Vector2(0, -7), apple + Vector2(2, -13), Color("5d3a1a"), 2.5, true)
		c.draw_circle(apple, 10.0, APPLE_RED, true, -1.0, true)
		c.draw_circle(apple + Vector2(-3, -3), 2.5, Color(1, 1, 1, 0.7), true, -1.0, true)
		_text(c, str(apples), Vector2(760, 62), 30, TEXT, 6, 0.0)
		# Best score.
		var crown := Vector2(860, 50)
		var points := PackedVector2Array()
		for p in [Vector2(-12, 8), Vector2(12, 8), Vector2(14, -7), Vector2(6, 0), Vector2(0, -11), Vector2(-6, 0), Vector2(-14, -7)]:
			points.append(crown + p)
		c.draw_colored_polygon(points, GOLD)
		_text(c, str(best), Vector2(924, 62), 30, GOLD, 6, 1.0)  # right-aligned, whatever the score's width

	var board := Rect2(BOARD_POS, BOARD_SIZE)
	match state:
		State.MENU:
			c.draw_rect(board, Color(0, 0, 0, 0.45))
			_draw_title(c)
			_text(c, tr("hud_tagline"), Vector2(SCREEN.x / 2.0, 385), 24, TEXT, 6)
			_text(c, tr("hud_campaign_progress") % [level_scores.size(), Levels.total()],
					Vector2(SCREEN.x / 2.0, 424), 20, Color(GOLD, 0.8), 5)
			_draw_options(c)
			var controls := tr("help_pad_steer") if using_pad else tr("help_kb_steer")
			_text(c, "%s      %s" % [controls, tr("hud_golden_worth") % GOLDEN_POINTS],
					Vector2(SCREEN.x / 2.0, 700), 18, Color(TEXT, 0.7), 5)
		State.LEVELS:
			c.draw_rect(board, Color(0, 0, 0, 0.66))
			_text(c, tr("campaign_title"), Vector2(SCREEN.x / 2.0, 186), 52, theme.accent, 12)
			_text(c, tr("campaign_progress") % [level_scores.size(), Levels.total()],
					Vector2(SCREEN.x / 2.0, 216), 19, Color(TEXT, 0.7), 5)
			_draw_level_grid(c)
			_text(c, _pick_blurb(), Vector2(SCREEN.x / 2.0, 706), 19,
					Color(TEXT, 0.78 if _is_open(pick_world, pick_stage) else 0.45), 5)
			_text(c, tr("help_pad_levels") if using_pad else tr("help_kb_levels"),
					Vector2(SCREEN.x / 2.0, 732), 16, Color(TEXT, 0.5), 4)
		State.PAUSED:
			c.draw_rect(board, Color(0, 0, 0, 0.55))
			_text(c, tr("paused_title"), Vector2(SCREEN.x / 2.0, 330), 80, TEXT, 12)
			_draw_options(c)
		State.OVER:
			c.draw_rect(board, Color(0, 0, 0, 0.55))
			_text(c, tr("game_over_title"), Vector2(SCREEN.x / 2.0, 300), 84, Color("ff6b6b"), 14)
			_text(c, _death_line(), Vector2(SCREEN.x / 2.0, 344), 24, Color(TEXT, 0.75), 6)
			_text(c, tr("hud_score_apples") % [score, apples], Vector2(SCREEN.x / 2.0, 392), 32, TEXT, 8)
			if campaign:
				_text(c, tr("goal_progress_line") % [_goal_noun(level.goal), goal_progress, level.goal.count],
						Vector2(SCREEN.x / 2.0, 434), 26, Color(theme.accent, 0.95), 6)
			elif new_best:
				var pulse := 1.0 + sin(clock * 6.0) * 0.08
				_text(c, tr("new_best"), Vector2(SCREEN.x / 2.0, 434), int(30 * pulse), GOLD, 8)
			else:
				_text(c, tr("best_value") % best, Vector2(SCREEN.x / 2.0, 434), 26, Color(TEXT, 0.7), 6)
			_draw_options(c)
		State.CLEARED:
			c.draw_rect(board, Color(0, 0, 0, 0.55))
			var last: bool = _flat() + 1 >= Levels.total()
			var beat := _pop_scale(clear_time) * (1.0 + sin(clock * 5.0) * 0.04)
			_text(c, tr("campaign_complete") if last else tr("level_clear"),
					Vector2(SCREEN.x / 2.0, 312), int((58 if last else 76) * beat), SNAKE_SHINE, 14)
			_text(c, "%s · %s" % [Levels.label(world_index, stage_index), level.name],
					Vector2(SCREEN.x / 2.0, 356), 28, TEXT, 7)
			_text(c, tr("hud_score_apples") % [score, apples], Vector2(SCREEN.x / 2.0, 404), 30, TEXT, 8)
			if new_best:
				_text(c, tr("best_on_level"), Vector2(SCREEN.x / 2.0, 444), 26, GOLD, 7)
			elif level_scores.has(_flat()):
				_text(c, tr("best_value") % int(level_scores[_flat()]), Vector2(SCREEN.x / 2.0, 444), 24, Color(TEXT, 0.7), 6)
			_draw_options(c)
		State.SETTINGS:
			c.draw_rect(board, Color(0, 0, 0, 0.7))
			_draw_settings(c)

	if flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(flash_color, flash * 0.35))


## What the level asks for, as a progress readout and a bar, plus the countdown when
## the level is timed.
func _draw_goal(c: CanvasItem) -> void:
	var goal: Dictionary = level.goal
	var done := mini(goal_progress, goal.count)
	if level.time > 0.0:
		var low := time_left < 10.0
		var tint := Color("ff6b6b") if low and fmod(clock, 0.6) < 0.35 else GOLD
		_text(c, "%d:%02d left" % [int(time_left) / 60, int(time_left) % 60], Vector2(924, 28), 20, tint, 5, 1.0)
	_text(c, "%s  %d / %d" % [_goal_noun(goal), done, goal.count], Vector2(924, 54), 23, TEXT, 6, 1.0)
	var bar := Rect2(700, 63, 224, 11)
	c.draw_rect(bar.grow(2), INK)
	c.draw_rect(bar, Color(0, 0, 0, 0.45))
	var fill := float(done) / maxf(goal.count, 1)
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), theme.accent)


func _goal_noun(goal: Dictionary) -> String:
	match goal.kind:
		"apples":
			return tr("goal_apples")
		"golden":
			return tr("goal_golden")
		"length":
			return tr("goal_length")
		"survive":
			return tr("goal_seconds")
	return tr("goal_default")


func _goal_short(goal: Dictionary) -> String:
	match goal.kind:
		"apples":
			return tr("goal_short_apples") % goal.count
		"golden":
			return tr("goal_short_golden") % goal.count
		"length":
			return tr("goal_short_length") % goal.count
		"survive":
			return tr("goal_short_survive") % goal.count
	return ""


func _death_line() -> String:
	match death_cause:
		"poison":
			return tr("death_poison")
		"blade":
			return tr("death_blade")
		"time":
			return tr("death_time")
	return tr("death_default")


## The whole campaign at a glance: one row per world, one tile per level. A level you
## have not reached shows only its number - no name, no goal, nothing to plan around -
## and a world you have not set foot in keeps its name hidden too.
func _draw_level_grid(c: CanvasItem) -> void:
	for world in Levels.world_count():
		var stages := Levels.stage_count(world)
		var reached := _is_open(world, 0)
		var row := _level_tile_rect(world, 0)
		var wash: Color = Levels.theme(world).light
		var tint: Color = Levels.theme(world).accent

		# The world's own ground colour runs down the left edge of its row.
		c.draw_rect(Rect2(WORLD_LABEL_X - 10.0, row.position.y, 8.0, row.size.y), wash if reached else Color(wash, 0.3))
		_text(c, tr("world_label") % (world + 1), Vector2(WORLD_LABEL_X + 8.0, row.position.y + 28.0), 15,
				Color(TEXT, 0.55 if reached else 0.3), 0, 0.0)
		_text(c, tr("world_%d" % (world + 1)) if reached else tr("world_unknown"), Vector2(WORLD_LABEL_X + 8.0, row.position.y + 54.0), 23,
				tint if reached else Color(LOCKED, 0.5), 0, 0.0)

		for stage in stages:
			_draw_level_tile(c, world, stage)


func _draw_level_tile(c: CanvasItem, world: int, stage: int) -> void:
	var rect := _level_tile_rect(world, stage)
	var open := _is_open(world, stage)
	var flat := Levels.flat(world, stage)
	var cleared: bool = level_scores.has(flat)
	var picked := world == pick_world and stage == pick_stage
	var tint: Color = Levels.theme(world).accent

	c.draw_rect(rect.grow(3), INK)
	if picked:
		c.draw_rect(rect, tint if open else Color(0.26, 0.26, 0.26, 0.9))
	elif cleared:
		c.draw_rect(rect, Color(tint, 0.22))
	else:
		c.draw_rect(rect, Color(0, 0, 0, 0.45 if open else 0.62))
	c.draw_rect(rect, Color(TEXT, 0.25), false, 2.0)

	var ink := INK if picked and open else (TEXT if open else LOCKED)
	var at := rect.position
	_text(c, Levels.label(world, stage), at + Vector2(12, 26), 19, Color(ink, 0.9 if open else 0.55), 0, 0.0)
	if not open:
		_draw_padlock(c, at + Vector2(rect.size.x - 24, 44), ink)
		_text(c, tr("level_locked"), at + Vector2(12, 52), 16, Color(ink, 0.55), 0, 0.0)
		return
	var data := Levels.get_level(world, stage)
	_text(c, data.name, at + Vector2(12, 50), 17, ink, 0, 0.0)
	_text(c, _goal_short(data.goal), at + Vector2(12, 69), 13, Color(ink, 0.7), 0, 0.0)
	if cleared:
		_draw_tick(c, at + Vector2(rect.size.x - 24, 22), INK if picked else GOLD)
		_text(c, tr("best_value") % int(level_scores[flat]), Vector2(at.x + rect.size.x - 12, at.y + 74), 13,
				Color(ink, 0.75), 0, 1.0)


## The line under the grid: the highlighted level's hint, or what it takes to open it.
func _pick_blurb() -> String:
	if _is_open(pick_world, pick_stage):
		return Levels.get_level(pick_world, pick_stage).hint
	var next := Levels.split(unlocked - 1)
	return tr("campaign_locked_hint") % Levels.label(next.x, next.y)


func _draw_padlock(c: CanvasItem, pos: Vector2, tint: Color) -> void:
	c.draw_arc(pos + Vector2(0, -6), 6.0, PI, TAU, 14, Color(tint, 0.8), 3.0, true)
	c.draw_rect(Rect2(pos - Vector2(9, 5), Vector2(18, 15)), Color(tint, 0.8))
	c.draw_circle(pos + Vector2(0, 2), 2.2, Color(INK, 0.8), true, -1.0, true)


func _draw_tick(c: CanvasItem, pos: Vector2, tint: Color) -> void:
	c.draw_line(pos + Vector2(-8, 0), pos + Vector2(-2, 6), tint, 3.5, true)
	c.draw_line(pos + Vector2(-2, 6), pos + Vector2(9, -7), tint, 3.5, true)


## Big wavy title, one letter at a time. The size shrinks to fit: "Snake Quest" is a lot
## wider than "SNAKE" was, and some languages (Jogo da Cobrinha) are wider still.
func _draw_title(c: CanvasItem) -> void:
	var title := tr("game_name")
	var max_width := 880.0
	var size := 128
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if width > max_width:
		size = maxi(40, int(size * max_width / width))
		width = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var outline := maxi(4, int(size * 0.17))
	var x := SCREEN.x / 2.0 - width / 2.0
	for i in title.length():
		var letter := title[i]
		var at := Vector2(x, 320 + sin(clock * 3.0 - i * 0.7) * 10.0)
		c.draw_string_outline(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, INK)
		c.draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SNAKE_BODY.lerp(SNAKE_SHINE, 0.5 + 0.5 * sin(clock * 3.0 - i * 0.7)))
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _draw_options(c: CanvasItem) -> void:
	var options := _options()
	for i in options.size():
		var rect := _option_rect(i)
		var selected := i == option_index
		if selected:
			c.draw_rect(rect.grow(3), INK)
			c.draw_rect(rect, SNAKE_BODY)
		else:
			c.draw_rect(rect, Color(0, 0, 0, 0.4))
			c.draw_rect(rect, Color(TEXT, 0.35), false, 2.0)
		var ink := INK if selected else TEXT
		if options[i] == "settings":
			_draw_settings_button_label(c, rect, ink)
		else:
			_text(c, tr(options[i]), Vector2(SCREEN.x / 2.0, rect.position.y + rect.size.y / 2.0 + 10.0), 28, ink)
	_text(c, tr("help_pad_choose") if using_pad else tr("help_kb_choose"),
			Vector2(SCREEN.x / 2.0, _option_rect(options.size()).position.y + 20.0), 16, Color(TEXT, 0.55), 4)


## The Settings button: a small gear beside its label, the pair centered as one unit.
func _draw_settings_button_label(c: CanvasItem, rect: Rect2, ink: Color) -> void:
	var label := tr("settings")
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var icon_d := 26.0
	var gap := 10.0
	var start_x := rect.get_center().x - (icon_d + gap + label_width) / 2.0
	var mid_y := rect.get_center().y
	_draw_gear_icon(c, Vector2(start_x + icon_d / 2.0, mid_y), icon_d / 2.0, ink)
	_text(c, label, Vector2(start_x + icon_d + gap, mid_y + 10.0), 28, ink, 0, 0.0)


## A small gear at `center`, `radius` across, in `color`.
func _draw_gear_icon(c: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	for i in 8:
		var a := i * TAU / 8.0
		c.draw_line(center + Vector2.from_angle(a) * (radius * 0.65), center + Vector2.from_angle(a) * radius, color, 3.0, true)
	c.draw_circle(center, radius * 0.68, color, true, -1.0, true)
	c.draw_circle(center, radius * 0.3, INK, true, -1.0, true)


func _settings_back_rect() -> Rect2:
	return Rect2(SCREEN.x / 2.0 - 90.0, 560.0, 180.0, OPTION_HEIGHT - 10.0)


## Ten language tiles in two rows, the current one highlighted, plus a Back button.
func _draw_settings(c: CanvasItem) -> void:
	_text(c, tr("settings_title"), Vector2(SCREEN.x / 2.0, 220), 52, theme.accent, 12)
	_text(c, tr("settings_language"), Vector2(SCREEN.x / 2.0, 264), 20, Color(TEXT, 0.7), 5)

	for i in Strings.LANGUAGES.size():
		var rect := _lang_tile_rect(i)
		var active: bool = Strings.LANGUAGES[i][0] == language
		var picked := i == lang_cursor
		c.draw_rect(rect.grow(3), INK)
		if picked:
			c.draw_rect(rect, theme.accent)
		elif active:
			c.draw_rect(rect, Color(theme.accent, 0.3))
		else:
			c.draw_rect(rect, Color(0, 0, 0, 0.45))
		c.draw_rect(rect, Color(TEXT, 0.3), false, 2.0)
		var ink := INK if picked else TEXT
		_text(c, Strings.LANGUAGES[i][1], rect.get_center() + Vector2(0, 7), 19, ink, 0)
		if active:
			_draw_tick(c, rect.position + Vector2(20, 18), INK if picked else theme.accent)

	var back := _settings_back_rect()
	c.draw_rect(back.grow(3), INK)
	c.draw_rect(back, Color(0, 0, 0, 0.4))
	c.draw_rect(back, Color(TEXT, 0.35), false, 2.0)
	_text(c, tr("settings_back"), back.get_center() + Vector2(0, 8), 22, TEXT)

	_text(c, tr("settings_hint_pad") if using_pad else tr("settings_hint_kb"),
			Vector2(SCREEN.x / 2.0, 660), 16, Color(TEXT, 0.55), 4)


## Draws text with its baseline at `pos.y`; `align` 0 = left, 0.5 = centered, 1 = right.
## `max_width` shrinks the font size to fit if the text (e.g. a long translated name) would
## otherwise overflow it; 0 leaves the size as given.
func _text(c: CanvasItem, text: String, pos: Vector2, size: int, color: Color, outline := 0, align := 0.5, max_width := 0.0) -> void:
	size = maxi(size, 1)  # sizes that animate from a scale of 0 would upset the text server
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if max_width > 0.0 and width > max_width:
		size = maxi(1, int(size * max_width / width))
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(pos.x - width * align, pos.y)
	if outline > 0:
		c.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(INK, color.a))
	c.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _has_head() -> bool:
	return not body.is_empty() and pop_count == 0


## Scale for things popping into view: overshoots a little, then settles at 1.
func _pop_scale(age: float) -> float:
	var x := clampf(age / 0.35, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * x * x * x + 1.70158 * x * x
