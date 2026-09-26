extends RefCounted
## Set dressing: the detail that makes the maps look lived in, placed from the map grid with a fixed
## random seed, so each map always looks the same. None of it changes where anyone can walk: trims
## and window frames sit flat on the walls, props only go into corners, out of the bots' paths.
##
##   Every map: skirting along the foot of the walls, a coping along their tops, windows, rubble,
##   barrels and boxes in corners, lamps under roofs.
##   Desert ("sand" floor): shutters, cloth awnings, sand drifted against the walls, palm trees.
##   Industrial: pipes along the walls, oil stains and puddles, hazard stripes on low walls.

const Tex := preload("res://scripts/textures.gd")
const Models := preload("res://scripts/models.gd")

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var world
var rng := RandomNumberGenerator.new()
var desert := true
var boxes := {}  # material key -> [[center, size], ...], merged into one mesh per material
var materials := {}


func build(world_ref, body: StaticBody3D) -> void:
	world = world_ref
	rng.seed = hash(world.data["name"])
	desert = world.data["floor"] == "sand"
	var wall_tex: String = world.data["wall"]
	materials = {
		"skirt": Tex.surface(world.data["low"], 2.0, Color(0.62, 0.58, 0.52)),
		"cap": Tex.surface(wall_tex, 4.0, Color(1.08, 1.05, 1.0)),
		"frame": Tex.surface(wall_tex, 2.0, Color(0.85, 0.82, 0.78)),
		"dark": Tex.flat(Color(0.05, 0.05, 0.055)),
		"wood": Tex.surface("wood", 1.0, Color(0.55, 0.42, 0.3)),
		"sand": Tex.surface("sand", 4.0, Color(1.02, 1.0, 0.97)),
		"metal": Tex.surface("metal", 1.0, Color(0.45, 0.47, 0.5)),
		"rubble": Tex.surface(wall_tex, 1.0, Color(0.8, 0.76, 0.7)),
		"hazard": Tex.flat(Color(0.85, 0.65, 0.1)),
		"glass": Tex.flat(Color(0.12, 0.16, 0.2), 0.0, 0.8),
	}
	for z in world.depth:
		for x in world.width:
			var c := Vector2i(x, z)
			if world.is_wall(c) or world.is_solid(c) and not world.char_at(c) in ["c", "C", "-", "o"]:
				continue
			var roofed := _roof_height(c) > 0.0
			for d: Vector2i in DIRS:
				if world.char_at(c + d) == "#" or world.walls.has(world.char_at(c + d)):
					_wall_face(c, d, roofed)
			_floor_bits(c)
			_corner_props(c, body)
			if world.char_at(c) == "-" and not desert:
				_hazard(c)
	if world.data.get("auto_lamps", true):
		_roof_lamps()
	_commit()


func _roof_height(c: Vector2i) -> float:
	for roof: Array in world.roofs:
		if (roof[0] as Rect2i).has_point(c):
			return roof[1]
	return 0.0


func _add(key: String, center: Vector3, size: Vector3) -> void:
	if not boxes.has(key):
		boxes[key] = []
	boxes[key].append([center, size])


## A point on the face of the wall between open cell c and the wall in direction d, `out` meters in
## front of it; `along` moves sideways along the face.
func _face(c: Vector2i, d: Vector2i, y: float, out: float, along := 0.0) -> Vector3:
	var edge: Vector3 = world.center(c) + Vector3(d.x, 0, d.y) * (world.CELL / 2.0 - out)
	var side := Vector3(-d.y, 0, d.x)
	return edge + side * along + Vector3(0, y, 0)


## A box lying flat against the wall: `width` along it, `height` up, `depth` out from it.
func _flat(key: String, c: Vector2i, d: Vector2i, y: float, width: float, height: float, depth: float, along := 0.0) -> void:
	var size := Vector3(width, height, depth) if d.y != 0 else Vector3(depth, height, width)
	_add(key, _face(c, d, y, depth / 2.0, along), size)


func _wall_face(c: Vector2i, d: Vector2i, roofed: bool) -> void:
	var cell: float = world.CELL
	var h: float = world.wall_height
	_flat("skirt", c, d, 0.16, cell, 0.32, 0.08)
	if not roofed:
		_flat("cap", c, d, h - 0.12, cell, 0.24, 0.14)
		_flat("cap", c, d, h - 0.34, cell, 0.06, 0.05)
	if desert and rng.randf() < 0.18:
		# Sand blown against the foot of the wall.
		var drift := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.left_to_right = 0.0
		prism.size = Vector3(0.7, 0.35, cell * rng.randf_range(0.6, 1.0))
		drift.mesh = prism
		drift.material_override = materials["sand"]
		drift.position = _face(c, d, 0.17, 0.35, rng.randf_range(-0.3, 0.3))
		drift.rotation.y = atan2(float(d.x), float(d.y)) + PI / 2.0
		world.add_child(drift)
	var top := _roof_height(c) if roofed else h
	if top - 0.4 < 3.4 or rng.randf() > 0.16:
		return
	# A window: a dark recess in a frame, with shutters or bars.
	var y := minf(3.6, top - 1.2)
	_flat("frame", c, d, y, 1.2, 1.5, 0.08)
	_flat("dark", c, d, y, 0.9, 1.2, 0.1)
	_flat("frame", c, d, y - 0.72, 1.4, 0.1, 0.18)  # sill
	if desert:
		for side in [-1, 1]:
			if rng.randf() < 0.7:
				_flat("wood", c, d, y, 0.45, 1.2, 0.05, side * 0.72)  # open shutter
		if rng.randf() < 0.45:
			_awning(c, d, y + 0.85)
	else:
		_flat("glass", c, d, y, 0.9, 1.2, 0.11)
		for i in 3:
			_flat("metal", c, d, y, 0.04, 1.2, 0.13, -0.3 + i * 0.3)  # bars
		_flat("metal", c, d, y, 0.9, 0.04, 0.13)
		if rng.randf() < 0.5:
			_pipe(c, d)


## A slanted cloth awning over a window.
func _awning(c: Vector2i, d: Vector2i, y: float) -> void:
	var cloth := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 0.03, 0.8)
	cloth.mesh = box
	var colors := [Color(0.7, 0.2, 0.15), Color(0.2, 0.45, 0.55), Color(0.8, 0.65, 0.3), Color(0.35, 0.5, 0.25)]
	cloth.material_override = Tex.surface("plain", 1.0, colors[rng.randi() % colors.size()])
	cloth.position = _face(c, d, y, 0.4)
	cloth.rotation = Vector3(0.45, atan2(float(-d.x), float(-d.y)), 0)
	world.add_child(cloth)
	for side in [-1, 1]:
		var rod := MeshInstance3D.new()
		rod.mesh = _cylinder(0.012, 0.75)
		rod.material_override = materials["metal"]
		rod.position = _face(c, d, y - 0.2, 0.4, side * 0.72)
		rod.rotation = Vector3(0, atan2(float(-d.x), float(-d.y)), 0)
		rod.rotate_object_local(Vector3.RIGHT, PI / 2.0 - 0.9)
		world.add_child(rod)


## A pipe running along the wall with brackets.
func _pipe(c: Vector2i, d: Vector2i) -> void:
	var y := 4.6
	var pipe := MeshInstance3D.new()
	pipe.mesh = _cylinder(0.09, world.CELL)
	pipe.material_override = Tex.flat(Color(0.3, 0.33, 0.3), 0.0, 0.6)
	pipe.position = _face(c, d, y, 0.2)
	pipe.rotation = Vector3(0, 0, PI / 2.0) if d.y != 0 else Vector3(PI / 2.0, 0, 0)
	world.add_child(pipe)
	_flat("metal", c, d, y, 0.06, 0.3, 0.3, 0.6)
	_flat("metal", c, d, y, 0.06, 0.3, 0.3, -0.6)


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return mesh


## Small things lying on the ground: stones and bricks, stains and puddles.
func _floor_bits(c: Vector2i) -> void:
	if world.is_solid(c):
		return
	var p: Vector3 = world.center(c)
	if rng.randf() < 0.22:
		for i in rng.randi_range(1, 4):
			var s := rng.randf_range(0.05, 0.16)
			_add("rubble", p + Vector3(rng.randf_range(-0.9, 0.9), s * 0.3, rng.randf_range(-0.9, 0.9)), Vector3(s * 1.4, s * 0.6, s))
	if not desert and rng.randf() < 0.06:
		var stain := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		var r := rng.randf_range(0.4, 0.9)
		disc.top_radius = r
		disc.bottom_radius = r
		disc.height = 0.01
		disc.radial_segments = 16
		stain.mesh = disc
		var puddle := rng.randf() < 0.4
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.09, 0.1, 0.85) if puddle else Color(0.05, 0.05, 0.04, 0.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.05 if puddle else 0.9
		mat.metallic = 0.3 if puddle else 0.0
		stain.material_override = mat
		stain.position = p + Vector3(rng.randf_range(-0.5, 0.5), 0.006, rng.randf_range(-0.5, 0.5))
		stain.scale = Vector3(1.0, 1.0, rng.randf_range(0.5, 1.0))
		stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(stain)


## Barrels, boxes and (in the desert) palm trees tucked into corners, where nobody walks.
func _corner_props(c: Vector2i, body: StaticBody3D) -> void:
	if world.is_solid(c) or rng.randf() > 0.3:
		return
	var walls: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		if world.is_wall(c + d):
			walls.append(d)
	if walls.size() != 2 or walls[0] + walls[1] == Vector2i.ZERO:
		return
	var corner: Vector2i = walls[0] + walls[1]
	var spot: Vector3 = world.center(c) + Vector3(corner.x, 0, corner.y) * 0.58
	var roll := rng.randf()
	if desert and roll < 0.2 and _roof_height(c) == 0.0:
		_palm(spot, body)
	elif roll < 0.65:
		_barrel(spot, body)
	else:
		var s := rng.randf_range(0.45, 0.6)
		spot = world.center(c) + Vector3(corner.x, 0, corner.y) * (world.CELL / 2.0 - s / 2.0 - 0.03)
		var crate := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(s, s, s)
		crate.mesh = mesh
		crate.material_override = Tex.surface("wood", s, Color.WHITE, true)
		crate.position = spot + Vector3(0, s / 2.0, 0)
		crate.rotation.y = rng.randf_range(-0.15, 0.15)
		world.add_child(crate)
		world._collider(body, crate.position, mesh.size, crate.rotation.y)


func _barrel(at: Vector3, body: StaticBody3D) -> void:
	var colors := [Color(0.25, 0.35, 0.55), Color(0.6, 0.2, 0.15), Color(0.3, 0.4, 0.25), Color(0.55, 0.5, 0.2)]
	var color: Color = colors[rng.randi() % colors.size()]
	var barrel := MeshInstance3D.new()
	barrel.mesh = _cylinder(0.3, 0.9)
	barrel.material_override = Tex.surface("metal", 0.5, color)
	barrel.position = at + Vector3(0, 0.45, 0)
	world.add_child(barrel)
	for y in [0.2, 0.7]:
		var hoop := MeshInstance3D.new()
		hoop.mesh = _cylinder(0.31, 0.04)
		hoop.material_override = Tex.flat(color.darkened(0.35), 0.0, 0.5)
		hoop.position = at + Vector3(0, y, 0)
		world.add_child(hoop)
	var lid := MeshInstance3D.new()
	lid.mesh = _cylinder(0.27, 0.01)
	lid.material_override = Tex.flat(color.darkened(0.2), 0.0, 0.5)
	lid.position = at + Vector3(0, 0.905, 0)
	world.add_child(lid)
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 0.9
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = at + Vector3(0, 0.45, 0)
	body.add_child(col)


func _palm(at: Vector3, body: StaticBody3D) -> void:
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25)).normalized()
	var height := rng.randf_range(6.5, 9.0)
	var bark := Tex.surface("wood", 0.6, Color(0.55, 0.45, 0.35))
	var segments := 8
	var top := at
	for i in segments:
		var seg := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = lerpf(0.17, 0.11, float(i + 1) / segments)
		cone.bottom_radius = lerpf(0.2, 0.13, float(i) / segments)
		cone.height = height / segments
		cone.radial_segments = 8
		seg.mesh = cone
		seg.material_override = bark
		var bend := lean.lerp(Vector3.UP, 0.4 - float(i) / segments * 0.4).normalized() if i > 0 else Vector3.UP
		seg.transform = Transform3D(Basis(Vector3.UP.cross(bend).normalized() if bend != Vector3.UP else Vector3.RIGHT, Vector3.UP.angle_to(bend)), top + bend * cone.height / 2.0)
		world.add_child(seg)
		top += bend * cone.height
	var leaf := Tex.surface("plain", 1.0, Color(0.28, 0.45, 0.18))
	for i in 9:
		var frond := MeshInstance3D.new()
		var blade := BoxMesh.new()
		blade.size = Vector3(0.5, 0.03, 2.6)
		frond.mesh = blade
		frond.material_override = leaf
		var a := i * TAU / 9.0 + rng.randf_range(-0.2, 0.2)
		frond.position = top + Vector3(sin(a), -0.35, cos(a)) * 1.2
		frond.rotation = Vector3(0.45 + rng.randf_range(0, 0.3), a, 0)
		world.add_child(frond)
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.2
	trunk.height = 3.0
	var col := CollisionShape3D.new()
	col.shape = trunk
	col.position = at + Vector3(0, 1.5, 0)
	body.add_child(col)


func _hazard(c: Vector2i) -> void:
	var p: Vector3 = world.center(c)
	for i in 4:
		_add("hazard", p + Vector3(-0.75 + i * 0.5, 1.12, 0), Vector3(0.22, 0.04, 0.02))


## Lamps hanging under roofs, with a warm light every few cells.
func _roof_lamps() -> void:
	for roof: Array in world.roofs:
		var r: Rect2i = roof[0]
		var h: float = roof[1]
		var n := 0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if world.is_solid(c) or (x + y) % 3 != 0 or (x * 7 + y * 3) % 2 != 0:
					continue
				var at: Vector3 = world.center(c, h)
				var cord := MeshInstance3D.new()
				cord.mesh = _cylinder(0.01, 0.5)
				cord.material_override = materials["dark"]
				cord.position = at - Vector3(0, 0.25, 0)
				world.add_child(cord)
				var shade := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.06
				cone.bottom_radius = 0.22
				cone.height = 0.15
				shade.mesh = cone
				shade.material_override = Tex.flat(Color(0.25, 0.3, 0.25), 0.0, 0.5)
				shade.position = at - Vector3(0, 0.55, 0)
				world.add_child(shade)
				var bulb := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = 0.05
				sphere.height = 0.1
				bulb.mesh = sphere
				bulb.material_override = Tex.flat(Color(1.0, 0.85, 0.6), 4.0)
				bulb.position = at - Vector3(0, 0.63, 0)
				world.add_child(bulb)
				n += 1
				if n % 2 == 1:
					var light := OmniLight3D.new()
					light.light_color = Color(1.0, 0.82, 0.6)
					light.light_energy = 1.4
					light.omni_range = 7.0
					light.omni_attenuation = 1.5
					light.position = at - Vector3(0, 0.75, 0)
					world.add_child(light)


func _commit() -> void:
	var mesh := ArrayMesh.new()
	for key: String in boxes:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for b: Array in boxes[key]:
			world._box_faces(st, b[0], b[1])
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials[key])
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	world.add_child(instance)
