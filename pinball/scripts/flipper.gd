extends AnimatableBody2D
## A flipper that rotates around its origin (the pivot) while its key is held.

signal flipped(is_left: bool)

@export var is_left := true
@export var length := 80.0
@export var up_speed := 22.0    # radians per second when flipping up
@export var down_speed := 12.0  # radians per second when falling back

var enabled := true  # turned off on TILT and game over
var rest_angle := 0.0
var up_angle := 0.0
var was_pressed := false


func _ready() -> void:
	add_to_group("flipper")
	# Physics moves this body as a kinematic object, so its motion pushes the ball.
	sync_to_physics = false
	var dir := 1.0 if is_left else -1.0
	rest_angle = deg_to_rad(30.0) * dir
	up_angle = deg_to_rad(-30.0) * dir
	rotation = rest_angle

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.2
	mat.friction = 0.2
	physics_material_override = mat

	# Tapered body with rounded ends: wide at the pivot, narrow at the tip.
	var body := CollisionPolygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -11), Vector2(length * dir, -5),
		Vector2(length * dir, 5), Vector2(0, 11),
	])
	add_child(body)
	_add_circle(Vector2.ZERO, 11)
	_add_circle(Vector2(length * dir, 0), 5)


func _add_circle(pos: Vector2, radius: float) -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var col := CollisionShape2D.new()
	col.shape = circle
	col.position = pos
	add_child(col)


func _physics_process(delta: float) -> void:
	var key := KEY_LEFT if is_left else KEY_RIGHT
	var alt_key := KEY_A if is_left else KEY_D
	var pressed := enabled and (Input.is_physical_key_pressed(key) or Input.is_physical_key_pressed(alt_key))
	if pressed and not was_pressed:
		flipped.emit(is_left)
	was_pressed = pressed

	var target := up_angle if pressed else rest_angle
	var speed := up_speed if pressed else down_speed
	var old_rotation := rotation
	rotation = move_toward(rotation, target, speed * delta)
	if rotation != old_rotation:
		queue_redraw()


func _draw() -> void:
	var tip := Vector2(length * (1.0 if is_left else -1.0), 0)
	# The shadow offset is undone by the rotation so it always falls down-right.
	var shadow := Vector2(3, 4).rotated(-rotation)
	_capsule(shadow, tip + shadow, 12, 6, Color(0, 0, 0, 0.35))
	_capsule(Vector2.ZERO, tip, 12, 6, Color(0.8, 0.08, 0.1))      # red rubber
	_capsule(Vector2.ZERO, tip, 9, 3.5, Color(0.96, 0.95, 0.9))    # white body
	draw_circle(Vector2.ZERO, 4.5, Color(0.5, 0.52, 0.58))          # pivot bolt
	draw_circle(Vector2(-1, -1), 2, Color(0.92, 0.93, 0.97))


func _capsule(a: Vector2, b: Vector2, radius_a: float, radius_b: float, color: Color) -> void:
	draw_circle(a, radius_a, color)
	draw_circle(b, radius_b, color)
	var n := (b - a).normalized().orthogonal()
	draw_colored_polygon(PackedVector2Array([
		a + n * radius_a, b + n * radius_b, b - n * radius_b, a - n * radius_a,
	]), color)
