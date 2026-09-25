extends CharacterBody3D
## One fighter: the player or a bot. Both run the same code; the player's controls come from the
## keyboard, mouse or controller, a bot's from its brain (bot.gd), which fills in the same fields.
##
## Movement works like the classic round-based shooters: friction and acceleration on the ground,
## a little air control, walking (silent) and crouching (steadier aim). Guns spray in a fixed pattern
## that climbs and then sways, and bullets land where the recoil kicked the aim (twice the view kick).

const Weapons := preload("res://scripts/weapons.gd")
const Models := preload("res://scripts/models.gd")

const GRAVITY := 20.0
const JUMP_SPEED := 7.2
const FRICTION := 5.2
const ACCEL := 5.5
const AIR_ACCEL := 12.0
const AIR_CAP := 0.8
const STOP_SPEED := 2.5
const HEIGHT := 1.8
const CROUCH_HEIGHT := 1.25
const EYE := 1.64
const CROUCH_EYE := 1.12
const RADIUS := 0.36
const WALK := 0.52
const CROUCHED := 0.34
const PLANT_TIME := 3.2
const DEFUSE_TIME := 10.0
const KIT_TIME := 5.0
const DEPLOY := 0.55
const MAX_MONEY := 16000
const SOUND := {
	"p18": "pistol", "m25": "pistol", "k45": "suppressed", "magnum": "magnum", "mx9": "smg", "u45": "smg",
	"pump": "shotgun", "viper": "rifle", "f90": "rifle", "ar7": "ak", "m4": "m4", "scout": "scout", "longbow": "sniper",
}

var world
var rules
var game
var brain  # bot.gd, or null for the player
var is_human := false
var nick := ""
var squad := 0  # 0 is the player's squad
var team := "att"
var health := 100.0
var armor := 0.0
var helmet := false
var has_kit := false
var money := 800
var kills := 0
var deaths := 0
var alive := true

# What they carry. mags / reserves hold the rounds of each gun they have.
var primary := ""
var secondary := ""
var grenades: Array[String] = []
var has_bomb := false
var mags := {}
var reserves := {}
var current := "knife"
var previous := "knife"

# Controls: set from input (player) or by the brain (bot) before each physics step.
var yaw := 0.0
var pitch := 0.0
var move_input := Vector2.ZERO  # x right, y back, like Input.get_vector
var want_jump := false
var want_crouch := false
var want_walk := false
var want_fire := false
var want_use := false
var frozen := false  # freeze time at the start of a round

var crouch := 0.0  # 0 standing, 1 crouched
var cooldown := 0.0
var reload_t := 0.0
var reload_len := 0.0
var reload_step := 0
var deploy_t := 0.0
var fire_latch := false
var shots := 0  # shots in the current spray
var punch := Vector2.ZERO  # recoil kick: x yaw, y pitch
var since_shot := 10.0
var scope := 0  # zoom level, 0 unscoped
var rescope := 0  # zoom to return to once the bolt is worked
var plant_t := 0.0
var key_t := 0.0
var defuse_t := 0.0
var flash_t := 0.0
var flash_len := 1.0
var step_t := 0.0
var hurt_t := 0.0
var hurt_from := Vector3.ZERO
var walk_phase := 0.0
var death_t := 0.0
var first_person := false
var view_muzzle: Node3D  # the first-person gun's muzzle, while the camera is behind this soldier's eyes

var shape: CapsuleShape3D
var col: CollisionShape3D
var parts := {}
var held: Node3D
var hitboxes: Array[Area3D] = []
var hit_shapes := {}


func setup(world_ref, rules_ref, game_ref, side: String, squad_index: int, name_text: String, human: bool) -> void:
	world = world_ref
	rules = rules_ref
	game = game_ref
	squad = squad_index
	nick = name_text
	is_human = human
	floor_snap_length = 0.3
	shape = CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	col = CollisionShape3D.new()
	col.shape = shape
	col.position.y = HEIGHT / 2.0
	add_child(col)
	for group in ["head", "chest", "stomach", "legs"]:
		var area := Area3D.new()
		area.collision_layer = world.LAYER_HIT
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("soldier", self)
		area.set_meta("group", group)
		var hit_col := CollisionShape3D.new()
		if group == "head":
			var sphere := SphereShape3D.new()
			sphere.radius = 0.14
			hit_col.shape = sphere
		else:
			hit_col.shape = BoxShape3D.new()
		hit_shapes[group] = hit_col
		area.add_child(hit_col)
		add_child(area)
		hitboxes.append(area)
	set_team(side)


func set_team(side: String) -> void:
	team = side
	collision_layer = world.LAYER_ATT if team == "att" else world.LAYER_DEF
	collision_mask = world.LAYER_WORLD | (world.LAYER_DEF if team == "att" else world.LAYER_ATT)
	if parts.has("root"):
		parts["root"].queue_free()
	parts = Models.soldier(team)
	add_child(parts["root"])
	held = null
	_arm()
	set_first_person(first_person)


## Places the soldier at the start of a round. Those who died, or everyone after the half, start over
## with a pistol and a knife; survivors keep what they carry.
func respawn(pos: Vector3, facing: float, keep: bool) -> void:
	if not keep:
		primary = ""
		secondary = Weapons.START_PISTOL[team]
		grenades.clear()
		armor = 0.0
		helmet = false
		has_kit = false
		mags.clear()
		reserves.clear()
		_fill(secondary)
	has_bomb = false
	health = 100.0
	alive = true
	position = pos
	velocity = Vector3.ZERO
	yaw = facing
	pitch = 0.0
	crouch = 0.0
	shape.height = HEIGHT
	col.position.y = HEIGHT / 2.0
	cooldown = 0.0
	reload_t = 0.0
	deploy_t = 0.0
	shots = 0
	punch = Vector2.ZERO
	scope = 0
	rescope = 0
	plant_t = 0.0
	defuse_t = 0.0
	flash_t = 0.0
	hurt_t = 0.0
	death_t = 0.0
	collision_layer = world.LAYER_ATT if team == "att" else world.LAYER_DEF
	collision_mask = world.LAYER_WORLD | (world.LAYER_DEF if team == "att" else world.LAYER_ATT)
	for area in hitboxes:
		area.collision_layer = world.LAYER_HIT
	var root: Node3D = parts["root"]
	root.rotation = Vector3(0, yaw, 0)
	root.position = Vector3.ZERO
	current = ""
	previous = "knife"
	equip(best_weapon())
	_update_hitboxes()


func _fill(id: String) -> void:
	var d := Weapons.data(id)
	mags[id] = d["mag"]
	reserves[id] = d["reserve"]


## Adds a weapon or grenade to what they carry (a gun replaces the one in its slot, which is dropped).
func give(id: String, mag := -1, reserve := -1) -> void:
	var d := Weapons.data(id)
	match int(d["slot"]):
		0, 1:
			var slot_id := primary if d["slot"] == 0 else secondary
			if slot_id != "":
				_drop(slot_id)
			if d["slot"] == 0:
				primary = id
			else:
				secondary = id
			_fill(id)
			if mag >= 0:
				mags[id] = mag
				reserves[id] = reserve
			equip(id)
		3:
			grenades.append(id)
		4:
			has_bomb = true


func owns(id: String) -> bool:
	return id == "knife" or id == primary or id == secondary or grenades.has(id) or (id == "bomb" and has_bomb)


func best_weapon() -> String:
	if primary != "":
		return primary
	if secondary != "":
		return secondary
	return "knife"


func equip(id: String) -> void:
	if id == current or not owns(id):
		return
	if current != "" and owns(current):
		previous = current
	current = id
	deploy_t = DEPLOY
	reload_t = 0.0
	scope = 0
	rescope = 0
	plant_t = 0.0
	shots = 0
	_arm()
	if is_human:
		game.sfx.play("deploy", -6.0)


## Slots like the classic keys: 1 primary, 2 pistol, 3 knife, 4 grenades (repeat to cycle), 5 bomb.
func select_slot(slot: int) -> void:
	match slot:
		0:
			equip(primary)
		1:
			equip(secondary)
		2:
			equip("knife")
		3:
			if grenades.is_empty():
				return
			var kinds: Array[String] = []
			for g in ["he", "flash", "smoke"]:
				if grenades.has(g):
					kinds.append(g)
			var i := kinds.find(current)
			equip(kinds[(i + 1) % kinds.size()])
		4:
			if has_bomb:
				equip("bomb")


func cycle(step: int) -> void:
	var order: Array[String] = [primary, secondary, "knife"]
	for g in ["he", "flash", "smoke"]:
		if grenades.has(g):
			order.append(g)
	if has_bomb:
		order.append("bomb")
	var owned: Array[String] = []
	for id in order:
		if id != "":
			owned.append(id)
	var i := owned.find(current)
	equip(owned[posmod(i + step, owned.size())])


func drop_current() -> void:
	if current == "knife" or not alive:
		return
	var d := Weapons.data(current)
	if d["slot"] == 3:
		return
	var id := current
	_drop(id)
	equip(best_weapon())


## Throws weapon `id` on the ground in front of them.
func _drop(id: String) -> void:
	var dir := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var pos := position + Vector3(0, 1.2, 0) + dir * 0.4
	if id == "bomb":
		has_bomb = false
		world.drop("bomb", 0, 0, pos, dir * 3.0 + Vector3(0, 2, 0) + velocity * 0.5)
		rules.on_bomb_dropped()
	else:
		world.drop(id, mags.get(id, 0), reserves.get(id, 0), pos, dir * 3.5 + Vector3(0, 2, 0) + velocity * 0.5)
		if id == primary:
			primary = ""
		elif id == secondary:
			secondary = ""
	if current == id:
		current = ""


func start_reload() -> void:
	var d := Weapons.data(current)
	if not d.has("mag") or reload_t > 0.0 or deploy_t > 0.0:
		return
	if mags[current] >= d["mag"] or reserves[current] <= 0:
		return
	reload_len = d["reload"]
	reload_t = reload_len
	reload_step = 0
	scope = 0
	rescope = 0
	shots = 0
	_sound("mag_out", -4.0)


func toggle_scope() -> void:
	var d := Weapons.data(current)
	if not d.has("scope") or reload_t > 0.0 or deploy_t > 0.0:
		return
	var levels: Array = d["scope"]
	scope = (scope + 1) % (levels.size() + 1)
	rescope = 0
	if is_human:
		game.sfx.play("zoom", -6.0)


func eye_height() -> float:
	return lerpf(EYE, CROUCH_EYE, crouch)


func eye_position() -> Vector3:
	return position + Vector3(0, eye_height(), 0)


## Where the gun points: the view plus the recoil kick.
func aim_basis() -> Basis:
	return Basis.from_euler(Vector3(pitch + punch.y * 2.0, yaw + punch.x * 2.0, 0))


func view_basis() -> Basis:
	return Basis.from_euler(Vector3(pitch + punch.y, yaw + punch.x, 0))


func muzzle_position() -> Vector3:
	if first_person and view_muzzle != null and view_muzzle.is_inside_tree():
		return view_muzzle.global_position
	if held != null and held.is_inside_tree():
		var mark := held.get_node_or_null("Muzzle") as Node3D
		if mark != null:
			return mark.global_position
	return eye_position()


func max_speed() -> float:
	var d := Weapons.data(current)
	var speed: float = d["speed"]
	if scope > 0:
		speed *= 0.5
	if crouch > 0.5:
		speed *= CROUCHED
	elif want_walk:
		speed *= WALK
	return speed


## How far off a shot can go right now, in radians.
func inaccuracy() -> float:
	var d := Weapons.data(current)
	if not d.has("spread"):
		return 0.0
	var base: float = d["spread"]
	if d.has("unscoped") and scope == 0:
		base = d["unscoped"]
	var speed := Vector2(velocity.x, velocity.z).length()
	var run := clampf((speed / d["speed"] - 0.36) / 0.64, 0.0, 1.0)  # walking keeps a gun steady
	var value: float = base * (0.75 if crouch > 0.8 else 1.0) + d["move"] * run
	if not is_on_floor():
		value += 0.12
	if d.get("auto", false):
		value += minf(shots, 10) * d["spread"] * 0.5
	return value


func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 1.0


func busy() -> bool:
	return plant_t > 0.0 or defuse_t > 0.0


func set_first_person(on: bool) -> void:
	first_person = on
	if not parts.has("root"):
		return
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for node in (parts["root"] as Node3D).find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = mode


# --- Player input --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_human or not alive or not game.can_control():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var zoom: float = 1.0 if scope == 0 else rules.scope_fov(self) / 74.0
		var turn: float = game.mouse_sensitivity * 0.0004 * zoom
		yaw -= event.relative.x * turn
		pitch -= event.relative.y * turn * (-1.0 if game.invert_y else 1.0)
		pitch = clampf(pitch, -1.5, 1.5)
		return
	for i in 5:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			select_slot(i)
	if event.is_action_pressed("next_weapon"):
		cycle(1)
	elif event.is_action_pressed("prev_weapon"):
		cycle(-1)
	elif event.is_action_pressed("last_weapon"):
		equip(previous)
	elif event.is_action_pressed("reload"):
		start_reload()
	elif event.is_action_pressed("scope"):
		toggle_scope()
	elif event.is_action_pressed("drop"):
		drop_current()
	elif event.is_action_pressed("use"):
		rules.try_pickup(self)
	elif event.is_action_pressed("jump"):
		want_jump = true


func _read_input(delta: float) -> void:
	if not game.can_control():
		move_input = Vector2.ZERO
		want_fire = false
		want_use = false
		want_crouch = false
		want_walk = false
		return
	move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	want_crouch = Input.is_action_pressed("crouch")
	want_walk = Input.is_action_pressed("walk")
	want_fire = Input.is_action_pressed("fire")
	want_use = Input.is_action_pressed("use")
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO:
		stick *= stick.length()
		var zoom: float = 1.0 if scope == 0 else rules.scope_fov(self) / 74.0
		var rate: float = (1.0 + game.stick_sensitivity * 0.35) * zoom
		yaw -= stick.x * rate * delta
		pitch -= stick.y * rate * 0.65 * delta * (-1.0 if game.invert_y else 1.0)
		pitch = clampf(pitch, -1.5, 1.5)


# --- Running -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	flash_t = maxf(flash_t - delta, 0.0)
	hurt_t = maxf(hurt_t - delta, 0.0)
	if not alive:
		_dead(delta)
		return
	if brain != null:
		brain.think(delta)
	elif is_human:
		_read_input(delta)
	_defusing(delta)
	_move(delta)
	_weapon(delta)
	_update_hitboxes()


func _process(delta: float) -> void:
	_animate(delta)


func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	var target := 1.0 if want_crouch else 0.0
	if target < crouch and _blocked_above():
		target = crouch
	crouch = move_toward(crouch, target, delta * 7.0)
	var h := lerpf(HEIGHT, CROUCH_HEIGHT, crouch)
	if absf(shape.height - h) > 0.001:
		shape.height = h
		col.position.y = h / 2.0
	var still := frozen or busy()
	var input := Vector2.ZERO if still else move_input.limit_length(1.0)
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	var wish_speed := wish.length() * max_speed()
	if wish.length() > 0.001:
		wish = wish.normalized()
	var v := Vector3(velocity.x, 0, velocity.z)
	if on_floor:
		if want_jump and not still:
			velocity.y = JUMP_SPEED
			v = _accelerate(v, wish, wish_speed, ACCEL, delta)
		else:
			v = _accelerate(_friction(v, delta), wish, wish_speed, ACCEL, delta)
			velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= GRAVITY * delta
		v = _air_accelerate(v, wish, wish_speed, delta)
	want_jump = false
	velocity.x = v.x
	velocity.z = v.z
	var falling := velocity.y
	move_and_slide()
	if is_on_floor() and not on_floor and falling < -6.0:
		_sound("land", -6.0)
	if is_on_floor():
		var speed := Vector2(velocity.x, velocity.z).length()
		step_t -= delta * speed
		if step_t <= 0.0:
			step_t = 2.2
			if speed > 3.4:
				_footstep()
	if position.y < -10.0:
		position = world.center(world.cell_of(position), 0.5)


func _friction(v: Vector3, delta: float) -> Vector3:
	var speed := v.length()
	if speed < 0.01:
		return Vector3.ZERO
	var drop := maxf(speed, STOP_SPEED) * FRICTION * delta
	return v * (maxf(speed - drop, 0.0) / speed)


func _accelerate(v: Vector3, wish: Vector3, wish_speed: float, accel: float, delta: float) -> Vector3:
	var add := wish_speed - v.dot(wish)
	if add <= 0.0:
		return v
	return v + wish * minf(accel * delta * wish_speed, add)


## In the air only a little speed can be added along the wish direction, which is what makes
## strafing in the air curve the jump.
func _air_accelerate(v: Vector3, wish: Vector3, wish_speed: float, delta: float) -> Vector3:
	var add := minf(wish_speed, AIR_CAP) - v.dot(wish)
	if add <= 0.0:
		return v
	return v + wish * minf(AIR_ACCEL * wish_speed * delta, add)


func _blocked_above() -> bool:
	var from := position + Vector3(0, shape.height - 0.05, 0)
	var query := PhysicsRayQueryParameters3D.create(from, position + Vector3(0, HEIGHT + 0.05, 0), world.LAYER_WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _footstep() -> void:
	var sound := "step1" if randf() < 0.5 else "step2"
	if is_human:
		game.sfx.play(sound, -12.0)
	else:
		game.sfx.play_at(sound, position, -3.0)
	world.noise(position, 20.0, self)


## Plays a sound of this soldier: in the player's ears for the player, from their spot for others.
func _sound(sound: String, volume := 0.0) -> void:
	if first_person:
		game.sfx.play(sound, volume)
	else:
		game.sfx.play_at(sound, position + Vector3(0, 1.2, 0), volume)


# --- Weapons -------------------------------------------------------------------------------

func _weapon(delta: float) -> void:
	cooldown -= delta
	deploy_t -= delta
	since_shot += delta
	if since_shot > 0.1:
		punch = punch.lerp(Vector2.ZERO, 1.0 - exp(-delta * 8.0))
	if since_shot > 0.45:
		shots = 0
	if reload_t > 0.0:
		_reloading(delta)
	if rescope > 0 and cooldown <= 0.0 and reload_t <= 0.0:
		scope = rescope
		rescope = 0
	if current == "bomb":
		_planting(delta)
		return
	var d := Weapons.data(current)
	if want_fire and not frozen and not busy():
		if d.get("auto", false) or not fire_latch:
			_try_fire(d)
		fire_latch = true
	elif not want_fire:
		fire_latch = false
	if d.has("mag") and mags[current] <= 0 and reserves[current] > 0 and cooldown <= 0.0 and reload_t <= 0.0:
		start_reload()


func _reloading(delta: float) -> void:
	reload_t -= delta
	if reload_step == 0 and reload_t < reload_len * 0.4:
		reload_step = 1
		_sound("mag_in", -4.0)
	if reload_t <= 0.0:
		reload_t = 0.0
		var d := Weapons.data(current)
		var need: int = d["mag"] - mags[current]
		var take: int = mini(need, reserves[current])
		mags[current] += take
		reserves[current] -= take
		_sound("bolt", -6.0)


func _try_fire(d: Dictionary) -> void:
	if cooldown > 0.0 or deploy_t > 0.0 or reload_t > 0.0:
		return
	match int(d["slot"]):
		2:
			_knife(d)
		3:
			_throw()
		_:
			if mags[current] <= 0:
				if reserves[current] <= 0:
					_sound("dry", -4.0)
					cooldown = 0.25
				return
			mags[current] -= 1
			_shoot(d)


func _shoot(d: Dictionary) -> void:
	cooldown = d["rate"]
	since_shot = 0.0
	var eye := eye_position()
	var spread := inaccuracy()
	var basis_now := aim_basis()
	var pellets := int(d.get("pellets", 1))
	var muzzle := muzzle_position()
	for i in pellets:
		var r: float = spread * randf() if pellets == 1 else d["spread"] * sqrt(randf()) + spread * 0.3
		var a := randf() * TAU
		var dir := (basis_now * Vector3(cos(a) * r, sin(a) * r, -1.0)).normalized()
		world.fire_bullet(self, eye, dir, d, current, muzzle, pellets == 1 or i < 3)
	shots += 1
	var kick: float = d["recoil"]
	punch.y = minf(punch.y + kick * (1.0 if shots <= 8 else 0.35), 0.32)
	punch.x += kick * 0.75 * _sway(shots)
	if pellets > 1 or not d.get("auto", false):
		punch.x += kick * randf_range(-0.3, 0.3)
	_sound(SOUND.get(current, "pistol"), -2.0 if first_person else 0.0)
	if not first_person:
		world.muzzle_flash(muzzle, 1.4 if pellets > 1 else 1.0)
	world.noise(position, 18.0 if current == "k45" else 55.0, self)
	if d.has("scope") and scope > 0:
		rescope = scope
		scope = 0
	if is_human:
		game.vibrate(clampf(kick * 10.0, 0.1, 0.6), 0.06)


## The sideways part of the spray pattern: steady at first, then swaying left and right.
static func _sway(n: int) -> float:
	if n < 6:
		return sin(n * 1.7) * 0.25
	return sin((n - 6) * 0.6) * 1.1


func _knife(d: Dictionary) -> void:
	cooldown = d["rate"]
	since_shot = 0.0
	var hit: Dictionary = world.trace(self, eye_position(), view_basis() * Vector3.FORWARD, d["reach"])
	if not hit.is_empty() and hit["target"] != null:
		var target = hit["target"]
		# From behind the stab is lethal.
		var facing: Vector3 = Basis(Vector3.UP, target.yaw) * Vector3.FORWARD
		var from_behind := facing.dot((target.position - position).normalized()) > 0.5
		target.take_hit(d["damage"] * (4.5 if from_behind else 1.0), "knife", self, "knife", facing, d["pen"])
		_sound("knife_hit")
	elif not hit.is_empty():
		world.mark(hit["pos"], hit["normal"])
		_sound("knife_hit", -6.0)
	else:
		_sound("knife", -4.0)


func _throw() -> void:
	cooldown = 1.0
	since_shot = 0.0
	var dir := view_basis() * Vector3.FORWARD
	var vel := dir * 17.0 + Vector3.UP * 2.5 + velocity * 0.5
	world.throw_grenade(self, current, eye_position() + dir * 0.5, vel)
	grenades.erase(current)
	_sound("throw", -4.0)
	var id := current
	current = ""
	if grenades.has(id):
		equip(id)
	elif owns(previous) and previous != id:
		equip(previous)
	else:
		equip(best_weapon())


func _planting(delta: float) -> void:
	var can: bool = want_fire and is_on_floor() and world.site_at(position) != "" and rules.can_plant()
	if can:
		plant_t += delta
		key_t -= delta
		if key_t <= 0.0:
			key_t = 0.4
			_sound("key", -4.0)
		if plant_t >= PLANT_TIME:
			plant_t = 0.0
			has_bomb = false
			current = ""
			rules.plant(self)
			equip(best_weapon())
	else:
		if want_fire and not fire_latch and is_human and world.site_at(position) == "":
			game.message(tr("plant_on_site"))
		plant_t = 0.0
		key_t = 0.0
	fire_latch = want_fire


func _defusing(delta: float) -> void:
	var bomb = rules.bomb_node
	if team == "def" and want_use and bomb != null and rules.bomb_state == "planted" and is_on_floor() and \
			Vector2(bomb.position.x - position.x, bomb.position.z - position.z).length() < 1.7 and absf(bomb.position.y - position.y) < 1.5:
		if defuse_t == 0.0:
			_sound("defuse", -2.0)
			rules.on_defuse_start(self)
		defuse_t += delta
		if defuse_t >= (KIT_TIME if has_kit else DEFUSE_TIME):
			defuse_t = 0.0
			rules.defuse(self)
	else:
		defuse_t = 0.0


func defuse_length() -> float:
	return KIT_TIME if has_kit else DEFUSE_TIME


# --- Damage --------------------------------------------------------------------------------

## A bullet or a knife: hit-group multiplier, then armor (the helmet guards the head).
func take_hit(amount: float, group: String, attacker, weapon: String, dir: Vector3, pen: float) -> void:
	if not alive:
		return
	var mult := 1.0
	match group:
		"head":
			mult = Weapons.HEAD
		"stomach":
			mult = Weapons.STOMACH
		"legs":
			mult = Weapons.LEGS
	var damage := amount * mult
	var armored := armor > 0.0 and group != "legs" and (group != "head" or helmet)
	if armored:
		var through := damage * pen
		var soaked := (damage - through) * 0.5
		if soaked > armor:
			through = damage - armor * 2.0
			soaked = armor
		armor -= soaked
		damage = through
	if group == "head":
		game.sfx.play_at("hit_helmet" if helmet and armored else "hit_head", eye_position())
	elif not is_human:
		game.sfx.play_at("hit_flesh", position + Vector3(0, 1.1, 0), -3.0)
	# Being hit slows you down ("tagging").
	velocity.x *= 0.45
	velocity.z *= 0.45
	_harm(damage, attacker, weapon, group == "head", dir)


## An explosion: armor takes half of it.
func take_blast(amount: float, attacker, weapon: String) -> void:
	if not alive or amount <= 0.0:
		return
	var damage := amount
	if armor > 0.0:
		var soaked := minf(amount * 0.5, armor * 2.0)
		armor = maxf(armor - soaked * 0.5, 0.0)
		damage -= soaked
	_harm(damage, attacker, weapon, false, Vector3.ZERO)


func _harm(damage: float, attacker, weapon: String, headshot: bool, _dir: Vector3) -> void:
	health -= damage
	hurt_t = 1.0
	if attacker != null and attacker != self:
		hurt_from = attacker.position
	if brain != null and attacker != null and attacker != self:
		brain.on_hurt(attacker)
	if is_human:
		game.vibrate(clampf(damage / 40.0, 0.2, 1.0), 0.15)
		game.shake(clampf(damage / 60.0, 0.1, 0.6))
	if health <= 0.0:
		_die(attacker, weapon, headshot)
	elif randf() < 0.35:
		_sound("pain", -4.0)


func blind(seconds: float) -> void:
	if not alive:
		return
	if seconds > flash_t:
		flash_t = seconds
		flash_len = seconds
	if is_human and seconds > 1.0:
		game.sfx.play("ring", -4.0)
	if brain != null:
		brain.on_blind()


func _die(attacker, weapon: String, headshot: bool) -> void:
	alive = false
	health = 0.0
	deaths += 1
	collision_layer = 0
	collision_mask = world.LAYER_WORLD
	for area in hitboxes:
		area.collision_layer = 0
	scope = 0
	plant_t = 0.0
	defuse_t = 0.0
	reload_t = 0.0
	if primary != "":
		_drop(primary)
	elif secondary != "":
		_drop(secondary)
	if has_bomb:
		_drop("bomb")
	secondary = ""
	grenades.clear()
	current = ""
	_arm()
	game.sfx.play_at("death", position + Vector3(0, 1.3, 0), -2.0)
	rules.on_death(self, attacker, weapon, headshot)


func _dead(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
	velocity.y -= GRAVITY * delta
	move_and_slide()
	death_t = minf(death_t + delta / 0.6, 1.0)


# --- Body ----------------------------------------------------------------------------------

## Puts the current weapon in the model's hands.
func _arm() -> void:
	if not parts.has("aim"):
		return
	var aim: Node3D = parts["aim"]
	if current == "":
		for child in aim.get_children():
			child.queue_free()
		held = null
		return
	held = Models.arm_soldier(aim, current, parts["arm_color"])
	set_first_person(first_person)


func _update_hitboxes() -> void:
	var legs := lerpf(0.86, 0.46, crouch)
	var stomach := lerpf(0.3, 0.26, crouch)
	var chest := lerpf(0.4, 0.34, crouch)
	var lean := Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.12 * crouch)
	_place_box("legs", Vector3(0.42, legs, 0.28), Vector3(0, legs / 2.0, 0))
	_place_box("stomach", Vector3(0.46, stomach, 0.3), Vector3(0, legs + stomach / 2.0, 0) + lean * 0.5)
	_place_box("chest", Vector3(0.5, chest, 0.32), Vector3(0, legs + stomach + chest / 2.0, 0) + lean)
	(hit_shapes["head"] as CollisionShape3D).position = Vector3(0, eye_height() + 0.06, 0) + lean * 1.2


func _place_box(group: String, size: Vector3, pos: Vector3) -> void:
	var hit_col: CollisionShape3D = hit_shapes[group]
	(hit_col.shape as BoxShape3D).size = size
	hit_col.position = pos


func _animate(delta: float) -> void:
	if not parts.has("root"):
		return
	var root: Node3D = parts["root"]
	if not alive:
		var ease_t := 1.0 - pow(1.0 - death_t, 3.0)
		root.rotation.x = ease_t * 1.45
		(parts["aim"] as Node3D).rotation.x = lerpf((parts["aim"] as Node3D).rotation.x, -1.2, ease_t)
		return
	root.rotation = Vector3(0, yaw, 0)
	var speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor():
		walk_phase += delta * speed * 2.1
	var stride := sin(walk_phase) * 0.55 * clampf(speed / 5.0, 0.0, 1.0)
	(parts["hips"] as Node3D).position.y = 0.9 - 0.5 * crouch
	var thighs: Array = parts["thighs"]
	var shins: Array = parts["shins"]
	for i in 2:
		var swing := stride if i == 0 else -stride
		(thighs[i] as Node3D).rotation.x = crouch * 1.3 + swing
		(shins[i] as Node3D).rotation.x = -crouch * 2.3 - maxf(-swing, 0.0) * 1.2
	(parts["torso"] as Node3D).rotation.x = -0.18 * crouch
	(parts["aim"] as Node3D).rotation.x = pitch + 0.18 * crouch
	(parts["head"] as Node3D).rotation.x = pitch * 0.5 + 0.18 * crouch
	if not is_on_floor():
		for i in 2:
			(thighs[i] as Node3D).rotation.x = 0.5
			(shins[i] as Node3D).rotation.x = -0.9
