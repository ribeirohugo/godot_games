extends "res://scripts/bot.gd"
## The brain of a HELIX creature. They see nearly all round and notice fast, never use guns, and run
## at what they want to kill.
##
##   infected  fast and frail; zigzags on the way in and leaps the last few meters
##   mutant    slow and huge; charges in a straight line when it has a clear run, and is winded after
##
## Modes: "roam" (shambles about near home), "sleep" (lies among the dead until something comes close
## or makes a noise, then gets up), "hunt" (knows where the player is: sent in by the mission).

const SENSES := {"react": 0.15, "error": 0.0, "settle": 10.0, "turn": 9.0, "comp": 0.0, "head": 0.0, "fov": -0.3, "spot": 0.35}

var kind := "infected"
var mode := "roam"
var home := Vector3.INF
var wander := Vector3.INF
var idle_t := 0.0
var rise_t := 0.0  # getting up
var leap_t := 0.0
var charge_t := 0.0  # until the next charge
var charging := 0.0  # a charge under way
var winded_t := 0.0
var voice_t := 0.0
var zig := 0.0


func setup(soldier, rules_ref, world_ref, skill_level: int) -> void:
	super.setup(soldier, rules_ref, world_ref, skill_level)
	skill = SENSES.duplicate()
	skill["spot"] = 0.45 - skill_level * 0.05


func begin(what: String, creature: String, at: Vector3) -> void:
	kind = creature
	mode = what
	home = at
	task = "chase"
	voice_t = randf_range(2.0, 8.0)
	leap_t = randf_range(0.5, 2.0)
	charge_t = randf_range(1.0, 3.0)
	zig = randf() * TAU
	if mode == "sleep":
		me.down = 1.0
		me.fall_dir = Basis(Vector3.UP, randf() * TAU) * Vector3.FORWARD
		me.death_t = 1.0
	elif mode == "hunt":
		last_seen = rules.human.position
		last_seen_t = 0.0


## Gets up (if asleep) and goes for the player.
func wake(hunt := true) -> void:
	if mode == "sleep":
		rise_t = randf_range(0.6, 1.4)
	mode = "hunt" if hunt else "roam"
	last_seen = rules.human.position
	last_seen_t = 0.0


func hear(pos: Vector3, source) -> void:
	super.hear(pos, source)
	if mode == "sleep" and me.position.distance_to(pos) < 14.0:
		wake(false)
		last_seen = pos
		last_seen_t = 0.0
	elif target == null:
		last_seen = pos
		last_seen_t = 0.0


func on_hurt(attacker) -> void:
	if mode == "sleep":
		wake(false)
	super.on_hurt(attacker)


func think(delta: float) -> void:
	me.move_input = Vector2.ZERO
	me.want_fire = false
	me.want_walk = false
	me.want_crouch = false
	me.want_jump = false
	me.speed_boost = 1.0
	last_seen_t += delta
	heard_t -= delta
	leap_t -= delta
	charge_t -= delta
	voice_t -= delta
	if mode == "runner":
		# Seen for a moment only: sprints to its mark and is gone.
		me.speed_boost = 1.6
		if _go(home, delta) or me.position.distance_to(home) < 1.5:
			rules.despawn(me)
		_turn(delta)
		return
	if mode == "sleep":
		# Lying among the dead: anyone who comes close, or looks away nearby, wakes it.
		var prey = rules.human
		if prey != null and prey.alive and me.position.distance_to(prey.position) < 5.5:
			wake(false)
		return
	if me.down > 0.0:
		rise_t -= delta
		if rise_t <= 0.0:
			me.down = maxf(me.down - delta * 1.3, 0.0)
			if me.down == 0.0:
				me.death_t = 0.0
				_voice(true)
		return
	if winded_t > 0.0:
		winded_t -= delta
		_turn(delta)
		return
	if me.flash_t > 0.5:
		me.move_input = Vector2(randf_range(-1, 1), randf_range(-1, 1))
		return
	_perceive(delta)
	if target != null:
		_attack(delta)
	else:
		_prowl(delta)
	_turn(delta)
	if voice_t <= 0.0:
		voice_t = randf_range(3.0, 7.0)
		if rules.human.position.distance_to(me.position) < 25.0:
			_voice(false)


func _voice(scream: bool) -> void:
	var sound := ("roar" if kind == "mutant" else "screech") if scream else ("growl" if kind == "mutant" else "moan")
	if me.game.sfx.sounds.has(sound):
		me.game.sfx.play_at(sound, me.eye_position(), 0.0 if scream else -6.0)


func _engage(enemy, extra: float) -> void:
	var fresh := target == null
	super._engage(enemy, extra)
	if fresh:
		_voice(true)


func _attack(delta: float) -> void:
	fighting = true
	var e = target
	if not e.alive:
		target = null
		return
	var to: Vector3 = e.position - me.position
	var flat := Vector3(to.x, 0, to.z)
	var d := flat.length()
	var dir := flat / maxf(d, 0.01)
	var reach: float = Weapons.data(me.current).get("reach", 2.0)
	var chest: Vector3 = e.position + Vector3(0, e.eye_height() * 0.7, 0) - me.eye_position()
	want_yaw = atan2(-to.x, -to.z)
	want_pitch = atan2(chest.y, Vector2(chest.x, chest.z).length())
	var sees := unseen_t == 0.0
	if kind == "mutant" and charging <= 0.0 and charge_t <= 0.0 and sees and d > 5.0 and d < 16.0 and world.walk_clear(me.position, e.position):
		charging = 1.4
		charge_t = randf_range(5.0, 8.0)
		_voice(true)
	if charging > 0.0:
		# Charging: head down, straight at them.
		charging -= delta
		me.speed_boost = 2.1
		me.move_input = Vector2(0, -1)
		if d < reach:
			e.take_hit(38.0, "chest", me, "maul", dir, 1.0)
			e.velocity += dir * 9.0 + Vector3.UP * 3.0
			if e == rules.human:
				me.game.shake(0.5)
			charging = 0.0
			winded_t = 0.8
		elif charging <= 0.0:
			winded_t = 1.2  # missed: stumbles
		return
	if d > reach * 0.8:
		_go(e.position, delta)
		# Infected come in zigzagging and leap the last stretch.
		if kind == "infected" and sees and d > 5.0:
			zig += delta * 3.0
			me.move_input += Vector2(sin(zig) * 0.6, 0)
		if kind == "infected" and sees and d > 2.5 and d < 6.5 and leap_t <= 0.0 and me.is_on_floor():
			leap_t = randf_range(2.5, 4.5)
			me.want_jump = true
			me.speed_boost = 1.8
			me.move_input = Vector2(0, -1)
			_voice(true)
		elif kind == "infected" and leap_t > 2.2:
			me.speed_boost = 1.8  # still in the air
	me.want_fire = d < reach and absf(angle_difference(me.yaw, want_yaw)) < 0.6


## No one to kill: go where they were last seen or heard, else shamble about home.
func _prowl(delta: float) -> void:
	if mode == "hunt" and rules.human.alive:
		last_seen = rules.human.position
		last_seen_t = 0.0
	if last_seen != Vector3.INF and last_seen_t < 12.0:
		if me.position.distance_to(last_seen) > 1.5:
			_go(last_seen, delta)
			return
		last_seen = Vector3.INF
	if home == Vector3.INF:
		home = me.position
	idle_t -= delta
	if idle_t <= 0.0:
		idle_t = randf_range(2.0, 6.0)
		wander = world.random_point_near(home, 4) if randf() < 0.6 else Vector3.INF
	if wander != Vector3.INF and me.position.distance_to(wander) > 1.0:
		_go(wander, delta)
		me.want_walk = true
	else:
		want_yaw += sin(Time.get_ticks_msec() / 300.0 + home.x) * delta * 1.5  # twitching
