extends CharacterBody3D
## The player: walks, looks around, picks things up and fires the four weapons.
## Guns are hitscan rays; the Slag Cannon throws a projectile that bursts. Armor soaks up a third of
## every hit while it lasts. The weapon on screen is drawn by hud.gd from the state kept here.

const ProjectileScript := preload("res://scripts/projectile.gd")

const SPEED := 8.5
const ACCEL := 70.0
const EYE := 1.6
const MAX_HEALTH := 100.0
const MAX_ARMOR := 200.0
const WEAPONS := [
	{"id": "hammer", "ammo": "", "delay": 0.5, "damage": [22.0, 36.0], "range": 2.8},
	{"id": "rivet", "ammo": "rivets", "delay": 0.25, "damage": [10.0, 15.0], "spread": 0.012, "pellets": 1},
	{"id": "scatter", "ammo": "shells", "delay": 0.9, "damage": [6.0, 10.0], "spread": 0.075, "pellets": 8},
	{"id": "slag", "ammo": "slag", "delay": 0.75, "damage": [85.0, 110.0], "splash": 4.5},
]
const AUTO_ORDER := [2, 1, 3, 0]  # weapon picked when the current one runs dry
const MAX_AMMO := {"rivets": 200, "shells": 50, "slag": 50}
const PICKUP_AMMO := {"n": ["rivets", 20], "s": ["shells", 8], "e": ["slag", 8]}
const NEW_WEAPON := {"S": [2, "shells", 8, "weapon_scatter"], "F": [3, "slag", 10, "weapon_slag"]}

var world
var game
var camera: Camera3D
var health := MAX_HEALTH
var armor := 0.0
var owned := [true, true, false, false]
var ammo := {"rivets": 50, "shells": 0, "slag": 0}
var weapon := 1
var next_weapon := -1
var lower := 0.0  # 0 weapon raised, 1 fully lowered while switching
var cooldown := 0.0
var since_shot := 10.0  # seconds since the last shot: recoil and muzzle flash
var keys := {}
var alive := true
var pitch := 0.0
var bob := 0.0
var bob_amount := 0.0
var shake := 0.0
var lava_t := 0.0
var pain_t := 0.0
var hurt_flash := 0.0
var bonus_flash := 0.0


func setup(world_ref, game_ref, carry: Dictionary, yaw: float) -> void:
	world = world_ref
	game = game_ref
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = world.LAYER_PLAYER
	collision_mask = world.LAYER_WORLD | world.LAYER_ENEMY
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	camera = Camera3D.new()
	camera.position.y = EYE
	camera.fov = 78.0
	camera.near = 0.05
	camera.far = 150.0
	add_child(camera)
	camera.current = true
	rotation.y = yaw
	if not carry.is_empty():
		health = carry["health"]
		armor = carry["armor"]
		owned = carry["owned"].duplicate()
		ammo = carry["ammo"].duplicate()
		weapon = carry["weapon"]


## What carries over to the next level.
func snapshot() -> Dictionary:
	return {"health": health, "armor": armor, "owned": owned.duplicate(), "ammo": ammo.duplicate(),
			"weapon": next_weapon if next_weapon >= 0 else weapon}


func _unhandled_input(event: InputEvent) -> void:
	if not alive or game.state != "playing":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var turn: float = game.mouse_sensitivity * 0.0005
		rotation.y -= event.relative.x * turn
		pitch -= event.relative.y * turn * (-1.0 if game.invert_y else 1.0)
		pitch = clampf(pitch, -1.35, 1.35)
	for i in WEAPONS.size():
		if event.is_action_pressed("weapon_%d" % (i + 1)):
			select(i)
	if event.is_action_pressed("next_weapon"):
		cycle(1)
	elif event.is_action_pressed("prev_weapon"):
		cycle(-1)


func _physics_process(delta: float) -> void:
	hurt_flash = move_toward(hurt_flash, 0.0, delta * 1.5)
	bonus_flash = move_toward(bonus_flash, 0.0, delta * 2.0)
	shake = move_toward(shake, 0.0, delta * 2.0)
	camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.06
	camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.06
	if not alive:
		# Slump to the floor.
		camera.position.y = move_toward(camera.position.y, 0.35, delta * 2.5)
		camera.rotation.z = move_toward(camera.rotation.z, 0.5, delta * 1.2)
		camera.rotation.x = move_toward(camera.rotation.x, 0.2, delta)
		return
	pain_t -= delta
	# Right stick look, with a curve so small tilts aim finely.
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO:
		stick *= stick.length()
		var rate: float = 0.9 + game.stick_sensitivity * 0.35
		rotation.y -= stick.x * rate * delta
		pitch -= stick.y * rate * 0.6 * delta * (-1.0 if game.invert_y else 1.0)
		pitch = clampf(pitch, -1.35, 1.35)
	camera.rotation.x = pitch
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := transform.basis * Vector3(input.x, 0.0, input.y)
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * SPEED, ACCEL * delta)
	velocity = flat
	move_and_slide()
	position.y = 0.0
	var moving := Vector2(velocity.x, velocity.z).length()
	bob_amount = move_toward(bob_amount, clampf(moving / SPEED, 0.0, 1.0), delta * 4.0)
	bob += delta * moving * 0.9
	camera.position.y = EYE + sin(bob * 2.0) * 0.06 * bob_amount
	if world.char_at(world.cell_of(position)) == "~":
		lava_t -= delta
		if lava_t <= 0.0:
			lava_t = 0.6
			game.sfx.play("sizzle")
			hurt(5.0 * (0.6 if game.difficulty == 0 else 1.0), Vector3.ZERO)
	else:
		lava_t = 0.2
	_update_weapon(delta)


# --- Weapons -------------------------------------------------------------------------------

func select(index: int) -> void:
	if not owned[index] or index == (next_weapon if next_weapon >= 0 else weapon):
		return
	next_weapon = index
	game.sfx.play("switch")


func cycle(step: int) -> void:
	var from: int = next_weapon if next_weapon >= 0 else weapon
	var i := from
	for n in WEAPONS.size():
		i = posmod(i + step, WEAPONS.size())
		if owned[i] and _has_ammo(i):
			select(i)
			return


func _has_ammo(index: int) -> bool:
	var kind: String = WEAPONS[index]["ammo"]
	return kind == "" or ammo[kind] > 0


func _auto_switch() -> void:
	for i: int in AUTO_ORDER:
		if owned[i] and _has_ammo(i):
			select(i)
			return


func _update_weapon(delta: float) -> void:
	cooldown -= delta
	since_shot += delta
	if next_weapon >= 0:
		lower = move_toward(lower, 1.0, delta * 6.0)
		if lower >= 1.0:
			weapon = next_weapon
			next_weapon = -1
	else:
		lower = move_toward(lower, 0.0, delta * 6.0)
	if next_weapon < 0 and lower < 0.25 and cooldown <= 0.0 and Input.is_action_pressed("fire"):
		_fire()


func _fire() -> void:
	var w: Dictionary = WEAPONS[weapon]
	var kind: String = w["ammo"]
	if kind != "":
		if ammo[kind] <= 0:
			game.sfx.play("dry")
			cooldown = 0.35
			_auto_switch()
			return
		ammo[kind] -= 1
	cooldown = w["delay"]
	since_shot = 0.0
	var origin := camera.global_position
	var basis_now := camera.global_transform.basis
	var forward := -basis_now.z
	var damage: Array = w["damage"]
	game.sfx.play(w["id"])
	match w["id"]:
		"hammer":
			_swing(origin, forward, randf_range(damage[0], damage[1]), w["range"])
			world.alert_near(position, 6.0)
		"slag":
			var shot = ProjectileScript.new()
			world.add_child(shot)
			var start := origin + forward * 1.1 - basis_now.y * 0.3
			shot.setup(world, start, forward * 30.0, randf_range(damage[0], damage[1]), true, w["splash"], 0.22, Color(1.0, 0.6, 0.15))
			world.alert_near(position, 30.0)
		_:
			var spread: float = w["spread"]
			for i in int(w["pellets"]):
				var dir := (forward + basis_now.x * randf_range(-spread, spread) + basis_now.y * randf_range(-spread, spread) * 0.6).normalized()
				_shoot_ray(origin, dir, randf_range(damage[0], damage[1]))
			world.alert_near(position, 30.0)
			shake = maxf(shake, 0.25 if w["id"] == "scatter" else 0.08)
	if kind != "" and ammo[kind] <= 0:
		_auto_switch()


func _ray(origin: Vector3, dir: Vector3, length: float) -> Dictionary:
	var mask: int = world.LAYER_WORLD | world.LAYER_ENEMY | world.LAYER_SURFACE
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * length, mask)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _shoot_ray(origin: Vector3, dir: Vector3, damage: float) -> void:
	var hit := _ray(origin, dir, 150.0)
	if hit.is_empty():
		return
	var target = hit["collider"]
	var at: Vector3 = hit["position"]
	if target != null and target.has_method("hurt"):
		target.hurt(damage, position)
	else:
		world.burst(at + hit["normal"] * 0.1, Color(1.0, 0.8, 0.4), 3, 4.0, 0.06, true)


## The hammer hits what's straight ahead, or failing that the nearest demon just in front.
func _swing(origin: Vector3, forward: Vector3, damage: float, reach: float) -> void:
	var hit := _ray(origin, forward, reach)
	var target = hit.get("collider")
	if target == null or not target.has_method("hurt"):
		var best_angle := 0.45
		for enemy in world.enemies:
			if not enemy.alive:
				continue
			var to: Vector3 = enemy.position + Vector3(0, 1.0, 0) - origin
			var flat := Vector3(to.x, 0, to.z)
			if flat.length() > reach + enemy.radius:
				continue
			var angle := flat.angle_to(Vector3(forward.x, 0, forward.z))
			if angle < best_angle:
				best_angle = angle
				target = enemy
	if target != null and target.has_method("hurt"):
		target.hurt(damage, position)
		game.sfx.play("hammer_hit")
		shake = maxf(shake, 0.2)
	elif not hit.is_empty():
		world.burst(hit["position"] + hit["normal"] * 0.1, Color(1.0, 0.7, 0.3), 5, 4.0, 0.06, true)
		game.sfx.play("hammer_wall")


# --- Pickups and damage --------------------------------------------------------------------

## Takes a pickup if it's any use; returns false to leave it lying there.
func take(kind: String) -> bool:
	var text := ""
	var sound := "pickup"
	match kind:
		"+":
			if health >= MAX_HEALTH:
				return false
			health = minf(health + 25.0, MAX_HEALTH)
			text = tr("got_medkit")
		"a":
			if armor >= MAX_ARMOR:
				return false
			armor = minf(armor + 50.0, MAX_ARMOR)
			text = tr("got_armor")
		"n", "s", "e":
			var ammo_kind: String = PICKUP_AMMO[kind][0]
			if ammo[ammo_kind] >= MAX_AMMO[ammo_kind]:
				return false
			var had: int = ammo[ammo_kind]
			ammo[ammo_kind] = mini(had + PICKUP_AMMO[kind][1], MAX_AMMO[ammo_kind])
			text = tr("got_" + ammo_kind)
			if had == 0 and weapon == 0:
				_auto_switch()
		"S", "F":
			var info: Array = NEW_WEAPON[kind]
			var index: int = info[0]
			ammo[info[1]] = mini(ammo[info[1]] + info[2], MAX_AMMO[info[1]])
			text = tr("got_weapon") % tr(info[3])
			sound = "weapon_pickup"
			if not owned[index]:
				owned[index] = true
				select(index)
		"r", "b":
			var color := "red" if kind == "r" else "blue"
			keys[color] = true
			text = tr("got_%s_key" % color)
			sound = "key"
	bonus_flash = 0.45
	game.sfx.play(sound)
	game.message(text)
	return true


func hurt(amount: float, _from: Vector3) -> void:
	if not alive or amount <= 0.0:
		return
	var soaked := 0.0
	if armor > 0.0:
		soaked = minf(armor, amount / 3.0)
		armor -= soaked
	health -= amount - soaked
	hurt_flash = minf(hurt_flash + amount / 25.0, 1.0)
	shake = maxf(shake, clampf(amount / 30.0, 0.15, 0.8))
	game.vibrate(clampf(amount / 30.0, 0.2, 1.0), 0.18)
	if health <= 0.0:
		health = 0.0
		alive = false
		velocity = Vector3.ZERO
		game.sfx.play("player_death")
		game.on_player_died()
		return
	if pain_t <= 0.0:
		pain_t = 0.4
		game.sfx.play("player_pain")
