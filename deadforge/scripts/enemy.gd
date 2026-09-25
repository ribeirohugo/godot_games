extends CharacterBody3D
## A demon of the foundry, built from boxes at runtime. It waits until it sees or hears the player,
## then chases: straight at the player while it can see them, otherwise along the level's flow field
## (world.path_target). Husks and Brutes claw; Cinders and the Forgelord also throw fireballs.

const Tex := preload("res://scripts/textures.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")

const STATS := {
	"husk": {"hp": 45.0, "speed": 3.4, "radius": 0.45, "height": 1.9, "melee": 10.0, "reach": 2.1,
			"ranged": 0.0, "cooldown": 1.0, "windup": 0.35, "pain": 0.7, "drop": ["n", 0.4]},
	"cinder": {"hp": 70.0, "speed": 3.8, "radius": 0.5, "height": 2.0, "melee": 8.0, "reach": 2.0,
			"ranged": 12.0, "cooldown": 1.8, "windup": 0.4, "pain": 0.5, "drop": ["s", 0.3]},
	"brute": {"hp": 300.0, "speed": 4.8, "radius": 0.8, "height": 2.7, "melee": 25.0, "reach": 2.8,
			"ranged": 0.0, "cooldown": 1.2, "windup": 0.45, "pain": 0.25, "drop": ["e", 0.5]},
	"boss": {"hp": 1800.0, "speed": 3.6, "radius": 1.1, "height": 3.6, "melee": 40.0, "reach": 3.4,
			"ranged": 14.0, "cooldown": 1.3, "windup": 0.5, "pain": 0.04, "drop": ["", 0.0]},
}
const DIFFICULTY_HP := [0.75, 1.0, 1.25]
const DIFFICULTY_DAMAGE := [0.5, 1.0, 1.5]
const SIGHT := 34.0  # meters an idle demon can spot the player from

var kind := "husk"
var world
var game
var stats: Dictionary
var hp := 1.0
var max_hp := 1.0
var speed := 1.0
var radius := 0.5
var height := 2.0
var damage_scale := 1.0
var alive := true
var alerted := false
var sees := false
var attack := ""  # "melee" or "ranged" while winding up
var attack_t := 0.0
var attack_cd := 1.0
var strike_t := 0.0  # arms swing down for a moment after a strike
var pain_t := 0.0
var flash_t := 0.0
var sight_t := 0.0
var light_t := 0.0
var growl_t := 0.0
var walk := 0.0
var death_t := 0.0
var volleys := 0
var blasts_left := 0  # the Forgelord goes out in a string of explosions
var blast_t := 0.0

var col: CollisionShape3D
var model: Node3D
var mats: Array[ShaderMaterial] = []
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hand: Node3D  # fireballs start here
var arm_rest := 0.2


func setup(world_ref, game_ref) -> void:
	world = world_ref
	game = game_ref
	stats = STATS[kind]
	var diff: int = game.difficulty
	max_hp = stats["hp"] * DIFFICULTY_HP[diff]
	hp = max_hp
	damage_scale = DIFFICULTY_DAMAGE[diff]
	speed = stats["speed"]
	radius = stats["radius"]
	height = stats["height"]
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = world.LAYER_ENEMY
	collision_mask = world.LAYER_WORLD | world.LAYER_PLAYER | world.LAYER_ENEMY
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col = CollisionShape3D.new()
	col.shape = shape
	col.position.y = height / 2.0
	add_child(col)
	model = Node3D.new()
	add_child(model)
	match kind:
		"husk":
			_build_husk()
		"cinder":
			_build_cinder()
		"brute":
			_build_brute("hide", Color.WHITE)
		"boss":
			_build_brute("char", Color(0.9, 0.8, 0.8))
			model.scale = Vector3.ONE * 1.33
	attack_cd = randf_range(0.6, 1.6)
	sight_t = randf() * 0.3
	_update_light()


# --- Model ---------------------------------------------------------------------------------

func _part(parent: Node3D, size: Vector3, pos: Vector3, texture: String, tint := Color.WHITE, glow := 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = Tex.box(size)
	var mat := Tex.material(texture, tint, glow)
	mats.append(mat)
	part.material_override = mat
	part.position = pos
	parent.add_child(part)
	return part


func _pivot(pos: Vector3, parent: Node3D = null) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	(parent if parent != null else model).add_child(pivot)
	return pivot


func _build_husk() -> void:
	arm_rest = 1.25  # arms reach out in front, zombie style
	for side in [-1, 1]:
		var leg := _pivot(Vector3(0.17 * side, 0.8, 0))
		_part(leg, Vector3(0.22, 0.8, 0.24), Vector3(0, -0.4, 0), "flesh", Color(0.6, 0.6, 0.6))
		var arm := _pivot(Vector3(0.4 * side, 1.48, -0.05))
		_part(arm, Vector3(0.16, 0.75, 0.18), Vector3(0, -0.36, 0), "flesh")
		_part(arm, Vector3(0.2, 0.12, 0.22), Vector3(0, -0.76, 0), "flesh", Color(0.5, 0.35, 0.35))
		if side < 0:
			leg_l = leg
			arm_l = arm
		else:
			leg_r = leg
			arm_r = arm
	var torso := _part(model, Vector3(0.62, 0.75, 0.36), Vector3(0, 1.18, 0), "flesh")
	torso.rotation.x = -0.2
	var head := _pivot(Vector3(0, 1.58, -0.12))
	_part(head, Vector3(0.36, 0.4, 0.36), Vector3(0, 0.18, 0), "flesh")
	_part(head, Vector3(0.26, 0.08, 0.04), Vector3(0, 0.05, -0.18), "plain", Color(0.25, 0.03, 0.03))
	for side in [-1, 1]:
		_part(head, Vector3(0.08, 0.05, 0.02), Vector3(0.08 * side, 0.24, -0.185), "glow", Color(1.0, 0.15, 0.05), 1.0)
	hand = arm_r


func _build_cinder() -> void:
	arm_rest = 0.3
	var skirt := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.38
	cone.bottom_radius = 0.06
	cone.height = 0.9
	skirt.mesh = cone
	var mat := Tex.material("char")
	mats.append(mat)
	skirt.material_override = mat
	skirt.position.y = 0.95
	model.add_child(skirt)
	var chest := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.42
	ball.height = 0.84
	chest.mesh = ball
	chest.material_override = mat
	chest.position.y = 1.45
	model.add_child(chest)
	var head := _pivot(Vector3(0, 1.82, 0))
	_part(head, Vector3(0.34, 0.34, 0.34), Vector3(0, 0.12, 0), "char")
	for side in [-1, 1]:
		var horn := _part(head, Vector3(0.06, 0.32, 0.06), Vector3(0.14 * side, 0.4, 0), "plain", Color(0.8, 0.74, 0.6))
		horn.rotation.z = -0.45 * side
		_part(head, Vector3(0.08, 0.05, 0.02), Vector3(0.08 * side, 0.16, -0.175), "glow", Color(1.0, 0.9, 0.2), 1.0)
		var arm := _pivot(Vector3(0.5 * side, 1.62, 0))
		_part(arm, Vector3(0.14, 0.6, 0.14), Vector3(0, -0.3, 0), "char")
		var palm := _part(arm, Vector3(0.2, 0.2, 0.2), Vector3(0, -0.66, 0), "glow", Color(1.0, 0.55, 0.1), 1.0)
		if side < 0:
			arm_l = arm
		else:
			arm_r = arm
			hand = palm


func _build_brute(skin: String, tint: Color) -> void:
	arm_rest = 0.15
	for side in [-1, 1]:
		var leg := _pivot(Vector3(0.32 * side, 1.1, 0))
		_part(leg, Vector3(0.4, 1.1, 0.45), Vector3(0, -0.55, 0), skin, tint.darkened(0.25))
		var arm := _pivot(Vector3(0.8 * side, 2.0, 0))
		_part(arm, Vector3(0.35, 1.0, 0.38), Vector3(0, -0.5, 0), skin, tint)
		var fist := _part(arm, Vector3(0.45, 0.4, 0.45), Vector3(0, -1.1, 0), "steel")
		_part(model, Vector3(0.45, 0.3, 0.6), Vector3(0.72 * side, 2.2, 0), "steel")
		if side < 0:
			leg_l = leg
			arm_l = arm
		else:
			leg_r = leg
			arm_r = arm
			hand = fist
	_part(model, Vector3(1.2, 1.0, 0.75), Vector3(0, 1.62, 0), skin, tint)
	_part(model, Vector3(0.8, 0.5, 0.1), Vector3(0, 1.45, -0.38), "steel")
	var head := _pivot(Vector3(0, 2.15, -0.2))
	_part(head, Vector3(0.5, 0.45, 0.5), Vector3(0, 0.22, -0.05), skin, tint)
	for side in [-1, 1]:
		var horn := _part(head, Vector3(0.1, 0.5, 0.1), Vector3(0.3 * side, 0.52, 0), "plain", Color(0.85, 0.8, 0.65))
		horn.rotation.z = -0.6 * side
		_part(head, Vector3(0.1, 0.06, 0.02), Vector3(0.12 * side, 0.28, -0.31), "glow", Color(1.0, 0.3, 0.05), 1.0)
	if kind == "boss":
		var core := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.28
		sphere.height = 0.56
		core.mesh = sphere
		core.material_override = Tex.material("lava", Color.WHITE, 1.0)
		core.material_override.set_shader_parameter("scroll", Vector2(0.3, 0.2))
		core.position = Vector3(0, 1.75, -0.36)
		model.add_child(core)
		# A forge hammer in the right fist.
		_part(arm_r, Vector3(0.12, 0.12, 1.5), Vector3(0, -1.1, -0.65), "steel")
		_part(arm_r, Vector3(0.7, 0.55, 0.45), Vector3(0, -1.1, -1.4), "steel", Color(0.7, 0.7, 0.7))
		_part(arm_r, Vector3(0.72, 0.57, 0.04), Vector3(0, -1.1, -1.64), "lava", Color.WHITE, 1.0)
		hand = core


# --- Behavior ------------------------------------------------------------------------------

func alert() -> void:
	if alerted or not alive:
		return
	alerted = true
	growl_t = randf_range(4.0, 9.0)
	game.sfx.play_at("growl_" + kind, position + Vector3(0, height * 0.8, 0))


func _can_see() -> bool:
	var p = world.player
	if not p.alive:
		return false
	return world.clear_line(position + Vector3(0, height * 0.8, 0), p.position + Vector3(0, 1.5, 0))


func _physics_process(delta: float) -> void:
	if not alive:
		return
	light_t -= delta
	if light_t <= 0.0:
		light_t = 0.2
		_update_light()
	var p = world.player
	var to: Vector3 = p.position - position
	to.y = 0.0
	var dist := to.length()
	if not alerted:
		sight_t -= delta
		if sight_t <= 0.0:
			sight_t = 0.3
			if dist < SIGHT and _can_see():
				alert()
		return
	sight_t -= delta
	if sight_t <= 0.0:
		sight_t = 0.2
		sees = _can_see()
	growl_t -= delta
	if growl_t <= 0.0:
		growl_t = randf_range(5.0, 11.0)
		game.sfx.play_at("growl_" + kind, position + Vector3(0, height * 0.8, 0))
	attack_cd -= delta
	strike_t -= delta
	if pain_t > 0.0:
		pain_t -= delta
		velocity = Vector3.ZERO
		return
	if not p.alive:
		velocity = Vector3.ZERO
		return
	if attack != "":
		attack_t -= delta
		_face(to, delta * 10.0)
		if attack_t <= 0.0:
			_strike(dist)
		return
	var ranged: float = stats["ranged"]
	if sees and dist < stats["reach"] + 0.3 and attack_cd <= 0.0:
		attack = "melee"
		attack_t = stats["windup"]
		return
	if ranged > 0.0 and sees and dist > 5.0 and dist < 36.0 and attack_cd <= 0.0 and randf() < delta * (3.0 if kind == "boss" else 1.6):
		attack = "ranged"
		attack_t = stats["windup"] + 0.2
		return
	var goal: Vector3 = p.position
	if not sees or _lava_ahead(to):
		goal = world.path_target(position)
	var dir := goal - position
	dir.y = 0.0
	if sees and dist < stats["reach"] * 0.75:
		dir = Vector3.ZERO  # close enough, don't shove the player
	if dir.length() > 0.1:
		velocity = dir.normalized() * speed
		_face(dir, delta * 8.0)
	else:
		velocity = Vector3.ZERO
		_face(to, delta * 8.0)
	move_and_slide()
	position.y = 0.0


func _lava_ahead(to: Vector3) -> bool:
	return world.char_at(world.cell_of(position + to.normalized() * 1.6)) == "~"


func _face(dir: Vector3, weight: float) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(weight, 0.0, 1.0))


func _strike(dist: float) -> void:
	var p = world.player
	if attack == "melee":
		strike_t = 0.25
		if dist <= stats["reach"] + 0.7 and sees:
			p.hurt(stats["melee"] * damage_scale, position)
			game.sfx.play_at("claw_hit", position + Vector3(0, 1.2, 0))
		else:
			game.sfx.play_at("claw", position + Vector3(0, 1.2, 0))
	else:
		strike_t = 0.25
		var from: Vector3 = hand.global_position
		var aim: Vector3 = (p.position + Vector3(0, 1.1, 0)) - from
		var shots := [0.0]
		if kind == "boss":
			volleys += 1
			shots = [-0.2, 0.0, 0.2] if volleys % 2 == 1 else [-0.3, -0.1, 0.1, 0.3]
		for angle: float in shots:
			var shot = ProjectileScript.new()
			world.add_child(shot)
			var speed_vector := aim.normalized().rotated(Vector3.UP, angle) * (19.0 if kind == "boss" else 15.0)
			shot.setup(world, from, speed_vector, stats["ranged"] * damage_scale, false, 0.0, 0.3 if kind == "boss" else 0.25, Color(1.0, 0.45, 0.1))
		game.sfx.play_at("fireball", from)
	attack = ""
	attack_cd = stats["cooldown"] * randf_range(0.8, 1.4)


func hurt(amount: float, _from := Vector3.ZERO) -> void:
	if not alive:
		return
	hp -= amount
	flash_t = 0.1
	alert()
	world.burst(position + Vector3(0, height * 0.6, 0), Color(0.5, 0.02, 0.02) if kind != "cinder" else Color(1.0, 0.5, 0.1),
			clampi(int(amount / 4.0), 3, 12), 4.0, 0.09, kind == "cinder")
	if hp <= 0.0:
		_die()
		return
	if randf() < stats["pain"] * clampf(amount / 15.0, 0.3, 1.0):
		pain_t = 0.3
		attack = ""
		game.sfx.play_at("pain_" + ("big" if kind in ["brute", "boss"] else "small"), position + Vector3(0, height * 0.8, 0))


func _die() -> void:
	alive = false
	attack = ""
	velocity = Vector3.ZERO
	collision_layer = 0
	col.set_deferred("disabled", true)
	game.sfx.play_at("death_" + ("big" if kind in ["brute", "boss"] else "small"), position + Vector3(0, height * 0.6, 0))
	world.on_enemy_killed(self)
	if kind == "boss":
		blasts_left = 6
	var drop: Array = stats["drop"]
	if drop[0] != "" and randf() < drop[1]:
		world.spawn_pickup(drop[0], position + Vector3(0, 0.45, 0), false)


func _update_light() -> void:
	var light: Color = world.light_level(position)
	var v := Vector3(light.r, light.g, light.b) * 1.25
	for mat in mats:
		mat.set_shader_parameter("light", v)


func _process(delta: float) -> void:
	if flash_t > 0.0:
		flash_t -= delta
		for mat in mats:
			mat.set_shader_parameter("flash", 0.6 if flash_t > 0.0 else 0.0)
	if not alive:
		blast_t -= delta
		if blasts_left > 0 and blast_t <= 0.0:
			blasts_left -= 1
			blast_t = 0.25
			world.explosion(position + Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 3.0), randf_range(-1.5, 1.5)), 1.6)
		death_t = minf(death_t + delta / 0.5, 1.0)
		var ease_t := 1.0 - pow(1.0 - death_t, 3.0)
		model.rotation.x = ease_t * PI * 0.48
		model.position.y = ease_t * 0.1 * model.scale.y
		if kind == "cinder":
			model.position.y = (1.0 - ease_t) * 0.3
		return
	var moving := velocity.length() > 0.3
	if moving:
		walk += delta * speed * 2.0
	var swing := sin(walk) * 0.6 if moving else 0.0
	if leg_l != null:
		leg_l.rotation.x = swing
		leg_r.rotation.x = -swing
	var arm := arm_rest - swing * 0.4
	var reach_up := 0.0
	if attack == "melee":
		reach_up = 1.6 * (1.0 - attack_t / stats["windup"])
	elif strike_t > 0.0:
		reach_up = -0.5
	arm_l.rotation.x = arm + swing * 0.8 + reach_up
	arm_r.rotation.x = arm - swing * 0.8 + reach_up
	if attack == "ranged":
		arm_r.rotation.x = lerpf(arm_r.rotation.x, 2.6, 1.0 - attack_t / (stats["windup"] + 0.2))
	if kind == "cinder":
		model.position.y = 0.3 + sin(Time.get_ticks_msec() / 300.0 + position.x) * 0.12
	model.rotation.x = -0.25 * pain_t / 0.3 if pain_t > 0.0 else 0.0
