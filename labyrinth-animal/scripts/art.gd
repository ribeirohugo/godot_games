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
const WOOD := Color(0.66, 0.46, 0.26)
const WOOD_DARK := Color(0.44, 0.29, 0.15)

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


## Wooden dock block, used for the start.
static func draw_dock(ci: CanvasItem, c: Vector2) -> void:
	var t := THICK
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-HW, 0), c + Vector2(0, HH), c + Vector2(0, HH + t), c + Vector2(-HW, t)]), WOOD_DARK)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, HH), c + Vector2(HW, 0), c + Vector2(HW, t), c + Vector2(0, HH + t)]), WOOD_DARK.darkened(0.2))
	ci.draw_colored_polygon(_diamond(c, 1.0), WOOD)
	for i in range(1, 4):
		var f := i / 4.0
		var a := c + Vector2(-HW, 0).lerp(Vector2(0, -HH), f)
		var b := c + Vector2(0, HH).lerp(Vector2(HW, 0), f)
		ci.draw_line(a, b, WOOD_DARK, 1.2)
	# Posts sticking out of the water.
	for p in [Vector2(-HW, t), Vector2(0, HH + t), Vector2(HW, t)]:
		ci.draw_line(c + p, c + p + Vector2(0, 8), WOOD_DARK.darkened(0.3), 3.0)


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
			var yellow := Color(1.0, 0.86, 0.2)
			var outline := Color(0.55, 0.4, 0.05)
			for i in 3:
				var center := p + Vector2(-6 + i * 6, -10)
				var start := deg_to_rad(20 + i * 25)
				ci.draw_arc(center, 9.0, start, start + 2.2, 12, outline, 5.0)
				ci.draw_arc(center, 9.0, start, start + 2.2, 12, yellow, 3.0)
			ci.draw_circle(p + Vector2(0, -20), 2.5, Color(0.35, 0.25, 0.1))
		1:
			for i in 2:
				var base := p + Vector2(-5 + i * 9, -4 + i * 2)
				var tip := base + Vector2(4 - i * 6, -18)
				ci.draw_colored_polygon(PackedVector2Array([
					tip + Vector2(-3.5, 0), tip + Vector2(3.5, 0), base]), Color(1.0, 0.5, 0.1))
				for leaf in [-4.0, 0.0, 4.0]:
					ci.draw_line(tip, tip + Vector2(leaf, -7), Color(0.25, 0.65, 0.2), 2.0, true)
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


static func _diamond(c: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(0, -HH * s), c + Vector2(HW * s, 0), c + Vector2(0, HH * s), c + Vector2(-HW * s, 0)])


static func _a(color: Color, alpha: float) -> Color:
	return Color(color, color.a * alpha)
