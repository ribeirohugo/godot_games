extends RefCounted
## Isometric geometry plus the code-drawn look of land blocks, so the project needs no image files.
## Grid cells: x grows toward the screen's bottom-right, y toward the bottom-left.

const HW := 28.0  # half width of a cell's top diamond
const HH := 14.0  # half height of a cell's top diamond
const THICK := 12.0  # height of a land block's side

const GRASS := Color(0.47, 0.76, 0.3)
const GRASS_DARK := Color(0.33, 0.6, 0.22)
const SAND := Color(0.93, 0.84, 0.58)
const DIRT_LEFT := Color(0.58, 0.4, 0.23)
const DIRT_RIGHT := Color(0.45, 0.3, 0.17)

# Neighbour offsets, indexed by direction: 0 east (+x), 1 south (+y), 2 west (-x), 3 north (-y).
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


static func cell_pos(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * HW, (cell.x + cell.y) * HH)


static func cell_at(p: Vector2) -> Vector2i:
	var u := p.x / HW
	var v := p.y / HH
	return Vector2i(floori((u + v) / 2.0 + 0.5), floori((v - u) / 2.0 + 0.5))


## Screen-space direction the animal faces when walking in grid direction `dir`.
static func dir_vector(dir: int) -> Vector2:
	return cell_pos(Vector2(DIRS[dir])).normalized()


static func hash_cell(cell: Vector2i, salt: int = 0) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)) % 1000


## One land block: two dirt sides and a grass top. `shore` holds one bool per direction,
## true where the neighbour is water, to draw a sandy edge there.
static func draw_land(ci: CanvasItem, c: Vector2, shore: Array, variation: int, alpha: float = 1.0) -> void:
	var t := THICK
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-HW, 0), c + Vector2(0, HH), c + Vector2(0, HH + t), c + Vector2(-HW, t)]),
		_a(DIRT_LEFT, alpha))
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, HH), c + Vector2(HW, 0), c + Vector2(HW, t), c + Vector2(0, HH + t)]),
		_a(DIRT_RIGHT, alpha))
	var shade := (variation % 7) * 0.006
	ci.draw_colored_polygon(_diamond(c, 1.0), _a(GRASS.darkened(shade), alpha))

	# Sandy shore along edges that face water. Diamond vertices: top, right, bottom, left.
	var v := [c + Vector2(0, -HH), c + Vector2(HW, 0), c + Vector2(0, HH), c + Vector2(-HW, 0)]
	var edges := [[1, 2], [2, 3], [3, 0], [0, 1]]  # east, south, west, north
	for d in 4:
		if shore[d]:
			var a: Vector2 = v[edges[d][0]]
			var b: Vector2 = v[edges[d][1]]
			var inset := (c - (a + b) * 0.5) * 0.18
			ci.draw_colored_polygon(PackedVector2Array([a, b, b + inset, a + inset]), _a(SAND, alpha))

	# A few tufts and flowers so big meadows don't look flat.
	var kind := variation % 9
	if kind == 0:
		for i in 3:
			var x := -5.0 + i * 5.0
			ci.draw_line(c + Vector2(x, 2), c + Vector2(x * 1.4, -4), _a(GRASS_DARK, alpha), 1.5)
	elif kind == 1:
		ci.draw_circle(c + Vector2(-4, 1), 2.2, _a(Color(1, 0.55, 0.7), alpha))
		ci.draw_circle(c + Vector2(5, -2), 1.8, _a(Color(1, 0.95, 0.5), alpha))


## Island outline: a wobbly ring of points around `c`. `radius` is in cells, `inward` points
## back toward the board so the shore there stays full and meets the connector block.
static func island_outline(c: Vector2, radius: float, inward: Vector2, shape_seed: int, scale: float = 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var phase := float(shape_seed % 97) * 0.37
	var inward_angle := inward.angle()
	var count := 40
	for i in count:
		var a := TAU * i / count
		var wobble := 0.2 * sin(3.0 * a + phase) + 0.12 * sin(5.0 * a + phase * 1.7) + 0.07 * sin(8.0 * a + phase * 2.3)
		var near := clampf(1.0 - absf(angle_difference(a, inward_angle)) / 1.0, 0.0, 1.0)
		var r := lerpf(radius * (1.0 + wobble), radius * 1.08, near) * scale
		points.append(c + cell_pos(Vector2(cos(a), sin(a)) * r))
	return points


## A natural-looking island: sandy sides, a sand beach and a grassy middle.
static func draw_island(ci: CanvasItem, c: Vector2, radius: float, inward: Vector2, shape_seed: int) -> void:
	var outline := island_outline(c, radius, inward, shape_seed)
	ci.draw_colored_polygon(_shifted(island_outline(c, radius, inward, shape_seed, 1.12), Vector2(0, THICK + 3)),
		Color(1, 1, 1, 0.3))  # foam
	for i in range(int(THICK), 0, -2):
		ci.draw_colored_polygon(_shifted(outline, Vector2(0, i)), SAND.darkened(0.15 + 0.2 * i / THICK))
	ci.draw_colored_polygon(outline, SAND)
	var grass := island_outline(c + Vector2(-2, -2), radius * 0.68, inward, shape_seed + 31)
	ci.draw_colored_polygon(grass, GRASS)
	for tuft in [Vector2(-22, -4), Vector2(18, -8), Vector2(6, 8), Vector2(-8, -12)]:
		for i in 3:
			var x := -4.0 + i * 4.0
			ci.draw_line(c + tuft + Vector2(x, 2), c + tuft + Vector2(x * 1.4, -4), GRASS_DARK, 1.5)
	# Shells and a couple of rocks on the beach.
	var n := outline.size()
	for k in [5, 17, 29]:
		var p := c.lerp(outline[(k + shape_seed) % n], 0.85)
		ci.draw_circle(p, 2.0, Color(1, 0.95, 0.9))
	for k in [11, 34]:
		var p := c.lerp(outline[(k + shape_seed) % n], 0.9)
		ci.draw_circle(p, 4.0, Color(0.55, 0.55, 0.5))
		ci.draw_circle(p + Vector2(-1, -1.5), 2.5, Color(0.68, 0.68, 0.62))


static func draw_palm(ci: CanvasItem, base: Vector2, time: float) -> void:
	var sway := sin(time * 1.5) * 1.5
	var top := base + Vector2(-6 + sway, -46)
	var trunk := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		trunk.append(base.lerp(top, t) + Vector2(sin(t * PI) * 5.0, 0))
	ci.draw_polyline(trunk, Color(0.45, 0.3, 0.16), 4.5, true)
	for i in range(1, 8, 2):
		var p := trunk[i]
		ci.draw_line(p + Vector2(-2.5, 0), p + Vector2(2.5, 1), Color(0.35, 0.22, 0.1), 1.2)
	var leaf := Color(0.25, 0.62, 0.22)
	for a in [-160.0, -125.0, -55.0, -20.0, 20.0, 160.0]:
		var ang := deg_to_rad(a) + sin(time * 2.0 + a) * 0.05
		var tip := top + Vector2(cos(ang), sin(ang) * 0.6 + 0.35) * 22.0
		var mid := top.lerp(tip, 0.5) + Vector2(0, -5)
		ci.draw_polyline(PackedVector2Array([top, mid, tip]), leaf, 4.0, true)
	ci.draw_circle(top + Vector2(-2, 3), 2.8, Color(0.4, 0.28, 0.12))
	ci.draw_circle(top + Vector2(3, 3), 2.8, Color(0.4, 0.28, 0.12))


static func draw_flag(ci: CanvasItem, base: Vector2, color: Color, time: float) -> void:
	var top := base + Vector2(0, -34)
	ci.draw_line(base, top, Color(0.3, 0.22, 0.15), 2.5)
	var wave := sin(time * 4.0) * 2.5
	ci.draw_colored_polygon(PackedVector2Array([
		top, top + Vector2(16, 5 + wave), top + Vector2(0, 11)]), color)


## The food waiting at the goal: 0 bananas, 1 carrots, 2 fish, 3 bone (same order as the animals).
static func draw_goal(ci: CanvasItem, c: Vector2, kind: int, time: float) -> void:
	var p := c + Vector2(0, sin(time * 3.0) * 1.5)
	match kind:
		0:
			# A bunch of three bananas hanging from one stem, fanned out.
			var stem := p + Vector2(-10, -24)
			for i in 3:
				_banana(ci, stem, deg_to_rad(-38.0 + i * 36.0), 18.0 - i * 1.5)
			ci.draw_line(stem + Vector2(1, 1), stem + Vector2(-1.5, -5), Color(0.36, 0.25, 0.08), 3.0, true)
		1:
			# Two carrots lying crossed, leafy tops up.
			_carrot(ci, p + Vector2(-7, -21), deg_to_rad(28))
			_carrot(ci, p + Vector2(7, -22), deg_to_rad(-22))
		2:
			var body := p + Vector2(0, -8)
			ci.draw_set_transform(body, 0.0, Vector2(1, 0.5))
			ci.draw_circle(Vector2.ZERO, 9.0, Color(0.55, 0.75, 0.9))
			ci.draw_set_transform(Vector2.ZERO)
			ci.draw_colored_polygon(PackedVector2Array([
				body + Vector2(-7, 0), body + Vector2(-14, -5), body + Vector2(-14, 5)]), Color(0.45, 0.62, 0.8))
			ci.draw_circle(body + Vector2(5, -1), 1.3, Color(0.1, 0.1, 0.15))
		_:
			var white := Color(0.97, 0.95, 0.88)
			var a := p + Vector2(-9, -6)
			var b := p + Vector2(9, -10)
			ci.draw_line(a, b, white, 4.5, true)
			for end in [a, b]:
				var n := (b - a).normalized().orthogonal() * 3.0
				ci.draw_circle(end + n, 3.2, white)
				ci.draw_circle(end - n, 3.2, white)


## One banana hanging from `stem`: a curved, tapered crescent that sags and turns its tip up.
static func _banana(ci: CanvasItem, stem: Vector2, rot: float, length: float) -> void:
	var center := Vector2(length * 0.5, -length * 0.35)
	var radius := center.length()
	var a0 := atan2(-center.y, -center.x)
	var a1 := deg_to_rad(25.0)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var mid := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var s := float(i) / steps
		var dir := Vector2.from_angle(lerp_angle(a0, a1, s))
		var t := 6.0 * pow(sin(PI * (0.06 + 0.88 * s)), 0.6)
		outer.append(stem + (center + dir * (radius + t * 0.5)).rotated(rot))
		inner.append(stem + (center + dir * (radius - t * 0.5)).rotated(rot))
		mid.append(stem + (center + dir * (radius + t * 0.15)).rotated(rot))
	var shape := outer.duplicate()
	for i in range(inner.size() - 1, -1, -1):
		shape.append(inner[i])
	ci.draw_colored_polygon(shape, Color(1.0, 0.84, 0.18))
	ci.draw_polyline(inner.slice(2, steps - 1), Color(0.88, 0.62, 0.08), 2.0, true)
	ci.draw_polyline(mid.slice(3, 10), Color(1.0, 0.96, 0.62), 1.4, true)
	shape.append(shape[0])
	ci.draw_polyline(shape, Color(0.4, 0.26, 0.03), 1.3, true)
	ci.draw_circle(outer[steps].lerp(inner[steps], 0.5), 1.1, Color(0.28, 0.2, 0.06))


## One carrot whose leafy top is at `top`, pointing down and turned by `rot`.
static func _carrot(ci: CanvasItem, top: Vector2, rot: float) -> void:
	var length := 21.0
	var width := 8.5
	var leaf := Color(0.3, 0.7, 0.22)
	var leaf_dark := Color(0.16, 0.45, 0.12)
	for angle in [-0.55, 0.0, 0.55]:
		var dir := Vector2(0, -1).rotated(rot + angle)
		var leaf_center := top + dir * 7.0
		ci.draw_set_transform(leaf_center, rot + angle, Vector2(0.4, 1))
		ci.draw_circle(Vector2.ZERO, 7.8, leaf_dark)
		ci.draw_circle(Vector2.ZERO, 7.0, leaf)
		ci.draw_set_transform(Vector2.ZERO)
		ci.draw_line(top, top + dir * 12.0, leaf_dark, 1.0, true)

	var body := PackedVector2Array()
	for i in 9:
		var a := -PI * i / 8.0
		body.append(Vector2(cos(a) * width * 0.5, sin(a) * width * 0.3))
	for i in range(1, 11):
		var s := i / 10.0
		body.append(Vector2(-width * 0.5 * (1.0 - pow(s, 1.4)), length * s))
	for i in range(9, 0, -1):
		var s := i / 10.0
		body.append(Vector2(width * 0.5 * (1.0 - pow(s, 1.4)), length * s))
	var shape := PackedVector2Array()
	for v in body:
		shape.append(top + v.rotated(rot))
	ci.draw_colored_polygon(shape, Color(1.0, 0.55, 0.12))
	for s in [0.28, 0.5, 0.7]:
		var hw := width * 0.5 * (1.0 - pow(s, 1.4))
		ci.draw_line(top + Vector2(hw * 0.1, length * s).rotated(rot), top + Vector2(hw * 0.95, length * s + 1.5).rotated(rot),
			Color(0.78, 0.36, 0.06), 1.2, true)
	ci.draw_line(top + Vector2(-width * 0.22, length * 0.1).rotated(rot), top + Vector2(-width * 0.14, length * 0.5).rotated(rot),
		Color(1.0, 0.78, 0.45), 1.5, true)
	shape.append(shape[0])
	ci.draw_polyline(shape, Color(0.55, 0.25, 0.04), 1.4, true)


## A whole 3x3 tile, with (0, 0) at `origin`. Used for the hover ghost and the HUD preview.
static func draw_tile(ci: CanvasItem, origin: Vector2, tile: int, alpha: float, tiles_script) -> void:
	for depth in 5:
		for x in 3:
			var y := depth - x
			if y < 0 or y > 2 or not tiles_script.is_land(tile, x, y):
				continue
			var shore := []
			for d in 4:
				var n: Vector2i = Vector2i(x, y) + DIRS[d]
				var inside := n.x >= 0 and n.x < 3 and n.y >= 0 and n.y < 3
				shore.append(not (inside and tiles_script.is_land(tile, n.x, n.y)))
			draw_land(ci, origin + cell_pos(Vector2(x, y)), shore, hash_cell(Vector2i(x, y), tile), alpha)


## Outline of a 3x3 slot whose top-left cell is `cell`.
static func slot_outline(origin: Vector2, cell: Vector2i) -> PackedVector2Array:
	var c := Vector2(cell)
	return PackedVector2Array([
		origin + cell_pos(c) + Vector2(0, -HH),
		origin + cell_pos(c + Vector2(2, 0)) + Vector2(HW, 0),
		origin + cell_pos(c + Vector2(2, 2)) + Vector2(0, HH),
		origin + cell_pos(c + Vector2(0, 2)) + Vector2(-HW, 0),
		origin + cell_pos(c) + Vector2(0, -HH),
	])


static func _shifted(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + offset)
	return out


static func _diamond(c: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(0, -HH * s), c + Vector2(HW * s, 0), c + Vector2(0, HH * s), c + Vector2(-HW * s, 0)])


static func _a(color: Color, alpha: float) -> Color:
	return Color(color, color.a * alpha)


## Simple gear outline for the settings button, centered at `c`: a ring with 8 short spokes
## poking out to `radius`, and a small hole in the middle.
static func draw_gear_icon(ci: CanvasItem, c: Vector2, radius: float, color: Color) -> void:
	var ring_r := radius * 0.58
	ci.draw_arc(c, ring_r, 0, TAU, 32, color, 2.2, true)
	ci.draw_arc(c, radius * 0.22, 0, TAU, 16, color, 2.2, true)
	for i in 8:
		var dir := Vector2.from_angle(TAU * i / 8.0)
		ci.draw_line(c + dir * ring_r, c + dir * radius, color, 2.6, true)


## Simple house outline for the "back to menu" button, centered at `c`.
static func draw_home_icon(ci: CanvasItem, c: Vector2, size: float, color: Color) -> void:
	var hw := size * 0.5
	var roof_top := c + Vector2(0, -size * 0.62)
	var wall_top := size * -0.06
	ci.draw_polyline(PackedVector2Array([
		c + Vector2(-hw, wall_top), roof_top, c + Vector2(hw, wall_top)]), color, 2.2, true)
	ci.draw_polyline(PackedVector2Array([
		c + Vector2(-hw * 0.78, wall_top), c + Vector2(-hw * 0.78, size * 0.5),
		c + Vector2(hw * 0.78, size * 0.5), c + Vector2(hw * 0.78, wall_top)]), color, 2.2, true)
	ci.draw_rect(Rect2(c + Vector2(-hw * 0.18, size * 0.06), Vector2(hw * 0.36, size * 0.44)), color, false, 2.0)
