extends "res://scripts/bot.gd"
## The First: the one HELIX soldier that worked. Human-sized, fast and strong. He always knows where
## Mercer is. He keeps to a middle distance and strafes, firing bursts from his HX-1, dashes aside in
## a blur (more often as the fight goes on), strikes anyone who gets close and leaps at anyone who
## runs. The mission (mission.gd) sets his phase and, while he regenerates, the spot he guards.

var phase := 1
var anchor := Vector3.INF  # while regenerating he stays near the reactor
var dash_t := 2.0
var dashing := 0.0
var dash_dir := Vector2.ZERO
var strike_t := 0.0
var leap_t := 4.0
var burst := 0
var rest := 0.0
var voice_t := 3.0


func setup(soldier, rules_ref, world_ref, skill_level: int) -> void:
	super.setup(soldier, rules_ref, world_ref, clampi(skill_level + 1, 0, 3))


func think(delta: float) -> void:
	me.move_input = Vector2.ZERO
	me.want_fire = false
	me.want_walk = false
	me.want_crouch = false
	me.speed_boost = 1.0
	fighting = true
	dash_t -= delta
	strike_t -= delta
	leap_t -= delta
	rest -= delta
	voice_t -= delta
	if me.frozen:
		return
	var e = rules.human
	if e == null or not e.alive:
		_turn(delta)
		return
	target = e
	var eye: Vector3 = me.eye_position()
	var to: Vector3 = e.position - me.position
	var d := Vector2(to.x, to.z).length()
	var sees: bool = world.clear_line(eye, e.eye_position())
	var aim_at: Vector3 = e.position + Vector3(0, e.eye_height() - 0.35, 0) + e.velocity * 0.08 - eye
	var wobble := Vector2(sin(Time.get_ticks_msec() / 170.0), cos(Time.get_ticks_msec() / 230.0)) * (0.03 - phase * 0.005)
	want_yaw = atan2(-aim_at.x, -aim_at.z) + wobble.x
	want_pitch = atan2(aim_at.y, Vector2(aim_at.x, aim_at.z).length()) + wobble.y
	if voice_t <= 0.0:
		voice_t = randf_range(5.0, 9.0)
		if me.game.sfx.sounds.has("first"):
			me.game.sfx.play_at("first", eye, -2.0)
	# Up close: a blow that throws you back.
	if d < 2.4 and strike_t <= 0.0:
		strike_t = 1.3 - phase * 0.15
		me.since_shot = 0.0
		var dir := Vector3(to.x, 0, to.z).normalized()
		e.take_hit(26.0 + phase * 4.0, "chest", me, "claws", dir, 1.0)
		e.velocity += dir * 10.0 + Vector3.UP * 2.5
		me.game.sfx.play_at("claw_hit" if me.game.sfx.sounds.has("claw_hit") else "knife_hit", e.position + Vector3.UP)
		me.game.shake(0.6)
	# A dash: a blur to one side (or in, late in the fight), leaving a trail.
	if dashing > 0.0:
		dashing -= delta
		me.speed_boost = 3.4
		me.move_input = dash_dir
		world.puff(me.position + Vector3(0, 1.0, 0), Color(0.3, 0.85, 1.0, 0.35), 0.5, 0.4, 0.1)
		_turn(delta)
		return
	if dash_t <= 0.0:
		dash_t = randf_range(3.5, 6.0) - phase * 0.7
		dashing = 0.32
		var side := 1.0 if randf() < 0.5 else -1.0
		dash_dir = Vector2(side, -0.6 if d > 10.0 and phase >= 2 else 0.2).normalized()
		if me.game.sfx.sounds.has("dash"):
			me.game.sfx.play_at("dash", eye)
		return
	# Too far or out of sight: close in, leaping.
	if d > 18.0 or not sees:
		var goal: Vector3 = e.position if anchor == Vector3.INF else anchor
		if anchor != Vector3.INF and me.position.distance_to(anchor) < 5.0:
			goal = me.position
		if goal != me.position:
			_go(goal, delta)
		if leap_t <= 0.0 and sees and me.is_on_floor():
			leap_t = randf_range(3.0, 5.0)
			me.want_jump = true
			me.speed_boost = 2.2
			me.move_input = Vector2(0, -1)
	elif anchor != Vector3.INF and me.position.distance_to(anchor) > 6.0:
		_go(anchor, delta)
	else:
		# Middle distance: strafe, and step in or out to keep 8-14 m.
		strafe_t -= delta
		if strafe_t <= 0.0:
			strafe_t = randf_range(0.6, 1.4)
			strafe_dir = -strafe_dir
		var in_out := -0.6 if d > 14.0 else (0.6 if d < 8.0 else 0.0)
		me.move_input = Vector2(strafe_dir, in_out)
	# Bursts from the rifle.
	if sees and rest <= 0.0 and absf(angle_difference(me.yaw, want_yaw)) < 0.08:
		me.want_fire = true
		if me.shots >= 5 + phase:
			burst = 0
			rest = randf_range(0.5, 1.0) - phase * 0.08
			me.want_fire = false
	_turn(delta)


func _turn(delta: float) -> void:
	var rate := 10.0 + phase * 2.0
	var diff := absf(angle_difference(me.yaw, want_yaw))
	me.yaw = rotate_toward(me.yaw, want_yaw, rate * delta * (1.0 + diff))
	me.pitch = move_toward(me.pitch, clampf(want_pitch, -1.4, 1.4), rate * delta * 0.7)
