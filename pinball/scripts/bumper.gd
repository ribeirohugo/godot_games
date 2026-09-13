extends StaticBody2D
## Pop bumper. main.gd kicks the ball away on contact; this draws it and lights it up.

const RADIUS := 26.0

var glow_amount := 0.0
var glow: Node2D


func _ready() -> void:
	add_to_group("bumper")
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.8
	mat.friction = 0.0
	physics_material_override = mat

	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	var col := CollisionShape2D.new()
	col.shape = circle
	add_child(col)

	# Separate child with additive blending, so the flash glows over the playfield.
	glow = Node2D.new()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	glow.draw.connect(_draw_glow)
	add_child(glow)


func flash() -> void:
	glow_amount = 1.0


func _process(delta: float) -> void:
	if glow_amount > 0.0:
		glow_amount = maxf(glow_amount - delta * 4.0, 0.0)
		queue_redraw()
		glow.queue_redraw()


func _draw() -> void:
	var lit := glow_amount
	draw_circle(Vector2(4, 5), RADIUS + 4, Color(0, 0, 0, 0.4))               # shadow
	draw_circle(Vector2.ZERO, RADIUS + 4, Color(0.13, 0.13, 0.16))             # base skirt
	draw_circle(Vector2.ZERO, RADIUS, Color(0.82, 0.85, 0.9))                  # metal ring
	draw_circle(Vector2.ZERO, RADIUS - 4, Color(0.75, 0.05, 0.3).lerp(Color(1, 0.85, 0.3), lit))
	draw_circle(Vector2(-5, -6), RADIUS - 14, Color(1, 0.45, 0.65, 0.6).lerp(Color(1, 1, 0.85, 0.9), lit))
	draw_arc(Vector2.ZERO, RADIUS - 8, 0, TAU, 32, Color(1, 1, 1, 0.35), 2)
	draw_string(ThemeDB.fallback_font, Vector2(-RADIUS, 5), "100",
		HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2, 13, Color.WHITE)


func _draw_glow() -> void:
	if glow_amount <= 0.0:
		return
	for i in 4:
		glow.draw_circle(Vector2.ZERO, RADIUS + 6 + i * 8, Color(1, 0.45, 0.7, 0.13 * glow_amount))
