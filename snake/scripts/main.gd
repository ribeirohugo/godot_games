extends Node2D
## Snake: steer the snake to eat apples and grow, without hitting the walls or yourself.
## Arrows / WASD or a gamepad (D-pad / left stick) steer; P, Esc or Start pauses.
## Behind the menu the snake plays by itself.

const SfxScript := preload("res://scripts/sfx.gd")

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

const BODY_RADIUS := 16.0
const TAIL_RADIUS := 3.5
const SAMPLE_SPACING := 4.0  # body is drawn as circles this far apart along its path
const SHADOW_OFFSET := Vector2(5, 7)
const OPTION_HEIGHT := 54.0
const STICK_PRESS := 0.55  # left stick counts as a direction past this
const STICK_RELEASE := 0.35  # and must come back under this before it counts again

const GRASS_LIGHT := Color("4f8a3c")
const GRASS_DARK := Color("467d35")
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

enum State { MENU, PLAY, PAUSED, DYING, OVER }

var state := State.MENU
var resume_state := State.PLAY
var option_index := 0

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
	font = ThemeDB.fallback_font
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

	_make_decor()
	_load_best()
	_reset_game()


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
	if state in [State.MENU, State.PAUSED, State.OVER]:
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
					_choose("Resume" if state == State.PAUSED else options[option_index])
				JOY_BUTTON_B:
					if state == State.PAUSED:
						_choose("Resume")
					elif state == State.OVER:
						_choose("Exit to menu")
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
					_choose("Resume")
			KEY_ESCAPE:
				if state != State.MENU:
					_choose("Exit to menu")


func _options() -> Array:
	match state:
		State.PAUSED:
			return ["Resume", "Restart", "Exit to menu"]
		State.OVER:
			return ["Play again", "Exit to menu"]
	return ["Play"]


func _options_top() -> float:
	match state:
		State.PAUSED:
			return 380.0
		State.OVER:
			return 440.0
	return 440.0


func _option_rect(index: int) -> Rect2:
	return Rect2(SCREEN.x / 2.0 - 150.0, _options_top() + index * OPTION_HEIGHT, 300.0, OPTION_HEIGHT - 10.0)


func _option_at(point: Vector2) -> int:
	for i in _options().size():
		if _option_rect(i).has_point(point):
			return i
	return -1


func _choose(option: String) -> void:
	match option:
		"Play", "Restart", "Play again":
			_reset_game()
			particles.clear()
			state = State.PLAY
			sfx.play("start")
		"Resume":
			state = resume_state
			sfx.play("select")
		"Exit to menu":
			_reset_game()
			state = State.MENU
			option_index = 0
			sfx.play("select")


# --- Game logic --------------------------------------------------------------

func _reset_game() -> void:
	body.clear()
	var start := Vector2i(6, int(ROWS / 2.0))
	for i in START_LENGTH:
		body.append(start - Vector2i(i, 0))
	prev_body = body.duplicate()
	dir = Vector2i.RIGHT
	prev_dir = dir
	input_queue.clear()
	step_time = STEP_START
	step_timer = 0.0
	score = 0
	apples = 0
	new_best = false
	pop_count = 0
	bulges.clear()
	popups.clear()
	golden_active = false
	food = _free_cell()
	food_age = 0.0


func _process(delta: float) -> void:
	clock += delta
	shake = maxf(shake - delta * 2.0, 0.0)
	flash = maxf(flash - delta * 2.5, 0.0)
	world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 12.0

	match state:
		State.MENU, State.PLAY:
			_advance(delta)
		State.DYING:
			_update_dying(delta)
	_update_effects(delta)
	_build_samples()

	shadow_layer.queue_redraw()
	game_layer.queue_redraw()
	hud_layer.queue_redraw()


func _advance(delta: float) -> void:
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

	step_timer += delta
	while step_timer >= step_time and (state == State.PLAY or state == State.MENU):
		step_timer -= step_time
		if state == State.MENU:
			_autopilot()
		_step()


func _step() -> void:
	prev_dir = dir
	if not input_queue.is_empty():
		dir = input_queue.pop_front()
	var head := body[0] + dir
	var eats_food := head == food
	var eats_golden := golden_active and head == golden
	var grows := eats_food or eats_golden
	# The tail moves out of the way this step, unless the snake grows.
	var solid := body.slice(0, body.size() if grows else body.size() - 1)
	if not _inside(head) or solid.has(head):
		_die()
		return

	prev_body = body.duplicate()
	body.push_front(head)
	if grows:
		prev_body.append(prev_body.back())
	else:
		body.pop_back()

	for i in bulges.size():
		bulges[i] += 1
	bulges = bulges.filter(func(b: int) -> bool: return b < body.size())

	if eats_food:
		_eat(head, APPLE_POINTS, APPLE_RED)
		food = _free_cell()
		food_age = 0.0
		if not golden_active and randf() < GOLDEN_CHANCE:
			golden = _free_cell()
			golden_active = true
			golden_timer = GOLDEN_TIME
			golden_age = 0.0
	if eats_golden:
		_eat(head, GOLDEN_POINTS, GOLD)
		golden_active = false
		flash = 0.4
		flash_color = Color(1, 0.9, 0.5)


func _eat(cell: Vector2i, points: int, color: Color) -> void:
	var pos := _cell_center(cell)
	bulges.append(0)
	step_time = maxf(step_time - STEP_SPEEDUP, STEP_MIN)
	_burst(pos, color, 18, 240.0)
	_burst(pos, SNAKE_SHINE, 6, 120.0)
	if state == State.PLAY:
		score += points
		apples += 1
		popups.append({"pos": pos, "text": "+%d" % points, "color": color, "life": 0.9})
		sfx.play("golden" if points == GOLDEN_POINTS else "eat")
		if points == GOLDEN_POINTS:
			_rumble(0.4, 0.0, 0.12)


func _die() -> void:
	if state == State.MENU:
		_reset_game()
		return
	state = State.DYING
	prev_body = body.duplicate()
	shake = 1.0
	flash = 0.6
	flash_color = Color(1, 0.15, 0.15)
	pop_timer = 0.35  # short freeze before the body bursts
	over_delay = 0.8
	sfx.play("hit")
	_rumble(0.6, 1.0, 0.4)
	if score > best:
		best = score
		new_best = true
		_save_best()


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
		if not _inside(next) or body.slice(0, body.size() - 1).has(next):
			continue
		var exits := 0
		for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if _inside(next + side) and not body.has(next + side):
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


func _free_cell() -> Vector2i:
	var cells: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if not body.has(cell) and cell != food and not (golden_active and cell == golden):
				cells.append(cell)
	if cells.is_empty():
		return Vector2i(-100, -100)
	return cells.pick_random()


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS


func _cell_center(cell: Vector2i) -> Vector2:
	return BOARD_POS + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best = config.get_value("score", "best", 0)


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("score", "best", best)
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
	var t := clampf(step_timer / step_time, 0.0, 1.0)
	var n := body.size()
	var path := PackedVector2Array()
	path.append(_cell_center(prev_body[0]).lerp(_cell_center(body[0]), t))
	for i in range(1, n):
		path.append(_cell_center(body[i]))
	path.append(_cell_center(prev_body[n - 1]).lerp(_cell_center(body[n - 1]), t))
	head_pos = path[0]
	head_angle = lerp_angle(Vector2(prev_dir).angle(), Vector2(dir).angle(), minf(t * 2.5, 1.0))

	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])

	var segment := 1
	var segment_start := 0.0
	var count := int(total / SAMPLE_SPACING) + 1
	for k in count + 1:
		var d := minf(k * SAMPLE_SPACING, total)
		while segment < path.size() - 1 and segment_start + path[segment - 1].distance_to(path[segment]) < d:
			segment_start += path[segment - 1].distance_to(path[segment])
			segment += 1
		var length := path[segment - 1].distance_to(path[segment])
		var f := 0.0 if length < 0.001 else (d - segment_start) / length
		var radius := lerpf(BODY_RADIUS, TAIL_RADIUS, pow(d / maxf(total, 1.0), 2.6))
		for bulge in bulges:
			radius += 5.0 * exp(-pow((d - (bulge + t) * CELL) / 14.0, 2.0))
		sample_pos.append(path[segment - 1].lerp(path[segment], clampf(f, 0.0, 1.0)))
		sample_radius.append(radius)
		sample_dist.append(d)


# --- Drawing -----------------------------------------------------------------

func _draw_board(c: CanvasItem) -> void:
	var board := Rect2(BOARD_POS, BOARD_SIZE)
	c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("16241a"))
	# Wooden frame.
	c.draw_rect(board.grow(16), Color("2b1d12"))
	c.draw_rect(board.grow(13), Color("6b4a2b"))
	c.draw_rect(board.grow(7), Color("8a6239"))
	c.draw_rect(board.grow(3), Color("24170d"))
	for corner in [board.position, Vector2(board.end.x, board.position.y), board.end, Vector2(board.position.x, board.end.y)]:
		c.draw_circle(corner + (board.get_center() - corner).sign() * -8.0, 3.0, Color("c9a26b"), true, -1.0, true)

	for y in ROWS:
		for x in COLS:
			var color := GRASS_LIGHT if (x + y) % 2 == 0 else GRASS_DARK
			c.draw_rect(Rect2(BOARD_POS + Vector2(x, y) * CELL, Vector2(CELL, CELL)), color)

	for item in decor:
		var pos: Vector2 = item["pos"]
		match item["kind"]:
			"tuft":
				var blade := Color("64a64a")
				c.draw_line(pos, pos + Vector2(-4, -8), blade, 2.0, true)
				c.draw_line(pos, pos + Vector2(0, -11), blade, 2.0, true)
				c.draw_line(pos, pos + Vector2(4, -8), blade, 2.0, true)
			"flower":
				for i in 5:
					c.draw_circle(pos + Vector2.from_angle(i * TAU / 5.0) * 3.2, 2.4, item["color"], true, -1.0, true)
				c.draw_circle(pos, 1.8, Color("ffd23f"), true, -1.0, true)
			"pebble":
				c.draw_set_transform(pos, 0.0, Vector2(1.4, 1.0))
				c.draw_circle(Vector2.ZERO, 3.0, Color("6f7a64"), true, -1.0, true)
				c.draw_circle(Vector2(-0.8, -0.8), 1.4, Color("9aa38e"), true, -1.0, true)
				c.draw_set_transform(Vector2.ZERO)

	c.draw_texture_rect(vignette, board, false)


func _make_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var flower_colors := [Color("f4f1de"), Color("f7b2c4"), Color("b8c5ff")]
	for i in 55:
		var roll := rng.randf()
		decor.append({
			"pos": BOARD_POS + Vector2(rng.randf_range(8, BOARD_SIZE.x - 8), rng.randf_range(12, BOARD_SIZE.y - 8)),
			"kind": "tuft" if roll < 0.6 else ("flower" if roll < 0.85 else "pebble"),
			"color": flower_colors[rng.randi() % flower_colors.size()],
		})


func _draw_shadows(c: CanvasItem) -> void:
	for pos in [food, golden] if golden_active else [food]:
		c.draw_set_transform(_cell_center(pos) + Vector2(3, 15), 0.0, Vector2(1.2, 0.45))
		c.draw_circle(Vector2.ZERO, 13.0 * _pop_scale(food_age if pos == food else golden_age), Color.BLACK)
	c.draw_set_transform(Vector2.ZERO)
	for i in sample_pos.size():
		c.draw_circle(sample_pos[i] + SHADOW_OFFSET, sample_radius[i] + 2.0, Color.BLACK)
	if _has_head():
		c.draw_set_transform(head_pos + SHADOW_OFFSET, head_angle, Vector2(1.3, 1.0))
		c.draw_circle(Vector2(3, 0), 17.5, Color.BLACK)
		c.draw_set_transform(Vector2.ZERO)


func _draw_game(c: CanvasItem) -> void:
	if state != State.OVER:
		_draw_apple(c, food, food_age, false)
	if golden_active and (golden_timer > 1.5 or fmod(clock, 0.2) < 0.12):
		_draw_apple(c, golden, golden_age, true)
	_draw_snake(c)
	if _has_head():
		_draw_head(c)

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


func _draw_hud(c: CanvasItem) -> void:
	_text(c, "SNAKE", Vector2(30, 64), 46, SNAKE_BODY, 10, 0.0)
	_text(c, "SCORE", Vector2(SCREEN.x / 2.0, 32), 16, Color(TEXT, 0.6))
	_text(c, str(score), Vector2(SCREEN.x / 2.0, 74), 42, TEXT, 8)

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
	_text(c, str(best), Vector2(882, 62), 30, GOLD, 6, 0.0)

	var board := Rect2(BOARD_POS, BOARD_SIZE)
	match state:
		State.MENU:
			c.draw_rect(board, Color(0, 0, 0, 0.45))
			_draw_title(c)
			_text(c, "Eat apples, grow long, and don't bite yourself!", Vector2(SCREEN.x / 2.0, 385), 24, TEXT, 6)
			_draw_options(c)
			var controls := "D-pad / stick: steer      Start: pause" if using_pad else "Arrows / WASD: steer      P / Esc: pause"
			_text(c, "%s      Golden apples: +%d" % [controls, GOLDEN_POINTS],
					Vector2(SCREEN.x / 2.0, 700), 18, Color(TEXT, 0.7), 5)
		State.PAUSED:
			c.draw_rect(board, Color(0, 0, 0, 0.55))
			_text(c, "PAUSED", Vector2(SCREEN.x / 2.0, 330), 80, TEXT, 12)
			_draw_options(c)
		State.OVER:
			c.draw_rect(board, Color(0, 0, 0, 0.55))
			_text(c, "GAME OVER", Vector2(SCREEN.x / 2.0, 300), 84, Color("ff6b6b"), 14)
			_text(c, "Score %d      Apples %d" % [score, apples], Vector2(SCREEN.x / 2.0, 360), 32, TEXT, 8)
			if new_best:
				var pulse := 1.0 + sin(clock * 6.0) * 0.08
				_text(c, "New best!", Vector2(SCREEN.x / 2.0, 410), int(30 * pulse), GOLD, 8)
			else:
				_text(c, "Best %d" % best, Vector2(SCREEN.x / 2.0, 410), 26, Color(TEXT, 0.7), 6)
			_draw_options(c)

	if flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(flash_color, flash * 0.35))


## Big wavy title, one letter at a time.
func _draw_title(c: CanvasItem) -> void:
	var title := "SNAKE"
	var size := 128
	var x := SCREEN.x / 2.0 - font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	for i in title.length():
		var letter := title[i]
		var at := Vector2(x, 320 + sin(clock * 3.0 - i * 0.7) * 10.0)
		c.draw_string_outline(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 22, INK)
		c.draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SNAKE_BODY.lerp(SNAKE_SHINE, 0.5 + 0.5 * sin(clock * 3.0 - i * 0.7)))
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _draw_options(c: CanvasItem) -> void:
	var options := _options()
	for i in options.size():
		var rect := _option_rect(i)
		var baseline := rect.position.y + rect.size.y / 2.0 + 10.0
		if i == option_index:
			c.draw_rect(rect.grow(3), INK)
			c.draw_rect(rect, SNAKE_BODY)
			_text(c, options[i], Vector2(SCREEN.x / 2.0, baseline), 28, INK)
		else:
			c.draw_rect(rect, Color(0, 0, 0, 0.4))
			c.draw_rect(rect, Color(TEXT, 0.35), false, 2.0)
			_text(c, options[i], Vector2(SCREEN.x / 2.0, baseline), 28, TEXT)
	_text(c, "D-pad or stick to choose, A to select" if using_pad else "W / S or arrows to choose, Enter or click to select",
			Vector2(SCREEN.x / 2.0, _option_rect(options.size()).position.y + 20.0), 16, Color(TEXT, 0.55), 4)


## Draws text with its baseline at `pos.y`; `align` 0 = left, 0.5 = centered, 1 = right.
func _text(c: CanvasItem, text: String, pos: Vector2, size: int, color: Color, outline := 0, align := 0.5) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
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
