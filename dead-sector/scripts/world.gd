extends Node3D
## The map: builds it from its ASCII grid (see maps.gd) and answers questions about it (paths, sight
## lines, bomb sites). It also runs everything that lives on the map rather than in a soldier: bullet
## traces and their marks, dropped weapons, grenades, smoke clouds, explosions and small effects.
##
## Campaign maps add a "legend" that gives more characters a meaning: other walls ({"solid": "wall"}),
## other waist-high cover ({"solid": "low"}), glass walls ({"solid": "glass"}), floors ({"floor": kind}),
## water ({"water": true}) and props that fill their cell ({"block": height}). Every other legend
## character is plain floor here; the mission (mission.gd) puts its things there. Doors shut cells
## (set_blocked) and floors can fall away (add_pit) while playing.

const Tex := preload("res://scripts/textures.gd")
const Models := preload("res://scripts/models.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Maps := preload("res://scripts/maps.gd")
const DressingScript := preload("res://scripts/dressing.gd")

const CELL := Maps.CELL
const SOLID := "#cC-o"
const CRATE := 1.1  # height of one crate
const GRAVITY := 20.0

# Physics layers.
const LAYER_WORLD := 1
const LAYER_ATT := 2  # attackers' bodies: they block the other side, not their own
const LAYER_DEF := 4
const LAYER_HIT := 8  # hitboxes, only for shots
const LAYER_X := 16  # a third side in the campaign: the HELIX creatures


static func team_layer(team: String) -> int:
	return {"att": LAYER_ATT, "def": LAYER_DEF}.get(team, LAYER_X)


## A body bumps into the world and into every side but its own.
static func team_mask(team: String) -> int:
	return LAYER_WORLD | ((LAYER_ATT | LAYER_DEF | LAYER_X) & ~team_layer(team))

var game  # main.gd
var rules  # rules.gd
var data: Dictionary
var rows := PackedStringArray()
var width := 0
var depth := 0
var wall_height := 6.0
var astar := AStarGrid2D.new()
var spawns := {"att": [], "def": []}
var sites := {}  # "a" / "b" -> Rect2i of cells
var roofs: Array = []  # [Rect2i, height]
var hold_spots := {}  # site -> cells next to cover, the ones deepest in the site (for attackers) first
var legend := {}  # map character -> its meaning (campaign maps)
var walls := {}  # character -> legend entry, for walls other than "#"
var lows := {}  # character -> legend entry, for waist-high cover other than "-"
var glass := {}  # characters that are glass walls
var water := {}  # cells under shallow water
var props := {}  # cell -> height of the prop that fills it
var blocked := {}  # cells shut by a closed door
var pits := {}  # cells whose floor has fallen away

var drops: Array[Node3D] = []
var grenades: Array = []  # {node, vel, kind, owner, t, still}
var smokes: Array = []  # {pos, radius, t, node, puffs}
var particles: Array = []  # [MeshInstance3D, velocity, life left, life]
var flashes: Array = []  # [Node3D, life left, life, grow]
var marks: Array[Node3D] = []  # bullet holes, oldest first
var shells: Array = []  # [MeshInstance3D, velocity, life left, bounced]
var puffs: Array = []  # [MeshInstance3D, life left, life, size, rise]
var shell_mesh: CylinderMesh
var hole_mesh: QuadMesh
var hole_mat: StandardMaterial3D


func build(game_ref, rules_ref, map_data: Dictionary) -> void:
	game = game_ref
	rules = rules_ref
	data = map_data
	rows = PackedStringArray(data["map"])
	depth = rows.size()
	for row in rows:
		width = maxi(width, row.length())
	wall_height = data["wall_height"]
	sites = data.get("sites", {})
	roofs = data.get("roofs", []).duplicate()
	if data.has("roofed"):
		roofs.append([Rect2i(0, 0, width, depth), data["roofed"]])
	legend = data.get("legend", {})
	for ch: String in legend:
		var entry: Dictionary = legend[ch]
		match entry.get("solid", ""):
			"wall":
				walls[ch] = entry
			"low":
				lows[ch] = entry
			"glass":
				glass[ch] = entry
	for z in depth:
		for x in rows[z].length():
			var entry: Dictionary = legend.get(rows[z][x], {})
			if entry.get("water", false):
				water[Vector2i(x, z)] = true
			if entry.has("block"):
				props[Vector2i(x, z)] = float(entry["block"])
	# Interiors: legend characters with a "roof" height get a roof, merged into rectangles.
	var under := {}  # height -> {cell: true}
	for z in depth:
		for x in rows[z].length():
			var entry: Dictionary = legend.get(rows[z][x], {})
			if entry.has("roof"):
				var h: float = entry["roof"]
				if not under.has(h):
					under[h] = {}
				under[h][Vector2i(x, z)] = true
	for h: float in under:
		roofs.append_array(_rectangles(under[h], h))
	hole_mesh = QuadMesh.new()
	hole_mesh.size = Vector2(0.09, 0.09)
	hole_mat = Tex.flat(Color(0.06, 0.05, 0.04))
	shell_mesh = CylinderMesh.new()
	shell_mesh.top_radius = 0.005
	shell_mesh.bottom_radius = 0.006
	shell_mesh.height = 0.03
	shell_mesh.radial_segments = 6
	shell_mesh.rings = 1
	_environment()
	_build_level()
	_build_nav()
	for z in depth:
		for x in rows[z].length():
			if rows[z][x] == "1":
				spawns["att"].append(center(Vector2i(x, z)))
			elif rows[z][x] == "2":
				spawns["def"].append(center(Vector2i(x, z)))
	_find_hold_spots()


# --- Map queries ---------------------------------------------------------------------------

func char_at(c: Vector2i) -> String:
	if c.y < 0 or c.y >= depth or c.x < 0 or c.x >= rows[c.y].length():
		return "#"
	return rows[c.y][c.x]


func is_solid(c: Vector2i) -> bool:
	var ch := char_at(c)
	return SOLID.contains(ch) or walls.has(ch) or lows.has(ch) or glass.has(ch) or props.has(c) or blocked.has(c)


## True for full-height walls of any kind (and outside the map).
func is_wall(c: Vector2i) -> bool:
	var ch := char_at(c)
	return ch == "#" or walls.has(ch) or glass.has(ch)


func _is_wall_char(ch: String) -> bool:
	return ch == "#" or walls.has(ch)


## How fast one can move at p: wading through water is slow.
func slow_at(p: Vector3) -> float:
	return 0.62 if water.has(cell_of(p)) else 1.0


## Shuts or opens cell c for walking (doors).
func set_blocked(c: Vector2i, on: bool) -> void:
	if on:
		blocked[c] = true
	else:
		blocked.erase(c)
	if astar.is_in_boundsv(c):
		astar.set_point_solid(c, is_solid(c) or pits.has(c))


## The floor of cell c falls away: nobody can walk there any more.
func add_pit(c: Vector2i) -> void:
	pits[c] = true
	if astar.is_in_boundsv(c):
		astar.set_point_solid(c, true)


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func center(c: Vector2i, y := 0.0) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, y, (c.y + 0.5) * CELL)


## Height of the ground at p: crate tops count, so dropped things can land on them.
func ground_at(p: Vector3) -> float:
	var c := cell_of(p)
	match char_at(c):
		"c", "-":
			return CRATE
		"C":
			return CRATE * 2.0
	if lows.has(char_at(c)):
		return CRATE
	return props.get(c, 0.0)


## The bomb site p stands in, or "".
func site_at(p: Vector3) -> String:
	var c := cell_of(p)
	for key: String in sites:
		if (sites[key] as Rect2i).has_point(c):
			return key
	return ""


func site_center(key: String) -> Vector3:
	var r: Rect2i = sites[key]
	return Vector3((r.position.x + r.size.x / 2.0) * CELL, 0.0, (r.position.y + r.size.y / 2.0) * CELL)


## A random open cell of a bomb site, as a point on the floor.
func random_site_point(key: String) -> Vector3:
	var r: Rect2i = sites[key]
	for i in 40:
		var c := Vector2i(randi_range(r.position.x, r.end.x - 1), randi_range(r.position.y, r.end.y - 1))
		if not is_solid(c):
			return center(c)
	return site_center(key)


## A defender's post: a cell beside cover, towards the back of the site as seen from the attackers.
func defend_point(key: String) -> Vector3:
	var spots: Array = hold_spots.get(key, [])
	if spots.is_empty():
		return random_site_point(key)
	var pick: int = randi() % maxi(1, int(spots.size() * 0.6))
	return center(spots[pick])


func _find_hold_spots() -> void:
	var from := cell_of(_spawn_middle("att"))
	for key: String in sites:
		var r: Rect2i = sites[key]
		var scored: Array = []
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if is_solid(c):
					continue
				var cover := 0
				for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
					if is_solid(c + d):
						cover += 1
				if cover == 0 or cover > 2:
					continue
				scored.append([astar.get_id_path(from, c).size(), c])
		scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var cells: Array = []
		for entry: Array in scored:
			cells.append(entry[1])
		hold_spots[key] = cells


func _spawn_middle(team: String) -> Vector3:
	var sum := Vector3.ZERO
	for p: Vector3 in spawns[team]:
		sum += p
	return sum / maxf(spawns[team].size(), 1.0)


## A random open cell within `radius` cells of p.
func random_point_near(p: Vector3, radius: int) -> Vector3:
	var home := cell_of(p)
	for i in 40:
		var c := home + Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
		if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
			return center(c)
	return center(home)


## True when no wall, crate or roof stands between a and b.
func clear_line(a: Vector3, b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a, b, LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## True when a smoke cloud hides b from a.
func smoke_between(a: Vector3, b: Vector3) -> bool:
	for smoke: Dictionary in smokes:
		if smoke["t"] < 0.8:
			continue
		var c: Vector3 = smoke["pos"]
		var r: float = smoke["radius"] * 0.85
		var ab := b - a
		var k := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if (a + ab * k).distance_to(c) < r:
			return true
	return false


## A walking path from a to b, as points on the floor (the start is left out).
func find_path(a: Vector3, b: Vector3) -> PackedVector3Array:
	var from := _open_cell(cell_of(a))
	var to := _open_cell(cell_of(b))
	var points := PackedVector3Array()
	if from == to:
		points.append(Vector3(b.x, 0, b.z))
		return points
	var ids := astar.get_id_path(from, to)
	for i in range(1, ids.size()):
		points.append(center(ids[i]))
	if points.size() > 0 and not is_solid(cell_of(b)):
		points[points.size() - 1] = Vector3(b.x, 0, b.z)
	return points


## c, or the nearest cell next to it that a bot can walk (when standing on a crate).
func _open_cell(c: Vector2i) -> Vector2i:
	if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
		return c
	for r in range(1, 4):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dz)
				if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
					return n
	return c


## True when a bot can walk straight from a to b without bumping into anything.
func walk_clear(a: Vector3, b: Vector3) -> bool:
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := flat.length()
	if length < 0.01:
		return true
	var side := Vector3(-flat.z, 0, flat.x) / length * 0.45
	var steps := ceili(length / 0.4)
	for i in range(1, steps + 1):
		var p := a + flat * (float(i) / steps)
		for offset: Vector3 in [Vector3.ZERO, side, -side]:
			var c := cell_of(p + offset)
			if not astar.is_in_boundsv(c) or astar.is_point_solid(c):
				return false
	return true


# --- Shots ---------------------------------------------------------------------------------

## Follows a bullet from `from` along `dir`; returns {pos, normal, target, group} or {} for nothing.
## Hitboxes of `shooter`'s own side are passed through (no friendly fire).
func trace(shooter, from: Vector3, dir: Vector3, length: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for area: Area3D in shooter.hitboxes:
		exclude.append(area.get_rid())
	for i in 12:
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * length, LAYER_WORLD | LAYER_HIT, exclude)
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider = hit["collider"]
		if collider is Area3D:
			var target = collider.get_meta("soldier")
			if target.team == shooter.team or not target.alive:
				exclude.append(collider.get_rid())
				continue
			return {"pos": hit["position"], "normal": hit["normal"], "target": target, "group": collider.get_meta("group")}
		return {"pos": hit["position"], "normal": hit["normal"], "target": null, "group": ""}
	return {}


## A bullet from `shooter`: traces it, deals damage and draws the tracer and the mark it leaves.
func fire_bullet(shooter, from: Vector3, dir: Vector3, weapon: Dictionary, id: String, muzzle: Vector3, draw_tracer: bool) -> void:
	var hit := trace(shooter, from, dir, 160.0)
	var end: Vector3 = from + dir * 160.0 if hit.is_empty() else hit["pos"]
	if draw_tracer:
		tracer(muzzle, end)
	if hit.is_empty():
		return
	var target = hit["target"]
	if target != null:
		var dist := from.distance_to(end)
		var damage: float = weapon["damage"] * pow(weapon.get("falloff", 1.0), dist / 12.7)
		target.take_hit(damage, hit["group"], shooter, id, dir, weapon.get("pen", 0.5))
		var blood: Color = target.blood
		burst(end, blood, 5, 2.5, 0.05, 3.0 if blood.v > 0.8 else 0.0)
	else:
		mark(end, hit["normal"])
		var n: Vector3 = hit["normal"]
		burst(end + n * 0.05, Color(0.45, 0.4, 0.33), 3, 2.0, 0.04)
		burst(end + n * 0.03, Color(1.0, 0.8, 0.45), 2, 5.0, 0.015, 5.0)
		puff(end + n * 0.1, Color(0.6, 0.55, 0.47, 0.5), 0.25, 0.5, 0.3)
		if randf() < 0.25:
			game.sfx.play_at("ricochet", end, -6.0)
		else:
			game.sfx.play_at("impact", end, -4.0)


func tracer(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 1.0:
		return
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, minf(length, 12.0))
	line.mesh = mesh
	line.material_override = Tex.fading(Color(1.0, 0.9, 0.55, 0.55))
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	var dir := (b - a) / length
	# A short streak, somewhere along the bullet's path.
	var along := randf_range(1.0, maxf(length - 6.0, 1.0))
	line.transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.BACK), a + dir * along)
	flashes.append([line, 0.05, 0.05, 0.0])


func mark(pos: Vector3, normal: Vector3) -> void:
	var hole := MeshInstance3D.new()
	hole.mesh = hole_mesh
	hole.material_override = hole_mat
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hole)
	var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.BACK
	hole.transform = Transform3D(Basis.looking_at(-normal, up), pos + normal * 0.01)
	hole.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	marks.append(hole)
	if marks.size() > 120:
		marks.pop_front().queue_free()


## A spent case flying out of the ejection port.
func eject_shell(pos: Vector3, vel: Vector3) -> void:
	var shell := MeshInstance3D.new()
	shell.mesh = shell_mesh
	shell.material_override = Tex.flat(Color(0.85, 0.65, 0.3), 0.0, 0.8)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.position = pos
	shell.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	add_child(shell)
	shells.append([shell, vel, 2.5, false])
	if shells.size() > 50:
		shells.pop_front()[0].queue_free()


## A soft cloud that grows, rises and fades: gun smoke, dust.
func puff(pos: Vector3, color: Color, size: float, life: float, rise: float) -> void:
	var cloud := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	cloud.mesh = sphere
	cloud.material_override = Tex.fading(color)
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud.position = pos
	cloud.scale = Vector3.ONE * size * 0.3
	add_child(cloud)
	puffs.append([cloud, life, life, size, rise])


func muzzle_flash(pos: Vector3, size := 1.0) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07 * size
	sphere.height = 0.14 * size
	sphere.radial_segments = 6
	sphere.rings = 3
	flash.mesh = sphere
	flash.material_override = Tex.flat(Color(1.0, 0.8, 0.4), 4.0)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = pos
	add_child(flash)
	flashes.append([flash, 0.04, 0.04, 0.0])


## Little cubes flying out of pos: blood, dust or sparks.
func burst(pos: Vector3, color: Color, count: int, speed: float, size: float, glow := 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var mat := Tex.flat(color, glow)
	for i in count:
		var bit := MeshInstance3D.new()
		bit.mesh = mesh
		bit.material_override = mat
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bit.position = pos
		add_child(bit)
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.2), randf_range(-1, 1)).normalized()
		var life := randf_range(0.25, 0.6)
		particles.append([bit, dir * speed * randf_range(0.4, 1.0), life, life])


func explosion(pos: Vector3, size: float) -> void:
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	ball.mesh = sphere
	ball.material_override = Tex.fading(Color(1.0, 0.7, 0.3, 0.9))
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.position = pos
	ball.scale = Vector3.ONE * 0.1
	add_child(ball)
	flashes.append([ball, 0.35, 0.35, size])
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 6.0
	light.omni_range = size * 4.0
	light.position = pos + Vector3.UP * 0.5
	add_child(light)
	flashes.append([light, 0.3, 0.3, 0.0])
	burst(pos, Color(1.0, 0.6, 0.2), 16, 10.0, 0.1, 3.0)
	burst(pos, Color(0.2, 0.18, 0.16), 12, 7.0, 0.14)


# --- Dropped weapons -----------------------------------------------------------------------

## Drops weapon `id` (with its rounds) from pos, thrown along vel.
func drop(id: String, mag: int, reserve: int, pos: Vector3, vel: Vector3) -> Node3D:
	var root := Node3D.new()
	root.set_meta("id", id)
	root.set_meta("mag", mag)
	root.set_meta("reserve", reserve)
	root.set_meta("vel", vel)
	root.set_meta("age", 0.0)
	var model := Models.gun(id)
	model.rotation = Vector3(0, 0, PI / 2.0)
	if id == "bomb":
		model.rotation = Vector3.ZERO
	root.add_child(model)
	root.position = pos
	add_child(root)
	drops.append(root)
	return root


func remove_drop(drop_node: Node3D) -> void:
	drops.erase(drop_node)
	drop_node.queue_free()


func clear_round() -> void:
	for d in drops:
		d.queue_free()
	drops.clear()
	for g: Dictionary in grenades:
		g["node"].queue_free()
	grenades.clear()
	for s: Dictionary in smokes:
		s["node"].queue_free()
	smokes.clear()
	for m in marks:
		m.queue_free()
	marks.clear()


func _update_drops(delta: float) -> void:
	for d in drops:
		var vel: Vector3 = d.get_meta("vel")
		d.set_meta("age", d.get_meta("age") + delta)
		if vel == Vector3.ZERO:
			continue
		vel.y -= GRAVITY * delta
		var next: Vector3 = d.position + vel * delta
		if is_solid(cell_of(next)) and next.y < ground_at(next) - 0.05 or is_wall(cell_of(next)) or char_at(cell_of(next)) == "o":
			next.x = d.position.x
			next.z = d.position.z
			vel.x = 0.0
			vel.z = 0.0
		var floor_y := ground_at(next) + 0.04
		if next.y <= floor_y:
			next.y = floor_y
			vel = Vector3.ZERO
		d.position = next
		d.set_meta("vel", vel)


# --- Grenades ------------------------------------------------------------------------------

func throw_grenade(owner, kind: String, pos: Vector3, vel: Vector3) -> void:
	var node := Models.gun(kind)
	node.position = pos
	add_child(node)
	grenades.append({"node": node, "vel": vel, "kind": kind, "owner": owner, "t": 0.0, "still": 0.0})


func _update_grenades(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for i in range(grenades.size() - 1, -1, -1):
		var g: Dictionary = grenades[i]
		var node: Node3D = g["node"]
		g["t"] += delta
		var vel: Vector3 = g["vel"]
		vel.y -= GRAVITY * 0.6 * delta
		var from := node.position
		var to := from + vel * delta
		var query := PhysicsRayQueryParameters3D.create(from, to + vel.normalized() * 0.05, LAYER_WORLD)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			vel = vel.bounce(n) * 0.45
			to = hit["position"] + n * 0.06
			if vel.length() > 1.5:
				game.sfx.play_at("bounce", to, -4.0)
		node.position = to
		node.rotation += Vector3(vel.z, 0, -vel.x) * delta * 2.0
		g["vel"] = vel
		g["still"] = g["still"] + delta if vel.length() < 0.5 else 0.0
		var kind: String = g["kind"]
		var boom: bool = g["t"] >= 1.6 if kind != "smoke" else (g["t"] > 1.2 and g["still"] > 0.3) or g["t"] > 4.0
		if boom:
			grenades.remove_at(i)
			node.queue_free()
			_detonate(kind, to + Vector3.UP * 0.1, g["owner"])


func _detonate(kind: String, pos: Vector3, owner) -> void:
	match kind:
		"he":
			explosion(pos, 1.6)
			game.sfx.play_at("explode", pos)
			rules.blast(pos, 8.0, 98.0, owner, "he")
			noise(pos, 50.0, owner)
		"flash":
			var light := OmniLight3D.new()
			light.light_energy = 12.0
			light.omni_range = 14.0
			light.position = pos
			add_child(light)
			flashes.append([light, 0.15, 0.15, 0.0])
			game.sfx.play_at("flashbang", pos)
			rules.flashbang(pos)
			noise(pos, 40.0, owner)
		"smoke":
			_smoke(pos)
			game.sfx.play_at("smoke", pos)


func _smoke(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.0, pos.z)
	add_child(root)
	var puffs: Array = []
	for i in 22:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = randf_range(1.4, 2.1)
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		puff.mesh = sphere
		var shade := randf_range(0.6, 0.72)
		puff.material_override = Tex.fading(Color(shade, shade, shade * 1.02, 0.0))
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := randf() * TAU
		var r := randf_range(0.0, 2.3)
		puff.position = Vector3(cos(a) * r, randf_range(0.8, 2.6), sin(a) * r)
		puff.scale = Vector3.ONE * 0.2
		root.add_child(puff)
		puffs.append(puff)
	smokes.append({"pos": Vector3(pos.x, 1.4, pos.z), "radius": 3.6, "t": 0.0, "node": root, "puffs": puffs})


func _update_smokes(delta: float) -> void:
	for i in range(smokes.size() - 1, -1, -1):
		var s: Dictionary = smokes[i]
		s["t"] += delta
		var t: float = s["t"]
		var grow := clampf(t / 1.5, 0.0, 1.0)
		var fade := clampf((18.0 - t) / 2.5, 0.0, 1.0)
		for puff: MeshInstance3D in s["puffs"]:
			puff.scale = Vector3.ONE * (0.2 + 0.8 * sqrt(grow))
			(puff.material_override as StandardMaterial3D).albedo_color.a = 0.9 * grow * fade
		if t >= 18.0:
			s["node"].queue_free()
			smokes.remove_at(i)


## A sound bots can hear: gunshots, footsteps, explosions.
func noise(pos: Vector3, radius: float, source) -> void:
	rules.on_noise(pos, radius, source)


# --- Running -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_drops(delta)
	_update_grenades(delta)
	_update_smokes(delta)


func _process(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Array = particles[i]
		var bit: MeshInstance3D = p[0]
		p[2] -= delta
		if p[2] <= 0.0:
			bit.queue_free()
			particles.remove_at(i)
			continue
		var v: Vector3 = p[1]
		v.y -= 12.0 * delta
		bit.position += v * delta
		if bit.position.y < 0.02:
			bit.position.y = 0.02
			v = Vector3.ZERO
		p[1] = v
		bit.scale = Vector3.ONE * (p[2] / p[3])
	for i in range(shells.size() - 1, -1, -1):
		var sh: Array = shells[i]
		var node: MeshInstance3D = sh[0]
		sh[2] -= delta
		if sh[2] <= 0.0:
			node.queue_free()
			shells.remove_at(i)
			continue
		var v: Vector3 = sh[1]
		if v == Vector3.ZERO:
			continue
		v.y -= GRAVITY * 0.7 * delta
		node.position += v * delta
		node.rotation.x += delta * 25.0
		var floor_y := ground_at(node.position) + 0.006
		if node.position.y < floor_y:
			node.position.y = floor_y
			if not sh[3]:
				sh[3] = true
				game.sfx.play_at("shell", node.position, -14.0)
				v = Vector3(v.x * 0.35, -v.y * 0.3, v.z * 0.35)
			else:
				v = Vector3.ZERO
				node.rotation.x = PI / 2.0
		sh[1] = v
	for i in range(puffs.size() - 1, -1, -1):
		var pf: Array = puffs[i]
		var cloud: MeshInstance3D = pf[0]
		pf[1] -= delta
		if pf[1] <= 0.0:
			cloud.queue_free()
			puffs.remove_at(i)
			continue
		var k: float = 1.0 - pf[1] / pf[2]
		cloud.scale = Vector3.ONE * pf[3] * (0.3 + 0.7 * sqrt(k))
		cloud.position.y += pf[4] * delta
		var mat := cloud.material_override as StandardMaterial3D
		mat.albedo_color.a = (1.0 - k) * 0.5
	for i in range(flashes.size() - 1, -1, -1):
		var f: Array = flashes[i]
		var node: Node3D = f[0]
		f[1] -= delta
		if f[1] <= 0.0:
			node.queue_free()
			flashes.remove_at(i)
			continue
		var k: float = 1.0 - f[1] / f[2]
		if node is OmniLight3D:
			(node as OmniLight3D).light_energy *= 0.85
		elif f[3] > 0.0:
			node.scale = Vector3.ONE * f[3] * (0.3 + 0.9 * sqrt(k))
			var mat := (node as MeshInstance3D).material_override as StandardMaterial3D
			mat.albedo_color.a = 0.9 * (1.0 - k)


# --- Building ------------------------------------------------------------------------------

func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = data["sky"]
	sky_mat.sky_horizon_color = data["horizon"]
	sky_mat.ground_bottom_color = data["ground"]
	sky_mat.ground_horizon_color = data["horizon"]
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.08
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = data.get("ambient", 0.7)
	if data.has("ambient_color"):
		# Night and indoors: a set fill light, so the dark stays readable.
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = data["ambient_color"]
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = data.get("exposure", 1.0)
	env.tonemap_white = 6.0
	# Contact shadows in corners and under crates, and a soft bloom on bright things.
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_detail = 0.6
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.glow_enabled = true
	env.glow_intensity = data.get("glow", 0.35)
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.08
	env.fog_enabled = true
	env.fog_light_color = data.get("fog_color", data["horizon"])
	env.fog_density = data.get("fog", 0.0035)
	env.fog_sky_affect = data.get("fog_sky", 0.0)
	if data.has("haze"):
		# Volumetric fog: light shafts from lamps and fires in the dark.
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = data["haze"]
		env.volumetric_fog_albedo = data.get("haze_color", Color(0.8, 0.8, 0.85))
		env.volumetric_fog_length = 48.0
		env.volumetric_fog_ambient_inject = 0.3
	if water.size() > 0:
		env.ssr_enabled = true
		env.ssr_max_steps = 48
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = data["sun"]
	sun.light_color = data["sun_color"]
	sun.light_energy = data.get("sun_energy", 1.35)
	sun.shadow_enabled = sun.light_energy > 0.05
	sun.shadow_blur = 0.8
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)


## Collects boxes by material, then builds one mesh per material and one static body for them all.
func _build_level() -> void:
	var boxes := {}  # material key -> [[center, size], ...]
	var add_box := func(key: String, c: Vector3, s: Vector3) -> void:
		if not boxes.has(key):
			boxes[key] = []
		boxes[key].append([c, s])
	# Walls: runs of wall cells along each row that touch an open cell.
	for z in depth:
		var x := 0
		while x < width:
			var ch := char_at(Vector2i(x, z))
			if _is_wall_char(ch) and _exposed(Vector2i(x, z)):
				var start := x
				while x + 1 < width and char_at(Vector2i(x + 1, z)) == ch and _exposed(Vector2i(x + 1, z)):
					x += 1
				var length := (x - start + 1) * CELL
				var h: float = walls[ch].get("height", wall_height) if walls.has(ch) else wall_height
				var key := "wall" if ch == "#" else "wall:" + ch
				add_box.call(key, Vector3(start * CELL + length / 2.0, h / 2.0, (z + 0.5) * CELL), Vector3(length, h, CELL))
			x += 1
	var crates: Array = []
	for z in depth:
		for x in rows[z].length():
			var c := Vector2i(x, z)
			match rows[z][x]:
				"c":
					crates.append([center(c, CRATE / 2.0), Vector3(1.8, CRATE, 1.8), 0.0])
				"C":
					crates.append([center(c, CRATE / 2.0), Vector3(1.8, CRATE, 1.8), 0.0])
					crates.append([center(c, CRATE * 1.5), Vector3(1.8, CRATE, 1.8), randf_range(-0.12, 0.12)])
				"-":
					var along_x := char_at(c + Vector2i(1, 0)) == "-" or char_at(c + Vector2i(-1, 0)) == "-"
					var size := Vector3(CELL, CRATE, 1.0) if along_x else Vector3(1.0, CRATE, CELL)
					if char_at(c + Vector2i(1, 0)) != "-" and char_at(c + Vector2i(-1, 0)) != "-" and char_at(c + Vector2i(0, 1)) != "-" and char_at(c + Vector2i(0, -1)) != "-":
						size = Vector3(1.6, CRATE, 1.6)
					add_box.call("low", center(c, CRATE / 2.0), size)
				"o":
					add_box.call("pillar", center(c, wall_height / 2.0), Vector3(1.0, wall_height, 1.0))
				_:
					var ch := rows[z][x]
					if lows.has(ch):
						var along := char_at(c + Vector2i(1, 0)) == ch or char_at(c + Vector2i(-1, 0)) == ch
						var lone := not along and char_at(c + Vector2i(0, 1)) != ch and char_at(c + Vector2i(0, -1)) != ch
						var size := Vector3(CELL, CRATE, 1.0) if along else Vector3(1.0, CRATE, CELL)
						if lone:
							size = Vector3(1.6, CRATE, 1.6)
						add_box.call("low:" + ch, center(c, CRATE / 2.0), size)
					elif glass.has(ch):
						var h: float = glass[ch].get("height", wall_height)
						var along := glass.has(char_at(c + Vector2i(1, 0))) or glass.has(char_at(c + Vector2i(-1, 0)))
						var pane := Vector3(CELL, h - 0.3, 0.1) if along else Vector3(0.1, h - 0.3, CELL)
						add_box.call("glass", center(c, 0.15 + (h - 0.3) / 2.0), pane)
						var sill := Vector3(CELL, 0.3, 0.3) if along else Vector3(0.3, 0.3, CELL)
						add_box.call("frame", center(c, 0.15), sill)
						add_box.call("frame", center(c, h - 0.1), Vector3(sill.x, 0.2, sill.z))
	var roofed := {}
	for roof: Array in roofs:
		var r: Rect2i = roof[0]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				roofed[Vector2i(x, y)] = roof[1]
	for roof: Array in roofs:
		var r: Rect2i = roof[0]
		var h: float = roof[1]
		var size := Vector3(r.size.x * CELL, 0.4, r.size.y * CELL)
		add_box.call("roof", Vector3(r.position.x * CELL + size.x / 2.0, h + 0.2, r.position.y * CELL + size.z / 2.0), size)
		# A header over every opening, so tunnels and doors have a top.
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if _is_wall_char(char_at(c)):
					continue
				for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
					var n := c + d
					if roofed.has(n) or _is_wall_char(char_at(n)):
						continue
					var edge := center(c) + Vector3(d.x, 0, d.y) * (CELL / 2.0)
					var header_h := wall_height - h
					var s := Vector3(CELL, header_h, 0.4) if d.y != 0 else Vector3(0.4, header_h, CELL)
					add_box.call("wall", Vector3(edge.x, h + header_h / 2.0, edge.z), s)
	var materials := {
		"wall": Tex.surface(data["wall"], 4.0, data["wall_tint"]),
		"low": Tex.surface(data["low"], 2.0, Color(0.92, 0.9, 0.86)),
		"pillar": Tex.surface(data["pillar"], 2.0),
		"roof": Tex.surface(data["roof"], 4.0, data.get("roof_tint", Color(0.8, 0.8, 0.8))),
		"glass": Tex.glass(),
		"frame": Tex.flat(Color(0.22, 0.24, 0.26), 0.0, 0.6),
	}
	for ch: String in walls:
		materials["wall:" + ch] = Tex.surface(walls[ch].get("tex", data["wall"]), walls[ch].get("meters", 4.0), walls[ch].get("tint", Color.WHITE))
	for ch: String in lows:
		materials["low:" + ch] = Tex.surface(lows[ch].get("tex", data["low"]), 2.0, lows[ch].get("tint", Color.WHITE))
	var mesh := ArrayMesh.new()
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	for key: String in boxes:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for b: Array in boxes[key]:
			_box_faces(st, b[0], b[1])
			_collider(body, b[0], b[1])
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials[key])
	var level := MeshInstance3D.new()
	level.mesh = mesh
	add_child(level)
	# Crates: one mesh each, so the planks line up with every crate.
	var crate_tint := Color(1, 1, 1)
	for crate: Array in crates:
		var part := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = crate[1]
		part.mesh = box
		if data["crate"] == "metal":
			crate_tint = [Color(0.45, 0.55, 0.4), Color(0.35, 0.45, 0.6), Color(0.65, 0.35, 0.28)][int(absf(crate[0].x * 7.0 + crate[0].z * 3.0)) % 3]
		part.material_override = Tex.surface(data["crate"], CRATE, crate_tint, true)
		part.position = crate[0]
		part.rotation.y = crate[2]
		add_child(part)
		_collider(body, crate[0], crate[1], crate[2])
	_build_floor(body)
	_build_water()
	_site_marks()
	DressingScript.new().build(self, body)


## Covers a set of cells with as few rectangles as it takes: [[Rect2i, h], ...].
static func _rectangles(cells: Dictionary, h: float) -> Array:
	var left := cells.duplicate()
	var out: Array = []
	var keys := left.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or a.y == b.y and a.x < b.x)
	for c: Vector2i in keys:
		if not left.has(c):
			continue
		var w := 1
		while left.has(c + Vector2i(w, 0)):
			w += 1
		var rows_down := 1
		while true:
			var full := true
			for i in w:
				if not left.has(c + Vector2i(i, rows_down)):
					full = false
					break
			if not full:
				break
			rows_down += 1
		for y in rows_down:
			for i in w:
				left.erase(c + Vector2i(i, y))
		out.append([Rect2i(c.x, c.y, w, rows_down), h])
	return out


## True when a wall cell touches an open cell (other walls are never seen).
func _exposed(c: Vector2i) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dz)
			if n.x >= 0 and n.y >= 0 and n.x < width and n.y < depth and not _is_wall_char(char_at(n)):
				return true
	return false


func _collider(body: StaticBody3D, c: Vector3, s: Vector3, yaw := 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = s
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = c
	col.rotation.y = yaw
	body.add_child(col)


func _box_faces(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var h := s / 2.0
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for face in faces:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var mid := c + n * h
		var eu := u * h
		var ev := v * h
		var corners := [mid - eu + ev, mid + eu + ev, mid + eu - ev, mid - eu - ev]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.add_vertex(corners[i])


## The floor: one quad per cell, grouped by kind, and a flat plane underneath to stand on.
func _build_floor(body: StaticBody3D) -> void:
	var kinds := {}
	for z in depth:
		for x in rows[z].length():
			var ch := rows[z][x]
			if _is_wall_char(ch):
				continue
			var key: String = data["paved"] if ch == "," else data["floor"]
			if legend.has(ch) and legend[ch].has("floor"):
				key = legend[ch]["floor"]
			elif legend.has(ch):
				key = _floor_near(x, z)  # things placed on the map stand on the floor around them
			if not kinds.has(key):
				var new_st := SurfaceTool.new()
				new_st.begin(Mesh.PRIMITIVE_TRIANGLES)
				kinds[key] = new_st
			var st: SurfaceTool = kinds[key]
			var o := Vector3(x * CELL, 0, z * CELL)
			var corners := [o, o + Vector3(CELL, 0, 0), o + Vector3(CELL, 0, CELL), o + Vector3(0, 0, CELL)]
			for i: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(corners[i])
	var mesh := ArrayMesh.new()
	for key: String in kinds:
		(kinds[key] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Tex.surface(key, 4.0 if key == data["floor"] else 2.0, data.get("floor_tint", Color.WHITE)))
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = mesh
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)
	var plane := WorldBoundaryShape3D.new()
	var col := CollisionShape3D.new()
	col.shape = plane
	body.add_child(col)


## The floor kind of the nearest plain ground cell in the same row.
func _floor_near(x: int, z: int) -> String:
	for step in range(1, 8):
		for nx in [x - step, x + step]:
			var ch := char_at(Vector2i(nx, z))
			if ch == ",":
				return data["paved"]
			if ch == ".":
				return data["floor"]
	return data["floor"]


## A still, dark surface a little above the floor on flooded cells.
func _build_water() -> void:
	if water.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: Vector2i in water:
		var o := Vector3(c.x * CELL, 0.16, c.y * CELL)
		var corners := [o, o + Vector3(CELL, 0, 0), o + Vector3(CELL, 0, CELL), o + Vector3(0, 0, CELL)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(corners[i])
	var surface := MeshInstance3D.new()
	surface.mesh = st.commit()
	surface.material_override = Tex.water()
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)


## Big painted letters and a border on each bomb site.
func _site_marks() -> void:
	for key: String in sites:
		var r: Rect2i = sites[key]
		var label := Label3D.new()
		label.text = key.to_upper()
		label.font_size = 256
		label.pixel_size = 0.018
		label.outline_size = 0
		label.modulate = Color(0.75, 0.12, 0.08, 0.8)
		label.shaded = true
		label.double_sided = false
		label.rotation = Vector3(-PI / 2.0, 0, 0)
		var at := site_center(key)
		# Put the letter on an open cell near the middle of the site.
		var c := cell_of(at)
		if is_solid(c):
			at = random_site_point(key)
		label.position = at + Vector3(0, 0.02, 0)
		add_child(label)
		var wall_label := label.duplicate() as Label3D
		wall_label.rotation = Vector3.ZERO
		wall_label.pixel_size = 0.012
		wall_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		wall_label.position = _site_wall_spot(r)
		add_child(wall_label)
		var paint := Tex.flat(Color(0.7, 0.14, 0.08))
		var o := Vector3(r.position.x * CELL, 0.012, r.position.y * CELL)
		var w := r.size.x * CELL
		var d := r.size.y * CELL
		for edge: Array in [[o + Vector3(w / 2.0, 0, 0), Vector3(w, 0.01, 0.12)], [o + Vector3(w / 2.0, 0, d), Vector3(w, 0.01, 0.12)],
				[o + Vector3(0, 0, d / 2.0), Vector3(0.12, 0.01, d)], [o + Vector3(w, 0, d / 2.0), Vector3(0.12, 0.01, d)]]:
			var line := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = edge[1]
			line.mesh = box
			line.material_override = paint
			line.position = edge[0]
			add_child(line)


## A spot on the site's north wall facing south, for the letter painted on the wall.
func _site_wall_spot(r: Rect2i) -> Vector3:
	var x := r.position.x + r.size.x / 2
	for y in range(r.position.y, -1, -1):
		if char_at(Vector2i(x, y - 1)) == "#":
			return Vector3((x + 0.5) * CELL, 2.6, y * CELL + 0.03)
	return Vector3((r.position.x + r.size.x / 2.0) * CELL, 2.6, r.position.y * CELL + 0.03)


func _build_nav() -> void:
	astar.region = Rect2i(0, 0, width, depth)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for z in depth:
		for x in width:
			var c := Vector2i(x, z)
			if is_solid(c):
				astar.set_point_solid(c, true)
			else:
				# Keep bots off the walls: cells beside something solid cost more.
				for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
					if is_solid(c + d):
						astar.set_point_weight_scale(c, 1.6)
						break
