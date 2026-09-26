extends RefCounted
## The 3D models, built from boxes and cylinders at runtime: every gun and piece of gear, the soldiers
## of both sides and the first-person arms. Guns point down -Z with the grip at the origin, and carry a
## "Muzzle" marker where the flash and tracers start.

const Tex := preload("res://scripts/textures.gd")
const Weapons := preload("res://scripts/weapons.gd")

const GUNMETAL := Color(0.13, 0.13, 0.14)
const POLY := Color(0.06, 0.06, 0.07)
const STEEL := Color(0.55, 0.56, 0.58)
const WOOD := Color(0.42, 0.24, 0.12)
const TAN := Color(0.58, 0.50, 0.36)
const OLIVE := Color(0.27, 0.31, 0.20)
const SKIN := Color(0.78, 0.60, 0.46)
const GLOVE := Color(0.10, 0.09, 0.09)

## Clothes of each side: shirt, vest, trousers, headgear. The match uses att and def; the campaign
## dresses its people by faction: the sector's rogue security, the Black Division (Mercer's own unit),
## the army, and the HELIX creatures (whose clothes are whatever they died in).
const UNIFORM := {
	"att": [Color(0.55, 0.47, 0.33), Color(0.29, 0.27, 0.21), Color(0.42, 0.37, 0.27), Color(0.07, 0.07, 0.07)],
	"def": [Color(0.20, 0.25, 0.33), Color(0.11, 0.13, 0.17), Color(0.22, 0.25, 0.30), Color(0.15, 0.18, 0.23)],
	"rogue": [Color(0.36, 0.4, 0.44), Color(0.2, 0.22, 0.25), Color(0.3, 0.33, 0.36), Color(0.25, 0.27, 0.3)],
	"black": [Color(0.13, 0.13, 0.14), Color(0.08, 0.08, 0.09), Color(0.14, 0.14, 0.15), Color(0.06, 0.06, 0.07)],
	"mercer": [Color(0.2, 0.22, 0.2), Color(0.13, 0.14, 0.12), Color(0.18, 0.19, 0.17), Color(0.12, 0.13, 0.12)],
	"army": [Color(0.36, 0.39, 0.26), Color(0.27, 0.29, 0.19), Color(0.33, 0.35, 0.23), Color(0.3, 0.33, 0.21)],
	"infected": [Color(0.7, 0.7, 0.68), Color(0.3, 0.3, 0.3), Color(0.25, 0.3, 0.42), Color(0.2, 0.2, 0.2)],
	"mutant": [Color(0.5, 0.45, 0.48), Color(0.3, 0.3, 0.3), Color(0.3, 0.3, 0.3), Color(0.2, 0.2, 0.2)],
	"first": [Color(0.07, 0.08, 0.09), Color(0.05, 0.05, 0.06), Color(0.07, 0.08, 0.09), Color(0.04, 0.04, 0.05)],
}
const HELIX_GLOW := Color(1.0, 0.55, 0.15)  # the color of HELIX tissue
const FIRST_GLOW := Color(0.2, 0.85, 1.0)

static var _boxes := {}
static var vm := false  # true while building the first-person model


static func _mat(color: Color, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	return Tex.flat(color, glow, metal, vm)


static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := str(size)
	if not _boxes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_boxes[key] = mesh
	return _boxes[key]


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metal := 0.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = _box_mesh(size)
	part.material_override = _mat(color, metal)
	part.position = pos
	part.rotation = rot
	parent.add_child(part)
	return part


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _mat(color, 0.3)
	part.position = pos
	part.rotation = rot
	parent.add_child(part)
	return part


## A box stretched from a to b, for arms and legs.
static func limb(parent: Node3D, a: Vector3, b: Vector3, thick: float, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var length := maxf(a.distance_to(b), 0.01)
	part.mesh = _box_mesh(Vector3(thick, thick, length))
	part.material_override = _mat(color)
	var dir := b - a
	var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.BACK
	part.transform = Transform3D(Basis.looking_at(dir, up), (a + b) / 2.0)
	parent.add_child(part)
	return part


static func _muzzle(parent: Node3D, z: float, y := 0.03) -> void:
	var mark := Marker3D.new()
	mark.name = "Muzzle"
	mark.position = Vector3(0, y, z)
	parent.add_child(mark)


# --- Guns ----------------------------------------------------------------------------------

static func gun(id: String) -> Node3D:
	var g := Node3D.new()
	match id:
		"claws", "maul":
			_muzzle(g, -0.3, 0.0)
		"helix":
			box(g, Vector3(0.055, 0.09, 0.5), Vector3(0, 0.04, -0.12), POLY, 0.4)
			box(g, Vector3(0.06, 0.03, 0.34), Vector3(0, 0.1, -0.12), GUNMETAL, 0.6)
			box(g, Vector3(0.03, 0.03, 0.3), Vector3(0, 0.03, -0.5), GUNMETAL, 0.6)
			box(g, Vector3(0.062, 0.012, 0.36), Vector3(0, 0.07, -0.12), FIRST_GLOW, 0.0)  # glowing strip
			box(g, Vector3(0.04, 0.14, 0.05), Vector3(0, -0.07, -0.08), POLY, 0.0, Vector3(-0.2, 0, 0))
			box(g, Vector3(0.032, 0.1, 0.045), Vector3(0, -0.04, 0.05), POLY, 0.0, Vector3(0.3, 0, 0))
			box(g, Vector3(0.045, 0.09, 0.2), Vector3(0, 0.0, 0.22), POLY)
			_glow(g, Vector3(0.064, 0.014, 0.3), Vector3(0, 0.07, -0.12), FIRST_GLOW)
			_sight(g, 0.12, 0.0)
			_muzzle(g, -0.66, 0.03)
		"knife":
			box(g, Vector3(0.028, 0.032, 0.11), Vector3(0, 0, 0.02), POLY)
			for i in 4:
				box(g, Vector3(0.03, 0.006, 0.012), Vector3(0, -0.017, -0.02 + i * 0.025), GUNMETAL)  # grip rings
			box(g, Vector3(0.05, 0.036, 0.012), Vector3(0, 0, -0.04), GUNMETAL, 0.6)
			box(g, Vector3(0.006, 0.032, 0.17), Vector3(0, 0.004, -0.13), STEEL, 0.9)
			box(g, Vector3(0.007, 0.006, 0.15), Vector3(0, 0.02, -0.12), STEEL.darkened(0.3), 0.9)  # spine
			box(g, Vector3(0.006, 0.012, 0.06), Vector3(0, 0.02, -0.19), STEEL.lightened(0.2), 0.9, Vector3(0.35, 0, 0))
			box(g, Vector3(0.03, 0.02, 0.02), Vector3(0, 0, 0.085), GUNMETAL, 0.6)  # pommel
			_muzzle(g, -0.2, 0.0)
		"p18", "k45", "m25", "magnum":
			var big := id == "magnum"
			var slide := STEEL if big else (TAN.darkened(0.3) if id == "m25" else GUNMETAL)
			var length := 0.26 if big else (0.2 if id == "k45" else 0.18)
			var k := 1.15 if big else 1.0
			var top := 0.045 + 0.023 * k
			box(g, Vector3(0.036, 0.046, length) * k, Vector3(0, 0.045, -length / 2.0 + 0.04), slide, 0.7)
			for i in 5:
				box(g, Vector3(0.038 * k, 0.03, 0.004), Vector3(0, 0.045, 0.02 - i * 0.008), slide.darkened(0.4), 0.7)  # serrations
			box(g, Vector3(0.004, 0.016, 0.04), Vector3(0.019 * k, 0.05, -0.02), POLY)  # ejection port
			box(g, Vector3(0.03, 0.028, length * 0.8), Vector3(0, 0.012, -length * 0.4 + 0.04), POLY)
			box(g, Vector3(0.024, 0.01, length * 0.35), Vector3(0, -0.004, -length * 0.55 + 0.04), POLY.lightened(0.05))  # rail
			box(g, Vector3(0.032, 0.11, 0.05), Vector3(0, -0.04, 0.02), POLY, 0.0, Vector3(0.25, 0, 0))
			box(g, Vector3(0.034, 0.08, 0.035), Vector3(0, -0.04, 0.025), POLY.lightened(0.08), 0.0, Vector3(0.25, 0, 0))  # grip panel
			box(g, Vector3(0.028, 0.012, 0.05), Vector3(0, -0.098, 0.035), GUNMETAL, 0.6)  # magazine base
			_guard(g, -0.03)
			box(g, Vector3(0.028, 0.01, 0.01), Vector3(0, top + 0.005, 0.03), POLY)  # rear sight
			box(g, Vector3(0.006, 0.01, 0.008), Vector3(0, top + 0.005, -length + 0.06), POLY)  # front sight
			if big:
				box(g, Vector3(0.02, 0.012, 0.03), Vector3(0, top - 0.004, 0.05), GUNMETAL, 0.6)  # hammer
			_sight(g, top + 0.011, 0.03)
			if id == "k45":
				cylinder(g, 0.016, 0.12, Vector3(0, 0.045, -0.21), POLY, Vector3(PI / 2.0, 0, 0))  # suppressor
				cylinder(g, 0.017, 0.01, Vector3(0, 0.045, -0.16), GUNMETAL, Vector3(PI / 2.0, 0, 0))
				_muzzle(g, -0.28, 0.045)
			else:
				_muzzle(g, -length + 0.02, 0.045)
		"mx9", "u45":
			var body := GUNMETAL if id == "mx9" else POLY
			box(g, Vector3(0.05, 0.075, 0.3), Vector3(0, 0.035, -0.1), body, 0.3)
			box(g, Vector3(0.004, 0.02, 0.06), Vector3(0.026, 0.05, -0.05), Color(0.02, 0.02, 0.02))  # ejection port
			box(g, Vector3(0.012, 0.012, 0.03), Vector3(-0.03, 0.06, -0.12), STEEL, 0.8)  # charging handle
			box(g, Vector3(0.024, 0.024, 0.12), Vector3(0, 0.05, -0.3), GUNMETAL, 0.6)
			cylinder(g, 0.016, 0.03, Vector3(0, 0.05, -0.37), GUNMETAL, Vector3(PI / 2.0, 0, 0))
			box(g, Vector3(0.03, 0.16 if id == "mx9" else 0.13, 0.045), Vector3(0, -0.08, -0.13), POLY, 0.0, Vector3(-0.1 if id == "u45" else 0.0, 0, 0))
			box(g, Vector3(0.032, 0.1, 0.045), Vector3(0, -0.04, 0.02), POLY, 0.0, Vector3(0.25, 0, 0))
			_guard(g, -0.03)
			box(g, Vector3(0.02, 0.05, 0.2), Vector3(0, 0.03, 0.15), POLY)
			box(g, Vector3(0.024, 0.07, 0.02), Vector3(0, 0.02, 0.25), POLY)  # butt plate
			box(g, Vector3(0.03, 0.012, 0.22), Vector3(0, 0.078, -0.1), POLY.lightened(0.06))  # top rail
			box(g, Vector3(0.03, 0.02, 0.012), Vector3(0, 0.092, 0.02), POLY)  # rear sight
			box(g, Vector3(0.008, 0.024, 0.01), Vector3(0, 0.09, -0.23), POLY)  # front sight
			_sight(g, 0.1, 0.02)
			_muzzle(g, -0.38, 0.05)
		"pump":
			box(g, Vector3(0.036, 0.036, 0.62), Vector3(0, 0.055, -0.36), GUNMETAL, 0.7)
			box(g, Vector3(0.03, 0.03, 0.46), Vector3(0, 0.018, -0.3), GUNMETAL, 0.5)
			box(g, Vector3(0.052, 0.05, 0.15), Vector3(0, 0.02, -0.34), WOOD)
			for i in 5:
				box(g, Vector3(0.054, 0.006, 0.01), Vector3(0, 0.02, -0.4 + i * 0.03), WOOD.darkened(0.35))  # grip grooves
			box(g, Vector3(0.05, 0.075, 0.2), Vector3(0, 0.035, -0.02), GUNMETAL, 0.5)
			box(g, Vector3(0.004, 0.025, 0.07), Vector3(0.026, 0.045, -0.03), Color(0.02, 0.02, 0.02))  # loading port
			box(g, Vector3(0.032, 0.1, 0.045), Vector3(0, -0.04, 0.05), WOOD, 0.0, Vector3(0.35, 0, 0))
			_guard(g, 0.0)
			box(g, Vector3(0.045, 0.09, 0.3), Vector3(0, -0.01, 0.22), WOOD, 0.0, Vector3(0.12, 0, 0))
			box(g, Vector3(0.047, 0.095, 0.02), Vector3(0, -0.03, 0.37), POLY, 0.0, Vector3(0.12, 0, 0))  # recoil pad
			box(g, Vector3(0.03, 0.008, 0.012), Vector3(0, 0.078, 0.02), GUNMETAL)  # rear notch
			box(g, Vector3(0.01, 0.01, 0.01), Vector3(0, 0.078, -0.65), Color(0.9, 0.85, 0.6), 0.8)  # bead
			_sight(g, 0.082, 0.02)
			_muzzle(g, -0.68, 0.055)
		"ar7", "viper":
			var furniture := WOOD if id == "ar7" else POLY
			var metal := GUNMETAL if id == "ar7" else OLIVE
			box(g, Vector3(0.05, 0.08, 0.34), Vector3(0, 0.035, -0.08), GUNMETAL, 0.5)
			box(g, Vector3(0.052, 0.012, 0.26), Vector3(0, 0.078, -0.03), GUNMETAL.lightened(0.05), 0.5)  # dust cover
			box(g, Vector3(0.004, 0.022, 0.07), Vector3(0.027, 0.055, -0.05), Color(0.02, 0.02, 0.02))  # ejection port
			box(g, Vector3(0.03, 0.01, 0.02), Vector3(0.035, 0.06, -0.07), STEEL, 0.8)  # bolt handle
			box(g, Vector3(0.004, 0.035, 0.08), Vector3(0.027, 0.02, -0.12), GUNMETAL.lightened(0.1), 0.6)  # selector
			box(g, Vector3(0.022, 0.022, 0.38), Vector3(0, 0.05, -0.44), GUNMETAL, 0.6)
			box(g, Vector3(0.02, 0.02, 0.24), Vector3(0, 0.082, -0.3), GUNMETAL, 0.6)  # gas tube
			box(g, Vector3(0.052, 0.056, 0.2), Vector3(0, 0.035, -0.34), furniture)
			box(g, Vector3(0.05, 0.03, 0.14), Vector3(0, 0.082, -0.33), furniture)  # upper handguard
			cylinder(g, 0.017, 0.05, Vector3(0, 0.05, -0.64), GUNMETAL, Vector3(PI / 2.0, 0, 0))  # muzzle brake
			box(g, Vector3(0.012, 0.04, 0.012), Vector3(0, 0.074, -0.6), GUNMETAL)  # front post
			box(g, Vector3(0.03, 0.02, 0.018), Vector3(0, 0.064, -0.6), GUNMETAL)
			box(g, Vector3(0.034, 0.018, 0.04), Vector3(0, 0.086, -0.22), GUNMETAL, 0.4)  # rear sight
			box(g, Vector3(0.034, 0.12, 0.06), Vector3(0, -0.07, -0.15), metal, 0.3, Vector3(-0.3, 0, 0))
			box(g, Vector3(0.034, 0.1, 0.06), Vector3(0, -0.16, -0.1), metal, 0.3, Vector3(-0.65, 0, 0))
			box(g, Vector3(0.036, 0.008, 0.06), Vector3(0, -0.06, -0.15), metal.lightened(0.1), 0.3, Vector3(-0.3, 0, 0))  # mag rib
			box(g, Vector3(0.032, 0.1, 0.045), Vector3(0, -0.04, 0.03), POLY, 0.0, Vector3(0.3, 0, 0))
			_guard(g, -0.02)
			box(g, Vector3(0.045, 0.09, 0.3), Vector3(0, -0.005, 0.24), furniture, 0.0, Vector3(0.1, 0, 0))
			box(g, Vector3(0.047, 0.1, 0.02), Vector3(0, -0.02, 0.39), GUNMETAL, 0.4, Vector3(0.1, 0, 0))  # butt plate
			_sight(g, 0.094, -0.22)
			_muzzle(g, -0.67, 0.05)
		"m4", "f90":
			var color := POLY if id == "m4" else TAN
			box(g, Vector3(0.05, 0.08, 0.34), Vector3(0, 0.035, -0.08), color, 0.2)
			box(g, Vector3(0.004, 0.022, 0.06), Vector3(0.027, 0.05, -0.04), Color(0.02, 0.02, 0.02))  # ejection port
			cylinder(g, 0.008, 0.012, Vector3(0.028, 0.05, 0.02), STEEL, Vector3(0, 0, PI / 2.0))  # forward assist
			box(g, Vector3(0.03, 0.02, 0.3), Vector3(0, 0.085, -0.1), POLY)  # top rail
			for i in 10:
				box(g, Vector3(0.032, 0.006, 0.012), Vector3(0, 0.097, 0.03 - i * 0.03), POLY.lightened(0.1))  # rail teeth
			box(g, Vector3(0.056, 0.062, 0.24), Vector3(0, 0.035, -0.36), color, 0.2)
			for i in 4:
				box(g, Vector3(0.058, 0.012, 0.03), Vector3(0, 0.035, -0.28 - i * 0.055), color.darkened(0.3))  # vents
			box(g, Vector3(0.02, 0.02, 0.2), Vector3(0, 0.045, -0.55), GUNMETAL, 0.6)
			cylinder(g, 0.016, 0.06, Vector3(0, 0.045, -0.66), GUNMETAL, Vector3(PI / 2.0, 0, 0))  # flash hider
			box(g, Vector3(0.012, 0.075, 0.015), Vector3(0, 0.087, -0.5), POLY)  # front sight post
			box(g, Vector3(0.03, 0.015, 0.02), Vector3(0, 0.055, -0.5), POLY)
			box(g, Vector3(0.032, 0.15, 0.06), Vector3(0, -0.09, -0.14), POLY, 0.2, Vector3(-0.12, 0, 0))
			box(g, Vector3(0.032, 0.1, 0.045), Vector3(0, -0.04, 0.03), POLY, 0.0, Vector3(0.3, 0, 0))
			_guard(g, -0.02)
			box(g, Vector3(0.022, 0.03, 0.14), Vector3(0, 0.035, 0.15), GUNMETAL, 0.4)  # buffer tube
			box(g, Vector3(0.04, 0.085, 0.16), Vector3(0, 0.005, 0.25), color)
			box(g, Vector3(0.042, 0.09, 0.02), Vector3(0, 0.0, 0.33), POLY)
			box(g, Vector3(0.03, 0.03, 0.04), Vector3(0, 0.11, 0.02), POLY)  # rear sight
			box(g, Vector3(0.008, 0.01, 0.042), Vector3(-0.011, 0.13, 0.02), POLY)
			box(g, Vector3(0.008, 0.01, 0.042), Vector3(0.011, 0.13, 0.02), POLY)
			_sight(g, 0.127, 0.02)
			_muzzle(g, -0.7, 0.045)
		"scout", "longbow":
			var awp := id == "longbow"
			var color := OLIVE if awp else POLY
			box(g, Vector3(0.05, 0.07, 0.4), Vector3(0, 0.03, -0.12), color)
			box(g, Vector3(0.024, 0.024, 0.5 if awp else 0.42), Vector3(0, 0.045, -0.55 if awp else -0.5), GUNMETAL, 0.6)
			if awp:
				cylinder(g, 0.022, 0.08, Vector3(0, 0.045, -0.82), GUNMETAL, Vector3(PI / 2.0, 0, 0))  # muzzle brake
			cylinder(g, 0.028 if awp else 0.022, 0.32, Vector3(0, 0.12, -0.12), POLY, Vector3(PI / 2.0, 0, 0))
			cylinder(g, 0.036 if awp else 0.03, 0.05, Vector3(0, 0.12, -0.3), POLY, Vector3(PI / 2.0, 0, 0))
			cylinder(g, 0.03 if awp else 0.026, 0.04, Vector3(0, 0.12, 0.05), POLY, Vector3(PI / 2.0, 0, 0))
			cylinder(g, 0.012, 0.03, Vector3(0, 0.155, -0.12), GUNMETAL)  # turret
			var lens := MeshInstance3D.new()
			lens.mesh = _box_mesh(Vector3(0.04, 0.04, 0.004))
			lens.material_override = _mat(Color(0.3, 0.5, 0.8), 0.9)
			lens.position = Vector3(0, 0.12, -0.326)
			g.add_child(lens)
			box(g, Vector3(0.01, 0.05, 0.02), Vector3(0, 0.085, -0.12), POLY)
			box(g, Vector3(0.03, 0.01, 0.03), Vector3(0.035, 0.05, 0.0), STEEL, 0.8)  # bolt
			box(g, Vector3(0.016, 0.016, 0.016), Vector3(0.05, 0.05, 0.0), POLY)
			box(g, Vector3(0.032, 0.1, 0.045), Vector3(0, -0.04, 0.04), color, 0.0, Vector3(0.3, 0, 0))
			_guard(g, -0.01)
			box(g, Vector3(0.048, 0.1 if awp else 0.08, 0.32), Vector3(0, -0.01, 0.24), color)
			box(g, Vector3(0.05, 0.03, 0.14), Vector3(0, 0.05, 0.22), color.lightened(0.05))  # cheek rest
			box(g, Vector3(0.03, 0.08, 0.08), Vector3(0, -0.05, -0.12), POLY)
			_sight(g, 0.12, 0.06)
			_muzzle(g, -0.86 if awp else -0.72, 0.045)
		"he":
			var shell := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.04
			sphere.height = 0.09
			shell.mesh = sphere
			shell.material_override = _mat(OLIVE)
			g.add_child(shell)
			for i in 3:
				box(g, Vector3(0.082, 0.004, 0.082), Vector3(0, -0.02 + i * 0.02, 0), OLIVE.darkened(0.3))  # grooves
			box(g, Vector3(0.02, 0.03, 0.02), Vector3(0, 0.05, 0), GUNMETAL, 0.6)
			box(g, Vector3(0.012, 0.07, 0.01), Vector3(0.02, 0.02, 0), GUNMETAL, 0.6)
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.008
			torus.outer_radius = 0.013
			ring.mesh = torus
			ring.material_override = _mat(STEEL, 0.8)
			ring.position = Vector3(-0.02, 0.065, 0)
			ring.rotation.x = PI / 2.0
			g.add_child(ring)
			_muzzle(g, 0.0, 0.0)
		"flash", "smoke":
			cylinder(g, 0.028, 0.11, Vector3.ZERO, Color(0.8, 0.8, 0.78) if id == "flash" else Color(0.35, 0.38, 0.35))
			cylinder(g, 0.029, 0.02, Vector3(0, 0.02, 0), Color(0.2, 0.3, 0.8) if id == "flash" else Color(0.7, 0.7, 0.7))
			cylinder(g, 0.029, 0.01, Vector3(0, -0.045, 0), GUNMETAL)
			box(g, Vector3(0.02, 0.03, 0.02), Vector3(0, 0.065, 0), GUNMETAL, 0.6)
			box(g, Vector3(0.012, 0.08, 0.01), Vector3(0.024, 0.03, 0), GUNMETAL, 0.6)  # spoon
			_muzzle(g, 0.0, 0.0)
		"bomb":
			bomb_model(g)
			_muzzle(g, 0.0, 0.0)
	return g


## A glowing part (not merged, so it keeps its light).
static func _glow(parent: Node3D, size: Vector3, pos: Vector3, color: Color, energy := 3.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = _box_mesh(size)
	part.material_override = Tex.flat(color, energy, 0.0, vm)
	part.position = pos
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


## A trigger guard and trigger in front of the grip, at z.
static func _guard(g: Node3D, z: float) -> void:
	box(g, Vector3(0.008, 0.006, 0.055), Vector3(0, -0.03, z - 0.01), POLY)
	box(g, Vector3(0.008, 0.03, 0.006), Vector3(0, -0.016, z - 0.037), POLY)
	box(g, Vector3(0.005, 0.02, 0.006), Vector3(0, -0.012, z - 0.005), GUNMETAL, 0.6, Vector3(0.3, 0, 0))


## The point the eye lines up with when aiming down the sights.
static func _sight(g: Node3D, y: float, z: float) -> void:
	var mark := Marker3D.new()
	mark.name = "Sight"
	mark.position = Vector3(0, y, z)
	g.add_child(mark)


## How far in front of the eye the rear sight sits when aiming.
static func ads_distance(id: String) -> float:
	match _kind(id):
		"pistol", "magnum":
			return 0.34
		"m4":
			return 0.1
		"smg", "shotgun":
			return 0.17
	return 0.14


static func bomb_model(parent: Node3D) -> MeshInstance3D:
	for i in 3:
		box(parent, Vector3(0.07, 0.07, 0.22), Vector3(-0.075 + i * 0.075, 0, 0), Color(0.62, 0.48, 0.30))
	box(parent, Vector3(0.24, 0.02, 0.06), Vector3(0, 0.04, 0.05), Color(0.1, 0.1, 0.1))
	box(parent, Vector3(0.24, 0.02, 0.06), Vector3(0, 0.04, -0.06), Color(0.1, 0.1, 0.1))
	box(parent, Vector3(0.1, 0.012, 0.07), Vector3(0.02, 0.045, 0), Color(0.12, 0.14, 0.12))
	box(parent, Vector3(0.07, 0.005, 0.025), Vector3(0.02, 0.052, -0.012), Color(0.3, 0.8, 0.3), 0.0)
	var led := MeshInstance3D.new()
	led.mesh = _box_mesh(Vector3(0.018, 0.018, 0.018))
	led.material_override = Tex.flat(Color(1.0, 0.1, 0.05), 3.0)
	led.position = Vector3(-0.07, 0.055, 0.02)
	parent.add_child(led)
	return led


## Where each hand holds a gun, relative to its grip: [right hand, left hand].
static func hands(id: String) -> Array:
	var kind: String = _kind(id)
	match kind:
		"pistol", "magnum":
			return [Vector3(0, -0.03, 0.02), Vector3(-0.02, -0.05, 0.01)]
		"knife", "he", "flash", "smoke", "bomb":
			return [Vector3(0, 0, 0.02), Vector3(-0.2, -0.12, 0.05)]
		"shotgun":
			return [Vector3(0, -0.03, 0.04), Vector3(0, 0.0, -0.34)]
		"claws":
			return [Vector3(0.1, 0.0, -0.1), Vector3(-0.3, 0.0, -0.1)]
		"smg":
			return [Vector3(0, -0.03, 0.02), Vector3(0, -0.02, -0.26)]
	return [Vector3(0, -0.03, 0.03), Vector3(0, 0.0, -0.36)]


static func _kind(id: String) -> String:
	return Weapons.LIST[id]["kind"] if Weapons.LIST.has(id) else "knife"


# --- Soldiers ------------------------------------------------------------------------------

## Skin tones and hair colors the soldiers are picked from.
const SKINS := [Color(0.88, 0.71, 0.57), Color(0.8, 0.62, 0.47), Color(0.68, 0.5, 0.36), Color(0.5, 0.35, 0.25),
		Color(0.36, 0.24, 0.17)]
const HAIR := [Color(0.08, 0.06, 0.05), Color(0.2, 0.13, 0.08), Color(0.42, 0.3, 0.18), Color(0.45, 0.43, 0.4)]
const BOOT := Color(0.16, 0.12, 0.09)


## A soldier of `team`: returns its moving parts by name (root, hips, thighs, shins, feet, torso, head,
## aim) and the colors of its arms. `look` picks the face, headgear and kit, so every soldier differs
## but always looks the same. Each moving part is one merged mesh.
static func soldier(team: String, look := 0) -> Dictionary:
	if team in ["infected", "mutant", "first"]:
		return creature(team, look)
	vm = false
	var rng := RandomNumberGenerator.new()
	rng.seed = look
	var colors: Array = UNIFORM[team]
	var shirt: Color = colors[0].darkened(rng.randf_range(-0.08, 0.1))
	var gear: Color = colors[1].darkened(rng.randf_range(-0.1, 0.12))
	var pants: Color = colors[2].darkened(rng.randf_range(-0.06, 0.1))
	var strap := gear.darkened(0.35)
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	var hair: Color = HAIR[rng.randi() % HAIR.size()]
	var root := Node3D.new()
	var hips := Node3D.new()
	hips.position.y = 0.9
	root.add_child(hips)
	var parts := {"root": root, "hips": hips, "thighs": [], "shins": [], "feet": []}
	box(hips, Vector3(0.34, 0.2, 0.22), Vector3(0, 0.0, 0.0), pants)  # pelvis
	box(hips, Vector3(0.3, 0.12, 0.06), Vector3(0, -0.02, 0.1), pants.darkened(0.05))  # seat
	for side in [-1, 1]:
		var thigh := Node3D.new()
		thigh.position = Vector3(0.1 * side, -0.02, 0)
		hips.add_child(thigh)
		box(thigh, Vector3(0.18, 0.26, 0.2), Vector3(0, -0.12, 0.0), pants)
		box(thigh, Vector3(0.155, 0.22, 0.175), Vector3(0, -0.33, -0.005), pants)
		box(thigh, Vector3(0.05, 0.13, 0.13), Vector3(0.095 * side, -0.25, 0.0), pants.darkened(0.14))  # cargo pocket
		box(thigh, Vector3(0.052, 0.02, 0.135), Vector3(0.095 * side, -0.18, 0.0), pants.darkened(0.25))  # pocket flap
		if side == 1:
			box(thigh, Vector3(0.06, 0.17, 0.12), Vector3(0.115, -0.12, 0.02), POLY)  # holster
			box(thigh, Vector3(0.05, 0.05, 0.08), Vector3(0.115, -0.02, 0.02), GUNMETAL, 0.6)  # pistol grip
			box(thigh, Vector3(0.185, 0.03, 0.205), Vector3(0, -0.2, 0), strap)  # leg strap
		var shin := Node3D.new()
		shin.position.y = -0.44
		thigh.add_child(shin)
		box(shin, Vector3(0.145, 0.12, 0.165), Vector3(0, -0.03, 0.0), pants)  # knee
		box(shin, Vector3(0.14, 0.24, 0.15), Vector3(0, -0.19, 0.01), pants)
		box(shin, Vector3(0.12, 0.14, 0.05), Vector3(0, -0.15, 0.075), pants.darkened(0.04))  # calf
		box(shin, Vector3(0.13, 0.13, 0.05), Vector3(0, -0.04, -0.085), gear.darkened(0.25))  # knee pad
		box(shin, Vector3(0.135, 0.12, 0.155), Vector3(0, -0.3, 0.0), BOOT)  # boot shaft
		var foot := Node3D.new()
		foot.position.y = -0.36
		shin.add_child(foot)
		box(foot, Vector3(0.14, 0.09, 0.17), Vector3(0, -0.02, 0.0), BOOT)
		box(foot, Vector3(0.13, 0.07, 0.14), Vector3(0, -0.035, -0.13), BOOT)  # toe
		box(foot, Vector3(0.145, 0.03, 0.31), Vector3(0, -0.07, -0.06), BOOT.darkened(0.6))  # sole
		for i in 3:
			box(foot, Vector3(0.1, 0.01, 0.015), Vector3(0, 0.0 - i * 0.022, -0.087 - i * 0.012), BOOT.darkened(0.5))  # laces
		parts["thighs"].append(thigh)
		parts["shins"].append(shin)
		parts["feet"].append(foot)
	var torso := Node3D.new()
	hips.add_child(torso)
	box(torso, Vector3(0.33, 0.24, 0.2), Vector3(0, 0.14, 0), shirt)  # waist
	box(torso, Vector3(0.42, 0.3, 0.23), Vector3(0, 0.38, 0), shirt)  # chest
	box(torso, Vector3(0.46, 0.12, 0.21), Vector3(0, 0.52, 0), shirt)  # shoulder line
	box(torso, Vector3(0.28, 0.08, 0.15), Vector3(0, 0.6, 0.01), shirt)  # trapezius
	for side in [-1, 1]:
		box(torso, Vector3(0.14, 0.15, 0.17), Vector3(0.24 * side, 0.5, 0), shirt.darkened(0.06), 0.0, Vector3(0, 0, 0.25 * side))  # deltoid
	# Load-bearing gear: a plate carrier for the defenders, a chest rig or plate carrier for the attackers.
	var rig := team == "att" and rng.randf() < 0.5
	if rig:
		box(torso, Vector3(0.38, 0.17, 0.07), Vector3(0, 0.27, -0.12), gear)  # chest rig
		for i in 4:
			box(torso, Vector3(0.075, 0.15, 0.05), Vector3(-0.13 + i * 0.087, 0.28, -0.165), gear.darkened(0.18))  # long mags
			box(torso, Vector3(0.08, 0.035, 0.055), Vector3(-0.13 + i * 0.087, 0.35, -0.167), strap)
		for side in [-1, 1]:
			box(torso, Vector3(0.06, 0.04, 0.34), Vector3(0.14 * side, 0.52, 0.0), strap)  # harness
			box(torso, Vector3(0.05, 0.3, 0.04), Vector3(0.14 * side, 0.4, 0.11), strap)
	else:
		box(torso, Vector3(0.38, 0.3, 0.05), Vector3(0, 0.4, -0.135), gear)  # front plate
		box(torso, Vector3(0.38, 0.32, 0.05), Vector3(0, 0.4, 0.135), gear)  # back plate
		box(torso, Vector3(0.44, 0.13, 0.27), Vector3(0, 0.27, 0), gear.darkened(0.08))  # cummerbund
		for i in 3:
			var x := -0.12 + i * 0.12
			box(torso, Vector3(0.1, 0.13, 0.06), Vector3(x, 0.3, -0.18), gear.darkened(0.2))  # mag pouches
			box(torso, Vector3(0.1, 0.03, 0.065), Vector3(x, 0.36, -0.18), strap)
		box(torso, Vector3(0.1, 0.07, 0.04), Vector3(0.1, 0.49, -0.17), gear.darkened(0.15))  # admin pouch
		box(torso, Vector3(0.05, 0.1, 0.05), Vector3(-0.14, 0.5, -0.17), POLY)  # radio
		for side in [-1, 1]:
			box(torso, Vector3(0.08, 0.04, 0.3), Vector3(0.13 * side, 0.57, 0), strap)  # shoulder straps
		if team == "def" and rng.randf() < 0.5:
			box(torso, Vector3(0.24, 0.04, 0.02), Vector3(0, 0.46, -0.162), Color(0.85, 0.85, 0.8))  # patch
	box(torso, Vector3(0.36, 0.06, 0.24), Vector3(0, 0.03, 0), Color(0.1, 0.09, 0.08))  # belt
	box(torso, Vector3(0.06, 0.05, 0.03), Vector3(0, 0.03, -0.125), STEEL, 0.7)  # buckle
	for side in [-1, 1]:
		box(torso, Vector3(0.08, 0.1, 0.08), Vector3(0.18 * side, 0.02, 0.07), gear.darkened(0.15))  # belt pouches
	var pack := rng.randi() % 3 if team in ["att", "army"] else rng.randi() % 2 + 1
	match pack:
		0:
			box(torso, Vector3(0.34, 0.38, 0.15), Vector3(0, 0.36, 0.23), Color(0.36, 0.3, 0.2))  # backpack
			box(torso, Vector3(0.28, 0.12, 0.04), Vector3(0, 0.26, 0.32), Color(0.3, 0.25, 0.17))
			box(torso, Vector3(0.36, 0.06, 0.16), Vector3(0, 0.56, 0.23), Color(0.3, 0.25, 0.17))  # flap
		1:
			box(torso, Vector3(0.24, 0.3, 0.09), Vector3(0, 0.38, 0.2), gear.darkened(0.1))  # hydration pack
		2:
			box(torso, Vector3(0.1, 0.18, 0.07), Vector3(0.1, 0.45, 0.2), POLY)  # radio
			box(torso, Vector3(0.012, 0.32, 0.012), Vector3(0.13, 0.68, 0.2), POLY)  # antenna
	var head := Node3D.new()
	head.position.y = 0.64
	torso.add_child(head)
	_head(head, team, rng, skin, hair, colors[3], strap)
	var aim := Node3D.new()
	aim.position = Vector3(0, 0.5, 0)
	torso.add_child(aim)
	parts["torso"] = torso
	parts["head"] = head
	parts["aim"] = aim
	var rolled := rng.randf() < (0.4 if team in ["att", "army"] else (0.0 if team in ["rogue", "black"] else 0.2))
	parts["arm_color"] = [shirt, skin if rolled else shirt.darkened(0.04), GLOVE if rng.randf() < 0.8 else skin]
	for part in [hips, torso, head] + parts["thighs"] + parts["shins"] + parts["feet"]:
		merge(part)
	return parts


## A face under the headgear of `team`.
static func _head(head: Node3D, team: String, rng: RandomNumberGenerator, skin: Color, hair: Color, hat: Color, strap: Color) -> void:
	var eyes := Color(0.1, 0.08, 0.07)
	box(head, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.02, 0.005), skin.darkened(0.15))  # neck
	box(head, Vector3(0.19, 0.2, 0.21), Vector3(0, 0.16, 0.005), skin)  # skull
	box(head, Vector3(0.16, 0.07, 0.17), Vector3(0, 0.065, -0.012), skin)  # jaw
	box(head, Vector3(0.1, 0.04, 0.06), Vector3(0, 0.04, -0.075), skin)  # chin
	for side in [-1, 1]:
		box(head, Vector3(0.025, 0.06, 0.045), Vector3(0.1 * side, 0.15, 0.01), skin.darkened(0.08))  # ear
		box(head, Vector3(0.042, 0.02, 0.01), Vector3(0.043 * side, 0.165, -0.101), Color(0.92, 0.9, 0.86))  # eye white
		box(head, Vector3(0.018, 0.02, 0.012), Vector3(0.043 * side, 0.165, -0.102), eyes)  # iris
		box(head, Vector3(0.05, 0.013, 0.02), Vector3(0.043 * side, 0.188, -0.1), hair.darkened(0.2))  # brow
	box(head, Vector3(0.034, 0.055, 0.035), Vector3(0, 0.135, -0.115), skin.darkened(0.06))  # nose
	box(head, Vector3(0.06, 0.012, 0.01), Vector3(0, 0.085, -0.1), skin.darkened(0.35))  # mouth
	if rng.randf() < (0.55 if team == "att" else 0.3):
		box(head, Vector3(0.17, 0.07, 0.18), Vector3(0, 0.07, -0.02), hair)  # beard
		box(head, Vector3(0.07, 0.015, 0.01), Vector3(0, 0.1, -0.104), hair)  # moustache
	var style := rng.randi() % 3
	if team in ["rogue", "black", "army", "mercer"]:
		_campaign_head(head, team, style, rng, skin, hair, hat, strap)
		return
	if team == "att":
		match style:
			0:  # balaclava with the eyes showing
				box(head, Vector3(0.205, 0.235, 0.225), Vector3(0, 0.15, 0.005), hat)
				box(head, Vector3(0.14, 0.045, 0.02), Vector3(0, 0.165, -0.107), skin)
				for side in [-1, 1]:
					box(head, Vector3(0.042, 0.02, 0.01), Vector3(0.043 * side, 0.165, -0.117), Color(0.92, 0.9, 0.86))
					box(head, Vector3(0.018, 0.02, 0.012), Vector3(0.043 * side, 0.165, -0.118), eyes)
				box(head, Vector3(0.19, 0.06, 0.2), Vector3(0, 0.28, 0.01), hat.lightened(0.06))  # rolled top
			1:  # shemagh wound around the head and over the mouth
				var cloth := Color(0.62, 0.55, 0.42)
				box(head, Vector3(0.21, 0.09, 0.23), Vector3(0, 0.25, 0.005), cloth)
				box(head, Vector3(0.2, 0.09, 0.22), Vector3(0, 0.07, -0.005), cloth)
				box(head, Vector3(0.22, 0.03, 0.02), Vector3(0, 0.25, -0.115), cloth.darkened(0.3))
				box(head, Vector3(0.18, 0.2, 0.06), Vector3(0, 0.1, 0.11), cloth.darkened(0.1))  # tail
			_:  # beanie and sunglasses
				box(head, Vector3(0.205, 0.1, 0.225), Vector3(0, 0.25, 0.005), hat.lightened(0.12))
				box(head, Vector3(0.21, 0.03, 0.23), Vector3(0, 0.205, 0.005), hat.lightened(0.05))
				box(head, Vector3(0.17, 0.035, 0.015), Vector3(0, 0.165, -0.11), Color(0.05, 0.05, 0.06), 0.6)
		box(head, Vector3(0.22, 0.06, 0.2), Vector3(0, 0.0, 0.0), Color(0.35, 0.3, 0.22))  # scarf
	else:
		if style < 2:  # helmet
			box(head, Vector3(0.24, 0.1, 0.26), Vector3(0, 0.27, 0.01), hat)
			box(head, Vector3(0.2, 0.04, 0.22), Vector3(0, 0.33, 0.01), hat)
			box(head, Vector3(0.25, 0.04, 0.27), Vector3(0, 0.225, 0.01), hat.darkened(0.3))  # brim
			for side in [-1, 1]:
				box(head, Vector3(0.012, 0.03, 0.18), Vector3(0.125 * side, 0.27, 0.01), POLY)  # rails
				box(head, Vector3(0.045, 0.085, 0.085), Vector3(0.115 * side, 0.15, 0.0), POLY)  # headset
				box(head, Vector3(0.02, 0.12, 0.02), Vector3(0.1 * side, 0.08, -0.03), strap)  # chin strap
			if style == 0:
				box(head, Vector3(0.08, 0.05, 0.04), Vector3(0, 0.285, -0.13), POLY)  # night vision mount
				box(head, Vector3(0.05, 0.05, 0.06), Vector3(0, 0.26, -0.17), GUNMETAL, 0.4)
			else:
				box(head, Vector3(0.2, 0.05, 0.03), Vector3(0, 0.29, -0.12), Color(0.2, 0.22, 0.2))  # goggles
				box(head, Vector3(0.16, 0.035, 0.01), Vector3(0, 0.29, -0.136), Color(0.35, 0.45, 0.55), 0.8)
			box(head, Vector3(0.17, 0.035, 0.015), Vector3(0, 0.165, -0.11), Color(0.06, 0.06, 0.07), 0.6)  # glasses
		else:  # cap and headset
			box(head, Vector3(0.2, 0.07, 0.22), Vector3(0, 0.27, 0.005), hat)
			box(head, Vector3(0.18, 0.015, 0.1), Vector3(0, 0.24, -0.14), hat.darkened(0.2))  # visor
			box(head, Vector3(0.22, 0.02, 0.02), Vector3(0, 0.3, 0.0), POLY)  # headband
			for side in [-1, 1]:
				box(head, Vector3(0.045, 0.085, 0.085), Vector3(0.115 * side, 0.16, 0.0), POLY)
			box(head, Vector3(0.012, 0.012, 0.08), Vector3(0.08, 0.09, -0.08), POLY)  # boom mic
			box(head, Vector3(0.2, 0.05, 0.2), Vector3(0, 0.215, 0.02), hair)


## Headgear of the campaign's soldiers.
static func _campaign_head(head: Node3D, team: String, style: int, rng: RandomNumberGenerator, skin: Color, hair: Color, hat: Color, strap: Color) -> void:
	var helmet := func(color: Color) -> void:
		box(head, Vector3(0.24, 0.1, 0.26), Vector3(0, 0.27, 0.01), color)
		box(head, Vector3(0.2, 0.04, 0.22), Vector3(0, 0.33, 0.01), color)
		box(head, Vector3(0.25, 0.04, 0.27), Vector3(0, 0.225, 0.01), color.darkened(0.3))
		for side in [-1, 1]:
			box(head, Vector3(0.012, 0.03, 0.18), Vector3(0.125 * side, 0.27, 0.01), POLY)
			box(head, Vector3(0.02, 0.12, 0.02), Vector3(0.1 * side, 0.08, -0.03), strap)
	match team:
		"rogue":
			# The sector's security, still in their gas masks.
			helmet.call(hat)
			box(head, Vector3(0.17, 0.15, 0.04), Vector3(0, 0.12, -0.1), Color(0.16, 0.17, 0.16))  # face plate
			for side in [-1, 1]:
				var lens := cylinder(head, 0.028, 0.02, Vector3(0.042 * side, 0.165, -0.123), Color(0.05, 0.07, 0.07), Vector3(PI / 2.0, 0, 0))
				lens.material_override = _mat(Color(0.12, 0.18, 0.2), 0.8)
			cylinder(head, 0.035, 0.06, Vector3(0, 0.07, -0.14), Color(0.22, 0.24, 0.2), Vector3(PI / 2.0, 0, 0))  # filter
			box(head, Vector3(0.21, 0.03, 0.21), Vector3(0, 0.2, 0.0), Color(0.12, 0.12, 0.12))  # straps
		"black":
			# Black Division: balaclava, helmet and goggles; no face to see.
			box(head, Vector3(0.205, 0.235, 0.225), Vector3(0, 0.15, 0.005), hat)
			helmet.call(hat.lightened(0.05))
			box(head, Vector3(0.19, 0.05, 0.03), Vector3(0, 0.17, -0.11), Color(0.03, 0.03, 0.03), 0.6)  # goggles
			box(head, Vector3(0.16, 0.035, 0.01), Vector3(0, 0.17, -0.126), Color(0.15, 0.25, 0.2), 0.8)
			if style == 0:
				box(head, Vector3(0.08, 0.05, 0.04), Vector3(0, 0.285, -0.13), POLY)
				box(head, Vector3(0.1, 0.05, 0.07), Vector3(0, 0.26, -0.17), GUNMETAL, 0.4)
			for side in [-1, 1]:
				box(head, Vector3(0.045, 0.085, 0.085), Vector3(0.115 * side, 0.15, 0.0), POLY)
		"army":
			if style < 2:
				helmet.call(hat)
				box(head, Vector3(0.26, 0.05, 0.28), Vector3(0, 0.3, 0.01), hat.darkened(0.15))  # helmet cover band
			else:
				box(head, Vector3(0.28, 0.03, 0.3), Vector3(0, 0.23, 0.01), hat)  # boonie hat brim
				box(head, Vector3(0.2, 0.08, 0.22), Vector3(0, 0.27, 0.01), hat)
			if rng.randf() < 0.4:
				box(head, Vector3(0.17, 0.035, 0.015), Vector3(0, 0.165, -0.11), Color(0.06, 0.06, 0.07), 0.6)
		_:  # mercer: Black Division, faces showing
			if style == 2:
				box(head, Vector3(0.2, 0.07, 0.22), Vector3(0, 0.27, 0.005), hat)  # cap
				box(head, Vector3(0.18, 0.015, 0.1), Vector3(0, 0.24, -0.14), hat.darkened(0.2))
				box(head, Vector3(0.2, 0.05, 0.2), Vector3(0, 0.215, 0.02), hair)
			else:
				helmet.call(hat)
				box(head, Vector3(0.08, 0.05, 0.04), Vector3(0, 0.285, -0.13), POLY)
			for side in [-1, 1]:
				box(head, Vector3(0.045, 0.085, 0.085), Vector3(0.115 * side, 0.15, 0.0), POLY)
			box(head, Vector3(0.012, 0.012, 0.08), Vector3(0.08, 0.09, -0.08), POLY)  # boom mic


## A HELIX creature: an infected (a person in the clothes they died in, skin grey, eyes burning), a
## mutant (swollen and hunched, glowing growths, one arm a club) or the First (a soldier in a black
## suit with glowing seams). Returns the same parts as soldier().
static func creature(kind: String, look := 0) -> Dictionary:
	vm = false
	var rng := RandomNumberGenerator.new()
	rng.seed = look
	var first := kind == "first"
	var mutant := kind == "mutant"
	var shirts := [Color(0.82, 0.82, 0.8), Color(0.32, 0.45, 0.6), Color(0.45, 0.45, 0.47), Color(0.55, 0.2, 0.18),
			Color(0.36, 0.4, 0.44), Color(0.25, 0.4, 0.38), Color(0.88, 0.88, 0.9)]
	var shirt: Color = shirts[rng.randi() % shirts.size()]
	var pants: Color = [Color(0.22, 0.28, 0.42), Color(0.45, 0.4, 0.3), Color(0.2, 0.2, 0.22), Color(0.3, 0.33, 0.36)][rng.randi() % 4]
	var skin: Color = (SKINS[rng.randi() % SKINS.size()] as Color).lerp(Color(0.55, 0.57, 0.52), 0.55)
	if mutant:
		skin = Color(0.46, 0.4, 0.44)
		shirt = Color(0.75, 0.75, 0.72) if rng.randf() < 0.5 else UNIFORM["rogue"][0]
		pants = Color(0.25, 0.26, 0.28)
	if first:
		shirt = UNIFORM["first"][0]
		pants = UNIFORM["first"][2]
	var glow := FIRST_GLOW if first else HELIX_GLOW
	var torn := shirt.darkened(0.45)
	var root := Node3D.new()
	var hips := Node3D.new()
	hips.position.y = 0.9
	root.add_child(hips)
	var parts := {"root": root, "hips": hips, "thighs": [], "shins": [], "feet": []}
	box(hips, Vector3(0.33, 0.2, 0.21), Vector3.ZERO, pants)
	for side in [-1, 1]:
		var thigh := Node3D.new()
		thigh.position = Vector3(0.1 * side, -0.02, 0)
		hips.add_child(thigh)
		box(thigh, Vector3(0.17, 0.26, 0.19), Vector3(0, -0.12, 0), pants)
		box(thigh, Vector3(0.15, 0.22, 0.17), Vector3(0, -0.33, -0.005), pants)
		if not first and rng.randf() < 0.5:
			box(thigh, Vector3(0.155, 0.08, 0.175), Vector3(0, -0.36, -0.005), skin)  # torn trouser leg
		if first:
			_glow(thigh, Vector3(0.02, 0.4, 0.02), Vector3(0.087 * side, -0.22, 0), glow, 2.0)
		var shin := Node3D.new()
		shin.position.y = -0.44
		thigh.add_child(shin)
		box(shin, Vector3(0.14, 0.12, 0.16), Vector3(0, -0.03, 0), pants)
		box(shin, Vector3(0.135, 0.24, 0.145), Vector3(0, -0.19, 0.01), pants if first or rng.randf() < 0.6 else skin)
		box(shin, Vector3(0.13, 0.12, 0.15), Vector3(0, -0.3, 0), BOOT if first or mutant else pants.darkened(0.3))
		var foot := Node3D.new()
		foot.position.y = -0.36
		shin.add_child(foot)
		var shoe := BOOT if first else ([Color(0.15, 0.13, 0.12), Color(0.8, 0.8, 0.78), Color(0.2, 0.2, 0.25)][rng.randi() % 3] as Color)
		if not first and not mutant and rng.randf() < 0.25:
			shoe = skin  # barefoot
		box(foot, Vector3(0.13, 0.08, 0.16), Vector3(0, -0.025, 0), shoe)
		box(foot, Vector3(0.12, 0.06, 0.14), Vector3(0, -0.04, -0.12), shoe)
		box(foot, Vector3(0.135, 0.025, 0.29), Vector3(0, -0.07, -0.06), shoe.darkened(0.5))
		parts["thighs"].append(thigh)
		parts["shins"].append(shin)
		parts["feet"].append(foot)
	var torso := Node3D.new()
	hips.add_child(torso)
	box(torso, Vector3(0.32, 0.24, 0.2), Vector3(0, 0.14, 0), shirt)
	box(torso, Vector3(0.41, 0.3, 0.23), Vector3(0, 0.38, 0), shirt)
	box(torso, Vector3(0.45, 0.12, 0.21), Vector3(0, 0.52, 0), shirt)
	for side in [-1, 1]:
		box(torso, Vector3(0.14, 0.15, 0.17), Vector3(0.24 * side, 0.5, 0), shirt.darkened(0.06), 0.0, Vector3(0, 0, 0.25 * side))
	if first:
		box(torso, Vector3(0.36, 0.3, 0.05), Vector3(0, 0.4, -0.13), Color(0.1, 0.11, 0.12), 0.5)  # armour
		box(torso, Vector3(0.36, 0.32, 0.05), Vector3(0, 0.4, 0.13), Color(0.1, 0.11, 0.12), 0.5)
		_glow(torso, Vector3(0.02, 0.26, 0.02), Vector3(0, 0.4, -0.16), glow)
		for side in [-1, 1]:
			_glow(torso, Vector3(0.12, 0.015, 0.02), Vector3(0.11 * side, 0.46, -0.16), glow)
			_glow(torso, Vector3(0.015, 0.2, 0.02), Vector3(0.15 * side, 0.35, 0.16), glow)
		box(torso, Vector3(0.14, 0.2, 0.08), Vector3(0, 0.42, 0.19), Color(0.08, 0.08, 0.09), 0.5)  # core unit
		_glow(torso, Vector3(0.06, 0.06, 0.02), Vector3(0, 0.44, 0.235), glow, 5.0)
	else:
		# Rips in the clothes, stains, and HELIX growing out of the skin.
		for i in rng.randi_range(2, 5):
			box(torso, Vector3(rng.randf_range(0.05, 0.12), rng.randf_range(0.04, 0.1), 0.01),
					Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.15, 0.5), -0.116 if rng.randf() < 0.6 else 0.116), skin if rng.randf() < 0.5 else torn)
		box(torso, Vector3(0.2, 0.14, 0.01), Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(0.2, 0.4), -0.117), Color(0.3, 0.05, 0.04))  # blood
		for i in (6 if mutant else rng.randi_range(0, 2)):
			var at := Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.3, 0.6), 0.12 if mutant or rng.randf() < 0.5 else -0.12)
			var s := rng.randf_range(0.04, 0.09) * (1.8 if mutant else 1.0)
			box(torso, Vector3(s, s, s), at, skin.darkened(0.2))
			_glow(torso, Vector3(s, s, s) * 0.5, at + Vector3(0, 0, signf(at.z) * s * 0.4), glow, 2.5)
		if mutant:
			box(torso, Vector3(0.5, 0.2, 0.3), Vector3(0.06, 0.6, 0.06), skin.darkened(0.1))  # a hunched mass on the shoulders
			box(torso, Vector3(0.22, 0.18, 0.2), Vector3(0.2, 0.66, 0.08), skin.darkened(0.15))
	var head := Node3D.new()
	head.position.y = 0.64
	torso.add_child(head)
	box(head, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.02, 0.005), skin.darkened(0.15))
	if first:
		box(head, Vector3(0.22, 0.25, 0.24), Vector3(0, 0.16, 0.005), Color(0.08, 0.09, 0.1), 0.5)  # helmet
		box(head, Vector3(0.2, 0.06, 0.03), Vector3(0, 0.17, -0.118), Color(0.02, 0.02, 0.02), 0.8)
		_glow(head, Vector3(0.18, 0.025, 0.01), Vector3(0, 0.17, -0.135), glow, 5.0)  # visor
		box(head, Vector3(0.24, 0.04, 0.2), Vector3(0, 0.27, 0.02), Color(0.08, 0.09, 0.1), 0.5)
	else:
		box(head, Vector3(0.19, 0.2, 0.21), Vector3(0, 0.16, 0.005), skin)
		box(head, Vector3(0.16, 0.08 if not mutant else 0.12, 0.17), Vector3(0, 0.06 if not mutant else 0.03, -0.015), skin)  # jaw
		box(head, Vector3(0.1, 0.012, 0.012), Vector3(0, 0.07 if not mutant else 0.03, -0.1), Color(0.2, 0.04, 0.04))  # mouth
		box(head, Vector3(0.034, 0.05, 0.035), Vector3(0, 0.135, -0.115), skin.darkened(0.08))
		for side in [-1, 1]:
			box(head, Vector3(0.05, 0.035, 0.012), Vector3(0.043 * side, 0.165, -0.101), Color(0.05, 0.03, 0.03))  # sunken sockets
			_glow(head, Vector3(0.018, 0.014, 0.01), Vector3(0.043 * side, 0.165, -0.106), glow, 4.0)
			box(head, Vector3(0.025, 0.06, 0.045), Vector3(0.1 * side, 0.15, 0.01), skin.darkened(0.08))
		for i in 3:
			box(head, Vector3(0.012, rng.randf_range(0.05, 0.1), 0.006), Vector3(rng.randf_range(-0.08, 0.08), 0.13, -0.104), skin.darkened(0.35))  # dark veins
		if not mutant and rng.randf() < 0.7:
			var hair: Color = HAIR[rng.randi() % HAIR.size()]
			box(head, Vector3(0.2, 0.06, 0.22), Vector3(0.01, 0.27, 0.01), hair)
			box(head, Vector3(0.12, 0.08, 0.05), Vector3(-0.03, 0.22, 0.1), hair)
		if mutant:
			_glow(head, Vector3(0.06, 0.06, 0.06), Vector3(0.06, 0.26, 0.03), glow, 2.5)
	var aim := Node3D.new()
	aim.position = Vector3(0, 0.5, 0)
	torso.add_child(aim)
	parts["torso"] = torso
	parts["head"] = head
	parts["aim"] = aim
	var hand := GLOVE if first else skin
	parts["arm_color"] = [shirt, shirt if first or rng.randf() < 0.5 else skin, hand, "mutant" if mutant else ""]
	for part in [hips, torso, head] + parts["thighs"] + parts["shins"] + parts["feet"]:
		merge(part)
	return parts


## An arm from shoulder to hand, bent at the elbow, with a gloved hand closed around the grip.
static func _arm(parent: Node3D, shoulder: Vector3, hand: Vector3, colors: Array, side: float) -> void:
	var reach := shoulder.distance_to(hand)
	var bend := sqrt(maxf(0.3 * 0.3 - reach * reach / 4.0, 0.0))  # upper arm and forearm are 0.3 m each
	var elbow := (shoulder + hand) / 2.0 + Vector3(0.6 * side, -0.8, 0.2).normalized() * maxf(bend, 0.03)
	limb(parent, shoulder, elbow, 0.105, colors[0])
	var cuff := elbow.lerp(hand, 0.2)
	limb(parent, elbow, cuff, 0.1, colors[0].darkened(0.08))
	limb(parent, cuff, hand, 0.085, colors[1])
	box(parent, Vector3(0.1, 0.035, 0.1), elbow, colors[0].darkened(0.25))  # elbow pad
	box(parent, Vector3(0.08, 0.085, 0.1), hand, colors[2])
	box(parent, Vector3(0.03, 0.04, 0.06), hand + Vector3(-0.045 * side, 0.02, -0.02), colors[2])  # thumb


## Puts gun `id` in a soldier's hands (the "aim" pivot at the shoulders) and returns the gun; with no
## gun the arms hang down. `arm_colors` is [sleeve, forearm, hand].
static func arm_soldier(aim: Node3D, id: String, arm_colors: Array) -> Node3D:
	vm = false
	for child in aim.get_children():
		child.queue_free()
	if id == "":
		for side in [-1.0, 1.0]:
			_arm(aim, Vector3(0.23 * side, 0, 0.02), Vector3(0.27 * side, -0.55, -0.06), arm_colors, side)
		merge(aim)
		return null
	if _kind(id) == "claws":
		var club: bool = arm_colors.size() > 3 and arm_colors[3] == "mutant"
		for side in [-1.0, 1.0]:
			var hand := Vector3(0.2 * side, -0.2, -0.5)
			_arm(aim, Vector3(0.23 * side, 0, 0.02), hand, arm_colors, side)
			for i in 3:
				box(aim, Vector3(0.015, 0.015, 0.09), hand + Vector3((i - 1) * 0.025, -0.02, -0.07), Color(0.2, 0.18, 0.15), 0.0, Vector3(-0.4, 0, 0))  # claws
			if club and side > 0:
				limb(aim, Vector3(0.24, -0.05, -0.1), hand + Vector3(0, -0.05, -0.1), 0.2, (arm_colors[2] as Color).darkened(0.1))
				box(aim, Vector3(0.24, 0.22, 0.26), hand + Vector3(0.02, -0.06, -0.2), (arm_colors[2] as Color).darkened(0.2))
				for i in 4:
					box(aim, Vector3(0.03, 0.03, 0.14), hand + Vector3(-0.08 + i * 0.05, 0.08, -0.26), Color(0.85, 0.8, 0.7), 0.0, Vector3(-0.8, 0, 0))  # bone spurs
				_glow(aim, Vector3(0.08, 0.08, 0.08), hand + Vector3(0.1, 0.0, -0.15), HELIX_GLOW, 2.5)
		var claws := gun(id)
		claws.position = Vector3(0, -0.2, -0.3)
		aim.add_child(claws)
		merge(aim)
		return claws
	var g := gun(id)
	var grip := Vector3(0.1, -0.12, -0.38)
	if _kind(id) in ["pistol", "magnum", "knife", "he", "flash", "smoke", "bomb"]:
		grip = Vector3(0.06, -0.08, -0.48)
	g.position = grip
	aim.add_child(g)
	var holds := hands(id)
	_arm(aim, Vector3(0.23, 0, 0.02), grip + holds[0], arm_colors, 1.0)
	_arm(aim, Vector3(-0.23, 0, 0.02), grip + holds[1], arm_colors, -1.0)
	merge(g)
	merge(aim)
	return g


## Merges the plain parts directly under `node` into one mesh with the colors in its vertices, so a
## soldier is drawn in a handful of calls instead of hundreds. Markers and moving parts stay as they
## are; so do glowing and see-through parts.
static func merge(node: Node3D) -> void:
	var tools := {}  # metalness -> SurfaceTool
	for child in node.get_children():
		var part := child as MeshInstance3D
		if part == null or part.get_child_count() > 0 or not part.material_override is StandardMaterial3D:
			continue
		var mat := part.material_override as StandardMaterial3D
		if mat.emission_enabled or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var key := snappedf(mat.metallic, 0.1)
		if not tools.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = tool
		var st: SurfaceTool = tools[key]
		var arrays := part.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var xf := part.transform
		st.set_color(mat.albedo_color)
		for i: int in arrays[Mesh.ARRAY_INDEX]:
			st.set_normal((xf.basis * normals[i]).normalized())
			st.add_vertex(xf * verts[i])
		node.remove_child(part)
		part.queue_free()
	if tools.is_empty():
		return
	var mesh := ArrayMesh.new()
	for key: float in tools:
		(tools[key] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Tex.painted(key))
	var body := MeshInstance3D.new()
	body.mesh = mesh
	node.add_child(body)


## A gloved hand closed around a grip at `at`: palm, four fingers wrapped in front, and a thumb.
static func _hand(parent: Node3D, at: Vector3, sleeve: Color, forearm_from: Vector3, left: bool) -> void:
	limb(parent, forearm_from, at + Vector3(0, -0.02, 0.07), 0.075, sleeve)
	var cuff := forearm_from.lerp(at, 0.72)
	limb(parent, cuff, at + Vector3(0, -0.02, 0.07), 0.08, sleeve.darkened(0.25))  # rolled cuff
	box(parent, Vector3(0.06, 0.075, 0.09), at + Vector3(0, -0.01, 0.02), GLOVE)
	var side := -1.0 if left else 1.0
	for i in 4:
		box(parent, Vector3(0.022, 0.02, 0.05), at + Vector3(-0.034 * side, 0.02 - i * 0.022, 0.0), GLOVE.lightened(0.08))
		box(parent, Vector3(0.02, 0.02, 0.022), at + Vector3(-0.034 * side + 0.012 * side, 0.02 - i * 0.022, -0.028), GLOVE.lightened(0.14))
	box(parent, Vector3(0.022, 0.022, 0.06), at + Vector3(0.028 * side, 0.03, -0.01), GLOVE.lightened(0.1))  # thumb
	if not left:
		box(parent, Vector3(0.078, 0.02, 0.03), at + Vector3(0, -0.02, 0.11), Color(0.1, 0.1, 0.1))  # watch strap
		box(parent, Vector3(0.03, 0.012, 0.03), at + Vector3(0.035, -0.02, 0.11), Color(0.2, 0.25, 0.22), 0.6)


## The first-person view of gun `id`: the gun with the arms holding it, for a camera looking down -Z.
static func viewmodel(id: String, team: String) -> Node3D:
	vm = true
	var root := Node3D.new()
	var g := gun(id)
	g.name = "Gun"
	root.add_child(g)
	var holds := hands(id)
	var sleeve: Color = UNIFORM[team][0]
	_hand(root, holds[0], sleeve, Vector3(0.07, -0.3, 0.34), false)
	if not _kind(id) in ["knife", "he", "flash", "smoke", "bomb"]:
		_hand(root, holds[1], sleeve, Vector3(-0.2, -0.32, 0.25), true)
	vm = false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
