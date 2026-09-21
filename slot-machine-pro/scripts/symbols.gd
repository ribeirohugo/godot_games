extends RefCounted
## Draws every reel symbol with shapes, so the game needs no image files.
## Each symbol is designed in a 100x100 box centered on 0,0 and scaled to the cell.
## Shapes get a dark outline and a top-to-bottom shade, like stickers.

const OUTLINE := Color(0.08, 0.04, 0.1, 0.9)

var font: Font  # bold serif, for the royal letters
var ui_font: Font  # bold sans, for BAR, WILD and BONUS

# Current drawing target and transform.
var cv: CanvasItem
var c := Vector2.ZERO
var k := 1.0
var rot := 0.0


## Draws symbol `id` centered on `center` in a box `size` wide. `accent` colors the wild and scatter.
func draw(canvas: CanvasItem, id: String, center: Vector2, size: float, accent: Color) -> void:
	cv = canvas
	c = center
	k = size / 100.0
	rot = 0.0
	match id:
		"cherry": _cherry()
		"lemon": _lemon()
		"orange": _orange()
		"plum": _plum()
		"grapes": _grapes()
		"watermelon": _watermelon()
		"bell": _bell()
		"bar1": _bar(1)
		"bar2": _bar(2)
		"bar3": _bar(3)
		"seven_red": _seven(Color("ff2a3d"), Color("9c0012"))
		"seven_blue": _seven(Color("39a0ff"), Color("0a3d9c"))
		"gem_green": _gem(Color("2ee67a"))
		"gem_blue": _gem(Color("3d8bff"))
		"gem_red": _gem(Color("ff3050"))
		"gem_purple": _gem(Color("b44dff"))
		"crown": _crown()
		"J": _letter("J", Color("45a4ff"))
		"Q": _letter("Q", Color("e45cff"))
		"K": _letter("K", Color("3ddc6b"))
		"A": _letter("A", Color("ff4a4a"))
		"horseshoe": _horseshoe()
		"coin": _coin()
		"pot": _pot()
		"clover": _clover()
		"ankh": _ankh()
		"eye": _eye()
		"scarab": _scarab()
		"pyramid": _pyramid()
		"shell": _shell()
		"fish": _fish()
		"anchor": _anchor()
		"chest": _chest()
		"moon": _moon()
		"planet": _planet()
		"rocket": _rocket()
		"ufo": _ufo()
		"heart": _heart()
		"candy": _candy()
		"lollipop": _lollipop()
		"donut": _donut()
		"cupcake": _cupcake()
		"wild": _wild(accent)
		"scatter": _scatter(accent)


# --- Helpers ---------------------------------------------------------------------------------

func _p(x: float, y: float) -> Vector2:
	return c + Vector2(x, y).rotated(rot) * k


func _pts(local: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in local:
		out.append(_p(v.x, v.y))
	return out


func _ellipse(cx: float, cy: float, rx: float, ry: float, a0 := 0.0, a1 := TAU, steps := 28, tilt := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var full := is_equal_approx(a1 - a0, TAU)
	var count := steps if full else steps + 1
	for i in count:
		var a := lerpf(a0, a1, float(i) / steps)
		out.append(Vector2(cx, cy) + Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
	return out


## Filled shape with an outline, shaded from `top` to `bottom`.
func _shape(local: PackedVector2Array, top: Color, bottom: Color, outline := 3.5) -> void:
	var points := _pts(local)
	if outline > 0.0:
		var closed := points.duplicate()
		closed.append(points[0])
		cv.draw_polyline(closed, OUTLINE, outline * 2.0 * k, true)
	var min_y := INF
	var max_y := -INF
	for v in local:
		min_y = minf(min_y, v.y)
		max_y = maxf(max_y, v.y)
	var colors := PackedColorArray()
	for v in local:
		colors.append(top.lerp(bottom, (v.y - min_y) / maxf(max_y - min_y, 0.001)))
	cv.draw_polygon(points, colors)


func _ball(x: float, y: float, r: float, top: Color, bottom: Color, outline := 3.0, shine := true) -> void:
	_shape(_ellipse(x, y, r, r, 0.0, TAU, 24), top, bottom, outline)
	if shine:
		_circle(x - r * 0.35, y - r * 0.4, r * 0.22, Color(1, 1, 1, 0.65))


func _circle(x: float, y: float, r: float, color: Color) -> void:
	cv.draw_circle(_p(x, y), r * k, color)


func _line(points: Array, color: Color, width: float, outline := true) -> void:
	var pts := PackedVector2Array()
	for v in points:
		pts.append(_p(v.x, v.y))
	if outline:
		cv.draw_polyline(pts, OUTLINE, (width + 5.0) * k, true)
	cv.draw_polyline(pts, color, width * k, true)


func _bezier(a: Vector2, control: Vector2, b: Vector2, steps := 12) -> Array:
	var out := []
	for i in steps + 1:
		var t := float(i) / steps
		out.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return out


func _arc(x: float, y: float, r: float, a0: float, a1: float, color: Color, width: float, outline := true) -> void:
	if outline:
		cv.draw_arc(_p(x, y), r * k, a0 + rot, a1 + rot, 40, OUTLINE, (width + 6.0) * k, true)
	cv.draw_arc(_p(x, y), r * k, a0 + rot, a1 + rot, 40, color, width * k, true)


func _text(text: String, x: float, y: float, size: float, color: Color, f: Font, outline := 6.0, outline_color := OUTLINE) -> void:
	var px := int(size * k)
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var base := _p(x, y) + Vector2(-width / 2.0, (f.get_ascent(px) - f.get_descent(px)) / 2.0)
	if outline > 0.0:
		cv.draw_string_outline(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(outline * k), outline_color)
	cv.draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


func _leaf(x: float, y: float, rx: float, ry: float, tilt: float) -> void:
	_shape(_ellipse(x, y, rx, ry, 0.0, TAU, 20, tilt), Color("7ee06a"), Color("2e8b2e"), 2.5)
	_line([Vector2(x, y) - Vector2(rx * 0.8, 0).rotated(tilt), Vector2(x, y) + Vector2(rx * 0.8, 0).rotated(tilt)], Color(0.1, 0.4, 0.1, 0.6), 1.5, false)


# --- Fruit and classics ----------------------------------------------------------------------

func _cherry() -> void:
	var top := Vector2(6, -38)
	_line(_bezier(Vector2(-18, 8), Vector2(-14, -20), top), Color("5aa83a"), 5.0)
	_line(_bezier(Vector2(20, 14), Vector2(20, -12), top), Color("5aa83a"), 5.0)
	_leaf(22, -36, 17, 8, -0.35)
	_ball(-18, 20, 20, Color("ff4d5a"), Color("a3001b"))
	_ball(18, 26, 20, Color("ff4d5a"), Color("a3001b"))


func _lemon() -> void:
	_shape(_ellipse(-36, 8, 8, 6, 0, TAU, 12, -0.35), Color("ffe94d"), Color("e0a800"), 3.0)
	_shape(_ellipse(36, -8, 8, 6, 0, TAU, 12, -0.35), Color("ffe94d"), Color("e0a800"), 3.0)
	_shape(_ellipse(0, 0, 38, 28, 0, TAU, 32, -0.35), Color("fff176"), Color("e6ac00"))
	_shape(_ellipse(-10, -10, 12, 5, 0, TAU, 12, -0.35), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.2), 0.0)


func _orange() -> void:
	_ball(0, 4, 36, Color("ffb13b"), Color("e25c00"))
	for v in [Vector2(-14, 10), Vector2(10, 18), Vector2(18, -4), Vector2(-4, 26), Vector2(-20, -8)]:
		_circle(v.x, v.y, 1.6, Color(0.7, 0.3, 0, 0.5))
	_line([Vector2(0, -30), Vector2(2, -40)], Color("6b3e1f"), 4.0)
	_leaf(16, -38, 14, 7, -0.3)


func _plum() -> void:
	_shape(_ellipse(0, 6, 31, 36, 0, TAU, 30), Color("b05cff"), Color("4a0f8a"))
	_line(_bezier(Vector2(2, -26), Vector2(-10, 6), Vector2(2, 38)), Color(0.25, 0.05, 0.45, 0.6), 2.5, false)
	_shape(_ellipse(-12, -8, 7, 13, 0, TAU, 14, 0.3), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.15), 0.0)
	_leaf(14, -34, 14, 6, -0.5)


func _grapes() -> void:
	_line([Vector2(0, -30), Vector2(4, -44)], Color("6b3e1f"), 4.0)
	_leaf(-16, -34, 15, 7, 0.4)
	var rows := [[-24, -18, 4], [-16, -2, 3], [-8, 14, 2], [0, 30, 1]]
	for row in rows:
		for i in row[2]:
			_ball(row[0] + i * 16, row[1], 10, Color("a36bff"), Color("4b1b99"), 2.5)


func _watermelon() -> void:
	_shape(_ellipse(0, -14, 46, 46, 0, PI, 28), Color("5dbb4a"), Color("1f6b1f"))
	_shape(_ellipse(0, -14, 40, 40, 0, PI, 28), Color("e8ffd8"), Color("b8e6a0"), 0.0)
	_shape(_ellipse(0, -14, 35, 35, 0, PI, 28), Color("ff5a6a"), Color("d8203a"), 0.0)
	for v in [Vector2(-18, -2), Vector2(0, 4), Vector2(18, -2), Vector2(-8, 12), Vector2(10, 12)]:
		_shape(_ellipse(v.x, v.y, 2.5, 4, 0, TAU, 8), Color("222"), Color("000"), 0.0)


func _bell() -> void:
	_ball(0, -36, 6, Color("ffe27a"), Color("c48a00"), 2.5, false)
	var body := PackedVector2Array([Vector2(-10, -32), Vector2(10, -32), Vector2(21, -22), Vector2(25, 0), Vector2(30, 16),
			Vector2(38, 26), Vector2(-38, 26), Vector2(-30, 16), Vector2(-25, 0), Vector2(-21, -22)])
	_ball(0, 32, 8, Color("ffd54f"), Color("b07800"), 2.5, false)
	_shape(body, Color("fff08a"), Color("d49a00"))
	_shape(_ellipse(0, 26, 38, 6, 0, TAU, 24), Color("ffcf40"), Color("a86f00"), 2.5)
	_shape(PackedVector2Array([Vector2(-14, -22), Vector2(-8, -22), Vector2(-14, 14), Vector2(-20, 14)]), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.1), 0.0)


func _bar(count: int) -> void:
	var h := 19.0
	var gap := 5.0
	var total := count * h + (count - 1) * gap
	for i in count:
		var y := -total / 2.0 + i * (h + gap)
		var rect := PackedVector2Array([Vector2(-40, y), Vector2(40, y), Vector2(40, y + h), Vector2(-40, y + h)])
		_shape(rect, Color("3a3a44"), Color("0c0c10"), 3.0)
		_line([Vector2(-38, y + 1.5), Vector2(38, y + 1.5)], Color(1, 0.85, 0.3, 0.8), 1.5, false)
		_text("BAR", 0, y + h / 2.0, 17, Color("ffe066"), ui_font, 0.0)


func _seven(light: Color, dark: Color) -> void:
	var seven := PackedVector2Array([Vector2(-30, -40), Vector2(33, -40), Vector2(33, -27), Vector2(2, 42), Vector2(-17, 42),
			Vector2(13, -25), Vector2(-30, -25)])
	_shape(seven, light, dark, 4.0)
	_line([Vector2(-26, -36), Vector2(28, -36)], Color(1, 1, 1, 0.55), 2.5, false)


func _gem(color: Color) -> void:
	var outline := PackedVector2Array([Vector2(-24, -30), Vector2(24, -30), Vector2(42, -10), Vector2(0, 40), Vector2(-42, -10)])
	_shape(outline, color.lightened(0.3), color.darkened(0.4), 3.5)
	var facets := [
		[[Vector2(-24, -30), Vector2(24, -30), Vector2(42, -10), Vector2(-42, -10)], color.lightened(0.25)],
		[[Vector2(-11, -30), Vector2(11, -30), Vector2(20, -10), Vector2(-20, -10)], color.lightened(0.55)],
		[[Vector2(-42, -10), Vector2(-20, -10), Vector2(0, 40)], color.darkened(0.1)],
		[[Vector2(-20, -10), Vector2(20, -10), Vector2(0, 40)], color],
		[[Vector2(20, -10), Vector2(42, -10), Vector2(0, 40)], color.darkened(0.35)],
	]
	for facet in facets:
		var pts := PackedVector2Array(facet[0])
		cv.draw_colored_polygon(_pts(pts), facet[1])
	_line([Vector2(-42, -10), Vector2(42, -10)], Color(1, 1, 1, 0.35), 1.2, false)
	_sparkle(-16, -22, 7)


func _sparkle(x: float, y: float, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var radius := r if i % 2 == 0 else r * 0.25
		pts.append(Vector2(x, y) + Vector2.from_angle(i * TAU / 8.0) * radius)
	cv.draw_colored_polygon(_pts(pts), Color(1, 1, 1, 0.9))


func _crown() -> void:
	var spikes := PackedVector2Array([Vector2(-36, 16), Vector2(-42, -26), Vector2(-20, -4), Vector2(0, -36), Vector2(20, -4),
			Vector2(42, -26), Vector2(36, 16)])
	_shape(spikes, Color("fff08a"), Color("d49a00"))
	for v in [Vector2(-42, -26), Vector2(0, -36), Vector2(42, -26)]:
		_ball(v.x, v.y, 6, Color("fff6c0"), Color("e0a800"), 2.5, false)
	_shape(PackedVector2Array([Vector2(-38, 12), Vector2(38, 12), Vector2(38, 32), Vector2(-38, 32)]), Color("ffd54f"), Color("b07800"))
	_ball(-20, 22, 5, Color("ff6b7a"), Color("b0001b"), 1.5)
	_ball(0, 22, 6, Color("6bb8ff"), Color("0a4db0"), 1.5)
	_ball(20, 22, 5, Color("7dffa0"), Color("0a8a3a"), 1.5)


func _letter(letter: String, color: Color) -> void:
	_text(letter, 0, 2, 84, color.darkened(0.1), font, 16.0, OUTLINE)
	_text(letter, 0, 2, 84, color, font, 7.0, Color("ffe9a0"))
	_text(letter, -1, 0, 84, color.lightened(0.2), font, 0.0)


# --- Lucky, Egypt and ocean ------------------------------------------------------------------

func _horseshoe() -> void:
	_arc(0, -6, 30, -0.25, PI + 0.25, Color("c9ced8"), 15.0)
	_arc(0, -6, 30, -0.25, PI + 0.25, Color("eef1f6"), 5.0, false)
	for i in 7:
		var a := lerpf(0.0, PI, float(i) / 6.0)
		_circle(cos(a) * 30, -6 + sin(a) * 30, 2.2, Color("4a4f5a"))


func _coin() -> void:
	_ball(0, 0, 40, Color("ffe066"), Color("c47d00"), 3.5, false)
	_circle(0, 0, 32, Color("f7c948"))
	cv.draw_arc(_p(0, 0), 30 * k, 0, TAU, 40, Color("b87a00"), 2.5 * k, true)
	var star := PackedVector2Array()
	for i in 10:
		var radius := 18.0 if i % 2 == 0 else 7.5
		star.append(Vector2.from_angle(-PI / 2.0 + i * TAU / 10.0) * radius)
	_shape(star, Color("ffe89a"), Color("d99a00"), 1.5)
	_circle(-18, -20, 6, Color(1, 1, 1, 0.5))


func _pot() -> void:
	for v in [Vector2(-20, -18), Vector2(0, -24), Vector2(20, -18), Vector2(-10, -30), Vector2(10, -32)]:
		_shape(_ellipse(v.x, v.y, 11, 7, 0, TAU, 16), Color("ffe066"), Color("c47d00"), 2.0)
	_shape(_ellipse(0, 12, 38, 28, 0, TAU, 30), Color("4a4a55"), Color("0e0e14"))
	_shape(_ellipse(0, -12, 40, 8, 0, TAU, 24), Color("5c5c68"), Color("1a1a22"), 3.0)
	_shape(_ellipse(-14, 4, 6, 12, 0, TAU, 12, 0.3), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.05), 0.0)
	_line([Vector2(-26, 36), Vector2(-30, 44)], Color("222"), 5.0)
	_line([Vector2(26, 36), Vector2(30, 44)], Color("222"), 5.0)


func _clover() -> void:
	_line(_bezier(Vector2(0, 4), Vector2(4, 28), Vector2(18, 44)), Color("2e8b2e"), 6.0)
	for i in 4:
		var dir := Vector2.from_angle(-PI / 4.0 + i * PI / 2.0)
		var side := dir.orthogonal()
		var base := dir * 18.0 - Vector2(0, 6)
		for s in [-1, 1]:
			var p: Vector2 = base + side * 8.0 * s + dir * 3.0
			_circle(p.x, p.y, 16.5, OUTLINE)
	for i in 4:
		var dir := Vector2.from_angle(-PI / 4.0 + i * PI / 2.0)
		var side := dir.orthogonal()
		var base := dir * 18.0 - Vector2(0, 6)
		for s in [-1, 1]:
			var p: Vector2 = base + side * 8.0 * s + dir * 3.0
			_shape(_ellipse(p.x, p.y, 13, 13, 0, TAU, 18), Color("8cf07a"), Color("1f9a3a"), 0.0)
		_line([Vector2(0, -6), Vector2(0, -6) + dir * 26.0], Color(0.1, 0.45, 0.15, 0.7), 1.8, false)
	_circle(0, -6, 9, Color("4ccf5e"))
	_circle(-18, -24, 4, Color(1, 1, 1, 0.5))


func _ankh() -> void:
	_arc(0, -24, 14, 0, TAU, Color("ffd54f"), 9.0)
	var bar := PackedVector2Array([Vector2(-30, -8), Vector2(30, -8), Vector2(30, 4), Vector2(-30, 4)])
	var stem := PackedVector2Array([Vector2(-6, 4), Vector2(6, 4), Vector2(12, 44), Vector2(-12, 44)])
	_shape(stem, Color("ffe27a"), Color("c48a00"))
	_shape(bar, Color("ffe89a"), Color("d49a00"))
	_line([Vector2(-8, -30), Vector2(-12, -22)], Color(1, 1, 1, 0.6), 2.0, false)


func _eye() -> void:
	var almond := PackedVector2Array()
	for v in _bezier(Vector2(-42, 0), Vector2(0, -34), Vector2(42, 0), 14):
		almond.append(v)
	var lower := _bezier(Vector2(42, 0), Vector2(0, 26), Vector2(-42, 0), 14)
	for i in range(1, lower.size() - 1):
		almond.append(lower[i])
	_shape(almond, Color("ffffff"), Color("d9e2ea"), 3.5)
	_ball(2, -1, 13, Color("4fa3ff"), Color("0a3d9c"), 2.0, false)
	_circle(2, -1, 6, Color("0a0a12"))
	_circle(-2, -5, 3, Color(1, 1, 1, 0.8))
	_line(_bezier(Vector2(-40, -18), Vector2(0, -44), Vector2(44, -16), 12), Color("123a8a"), 5.0)
	_line(_bezier(Vector2(-8, 12), Vector2(-14, 36), Vector2(6, 38), 10), Color("123a8a"), 4.5)
	_line([Vector2(18, 12), Vector2(34, 36)], Color("123a8a"), 4.5)


func _scarab() -> void:
	for s in [-1, 1]:
		for i in 3:
			var y := -4.0 + i * 16.0
			_line([Vector2(s * 20, y), Vector2(s * 38, y - 8 + i * 8)], Color("1f3b2f"), 3.5)
	_shape(_ellipse(0, -28, 14, 9, 0, TAU, 16), Color("3fd6a0"), Color("0a6a4a"), 3.0)
	_shape(_ellipse(0, 8, 26, 30, 0, TAU, 28), Color("5ef0c0"), Color("0a5a6a"))
	_line([Vector2(0, -20), Vector2(0, 36)], Color(0.02, 0.2, 0.2, 0.8), 2.0, false)
	_shape(PackedVector2Array([Vector2(-16, -10), Vector2(-8, -12), Vector2(-10, 10), Vector2(-18, 8)]), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.1), 0.0)
	_arc(0, 8, 29, PI * 1.15, PI * 1.85, Color("ffd54f"), 2.5, false)


func _pyramid() -> void:
	_ball(20, -26, 14, Color("ffe066"), Color("ff8a00"), 2.5, false)
	_shape(PackedVector2Array([Vector2(0, -38), Vector2(46, 34), Vector2(-46, 34)]), Color("ffe08a"), Color("c48a00"))
	cv.draw_colored_polygon(_pts(PackedVector2Array([Vector2(0, -38), Vector2(46, 34), Vector2(6, 34)])), Color(0.45, 0.25, 0, 0.35))
	for i in 4:
		var y := -18.0 + i * 13.0
		var half := (y + 38.0) / 72.0 * 46.0
		_line([Vector2(-half + 2, y), Vector2(half - 2, y)], Color(0.45, 0.28, 0, 0.45), 1.5, false)


func _shell() -> void:
	var fan := PackedVector2Array([Vector2(0, 34)])
	var edge := []
	for i in 25:
		var t := float(i) / 24.0
		var a := lerpf(PI * 1.08, PI * 1.92, t)
		var r := 44.0 + 4.0 * absf(sin(t * PI * 6.0))
		var v := Vector2(0, 16) + Vector2.from_angle(a) * r
		fan.append(v)
		edge.append(v)
	_shape(fan, Color("ffd3c0"), Color("f07a8a"))
	for i in range(2, 24, 3):
		_line([Vector2(0, 30), edge[i].lerp(Vector2(0, 30), 0.1)], Color(0.7, 0.25, 0.35, 0.55), 2.0, false)
	_shape(PackedVector2Array([Vector2(-12, 30), Vector2(12, 30), Vector2(8, 42), Vector2(-8, 42)]), Color("ffc4b8"), Color("e06a7a"), 2.5)


func _fish() -> void:
	_shape(PackedVector2Array([Vector2(24, 0), Vector2(46, -22), Vector2(42, 0), Vector2(46, 22)]), Color("ffb13b"), Color("e25c00"))
	_shape(PackedVector2Array([Vector2(-10, -16), Vector2(8, -34), Vector2(14, -14)]), Color("ffb13b"), Color("e25c00"), 2.5)
	_shape(_ellipse(-4, 0, 32, 21, 0, TAU, 30), Color("ffc24d"), Color("e2480a"))
	for x in [0.0, 12.0]:
		_arc(x, 0, 16, -0.9, 0.9, Color(1, 1, 1, 0.55), 3.0, false)
	_circle(-20, -5, 6, Color.WHITE)
	_circle(-21, -5, 3.2, Color("111"))
	_line(_bezier(Vector2(-34, 6), Vector2(-30, 10), Vector2(-26, 8), 4), Color("7a2a00"), 1.8, false)


func _anchor() -> void:
	var steel := Color("5f7d99")
	for pass_i in 2:
		var col := OUTLINE if pass_i == 0 else steel
		var extra := 5.0 if pass_i == 0 else 0.0
		cv.draw_arc(_p(0, -34), 8 * k, 0, TAU, 24, col, (6 + extra) * k, true)
		_line([Vector2(0, -26), Vector2(0, 34)], col, 8 + extra, false)
		_line([Vector2(-20, -14), Vector2(20, -14)], col, 7 + extra, false)
		cv.draw_arc(_p(0, 4), 32 * k, 0.15 * PI, 0.85 * PI, 32, col, (7 + extra) * k, true)
	for s in [-1, 1]:
		var tip := Vector2(cos(0.15 * PI) * 32 * s, 4 + sin(0.15 * PI) * 32)
		_shape(PackedVector2Array([tip + Vector2(0, -12), tip + Vector2(s * 9, 4), tip + Vector2(-s * 7, 2)]), steel.lightened(0.2), steel.darkened(0.3), 2.5)
	_line([Vector2(-2, -24), Vector2(-2, 30)], Color(1, 1, 1, 0.35), 2.0, false)


func _chest() -> void:
	_circle(0, -8, 30, Color(1, 0.85, 0.3, 0.25))
	_shape(_ellipse(0, -4, 38, 24, PI, TAU, 20), Color("a0622e"), Color("6b3a14"))
	_shape(PackedVector2Array([Vector2(-38, -4), Vector2(38, -4), Vector2(38, 34), Vector2(-38, 34)]), Color("8a4f22"), Color("4a2408"))
	for x in [-24.0, 24.0]:
		_line([Vector2(x, -24 + absf(x) * 0.25), Vector2(x, 34)], Color("f2c14e"), 5.0, false)
	_line([Vector2(-38, -4), Vector2(38, -4)], Color("f2c14e"), 5.0, false)
	_shape(PackedVector2Array([Vector2(-7, -8), Vector2(7, -8), Vector2(7, 10), Vector2(-7, 10)]), Color("ffe066"), Color("c48a00"), 2.0)
	_circle(0, 2, 2.2, Color("3a2000"))


# --- Space and sweets ------------------------------------------------------------------------

func _moon() -> void:
	var crescent := PackedVector2Array()
	for i in 25:
		crescent.append(Vector2.from_angle(deg_to_rad(lerpf(60, 300, float(i) / 24.0))) * 36.0)
	for i in range(1, 24):
		var a := deg_to_rad(lerpf(279.7, 80.3, float(i) / 24.0))
		crescent.append(Vector2(13, 0) + Vector2.from_angle(a) * 29.8)
	rot = -0.3
	_shape(crescent, Color("fff6a0"), Color("f0b400"))
	_circle(-20, -6, 3.5, Color(0.8, 0.6, 0, 0.35))
	_circle(-14, 14, 2.5, Color(0.8, 0.6, 0, 0.35))
	rot = 0.0
	_sparkle(26, -26, 9)
	_sparkle(34, 16, 6)


func _planet() -> void:
	var back := PackedVector2Array()
	var front := PackedVector2Array()
	for i in 21:
		var a := lerpf(PI, TAU, i / 20.0)
		back.append(_p(cos(a) * 48 * cos(-0.35) - sin(a) * 12 * sin(-0.35), cos(a) * 48 * sin(-0.35) + sin(a) * 12 * cos(-0.35)))
		var b := lerpf(0.0, PI, i / 20.0)
		front.append(_p(cos(b) * 48 * cos(-0.35) - sin(b) * 12 * sin(-0.35), cos(b) * 48 * sin(-0.35) + sin(b) * 12 * cos(-0.35)))
	cv.draw_polyline(back, OUTLINE, 10 * k, true)
	cv.draw_polyline(back, Color("ffcc80"), 5 * k, true)
	_ball(0, 0, 28, Color("ff9e6b"), Color("b0324a"), 3.5, false)
	_arc(0, 0, 20, PI * 1.1, PI * 1.5, Color(1, 1, 1, 0.3), 5.0, false)
	_line([Vector2(-26, 8), Vector2(26, 2)], Color(0.6, 0.15, 0.25, 0.4), 4.0, false)
	cv.draw_polyline(front, OUTLINE, 10 * k, true)
	cv.draw_polyline(front, Color("ffe0b2"), 5 * k, true)


func _rocket() -> void:
	rot = 0.6
	_shape(PackedVector2Array([Vector2(-8, 20), Vector2(8, 20), Vector2(0, 46)]), Color("ffe066"), Color("ff5a00"), 2.5)
	_shape(PackedVector2Array([Vector2(-13, 2), Vector2(-28, 26), Vector2(-12, 20)]), Color("ff5a6a"), Color("a0001b"), 2.5)
	_shape(PackedVector2Array([Vector2(13, 2), Vector2(28, 26), Vector2(12, 20)]), Color("ff5a6a"), Color("a0001b"), 2.5)
	_shape(PackedVector2Array([Vector2(0, -46), Vector2(12, -30), Vector2(14, 20), Vector2(-14, 20), Vector2(-12, -30)]), Color("ffffff"), Color("b8c2d0"))
	_shape(PackedVector2Array([Vector2(0, -46), Vector2(12, -30), Vector2(-12, -30)]), Color("ff5a6a"), Color("c0102a"), 0.0)
	_ball(0, -10, 7, Color("7fd8ff"), Color("1a6ab0"), 2.5)
	rot = 0.0


func _ufo() -> void:
	_shape(PackedVector2Array([Vector2(-14, 14), Vector2(14, 14), Vector2(30, 46), Vector2(-30, 46)]), Color(0.6, 1, 0.6, 0.45), Color(0.6, 1, 0.6, 0.05), 0.0)
	_shape(_ellipse(0, -6, 19, 18, PI, TAU, 16), Color("c8f7ff"), Color("4fb8d9"), 3.0)
	_shape(_ellipse(0, 6, 46, 13, 0, TAU, 32), Color("d8dde6"), Color("6a7280"))
	var colors := [Color("ff5a6a"), Color("ffe066"), Color("7dff8a"), Color("5ab8ff"), Color("ff7ae0")]
	for i in 5:
		_circle(-28 + i * 14, 8, 3.5, colors[i])
	_circle(-8, -14, 4, Color(1, 1, 1, 0.7))


func _heart() -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := i * TAU / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(Vector2(x, y + 2) * 2.5)
	_shape(pts, Color("ff6b9a"), Color("c4003a"))
	_shape(_ellipse(-18, -14, 8, 5, 0, TAU, 12, -0.6), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.3), 0.0)


func _candy() -> void:
	_shape(PackedVector2Array([Vector2(-20, 0), Vector2(-46, -18), Vector2(-40, 0), Vector2(-46, 18)]), Color("ffe066"), Color("f09000"), 2.5)
	_shape(PackedVector2Array([Vector2(20, 0), Vector2(46, -18), Vector2(40, 0), Vector2(46, 18)]), Color("ffe066"), Color("f09000"), 2.5)
	_ball(0, 0, 24, Color("ff6ba8"), Color("c4005a"), 3.0, false)
	for i in 3:
		_arc(-24 + i * 16, -14, 24, 0.5, 1.6, Color(1, 1, 1, 0.8), 4.0, false)
	_circle(-8, -10, 4, Color(1, 1, 1, 0.6))


func _lollipop() -> void:
	_line([Vector2(0, 8), Vector2(0, 46)], Color("f4f4f4"), 6.0)
	_ball(0, -12, 30, Color("ff8ac2"), Color("d0006a"), 3.5, false)
	var spiral := []
	for i in 50:
		var t := float(i) / 49.0
		spiral.append(Vector2(0, -12) + Vector2.from_angle(t * TAU * 2.6) * (2.0 + t * 26.0))
	_line(spiral, Color(1, 1, 1, 0.9), 5.0, false)
	_circle(-12, -26, 4, Color(1, 1, 1, 0.6))


func _donut() -> void:
	cv.draw_arc(_p(0, 2), 26 * k, 0, TAU, 40, OUTLINE, 30 * k, true)
	cv.draw_arc(_p(0, 2), 26 * k, 0, TAU, 40, Color("d99a55"), 24 * k, true)
	var frosting := PackedVector2Array()
	for i in 40:
		var a := i * TAU / 40.0
		frosting.append(_p(0, 2) + Vector2.from_angle(a) * (26 + 2.5 * sin(a * 7)) * k)
	frosting.append(frosting[0])
	cv.draw_polyline(frosting, Color("ff7ab8"), 17 * k, true)
	var colors := [Color("fff"), Color("7dd8ff"), Color("ffe066"), Color("7dff8a")]
	for i in 12:
		var a := i * TAU / 12.0 + 0.2
		var p := Vector2(0, 2) + Vector2.from_angle(a) * (26 + (i % 3 - 1) * 4)
		var d := Vector2.from_angle(a * 3.0) * 3.0
		_line([p - d, p + d], colors[i % 4], 2.5, false)


func _cupcake() -> void:
	_shape(PackedVector2Array([Vector2(-28, 8), Vector2(28, 8), Vector2(20, 42), Vector2(-20, 42)]), Color("6ad0ff"), Color("1a7ab0"))
	for i in 5:
		var x := -16.0 + i * 8.0
		_line([Vector2(x * 1.3, 10), Vector2(x, 40)], Color(1, 1, 1, 0.45), 2.0, false)
	for v in [Vector3(-16, 0, 15), Vector3(16, 0, 15), Vector3(0, -6, 18), Vector3(0, -22, 13)]:
		_circle(v.x, v.y, v.z + 3, OUTLINE)
	for v in [Vector3(-16, 0, 15), Vector3(16, 0, 15), Vector3(0, -6, 18), Vector3(0, -22, 13)]:
		_shape(_ellipse(v.x, v.y, v.z, v.z, 0, TAU, 20), Color("fff0f6"), Color("ff9ac8"), 0.0)
	_line(_bezier(Vector2(0, -38), Vector2(2, -46), Vector2(8, -48), 5), Color("5aa83a"), 2.5)
	_ball(0, -36, 7, Color("ff4d5a"), Color("a3001b"), 2.5)


# --- Specials --------------------------------------------------------------------------------

func _wild(accent: Color) -> void:
	var badge := PackedVector2Array([Vector2(-44, -22), Vector2(44, -22), Vector2(48, 0), Vector2(44, 22), Vector2(-44, 22), Vector2(-48, 0)])
	_circle(0, 0, 46, Color(accent, 0.25))
	_shape(badge, accent.lightened(0.35), accent.darkened(0.45), 4.0)
	var inner := PackedVector2Array([Vector2(-40, -18), Vector2(40, -18), Vector2(43, 0), Vector2(40, 18), Vector2(-40, 18), Vector2(-43, 0)])
	var closed := _pts(inner)
	closed.append(closed[0])
	cv.draw_polyline(closed, Color("ffe38a"), 2.5 * k, true)
	_text("WILD", 0, 1, 30, Color("fff8d8"), ui_font, 7.0)
	_sparkle(-34, -28, 8)
	_sparkle(36, 26, 7)


func _scatter(accent: Color) -> void:
	var burst := PackedVector2Array()
	for i in 24:
		var radius := 48.0 if i % 2 == 0 else 36.0
		burst.append(Vector2.from_angle(i * TAU / 24.0) * radius)
	_shape(burst, Color("ffe066"), Color("ff7a00"), 3.0)
	_ball(0, 0, 30, accent.lightened(0.2), accent.darkened(0.5), 3.0, false)
	var star := PackedVector2Array()
	for i in 10:
		var radius := 14.0 if i % 2 == 0 else 6.0
		star.append(Vector2(0, -10) + Vector2.from_angle(-PI / 2.0 + i * TAU / 10.0) * radius)
	_shape(star, Color("fff6c0"), Color("ffc400"), 2.0)
	_text("BONUS", 0, 14, 15, Color.WHITE, ui_font, 5.0)
