extends RefCounted
## The campaign's props, built from boxes and cylinders like everything else: vehicles, tents and
## towers, machines and furniture, lamps, HELIX pods, bodies, and the things the player picks up.
## make() returns a prop standing on the floor at the origin, its long side along X, sized to fit
## `size` (meters, the cells the map gives it). Plain parts are merged into one mesh.

const Tex := preload("res://scripts/textures.gd")
const Models := preload("res://scripts/models.gd")

const CAR_COLORS := [Color(0.62, 0.1, 0.08), Color(0.15, 0.25, 0.45), Color(0.75, 0.75, 0.72), Color(0.2, 0.2, 0.22),
		Color(0.55, 0.5, 0.35), Color(0.3, 0.4, 0.3), Color(0.85, 0.65, 0.1)]
const BURNT := Color(0.09, 0.08, 0.075)
const DARK_GLASS := Color(0.05, 0.07, 0.08)


static func _box(p: Node3D, size: Vector3, pos: Vector3, color: Color, metal := 0.0, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.box(p, size, pos, color, metal, rot)


static func _cyl(p: Node3D, r: float, h: float, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.cylinder(p, r, h, pos, color, rot)


static func _glow(p: Node3D, size: Vector3, pos: Vector3, color: Color, energy := 3.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = Tex.flat(color, energy)
	part.position = pos
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(part)
	return part


static func _light(p: Node3D, pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.4
	p.add_child(light)
	return light


static func make(kind: String, size: Vector2, rng: RandomNumberGenerator) -> Node3D:
	Models.vm = false
	var p := Node3D.new()
	match kind:
		"car", "wreck":
			_car(p, rng, kind == "wreck")
		"truck":
			_truck(p, rng)
		"heli", "heli_wreck":
			_heli(p, kind == "heli_wreck")
		"tent", "med_tent":
			_tent(p, size, kind == "med_tent")
		"tower":
			_tower(p)
		"generator":
			_generator(p)
		"terminal":
			_terminal(p, rng)
		"server":
			_server(p, size, rng)
		"pod", "pod_empty", "pod_broken":
			_pod(p, kind, rng)
		"tv":
			_tv(p)
		"table":
			_box(p, Vector3(size.x - 0.3, 0.06, size.y - 0.5), Vector3(0, 0.76, 0), Color(0.45, 0.32, 0.2))
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(p, Vector3(0.06, 0.74, 0.06), Vector3(sx * (size.x / 2.0 - 0.3), 0.37, sz * (size.y / 2.0 - 0.4)), Color(0.35, 0.25, 0.16))
			if rng.randf() < 0.7:
				_box(p, Vector3(0.25, 0.02, 0.2), Vector3(rng.randf_range(-0.4, 0.4), 0.8, 0.1), Color(0.9, 0.9, 0.85))  # papers
			if rng.randf() < 0.6:
				_cyl(p, 0.1, 0.03, Vector3(-0.3, 0.8, -0.2), Color(0.85, 0.85, 0.8))  # a plate: they left mid-meal
		"desk":
			_box(p, Vector3(size.x - 0.2, 0.05, 0.8), Vector3(0, 0.75, 0), Color(0.6, 0.6, 0.58), 0.3)
			_box(p, Vector3(0.4, 0.72, 0.75), Vector3(size.x / 2.0 - 0.35, 0.36, 0), Color(0.5, 0.5, 0.48), 0.3)
			_monitor(p, Vector3(0, 0.78, 0.1), rng)
		"counter":
			_box(p, Vector3(size.x - 0.1, 1.0, 0.8), Vector3(0, 0.5, 0), Color(0.55, 0.5, 0.45))
			_box(p, Vector3(size.x - 0.05, 0.05, 0.9), Vector3(0, 1.02, 0), Color(0.3, 0.3, 0.32), 0.4)
			_box(p, Vector3(0.35, 0.2, 0.3), Vector3(size.x * 0.25, 1.15, 0), Color(0.15, 0.15, 0.16))  # register
		"shelf":
			_box(p, Vector3(size.x - 0.2, 2.0, 0.5), Vector3(0, 1.0, 0), Color(0.5, 0.52, 0.55), 0.3)
			for level in 4:
				for i in int(size.x * 2.5):
					if rng.randf() < 0.75:
						var h := rng.randf_range(0.15, 0.3)
						_box(p, Vector3(0.18, h, 0.3), Vector3(-size.x / 2.0 + 0.3 + i * 0.4, 0.2 + level * 0.48 + h / 2.0, 0), CAR_COLORS[rng.randi() % CAR_COLORS.size()])
		"sofa":
			var c: Color = [Color(0.35, 0.3, 0.45), Color(0.5, 0.3, 0.2), Color(0.3, 0.38, 0.3)][rng.randi() % 3]
			_box(p, Vector3(size.x - 0.3, 0.45, 0.9), Vector3(0, 0.25, 0), c)
			_box(p, Vector3(size.x - 0.3, 0.5, 0.2), Vector3(0, 0.65, 0.35), c.darkened(0.1))
			for s in [-1, 1]:
				_box(p, Vector3(0.2, 0.6, 0.9), Vector3(s * (size.x / 2.0 - 0.25), 0.4, 0), c.darkened(0.15))
		"bed":
			_box(p, Vector3(size.x - 0.2, 0.4, 1.3), Vector3(0, 0.2, 0), Color(0.4, 0.3, 0.2))
			_box(p, Vector3(size.x - 0.3, 0.15, 1.25), Vector3(0, 0.47, 0), Color(0.8, 0.8, 0.82))
			_box(p, Vector3(0.4, 0.12, 0.8), Vector3(-size.x / 2.0 + 0.4, 0.6, 0), Color(0.9, 0.9, 0.9))
		"med_bed":
			_box(p, Vector3(1.9, 0.08, 0.8), Vector3(0, 0.8, 0), Color(0.75, 0.78, 0.8), 0.3)
			_box(p, Vector3(1.8, 0.1, 0.75), Vector3(0, 0.88, 0), Color(0.85, 0.88, 0.9))
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(p, Vector3(0.04, 0.8, 0.04), Vector3(sx * 0.9, 0.4, sz * 0.35), STEEL())
			_box(p, Vector3(1.6, 0.08, 0.6), Vector3(0.1, 0.97, 0), Color(0.6, 0.62, 0.6))  # sheet over someone
			_box(p, Vector3(0.3, 0.12, 0.35), Vector3(-0.75, 0.98, 0), Color(0.6, 0.62, 0.6))
		"fridge":
			_box(p, Vector3(0.75, 1.8, 0.7), Vector3(0, 0.9, 0), Color(0.88, 0.88, 0.86), 0.2)
			_box(p, Vector3(0.03, 0.4, 0.03), Vector3(0.3, 1.2, -0.37), STEEL(), 0.8)
		"lockers":
			for i in int(size.x / 0.5):
				_box(p, Vector3(0.46, 1.9, 0.5), Vector3(-size.x / 2.0 + 0.25 + i * 0.5, 0.95, 0), Color(0.35, 0.42, 0.45), 0.4)
				_box(p, Vector3(0.3, 0.02, 0.01), Vector3(-size.x / 2.0 + 0.25 + i * 0.5, 1.6, -0.26), Color(0.1, 0.1, 0.1))
		"dumpster":
			_box(p, Vector3(1.8, 1.2, 1.1), Vector3(0, 0.65, 0), Color(0.2, 0.35, 0.25), 0.4)
			_box(p, Vector3(1.85, 0.08, 1.15), Vector3(0, 1.28, 0), Color(0.15, 0.25, 0.18), 0.4, Vector3(0.1, 0, 0))
		"pallets":
			for i in 3:
				_box(p, Vector3(1.2, 0.12, 1.0), Vector3(0, 0.08 + i * 0.14, 0), Color(0.55, 0.42, 0.28))
			_box(p, Vector3(1.1, 0.7, 0.9), Vector3(0, 0.8, 0), Color(0.3, 0.4, 0.3))
		"bench":
			_box(p, Vector3(size.x - 0.3, 0.06, 0.45), Vector3(0, 0.45, 0), Color(0.3, 0.32, 0.34), 0.5)
			_box(p, Vector3(size.x - 0.3, 0.45, 0.05), Vector3(0, 0.7, 0.22), Color(0.3, 0.32, 0.34), 0.5)
		"seats":  # a row of train seats
			for i in int(size.x / 0.55):
				_box(p, Vector3(0.5, 0.1, 0.5), Vector3(-size.x / 2.0 + 0.3 + i * 0.55, 0.45, 0), Color(0.2, 0.3, 0.5))
				_box(p, Vector3(0.5, 0.55, 0.08), Vector3(-size.x / 2.0 + 0.3 + i * 0.55, 0.75, 0.22), Color(0.2, 0.3, 0.5))
		"sandbags":
			for row in 3:
				for i in int(size.x / 0.55) + 1:
					_box(p, Vector3(0.55, 0.22, 0.4), Vector3(-size.x / 2.0 + 0.28 + i * 0.52 + (0.26 if row % 2 else 0.0), 0.12 + row * 0.22, 0), Color(0.55, 0.5, 0.36).darkened(rng.randf_range(0.0, 0.1)))
		"cones":
			for i in 3:
				_cyl(p, 0.12, 0.5, Vector3(rng.randf_range(-0.7, 0.7), 0.25, rng.randf_range(-0.6, 0.6)), Color(0.9, 0.4, 0.1))
		"reactor":
			_reactor(p)
		"elevator":
			_elevator(p)
		"console":
			_box(p, Vector3(size.x - 0.2, 1.0, 0.8), Vector3(0, 0.5, 0), Color(0.25, 0.27, 0.3), 0.4)
			_box(p, Vector3(size.x - 0.3, 0.05, 0.6), Vector3(0, 1.05, -0.05), Color(0.1, 0.1, 0.12), 0.4, Vector3(-0.4, 0, 0))
			for i in int(size.x * 3):
				_glow(p, Vector3(0.05, 0.02, 0.05), Vector3(-size.x / 2.0 + 0.3 + i * 0.3, 1.1, -0.1), [Color(0.2, 1, 0.3), Color(1, 0.3, 0.2), Color(1, 0.8, 0.2)][rng.randi() % 3], 2.0)
			_monitor(p, Vector3(0, 1.05, 0.25), rng)
		"crates_mil":
			for i in 2:
				_box(p, Vector3(1.0, 0.5, 0.6), Vector3(0, 0.25 + i * 0.5, 0), Color(0.3, 0.34, 0.22), 0.2)
				_box(p, Vector3(0.2, 0.08, 0.01), Vector3(0, 0.3 + i * 0.5, -0.31), Color(0.85, 0.8, 0.5))
		"body_bag":
			_box(p, Vector3(1.8, 0.25, 0.6), Vector3(0, 0.13, 0), Color(0.1, 0.11, 0.1))
			_box(p, Vector3(1.6, 0.02, 0.02), Vector3(0, 0.26, 0), Color(0.5, 0.5, 0.5), 0.8)
		"pipes":
			for i in 3:
				_cyl(p, 0.12, size.x, Vector3(0, 0.3 + i * 0.35, 0), Color(0.35, 0.36, 0.33), Vector3(0, 0, PI / 2.0))
		"tank":  # a chemical tank
			_cyl(p, 0.8, 2.6, Vector3(0, 1.3, 0), Color(0.6, 0.62, 0.6))
			_cyl(p, 0.82, 0.08, Vector3(0, 0.6, 0), Color(0.8, 0.65, 0.1))
			_box(p, Vector3(0.5, 0.3, 0.02), Vector3(0, 1.6, -0.81), Color(0.85, 0.75, 0.1))
		_:
			_box(p, Vector3(size.x - 0.2, 1.0, size.y - 0.2), Vector3(0, 0.5, 0), Color(0.4, 0.4, 0.4))
	Models.merge(p)
	return p


static func STEEL() -> Color:
	return Models.STEEL


static func _monitor(p: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	_box(p, Vector3(0.55, 0.36, 0.05), at + Vector3(0, 0.25, 0), Color(0.1, 0.1, 0.11))
	_box(p, Vector3(0.06, 0.1, 0.06), at + Vector3(0, 0.05, 0.02), Color(0.1, 0.1, 0.11))
	var screen := [Color(0.2, 0.6, 1.0), Color(0.3, 1.0, 0.5), Color(1.0, 0.35, 0.25)][rng.randi() % 3] as Color
	_glow(p, Vector3(0.5, 0.3, 0.01), at + Vector3(0, 0.25, -0.03), screen.darkened(0.3), 1.2)


static func _car(p: Node3D, rng: RandomNumberGenerator, burnt: bool) -> void:
	var paint: Color = BURNT if burnt else CAR_COLORS[rng.randi() % CAR_COLORS.size()]
	var trim := Color(0.08, 0.08, 0.08) if not burnt else Color(0.3, 0.16, 0.08)
	_box(p, Vector3(4.2, 0.7, 1.8), Vector3(0, 0.62, 0), paint, 0.5 if not burnt else 0.0)
	_box(p, Vector3(2.2, 0.62, 1.64), Vector3(-0.2, 1.28, 0), paint, 0.5 if not burnt else 0.0)
	_box(p, Vector3(2.0, 0.5, 1.66), Vector3(-0.2, 1.3, 0), DARK_GLASS if not burnt else Color(0.02, 0.02, 0.02), 0.8)
	_box(p, Vector3(0.25, 0.5, 1.5), Vector3(0.95, 1.28, 0), DARK_GLASS if not burnt else Color(0.02, 0.02, 0.02), 0.8, Vector3(0, 0, 0.5))
	_box(p, Vector3(4.25, 0.18, 1.85), Vector3(0, 0.36, 0), trim)  # bumpers and sills
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var wheel := _cyl(p, 0.34, 0.26, Vector3(sx * 1.35, 0.34, sz * 0.82), Color(0.06, 0.06, 0.06), Vector3(PI / 2.0, 0, 0))
			if burnt and rng.randf() < 0.5:
				wheel.position.y = 0.22  # burnt flat
	if not burnt:
		for sz in [-0.6, 0.6]:
			_box(p, Vector3(0.05, 0.14, 0.3), Vector3(2.1, 0.72, sz), Color(0.95, 0.95, 0.85), 0.3)
			_box(p, Vector3(0.05, 0.12, 0.3), Vector3(-2.1, 0.72, sz), Color(0.7, 0.05, 0.05), 0.3)
	else:
		for i in 4:
			_box(p, Vector3(0.4, 0.05, 0.3), Vector3(rng.randf_range(-1.5, 1.5), 0.99, rng.randf_range(-0.6, 0.6)), Color(0.35, 0.18, 0.08))  # rust


static func _truck(p: Node3D, rng: RandomNumberGenerator) -> void:
	var olive := Color(0.3, 0.33, 0.22).darkened(rng.randf_range(0.0, 0.15))
	_box(p, Vector3(5.8, 0.4, 2.2), Vector3(0, 0.8, 0), Color(0.12, 0.12, 0.12))  # chassis
	_box(p, Vector3(1.8, 1.6, 2.2), Vector3(2.0, 1.7, 0), olive)  # cab
	_box(p, Vector3(0.05, 0.7, 1.9), Vector3(2.92, 2.0, 0), DARK_GLASS, 0.8)
	_box(p, Vector3(3.8, 2.2, 2.3), Vector3(-0.9, 2.1, 0), olive.darkened(0.12))  # canvas back
	for i in 4:
		_box(p, Vector3(0.06, 2.25, 2.32), Vector3(-2.6 + i * 1.1, 2.1, 0), olive.darkened(0.3))
	for x in [2.0, -0.6, -2.0]:
		for sz in [-1, 1]:
			_cyl(p, 0.5, 0.36, Vector3(x, 0.5, sz * 1.0), Color(0.06, 0.06, 0.06), Vector3(PI / 2.0, 0, 0))
	_box(p, Vector3(0.3, 0.3, 0.02), Vector3(-1.5, 2.6, -1.17), Color(0.9, 0.9, 0.85))  # a white star


static func _heli(p: Node3D, wreck: bool) -> void:
	var body := Color(0.18, 0.2, 0.17) if not wreck else Color(0.12, 0.11, 0.1)
	var tilt := Vector3(0, 0, 0.25) if wreck else Vector3.ZERO
	var hull := Node3D.new()
	hull.rotation = tilt
	p.add_child(hull)
	_box(hull, Vector3(5.0, 2.0, 2.4), Vector3(0, 1.4, 0), body, 0.3)
	_box(hull, Vector3(1.4, 1.4, 2.2), Vector3(2.9, 1.2, 0), body, 0.3)
	_box(hull, Vector3(1.0, 0.9, 2.0), Vector3(3.2, 1.6, 0), DARK_GLASS, 0.8)
	_box(hull, Vector3(1.6, 1.4, 0.05), Vector3(0.2, 1.4, 1.22), Color(0.02, 0.02, 0.02))  # open door
	if wreck:
		_box(hull, Vector3(3.0, 0.5, 0.5), Vector3(-3.6, 1.8, 0.4), body, 0.3, Vector3(0, 0.5, -0.2))  # tail snapped
		_box(hull, Vector3(4.5, 0.08, 0.3), Vector3(0.6, 2.6, 1.8), Color(0.1, 0.1, 0.1), 0.5, Vector3(0.3, 0.8, 0.1))  # bent blade
		_box(hull, Vector3(3.8, 0.08, 0.3), Vector3(-1.0, 1.0, -2.2), Color(0.1, 0.1, 0.1), 0.5, Vector3(0.1, -0.6, 0.4))
	else:
		_box(hull, Vector3(5.5, 0.6, 0.6), Vector3(-5.0, 1.9, 0), body, 0.3)
		_box(hull, Vector3(0.6, 1.5, 0.1), Vector3(-7.6, 2.4, 0), body, 0.3)
		_box(hull, Vector3(11.0, 0.06, 0.4), Vector3(0, 2.7, 0), Color(0.1, 0.1, 0.1), 0.5)
		_box(hull, Vector3(0.4, 0.06, 11.0), Vector3(0, 2.7, 0), Color(0.1, 0.1, 0.1), 0.5)
	for sz in [-1, 1]:
		_box(hull, Vector3(3.6, 0.08, 0.08), Vector3(0.3, 0.12, sz * 1.1), Color(0.1, 0.1, 0.1), 0.5)  # skids


static func _tent(p: Node3D, size: Vector2, medical: bool) -> void:
	var cloth := Color(0.35, 0.38, 0.26) if not medical else Color(0.75, 0.75, 0.7)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(size.y - 0.2, 2.4, size.x - 0.2)
	roof.mesh = prism
	roof.material_override = Tex.surface("plain", 2.0, cloth, true)
	roof.position = Vector3(0, 1.2, 0)
	roof.rotation.y = PI / 2.0
	p.add_child(roof)
	if medical:
		for s in [-1, 1]:
			_box(p, Vector3(0.6, 0.18, 0.02), Vector3(0, 1.2, s * (size.y / 2.0 - 0.25) * 0.5 - s * 0.02), Color(0.8, 0.1, 0.1), 0.0, Vector3(0, 0, 0))
			_box(p, Vector3(0.18, 0.6, 0.02), Vector3(0, 1.2, s * (size.y / 2.0 - 0.25) * 0.5 - s * 0.02), Color(0.8, 0.1, 0.1))


static func _tower(p: Node3D) -> void:
	var wood := Color(0.42, 0.33, 0.22)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(p, Vector3(0.18, 4.2, 0.18), Vector3(sx * 0.8, 2.1, sz * 0.8), wood)
	_box(p, Vector3(2.2, 0.15, 2.2), Vector3(0, 4.2, 0), wood.darkened(0.1))
	for side in 4:
		var a := side * PI / 2.0
		_box(p, Vector3(2.2, 1.0, 0.08), Vector3(sin(a) * 1.08, 4.75, cos(a) * 1.08), wood, 0.0, Vector3(0, a, 0))
	_box(p, Vector3(2.5, 0.1, 2.5), Vector3(0, 6.3, 0), Color(0.3, 0.32, 0.3), 0.4)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(p, Vector3(0.08, 1.4, 0.08), Vector3(sx * 1.0, 5.6, sz * 1.0), wood)
	for i in 8:
		_box(p, Vector3(0.5, 0.05, 0.08), Vector3(0.95, 0.4 + i * 0.48, 0), wood.darkened(0.2))  # ladder rungs


static func _generator(p: Node3D) -> void:
	var body := Color(0.72, 0.6, 0.18)
	_box(p, Vector3(2.6, 1.5, 1.3), Vector3(0, 0.85, 0), body, 0.3)
	_box(p, Vector3(2.7, 0.12, 1.4), Vector3(0, 0.08, 0), Color(0.15, 0.15, 0.15), 0.5)
	for i in 5:
		_box(p, Vector3(0.05, 0.9, 0.02), Vector3(-1.0 + i * 0.12, 0.9, -0.66), Color(0.2, 0.2, 0.18))  # grille
	_cyl(p, 0.1, 0.8, Vector3(0.9, 1.9, 0.3), Color(0.2, 0.2, 0.2))  # exhaust
	_box(p, Vector3(0.6, 0.5, 0.05), Vector3(0.6, 1.0, -0.67), Color(0.2, 0.22, 0.24), 0.4)  # panel
	_box(p, Vector3(0.5, 0.12, 0.01), Vector3(0.6, 1.4, -0.66), Color(0.1, 0.1, 0.1))
	_box(p, Vector3(0.15, 0.3, 0.02), Vector3(-0.3, 1.2, -0.67), Color(0.9, 0.2, 0.1))  # the big red switch
	for i in 3:
		_box(p, Vector3(0.9, 0.05, 0.02), Vector3(-0.4, 1.45 - i * 0.06, -0.66), Color(0.1, 0.1, 0.1) if i % 2 else body.darkened(0.5))


static func _terminal(p: Node3D, rng: RandomNumberGenerator) -> void:
	_box(p, Vector3(1.4, 0.05, 0.7), Vector3(0, 0.75, 0), Color(0.3, 0.32, 0.34), 0.4)
	_box(p, Vector3(1.3, 0.72, 0.6), Vector3(0, 0.36, 0.02), Color(0.22, 0.24, 0.26), 0.4)
	_monitor(p, Vector3(0, 0.78, 0.05), rng)
	_box(p, Vector3(0.5, 0.03, 0.18), Vector3(0, 0.79, -0.18), Color(0.12, 0.12, 0.12))  # keyboard


static func _server(p: Node3D, size: Vector2, rng: RandomNumberGenerator) -> void:
	var count := maxi(int(size.x / 0.7), 1)
	for i in count:
		var x := -size.x / 2.0 + 0.35 + i * 0.7
		_box(p, Vector3(0.65, 2.1, 0.9), Vector3(x, 1.05, 0), Color(0.1, 0.11, 0.12), 0.5)
		for j in 8:
			_box(p, Vector3(0.58, 0.02, 0.01), Vector3(x, 0.3 + j * 0.22, -0.455), Color(0.2, 0.21, 0.22))
			if rng.randf() < 0.6:
				_glow(p, Vector3(0.03, 0.02, 0.01), Vector3(x + rng.randf_range(-0.2, 0.2), 0.35 + j * 0.22, -0.46), Color(0.2, 1.0, 0.4) if rng.randf() < 0.8 else Color(1.0, 0.5, 0.1), 3.0)


static func _pod(p: Node3D, kind: String, rng: RandomNumberGenerator) -> void:
	_cyl(p, 0.75, 0.3, Vector3(0, 0.15, 0), Color(0.3, 0.32, 0.34))
	_cyl(p, 0.75, 0.3, Vector3(0, 2.75, 0), Color(0.3, 0.32, 0.34))
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		_box(p, Vector3(0.08, 2.3, 0.08), Vector3(cos(a) * 0.7, 1.45, sin(a) * 0.7), Color(0.25, 0.27, 0.28), 0.6)
	if kind != "pod_broken":
		var tube := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.68
		cyl.bottom_radius = 0.68
		cyl.height = 2.3
		tube.mesh = cyl
		var liquid := StandardMaterial3D.new()
		liquid.albedo_color = Color(0.9, 0.55, 0.2, 0.35) if kind == "pod" else Color(0.5, 0.7, 0.7, 0.18)
		liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		liquid.emission_enabled = kind == "pod"
		liquid.emission = Color(1.0, 0.5, 0.15)
		liquid.emission_energy_multiplier = 0.4
		liquid.roughness = 0.1
		tube.material_override = liquid
		tube.position.y = 1.45
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_child(tube)
	else:
		for i in 6:
			_box(p, Vector3(rng.randf_range(0.1, 0.3), 0.02, rng.randf_range(0.1, 0.3)), Vector3(rng.randf_range(-1, 1), 0.02, rng.randf_range(-1, 1)), Tex.glass().albedo_color, 0.6)
	if kind == "pod":
		# Someone floating inside, curled up.
		var parts := Models.creature("mutant" if rng.randf() < 0.3 else "infected", rng.randi())
		var body: Node3D = parts["root"]
		body.position = Vector3(0, 0.55, 0)
		body.rotation = Vector3(0.15, rng.randf() * TAU, 0.1)
		(parts["thighs"][0] as Node3D).rotation.x = 0.6
		(parts["thighs"][1] as Node3D).rotation.x = 0.4
		(parts["shins"][0] as Node3D).rotation.x = -0.9
		(parts["head"] as Node3D).rotation.x = 0.4
		p.add_child(body)
		_light(p, Vector3(0, 1.5, 0), Color(1.0, 0.55, 0.2), 0.7, 3.0)


static func _tv(p: Node3D) -> void:
	_box(p, Vector3(1.4, 0.5, 0.45), Vector3(0, 0.25, 0), Color(0.3, 0.22, 0.15))  # stand
	_box(p, Vector3(1.2, 0.72, 0.08), Vector3(0, 0.9, 0), Color(0.05, 0.05, 0.05))
	var screen := _glow(p, Vector3(1.1, 0.62, 0.01), Vector3(0, 0.9, -0.045), Color(0.35, 0.45, 0.8), 1.4)
	screen.name = "Screen"
	var label := Label3D.new()
	label.text = "EMERGENCY\nBROADCAST"
	label.font_size = 48
	label.pixel_size = 0.004
	label.modulate = Color(1, 1, 1, 0.9)
	label.position = Vector3(0, 0.9, -0.052)
	label.rotation.y = PI
	p.add_child(label)
	_light(p, Vector3(0, 0.9, -0.8), Color(0.5, 0.6, 1.0), 0.6, 4.0)


static func _reactor(p: Node3D) -> void:
	_cyl(p, 2.6, 0.6, Vector3(0, 0.3, 0), Color(0.2, 0.21, 0.22))
	_cyl(p, 2.0, 0.4, Vector3(0, 7.5, 0), Color(0.2, 0.21, 0.22))
	var core := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.2
	cyl.height = 7.0
	core.mesh = cyl
	core.material_override = Tex.flat(Color(1.0, 0.55, 0.15), 4.0)
	core.position.y = 3.8
	core.name = "Core"
	p.add_child(core)
	for i in 5:
		_cyl(p, 1.5, 0.2, Vector3(0, 1.2 + i * 1.4, 0), Color(0.25, 0.26, 0.27))
	for i in 6:
		var a := i * TAU / 6.0
		_box(p, Vector3(0.3, 7.2, 0.3), Vector3(cos(a) * 1.7, 3.8, sin(a) * 1.7), Color(0.18, 0.19, 0.2), 0.6)
	var light := _light(p, Vector3(0, 4, 0), Color(1.0, 0.55, 0.2), 4.0, 22.0)
	light.name = "Glow"


static func _elevator(p: Node3D) -> void:
	_box(p, Vector3(2.6, 3.4, 0.3), Vector3(0, 1.7, 0.2), Color(0.3, 0.32, 0.34), 0.5)
	_box(p, Vector3(1.9, 2.6, 0.06), Vector3(0, 1.3, 0.02), Color(0.55, 0.57, 0.58), 0.8)
	_box(p, Vector3(0.02, 2.6, 0.07), Vector3(0, 1.3, 0.0), Color(0.1, 0.1, 0.1))
	_box(p, Vector3(0.18, 0.3, 0.05), Vector3(1.15, 1.3, 0.0), Color(0.15, 0.15, 0.16))
	_glow(p, Vector3(0.08, 0.08, 0.02), Vector3(1.15, 1.35, -0.03), Color(0.2, 1.0, 0.3), 3.0)
	_glow(p, Vector3(0.6, 0.12, 0.02), Vector3(0, 2.8, -0.0), Color(1.0, 0.7, 0.2), 1.5)


# --- Lamps ---------------------------------------------------------------------------------

## A lamp of `kind` (street, ceiling, wall, red, work); returns [node, light, bulb].
static func lamp(kind: String, height: float) -> Array:
	Models.vm = false
	var p := Node3D.new()
	var light: Light3D
	var bulb: MeshInstance3D
	match kind:
		"street":
			_cyl(p, 0.08, 6.5, Vector3(0, 3.25, 0), Color(0.25, 0.26, 0.27))
			_box(p, Vector3(1.4, 0.1, 0.12), Vector3(0.65, 6.45, 0), Color(0.25, 0.26, 0.27), 0.5)
			_box(p, Vector3(0.6, 0.15, 0.3), Vector3(1.3, 6.35, 0), Color(0.2, 0.2, 0.2), 0.5)
			bulb = _glow(p, Vector3(0.5, 0.04, 0.24), Vector3(1.3, 6.26, 0), Color(1.0, 0.8, 0.5), 5.0)
			var spot := SpotLight3D.new()
			spot.position = Vector3(1.3, 6.1, 0)
			spot.rotation.x = -PI / 2.0
			spot.light_color = Color(1.0, 0.78, 0.5)
			spot.light_energy = 6.0
			spot.spot_range = 13.0
			spot.spot_angle = 55.0
			spot.shadow_enabled = true
			p.add_child(spot)
			light = spot
		"ceiling", "red", "work":
			var color := Color(0.95, 0.95, 1.0) if kind == "ceiling" else (Color(1.0, 0.12, 0.08) if kind == "red" else Color(1.0, 0.85, 0.6))
			_box(p, Vector3(1.2, 0.08, 0.3), Vector3(0, height - 0.06, 0), Color(0.3, 0.3, 0.32), 0.4)
			bulb = _glow(p, Vector3(1.1, 0.03, 0.22), Vector3(0, height - 0.11, 0), color, 4.0)
			light = _light(p, Vector3(0, height - 0.5, 0), color, 1.6 if kind != "red" else 2.2, 9.0 if kind != "red" else 11.0)
		_:  # wall: a caged bulb
			_box(p, Vector3(0.2, 0.25, 0.12), Vector3(0, 2.6, 0), Color(0.25, 0.25, 0.25), 0.4)
			bulb = _glow(p, Vector3(0.12, 0.12, 0.1), Vector3(0, 2.6, -0.06), Color(1.0, 0.85, 0.55), 4.0)
			light = _light(p, Vector3(0, 2.5, -0.4), Color(1.0, 0.8, 0.55), 1.4, 7.0)
	Models.merge(p)
	return [p, light, bulb]


# --- Pickups -------------------------------------------------------------------------------

## Something the player picks up by walking over it.
static func pickup(kind: String) -> Node3D:
	Models.vm = false
	var p := Node3D.new()
	match kind:
		"medkit":
			_box(p, Vector3(0.45, 0.28, 0.32), Vector3(0, 0.14, 0), Color(0.9, 0.9, 0.88))
			_box(p, Vector3(0.24, 0.07, 0.01), Vector3(0, 0.16, -0.165), Color(0.8, 0.1, 0.1))
			_box(p, Vector3(0.07, 0.2, 0.01), Vector3(0, 0.16, -0.165), Color(0.8, 0.1, 0.1))
			_box(p, Vector3(0.01, 0.07, 0.24), Vector3(0.23, 0.16, 0), Color(0.8, 0.1, 0.1))
		"ammo":
			_box(p, Vector3(0.5, 0.3, 0.3), Vector3(0, 0.15, 0), Color(0.3, 0.34, 0.2), 0.3)
			_box(p, Vector3(0.52, 0.04, 0.32), Vector3(0, 0.3, 0), Color(0.2, 0.22, 0.14), 0.3)
			_box(p, Vector3(0.3, 0.08, 0.01), Vector3(0, 0.16, -0.155), Color(0.9, 0.85, 0.5))
		"armor":
			_box(p, Vector3(0.45, 0.55, 0.1), Vector3(0, 0.3, 0), Color(0.2, 0.22, 0.2))
			_box(p, Vector3(0.38, 0.3, 0.05), Vector3(0, 0.33, -0.07), Color(0.28, 0.3, 0.26))
		"intel":
			_box(p, Vector3(0.32, 0.03, 0.24), Vector3(0, 0.02, 0), Color(0.85, 0.72, 0.4))
			_box(p, Vector3(0.28, 0.02, 0.2), Vector3(0.02, 0.045, 0.01), Color(0.95, 0.95, 0.9))
			_box(p, Vector3(0.1, 0.01, 0.04), Vector3(0.0, 0.056, -0.05), Color(0.8, 0.1, 0.1))  # CLASSIFIED stamp
		"key_red", "key_blue", "key_yellow":
			var c := {"key_red": Color(0.9, 0.15, 0.1), "key_blue": Color(0.2, 0.45, 1.0), "key_yellow": Color(1.0, 0.8, 0.1)}[kind] as Color
			_box(p, Vector3(0.2, 0.01, 0.13), Vector3(0, 0.02, 0), Color(0.9, 0.9, 0.9))
			_glow(p, Vector3(0.2, 0.012, 0.05), Vector3(0, 0.022, -0.03), c, 2.0)
		"gasmask":
			_box(p, Vector3(0.2, 0.22, 0.1), Vector3(0, 0.12, 0), Color(0.16, 0.17, 0.16))
			_cyl(p, 0.05, 0.08, Vector3(0, 0.06, -0.07), Color(0.22, 0.24, 0.2), Vector3(PI / 2.0, 0, 0))
		"charge":
			_box(p, Vector3(0.3, 0.2, 0.2), Vector3(0, 0.1, 0), Color(0.62, 0.48, 0.3))
			_glow(p, Vector3(0.05, 0.05, 0.02), Vector3(0.08, 0.21, 0), Color(1, 0.1, 0.05), 3.0)
	Models.merge(p)
	return p


## A dead body on the ground, as they fell.
static func corpse(faction: String, rng: RandomNumberGenerator) -> Node3D:
	var parts := Models.soldier(faction, rng.randi())
	var root: Node3D = parts["root"]
	var body := Node3D.new()
	body.add_child(root)
	root.rotation = Vector3(-PI / 2.0 + 0.05 if rng.randf() < 0.5 else PI / 2.0 - 0.05, rng.randf() * TAU, 0)
	root.position.y = 0.14
	(parts["thighs"][0] as Node3D).rotation.x = rng.randf_range(-0.2, 0.6)
	(parts["shins"][0] as Node3D).rotation.x = rng.randf_range(-1.2, 0.0)
	(parts["thighs"][1] as Node3D).rotation.x = rng.randf_range(-0.1, 0.3)
	(parts["head"] as Node3D).rotation.z = rng.randf_range(-0.6, 0.6)
	Models.arm_soldier(parts["aim"], "", parts["arm_color"])
	(parts["aim"] as Node3D).rotation.x = rng.randf_range(-0.2, 1.2)
	# A dark pool under them.
	var pool := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = rng.randf_range(0.5, 0.8)
	disc.bottom_radius = disc.top_radius
	disc.height = 0.01
	pool.mesh = disc
	pool.material_override = Tex.flat(Color(0.2, 0.02, 0.02))
	pool.position = Vector3(0, 0.008, 0)
	pool.scale = Vector3(1.0, 1.0, 1.5)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(pool)
	return body
