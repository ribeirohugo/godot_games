extends Node2D
## The Deadforge emblem: a horned demon skull over an anvil, lit by the forge. Drawn on a 512 x 512
## canvas; the menu shows it small and main.gd renders it to icon.png (run with "-- --render-icon").

const BONE := Color("e8dcc4")
const BONE_SHADE := Color("9c8c72")
const HOT := Color("ff7a1a")
const DEEP := Color("1a0806")

var background := true  # the menu draws the emblem without the square behind it


func _draw() -> void:
	if background:
		for i in 40:
			var t := i / 39.0
			draw_circle(Vector2(256, 330), lerpf(470.0, 30.0, t), DEEP.lerp(Color("7a1f0a"), t * t))
		for i in 24:
			draw_circle(Vector2(256, 400), lerpf(230.0, 40.0, i / 23.0), Color(1.0, 0.42, 0.08, 0.035))
	_anvil()
	_skull()


func _anvil() -> void:
	var body := PackedVector2Array([
		Vector2(70, 360), Vector2(442, 360), Vector2(442, 386), Vector2(370, 404), Vector2(340, 420),
		Vector2(340, 452), Vector2(390, 480), Vector2(122, 480), Vector2(172, 452), Vector2(172, 420),
		Vector2(142, 404), Vector2(70, 386)])
	draw_colored_polygon(body, Color("2b2a2e"))
	draw_colored_polygon(PackedVector2Array([Vector2(70, 360), Vector2(442, 360), Vector2(442, 370), Vector2(70, 370)]), HOT)
	draw_colored_polygon(PackedVector2Array([Vector2(24, 360), Vector2(70, 360), Vector2(70, 380)]), Color("2b2a2e"))
	draw_polyline(PackedVector2Array([Vector2(172, 452), Vector2(340, 452)]), Color(1.0, 0.5, 0.1, 0.5), 3.0)


func _skull() -> void:
	for side in [-1, 1]:
		# The horn's spine curls out from the temple, then up to a point; it tapers along the way.
		var spine := PackedVector2Array()
		for i in 17:
			var t := i / 16.0
			spine.append(Vector2(256 + side * (78 + 118 * sin(t * PI * 0.55)), 180 - 150 * t * t))
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in spine.size():
			var t := i / 16.0
			var along := (spine[mini(i + 1, 16)] - spine[maxi(i - 1, 0)]).normalized()
			var normal := Vector2(-along.y, along.x)
			var w := (1.0 - t) * 30.0 + 1.0
			outer.append(spine[i] + normal * w)
			inner.append(spine[i] - normal * w)
		inner.reverse()
		draw_colored_polygon(outer + inner, BONE_SHADE)
		var ridge := PackedVector2Array()
		for i in spine.size() - 2:
			ridge.append(spine[i].lerp(outer[i], 0.5))
		draw_polyline(ridge, BONE, 5.0)
	# Cranium and cheeks.
	draw_circle(Vector2(256, 200), 108, BONE)
	draw_colored_polygon(PackedVector2Array([Vector2(160, 230), Vector2(352, 230), Vector2(330, 318), Vector2(290, 340), Vector2(222, 340), Vector2(182, 318)]), BONE)
	draw_colored_polygon(PackedVector2Array([Vector2(182, 300), Vector2(330, 300), Vector2(320, 330), Vector2(192, 330)]), BONE_SHADE)
	# Glowing eye sockets, angled into a scowl.
	for side in [-1, 1]:
		var eye := PackedVector2Array([Vector2(256 + side * 22, 214), Vector2(256 + side * 88, 196), Vector2(256 + side * 80, 250), Vector2(256 + side * 34, 256)])
		draw_colored_polygon(eye, Color("140404"))
		draw_circle(Vector2(256 + side * 56, 232), 15, HOT)
		draw_circle(Vector2(256 + side * 56, 232), 7, Color("ffe08a"))
	draw_colored_polygon(PackedVector2Array([Vector2(256, 262), Vector2(242, 292), Vector2(270, 292)]), Color("140404"))
	# Teeth.
	for i in 6:
		var x := 206.0 + i * 17.0
		draw_rect(Rect2(x, 312, 13, 24), BONE)
		draw_line(Vector2(x + 14, 312), Vector2(x + 14, 336), Color("140404"), 3.0)
	# A crack across the brow.
	draw_polyline(PackedVector2Array([Vector2(230, 110), Vector2(244, 140), Vector2(236, 160), Vector2(252, 182)]), Color("5a4a3a"), 4.0)
