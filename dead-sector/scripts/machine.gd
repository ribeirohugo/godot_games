extends Node3D
## The campaign's machines: security turrets and drones, and the containment conduits that feed the
## First in the last fight. They are enemies like soldiers (shot through their hitbox, killers in the
## kill feed), so they carry the same fields other code reads from a soldier.
##
##   turret   bolted down, dead until its power group comes on; sweeps, locks on and fires bursts
##   drone    hovers and wanders near home; keeps its distance from what it sees and shoots
##   conduit  does nothing but stand there glowing, until it is destroyed

const Models := preload("res://scripts/models.gd")
const Tex := preload("res://scripts/textures.gd")
const Weapons := preload("res://scripts/weapons.gd")

const STATS := {
	"turret": {"health": 160.0, "range": 34.0, "damage": 9.0, "rate": 0.11, "burst": 6, "rest": 0.9, "cone": 0.55},
	"drone": {"health": 55.0, "range": 26.0, "damage": 7.0, "rate": 0.16, "burst": 4, "rest": 1.2, "cone": 0.3},
	"conduit": {"health": 260.0},
}

var world
var rules
var game
var kind := "turret"
var nick := ""
var team := "def"
var squad := 1
var alive := true
var active := true
var power := ""  # a power group that switches it on
var health := 100.0
var kills := 0
var deaths := 0
var money := 0
var brain = null
var is_human := false
var has_bomb := false
var crouch := 0.0
var since_shot := 10.0
var yaw := 0.0
var pitch := 0.0
var velocity := Vector3.ZERO
var blood := Color(1.0, 0.8, 0.3)  # sparks
var hitboxes: Array[Area3D] = []
var group := ""

var home := Vector3.ZERO
var facing := 0.0  # the way a turret was set up to watch
var head: Node3D  # the part that turns
var eye: Node3D  # a glowing lamp that shows its state
var eye_mat: StandardMaterial3D
var target = null
var lock_t := 0.0
var burst_left := 0
var rest_t := 0.0
var fire_t := 0.0
var sweep := 0.0
var wander := Vector3.ZERO
var wander_t := 0.0
var look_t := 0.0
var fall_v := 0.0
var hum_t := 0.0


func setup(world_ref, rules_ref, game_ref, what: String, pos: Vector3, look: float) -> void:
	world = world_ref
	rules = rules_ref
	game = game_ref
	kind = what
	nick = tr("machine_" + kind)
	health = STATS[kind]["health"]
	position = pos
	home = pos
	yaw = look
	facing = look
	_build()
	var area := Area3D.new()
	area.collision_layer = world.LAYER_HIT
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("soldier", self)
	area.set_meta("group", "chest")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = {"turret": Vector3(0.9, 0.8, 0.9), "drone": Vector3(1.0, 0.4, 1.0), "conduit": Vector3(1.2, 3.2, 1.2)}[kind]
	shape.shape = box
	shape.position.y = {"turret": 1.35, "drone": 0.0, "conduit": 1.6}[kind]
	area.add_child(shape)
	add_child(area)
	hitboxes.append(area)
	set_active(active)


func _build() -> void:
	Models.vm = false
	match kind:
		"turret":
			var base := Node3D.new()
			add_child(base)
			Models.box(base, Vector3(0.9, 0.3, 0.9), Vector3(0, 0.15, 0), Color(0.25, 0.27, 0.28), 0.5)
			Models.cylinder(base, 0.18, 0.8, Vector3(0, 0.7, 0), Color(0.2, 0.21, 0.22))
			Models.merge(base)
			head = Node3D.new()
			head.position.y = 1.3
			add_child(head)
			Models.box(head, Vector3(0.7, 0.45, 0.8), Vector3.ZERO, Color(0.3, 0.32, 0.33), 0.5)
			Models.box(head, Vector3(0.72, 0.08, 0.82), Vector3(0, 0.2, 0), Color(0.8, 0.65, 0.1))
			for side in [-1, 1]:
				Models.cylinder(head, 0.05, 0.7, Vector3(0.18 * side, -0.02, -0.7), Color(0.1, 0.1, 0.1), Vector3(PI / 2.0, 0, 0))
			Models.merge(head)
			eye = _eye(head, Vector3(0, 0.05, -0.41))
		"drone":
			head = Node3D.new()
			add_child(head)
			Models.box(head, Vector3(0.45, 0.2, 0.55), Vector3.ZERO, Color(0.85, 0.86, 0.87), 0.3)
			Models.box(head, Vector3(0.3, 0.12, 0.3), Vector3(0, -0.14, -0.08), Color(0.15, 0.15, 0.16), 0.4)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					Models.box(head, Vector3(0.36, 0.04, 0.05), Vector3(sx * 0.3, 0.05, sz * 0.3), Color(0.2, 0.2, 0.2), 0.4, Vector3(0, sx * sz * 0.78, 0))
					Models.cylinder(head, 0.2, 0.02, Vector3(sx * 0.45, 0.12, sz * 0.45), Color(0.1, 0.1, 0.1))
			Models.cylinder(head, 0.03, 0.3, Vector3(0, -0.16, -0.3), Color(0.08, 0.08, 0.08), Vector3(PI / 2.0, 0, 0))
			Models.merge(head)
			eye = _eye(head, Vector3(0, -0.14, -0.24))
			position.y = 3.2
			home.y = 3.2
		"conduit":
			head = Node3D.new()
			add_child(head)
			Models.cylinder(head, 0.7, 0.4, Vector3(0, 0.2, 0), Color(0.2, 0.21, 0.22))
			Models.cylinder(head, 0.5, 0.3, Vector3(0, 3.2, 0), Color(0.2, 0.21, 0.22))
			for i in 4:
				var a := i * TAU / 4.0
				Models.box(head, Vector3(0.12, 3.0, 0.12), Vector3(cos(a) * 0.45, 1.7, sin(a) * 0.45), Color(0.25, 0.26, 0.27), 0.6)
			Models.merge(head)
			var core := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.25
			cyl.bottom_radius = 0.3
			cyl.height = 2.7
			core.mesh = cyl
			eye_mat = Tex.flat(Models.FIRST_GLOW, 4.0).duplicate()
			core.material_override = eye_mat
			core.position.y = 1.7
			head.add_child(core)
			var light := OmniLight3D.new()
			light.light_color = Models.FIRST_GLOW
			light.light_energy = 2.0
			light.omni_range = 7.0
			light.position.y = 1.8
			head.add_child(light)
			eye = core


func _eye(parent: Node3D, at: Vector3) -> MeshInstance3D:
	var lamp := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	lamp.mesh = mesh
	eye_mat = Tex.flat(Color(1.0, 0.1, 0.05), 5.0).duplicate()
	lamp.material_override = eye_mat
	lamp.position = at
	parent.add_child(lamp)
	return lamp


## Switched on (the power came back) or off.
func set_active(on: bool) -> void:
	active = on
	if eye_mat != null and kind != "conduit":
		eye_mat.emission_energy_multiplier = 5.0 if on else 0.0
		eye_mat.albedo_color = Color(1.0, 0.1, 0.05) if on else Color(0.1, 0.1, 0.1)
	if head != null and kind == "turret":
		head.rotation.x = 0.0 if on else -0.45  # slumped when dead


# --- What other code reads from a soldier --------------------------------------------------

func eye_position() -> Vector3:
	return head.global_position if head != null and head.is_inside_tree() else position + Vector3.UP


func eye_height() -> float:
	return eye_position().y - position.y


func view_basis() -> Basis:
	return Basis.from_euler(Vector3(pitch, yaw, 0))


func is_moving() -> bool:
	return kind == "drone"


func blind(_seconds: float) -> void:
	pass


func take_hit(amount: float, _group: String, attacker, weapon: String, _dir: Vector3, _pen: float) -> void:
	_harm(amount * (1.4 if weapon in ["pump", "magnum"] else 1.0), attacker, weapon)


func take_blast(amount: float, attacker, weapon: String) -> void:
	_harm(amount * 1.5, attacker, weapon)


func _harm(damage: float, attacker, weapon: String) -> void:
	if not alive:
		return
	health -= damage * rules.damage_scale(self, attacker)
	world.burst(eye_position(), Color(1.0, 0.8, 0.3), 3, 4.0, 0.03, 4.0)
	if attacker != null and attacker.team != team and target == null and active:
		target = attacker
		lock_t = 0.2
	if health <= 0.0:
		_die(attacker, weapon)


func _die(attacker, weapon: String) -> void:
	alive = false
	deaths += 1
	for area in hitboxes:
		area.collision_layer = 0
	world.explosion(eye_position(), 0.9 if kind != "conduit" else 2.0)
	game.sfx.play_at("explode", eye_position(), -4.0 if kind != "conduit" else 2.0)
	if eye_mat != null:
		eye_mat.emission_energy_multiplier = 0.0
		eye_mat.albedo_color = Color(0.08, 0.08, 0.08)
	for child in head.get_children():
		if child is OmniLight3D:
			child.queue_free()
	rules.on_machine_destroyed(self, attacker, weapon)


# --- Running -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	since_shot += delta
	if not alive:
		if kind == "drone" and position.y > world.ground_at(position) + 0.2:
			fall_v += 20.0 * delta
			position.y -= fall_v * delta
			head.rotation.z += delta * 6.0
		elif kind == "turret":
			head.rotation.x = move_toward(head.rotation.x, -0.6, delta * 2.0)
		return
	if kind == "conduit":
		head.rotation.y += delta * 0.4
		eye_mat.emission_energy_multiplier = 3.0 + sin(Time.get_ticks_msec() / 150.0) * 1.2
		return
	if not active:
		return
	if kind == "drone":
		head.position.y = sin(Time.get_ticks_msec() / 400.0 + home.x) * 0.08  # bobbing
	look_t -= delta
	if look_t <= 0.0:
		look_t = 0.2
		_look()
	if target != null:
		_engage(delta)
	else:
		_idle(delta)
	head.rotation = Vector3(pitch if kind == "turret" else 0.0, yaw, 0)
	if kind == "drone":
		_hover(delta)


## Finds the nearest enemy it can see in front of it.
func _look() -> void:
	var from := eye_position()
	var facing := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var best = null
	var best_d: float = STATS[kind]["range"]
	for e in rules.enemies_of(self):
		if not e.alive:
			continue
		var at: Vector3 = e.position + Vector3(0, e.eye_height() * 0.75, 0)
		var d := from.distance_to(at)
		if d > best_d:
			continue
		var dir := (at - from) / maxf(d, 0.01)
		if e != target and Vector2(facing.x, facing.z).normalized().dot(Vector2(dir.x, dir.z).normalized()) < STATS[kind]["cone"]:
			continue
		if not world.clear_line(from, at) or world.smoke_between(from, at):
			continue
		best = e
		best_d = d
	if best == null:
		if target != null:
			target = null
			rest_t = 1.0
		return
	if best != target:
		target = best
		lock_t = 0.6 if kind == "turret" else 0.4
		game.sfx.play_at("lock_on" if game.sfx.sounds.has("lock_on") else "beep", from, -4.0)


func _engage(delta: float) -> void:
	if not target.alive:
		target = null
		return
	var from := eye_position()
	var at: Vector3 = target.position + Vector3(0, target.eye_height() * 0.75, 0) + target.velocity * 0.1
	var to := at - from
	yaw = rotate_toward(yaw, atan2(-to.x, -to.z), delta * (2.2 if kind == "turret" else 3.0))
	pitch = move_toward(pitch, atan2(to.y, Vector2(to.x, to.z).length()), delta * 2.0)
	lock_t -= delta
	rest_t -= delta
	fire_t -= delta
	if lock_t > 0.0 or rest_t > 0.0 or fire_t > 0.0:
		return
	if absf(angle_difference(yaw, atan2(-to.x, -to.z))) > 0.12:
		return
	var s: Dictionary = STATS[kind]
	fire_t = s["rate"]
	burst_left -= 1
	if burst_left <= 0:
		burst_left = s["burst"]
		rest_t = s["rest"]
	since_shot = 0.0
	var spread := 0.035 if kind == "turret" else 0.05
	var dir := (Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3(randf_range(-spread, spread), randf_range(-spread, spread), -1.0)).normalized()
	var muzzle := from + dir * 0.7
	var weapon := {"damage": s["damage"], "falloff": 0.95, "pen": 0.5}
	world.fire_bullet(self, from + dir * 0.6, dir, weapon, kind, muzzle, true)
	world.muzzle_flash(muzzle, 0.8)
	game.sfx.play_at("smg" if kind == "turret" else "pistol", from, -2.0 if kind == "turret" else -6.0)
	world.noise(from, 40.0, self)


func _idle(delta: float) -> void:
	if kind == "turret":
		sweep += delta * 0.6
		yaw = facing + sin(sweep) * 0.9
		pitch = move_toward(pitch, 0.0, delta)


## A drone drifts about home, and in a fight keeps 8-12 m from its target, sliding sideways.
func _hover(delta: float) -> void:
	var want := home
	if target != null:
		var flat := Vector3(position.x - target.position.x, 0, position.z - target.position.z)
		var d := flat.length()
		var keep := flat / maxf(d, 0.1) * clampf(d, 8.0, 12.0)
		var side := Vector3(-flat.z, 0, flat.x).normalized() * sin(Time.get_ticks_msec() / 900.0 + home.z) * 4.0
		want = Vector3(target.position.x, home.y, target.position.z) + keep + side
	else:
		wander_t -= delta
		if wander_t <= 0.0:
			wander_t = randf_range(2.0, 4.0)
			wander = Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
		want = home + wander
		yaw = rotate_toward(yaw, atan2(-(want - position).x, -(want - position).z), delta)
	var step := (want - position).limit_length(4.0 * delta)
	var next := position + step
	# Stay over open floor: never fly into a wall.
	if world.is_wall(world.cell_of(next)) or world.is_solid(world.cell_of(next)) and world.ground_at(next) > next.y - 0.5:
		wander_t = 0.0
		return
	if not world.clear_line(position, next + step.normalized() * 0.6):
		wander_t = 0.0
		return
	position = next
	hum_t -= delta
	if hum_t <= 0.0 and game.sfx.sounds.has("drone"):
		hum_t = 1.9
		game.sfx.play_at("drone", position, -10.0)
