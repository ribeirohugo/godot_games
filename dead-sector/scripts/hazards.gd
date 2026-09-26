extends Node3D
## What the collapsing facility throws at everyone in it. Each hazard sits on a cell of the map and
## hurts whoever stands in it while it is active; all of them warn first, so they can be timed.
##
##   steam    a vent that hisses, then blasts a scalding column for a moment
##   arc      a broken conduit that crackles, then throws lightning at the floor around it
##   gas      a cloud of toxic gas: a steady drain (none with a gas mask)
##   fire     burning wreckage or fuel: flames, light and smoke
##   sparks   a torn cable spitting sparks (harmless, for the look and the sound)
##
## Also: debris falling in an area for a while (a shadow shows where), and floors that crack and
## fall away (anyone standing there falls to their death).

const Tex := preload("res://scripts/textures.gd")
const Models := preload("res://scripts/models.gd")

const SPECS := {
	"steam": {"period": 3.4, "warn": 0.7, "active": 1.3, "radius": 1.3, "damage": 24.0},
	"arc": {"period": 2.8, "warn": 0.6, "active": 0.55, "radius": 1.7, "damage": 40.0},
	"gas": {"period": 1.0, "warn": 0.0, "active": 1.0, "radius": 1.5, "damage": 7.0},
	"fire": {"period": 1.0, "warn": 0.0, "active": 1.0, "radius": 1.0, "damage": 18.0},
	"sparks": {"period": 2.2, "warn": 0.0, "active": 0.2, "radius": 0.0, "damage": 0.0},
}

var world
var rules
var game
var list: Array = []  # {kind, pos, id, on, t, node, light, flames}
var drops: Array = []  # {pos, t, node, shadow}
var zones: Array = []  # {pos, radius, until, next}
var cracks: Array = []  # {cells, t, nodes}
var bolt: MeshInstance3D


func setup(world_ref, rules_ref, game_ref) -> void:
	world = world_ref
	rules = rules_ref
	game = game_ref


func add(kind: String, pos: Vector3, id: String, on: bool) -> void:
	var h := {"kind": kind, "pos": pos, "id": id, "on": on, "t": randf() * SPECS[kind]["period"], "node": null, "light": null, "flames": []}
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	h["node"] = node
	match kind:
		"steam":
			Models.box(node, Vector3(0.9, 0.12, 0.9), Vector3(0, 0.06, 0), Color(0.25, 0.26, 0.27), 0.5)
			for i in 4:
				Models.box(node, Vector3(0.8, 0.03, 0.08), Vector3(0, 0.13, -0.3 + i * 0.2), Color(0.08, 0.08, 0.08))
		"arc":
			Models.box(node, Vector3(0.6, 2.4, 0.6), Vector3(0, 1.2, 0), Color(0.3, 0.31, 0.3), 0.6)
			Models.box(node, Vector3(0.8, 0.2, 0.8), Vector3(0, 2.5, 0), Color(0.75, 0.6, 0.1))
			var light := OmniLight3D.new()
			light.light_color = Color(0.6, 0.8, 1.0)
			light.light_energy = 0.0
			light.omni_range = 8.0
			light.position = Vector3(0, 2.0, 0)
			node.add_child(light)
			h["light"] = light
		"fire":
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.55, 0.2)
			light.light_energy = 2.2
			light.omni_range = 9.0
			light.shadow_enabled = false
			light.position = Vector3(0, 1.0, 0)
			node.add_child(light)
			h["light"] = light
			for i in 5:
				var flame := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = Vector3(0.35, 0.8, 0.35)
				flame.mesh = mesh
				flame.material_override = Tex.flat(Color(1.0, 0.45 + i * 0.08, 0.1), 5.0)
				flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				flame.position = Vector3(randf_range(-0.4, 0.4), 0.4, randf_range(-0.4, 0.4))
				node.add_child(flame)
				h["flames"].append(flame)
		"sparks":
			var light := OmniLight3D.new()
			light.light_color = Color(0.7, 0.85, 1.0)
			light.light_energy = 0.0
			light.omni_range = 5.0
			light.position = Vector3(0, 0.5, 0)
			node.add_child(light)
			h["light"] = light
	list.append(h)
	_show(h)


func set_on(id: String, on: bool) -> void:
	for h: Dictionary in list:
		if h["id"] == id:
			h["on"] = on
			_show(h)


func _show(h: Dictionary) -> void:
	for flame in h["flames"]:
		flame.visible = h["on"]
	if h["kind"] == "fire" and h["light"] != null:
		h["light"].visible = h["on"]


## Debris falls around `pos` (within `radius` m) for `seconds`.
func debris(pos: Vector3, radius: float, seconds: float) -> void:
	zones.append({"pos": pos, "radius": radius, "until": seconds, "next": 0.3})


## The floor of these cells cracks, rumbles, then falls away.
func collapse(cells: Array) -> void:
	var nodes: Array = []
	for c: Vector2i in cells:
		var crack := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(world.CELL * 0.9, 0.01, 0.06)
		crack.mesh = mesh
		crack.material_override = Tex.flat(Color(0.03, 0.03, 0.03))
		crack.position = world.center(c, 0.012)
		crack.rotation.y = randf() * PI
		add_child(crack)
		nodes.append(crack)
	cracks.append({"cells": cells, "t": 1.6, "nodes": nodes})
	game.sfx.play("rumble" if game.sfx.sounds.has("rumble") else "explode", -2.0)
	game.shake(0.4)


func _physics_process(delta: float) -> void:
	for h: Dictionary in list:
		if h["on"]:
			_run(h, delta)
	_run_debris(delta)
	_run_cracks(delta)
	# Standing over a hole: a long fall.
	for s in rules.soldiers:
		if s.alive and world.pits.has(world.cell_of(s.position)) and s.position.y < 0.3:
			s.take_blast(999.0, null, "fall")


func _run(h: Dictionary, delta: float) -> void:
	var spec: Dictionary = SPECS[h["kind"]]
	h["t"] = fmod(h["t"] + delta, spec["period"])
	var t: float = h["t"]
	var pos: Vector3 = h["pos"]
	var warn: bool = t < spec["warn"]
	var hot: bool = t >= spec["warn"] and t < spec["warn"] + spec["active"]
	var just: bool = hot and t - delta < spec["warn"]
	match h["kind"]:
		"steam":
			if warn and randf() < 0.3:
				world.puff(pos + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3)), Color(0.9, 0.9, 0.9, 0.3), 0.3, 0.6, 1.0)
			if just:
				game.sfx.play_at("steam" if game.sfx.sounds.has("steam") else "smoke", pos, 0.0)
			if hot:
				for i in 2:
					world.puff(pos + Vector3(randf_range(-0.2, 0.2), randf_range(0.2, 2.8), randf_range(-0.2, 0.2)), Color(0.95, 0.95, 0.95, 0.55), 1.3, 0.8, 2.5)
		"arc":
			var light: OmniLight3D = h["light"]
			light.light_energy = (randf() * 1.5 if warn else 0.0) + (7.0 * randf() if hot else 0.0)
			if warn and randf() < 0.2:
				world.burst(pos + Vector3(0, 2.4, 0), Color(0.7, 0.85, 1.0), 2, 3.0, 0.02, 5.0)
			if hot:
				_bolt(pos + Vector3(0, 2.4, 0), pos + Vector3(randf_range(-1.4, 1.4), 0.05, randf_range(-1.4, 1.4)))
			if just:
				game.sfx.play_at("zap" if game.sfx.sounds.has("zap") else "flashbang", pos + Vector3.UP * 2.0, -2.0)
		"gas":
			if randf() < delta * 6.0:
				world.puff(pos + Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.4), randf_range(-1.0, 1.0)), Color(0.45, 0.65, 0.2, 0.35), 2.2, 2.5, 0.15)
		"fire":
			for flame: MeshInstance3D in h["flames"]:
				flame.scale = Vector3(1.0, randf_range(0.6, 1.5), 1.0)
				flame.position.y = flame.scale.y * 0.4
			(h["light"] as OmniLight3D).light_energy = randf_range(1.6, 2.6)
			if randf() < delta * 3.0:
				world.puff(pos + Vector3(randf_range(-0.3, 0.3), 1.6, randf_range(-0.3, 0.3)), Color(0.12, 0.11, 0.1, 0.5), 1.2, 2.5, 1.5)
			if randf() < delta * 2.0:
				world.burst(pos + Vector3(0, 0.8, 0), Color(1.0, 0.6, 0.2), 2, 3.0, 0.03, 4.0)
		"sparks":
			var light: OmniLight3D = h["light"]
			light.light_energy = 4.0 if hot else 0.0
			if just:
				world.burst(pos + Vector3(0, 0.5, 0), Color(1.0, 0.85, 0.5), 8, 4.0, 0.02, 5.0)
				game.sfx.play_at("zap" if game.sfx.sounds.has("zap") else "impact", pos, -12.0)
	if not hot or spec["damage"] <= 0.0:
		return
	for s in rules.soldiers:
		if not s.alive:
			continue
		var d := Vector2(s.position.x - pos.x, s.position.z - pos.z).length()
		if d < spec["radius"] and s.position.y < 3.0:
			if h["kind"] == "gas" and s == rules.human and rules.has_mask:
				continue
			s.take_blast(spec["damage"] * delta, null, h["kind"])


## A jagged bolt of light between a and b, gone in a moment.
func _bolt(a: Vector3, b: Vector3) -> void:
	var points := [a]
	for i in range(1, 5):
		var k := i / 5.0
		points.append(a.lerp(b, k) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)))
	points.append(b)
	for i in points.size() - 1:
		var p: Vector3 = points[i]
		var q: Vector3 = points[i + 1]
		var seg := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.05, 0.05, p.distance_to(q))
		seg.mesh = mesh
		seg.material_override = Tex.flat(Color(0.8, 0.9, 1.0), 8.0)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(seg)
		seg.look_at_from_position((p + q) / 2.0, q, Vector3.UP if absf((q - p).normalized().y) < 0.95 else Vector3.BACK)
		world.flashes.append([seg, 0.06, 0.06, 0.0])


func _run_debris(delta: float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var z: Dictionary = zones[i]
		z["until"] -= delta
		z["next"] -= delta
		if z["until"] <= 0.0:
			zones.remove_at(i)
			continue
		if z["next"] <= 0.0:
			z["next"] = randf_range(0.25, 0.7)
			var p: Vector3 = z["pos"] + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf() * z["radius"]
			if world.is_solid(world.cell_of(p)):
				continue
			# Sometimes right on top of the player, so standing still is never safe.
			if randf() < 0.3 and rules.human.alive and rules.human.position.distance_to(z["pos"]) < z["radius"]:
				p = rules.human.position + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
			var shadow := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 1.0
			disc.bottom_radius = 1.0
			disc.height = 0.01
			shadow.mesh = disc
			shadow.material_override = Tex.fading(Color(0, 0, 0, 0.0))
			shadow.position = Vector3(p.x, 0.02, p.z)
			add_child(shadow)
			var chunk := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(randf_range(0.6, 1.3), randf_range(0.4, 0.9), randf_range(0.6, 1.3))
			chunk.mesh = box
			chunk.material_override = Tex.surface(world.data["wall"], 2.0, Color(0.8, 0.8, 0.8), true)
			chunk.position = Vector3(p.x, 9.0, p.z)
			chunk.rotation = Vector3(randf(), randf(), randf())
			chunk.visible = false
			add_child(chunk)
			drops.append({"pos": p, "t": 0.9, "node": chunk, "shadow": shadow, "fall": 0.0})
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		d["t"] -= delta
		var shadow: MeshInstance3D = d["shadow"]
		(shadow.material_override as StandardMaterial3D).albedo_color.a = clampf(1.0 - d["t"] / 0.9, 0.0, 0.7)
		if d["t"] > 0.35:
			continue
		var chunk: MeshInstance3D = d["node"]
		chunk.visible = true
		d["fall"] += delta * 30.0
		chunk.position.y -= d["fall"] * delta * 3.0
		chunk.rotation.x += delta * 4.0
		if chunk.position.y <= 0.3:
			var p: Vector3 = d["pos"]
			world.burst(p + Vector3.UP * 0.3, Color(0.5, 0.48, 0.45), 10, 6.0, 0.12)
			world.puff(p + Vector3.UP * 0.5, Color(0.55, 0.52, 0.48, 0.5), 2.0, 1.2, 0.5)
			game.sfx.play_at("impact", p, 4.0)
			for s in rules.soldiers:
				if s.alive and Vector2(s.position.x - p.x, s.position.z - p.z).length() < 1.5:
					s.take_blast(45.0, null, "debris")
			if rules.human.position.distance_to(p) < 12.0:
				game.shake(0.3)
			chunk.position.y = 0.3
			shadow.queue_free()
			drops.remove_at(i)
			# The chunk stays where it fell, as rubble.


func _run_cracks(delta: float) -> void:
	for i in range(cracks.size() - 1, -1, -1):
		var c: Dictionary = cracks[i]
		c["t"] -= delta
		if randf() < delta * 8.0:
			var cells: Array = c["cells"]
			var at: Vector3 = world.center(cells[randi() % cells.size()])
			world.puff(at + Vector3(0, 0.2, 0), Color(0.5, 0.48, 0.45, 0.4), 0.8, 0.8, 0.4)
		if c["t"] > 0.0:
			continue
		for node in c["nodes"]:
			node.queue_free()
		for cell: Vector2i in c["cells"]:
			world.add_pit(cell)
			var hole := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(world.CELL, 0.02, world.CELL)
			hole.mesh = box
			var black := StandardMaterial3D.new()
			black.albedo_color = Color(0.0, 0.0, 0.0)
			black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			hole.material_override = black
			hole.position = world.center(cell, 0.012)
			add_child(hole)
			world.burst(world.center(cell, 0.2), Color(0.45, 0.43, 0.4), 6, 5.0, 0.2)
		game.sfx.play("explode", -4.0)
		game.shake(0.6)
		cracks.remove_at(i)
