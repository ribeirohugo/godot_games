extends RefCounted
## A bot's brain. Each physics step it fills in its soldier's controls (move, look, fire, use) the
## way a player would. It never reads what it couldn't know: enemies must be in its field of view with
## a clear line of sight (smoke blocks it), or be heard (shots, footsteps), or shoot it.
##
## Attackers follow one of the map's routes to the planned bomb site; the carrier plants, the others
## hold the site. Defenders split over both sites and watch the entrances; once the bomb is down
## everyone goes to it, defenders to defuse, attackers to guard it. Aim starts off by an error that
## settles over time, and firing waits for a reaction delay; both depend on the skill level.

const Weapons := preload("res://scripts/weapons.gd")

const SKILL := [
	{"react": 0.6, "error": 0.12, "settle": 2.5, "turn": 4.0, "comp": 0.25, "head": 0.1, "fov": 0.5},
	{"react": 0.4, "error": 0.08, "settle": 3.5, "turn": 6.0, "comp": 0.5, "head": 0.2, "fov": 0.42},
	{"react": 0.26, "error": 0.055, "settle": 5.0, "turn": 9.0, "comp": 0.75, "head": 0.35, "fov": 0.34},
	{"react": 0.17, "error": 0.035, "settle": 7.0, "turn": 13.0, "comp": 0.9, "head": 0.55, "fov": 0.25},
]
const SCAN := 0.12  # seconds between looks around for enemies
const LONG_GUNS := ["rifle", "ak", "m4", "scout", "sniper"]

var me  # soldier.gd
var rules
var world
var skill: Dictionary
var level := 1

var guard_site := "a"
var task := ""  # route, site, plant, hold, fetch, guard, retake, chase
var route: Array = []
var route_i := 0
var spot := Vector3.INF  # where this bot wants to stand
var watch := Vector3.INF  # what it watches while holding a spot
var start_t := 0.0
var path := PackedVector3Array()
var path_i := 0
var path_goal := Vector3.INF
var repath_t := 0.0
var stuck_t := 0.0
var stuck_from := Vector3.ZERO
var dodge_t := 0.0
var dodge := Vector2.ZERO

var target = null
var react_t := 0.0
var aim_err := Vector2.ZERO
var aim_head := false
var unseen_t := 0.0
var last_seen := Vector3.INF
var last_seen_t := 99.0
var scan_t := 0.0
var pause_t := 0.0
var tap_t := 0.0
var strafe_t := 0.0
var strafe_dir := 1.0
var heard := Vector3.INF
var heard_t := 0.0
var nade_t := 0.0
var crouch_hold := false

var want_yaw := 0.0
var want_pitch := 0.0
var fighting := false


func setup(soldier, rules_ref, world_ref, skill_level: int) -> void:
	me = soldier
	rules = rules_ref
	world = world_ref
	level = skill_level
	skill = SKILL[skill_level]


func new_round() -> void:
	target = null
	path = PackedVector3Array()
	path_goal = Vector3.INF
	last_seen = Vector3.INF
	last_seen_t = 99.0
	heard = Vector3.INF
	heard_t = 0.0
	watch = Vector3.INF
	start_t = randf_range(0.0, 2.5)
	nade_t = randf_range(3.0, 8.0)
	crouch_hold = randf() < 0.4
	want_yaw = me.yaw
	want_pitch = 0.0
	if me.team == "att":
		var routes: Array = world.data["routes"][rules.plan_site]
		route = routes[randi() % routes.size()]
		route_i = 0
		task = "route"
		spot = world.random_site_point(rules.plan_site)
	else:
		task = "hold"
		spot = world.defend_point(guard_site)


func on_planted() -> void:
	if not me.alive:
		return
	path_goal = Vector3.INF
	if me.team == "att":
		task = "guard"
		spot = world.random_point_near(rules.bomb_node.position, 4)
		watch = Vector3.INF
	else:
		task = "retake"


func on_bomb_dropped() -> void:
	if not me.alive or me.team != "att":
		return
	# The attacker bot nearest the bomb goes to get it.
	var bomb: Vector3 = rules.bomb_position()
	if bomb == Vector3.INF:
		return
	for s in rules.side_team("att"):
		if s != me and s.alive and s.brain != null and s.position.distance_to(bomb) < me.position.distance_to(bomb):
			return
	task = "fetch"
	path_goal = Vector3.INF


func rotate_to(site: String) -> void:
	guard_site = site
	if task == "hold":
		spot = world.defend_point(site)
		watch = Vector3.INF
		path_goal = Vector3.INF


func on_hurt(attacker) -> void:
	if target == null and attacker != null and attacker.alive and attacker.team != me.team:
		_engage(attacker, 0.25)
	last_seen = attacker.position if attacker != null else last_seen
	last_seen_t = 0.0


func on_blind() -> void:
	target = null


func hear(pos: Vector3, _source) -> void:
	if target == null:
		heard = pos
		heard_t = randf_range(1.5, 3.0)


# --- Thinking ------------------------------------------------------------------------------

func think(delta: float) -> void:
	me.move_input = Vector2.ZERO
	me.want_fire = false
	me.want_use = false
	me.want_walk = false
	me.want_crouch = false
	fighting = false
	last_seen_t += delta
	heard_t -= delta
	if me.frozen:
		want_yaw = me.yaw
		return
	if me.flash_t > 0.5:
		# Blinded: back off and wait.
		me.move_input = Vector2(0, 0.6)
		_turn(delta)
		return
	_perceive(delta)
	if target != null:
		_fight(delta)
	else:
		_objective(delta)
	_turn(delta)


func _perceive(delta: float) -> void:
	scan_t -= delta
	if scan_t > 0.0:
		return
	scan_t = SCAN
	var eye: Vector3 = me.eye_position()
	var facing: Vector3 = me.view_basis() * Vector3.FORWARD
	var best = null
	var best_d := INF
	for e in rules.enemies_of(me):
		if not e.alive:
			continue
		var head: Vector3 = e.eye_position()
		var d := eye.distance_to(head)
		if d > 80.0:
			continue
		var dir := (head - eye) / maxf(d, 0.01)
		if facing.dot(dir) < skill["fov"] and d > 3.0 and e != target:
			continue
		var chest: Vector3 = e.position + Vector3(0, e.eye_height() * 0.7, 0)
		if not world.clear_line(eye, head) and not world.clear_line(eye, chest):
			continue
		if world.smoke_between(eye, head):
			continue
		if d < best_d:
			best = e
			best_d = d
	if best != null:
		if best != target:
			_engage(best, 0.0 if target != null else 0.1)
		unseen_t = 0.0
		last_seen = best.position
		last_seen_t = 0.0
	elif target != null:
		unseen_t += SCAN
		if unseen_t > 0.6 or not target.alive:
			target = null


func _engage(enemy, extra: float) -> void:
	target = enemy
	unseen_t = 0.0
	react_t = skill["react"] * randf_range(0.8, 1.3) + extra
	var d: float = me.position.distance_to(enemy.position)
	var a := randf() * TAU
	aim_err = Vector2(cos(a), sin(a) * 0.6) * skill["error"] * (1.0 + d / 30.0)
	# Holding an angle: an enemy walking into the aim is shot sooner and straighter.
	var to: Vector3 = enemy.position - me.position
	var off := absf(angle_difference(me.yaw, atan2(-to.x, -to.z)))
	if not me.is_moving() and off < 0.35:
		react_t *= 0.55
		aim_err *= 0.5
	aim_head = randf() < skill["head"]
	pause_t = 0.0
	if me.team == "def":
		rules.report_contact(enemy.position, me)


func _fight(delta: float) -> void:
	fighting = true
	var e = target
	if not e.alive:
		target = null
		return
	_pick_weapon(e)
	var eye: Vector3 = me.eye_position()
	var point: Vector3 = e.eye_position() + Vector3(0, 0.02, 0) if aim_head else e.position + Vector3(0, e.eye_height() - 0.4, 0)
	if unseen_t > 0.0:
		point = last_seen + Vector3(0, 1.3, 0)
	point += e.velocity * 0.06
	aim_err *= exp(-delta * skill["settle"])
	var to := point - eye
	var flat := Vector2(to.x, to.z).length()
	want_yaw = atan2(-to.x, -to.z) + aim_err.x - me.punch.x * 2.0 * skill["comp"]
	want_pitch = atan2(to.y, flat) + aim_err.y - me.punch.y * 2.0 * skill["comp"]
	react_t -= delta
	var d := to.length()
	var off := absf(angle_difference(me.yaw, want_yaw)) + absf(me.pitch - want_pitch)
	var tolerance := maxf(0.012, atan(0.2 / maxf(d, 0.1)))
	var data := Weapons.data(me.current)
	var kind: String = data["kind"]
	var can_shoot: bool = react_t <= 0.0 and unseen_t == 0.0 and off < tolerance * 1.6
	# Keep defusing when there isn't time to fight first.
	if task == "retake" and me.defuse_t > 0.0 and rules.bomb_t < me.defuse_length() - me.defuse_t + 1.0:
		me.want_use = true
		return
	match kind:
		"knife":
			_go(e.position, delta)
			me.want_fire = d < 2.0
			return
		"sniper", "scout":
			if react_t <= 0.2 and me.scope == 0 and me.cooldown <= 0.0 and me.reload_t <= 0.0:
				me.toggle_scope()
			me.want_fire = can_shoot and me.scope > 0 and off < tolerance and me.cooldown <= 0.0
		"shotgun":
			me.want_fire = can_shoot and d < 16.0 and me.cooldown <= 0.0
		_:
			if data.get("auto", false):
				pause_t -= delta
				if pause_t <= 0.0 and can_shoot:
					me.want_fire = true
					var burst := 3 if d > 22.0 else (6 if d > 11.0 else 30)
					if me.shots >= burst:
						pause_t = randf_range(0.25, 0.45)
						me.want_fire = false
			else:
				tap_t -= delta
				if can_shoot and tap_t <= 0.0 and me.cooldown <= 0.0:
					me.want_fire = true
					tap_t = data["rate"] + (0.25 - level * 0.05)
	# Moving while fighting: long guns stand still to stay accurate, others strafe at a walk.
	if unseen_t > 0.0:
		if task != "hold" or me.position.distance_to(spot) < 10.0:
			_go(last_seen, delta)
		return
	if kind in LONG_GUNS:
		if level >= 2 and d > 18.0 and data.get("auto", false) and me.want_fire:
			me.want_crouch = true
	else:
		strafe_t -= delta
		if strafe_t <= 0.0:
			strafe_t = randf_range(0.35, 0.8)
			strafe_dir = -strafe_dir
		me.move_input = Vector2(strafe_dir, 0)
		me.want_walk = level >= 1


## Uses the best gun that still has rounds; reloads out of sight.
func _pick_weapon(_e) -> void:
	var cur := Weapons.data(me.current)
	if me.current == "" or cur["slot"] >= 3:
		me.equip(me.best_weapon())
		return
	if cur.has("mag") and me.mags[me.current] == 0 and me.reserves[me.current] == 0:
		for id in [me.primary, me.secondary]:
			if id != "" and id != me.current and (me.mags[id] > 0 or me.reserves[id] > 0):
				me.equip(id)
				return
		me.equip("knife")
	elif cur.has("mag") and me.mags[me.current] == 0 and level >= 2 and me.current == me.primary and me.secondary != "" and me.mags[me.secondary] > 0:
		me.equip(me.secondary)  # switching is faster than reloading


func _objective(delta: float) -> void:
	# Out of the fight: reload, then go about the plan.
	var cur := Weapons.data(me.current)
	var throwing: bool = me.current == "he" and last_seen_t < 5.0
	if me.current == "" or (cur["slot"] >= 3 and task != "plant" and not throwing):
		me.equip(me.best_weapon())
	elif cur.has("mag") and me.mags[me.current] < cur["mag"] * 0.4 and me.reserves[me.current] > 0 and last_seen_t > 1.5:
		me.start_reload()
	if last_seen_t < 5.0 and last_seen != Vector3.INF and task != "retake" and task != "plant":
		if _throw_grenade(delta):
			return
		# Chase the enemy a little way, unless guarding a spot.
		var near_post: bool = not (task in ["hold", "guard"]) or me.position.distance_to(spot) < 12.0
		if near_post and me.position.distance_to(last_seen) > 1.5:
			_go(last_seen, delta)
			_look_ahead()
			return
	start_t -= delta
	if start_t > 0.0 and me.team == "att" and task == "route":
		_look_around(delta)
		return
	match task:
		"route":
			if route_i >= route.size():
				task = "plant" if me.has_bomb else "site"
			elif _go(world.center(route[route_i]), delta):
				route_i += 1
			_look_ahead()
		"site", "guard", "hold":
			if task == "site" and me.has_bomb:
				task = "plant"
			elif me.position.distance_to(spot) > 1.0:
				_go(spot, delta)
				_look_ahead()
			else:
				_hold(delta)
		"plant":
			if not me.has_bomb:
				task = "site"
			elif world.site_at(me.position) != "" and me.position.distance_to(spot) < 3.0 or \
					world.site_at(me.position) == rules.plan_site and me.position.distance_to(spot) < 6.0:
				me.equip("bomb")
				me.want_fire = true
				me.want_crouch = true
			else:
				_go(spot, delta)
				_look_ahead()
		"fetch":
			var bomb: Vector3 = rules.bomb_position()
			if rules.bomb_state != "dropped" or bomb == Vector3.INF:
				task = "route" if not me.has_bomb else "plant"
				route_i = route.size()
			else:
				_go(bomb, delta)
				_look_ahead()
		"retake":
			if rules.bomb_state != "planted":
				_look_around(delta)
				return
			var bomb: Vector3 = rules.bomb_node.position
			if Vector2(bomb.x - me.position.x, bomb.z - me.position.z).length() > 0.9:
				_go(bomb, delta)
				_look_ahead()
			else:
				me.want_use = true
				me.want_crouch = true
				want_pitch = -0.5
		_:
			_look_around(delta)
	if heard_t > 0.0 and heard != Vector3.INF and task != "retake" and task != "plant":
		_look_at(heard + Vector3(0, 1.3, 0))


## Standing at a spot: watch the way enemies will come.
func _hold(_delta: float) -> void:
	if watch == Vector3.INF:
		var from_side := "att" if me.team == "def" else "def"
		var far: Vector3 = rules.centroid(world.spawns[from_side])
		var way: PackedVector3Array = world.find_path(me.position, far)
		watch = way[mini(6, way.size() - 1)] if way.size() > 0 else far
		watch.y = 1.4
	_look_at(watch)
	me.want_crouch = crouch_hold


## Lobs an HE grenade where the enemy was last seen.
func _throw_grenade(delta: float) -> bool:
	nade_t -= delta
	if not me.grenades.has("he") or nade_t > 0.0 and me.current != "he":
		return false
	var d: float = me.position.distance_to(last_seen)
	if d < 7.0 or d > 25.0:
		return false
	if me.current != "he":
		me.equip("he")
		return true
	var to: Vector3 = last_seen - me.position
	want_yaw = atan2(-to.x, -to.z)
	var v := 17.0
	want_pitch = clampf(0.5 * asin(clampf(d * 12.0 / (v * v), 0.0, 1.0)), 0.05, 0.7) - 0.1
	if absf(angle_difference(me.yaw, want_yaw)) < 0.05 and me.deploy_t <= 0.0:
		me.want_fire = true
		nade_t = randf_range(8.0, 15.0)
	return true


## Walks towards `to` along a path; returns true on arrival.
func _go(to: Vector3, delta: float) -> bool:
	repath_t -= delta
	if path_goal == Vector3.INF or path_goal.distance_to(to) > 1.5 or repath_t <= 0.0:
		path = world.find_path(me.position, to)
		path_i = 0
		path_goal = to
		repath_t = 3.0
	var skips := 0
	while path_i + 1 < path.size() and skips < 3 and world.walk_clear(me.position, path[path_i + 1]):
		path_i += 1
		skips += 1
	var flat_to := Vector3(to.x - me.position.x, 0, to.z - me.position.z)
	if path_i >= path.size() or flat_to.length() < 0.6:
		return true
	var p: Vector3 = path[path_i]
	var flat := Vector3(p.x - me.position.x, 0, p.z - me.position.z)
	if flat.length() < 0.5:
		path_i += 1
		if path_i >= path.size():
			return true
		p = path[path_i]
		flat = Vector3(p.x - me.position.x, 0, p.z - me.position.z)
	var dir := flat.normalized()
	var local := Basis(Vector3.UP, me.yaw).inverse() * dir
	me.move_input = Vector2(local.x, local.z)
	if not fighting:
		want_yaw = atan2(-dir.x, -dir.z)
		want_pitch = 0.0
	# Unstick: if it hasn't moved for a second, sidestep and jump, then find a new path.
	stuck_t += delta
	if dodge_t > 0.0:
		dodge_t -= delta
		me.move_input = dodge
	if stuck_t > 1.0:
		if me.position.distance_to(stuck_from) < 0.4:
			dodge = Vector2(randf_range(-1, 1), randf_range(-1, 0.5)).normalized()
			dodge_t = 0.4
			me.want_jump = true
			repath_t = 0.0
		stuck_t = 0.0
		stuck_from = me.position
	return false


func _look_ahead() -> void:
	if heard_t > 0.0 and heard != Vector3.INF:
		_look_at(heard + Vector3(0, 1.3, 0))


func _look_at(point: Vector3) -> void:
	var to: Vector3 = point - me.eye_position()
	want_yaw = atan2(-to.x, -to.z)
	want_pitch = atan2(to.y, Vector2(to.x, to.z).length())


func _look_around(delta: float) -> void:
	want_yaw += sin(Time.get_ticks_msec() / 900.0 + me.position.x) * delta * 0.6
	want_pitch = 0.0


func _turn(delta: float) -> void:
	var rate: float = skill["turn"] if fighting else 5.0
	var diff := absf(angle_difference(me.yaw, want_yaw))
	me.yaw = rotate_toward(me.yaw, want_yaw, rate * delta * (1.0 + diff))
	me.pitch = move_toward(me.pitch, clampf(want_pitch, -1.4, 1.4), rate * delta * 0.7)
