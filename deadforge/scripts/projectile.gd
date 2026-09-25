extends Node3D
## A fireball thrown by a demon, or a glob of slag from the Slag Cannon. It flies straight, checks
## what it crossed each physics step with a ray, and bursts on the first thing it meets.

const Tex := preload("res://scripts/textures.gd")

var world
var velocity := Vector3.ZERO
var damage := 10.0
var from_player := false
var splash := 0.0  # blast radius; 0 hits only what it touches
var radius := 0.25
var color := Color(1.0, 0.5, 0.1)
var life := 6.0
var trail := 0.0
var core: MeshInstance3D


func setup(world_ref, at: Vector3, speed_vector: Vector3, amount: float, player_owned: bool, blast: float, size: float, tint: Color) -> void:
	world = world_ref
	position = at
	velocity = speed_vector
	damage = amount
	from_player = player_owned
	splash = blast
	radius = size
	color = tint
	for i in 2:
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = size * (1.0 if i == 0 else 0.55)
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		ball.mesh = sphere
		ball.material_override = Tex.material("lava" if i == 0 else "glow", Color.WHITE if i == 0 else Color(1.0, 0.95, 0.7), 1.0)
		if i == 0:
			ball.material_override.set_shader_parameter("tint", tint)
			ball.material_override.set_shader_parameter("scroll", Vector2(0.8, 0.5))
			core = ball
		add_child(ball)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var mask: int = world.LAYER_WORLD | world.LAYER_SURFACE | (world.LAYER_ENEMY if from_player else world.LAYER_PLAYER)
	var step := velocity * delta
	var query := PhysicsRayQueryParameters3D.create(position, position + step + velocity.normalized() * radius, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_impact(hit)
		return
	position += step
	core.scale = Vector3.ONE * (1.0 + 0.15 * sin(life * 40.0))
	trail -= delta
	if trail <= 0.0:
		trail = 0.04
		world.burst(position, color, 1, 1.0, radius * 0.5, true)


func _impact(hit: Dictionary) -> void:
	var at: Vector3 = hit["position"] + hit["normal"] * 0.25
	if splash > 0.0:
		world.explosion(at, splash * 0.55)
		world.splash(at, splash, damage, from_player)
	else:
		var target = hit["collider"]
		if target != null and target.has_method("hurt"):
			target.hurt(damage, position - velocity.normalized())
		world.burst(at, color, 8, 5.0, 0.1, true)
		world.game.sfx.play_at("fizzle", at)
	queue_free()
