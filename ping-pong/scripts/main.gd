extends Node2D
## Classic ping pong: one player against the computer, or two players on one keyboard.
## Left paddle: W / S. Right paddle: Up / Down (two-player mode).

const SfxScript := preload("res://scripts/sfx.gd")

const SIZE := Vector2(960, 540)
const PADDLE_SIZE := Vector2(14, 90)
const PADDLE_MARGIN := 30.0
const PADDLE_SPEED := 460.0
const CPU_SPEED := 330.0  # slower than a player, so the computer can be beaten
const BALL_SIZE := 14.0
const BALL_START_SPEED := 380.0
const BALL_SPEEDUP := 1.06  # per paddle hit
const BALL_MAX_SPEED := 900.0
const MAX_BOUNCE_ANGLE := 0.96  # radians, about 55 degrees
const SERVE_DELAY := 0.8
const WIN_SCORE := 11
const OPTIONS_TOP := 310.0
const OPTION_HEIGHT := 50.0

const COLOR := Color(0.9, 0.93, 1.0)
const DIM := Color(0.9, 0.93, 1.0, 0.25)

enum State { MENU, SERVE, PLAY, PAUSED, OVER }

var state := State.MENU
var resume_state := State.PLAY  # state to go back to when unpausing
var option_index := 0  # highlighted entry in the pause / game over options
var two_players := false
var left_y := SIZE.y / 2.0
var right_y := SIZE.y / 2.0
var ball_pos := SIZE / 2.0
var ball_vel := Vector2.ZERO
var scores := [0, 0]
var serve_dir := 1.0
var serve_timer := 0.0
var cpu_aim := 0.0  # offset from the ball the computer aims at, re-rolled every hit
var flash := 0.0
var sfx
var font: Font


func _ready() -> void:
	sfx = SfxScript.new()
	add_child(sfx)
	font = ThemeDB.fallback_font


func _unhandled_input(event: InputEvent) -> void:
	if state == State.PAUSED or state == State.OVER:
		_options_input(event)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match state:
		State.MENU:
			if event.physical_keycode == KEY_1:
				_start(false)
			elif event.physical_keycode == KEY_2:
				_start(true)
		_:
			if event.physical_keycode in [KEY_P, KEY_ESCAPE]:
				resume_state = state
				state = State.PAUSED
				option_index = 0


## Picks from the pause / game over options with the keyboard or the mouse.
func _options_input(event: InputEvent) -> void:
	var options := _options()
	if event is InputEventMouseMotion:
		var hovered := _option_at(event.position)
		if hovered >= 0:
			option_index = hovered
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _option_at(event.position)
		if clicked >= 0:
			_choose(options[clicked])
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_W, KEY_UP:
				option_index = posmod(option_index - 1, options.size())
			KEY_S, KEY_DOWN:
				option_index = posmod(option_index + 1, options.size())
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_choose(options[option_index])
			KEY_P:
				if state == State.PAUSED:
					_choose("Resume")
			KEY_ESCAPE:
				_choose("Exit to menu")


func _options() -> Array:
	if state == State.PAUSED:
		return ["Resume", "Restart", "Exit to menu"]
	return ["Play again", "Exit to menu"]


func _option_rect(index: int) -> Rect2:
	return Rect2(SIZE.x / 2.0 - 140.0, OPTIONS_TOP + index * OPTION_HEIGHT - 32.0, 280.0, OPTION_HEIGHT - 8.0)


func _option_at(point: Vector2) -> int:
	for i in _options().size():
		if _option_rect(i).has_point(point):
			return i
	return -1


func _choose(option: String) -> void:
	match option:
		"Resume":
			state = resume_state
		"Restart", "Play again":
			_start(two_players)
		"Exit to menu":
			state = State.MENU


func _start(versus_player: bool) -> void:
	two_players = versus_player
	scores = [0, 0]
	left_y = SIZE.y / 2.0
	right_y = SIZE.y / 2.0
	serve_dir = 1.0 if randf() < 0.5 else -1.0
	_serve()


func _serve() -> void:
	ball_pos = SIZE / 2.0
	ball_vel = Vector2.ZERO
	serve_timer = SERVE_DELAY
	state = State.SERVE


func _process(delta: float) -> void:
	flash = maxf(flash - delta * 3.0, 0.0)
	if state == State.SERVE or state == State.PLAY:
		_move_paddles(delta)
	if state == State.SERVE:
		serve_timer -= delta
		if serve_timer <= 0.0:
			var angle := randf_range(-0.4, 0.4)
			ball_vel = Vector2(serve_dir, 0).rotated(angle * serve_dir) * BALL_START_SPEED
			state = State.PLAY
	elif state == State.PLAY:
		_move_ball(delta)
	queue_redraw()


func _move_paddles(delta: float) -> void:
	left_y += _axis(KEY_W, KEY_S) * PADDLE_SPEED * delta
	if two_players:
		right_y += _axis(KEY_UP, KEY_DOWN) * PADDLE_SPEED * delta
	else:
		# Follow the ball only while it comes towards the computer, otherwise drift to the middle.
		var target: float = ball_pos.y + cpu_aim if ball_vel.x > 0.0 else SIZE.y / 2.0
		right_y = move_toward(right_y, target, CPU_SPEED * delta)
	var half := PADDLE_SIZE.y / 2.0
	left_y = clampf(left_y, half, SIZE.y - half)
	right_y = clampf(right_y, half, SIZE.y - half)


func _axis(up: Key, down: Key) -> float:
	return float(Input.is_physical_key_pressed(down)) - float(Input.is_physical_key_pressed(up))


func _move_ball(delta: float) -> void:
	ball_pos += ball_vel * delta
	var r := BALL_SIZE / 2.0

	if ball_pos.y < r:
		ball_pos.y = r
		ball_vel.y = absf(ball_vel.y)
		sfx.play("wall")
	elif ball_pos.y > SIZE.y - r:
		ball_pos.y = SIZE.y - r
		ball_vel.y = -absf(ball_vel.y)
		sfx.play("wall")

	var left_face := PADDLE_MARGIN + PADDLE_SIZE.x
	var right_face := SIZE.x - PADDLE_MARGIN - PADDLE_SIZE.x
	if ball_vel.x < 0.0 and ball_pos.x - r <= left_face and ball_pos.x - r >= PADDLE_MARGIN - r \
			and absf(ball_pos.y - left_y) <= PADDLE_SIZE.y / 2.0 + r:
		ball_pos.x = left_face + r
		_bounce(left_y, 1.0)
	elif ball_vel.x > 0.0 and ball_pos.x + r >= right_face and ball_pos.x + r <= SIZE.x - PADDLE_MARGIN + r \
			and absf(ball_pos.y - right_y) <= PADDLE_SIZE.y / 2.0 + r:
		ball_pos.x = right_face - r
		_bounce(right_y, -1.0)

	if ball_pos.x < -r:
		_point(1)
	elif ball_pos.x > SIZE.x + r:
		_point(0)


## Sends the ball back; hitting near a paddle's edge gives a steeper angle.
func _bounce(paddle_y: float, direction: float) -> void:
	var offset := clampf((ball_pos.y - paddle_y) / (PADDLE_SIZE.y / 2.0), -1.0, 1.0)
	var speed := minf(ball_vel.length() * BALL_SPEEDUP, BALL_MAX_SPEED)
	var angle := offset * MAX_BOUNCE_ANGLE
	ball_vel = Vector2(cos(angle) * direction, sin(angle)) * speed
	cpu_aim = randf_range(-PADDLE_SIZE.y * 0.45, PADDLE_SIZE.y * 0.45)
	sfx.play("paddle")


func _point(player: int) -> void:
	scores[player] += 1
	flash = 1.0
	serve_dir = -1.0 if player == 0 else 1.0  # serve towards the player who lost the point
	if scores[player] >= WIN_SCORE and scores[player] - scores[1 - player] >= 2:
		state = State.OVER
		option_index = 0
		sfx.play("win")
	else:
		sfx.play("score")
		_serve()


func _draw() -> void:
	# Center net.
	var y := 10.0
	while y < SIZE.y:
		draw_rect(Rect2(SIZE.x / 2.0 - 2.0, y, 4.0, 18.0), DIM)
		y += 30.0

	_text(str(scores[0]), Vector2(SIZE.x / 2.0 - 90.0, 80.0), 64, COLOR.lerp(Color.GOLD, flash))
	_text(str(scores[1]), Vector2(SIZE.x / 2.0 + 90.0, 80.0), 64, COLOR.lerp(Color.GOLD, flash))

	var half := PADDLE_SIZE.y / 2.0
	draw_rect(Rect2(PADDLE_MARGIN, left_y - half, PADDLE_SIZE.x, PADDLE_SIZE.y), COLOR)
	draw_rect(Rect2(SIZE.x - PADDLE_MARGIN - PADDLE_SIZE.x, right_y - half, PADDLE_SIZE.x, PADDLE_SIZE.y), COLOR)

	match state:
		State.MENU:
			_text("PING PONG", Vector2(SIZE.x / 2.0, 220.0), 72, COLOR)
			_text("1  -  Play vs computer", Vector2(SIZE.x / 2.0, 300.0), 26, COLOR)
			_text("2  -  Two players", Vector2(SIZE.x / 2.0, 340.0), 26, COLOR)
			_text("Left: W / S      Right: Up / Down      P / Esc: pause", Vector2(SIZE.x / 2.0, 470.0), 18, DIM)
		State.OVER:
			var winner: String = "Left player" if scores[0] > scores[1] else "Right player"
			if not two_players:
				winner = "You" if scores[0] > scores[1] else "Computer"
			_text("%s win%s!" % [winner, "" if winner == "You" else "s"], Vector2(SIZE.x / 2.0, 250.0), 52, Color.GOLD)
			_draw_options()
		State.PAUSED:
			_draw_ball()
			draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0.6))
			_text("PAUSED", Vector2(SIZE.x / 2.0, 250.0), 64, COLOR)
			_draw_options()
		_:
			_draw_ball()
			_text("P: pause      Esc: pause / exit", Vector2(SIZE.x / 2.0, SIZE.y - 14.0), 16, DIM)


func _draw_options() -> void:
	var options := _options()
	for i in options.size():
		var rect := _option_rect(i)
		if i == option_index:
			draw_rect(rect, COLOR)
			_text(options[i], Vector2(SIZE.x / 2.0, rect.position.y + 30.0), 26, Color(0.05, 0.06, 0.12))
		else:
			draw_rect(rect, DIM, false, 2.0)
			_text(options[i], Vector2(SIZE.x / 2.0, rect.position.y + 30.0), 26, COLOR)
	_text("W / S or arrows to choose, Enter or click to select", Vector2(SIZE.x / 2.0, SIZE.y - 20.0), 16, DIM)


func _draw_ball() -> void:
	var r := BALL_SIZE / 2.0
	draw_circle(ball_pos, r, COLOR)
	draw_circle(ball_pos + Vector2(-r, -r) * 0.35, r * 0.3, Color(1, 1, 1, 0.8))  # small highlight


## Draws text centered horizontally on `pos`.
func _text(text: String, pos: Vector2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(pos.x - width / 2.0, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
