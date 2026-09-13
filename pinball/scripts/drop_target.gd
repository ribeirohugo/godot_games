extends StaticBody2D
## A drop target: sinks when the ball hits it, pops back up on reset().

signal knocked_down

const SIZE := Vector2(34, 12)

var is_down := false
var shape: CollisionShape2D


func _ready() -> void:
	add_to_group("drop_target")
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape = CollisionShape2D.new()
	shape.shape = rect
	add_child(shape)


func hit() -> void:
	if is_down:
		return
	is_down = true
	# Deferred: collision shapes can't change during the physics callback that called us.
	shape.set_deferred("disabled", true)
	queue_redraw()
	knocked_down.emit()


func reset() -> void:
	is_down = false
	shape.set_deferred("disabled", false)
	queue_redraw()


func _draw() -> void:
	if is_down:
		return
	var r := Rect2(-SIZE / 2.0, SIZE)
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, Color(1.0, 0.72, 0.1))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color(1, 0.95, 0.65))
	draw_rect(r, Color(0.45, 0.25, 0.0), false, 1.5)
