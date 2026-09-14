extends Node2D
## Draws the world: sea, land shadows, region fills, borders, sea routes, highlights and labels.

const OCEAN := Color(0.1, 0.24, 0.38)
const OCEAN_LIGHT := Color(0.16, 0.34, 0.5)
const BORDER := Color(0.08, 0.08, 0.1, 0.85)
const SELECTED := Color(1.0, 0.86, 0.3)
const TARGET := Color(1, 1, 1, 0.9)

var data
var zoom := 1.0
var colors := {}  # id -> Color
var hovered := ""
var selected := ""
var targets: Array = []  # regions outlined as possible moves
var badges := {}  # id -> {text: String, color: Color}

var _fills := {}  # id -> Array[Polygon2D]
var _borders: Array[Line2D] = []
var _highlight: Node2D
var _routes: Node2D
var _labels: Node2D


func build(map_data) -> void:
	data = map_data

	var sea := _Sea.new()
	sea.map = self
	add_child(sea)

	var shadows := Node2D.new()
	add_child(shadows)
	var fills := Node2D.new()
	add_child(fills)
	var borders := Node2D.new()
	add_child(borders)

	for id in data.ids:
		_fills[id] = []
		for polygon in data.regions[id].polygons:
			var shadow := Polygon2D.new()
			shadow.polygon = polygon
			shadow.color = Color(0, 0, 0, 0.28)
			shadow.position = Vector2(1.5, 2.5)
			shadows.add_child(shadow)

			var fill := Polygon2D.new()
			fill.polygon = polygon
			fills.add_child(fill)
			_fills[id].append(fill)

			var line := Line2D.new()
			line.points = polygon
			line.closed = true
			line.default_color = BORDER
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			borders.add_child(line)
			_borders.append(line)
		colors[id] = data.continents[data.regions[id].continent].color

	_routes = _Routes.new()
	_routes.map = self
	add_child(_routes)
	_highlight = _Highlight.new()
	_highlight.map = self
	add_child(_highlight)
	_labels = _Labels.new()
	_labels.map = self
	add_child(_labels)
	refresh()


func set_zoom(value: float) -> void:
	zoom = value
	for line in _borders:
		line.width = clampf(1.1 / zoom, 0.6, 2.2)
	refresh()


## Re-applies colours and redraws overlays after state changes.
func refresh() -> void:
	for id in _fills:
		var color: Color = colors[id]
		if id == selected:
			color = color.lightened(0.25)
		elif id == hovered:
			color = color.lightened(0.15)
		for fill in _fills[id]:
			fill.color = color
	_routes.queue_redraw()
	_highlight.queue_redraw()
	_labels.queue_redraw()


class _Sea extends Node2D:
	var map

	func _draw() -> void:
		var size: Vector2 = map.data.size
		draw_rect(Rect2(-Vector2(4000, 3000), size + Vector2(8000, 6000)), map.OCEAN)
		draw_rect(Rect2(Vector2.ZERO, size), map.OCEAN_LIGHT)
		# Faint graticule every ~15 degrees.
		for i in range(1, 24):
			var x := size.x * i / 24.0
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.04), 1.0)
		for i in range(1, 10):
			var y := size.y * i / 10.0
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.04), 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.1), false, 2.0)


class _Routes extends Node2D:
	var map

	func _draw() -> void:
		var width: float = clampf(1.4 / map.zoom, 0.8, 3.0)
		var dash: float = clampf(6.0 / map.zoom, 4.0, 14.0)
		for link in map.data.links:
			if not link.sea:
				continue
			var a: Vector2 = map.data.regions[link.a].label
			var b: Vector2 = map.data.regions[link.b].label
			var color := Color(1, 1, 1, 0.55)
			if map.selected in [link.a, link.b]:
				color = Color(1, 0.9, 0.5, 0.95)
			var span: float = map.data.size.x
			if absf(a.x - b.x) > span * 0.5:
				# The route wraps around the edge of the map (Alaska - Russian Far East).
				var left := a if a.x < b.x else b
				var right := b if a.x < b.x else a
				var mid_y := (left.y + right.y) * 0.5
				draw_dashed_line(left, Vector2(-40, mid_y), color, width, dash)
				draw_dashed_line(right, Vector2(span + 40, mid_y), color, width, dash)
			else:
				draw_dashed_line(a, b, color, width, dash)


class _Highlight extends Node2D:
	var map

	func _draw() -> void:
		var width: float = 2.5 / map.zoom
		for id in map.targets:
			_outline(id, map.TARGET, 1.6 / map.zoom)
		if map.selected != "":
			_outline(map.selected, map.SELECTED, width)

	func _outline(id: String, color: Color, width: float) -> void:
		for polygon in map.data.regions[id].polygons:
			var closed: PackedVector2Array = polygon.duplicate()
			closed.append(polygon[0])
			draw_polyline(closed, color, width, true)


class _Labels extends Node2D:
	var map

	## Text is drawn with a transform that cancels the camera zoom, so it stays sharp and readable.
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var s: float = 1.0 / map.zoom
		var show_names: bool = map.zoom >= 1.1
		for id in map.data.ids:
			var region: Dictionary = map.data.regions[id]
			draw_set_transform(region.label, 0.0, Vector2(s, s))
			if map.badges.has(id):
				var badge: Dictionary = map.badges[id]
				draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.65))
				draw_circle(Vector2.ZERO, 11.5, badge.color)
				_centered(font, badge.text, Vector2(0, 5), 14, Color.WHITE, 0)
			if show_names or id == map.hovered or id == map.selected:
				_centered(font, region.name, Vector2(0, 30), 13, Color.WHITE, 5)
		draw_set_transform(Vector2.ZERO)

	func _centered(font: Font, text: String, at: Vector2, size: int, color: Color, outline: int) -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pos := at - Vector2(w * 0.5, 0)
		if outline > 0:
			draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, 0.8))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
