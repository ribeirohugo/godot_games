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

## Clothes of each side: shirt, vest, trousers, headgear.
const UNIFORM := {
	"att": [Color(0.55, 0.47, 0.33), Color(0.29, 0.27, 0.21), Color(0.42, 0.37, 0.27), Color(0.07, 0.07, 0.07)],
	"def": [Color(0.20, 0.25, 0.33), Color(0.11, 0.13, 0.17), Color(0.22, 0.25, 0.30), Color(0.15, 0.18, 0.23)],
}

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
		"knife":
			box(g, Vector3(0.028, 0.032, 0.11), Vector3(0, 0, 0.02), POLY)
			box(g, Vector3(0.05, 0.036, 0.012), Vector3(0, 0, -0.04), GUNMETAL, 0.6)
			box(g, Vector3(0.006, 0.032, 0.17), Vector3(0, 0.004, -0.13), STEEL, 0.9)
			box(g, Vector3(0.006, 0.012, 0.06), Vector3(0, 0.02, -0.19), STEEL.lightened(0.2), 0.9, Vector3(0.35, 0, 0))
			_muzzle(g, -0.2, 0.0)
		"p18", "k45", "m25", "magnum":
			var big := id == "magnum"
			var slide := STEEL if big else (TAN.darkened(0.3) if id == "m25" else GUNMETAL)
			var length := 0.26 if big else (0.2 if id == "k45" else 0.18)
			box(g, Vector3(0.036, 0.046, length) * (1.15 if big else 1.0), Vector3(0, 0.045, -length / 2.0 + 0.04), slide, 0.7)
			box(g, Vector3(0.03, 0.028, length * 0.8), Vector3(0, 0.012, -length * 0.4 + 0.04), POLY)
			box(g, Vector3(0.032, 0.11, 0.05), Vector3(0, -0.04, 0.02), POLY, 0.0, Vector3(0.25, 0, 0))
			box(g, Vector3(0.006, 0.03, 0.035), Vector3(0, -0.005, -0.03), POLY)
			if id == "k45":
				cylinder(g, 0.016, 0.12, Vector3(0, 0.045, -0.21), POLY, Vector3(PI / 2.0, 0, 0))  # suppressor
				_muzzle(g, -0.28, 0.045)
			else:
				_muzzle(g, -length + 0.02, 0.045)
		"mx9", "u45":
			var body := GUNMETAL if id == "mx9" else POLY
			box(g, Vector3(0.05, 0.075, 0.3), Vector3(0, 0.035, -0.1), body, 0.3)
			box(g, Vector3(0.024, 0.024, 0.12), Vector3(0, 0.05, -0.3), GUNMETAL, 0.6)
			box(g, Vector3(0.03, 0.16 if id == "mx9" else 0.13, 0.045), Vector3(0, -0.08, -0.13), POLY, 0.0, Vector3(-0.1 if id == "u45" else 0.0, 0, 0))
			box(g, Vector3(0.032, 0.1, 0.045), Vector3(0, -0.04, 0.02), POLY, 0.0, Vector3(0.25, 0, 0))
			box(g, Vector3(0.02, 0.05, 0.2), Vector3(0, 0.03, 0.15), POLY)
			box(g, Vector3(0.02, 0.02, 0.05), Vector3(0, 0.08, -0.05), POLY)
			_muzzle(g, -0.36, 0.05)
		"pump":
			box(g, Vector3(0.036, 0.036, 0.62), Vector3(0, 0.055, -0.36), GUNMETAL, 0.7)
			box(g, Vector3(0.03, 0.03, 0.46), Vector3(0, 0.018, -0.3), GUNMETAL, 0.5)
			box(g, Vector3(0.052, 0.05, 0.15), Vector3(0, 0.02, -0.34), WOOD)
			box(g, Vector3(0.05, 0.075, 0.2), Vector3(0, 0.035, -0.02), GUNMETAL, 0.5)
			box(g, Vector3(0.032, 0.1, 0.045), Vector3(0, -0.04, 0.05), WOOD, 0.0, Vector3(0.35, 0, 0))
			box(g, Vector3(0.045, 0.09, 0.3), Vector3(0, -0.01, 0.22), WOOD, 0.0, Vector3(0.12, 0, 0))
			_muzzle(g, -0.68, 0.055)
		"ar7", "viper":
			var furniture := WOOD if id == "ar7" else POLY
			box(g, Vector3(0.05, 0.08, 0.34), Vector3(0, 0.035, -0.08), GUNMETAL, 0.5)
			box(g, Vector3(0.022, 0.022, 0.38), Vector3(0, 0.05, -0.44), GUNMETAL, 0.6)
			box(g, Vector3(0.052, 0.056, 0.2), Vector3(0, 0.035, -0.34), furniture)
			box(g, Vector3(0.012, 0.05, 0.012), Vector3(0, 0.08, -0.6), GUNMETAL)
			box(g, Vector3(0.034, 0.12, 0.06), Vector3(0, -0.07, -0.15), GUNMETAL if id == "ar7" else OLIVE, 0.3, Vector3(-0.3, 0, 0))
			box(g, Vector3(0.034, 0.1, 0.06), Vector3(0, -0.16, -0.1), GUNMETAL if id == "ar7" else OLIVE, 0.3, Vector3(-0.65, 0, 0))
			box(g, Vector3(0.032, 0.1, 0.045), Vector3(0, -0.04, 0.03), POLY, 0.0, Vector3(0.3, 0, 0))
			box(g, Vector3(0.045, 0.09, 0.3), Vector3(0, -0.005, 0.24), furniture, 0.0, Vector3(0.1, 0, 0))
			_muzzle(g, -0.64, 0.05)
		"m4", "f90":
			var color := POLY if id == "m4" else TAN
			box(g, Vector3(0.05, 0.08, 0.34), Vector3(0, 0.035, -0.08), color, 0.2)
			box(g, Vector3(0.03, 0.02, 0.3), Vector3(0, 0.085, -0.1), POLY)
			box(g, Vector3(0.056, 0.062, 0.24), Vector3(0, 0.035, -0.36), color, 0.2)
			box(g, Vector3(0.02, 0.02, 0.2), Vector3(0, 0.045, -0.55), GUNMETAL, 0.6)
			box(g, Vector3(0.032, 0.15, 0.06), Vector3(0, -0.09, -0.14), POLY, 0.2, Vector3(-0.12, 0, 0))
			box(g, Vector3(0.032, 0.1, 0.045), Vector3(0, -0.04, 0.03), POLY, 0.0, Vector3(0.3, 0, 0))
			box(g, Vector3(0.04, 0.08, 0.22), Vector3(0, 0.0, 0.22), color)
			box(g, Vector3(0.03, 0.05, 0.08), Vector3(0, 0.12, -0.06), GUNMETAL)  # sight
			_muzzle(g, -0.66, 0.045)
		"scout", "longbow":
			var awp := id == "longbow"
			var color := OLIVE if awp else POLY
			box(g, Vector3(0.05, 0.07, 0.4), Vector3(0, 0.03, -0.12), color)
			box(g, Vector3(0.024, 0.024, 0.5 if awp else 0.42), Vector3(0, 0.045, -0.55 if awp else -0.5), GUNMETAL, 0.6)
			cylinder(g, 0.028 if awp else 0.022, 0.32, Vector3(0, 0.12, -0.12), POLY, Vector3(PI / 2.0, 0, 0))
			cylinder(g, 0.036 if awp else 0.03, 0.05, Vector3(0, 0.12, -0.3), POLY, Vector3(PI / 2.0, 0, 0))
			box(g, Vector3(0.01, 0.05, 0.02), Vector3(0, 0.085, -0.12), POLY)
			box(g, Vector3(0.032, 0.1, 0.045), Vector3(0, -0.04, 0.04), color, 0.0, Vector3(0.3, 0, 0))
			box(g, Vector3(0.048, 0.1 if awp else 0.08, 0.32), Vector3(0, -0.01, 0.24), color)
			box(g, Vector3(0.03, 0.08, 0.08), Vector3(0, -0.05, -0.12), POLY)
			_muzzle(g, -0.82 if awp else -0.72, 0.045)
		"he":
			var shell := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.04
			sphere.height = 0.09
			shell.mesh = sphere
			shell.material_override = _mat(OLIVE)
			g.add_child(shell)
			box(g, Vector3(0.02, 0.03, 0.02), Vector3(0, 0.05, 0), GUNMETAL, 0.6)
			box(g, Vector3(0.012, 0.07, 0.01), Vector3(0.02, 0.02, 0), GUNMETAL, 0.6)
			_muzzle(g, 0.0, 0.0)
		"flash", "smoke":
			cylinder(g, 0.028, 0.11, Vector3.ZERO, Color(0.8, 0.8, 0.78) if id == "flash" else Color(0.35, 0.38, 0.35))
			cylinder(g, 0.029, 0.02, Vector3(0, 0.02, 0), Color(0.2, 0.3, 0.8) if id == "flash" else Color(0.7, 0.7, 0.7))
			box(g, Vector3(0.02, 0.03, 0.02), Vector3(0, 0.065, 0), GUNMETAL, 0.6)
			_muzzle(g, 0.0, 0.0)
		"bomb":
			bomb_model(g)
			_muzzle(g, 0.0, 0.0)
	return g


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
		"smg":
			return [Vector3(0, -0.03, 0.02), Vector3(0, -0.02, -0.26)]
	return [Vector3(0, -0.03, 0.03), Vector3(0, 0.0, -0.36)]


static func _kind(id: String) -> String:
	return Weapons.LIST[id]["kind"] if Weapons.LIST.has(id) else "knife"


# --- Soldiers ------------------------------------------------------------------------------

## A soldier of `team`: returns its moving parts by name (root, hips, thighs, shins, torso, head, aim).
static func soldier(team: String) -> Dictionary:
	vm = false
	var colors: Array = UNIFORM[team]
	var root := Node3D.new()
	var hips := Node3D.new()
	hips.position.y = 0.9
	root.add_child(hips)
	var parts := {"root": root, "hips": hips, "thighs": [], "shins": []}
	for side in [-1, 1]:
		var thigh := Node3D.new()
		thigh.position = Vector3(0.11 * side, 0, 0)
		hips.add_child(thigh)
		box(thigh, Vector3(0.16, 0.47, 0.18), Vector3(0, -0.22, 0), colors[2])
		var shin := Node3D.new()
		shin.position.y = -0.45
		thigh.add_child(shin)
		box(shin, Vector3(0.14, 0.42, 0.15), Vector3(0, -0.2, 0), colors[2])
		box(shin, Vector3(0.15, 0.09, 0.27), Vector3(0, -0.41, -0.04), Color(0.12, 0.1, 0.08))
		parts["thighs"].append(thigh)
		parts["shins"].append(shin)
	var torso := Node3D.new()
	hips.add_child(torso)
	box(torso, Vector3(0.44, 0.58, 0.25), Vector3(0, 0.3, 0), colors[0])
	box(torso, Vector3(0.47, 0.38, 0.31), Vector3(0, 0.34, 0), colors[1])
	box(torso, Vector3(0.12, 0.1, 0.05), Vector3(-0.12, 0.28, -0.17), colors[1].darkened(0.3))
	box(torso, Vector3(0.12, 0.1, 0.05), Vector3(0.12, 0.28, -0.17), colors[1].darkened(0.3))
	box(torso, Vector3(0.46, 0.07, 0.27), Vector3(0, 0.03, 0), Color(0.1, 0.09, 0.08))
	var head := Node3D.new()
	head.position.y = 0.64
	torso.add_child(head)
	box(head, Vector3(0.1, 0.08, 0.1), Vector3(0, 0.02, 0), SKIN.darkened(0.15))
	if team == "att":
		box(head, Vector3(0.22, 0.26, 0.24), Vector3(0, 0.16, 0), colors[3])
		box(head, Vector3(0.18, 0.05, 0.02), Vector3(0, 0.19, -0.12), SKIN)
		box(head, Vector3(0.04, 0.025, 0.01), Vector3(-0.045, 0.19, -0.13), Color(0.1, 0.07, 0.05))
		box(head, Vector3(0.04, 0.025, 0.01), Vector3(0.045, 0.19, -0.13), Color(0.1, 0.07, 0.05))
	else:
		box(head, Vector3(0.21, 0.24, 0.23), Vector3(0, 0.15, 0), SKIN)
		box(head, Vector3(0.26, 0.12, 0.28), Vector3(0, 0.27, 0.01), colors[3])
		box(head, Vector3(0.27, 0.04, 0.29), Vector3(0, 0.22, 0.01), colors[3].darkened(0.3))
		box(head, Vector3(0.17, 0.05, 0.02), Vector3(0, 0.17, -0.12), Color(0.08, 0.08, 0.09), 0.5)
	var aim := Node3D.new()
	aim.position = Vector3(0, 0.5, 0)
	torso.add_child(aim)
	parts["torso"] = torso
	parts["head"] = head
	parts["aim"] = aim
	parts["arm_color"] = colors[0]
	return parts


## Puts gun `id` in a soldier's hands (the "aim" pivot at the shoulders); returns the gun.
static func arm_soldier(aim: Node3D, id: String, arm_color: Color) -> Node3D:
	vm = false
	for child in aim.get_children():
		child.queue_free()
	var g := gun(id)
	var grip := Vector3(0.1, -0.12, -0.38)
	if _kind(id) in ["pistol", "magnum", "knife", "he", "flash", "smoke", "bomb"]:
		grip = Vector3(0.06, -0.08, -0.48)
	g.position = grip
	aim.add_child(g)
	var holds := hands(id)
	var right: Vector3 = grip + holds[0]
	var left: Vector3 = grip + holds[1]
	limb(aim, Vector3(0.22, 0, 0.02), right, 0.1, arm_color)
	limb(aim, Vector3(-0.22, 0, 0.02), left, 0.1, arm_color)
	box(aim, Vector3(0.08, 0.08, 0.08), right, GLOVE)
	box(aim, Vector3(0.08, 0.08, 0.08), left, GLOVE)
	return g


## The first-person view of gun `id`: the gun with the arms holding it, for a camera looking down -Z.
static func viewmodel(id: String, team: String) -> Node3D:
	vm = true
	var root := Node3D.new()
	var g := gun(id)
	g.name = "Gun"
	root.add_child(g)
	var holds := hands(id)
	var sleeve: Color = UNIFORM[team][0]
	var right: Vector3 = holds[0]
	var left: Vector3 = holds[1]
	limb(root, Vector3(0.07, -0.3, 0.32), right, 0.07, sleeve)
	box(root, Vector3(0.07, 0.07, 0.09), right, GLOVE)
	if not _kind(id) in ["knife", "he", "flash", "smoke", "bomb"]:
		limb(root, Vector3(-0.2, -0.32, 0.25), left, 0.07, sleeve)
		box(root, Vector3(0.07, 0.07, 0.09), left, GLOVE)
	vm = false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
