extends Node2D
## The Dead Sector emblem: a skull inside a rifle scope's reticle, with one sector of a radar sweep
## lit behind it. Drawn on a 512 x 512 canvas; the menu shows it small and main.gd renders it to
## icon.png (run with "-- --render-icon").

const ORANGE := Color("f0a830")
const HOT := Color("ff6a2a")
const BONE := Color("ece6da")
const SHADE := Color("a79e8e")
const DARK := Color("12161b")

var background := true  # the menu draws the emblem without the square behind it


func _draw() -> void:
	var c := Vector2(256, 256)
	if background:
		for i in 40:
			var t := i / 39.0
			draw_circle(c, lerpf(380.0, 20.0, t), Color("0b0f13").lerp(Color("2a3440"), t * t))
		# Faint grid, like a map.
		for i in range(1, 8):
			var k := i * 64.0
			draw_line(Vector2(k, 0), Vector2(k, 512), Color(1, 1, 1, 0.035), 2.0)
			draw_line(Vector2(0, k), Vector2(512, k), Color(1, 1, 1, 0.035), 2.0)
	# The lit sector of the sweep.
	var wedge := PackedVector2Array([c])
	for i in 25:
		var a := lerpf(-PI * 0.78, -PI * 0.38, i / 24.0)
		wedge.append(c + Vector2(cos(a), sin(a)) * 212.0)
	draw_colored_polygon(wedge, Color(HOT, 0.28))
	draw_line(c, c + Vector2(cos(-PI * 0.38), sin(-PI * 0.38)) * 212.0, Color(HOT, 0.9), 6.0)
	# Reticle rings and ticks.
	draw_arc(c, 212.0, 0.0, TAU, 96, ORANGE, 14.0)
	draw_arc(c, 180.0, 0.0, TAU, 96, Color(ORANGE, 0.35), 4.0)
	for i in 4:
		var d := Vector2.RIGHT.rotated(i * PI / 2.0)
		draw_line(c + d * 150.0, c + d * 236.0, ORANGE, 14.0)
	for i in 36:
		var d := Vector2.RIGHT.rotated(i * TAU / 36.0)
		draw_line(c + d * 196.0, c + d * 206.0, Color(ORANGE, 0.6), 3.0)
	_skull(c + Vector2(0, 6))


func _skull(c: Vector2) -> void:
	# Cranium and jaw.
	draw_circle(c + Vector2(0, -26), 98.0, BONE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-78, 10), c + Vector2(78, 10), c + Vector2(62, 88),
			c + Vector2(34, 104), c + Vector2(-34, 104), c + Vector2(-62, 88)]), BONE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-62, 70), c + Vector2(62, 70), c + Vector2(54, 96), c + Vector2(-54, 96)]), SHADE)
	# Eyes: dark sockets, angled into a scowl.
	for side in [-1, 1]:
		var eye := PackedVector2Array([c + Vector2(side * 14, -6), c + Vector2(side * 70, -22), c + Vector2(side * 64, 26), c + Vector2(side * 24, 30)])
		draw_colored_polygon(eye, DARK)
	draw_circle(c + Vector2(42, 8), 9.0, HOT)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 36), c + Vector2(-13, 60), c + Vector2(13, 60)]), DARK)
	for i in 5:
		var x := -40.0 + i * 17.0
		draw_rect(Rect2(c + Vector2(x, 76), Vector2(13, 24)), BONE)
		draw_line(c + Vector2(x + 14, 76), c + Vector2(x + 14, 100), DARK, 3.0)
	# A bullet hole in the brow, with cracks.
	var hole := c + Vector2(-34, -78)
	for crack: Vector2 in [Vector2(-30, -16), Vector2(24, -22), Vector2(-20, 26), Vector2(32, 14)]:
		draw_line(hole, hole + crack, Color("6a6254"), 4.0)
	draw_circle(hole, 12.0, DARK)
