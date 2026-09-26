extends "res://scripts/bot.gd"
## A soldier's brain in the campaign: the sector's rogue security, the Black Division, the army, and
## Mercer's own squad. It fights like a match bot (bot.gd: noticing, aim, bursts, strafing) but has
## no bomb to play for. Instead it has a mode:
##
##   guard    stands at its post, watching one way and glancing around; checks out noises
##   patrol   walks slowly between spots near its post, pausing now and then
##   hold     never leaves its post (snipers on towers, gunners behind sandbags)
##   hunt     knows roughly where the player is and goes for them (reinforcements)
##   follow   an ally: keeps a few meters from Mercer and fights at his side
##   wait     does nothing until woken by the mission (an ambush)
##
## Once it sees or hears a fight it is alerted: it calls nearby squadmates, searches where the enemy
## was last seen (some go the long way round, to flank), and runs for cover to reload or when hurt.

var post := Vector3.INF
var post_yaw := 0.0
var mode := "guard"
var awake := true
var alerted := false
var flanker := false
var leader  # who an ally follows
var patrol_to := Vector3.INF
var pause := 0.0
var cover := Vector3.INF
var cover_low := false
var cover_t := 0.0
var search_t := 0.0
var callout_t := 0.0


## Sets the soldier to `what` at spot `at`, watching `facing`.
func begin(what: String, at: Vector3, facing: float) -> void:
	mode = what
	post = at
	post_yaw = facing
	spot = at
	awake = mode != "wait"
	task = {"guard": "hold", "hold": "hold", "patrol": "hold", "hunt": "chase", "follow": "follow"}.get(mode, "hold")
	flanker = randf() < 0.35
	crouch_hold = mode == "hold" and randf() < 0.5
	want_yaw = facing
	me.yaw = facing
	start_t = 0.0
	nade_t = randf_range(4.0, 10.0)
	if mode == "hunt":
		alert(rules.human.position)


## Wakes an ambush, or sends it after the player.
func wake(hunt := true) -> void:
	awake = true
	if hunt:
		mode = "hunt"
		task = "chase"
		alert(rules.human.position)


## Something is going on at `pos`: go and look.
func alert(pos: Vector3) -> void:
	if mode == "follow":
		return
	alerted = true
	last_seen = pos
	last_seen_t = 0.0
	search_t = randf_range(10.0, 16.0)
	if mode == "guard" or mode == "patrol":
		mode = "hunt" if randf() < 0.6 else mode


func hear(pos: Vector3, source) -> void:
	super.hear(pos, source)
	if mode != "follow" and mode != "hold" and awake and target == null:
		if not alerted or search_t <= 0.0:
			alert(pos)


func _engage(enemy, extra: float) -> void:
	var first_contact := not alerted
	super._engage(enemy, extra)
	alerted = true
	search_t = randf_range(12.0, 18.0)
	if first_contact or callout_t <= 0.0:
		callout_t = 6.0
		rules.alert_squad(me, enemy.position)


func think(delta: float) -> void:
	callout_t -= delta
	search_t -= delta
	cover_t -= delta
	if not awake:
		me.move_input = Vector2.ZERO
		me.want_fire = false
		me.want_crouch = mode == "wait" and crouch_hold
		return
	super.think(delta)


func _fight(delta: float) -> void:
	super._fight(delta)
	if target == null:
		return
	if mode == "hold":
		me.move_input = Vector2.ZERO
		me.want_crouch = crouch_hold and not me.want_fire
		return
	# Out of rounds or badly hurt: get behind something first.
	if me.reload_t > 0.0 or retreat_t > 0.0 or (me.health < 45.0 and randf() < 0.01):
		_take_cover(delta)


## Runs to a spot the enemy can't see (crouching behind low cover counts), facing them all the way.
func _take_cover(delta: float) -> void:
	if target == null:
		return
	if cover == Vector3.INF or cover_t <= 0.0:
		cover_t = 1.5
		_find_cover(target.eye_position())
	if cover == Vector3.INF:
		return
	if me.position.distance_to(cover) > 0.8:
		_go(cover, delta)
	else:
		me.move_input = Vector2.ZERO
	me.want_crouch = cover_low


func _find_cover(threat: Vector3) -> void:
	cover = Vector3.INF
	var here: Vector2i = world.cell_of(me.position)
	var best := INF
	for i in 36:
		var c := here + Vector2i(randi_range(-5, 5), randi_range(-5, 5))
		if not world.astar.is_in_boundsv(c) or world.astar.is_point_solid(c):
			continue
		var p: Vector3 = world.center(c)
		var d: float = me.position.distance_to(p)
		if d > best or threat.distance_to(p) < 4.0:
			continue
		if not world.clear_line(threat, p + Vector3(0, 1.5, 0)):
			best = d
			cover = p
			cover_low = false
		elif not world.clear_line(threat, p + Vector3(0, 0.9, 0)):
			best = d
			cover = p
			cover_low = true


func _objective(delta: float) -> void:
	var cur := Weapons.data(me.current)
	if me.current == "" or cur["slot"] >= 3 and me.current != "he":
		me.equip(me.best_weapon())
	elif cur.has("mag") and me.mags[me.current] < cur["mag"] * 0.5 and me.reserves[me.current] > 0 and last_seen_t > 1.5:
		me.start_reload()
	if mode == "follow":
		_follow(delta)
		return
	# Searching: where the enemy was, or the long way round to flank them.
	if alerted and search_t > 0.0 and last_seen != Vector3.INF and mode != "hold":
		if last_seen_t < 6.0 and _throw_grenade(delta):
			return
		var goal := last_seen
		if flanker and me.position.distance_to(last_seen) > 10.0:
			var to: Vector3 = last_seen - me.position
			var side := Vector3(-to.z, 0, to.x).normalized() * 7.0
			var around: Vector3 = last_seen + side
			if not world.is_solid(world.cell_of(around)):
				goal = around
		if me.position.distance_to(goal) > 2.0:
			_go(goal, delta)
			me.want_walk = me.position.distance_to(goal) < 12.0 and level >= 1
			_look_ahead()
			return
		_look_around(delta)
		return
	match mode:
		"hunt":
			var prey = rules.human
			if prey != null and prey.alive and me.position.distance_to(prey.position) > 3.0:
				_go(prey.position, delta)
				_look_ahead()
			else:
				_look_around(delta)
		"patrol":
			_patrol(delta)
		_:
			if me.position.distance_to(post) > 1.2:
				_go(post, delta)
				me.want_walk = not alerted
			else:
				want_yaw = post_yaw
				want_pitch = 0.0
				_glance(delta, 0.6, 2.0, 4.5)
				want_yaw += glance
				me.want_crouch = crouch_hold
	if heard_t > 0.0 and heard != Vector3.INF:
		_look_at(heard + Vector3(0, 1.3, 0))


func _patrol(delta: float) -> void:
	if pause > 0.0:
		pause -= delta
		_glance(delta, 0.9, 1.0, 2.0)
		want_yaw += glance * delta
		return
	if patrol_to == Vector3.INF:
		patrol_to = world.random_point_near(post, 5)
	if _go(patrol_to, delta):
		patrol_to = Vector3.INF
		pause = randf_range(1.5, 4.0)
	me.want_walk = true


## An ally: stays a few meters from the leader, catches up when left behind.
func _follow(delta: float) -> void:
	if leader == null or not leader.alive:
		_look_around(delta)
		return
	var d: float = me.position.distance_to(leader.position)
	if d > 5.0:
		var behind: Vector3 = leader.position - (Basis(Vector3.UP, leader.yaw) * Vector3.FORWARD) * 2.5
		_go(behind if not world.is_solid(world.cell_of(behind)) else leader.position, delta)
		me.want_walk = d < 8.0 and not leader.is_moving()
		_look_ahead()
	else:
		# Close enough: watch where the leader is looking, a little off to one side.
		want_yaw = leader.yaw + (0.6 if hash(me.nick) % 2 == 0 else -0.6)
		want_pitch = 0.0
		_glance(delta, 0.7, 2.0, 4.0)
		want_yaw += glance
