extends StaticBody2D
## Triangular slingshot above a flipper. main.gd kicks the ball; this draws it and flashes.

var points := PackedVector2Array()  # set before adding to the tree
var flash_amount := 0.0


func _ready() -> void:
	add_to_group("sling")
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.6
	mat.friction = 0.0
	physics_material_override = mat

	var col := CollisionPolygon2D.new()
	col.polygon = points
	add_child(col)


func flash() -> void:
	flash_amount = 1.0


func _process(delta: float) -> void:
	if flash_amount > 0.0:
		flash_amount = maxf(flash_amount - delta * 5.0, 0.0)
		queue_redraw()


func _draw() -> void:
	var shadow := PackedVector2Array()
	for p in points:
		shadow.append(p + Vector2(3, 4))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	draw_colored_polygon(points, Color(0.08, 0.3, 0.26).lerp(Color(0.45, 1, 0.75), flash_amount))

	# Lit insert inside the triangle.
	var center := (points[0] + points[1] + points[2]) / 3.0
	var inner := PackedVector2Array()
	for p in points:
		inner.append(p.lerp(center, 0.45))
	draw_colored_polygon(inner, Color(0.25, 0.95, 0.6, 0.45 + 0.55 * flash_amount))

	# White rubber band around the posts.
	var band := points.duplicate()
	band.append(points[0])
	draw_polyline(band, Color(0.95, 0.95, 0.93), 4.0, true)
	for p in points:
		draw_circle(p, 5, Color(0.55, 0.57, 0.62))
		draw_circle(p - Vector2(1, 1), 2, Color(0.95, 0.95, 1))
