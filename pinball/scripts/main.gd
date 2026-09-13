extends Node2D
## Builds the pinball table and runs the game: launching, scoring, lights, tilt, lives.

const FlipperScript := preload("res://scripts/flipper.gd")
const BumperScript := preload("res://scripts/bumper.gd")
const SlingshotScript := preload("res://scripts/slingshot.gd")
const DropTargetScript := preload("res://scripts/drop_target.gd")
const TableArtScript := preload("res://scripts/table_art.gd")
const DmdScript := preload("res://scripts/dmd.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const TABLE_OFFSET := Vector2(0, 100)  # leaves room for the score display above the table
const BALL_RADIUS := 10.0
const BALL_START := Vector2(440, 760)
const LAUNCH_MIN := 500.0
const LAUNCH_MAX := 1400.0
const CHARGE_TIME := 1.0  # seconds to reach full launch power
const DRAIN_Y := 830.0
const START_LIVES := 3
const BALL_SAVE_TIME := 8.0
const NUDGE_FORCE := 140.0
const TILT_NUDGES := 4  # nudges within NUDGE_WINDOW that cause a TILT
const NUDGE_WINDOW := 4.0
const MAX_MULTIPLIER := 5
const LANE_X := [180.0, 240.0, 300.0]
const TARGET_X := [195.0, 240.0, 285.0]
const TARGET_Y := 430.0
const HIGH_SCORE_PATH := "user://highscore.cfg"

const RAIL_COLOR := Color(0.32, 0.34, 0.4)
const RAIL_SHINE := Color(0.9, 0.92, 1.0, 0.8)

var table: Node2D
var camera: Camera2D
var art
var dmd
var sfx
var ball: RigidBody2D
var ball_look: Node2D
var trail: Line2D
var flippers := []
var targets := []

var score := 0
var high_score := 0
var lives := START_LIVES
var multiplier := 1
var lane_lit := [false, false, false]
var charge := 0.0
var ball_in_play := false
var ball_save := 0.0
var ball_save_ready := true  # one ball save per ball
var tilted := false
var nudge_times := []
var nudge_was_pressed := false
var target_reset_timer := 0.0
var shake := 0.0
var clock := 0.0
var game_over := false


func _ready() -> void:
	_load_high_score()

	camera = Camera2D.new()
	camera.position = Vector2(240, 450)
	add_child(camera)

	table = Node2D.new()
	table.position = TABLE_OFFSET
	add_child(table)

	art = Node2D.new()
	art.set_script(TableArtScript)
	art.set("game", self)
	table.add_child(art)

	trail = Line2D.new()
	trail.width = 14
	trail.gradient = Gradient.new()
	trail.gradient.set_color(0, Color(0.7, 0.8, 1, 0))
	trail.gradient.set_color(1, Color(0.7, 0.8, 1, 0.35))
	table.add_child(trail)

	_build_walls()
	_build_lanes()
	_build_bumpers()
	_build_targets()
	_build_slingshots()
	_build_flippers()

	sfx = Node.new()
	sfx.set_script(SfxScript)
	add_child(sfx)

	var layer := CanvasLayer.new()
	add_child(layer)
	dmd = Control.new()
	dmd.set_script(DmdScript)
	layer.add_child(dmd)

	_spawn_ball()
	_update_display()
	dmd.show_message("SHOOT THE BALL", 3.0)


# ---------------------------------------------------------------- building

func _add_wall(points: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	body.physics_material_override = _material(0.3, 0.1)
	for i in points.size() - 1:
		var seg := SegmentShape2D.new()
		seg.a = points[i]
		seg.b = points[i + 1]
		var col := CollisionShape2D.new()
		col.shape = seg
		body.add_child(col)
	# Metal rail: a wide dark line with a thin shiny line on top.
	for style in [[8.0, RAIL_COLOR], [2.5, RAIL_SHINE]]:
		var line := Line2D.new()
		line.points = points
		line.width = style[0]
		line.default_color = style[1]
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		body.add_child(line)
	table.add_child(body)


func _build_walls() -> void:
	# Outer boundary, including the rounded top and the right shooter lane.
	_add_wall(PackedVector2Array([
		Vector2(20, 590), Vector2(20, 110), Vector2(45, 55), Vector2(100, 25),
		Vector2(380, 25), Vector2(435, 50), Vector2(460, 100), Vector2(460, 780),
		Vector2(420, 780), Vector2(420, 170),
	]))
	# Inlane slopes that guide the ball to the flippers.
	# They end tucked under the flipper base so the ball rolls smoothly onto it.
	_add_wall(PackedVector2Array([Vector2(20, 590), Vector2(160, 692)]))
	_add_wall(PackedVector2Array([Vector2(420, 590), Vector2(320, 692)]))


func _build_lanes() -> void:
	# Short guide posts between the three top lanes.
	for x in [150.0, 210.0, 270.0, 330.0]:
		_add_wall(PackedVector2Array([Vector2(x, 72), Vector2(x, 112)]))
	# Invisible sensors that notice the ball rolling through each lane.
	for i in 3:
		var area := Area2D.new()
		area.position = Vector2(LANE_X[i], 95)
		var rect := RectangleShape2D.new()
		rect.size = Vector2(24, 16)
		var col := CollisionShape2D.new()
		col.shape = rect
		area.add_child(col)
		area.body_entered.connect(_on_lane_entered.bind(i))
		table.add_child(area)


func _build_bumpers() -> void:
	for pos in [Vector2(160, 220), Vector2(300, 220), Vector2(230, 320)]:
		var bumper := StaticBody2D.new()
		bumper.set_script(BumperScript)
		bumper.position = pos
		table.add_child(bumper)


func _build_targets() -> void:
	for x in TARGET_X:
		var target := StaticBody2D.new()
		target.set_script(DropTargetScript)
		target.position = Vector2(x, TARGET_Y)
		target.physics_material_override = _material(0.4, 0.1)
		target.connect("knocked_down", _on_target_down)
		table.add_child(target)
		targets.append(target)


func _build_slingshots() -> void:
	var shapes := [
		PackedVector2Array([Vector2(65, 500), Vector2(65, 590), Vector2(120, 630)]),
		PackedVector2Array([Vector2(375, 500), Vector2(375, 590), Vector2(320, 630)]),
	]
	for points in shapes:
		var sling := StaticBody2D.new()
		sling.set_script(SlingshotScript)
		sling.set("points", points)
		table.add_child(sling)


func _build_flippers() -> void:
	for data in [[Vector2(145, 695), true], [Vector2(335, 695), false]]:
		var flipper := AnimatableBody2D.new()
		flipper.set_script(FlipperScript)
		flipper.set("is_left", data[1])
		flipper.position = data[0]
		flipper.connect("flipped", _on_flipped)
		table.add_child(flipper)
		flippers.append(flipper)


func _spawn_ball() -> void:
	ball = RigidBody2D.new()
	ball.position = BALL_START
	# Cast-ray CCD stops tunneling; cast-shape mode glitched at wall joints in testing.
	ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	ball.physics_material_override = _material(0.3, 0.05)
	ball.contact_monitor = true
	ball.max_contacts_reported = 4
	ball.body_entered.connect(_on_ball_hit)
	var circle := CircleShape2D.new()
	circle.radius = BALL_RADIUS
	var col := CollisionShape2D.new()
	col.shape = circle
	ball.add_child(col)
	ball_look = Node2D.new()
	ball_look.draw.connect(_draw_ball)
	ball.add_child(ball_look)
	table.add_child(ball)

	charge = 0.0
	ball_in_play = false
	trail.clear_points()
	nudge_times.clear()


func _draw_ball() -> void:
	ball_look.draw_circle(Vector2(3, 4), BALL_RADIUS, Color(0, 0, 0, 0.35))
	ball_look.draw_circle(Vector2.ZERO, BALL_RADIUS, Color(0.42, 0.44, 0.5))
	ball_look.draw_circle(Vector2(-1, -1), BALL_RADIUS - 2, Color(0.72, 0.74, 0.8))
	ball_look.draw_circle(Vector2(2, 3), BALL_RADIUS - 6, Color(0.55, 0.57, 0.63))
	ball_look.draw_circle(Vector2(-3.5, -3.5), 3.2, Color(1, 1, 1, 0.95))


func _material(bounce: float, friction: float) -> PhysicsMaterial:
	var mat := PhysicsMaterial.new()
	mat.bounce = bounce
	mat.friction = friction
	return mat


# ---------------------------------------------------------------- gameplay

func _process(delta: float) -> void:
	shake = move_toward(shake, 0.0, delta * 40.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	if is_instance_valid(ball):
		# Keep the ball's highlight fixed even though the physics body spins.
		ball_look.global_rotation = 0.0


func _physics_process(delta: float) -> void:
	clock += delta
	if game_over:
		if Input.is_physical_key_pressed(KEY_ENTER):
			_restart()
		return

	_handle_plunger(delta)
	_handle_nudge()

	if not ball_in_play and ball.position.x < 415:
		ball_in_play = true
		if ball_save_ready:
			ball_save = BALL_SAVE_TIME
			ball_save_ready = false
	ball_save = maxf(ball_save - delta, 0.0)

	trail.add_point(ball.position)
	if trail.get_point_count() > 12:
		trail.remove_point(0)

	if target_reset_timer > 0.0:
		target_reset_timer -= delta
		if target_reset_timer <= 0.0:
			if absf(ball.position.y - TARGET_Y) < 35 and absf(ball.position.x - 240) < 75:
				target_reset_timer = 0.2  # ball is in the way, try again shortly
			else:
				for target in targets:
					target.reset()

	if ball.position.y > DRAIN_Y:
		_on_drain()


func _handle_plunger(delta: float) -> void:
	# Hold Space (or Down) while the ball sits in the shooter lane.
	var charging := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_DOWN)
	if _ball_in_launcher():
		if charging:
			charge = minf(charge + delta / CHARGE_TIME, 1.0)
		elif charge > 0.0:
			ball.apply_central_impulse(Vector2.UP * lerpf(LAUNCH_MIN, LAUNCH_MAX, charge))
			sfx.play("launch")
			charge = 0.0
	else:
		charge = 0.0


func _ball_in_launcher() -> bool:
	return ball.position.x > 420 and ball.position.y > 700 and ball.linear_velocity.length() < 30


func _handle_nudge() -> void:
	var pressed := Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)
	if pressed and not nudge_was_pressed and ball_in_play and not tilted:
		_nudge()
	nudge_was_pressed = pressed


func _nudge() -> void:
	ball.apply_central_impulse(Vector2(randf_range(-60, 60), -NUDGE_FORCE))
	shake = 9.0
	sfx.play("nudge")
	nudge_times.append(clock)
	nudge_times = nudge_times.filter(func(t): return clock - t < NUDGE_WINDOW)
	if nudge_times.size() >= TILT_NUDGES:
		_tilt()
	elif nudge_times.size() == TILT_NUDGES - 1:
		dmd.show_message("DANGER", 1.5)


func _tilt() -> void:
	tilted = true
	for flipper in flippers:
		flipper.enabled = false
	sfx.play("tilt")
	dmd.show_message("TILT", 1e9)


func _on_flipped(is_left: bool) -> void:
	sfx.play("flipper")
	# Flippers shift the lit lanes, so players can line up the unlit one.
	if is_left:
		lane_lit = [lane_lit[1], lane_lit[2], lane_lit[0]]
	else:
		lane_lit = [lane_lit[2], lane_lit[0], lane_lit[1]]


func _on_ball_hit(body: Node) -> void:
	if tilted or not body is Node2D:
		return
	var push: Vector2 = ball.global_position - (body as Node2D).global_position
	if body.is_in_group("bumper"):
		ball.apply_central_impulse(push.normalized() * 450)
		body.call("flash")
		sfx.play("bumper")
		shake = maxf(shake, 3.0)
		_add_score(100)
	elif body.is_in_group("sling"):
		# Slings kick the ball up and toward the middle of the table.
		var dir := Vector2(1 if ball.position.x < 240 else -1, -0.6).normalized()
		ball.apply_central_impulse(dir * 350)
		body.call("flash")
		sfx.play("sling")
		_add_score(50)
	elif body.is_in_group("drop_target"):
		body.call("hit")


func _on_target_down() -> void:
	sfx.play("target")
	_add_score(500)
	if targets.all(func(t): return t.is_down):
		_add_score(5000)
		sfx.play("bonus")
		dmd.show_message("TARGETS 5,000", 2.0)
		target_reset_timer = 1.5


func _on_lane_entered(body: Node, lane: int) -> void:
	if body != ball or tilted:
		return
	if lane_lit[lane]:
		_add_score(50)
		return
	lane_lit[lane] = true
	sfx.play("lane")
	_add_score(250)
	if lane_lit.all(func(lit): return lit):
		lane_lit = [false, false, false]
		multiplier = mini(multiplier + 1, MAX_MULTIPLIER)
		sfx.play("bonus")
		dmd.show_message("MULTIPLIER %dx" % multiplier, 2.0)
		_update_display()


func _add_score(points: int) -> void:
	score += points * multiplier
	_update_display()


func _on_drain() -> void:
	ball.queue_free()
	if ball_save > 0.0 and not tilted:
		ball_save = 0.0
		sfx.play("bonus")
		dmd.show_message("BALL SAVED", 2.0)
		_spawn_ball()
		return

	sfx.play("drain")
	lives -= 1
	ball_save = 0.0
	ball_save_ready = true
	multiplier = 1
	if tilted:
		tilted = false
		dmd.clear_message()
	for flipper in flippers:
		flipper.enabled = true

	if lives <= 0:
		_game_over()
	else:
		dmd.show_message("BALL %d" % (START_LIVES - lives + 1), 2.0)
		_spawn_ball()
	_update_display()


func _game_over() -> void:
	game_over = true
	for flipper in flippers:
		flipper.enabled = false
	if score > high_score:
		high_score = score
		_save_high_score()
		dmd.show_message("NEW HIGH SCORE", 1e9)
	else:
		dmd.show_message("GAME OVER", 1e9)


func _restart() -> void:
	score = 0
	lives = START_LIVES
	multiplier = 1
	lane_lit = [false, false, false]
	game_over = false
	ball_save_ready = true
	for flipper in flippers:
		flipper.enabled = true
	for target in targets:
		target.reset()
	_spawn_ball()
	dmd.show_message("SHOOT THE BALL", 3.0)
	_update_display()


func _update_display() -> void:
	dmd.set_score(score)
	if game_over:
		dmd.set_info("PRESS ENTER TO PLAY AGAIN")
	else:
		dmd.set_info("BALL %d/%d      %dx      HIGH %s" % [
			START_LIVES - lives + 1, START_LIVES, multiplier, dmd.format_number(high_score)])


func _load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(HIGH_SCORE_PATH) == OK:
		high_score = int(cfg.get_value("scores", "high", 0))


func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "high", high_score)
	cfg.save(HIGH_SCORE_PATH)
