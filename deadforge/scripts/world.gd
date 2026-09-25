extends Node3D
## One level: builds it from its ASCII map (see levels.gd) and runs everything in it besides the
## player's own controls: doors, pickups, enemies' pathfinding, splash damage and effects.
##
## Lighting is worked out once, here: every light (lamps, braziers, lava, the exit pad) reaches the
## cells it can see, and each vertex of the walls, floor and ceiling stores its brightness as a vertex
## color. Moving things read the brightness of the cell they stand in (light_level).

const Tex := preload("res://scripts/textures.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const DoorScript := preload("res://scripts/door.gd")
const PlayerScript := preload("res://scripts/player.gd")

const CELL := 4.0
const HEIGHT := 4.0
const SUB := 4  # wall, floor and ceiling quads are split SUB x SUB so the vertex light is smooth
const WALLS := "#MK"
const ENEMIES := {"h": "husk", "c": "cinder", "g": "brute", "X": "boss"}
const PICKUPS := "+anserbSF"
const FACING := {"n": 0.0, "w": PI / 2.0, "s": PI, "e": -PI / 2.0}
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIAGONALS := [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]

# Physics layers.
const LAYER_WORLD := 1  # walls, doors, pillars
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_SURFACE := 8  # floor and ceiling, only for shots

var game  # main.gd
var level: Dictionary
var rows := PackedStringArray()
var width := 0
var depth := 0
var player  # player.gd
var enemies: Array = []
var doors := {}  # Vector2i -> door.gd
var pickups: Array[Node3D] = []
var boss  # the Forgelord, on the level that has one
var exit_cell := Vector2i(-1, -1)
var finished := false

var ambient := Color(0.2, 0.2, 0.2)
var lights: Array = []  # {pos, color, radius, energy}
var cell_lights := {}  # Vector2i -> [[light index, visibility 0..1], ...]
var cell_light := {}  # Vector2i -> Color at the middle of the cell, for moving things

var flow := PackedInt32Array()  # steps from each cell to the player, -1 where enemies can't walk
var flow_cell := Vector2i(-99, -99)
var flow_timer := 0.0

var kills := 0
var total_kills := 0
var items := 0
var total_items := 0
var time := 0.0

var particles: Array = []  # [MeshInstance3D, velocity, life left, life]
var blasts: Array = []  # [MeshInstance3D, age, size]
var flames: Array[Node3D] = []
var message_cooldown := 0.0
var clock := 0.0


func build(game_ref, level_data: Dictionary, carry: Dictionary) -> void:
	game = game_ref
	level = level_data
	rows = PackedStringArray(level["map"])
	depth = rows.size()
	for row in rows:
		width = maxi(width, row.length())
	ambient = level["ambient"]
	flow.resize(width * depth)
	_environment()
	_find_lights()
	_light_cells()
	_build_geometry()
	_build_collision()
	_spawn(carry)


# --- Map queries ---------------------------------------------------------------------------

func char_at(c: Vector2i) -> String:
	if c.y < 0 or c.y >= depth or c.x < 0 or c.x >= rows[c.y].length():
		return "#"
	return rows[c.y][c.x]


func is_wall(c: Vector2i) -> bool:
	return WALLS.contains(char_at(c))


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func center(c: Vector2i, y := 0.0) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, y, (c.y + 0.5) * CELL)


## Cells enemies path through: no walls, pillars or lava, and key doors only while they're open.
func walkable(c: Vector2i) -> bool:
	var ch := char_at(c)
	if WALLS.contains(ch) or ch in ["o", "T", "~"]:
		return false
	if ch == "R" or ch == "B":
		return doors[c].open_amount > 0.8
	return true


## Brightness at a point, for things that move or were placed there.
func light_level(p: Vector3) -> Color:
	return cell_light.get(cell_of(p), ambient)


## True when nothing solid (walls, doors) stands between a and b.
func clear_line(a: Vector3, b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a, b, LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Where an enemy at `from` should head next to reach the player, following the flow field.
func path_target(from: Vector3) -> Vector3:
	var c := cell_of(from)
	var here := _flow(c)
	var best := c
	var best_steps := here if here >= 0 else 1 << 30
	for d: Vector2i in DIRS:
		var steps := _flow(c + d)
		if steps >= 0 and steps < best_steps:
			best = c + d
			best_steps = steps
	for d: Vector2i in DIAGONALS:
		var steps := _flow(c + d)
		# Cut a corner only when both cells beside it are open too.
		if steps >= 0 and steps < best_steps and _flow(c + Vector2i(d.x, 0)) >= 0 and _flow(c + Vector2i(0, d.y)) >= 0:
			best = c + d
			best_steps = steps
	if best == c:
		return player.position
	return center(best)


func _flow(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= depth:
		return -1
	return flow[c.y * width + c.x]


func _update_flow() -> void:
	flow.fill(-1)
	var start := cell_of(player.position)
	flow_cell = start
	if start.x < 0 or start.y < 0 or start.x >= width or start.y >= depth:
		return
	flow[start.y * width + start.x] = 0
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var steps := flow[c.y * width + c.x] + 1
		for d: Vector2i in DIRS:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x >= width or n.y >= depth:
				continue
			if flow[n.y * width + n.x] == -1 and walkable(n):
				flow[n.y * width + n.x] = steps
				queue.append(n)


# --- Running -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if player == null:
		return
	clock += delta
	message_cooldown -= delta
	if player.alive and not finished:
		time += delta
	flow_timer -= delta
	if flow_timer <= 0.0 or cell_of(player.position) != flow_cell:
		flow_timer = 0.5
		_update_flow()
	_update_doors()
	_update_pickups()
	_check_exit()


func _process(delta: float) -> void:
	_update_particles(delta)
	for flame in flames:
		# Flicker by stretching each cone up from its base.
		var s := 0.85 + 0.2 * sin(clock * 13.0 + flame.rotation.y * 5.0) + 0.12 * sin(clock * 29.0 + flame.position.z)
		flame.scale = Vector3(1.0, s, 1.0)
		var mesh := (flame as MeshInstance3D).mesh as CylinderMesh
		flame.position.y = flame.get_meta("base") + mesh.height * s / 2.0
	for pickup in pickups:
		pickup.rotation.y += delta * 1.6
		pickup.position.y = pickup.get_meta("y") + sin(clock * 2.5 + pickup.position.x) * 0.08


func _update_doors() -> void:
	for c: Vector2i in doors:
		var door = doors[c]
		var spot := center(c)
		if player.alive and _flat_distance(player.position, spot) < 3.4:
			if door.key != "" and not player.keys.has(door.key):
				if door.open_amount < 0.05 and message_cooldown <= 0.0:
					message_cooldown = 2.0
					game.message(tr("need_%s_key" % door.key))
					game.sfx.play("locked")
			else:
				door.open()
		elif door.key == "":
			for enemy in enemies:
				if enemy.alive and enemy.alerted and _flat_distance(enemy.position, spot) < 3.0:
					door.open()
					break


## True while something stands in the doorway, so the door waits before closing.
func doorway_busy(c: Vector2i) -> bool:
	var spot := center(c)
	if player.alive and _flat_distance(player.position, spot) < 2.6:
		return true
	for enemy in enemies:
		if enemy.alive and _flat_distance(enemy.position, spot) < 2.2 + enemy.radius:
			return true
	return false


func _update_pickups() -> void:
	if not player.alive:
		return
	for i in range(pickups.size() - 1, -1, -1):
		var pickup := pickups[i]
		if _flat_distance(pickup.position, player.position) < 1.4 and player.take(pickup.get_meta("kind")):
			pickups.remove_at(i)
			pickup.queue_free()
			if pickup.get_meta("counted"):
				items += 1


func _check_exit() -> void:
	if finished or not player.alive or cell_of(player.position) != exit_cell:
		return
	if boss != null and boss.alive:
		if message_cooldown <= 0.0:
			message_cooldown = 2.5
			game.message(tr("exit_sealed"))
			game.sfx.play("locked")
		return
	finished = true
	game.level_complete()


func on_enemy_killed(enemy) -> void:
	kills += 1
	if enemy == boss:
		game.message(tr("boss_dead"))
		game.sfx.play("exit")
	elif kills == total_kills:
		game.message(tr("all_killed"))


## Wakes up the enemies within `radius` of a noise (a shot, an explosion).
func alert_near(pos: Vector3, radius: float) -> void:
	for enemy in enemies:
		if enemy.alive and not enemy.alerted and enemy.position.distance_to(pos) < radius:
			enemy.alert()


## Damage that fades with distance from `pos`, stopped by walls.
func splash(pos: Vector3, radius: float, damage: float, from_player: bool) -> void:
	for enemy in enemies:
		if not enemy.alive:
			continue
		var target: Vector3 = enemy.position + Vector3(0, enemy.height * 0.5, 0)
		var d: float = maxf(target.distance_to(pos) - enemy.radius, 0.0)
		if d < radius and clear_line(pos, target):
			enemy.hurt(damage * (1.0 - d / radius), pos)
	if player.alive:
		var target: Vector3 = player.position + Vector3(0, 1.0, 0)
		var d := maxf(target.distance_to(pos) - 0.4, 0.0)
		if d < radius and clear_line(pos, target):
			player.hurt(damage * (1.0 - d / radius) * (0.5 if from_player else 1.0), pos)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Effects -------------------------------------------------------------------------------

## Little cubes flying out of `pos`: sparks (glowing) or blood (lit like the room).
func burst(pos: Vector3, color: Color, count: int, speed: float, size: float, glowing: bool) -> void:
	var mat := Tex.material("plain", color, 1.0 if glowing else 0.0)
	if not glowing:
		mat.set_shader_parameter("light", _rgb(light_level(pos)))
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	for i in count:
		var bit := MeshInstance3D.new()
		bit.mesh = mesh
		bit.material_override = mat
		bit.position = pos
		add_child(bit)
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.3), randf_range(-1, 1)).normalized()
		var life := randf_range(0.3, 0.7)
		particles.append([bit, dir * speed * randf_range(0.4, 1.0), life, life])


func explosion(pos: Vector3, size: float) -> void:
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	ball.mesh = sphere
	ball.material_override = Tex.material("lava", Color(1.3, 1.0, 0.8), 1.0)
	ball.position = pos
	ball.scale = Vector3.ONE * 0.1
	add_child(ball)
	blasts.append([ball, 0.0, size])
	burst(pos, Color(1.0, 0.6, 0.15), 14, 9.0, 0.16, true)
	game.sfx.play_at("explode", pos)
	game.shake(clampf(1.0 - player.position.distance_to(pos) / 14.0, 0.0, 1.0) * 0.6)


func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Array = particles[i]
		var bit: MeshInstance3D = p[0]
		p[2] -= delta
		if p[2] <= 0.0:
			bit.queue_free()
			particles.remove_at(i)
			continue
		var v: Vector3 = p[1]
		v.y -= 14.0 * delta
		bit.position += v * delta
		if bit.position.y < 0.04:
			bit.position.y = 0.04
			v = Vector3.ZERO
		p[1] = v
		bit.scale = Vector3.ONE * (p[2] / p[3])
	for i in range(blasts.size() - 1, -1, -1):
		var b: Array = blasts[i]
		var ball: MeshInstance3D = b[0]
		b[1] += delta
		var t: float = b[1] / 0.3
		if t >= 1.0:
			ball.queue_free()
			blasts.remove_at(i)
			continue
		ball.scale = Vector3.ONE * b[2] * (sin(t * PI) * 0.8 + t * 0.2)


# --- Building ------------------------------------------------------------------------------

func _environment() -> void:
	var fog: Color = level["fog"]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = fog
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = 0.03
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _add_light(pos: Vector3, color: Color, radius: float, energy: float) -> void:
	lights.append({"pos": pos, "color": color, "radius": radius, "energy": energy})


func _find_lights() -> void:
	for z in depth:
		for x in rows[z].length():
			var c := Vector2i(x, z)
			match rows[z][x]:
				"l":
					_add_light(center(c, 3.2), Color(1.0, 0.8, 0.55), 16.0, 1.4)
				"T":
					_add_light(center(c, 1.8), Color(1.0, 0.5, 0.2), 14.0, 1.4)
				"E":
					_add_light(center(c, 0.6), Color(0.3, 1.0, 0.45), 9.0, 1.0)
				"r":
					_add_light(center(c, 1.0), Color(1.0, 0.2, 0.1), 6.0, 0.6)
				"b":
					_add_light(center(c, 1.0), Color(0.2, 0.4, 1.0), 6.0, 0.7)
				"~":
					if (x + z) % 2 == 0:
						_add_light(center(c, 0.5), Color(1.0, 0.32, 0.06), 9.0, 1.0)


## Which lights reach which cells, and how much of each cell they can see.
func _light_cells() -> void:
	for i in lights.size():
		var pos: Vector3 = lights[i]["pos"]
		var reach := ceili(lights[i]["radius"] / CELL) + 1
		var home := cell_of(pos)
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var c := home + Vector2i(dx, dz)
				if is_wall(c):
					continue
				var seen := 0
				for offset: Vector2 in [Vector2.ZERO, Vector2(-1.7, -1.7), Vector2(1.7, -1.7), Vector2(1.7, 1.7), Vector2(-1.7, 1.7)]:
					if _grid_clear(pos, center(c, pos.y) + Vector3(offset.x, 0, offset.y), c):
						seen += 1
				if seen > 0:
					if not cell_lights.has(c):
						cell_lights[c] = []
					cell_lights[c].append([i, seen / 5.0])
	for z in depth:
		for x in rows[z].length():
			var c := Vector2i(x, z)
			if not is_wall(c):
				cell_light[c] = light_at(center(c, 1.2), Vector3.ZERO, c)


## A straight walk over the map from a to b, blocked by walls and by doors in between.
func _grid_clear(a: Vector3, b: Vector3, target: Vector2i) -> bool:
	var home := cell_of(a)
	var steps := ceili(Vector2(b.x - a.x, b.z - a.z).length() / 0.3)
	for i in range(1, steps + 1):
		var c := cell_of(a.lerp(b, float(i) / steps))
		if c == target:
			return true
		if is_wall(c) or (c != home and char_at(c) in ["D", "R", "B"]):
			return false
	return true


## Brightness at point p with surface normal n (zero for no surface) inside cell c.
func light_at(p: Vector3, n: Vector3, c: Vector2i) -> Color:
	var col := ambient
	for entry: Array in cell_lights.get(c, []):
		var light: Dictionary = lights[entry[0]]
		var d: Vector3 = light["pos"] - p
		var dist := d.length()
		var radius: float = light["radius"]
		if dist >= radius:
			continue
		var f := 1.0 - dist / radius
		f *= f
		if n != Vector3.ZERO and dist > 0.01:
			var facing := n.dot(d / dist)
			if facing <= 0.0:
				continue
			f *= 0.35 + 0.65 * facing
		col += light["color"] * (f * light["energy"] * entry[1])
	return Color(minf(col.r, 1.8), minf(col.g, 1.8), minf(col.b, 1.8))


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _wall_kind(ch: String) -> String:
	match ch:
		"M":
			return "metal"
		"K":
			return "rock"
	return level["wall"]


func _build_geometry() -> void:
	var surfaces := {}
	for z in depth:
		for x in rows[z].length():
			var c := Vector2i(x, z)
			var ch := rows[z][x]
			if WALLS.contains(ch):
				continue
			var x0 := x * CELL
			var z0 := z * CELL
			var floor_kind: String = level["floor"]
			if ch == "~":
				floor_kind = "lava"
			elif ch == ",":
				floor_kind = "grate"
			elif ch == "E":
				floor_kind = "exit"
			_quad(surfaces, floor_kind, Vector3(x0, 0, z0), Vector3(CELL, 0, 0), Vector3(0, 0, CELL), Vector3.UP, c, Vector2(x, z))
			_quad(surfaces, level["ceiling"], Vector3(x0, HEIGHT, z0), Vector3(CELL, 0, 0), Vector3(0, 0, CELL), Vector3.DOWN, c, Vector2(x, z))
			# Walls around this cell, facing into it.
			var down := Vector3(0, -HEIGHT, 0)
			if is_wall(c + Vector2i(0, -1)):
				_quad(surfaces, _wall_kind(char_at(c + Vector2i(0, -1))), Vector3(x0, HEIGHT, z0), Vector3(CELL, 0, 0), down, Vector3.BACK, c, Vector2.ZERO)
			if is_wall(c + Vector2i(0, 1)):
				_quad(surfaces, _wall_kind(char_at(c + Vector2i(0, 1))), Vector3(x0 + CELL, HEIGHT, z0 + CELL), Vector3(-CELL, 0, 0), down, Vector3.FORWARD, c, Vector2.ZERO)
			if is_wall(c + Vector2i(-1, 0)):
				_quad(surfaces, _wall_kind(char_at(c + Vector2i(-1, 0))), Vector3(x0, HEIGHT, z0 + CELL), Vector3(0, 0, -CELL), down, Vector3.RIGHT, c, Vector2.ZERO)
			if is_wall(c + Vector2i(1, 0)):
				_quad(surfaces, _wall_kind(char_at(c + Vector2i(1, 0))), Vector3(x0 + CELL, HEIGHT, z0), Vector3(0, 0, CELL), down, Vector3.LEFT, c, Vector2.ZERO)
	var mesh := ArrayMesh.new()
	for kind: String in surfaces:
		var st: SurfaceTool = surfaces[kind]
		st.commit(mesh)
		var mat := Tex.material(kind)
		mat.set_shader_parameter("color_scale", 2.0)
		if kind == "lava":
			mat.set_shader_parameter("scroll", Vector2(0.03, 0.015))
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)


## One wall, floor or ceiling square: corner o, edges u (across) and v (down), split SUB x SUB,
## each vertex lit by light_at. The texture repeats once per cell, starting at uv0.
func _quad(surfaces: Dictionary, kind: String, o: Vector3, u: Vector3, v: Vector3, n: Vector3, c: Vector2i, uv0: Vector2) -> void:
	if not surfaces.has(kind):
		var new_st := SurfaceTool.new()
		new_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[kind] = new_st
	var st: SurfaceTool = surfaces[kind]
	var points := []
	var colors := []
	for j in SUB + 1:
		for i in SUB + 1:
			var p := o + u * (float(i) / SUB) + v * (float(j) / SUB)
			points.append(p)
			# Stored at half brightness: vertex colors can't go over 1, the shader doubles them.
			var lit := light_at(p + n * 0.05, n, c) * 0.5
			colors.append(Color(minf(lit.r, 1.0), minf(lit.g, 1.0), minf(lit.b, 1.0)))
	for j in SUB:
		for i in SUB:
			var a := j * (SUB + 1) + i
			for k: int in [a, a + 1, a + SUB + 2, a, a + SUB + 2, a + SUB + 1]:
				var col := k % (SUB + 1)
				var row := k / (SUB + 1)
				st.set_color(colors[k])
				st.set_normal(n)
				st.set_uv(uv0 + Vector2(float(col) / SUB, float(row) / SUB))
				st.add_vertex(points[k])


func _build_collision() -> void:
	var walls := StaticBody3D.new()
	walls.collision_layer = LAYER_WORLD
	walls.collision_mask = 0
	add_child(walls)
	var cube := BoxShape3D.new()
	cube.size = Vector3(CELL, HEIGHT, CELL)
	var column := BoxShape3D.new()
	column.size = Vector3(1.4, HEIGHT, 1.4)
	var stand := CylinderShape3D.new()
	stand.radius = 0.6
	stand.height = HEIGHT
	for z in depth:
		for x in rows[z].length():
			var c := Vector2i(x, z)
			var shape: Shape3D = null
			var ch := rows[z][x]
			if WALLS.contains(ch):
				for d: Vector2i in DIRS:
					if not is_wall(c + d):
						shape = cube
						break
			elif ch == "o":
				shape = column
			elif ch == "T":
				shape = stand
			if shape != null:
				var col := CollisionShape3D.new()
				col.shape = shape
				col.position = center(c, HEIGHT / 2.0)
				walls.add_child(col)
	# Floor and ceiling only stop shots, so bullets and fireballs don't fly through them.
	var surfaces := StaticBody3D.new()
	surfaces.collision_layer = LAYER_SURFACE
	surfaces.collision_mask = 0
	add_child(surfaces)
	for plane: Plane in [Plane(Vector3.UP, 0.0), Plane(Vector3.DOWN, -HEIGHT)]:
		var boundary := WorldBoundaryShape3D.new()
		boundary.plane = plane
		var col := CollisionShape3D.new()
		col.shape = boundary
		surfaces.add_child(col)


func _spawn(carry: Dictionary) -> void:
	for z in depth:
		for x in rows[z].length():
			var c := Vector2i(x, z)
			var ch := rows[z][x]
			if ch == "P":
				player = PlayerScript.new()
				add_child(player)
				player.position = center(c)
				player.setup(self, game, carry, FACING.get(level.get("facing", "e"), 0.0))
			elif ch == "E":
				exit_cell = c
			elif ch in ["D", "R", "B"]:
				var door = DoorScript.new()
				var across_x := is_wall(c + Vector2i(-1, 0)) and is_wall(c + Vector2i(1, 0))
				var key: String = {"D": "", "R": "red", "B": "blue"}[ch]
				add_child(door)
				door.position = center(c)
				door.setup(self, c, key, across_x)
				doors[c] = door
			elif ENEMIES.has(ch):
				var enemy = EnemyScript.new()
				enemy.kind = ENEMIES[ch]
				add_child(enemy)
				enemy.position = center(c)
				enemy.rotation.y = randf() * TAU
				enemy.setup(self, game)
				enemies.append(enemy)
				total_kills += 1
				if ch == "X":
					boss = enemy
			elif PICKUPS.contains(ch):
				spawn_pickup(ch, center(c, 0.45))
			elif ch == "o":
				_prop(Tex.box(Vector3(1.4, HEIGHT, 1.4), Vector2(0.4, 1.0)), center(c, HEIGHT / 2.0), _wall_kind("#"), c)
			elif ch == "T":
				_brazier(c)
			elif ch == "l":
				_lamp(c)


func _prop(mesh: Mesh, pos: Vector3, kind: String, c: Vector2i, tint := Color.WHITE, glow := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat := Tex.material(kind, tint, glow)
	mat.set_shader_parameter("light", _rgb(cell_light.get(c, ambient)))
	instance.material_override = mat
	instance.position = pos
	add_child(instance)
	return instance


func _brazier(c: Vector2i) -> void:
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.6
	bowl.bottom_radius = 0.2
	bowl.height = 0.5
	var leg := CylinderMesh.new()
	leg.top_radius = 0.12
	leg.bottom_radius = 0.3
	leg.height = 0.9
	_prop(leg, center(c, 0.45), "steel", c)
	_prop(bowl, center(c, 1.1), "steel", c)
	for i in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.45 - i * 0.12
		cone.height = 1.1 - i * 0.25
		cone.radial_segments = 7
		var flame := _prop(cone, center(c, 1.35 + cone.height / 2.0) + Vector3(0.06 * i - 0.06, 0, 0.05 * (i % 2)), "glow",
				c, [Color(1.0, 0.4, 0.08), Color(1.0, 0.68, 0.2), Color(1.0, 0.95, 0.65)][i], 1.0)
		flame.rotation.y = i * 0.7
		flame.set_meta("base", flame.position.y - cone.height / 2.0)
		flames.append(flame)


func _lamp(c: Vector2i) -> void:
	_prop(Tex.box(Vector3(0.05, 0.6, 0.05)), center(c, HEIGHT - 0.3), "steel", c)
	_prop(Tex.box(Vector3(0.4, 0.45, 0.4)), center(c, HEIGHT - 0.8), "steel", c, Color(0.6, 0.6, 0.6))
	var bulb := SphereMesh.new()
	bulb.radius = 0.17
	bulb.height = 0.34
	_prop(bulb, center(c, HEIGHT - 0.85), "glow", c, Color(1.0, 0.85, 0.55), 1.0)


## Places a pickup; `counted` ones make up the level's item total (drops from demons don't).
func spawn_pickup(ch: String, pos: Vector3, counted := true) -> void:
	var root := Node3D.new()
	root.set_meta("kind", ch)
	root.set_meta("y", pos.y)
	root.set_meta("counted", counted)
	root.position = pos
	add_child(root)
	var light := _rgb(light_level(pos)) * 1.3
	var add := func(mesh: Mesh, pos: Vector3, kind: String, tint: Color, glow := 0.0) -> MeshInstance3D:
		var part := MeshInstance3D.new()
		part.mesh = mesh
		var mat := Tex.material(kind, tint, glow)
		mat.set_shader_parameter("light", light)
		part.material_override = mat
		part.position = pos
		root.add_child(part)
		return part
	match ch:
		"+":
			add.call(Tex.box(Vector3(0.7, 0.42, 0.5)), Vector3.ZERO, "plain", Color(0.95, 0.95, 0.92))
			add.call(Tex.box(Vector3(0.44, 0.03, 0.13)), Vector3(0, 0.22, 0), "glow", Color(0.9, 0.1, 0.1), 0.6)
			add.call(Tex.box(Vector3(0.13, 0.03, 0.36)), Vector3(0, 0.22, 0), "glow", Color(0.9, 0.1, 0.1), 0.6)
			add.call(Tex.box(Vector3(0.3, 0.1, 0.03)), Vector3(0, 0, 0.26), "glow", Color(0.9, 0.1, 0.1), 0.6)
			add.call(Tex.box(Vector3(0.1, 0.3, 0.03)), Vector3(0, 0, 0.26), "glow", Color(0.9, 0.1, 0.1), 0.6)
		"a":
			add.call(Tex.box(Vector3(0.75, 0.85, 0.3)), Vector3(0, 0.15, 0), "steel", Color(0.55, 1.0, 0.75))
			add.call(Tex.box(Vector3(0.95, 0.25, 0.34)), Vector3(0, 0.5, 0), "steel", Color(0.45, 0.8, 0.6))
			add.call(Tex.box(Vector3(0.2, 0.2, 0.05)), Vector3(0, 0.2, 0.17), "glow", Color(0.4, 1.0, 0.6), 1.0)
		"n":
			add.call(Tex.box(Vector3(0.55, 0.3, 0.38)), Vector3.ZERO, "plain", Color(0.35, 0.25, 0.15))
			add.call(Tex.box(Vector3(0.5, 0.06, 0.33)), Vector3(0, 0.17, 0), "plain", Color(0.85, 0.65, 0.25))
		"s":
			add.call(Tex.box(Vector3(0.55, 0.3, 0.35)), Vector3.ZERO, "plain", Color(0.65, 0.12, 0.1))
			add.call(Tex.box(Vector3(0.57, 0.08, 0.37)), Vector3(0, -0.1, 0), "plain", Color(0.85, 0.65, 0.25))
		"e":
			var can := CylinderMesh.new()
			can.top_radius = 0.22
			can.bottom_radius = 0.22
			can.height = 0.65
			add.call(can, Vector3(0, 0.1, 0), "steel", Color.WHITE)
			var band := CylinderMesh.new()
			band.top_radius = 0.24
			band.bottom_radius = 0.24
			band.height = 0.18
			add.call(band, Vector3(0, 0.1, 0), "lava", Color.WHITE, 1.0)
		"S":
			add.call(Tex.box(Vector3(0.1, 0.1, 1.1)), Vector3(-0.06, 0.1, -0.1), "steel", Color(0.7, 0.7, 0.7))
			add.call(Tex.box(Vector3(0.1, 0.1, 1.1)), Vector3(0.06, 0.1, -0.1), "steel", Color(0.7, 0.7, 0.7))
			add.call(Tex.box(Vector3(0.2, 0.16, 0.3)), Vector3(0, 0.06, 0.05), "plain", Color(0.4, 0.22, 0.1))
			add.call(Tex.box(Vector3(0.14, 0.24, 0.45)), Vector3(0, -0.02, 0.55), "plain", Color(0.4, 0.22, 0.1))
		"F":
			add.call(Tex.box(Vector3(0.36, 0.36, 1.1)), Vector3(0, 0.1, 0), "steel", Color(0.8, 0.8, 0.8))
			for i in 3:
				add.call(Tex.box(Vector3(0.4, 0.4, 0.08)), Vector3(0, 0.1, -0.35 + i * 0.3), "lava", Color.WHITE, 1.0)
			add.call(Tex.box(Vector3(0.14, 0.3, 0.14)), Vector3(0, -0.2, 0.2), "steel", Color(0.5, 0.5, 0.5))
		"r", "b":
			var color := Color(1.0, 0.2, 0.1) if ch == "r" else Color(0.25, 0.45, 1.0)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.1
			ring.outer_radius = 0.2
			var bow := add.call(ring, Vector3(0, 0.3, 0), "glow", color, 1.0) as MeshInstance3D
			bow.rotation.x = PI / 2.0
			add.call(Tex.box(Vector3(0.07, 0.45, 0.07)), Vector3(0, -0.03, 0), "glow", color, 1.0)
			add.call(Tex.box(Vector3(0.15, 0.07, 0.07)), Vector3(0.07, -0.2, 0), "glow", color, 1.0)
			add.call(Tex.box(Vector3(0.12, 0.07, 0.07)), Vector3(0.06, -0.08, 0), "glow", color, 1.0)
	pickups.append(root)
	if counted:
		total_items += 1
