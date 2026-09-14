extends RefCounted
## Loads data/map.json (built by tools/build_map.py): regions with their shapes, continents
## and which regions border each other.

const PATH := "res://data/map.json"

var size := Vector2.ZERO
var ids: Array[String] = []
var regions := {}  # id -> {name, continent, label: Vector2, polygons: Array[PackedVector2Array], rect: Rect2}
var continents := {}  # code -> {name, bonus, color: Color, regions: Array[String]}
var neighbours := {}  # id -> Array[String]
var links := []  # {a, b, sea}


static func load_map():
	var data = new()
	var text := FileAccess.get_file_as_string(PATH)
	var json = JSON.parse_string(text)
	if json == null:
		push_error("Could not read %s" % PATH)
		return data

	data.size = Vector2(json.size[0], json.size[1])
	for code in json.continents:
		var c: Dictionary = json.continents[code]
		data.continents[code] = {
			"name": c.name, "bonus": int(c.bonus), "color": Color.html(c.color), "regions": [],
		}

	for r in json.regions:
		var polygons: Array[PackedVector2Array] = []
		var rect := Rect2()
		for flat in r.polygons:
			var points := PackedVector2Array()
			points.resize(flat.size() / 2)
			for i in points.size():
				points[i] = Vector2(flat[i * 2], flat[i * 2 + 1])
			polygons.append(points)
			var bounds := _bounds(points)
			rect = bounds if rect.size == Vector2.ZERO else rect.merge(bounds)
		data.ids.append(r.id)
		data.regions[r.id] = {
			"name": r.name, "continent": r.continent,
			"label": Vector2(r.label[0], r.label[1]), "polygons": polygons, "rect": rect,
		}
		data.continents[r.continent].regions.append(r.id)
		data.neighbours[r.id] = []

	for l in json.links:
		data.links.append({"a": l.a, "b": l.b, "sea": l.sea})
		data.neighbours[l.a].append(l.b)
		data.neighbours[l.b].append(l.a)
	return data


func region_at(point: Vector2) -> String:
	for id in ids:
		var region: Dictionary = regions[id]
		if not region.rect.grow(2.0).has_point(point):
			continue
		for polygon in region.polygons:
			if Geometry2D.is_point_in_polygon(point, polygon):
				return id
	return ""


func are_neighbours(a: String, b: String) -> bool:
	return neighbours.has(a) and b in neighbours[a]


static func _bounds(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for p in points:
		rect = rect.expand(p)
	return rect
