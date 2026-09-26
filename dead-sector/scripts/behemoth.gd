extends Node3D
## The thing that breaks out of the great containment chamber in "Breach". It can't be hurt and it
## can't be stopped: it comes after Mercer along a path through the collapsing facility, smashing
## what is in the way. Run. It keeps close enough to be felt (faster when left behind, slower when
## right on top of you) and kills whoever it reaches.

const Models := preload("res://scripts/models.gd")
const Tex := preload("res://scripts/textures.gd")

var world
var rules
var game
var nick := ""
var team := "x"
var squad := 2
var alive := true
var health := 99999.0
var kills := 0
var deaths := 0
var money := 0
var velocity := Vector3.ZERO
var since_shot := 10.0
var crouch := 0.0
var yaw := 0.0
var blood := Color(0.4, 0.3, 0.1)
var hitboxes: Array[Area3D] = []

var path := PackedVector3Array()
var path_i := 0
var running := false
var speed := 5.0
var step_t := 0.0
var roar_t := 2.0
var gait := 0.0
var body: Node3D
var legs: Array[Node3D] = []
var jaw: Node3D


func setup(world_ref, rules_ref, game_ref, route: PackedVector3Array) -> void:
	world = world_ref
	rules = rules_ref
	game = game_ref
	nick = tr("behemoth")
	path = route
	position = path[0] if path.size() > 0 else Vector3.ZERO
	_build()


func _build() -> void:
	Models.vm = false
	var flesh := Color(0.4, 0.34, 0.38)
	body = Node3D.new()
	body.position.y = 2.6
	add_child(body)
	Models.box(body, Vector3(3.2, 2.6, 4.6), Vector3(0, 0.4, 0.6), flesh)
	Models.box(body, Vector3(3.8, 2.0, 2.4), Vector3(0, 1.3, -1.2), flesh.darkened(0.08))  # hunched shoulders
	Models.box(body, Vector3(2.4, 1.4, 2.0), Vector3(0, 2.3, 0.2), flesh.darkened(0.15))
	for i in 7:
		Models.box(body, Vector3(0.3, 0.9, 0.3), Vector3(-1.2 + i * 0.4, 2.9, 0.4 + (i % 2) * 0.4), Color(0.85, 0.8, 0.7), 0.0, Vector3(0.4, 0, 0))  # spines
	Models.merge(body)
	for i in 9:
		var node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var s := randf_range(0.25, 0.5)
		mesh.size = Vector3(s, s, s)
		node.mesh = mesh
		node.material_override = Tex.flat(Models.HELIX_GLOW, 3.0)
		node.position = Vector3(randf_range(-1.7, 1.7), randf_range(0.0, 2.6), randf_range(-1.8, 2.6))
		body.add_child(node)
	var head := Node3D.new()
	head.position = Vector3(0, 0.6, -3.0)
	body.add_child(head)
	Models.box(head, Vector3(1.6, 1.2, 1.4), Vector3.ZERO, flesh.darkened(0.2))
	jaw = Node3D.new()
	jaw.position = Vector3(0, -0.5, -0.1)
	head.add_child(jaw)
	Models.box(jaw, Vector3(1.5, 0.4, 1.3), Vector3(0, -0.2, -0.3), flesh.darkened(0.25))
	for i in 5:
		Models.box(jaw, Vector3(0.1, 0.3, 0.1), Vector3(-0.6 + i * 0.3, 0.1, -0.9), Color(0.9, 0.85, 0.75))
	var maw := MeshInstance3D.new()
	var maw_mesh := BoxMesh.new()
	maw_mesh.size = Vector3(1.2, 0.3, 0.8)
	maw.mesh = maw_mesh
	maw.material_override = Tex.flat(Models.HELIX_GLOW, 5.0)
	maw.position = Vector3(0, -0.45, -0.4)
	head.add_child(maw)
	for i in 2:
		var eye_light := OmniLight3D.new()
		eye_light.light_color = Models.HELIX_GLOW
		eye_light.light_energy = 3.0
		eye_light.omni_range = 9.0
		eye_light.position = Vector3(0, -0.3, -1.2)
		head.add_child(eye_light)
		break
	# Four huge limbs: knuckle-walking arms in front, legs behind.
	for corner in [Vector3(-1.9, 0, -1.8), Vector3(1.9, 0, -1.8), Vector3(-1.5, 0, 2.2), Vector3(1.5, 0, 2.2)]:
		var leg := Node3D.new()
		leg.position = corner + Vector3(0, 2.6, 0)
		add_child(leg)
		var front: bool = corner.z < 0.0
		Models.box(leg, Vector3(1.0 if front else 0.9, 2.8, 1.0), Vector3(0, -1.3, 0), flesh.darkened(0.1))
		Models.box(leg, Vector3(1.3, 0.5, 1.5), Vector3(0, -2.55, -0.2), flesh.darkened(0.3))
		Models.merge(leg)
		legs.append(leg)


## Lets it loose.
func start() -> void:
	running = true
	path_i = 0
	_roar()


## Stops it (the blast door closed in its face).
func halt() -> void:
	running = false


func _roar() -> void:
	if game.sfx.sounds.has("behemoth"):
		game.sfx.play_at("behemoth", position + Vector3.UP * 3.0, 6.0)
	game.shake(0.8)


# --- What other code reads from a killer --------------------------------------------------

func eye_position() -> Vector3:
	return position + Vector3(0, 3.5, 0)


func eye_height() -> float:
	return 3.5


func is_moving() -> bool:
	return running


func take_hit(_amount: float, _group: String, _attacker, _weapon: String, _dir: Vector3, _pen: float) -> void:
	pass


func take_blast(_amount: float, _attacker, _weapon: String) -> void:
	pass


func blind(_seconds: float) -> void:
	pass


func _process(delta: float) -> void:
	gait += delta * (6.0 if running else 1.5)
	for i in legs.size():
		legs[i].rotation.x = sin(gait + (PI if i % 3 == 0 else 0.0)) * (0.5 if running else 0.05)
	body.rotation.z = sin(gait * 0.5) * 0.05
	body.position.y = 2.6 + absf(sin(gait)) * (0.25 if running else 0.03)
	jaw.rotation.x = 0.3 + sin(gait * 0.7) * 0.2


func _physics_process(delta: float) -> void:
	if not running or path_i >= path.size():
		return
	var prey = rules.human
	if prey == null or not prey.alive:
		return
	var d: float = position.distance_to(prey.position)
	# Rubber band: close enough to be felt, never so fast it can't be outrun by someone running.
	var want := 5.1
	if d > 24.0:
		want = 7.8
	elif d < 9.0:
		want = 4.4
	speed = move_toward(speed, want, delta * 3.0)
	var goal := path[path_i]
	var flat := Vector3(goal.x - position.x, 0, goal.z - position.z)
	if flat.length() < 0.6:
		path_i += 1
		return
	var dir := flat.normalized()
	yaw = rotate_toward(yaw, atan2(-dir.x, -dir.z), delta * 3.0)
	rotation.y = yaw
	position += dir * minf(speed * delta, flat.length())
	velocity = dir * speed
	step_t -= delta
	if step_t <= 0.0:
		step_t = 0.45
		if game.sfx.sounds.has("stomp"):
			game.sfx.play_at("stomp", position, 4.0)
		game.shake(clampf(1.0 - d / 30.0, 0.0, 1.0) * 0.45)
		world.burst(position + dir * 3.0 + Vector3(randf_range(-2, 2), 0.3, randf_range(-2, 2)), Color(0.45, 0.43, 0.4), 6, 5.0, 0.18)
	roar_t -= delta
	if roar_t <= 0.0:
		roar_t = randf_range(4.0, 7.0)
		_roar()
	if d < 3.6:
		prey.take_blast(999.0, self, "behemoth")
