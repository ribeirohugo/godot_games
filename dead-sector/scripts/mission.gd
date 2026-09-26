extends "res://scripts/rules.gd"
## One campaign mission, in place of a match (it answers everything soldiers, bots, the camera and
## the HUD ask of rules.gd). A mission is a list of areas; each area is a map (scripts/missions/)
## whose legend places everything: the player, enemies, allies, machines, props, doors, lamps,
## things to use and to pick up, hazards, triggers and marks. Its events ("when" something happens,
## "do" these actions) tell the story: dialogue, objectives, waves, doors, power, checkpoints.
##
## Dying restarts from the last checkpoint: the area is rebuilt and the events fired until then are
## replayed silently (only what changes the world: doors, power, spawns...), minus whoever was
## already dead.

const Campaign := preload("res://scripts/campaign.gd")
const GruntScript := preload("res://scripts/grunt.gd")
const BeastScript := preload("res://scripts/beast.gd")
const BossScript := preload("res://scripts/boss.gd")
const MachineScript := preload("res://scripts/machine.gd")
const HazardsScript := preload("res://scripts/hazards.gd")
const BehemothScript := preload("res://scripts/behemoth.gd")
const Props := preload("res://scripts/props.gd")
const Tex := preload("res://scripts/textures.gd")

## Actions replayed when restoring a checkpoint: the ones that change the world.
const LASTING := ["spawn", "wake", "open", "close", "lock", "unlock", "power", "hazard", "alarm", "ally",
		"collapse", "mask", "give", "prop_off", "remove"]

var campaign := true
var mission_i := 0
var mission: Dictionary
var area_i := 0
var area: Dictionary
var legend: Dictionary
var difficulty := 1
var hazards
var markers := {}  # mark id -> [positions]
var trigger_cells := {}  # cell -> trigger id
var entered := {}  # trigger ids the player has stepped on
var doors := {}  # id -> {cells, open, locked, kind, body, panels, t}
var uses := {}  # id -> {pos, hold, text, done, need, t, enabled}
var pickups: Array = []  # {kind, id, pos, node, taken}
var machines: Array = []
var lamps := {}  # power group -> [[light, bulb]]
var power := {}  # power group -> on
var groups := {}  # group -> [soldiers and machines]
var wave_spots := {}  # spawn id -> [positions]
var collapse_zones := {}  # zone id -> [cells]
var allies := {}  # name -> soldier
var ids := {}  # soldier or machine -> its id, for checkpoints
var dead := {}  # ids of the killed
var fired: Array = []  # event ids in the order they fired
var fired_at := {}  # event id -> clock
var used := {}  # use ids done
var taken := {}  # pickup ids taken
var keys := {}  # keycards held
var has_mask := false
var objective := ""
var objective_mark := ""
var objective_group := ""
var clock := 0.0
var lines: Array = []  # dialogue waiting: [speaker, text, seconds]
var line: Array = []  # the line on screen
var line_t := 0.0
var toast := ""  # "Checkpoint", "Objective complete"...
var toast_t := 0.0
var title := ["", ""]
var title_t := 0.0
var fade := 1.0
var fade_want := 0.0
var fade_then: Callable
var countdown := -1.0
var alarm := false
var alarm_t := 0.0
var checkpoint := {}
var respawn_t := 0.0
var interact_t := 0.0
var interact_id := ""
var hint := ""
var hitmark_t := 0.0
var kill_mark := false
var boss = null
var behemoth = null
var cine: Dictionary = {}
var cine_t := 0.0
var cine_i := 0
var restoring := false
var done := false
var stats := {"time": 0.0, "kills": 0, "headshots": 0, "shots": 0, "hits": 0, "deaths": 0}
var shot_counted := false
var torch_on := false
var ambient: AudioStreamPlayer
var start_loadout := {}
var intel_new: Array = []
var low_warned := false


func start(game_ref, options: Dictionary) -> void:
	game = game_ref
	settings = options
	phase = "live"
	bomb_state = "none"
	mission_i = options.get("mission", 0)
	difficulty = options.get("difficulty", 1)
	area_i = options.get("area", 0)
	mission = Campaign.mission(mission_i)
	start_loadout = options.get("loadout", mission["loadout"])
	game.sfx.load_campaign()
	ambient = AudioStreamPlayer.new()
	ambient.volume_db = -14.0
	add_child(ambient)
	view = ViewScript.new()
	add_child(view)
	view.setup(self, game)
	_build_area({})
	if area_i == 0 and mission.has("intro"):
		_run([["cine", mission["intro"]]], false)


# --- Building an area ----------------------------------------------------------------------

func _build_area(snap: Dictionary) -> void:
	_clear()
	area = mission["areas"][area_i]
	var data: Dictionary = Campaign.THEMES[area.get("theme", "night")].duplicate()
	for key: String in area:
		data[key] = area[key]
	data["name"] = "%s_%d" % [mission["id"], area_i]
	legend = area.get("legend", {})
	world = WorldScript.new()
	add_child(world)
	world.build(game, self, data)
	hazards = HazardsScript.new()
	add_child(hazards)
	hazards.setup(world, self, game)
	restoring = not snap.is_empty()
	dead = snap.get("dead", {}).duplicate()
	taken = snap.get("taken", {}).duplicate()
	used = snap.get("used", {}).duplicate()
	keys = snap.get("keys", {}).duplicate()
	has_mask = snap.get("mask", false)
	var start_at := Vector3.ZERO
	var clusters := {}  # legend char -> {cells}
	for z in world.depth:
		var row: String = world.rows[z]
		for x in row.length():
			var ch := row[x]
			if not legend.has(ch):
				continue
			var e: Dictionary = legend[ch]
			var c := Vector2i(x, z)
			var p: Vector3 = world.center(c)
			if e.has("player"):
				start_at = p
			if e.has("mark"):
				if not markers.has(e["mark"]):
					markers[e["mark"]] = []
				markers[e["mark"]].append(p)
			if e.has("trigger"):
				trigger_cells[c] = e["trigger"]
			if e.has("spawn"):
				if not wave_spots.has(e["spawn"]):
					wave_spots[e["spawn"]] = []
				wave_spots[e["spawn"]].append(p)
			if e.has("collapse"):
				if not collapse_zones.has(e["collapse"]):
					collapse_zones[e["collapse"]] = []
				collapse_zones[e["collapse"]].append(c)
			if e.has("door"):
				_add_door_cell(e, c)
			if e.has("prop") or e.has("use"):
				if not clusters.has(ch):
					clusters[ch] = {}
				clusters[ch][c] = true
			if e.has("hazard"):
				hazards.add(e["hazard"], p, e.get("id", ""), e.get("on", true))
			if e.has("lamp"):
				_add_lamp(e, c)
			if e.has("corpse"):
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(c)
				var body := Props.corpse(e["corpse"], rng)
				body.position = p + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
				world.add_child(body)
			if e.has("item"):
				var id: String = e.get("id", "%s_%d_%d" % [e["item"], x, z])
				if not taken.has(id):
					_add_pickup(e["item"], id, p)
	for ch: String in clusters:
		for cells: Array in _split(clusters[ch]):
			_add_prop(legend[ch], cells)
	_build_doors()
	# The player.
	human = SoldierScript.new()
	human.faction = "mercer"
	add_child(human)
	human.setup(world, self, game, "att", 0, tr("you"), true)
	soldiers.append(human)
	var spot: Vector3 = snap.get("spot", start_at)
	var face: float = snap.get("yaw", _face_toward(spot, area.get("face", "")))
	human.respawn(spot + Vector3(0, 0.05, 0), face, true)
	_apply_loadout(human, snap.get("loadout", start_loadout))
	# Everyone else placed on the map.
	for z in world.depth:
		var row: String = world.rows[z]
		for x in row.length():
			var e: Dictionary = legend.get(row[x], {})
			if e.has("enemy") and not e.get("wave", false):
				var id := "e_%d_%d" % [x, z]
				if not dead.has(id):
					_spawn_enemy(e["enemy"], world.center(Vector2i(x, z)), e, id, spot)
			if e.has("machine"):
				var id := "m_%d_%d" % [x, z]
				if not dead.has(id):
					_spawn_machine(e, world.center(Vector2i(x, z)), id, spot)
			if e.has("ally") and not allies.has(e["ally"]):
				_spawn_ally(e["ally"], world.center(Vector2i(x, z)), e.get("mode", "follow"))
	for name: String in snap.get("allies", {}):
		if not allies.has(name):
			_spawn_ally(name, spot + Vector3(randf_range(-1.5, 1.5), 0, 1.5), "follow")
	view.on_round_start()
	torch_on = data.get("dark", false)
	view.set_torch(torch_on)
	_ambient(area.get("ambience", ""))
	# Events: replay what already happened (restoring a checkpoint), then start.
	fired = []
	fired_at = {}
	if restoring:
		for id: String in snap.get("fired", []):
			var ev := _event(id)
			fired.append(id)
			fired_at[id] = -999.0
			var lasting: Array = []
			for action: Array in ev.get("do", []):
				if action[0] in LASTING:
					lasting.append(action)
			_run(lasting, true)
		objective = snap.get("objective", "")
		objective_mark = snap.get("objective_mark", "")
		objective_group = snap.get("objective_group", "")
		countdown = snap.get("countdown", -1.0)
	restoring = false
	clock = 0.0
	fade = 1.0
	fade_want = 0.0
	if snap.is_empty():
		if not (area_i == 0 and mission.has("intro")):
			title = [tr(area.get("title", mission["title"])), tr(area.get("subtitle", mission["location"]))]
			title_t = 6.0
		_save_checkpoint()  # every area starts with a checkpoint


func _clear() -> void:
	for s in soldiers:
		s.queue_free()
	soldiers.clear()
	for m in machines:
		m.queue_free()
	machines.clear()
	if world != null:
		world.queue_free()
		world = null
	if hazards != null:
		hazards.queue_free()
	if behemoth != null:
		behemoth.queue_free()
		behemoth = null
	boss = null
	markers.clear()
	trigger_cells.clear()
	entered.clear()
	doors.clear()
	uses.clear()
	pickups.clear()
	lamps.clear()
	power.clear()
	groups.clear()
	wave_spots.clear()
	collapse_zones.clear()
	allies.clear()
	ids.clear()
	lines.clear()
	line = []
	alarm = false
	cine = {}
	feed.clear()
	spotted.clear()


## Splits a set of cells into connected pieces.
func _split(cells: Dictionary) -> Array:
	var left := cells.duplicate()
	var out: Array = []
	while not left.is_empty():
		var first: Vector2i = left.keys()[0]
		var piece: Array = []
		var todo: Array = [first]
		left.erase(first)
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			piece.append(c)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if left.has(c + d):
					left.erase(c + d)
					todo.append(c + d)
		out.append(piece)
	return out


func _bounds(cells: Array) -> Rect2i:
	var r := Rect2i(cells[0], Vector2i.ONE)
	for c: Vector2i in cells:
		r = r.expand(c).expand(c + Vector2i.ONE)
	return r


## Which way to face from p: toward a mark, a compass point ("n", "e", "s", "w"), or the open side.
func _face_toward(p: Vector3, toward) -> float:
	if toward is String and markers.has(toward):
		var to: Vector3 = markers[toward][0] - p
		return atan2(-to.x, -to.z)
	match toward:
		"n":
			return 0.0
		"w":
			return PI / 2.0
		"s":
			return PI
		"e":
			return -PI / 2.0
	return 0.0


func _add_prop(e: Dictionary, cells: Array) -> void:
	var r := _bounds(cells)
	var size: Vector2 = Vector2(r.size.x, r.size.y) * world.CELL
	var along_z := r.size.y > r.size.x
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(r.position)
	var center := Vector3((r.position.x + r.size.x / 2.0) * world.CELL, 0, (r.position.y + r.size.y / 2.0) * world.CELL)
	if e.has("prop"):
		var node: Node3D = Props.make(e["prop"], Vector2(size.y, size.x) if along_z else size, rng)
		node.position = center
		node.rotation.y = (PI / 2.0 if along_z else 0.0) + deg_to_rad(e.get("turn", 0.0)) + rng.randf_range(-1, 1) * e.get("jitter", 0.0)
		world.add_child(node)
		if e.has("use"):
			node.name = "Prop_" + e["use"]
	if e.has("use"):
		uses[e["use"]] = {"pos": center, "hold": e.get("hold", 1.2), "text": e.get("text", "use_generic"), "done": used.has(e["use"]),
			"need": e.get("need", ""), "t": 0.0, "enabled": e.get("enabled", true), "reach": maxf(size.x, size.y) / 2.0 + 1.3}


func _add_lamp(e: Dictionary, c: Vector2i) -> void:
	var roof := 0.0
	for roof_entry: Array in world.roofs:
		if (roof_entry[0] as Rect2i).has_point(c):
			roof = roof_entry[1]
	var made: Array = Props.lamp(e["lamp"], roof if roof > 0.0 else 4.0)
	var node: Node3D = made[0]
	node.position = world.center(c)
	node.rotation.y = _face_toward(node.position, e.get("face", ""))
	world.add_child(node)
	var group: String = e.get("power", "")
	if not lamps.has(group):
		lamps[group] = []
	lamps[group].append(made)
	if group != "":
		_light(made, power.get(group, false))


func _light(made: Array, on: bool) -> void:
	(made[1] as Light3D).visible = on
	(made[2] as MeshInstance3D).visible = on


func _add_pickup(kind: String, id: String, p: Vector3) -> void:
	var node := Props.pickup(kind)
	node.position = p + Vector3(0, 0.05, 0)
	world.add_child(node)
	if kind == "intel" or kind.begins_with("key"):
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.85, 0.4) if kind == "intel" else Color(0.6, 0.8, 1.0)
		glow.light_energy = 0.6
		glow.omni_range = 2.0
		glow.position.y = 0.4
		node.add_child(glow)
	pickups.append({"kind": kind, "id": id, "pos": p, "node": node, "taken": false})


# --- Doors ---------------------------------------------------------------------------------

func _add_door_cell(e: Dictionary, c: Vector2i) -> void:
	var id: String = e["door"]
	if not doors.has(id):
		doors[id] = {"cells": [], "open": false, "locked": e.get("locked", false), "kind": e.get("kind", "blast"),
			"body": null, "panels": [], "t": 0.0, "height": e.get("height", 0.0)}
	doors[id]["cells"].append(c)


func _build_doors() -> void:
	for id: String in doors:
		var d: Dictionary = doors[id]
		var body := StaticBody3D.new()
		body.collision_layer = world.LAYER_WORLD
		body.collision_mask = 0
		world.add_child(body)
		d["body"] = body
		var h: float = d["height"] if d["height"] > 0.0 else minf(world.wall_height, 3.4)
		d["height"] = h
		var color := {"blast": Color(0.35, 0.36, 0.37), "gate": Color(0.3, 0.32, 0.28), "shutter": Color(0.5, 0.5, 0.48),
			"wood": Color(0.42, 0.3, 0.2), "glass": Color(0.5, 0.7, 0.7), "auto": Color(0.7, 0.72, 0.74)}.get(d["kind"], Color(0.4, 0.4, 0.4)) as Color
		for c: Vector2i in d["cells"]:
			var along_x: bool = world.is_wall(c + Vector2i(1, 0)) or world.is_wall(c + Vector2i(-1, 0)) or (d["cells"] as Array).has(c + Vector2i(1, 0)) or (d["cells"] as Array).has(c + Vector2i(-1, 0))
			var size := Vector3(world.CELL, h, 0.25) if along_x else Vector3(0.25, h, world.CELL)
			var panel := Node3D.new()
			panel.position = world.center(c, 0.0)
			world.add_child(panel)
			Models.vm = false
			if d["kind"] == "glass":
				var pane := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = size
				pane.mesh = mesh
				pane.material_override = Tex.glass()
				pane.position.y = h / 2.0
				panel.add_child(pane)
			else:
				Models.box(panel, size, Vector3(0, h / 2.0, 0), color, 0.4)
				var stripe := Vector3(size.x * 0.96, 0.12, size.z * 1.1)
				Models.box(panel, stripe, Vector3(0, h * 0.45, 0), Color(0.8, 0.62, 0.1) if d["kind"] == "blast" else color.darkened(0.3))
				if d["kind"] == "gate":
					for i in 5:
						var bar := Vector3(0.06, h, size.z * 1.2) if along_x else Vector3(size.x * 1.2, h, 0.06)
						var off := Vector3(-0.8 + i * 0.4, h / 2.0, 0) if along_x else Vector3(0, h / 2.0, -0.8 + i * 0.4)
						Models.box(panel, bar, off, color.darkened(0.2), 0.5)
				Models.merge(panel)
			d["panels"].append(panel)
			# Above the door, up to the wall top.
			if world.wall_height - h > 0.1 and not _roofed(c):
				Models.box(world, Vector3(size.x, world.wall_height - h, maxf(size.z, 0.5)) if along_x else Vector3(maxf(size.x, 0.5), world.wall_height - h, size.z),
						world.center(c, h + (world.wall_height - h) / 2.0), Color(0.3, 0.31, 0.3))
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = size
			col.shape = box
			col.position = world.center(c, h / 2.0)
			body.add_child(col)
			world.set_blocked(c, true)


func _roofed(c: Vector2i) -> bool:
	for roof: Array in world.roofs:
		if (roof[0] as Rect2i).has_point(c):
			return true
	return false


func _open_door(id: String, silent := false) -> void:
	if not doors.has(id) or doors[id]["open"]:
		return
	var d: Dictionary = doors[id]
	d["open"] = true
	d["locked"] = false
	for col in (d["body"] as StaticBody3D).get_children():
		(col as CollisionShape3D).set_deferred("disabled", true)
	for c: Vector2i in d["cells"]:
		world.set_blocked(c, false)
	if d["kind"] == "glass":
		for panel: Node3D in d["panels"]:
			world.burst(panel.position + Vector3.UP * 1.5, Color(0.7, 0.9, 0.9), 16, 5.0, 0.06)
			panel.visible = false
		if not silent:
			game.sfx.play_at("glass" if game.sfx.sounds.has("glass") else "impact", (d["panels"][0] as Node3D).position, 2.0)
		return
	d["t"] = 0.0 if not silent else 1.0
	if not silent:
		game.sfx.play_at("door" if game.sfx.sounds.has("door") else "bolt", (d["panels"][0] as Node3D).position + Vector3.UP, 0.0)


func _close_door(id: String) -> void:
	if not doors.has(id) or not doors[id]["open"]:
		return
	var d: Dictionary = doors[id]
	d["open"] = false
	for col in (d["body"] as StaticBody3D).get_children():
		(col as CollisionShape3D).set_deferred("disabled", false)
	for c: Vector2i in d["cells"]:
		world.set_blocked(c, true)
	for panel: Node3D in d["panels"]:
		panel.visible = true
	d["t"] = 0.0
	game.sfx.play_at("door" if game.sfx.sounds.has("door") else "bolt", (d["panels"][0] as Node3D).position + Vector3.UP, 0.0)


func _run_doors(delta: float) -> void:
	for id: String in doors:
		var d: Dictionary = doors[id]
		d["t"] = minf(d["t"] + delta, 1.0)
		var k: float = smoothstep(0.0, 1.0, d["t"])
		var lift: float = d["height"] * (k if d["open"] else 1.0 - k) if d["kind"] != "glass" else 0.0
		for panel: Node3D in d["panels"]:
			if d["kind"] in ["gate", "wood", "auto"]:
				panel.scale.y = 1.0 - lift / d["height"] * 0.95  # folds away
			else:
				panel.position.y = lift * 0.97
		# A locked door opens for the player carrying its key.
		var need = d["locked"]
		if need is String and need.begins_with("key") and keys.has(need) and not d["open"]:
			for c: Vector2i in d["cells"]:
				if human.alive and human.position.distance_to(world.center(c)) < 3.0:
					_open_door(id)
					game.message(tr("door_unlocked"))
					break


# --- People and machines -------------------------------------------------------------------

func _spawn_enemy(kind: String, p: Vector3, e: Dictionary, id: String, look_from: Vector3) -> Variant:
	var spec: Dictionary = Campaign.ENEMIES[kind]
	var s = SoldierScript.new()
	s.faction = spec["faction"]
	s.body_scale = spec.get("scale", 1.0)
	s.blood = spec.get("blood", s.blood)
	add_child(s)
	s.setup(world, self, game, spec["team"], 1 if spec["team"] == "def" else 2, tr("enemy_" + kind), false)
	var face: float = _face_toward(p, e.get("face", "")) if e.has("face") else atan2(-(look_from - p).x, -(look_from - p).z)
	s.respawn(p + Vector3(0, 0.05, 0), face, true)
	s.health = spec["health"] * (1.0 + (difficulty - 1) * 0.1)
	s.armor = spec.get("armor", 0.0)
	s.helmet = spec.get("helmet", false)
	var skill: int = clampi(Campaign.DIFFICULTY[difficulty]["skill"] + spec.get("skill", 0), 0, 3)
	var brain
	match spec["brain"]:
		"grunt":
			var guns: Array = spec["guns"]
			var gun: String = e.get("gun", guns[hash(id) % guns.size()])
			s.give(spec["pistol"])
			s.give(gun)
			for g: String in spec.get("grenades", []):
				if randf() < 0.5:
					s.give(g)
			brain = GruntScript.new()
			brain.setup(s, self, world, skill)
			s.brain = brain
			brain.begin(e.get("mode", "guard"), s.position, face)
			if world.data.get("dark", false):
				_weapon_light(s)
		"beast":
			brain = BeastScript.new()
			brain.setup(s, self, world, skill)
			s.brain = brain
			s.current = spec["gun"]
			s._arm()
			brain.begin(e.get("mode", "roam"), kind, s.position)
		"boss":
			s.give(spec["gun"])
			brain = BossScript.new()
			brain.setup(s, self, world, skill)
			s.brain = brain
			boss = s
	soldiers.append(s)
	ids[s] = id
	var group: String = e.get("group", "")
	if group != "":
		if not groups.has(group):
			groups[group] = []
		groups[group].append(s)
	return s


## A lamp on the gun, so soldiers in the dark can be seen coming (and see).
func _weapon_light(s) -> void:
	var spot := SpotLight3D.new()
	spot.light_energy = 2.5
	spot.spot_range = 16.0
	spot.spot_angle = 22.0
	spot.light_color = Color(1.0, 0.95, 0.85)
	spot.position = Vector3(0.1, -0.1, -0.5)
	s.parts["aim"].add_child(spot)


func _spawn_machine(e: Dictionary, p: Vector3, id: String, look_from: Vector3) -> void:
	var m = MachineScript.new()
	m.power = e.get("power", "")
	m.active = m.power == "" or power.get(m.power, false)
	world.add_child(m)
	var face: float = _face_toward(p, e.get("face", "")) if e.has("face") else atan2(-(look_from - p).x, -(look_from - p).z)
	m.setup(world, self, game, e["machine"], p, face)
	machines.append(m)
	ids[m] = id
	var group: String = e.get("group", "")
	if group != "":
		if not groups.has(group):
			groups[group] = []
		groups[group].append(m)


func _spawn_ally(name: String, p: Vector3, mode: String) -> void:
	var spec: Dictionary = Campaign.ALLIES[name]
	var s = SoldierScript.new()
	s.faction = "mercer"
	add_child(s)
	s.setup(world, self, game, "att", 0, spec["nick"], false)
	s.respawn(p + Vector3(0, 0.05, 0), human.yaw, true)
	s.armor = 100.0
	s.helmet = true
	s.give(spec["pistol"])
	s.give(spec["gun"])
	var brain = GruntScript.new()
	brain.setup(s, self, world, 2)
	s.brain = brain
	brain.leader = human
	brain.begin(mode, s.position, human.yaw)
	soldiers.append(s)
	allies[name] = s


func _apply_loadout(s, l: Dictionary) -> void:
	if l.get("primary", "") == "" and l.get("secondary", "") == "":
		l = mission["loadout"]
	s.primary = ""
	s.secondary = ""
	s.grenades.clear()
	s.mags.clear()
	s.reserves.clear()
	for key in ["secondary", "primary"]:
		var id: String = l.get(key, "")
		if id != "":
			s.give(id)
			if l.has(key + "_ammo"):
				s.mags[id] = l[key + "_ammo"][0]
				s.reserves[id] = l[key + "_ammo"][1]
	for g: String in l.get("grenades", []):
		s.grenades.append(g)
	if not l.has("primary_ammo"):
		# A fresh start: twice the usual reserve, it's a long way.
		for id in [s.primary, s.secondary]:
			if id != "" and Weapons.is_gun(id):
				s.reserves[id] = Weapons.data(id)["reserve"] * 2
	s.armor = l.get("armor", 0.0)
	s.helmet = l.get("helmet", false)
	s.health = l.get("health", 100.0)
	s.current = ""
	s.equip(s.best_weapon())


func _loadout(s) -> Dictionary:
	var l := {"primary": s.primary, "secondary": s.secondary, "grenades": s.grenades.duplicate(),
		"armor": s.armor, "helmet": s.helmet, "health": maxf(s.health, 60.0)}
	for key in ["primary", "secondary"]:
		var id: String = l[key]
		if id != "":
			l[key + "_ammo"] = [s.mags.get(id, 0), s.reserves.get(id, 0)]
	return l


# --- Rules for everyone --------------------------------------------------------------------

func enemies_of(s) -> Array:
	var list := []
	for o in soldiers:
		if o.team != s.team:
			list.append(o)
	for m in machines:
		if m.team != s.team and m.alive and m.active:
			list.append(m)
	return list


func side_team(team: String) -> Array:
	var list := []
	for s in soldiers:
		if s.team == team:
			list.append(s)
	return list


func can_buy(_s) -> bool:
	return false


func can_plant() -> bool:
	return false


func time_left() -> float:
	return maxf(countdown, 0.0)


func damage_scale(victim, attacker) -> float:
	if attacker == human and victim != human:
		hitmark_t = 0.15
		if not shot_counted:
			shot_counted = true
			stats["hits"] += 1
		if victim == boss and _boss_shielded():
			return 0.15
		return 1.0
	if victim == human:
		return Campaign.DIFFICULTY[difficulty]["taken"] * (0.6 if attacker == null else 1.0)
	if victim in allies.values():
		return 0.5
	return 1.0


func spare(victim) -> bool:
	return victim in allies.values()


func _boss_shielded() -> bool:
	for m in machines:
		if m.kind == "conduit" and m.alive:
			return true
	return false


## A squad-mate saw the enemy: everyone near enough comes to help.
func alert_squad(caller, pos: Vector3) -> void:
	for s in soldiers:
		if s != caller and s.alive and s.team == caller.team and s.brain != null and s.position.distance_to(caller.position) < 32.0:
			if s.brain.has_method("alert") and s.brain.target == null:
				s.brain.alert(pos)


func report_contact(_pos: Vector3, _reporter) -> void:
	pass


func on_death(victim, killer, weapon: String, headshot: bool) -> void:
	if killer == human and victim != human:
		stats["kills"] += 1
		if headshot:
			stats["headshots"] += 1
		kill_mark = true
		hitmark_t = 0.3
		game.sfx.play("hit_head" if headshot else "hit_flesh", -6.0)
	if ids.has(victim):
		dead[ids[victim]] = true
	for s in soldiers:
		if s.brain != null and s.alive and s.team == victim.team and s.position.distance_to(victim.position) < 25.0:
			s.brain.hear(victim.position, killer)
	if victim == human:
		stats["deaths"] += 1
		view.on_player_died(killer)
		respawn_t = 3.5
		line = []
		lines.clear()


func on_machine_destroyed(m, killer, _weapon: String) -> void:
	if killer == human:
		stats["kills"] += 1
		kill_mark = true
		hitmark_t = 0.3
	if ids.has(m):
		dead[ids[m]] = true


func blast(pos: Vector3, radius: float, damage: float, owner, weapon: String) -> void:
	super.blast(pos, radius, damage, owner, weapon)
	for m in machines:
		if m.alive and m.eye_position().distance_to(pos) < radius and world.clear_line(pos, m.eye_position()):
			m.take_blast(damage * (1.0 - m.eye_position().distance_to(pos) / radius), owner, weapon)


## The player pressed use: pick up the weapon at their feet (using things is held, see _interact).
func try_pickup(s) -> void:
	if interact_id == "":
		super.try_pickup(s)


## Walking over a gun they already carry takes its ammunition; over pickups takes them.
func _auto_pickups() -> void:
	for s in soldiers:
		if not s.alive:
			continue
		for d in world.drops.duplicate():
			if d.get_meta("age") < 0.8:
				continue
			if Vector2(d.position.x - s.position.x, d.position.z - s.position.z).length() > 1.1 or absf(d.position.y - s.position.y) > 1.4:
				continue
			var id: String = d.get_meta("id")
			if id == "bomb" or not Weapons.LIST.has(id):
				continue
			if s.is_human and Weapons.is_gun(id) and d.get_meta("mag") + d.get_meta("reserve") > 0:
				# Scavenging: any dropped gun refills the guns Mercer carries. The gun itself stays.
				var got := false
				for mine in [s.primary, s.secondary]:
					if mine == "" or not Weapons.is_gun(mine):
						continue
					var cap: int = Weapons.data(mine)["reserve"] * 2
					var before: int = s.reserves[mine]
					var share: int = Weapons.data(mine)["mag"] * (2 if mine == id else 1)
					s.reserves[mine] = mini(before + share, cap)
					got = got or s.reserves[mine] > before
				if got:
					d.set_meta("mag", 0)
					d.set_meta("reserve", 0)
					game.sfx.play("pickup")
					game.message(tr("got_ammo") % Weapons.name_of(s.current if Weapons.is_gun(s.current) else s.primary))
					low_warned = false
				elif s.owns(id):
					continue
			elif Weapons.data(id)["slot"] == 0 and s.primary == "" or Weapons.data(id)["slot"] == 1 and s.secondary == "":
				_take(s, d)


func _run_pickups() -> void:
	if not human.alive:
		return
	for p: Dictionary in pickups:
		if p["taken"] or human.position.distance_to(p["pos"]) > 1.3:
			continue
		var took := true
		match p["kind"]:
			"medkit":
				if human.health >= 100.0:
					took = false
				else:
					human.health = minf(human.health + 50.0, 100.0)
					game.message(tr("got_medkit"))
			"armor":
				if human.armor >= 100.0:
					took = false
				else:
					human.armor = 100.0
					human.helmet = true
					game.message(tr("got_armor"))
			"ammo":
				var any := false
				for id in [human.primary, human.secondary]:
					if id != "" and Weapons.is_gun(id):
						var full: int = Weapons.data(id)["reserve"] * 2
						if human.reserves[id] < full:
							human.reserves[id] = mini(human.reserves[id] + Weapons.data(id)["mag"] * 3, full)
							any = true
				if human.grenades.size() < 2:
					human.grenades.append("he")
					any = true
				took = any
				if took:
					game.message(tr("got_ammo_box"))
			"intel":
				game.intel_found(p["id"])
				intel_new.append(p["id"])
				toast = tr("intel_found") % [tr(p["id"] + "_title")]
				toast_t = 4.0
				game.sfx.play("intel" if game.sfx.sounds.has("intel") else "defused")
			"gasmask":
				has_mask = true
				game.message(tr("got_mask"))
			_:
				if p["kind"].begins_with("key"):
					keys[p["kind"]] = true
					game.message(tr("got_" + p["kind"]))
		if took:
			p["taken"] = true
			taken[p["id"]] = true
			(p["node"] as Node3D).queue_free()
			if p["kind"] != "intel":
				game.sfx.play("pickup")
			_fire_when(["picked", p["id"]])


# --- Running -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	for i in range(feed.size() - 1, -1, -1):
		feed[i]["t"] -= delta
		if feed[i]["t"] <= 0.0:
			feed.remove_at(i)
	if world == null or human == null:
		return
	clock += delta
	if not done and human.alive:
		stats["time"] += delta
	# Accuracy: a shot is counted once, however many pellets hit.
	if human.since_shot == 0.0 and Weapons.is_gun(human.current):
		stats["shots"] += 1
		shot_counted = false
	hitmark_t = maxf(hitmark_t - delta, 0.0)
	if hitmark_t == 0.0:
		kill_mark = false
	toast_t = maxf(toast_t - delta, 0.0)
	title_t = maxf(title_t - delta, 0.0)
	_run_fade(delta)
	_run_dialogue(delta)
	if not cine.is_empty():
		return
	_run_doors(delta)
	_run_pickups()
	_interact(delta)
	_run_allies(delta)
	_run_alarm(delta)
	if human.alive:
		_triggers()
		_check_events()
	if countdown > 0.0:
		countdown -= delta
		if countdown <= 0.0:
			countdown = 0.0
			_fire_when(["timer"])
			if human.alive and not _has_event_for(["timer"]):
				human.take_blast(999.0, null, "strike")
	# Running low: say where more ammunition comes from, once.
	if human.alive and not low_warned and Weapons.is_gun(human.current) and human.reserves.get(human.current, 0) + human.mags.get(human.current, 0) <= Weapons.data(human.current)["mag"]:
		low_warned = true
		game.message(tr("low_ammo"))
	if respawn_t > 0.0:
		respawn_t -= delta
		if respawn_t <= 0.0:
			_fade_then(_restore_checkpoint)
	spot_t -= delta
	if spot_t <= 0.0:
		spot_t = 0.2
		_update_spotted(0.2)
	pickup_t -= delta
	if pickup_t <= 0.0:
		pickup_t = 0.1
		_auto_pickups()


func _unhandled_input(event: InputEvent) -> void:
	if not game.can_control():
		return
	if event.is_action_pressed("torch"):
		torch_on = not torch_on
		view.set_torch(torch_on)
		game.sfx.play("zoom", -6.0)
	elif not cine.is_empty() and (event.is_action_pressed("jump") or event.is_action_pressed("pause") and false):
		_end_cine()


## Held use near something usable fills a bar, then it is done.
func _interact(delta: float) -> void:
	hint = ""
	interact_id = ""
	if not human.alive:
		return
	var eye: Vector3 = human.eye_position()
	var facing: Vector3 = human.view_basis() * Vector3.FORWARD
	var best := ""
	var best_d := INF
	for id: String in uses:
		var u: Dictionary = uses[id]
		if u["done"] or not u["enabled"]:
			continue
		var p: Vector3 = u["pos"]
		var d := Vector2(p.x - human.position.x, p.z - human.position.z).length()
		if d > u["reach"] or d > best_d:
			continue
		var to := (p + Vector3.UP - eye).normalized()
		if facing.dot(to) < 0.3 and d > 1.2:
			continue
		best = id
		best_d = d
	if best == "":
		return
	var u: Dictionary = uses[best]
	interact_id = best
	if u["need"] != "" and not keys.has(u["need"]) and not (u["need"] == "gasmask" and has_mask):
		hint = tr("needs_" + u["need"])
		return
	hint = tr("hold_to") % [game.hud._key("use"), tr(u["text"])]
	if human.want_use:
		if u["t"] == 0.0:
			game.sfx.play("key", -4.0)
		u["t"] += delta
		if u["t"] >= u["hold"]:
			u["done"] = true
			used[best] = true
			game.sfx.play("use_done" if game.sfx.sounds.has("use_done") else "defused", -4.0)
			_fire_when(["used", best])
	else:
		u["t"] = 0.0


## Allies are never killed, only wounded: they get back up and heal.
func _run_allies(delta: float) -> void:
	for name: String in allies:
		var a = allies[name]
		if a.hurt_t <= 0.0:
			a.health = minf(a.health + delta * 8.0, 100.0)
		a.want_crouch = a.want_crouch or a.health < 15.0


func _run_alarm(delta: float) -> void:
	if not alarm:
		return
	alarm_t -= delta
	if alarm_t <= 0.0:
		alarm_t = 1.6
		if game.sfx.sounds.has("alarm"):
			game.sfx.play("alarm", -10.0)
	var pulse := 0.5 + 0.5 * sin(clock * 6.0)
	for made: Array in lamps.get("alarm", []):
		(made[1] as Light3D).light_energy = 0.4 + pulse * 2.4


func _triggers() -> void:
	if not human.alive:
		return
	var c: Vector2i = world.cell_of(human.position)
	if trigger_cells.has(c) and not entered.has(trigger_cells[c]):
		entered[trigger_cells[c]] = true
		_fire_when(["enter", trigger_cells[c]])


# --- Events --------------------------------------------------------------------------------

func _event(id: String) -> Dictionary:
	for ev: Dictionary in area.get("events", []):
		if ev["id"] == id:
			return ev
	return {}


func _has_event_for(when: Array) -> bool:
	for ev: Dictionary in area.get("events", []):
		if ev["when"] == when:
			return true
	return false


## Fires the events that wait for exactly this.
func _fire_when(when: Array) -> void:
	for ev: Dictionary in area.get("events", []):
		if not fired.has(ev["id"]) and ev["when"] == when:
			_fire(ev)


func _fire(ev: Dictionary) -> void:
	fired.append(ev["id"])
	fired_at[ev["id"]] = clock
	_run(ev.get("do", []), false)


func _check_events() -> void:
	for ev: Dictionary in area.get("events", []):
		if fired.has(ev["id"]):
			continue
		if _met(ev["when"]):
			_fire(ev)
			if not cine.is_empty():
				return


func _met(when: Array) -> bool:
	match when[0]:
		"start":
			return true
		"after":
			return fired_at.has(when[1]) and clock - fired_at[when[1]] >= when[2]
		"dead":
			var list: Array = groups.get(when[1], [])
			if list.is_empty():
				return false
			var left := 0
			for s in list:
				if s.alive:
					left += 1
			return left <= (when[2] if when.size() > 2 else 0)
		"near":
			return markers.has(when[1]) and human.alive and human.position.distance_to(markers[when[1]][0]) < when[2]
		"all":
			for part: Array in when[1]:
				if not _met(part):
					return false
			return true
		"entered":
			return entered.has(when[1])
		"has_used":
			return used.has(when[1])
		"boss_below":
			return boss != null and boss.health < when[1]
	return false


func _run(actions: Array, silent: bool) -> void:
	for a: Array in actions:
		match a[0]:
			"say":
				if not silent:
					lines.append([a[1], a[2], a[3] if a.size() > 3 else 0.0])
			"obj":
				objective = a[1]
				objective_mark = a[2] if a.size() > 2 else ""
				objective_group = a[3] if a.size() > 3 else ""
				if not silent:
					toast = tr("new_objective")
					toast_t = 3.0
					game.sfx.play("objective" if game.sfx.sounds.has("objective") else "radio", -4.0)
			"spawn":
				_spawn_wave(a, silent)
			"wake":
				for s in groups.get(a[1], []):
					if s.alive and s.brain != null and s.brain.has_method("wake"):
						s.brain.wake(a[2] if a.size() > 2 else true)
			"open":
				_open_door(a[1], silent)
			"close":
				_close_door(a[1])
			"lock":
				if doors.has(a[1]):
					doors[a[1]]["locked"] = a[2] if a.size() > 2 else true
			"unlock":
				if doors.has(a[1]):
					doors[a[1]]["locked"] = false
			"power":
				var on: bool = a[2] if a.size() > 2 else true
				power[a[1]] = on
				for made: Array in lamps.get(a[1], []):
					_light(made, on)
				for m in machines:
					if m.power == a[1] and m.alive:
						m.set_active(on)
				if not silent and on:
					game.sfx.play("power_on" if game.sfx.sounds.has("power_on") else "defused", -2.0)
			"hazard":
				hazards.set_on(a[1], a[2])
			"alarm":
				alarm = a[1]
				power["alarm"] = alarm
				for made: Array in lamps.get("alarm", []):
					_light(made, alarm)
			"ally":
				_ally_action(a)
			"collapse":
				hazards.collapse(collapse_zones.get(a[1], []))
			"debris":
				if not silent and markers.has(a[1]):
					hazards.debris(markers[a[1]][0], a[2], a[3])
			"mask":
				has_mask = true
			"give":
				human.give(a[1])
			"checkpoint":
				if not silent:
					_save_checkpoint()
					toast = tr("checkpoint")
					toast_t = 2.5
			"shake":
				if not silent:
					game.shake(a[1])
			"boom":
				if not silent and markers.has(a[1]):
					for p: Vector3 in markers[a[1]]:
						world.explosion(p + Vector3.UP * 0.5, a[2] if a.size() > 2 else 2.0)
					game.sfx.play_at("explode", markers[a[1]][0], 4.0)
					game.shake(0.4)
			"sound":
				if not silent and game.sfx.sounds.has(a[1]):
					if a.size() > 2 and markers.has(a[2]):
						game.sfx.play_at(a[1], markers[a[2]][0] + Vector3.UP, a[3] if a.size() > 3 else 0.0)
					else:
						game.sfx.play(a[1], a[3] if a.size() > 3 else -4.0)
			"glimpse":
				if not silent:
					_glimpse(a[1], a[2])
			"timer":
				countdown = a[1]
			"stop_timer":
				countdown = -1.0
			"enable":
				if uses.has(a[1]):
					uses[a[1]]["enabled"] = true
			"hint":
				if not silent:
					game.message(tr(a[1]))
			"title":
				if not silent:
					title = [tr(a[1]), tr(a[2]) if a.size() > 2 else ""]
					title_t = 5.0
			"cine":
				if not silent:
					_start_cine(a[1])
			"behemoth":
				if not silent:
					_start_behemoth(a[1], a[2])
			"halt":
				if behemoth != null:
					behemoth.halt()
			"next":
				if not silent:
					_fade_then(_next_area)
			"complete":
				if not silent:
					_fade_then(_complete)


func _spawn_wave(a: Array, silent: bool) -> void:
	# ["spawn", spot id, enemy kind, count, mode, group]
	var spots: Array = wave_spots.get(a[1], [])
	if spots.is_empty():
		return
	var count: int = a[3]
	if difficulty >= 2:
		count += count / 4
	var group: String = a[5] if a.size() > 5 else a[1]
	for i in count:
		var id := "w_%s_%s_%d" % [a[1], group, i]
		if dead.has(id):
			continue
		var p: Vector3 = spots[i % spots.size()] + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
		_spawn_enemy(a[2], p, {"mode": a[4] if a.size() > 4 else "hunt", "group": group}, id, human.position)


func _ally_action(a: Array) -> void:
	# ["ally", name, "join" | "follow" | "stay" | "leave", mark]
	var name: String = a[1]
	match a[2]:
		"join":
			if not allies.has(name):
				var p: Vector3 = markers[a[3]][0] if a.size() > 3 and markers.has(a[3]) else human.position + Vector3(1.5, 0, 1.5)
				_spawn_ally(name, p, "follow")
		"follow":
			if allies.has(name):
				allies[name].brain.begin("follow", allies[name].position, allies[name].yaw)
		"stay":
			if allies.has(name):
				var p: Vector3 = markers[a[3]][0] if a.size() > 3 and markers.has(a[3]) else allies[name].position
				allies[name].brain.begin("hold", p, allies[name].yaw)
		"leave":
			if allies.has(name):
				despawn(allies[name])
				allies.erase(name)


## Something runs across, fast, from one mark to another, and is gone.
func _glimpse(from: String, to: String) -> void:
	if not markers.has(from) or not markers.has(to):
		return
	var s = _spawn_enemy("infected", markers[from][0], {"mode": "roam"}, "glimpse_%d" % clock, human.position)
	s.brain.mode = "runner"
	s.brain.home = markers[to][0]
	s.team = "neutral"
	for area_node in s.hitboxes:
		area_node.collision_layer = 0
	game.sfx.play_at("screech" if game.sfx.sounds.has("screech") else "pain", markers[from][0], 2.0)


func despawn(s) -> void:
	soldiers.erase(s)
	spotted.erase(s)
	s.queue_free()


# --- Checkpoints ---------------------------------------------------------------------------

func _save_checkpoint() -> void:
	if not human.alive:
		return  # never save a dead man's empty hands
	checkpoint = {"spot": human.position, "yaw": human.yaw, "loadout": _loadout(human), "fired": fired.duplicate(),
		"dead": dead.duplicate(), "taken": taken.duplicate(), "used": used.duplicate(), "keys": keys.duplicate(),
		"mask": has_mask, "objective": objective, "objective_mark": objective_mark, "objective_group": objective_group,
		"countdown": countdown, "allies": allies.keys()}
	var list := {}
	for name in allies:
		list[name] = true
	checkpoint["allies"] = list
	game.campaign_progress(mission_i, area_i, _loadout(human))


func _restore_checkpoint() -> void:
	var snap := checkpoint.duplicate(true)
	_build_area(snap)
	checkpoint = snap


func _next_area() -> void:
	var carry := _loadout(human)
	area_i += 1
	if area_i >= mission["areas"].size():
		_complete()
		return
	start_loadout = carry
	_build_area({})


func _complete() -> void:
	done = true
	ambient.stop()
	stats["intel"] = intel_new.size()
	game.mission_complete(mission_i, stats, _loadout(human))


# --- Dialogue, fades, cinematics -----------------------------------------------------------

func _run_dialogue(delta: float) -> void:
	if not line.is_empty():
		line_t -= delta
		if line_t <= 0.0:
			line = []
	if line.is_empty() and not lines.is_empty():
		line = lines.pop_front()
		var text: String = tr(line[1])
		var seconds: float = line[2] if line.size() > 2 else 0.0
		line_t = seconds if seconds > 0.0 else clampf(1.6 + text.length() * 0.055, 2.5, 9.0)
		if line[0] in ["hale", "pilot", "radio"]:
			game.sfx.play("radio", -12.0)


func _fade_then(then: Callable) -> void:
	fade_want = 1.0
	fade_then = then


func _run_fade(delta: float) -> void:
	fade = move_toward(fade, fade_want, delta * 1.6)
	if fade_want == 1.0 and fade >= 1.0 and fade_then.is_valid():
		var then := fade_then
		fade_then = Callable()
		fade_want = 0.0
		then.call()


func _start_cine(id: String) -> void:
	cine = area.get("cines", {}).get(id, mission.get("cines", {}).get(id, {}))
	if cine.is_empty():
		return
	cine_t = 0.0
	cine_i = 0
	human.frozen = true
	_cine_shot()


func _cine_shot() -> void:
	var shots: Array = cine["shots"]
	if cine_i >= shots.size():
		_end_cine()
		return
	var shot: Dictionary = shots[cine_i]
	for l: Array in shot.get("say", []):
		lines.append(l)
	if shot.has("sound") and game.sfx.sounds.has(shot["sound"]):
		game.sfx.play(shot["sound"], 0.0)
	if shot.get("shake", 0.0) > 0.0:
		game.shake(shot["shake"])
	if shot.get("boom", false):
		game.sfx.play("bomb_explode", 0.0)
	if shot.has("title"):
		title = [tr(shot["title"][0]), tr(shot["title"][1])]
		title_t = shot.get("t", 4.0)


func _end_cine() -> void:
	var then: Array = cine.get("then", [])
	cine = {}
	human.frozen = false
	lines.clear()
	line = []
	fade = 1.0
	_run(then, false)


func _point(p) -> Vector3:
	if p is Vector3:
		return p
	if p is Array:
		return (markers[p[0]][0] if markers.has(p[0]) else Vector3.ZERO) + Vector3(0, p[1], 0) + (p[2] if p.size() > 2 else Vector3.ZERO)
	return Vector3.ZERO


## The camera during cinematics (and, after death, while waiting to restart).
func camera_override(camera: Camera3D, delta: float) -> bool:
	if cine.is_empty():
		return false
	var shots: Array = cine["shots"]
	var shot: Dictionary = shots[cine_i]
	cine_t += delta
	var t: float = shot.get("t", 4.0)
	var k := clampf(cine_t / t, 0.0, 1.0)
	var ease_k := k * k * (3.0 - 2.0 * k)
	var from := _point(shot["from"])
	var to := _point(shot.get("to", shot["from"]))
	var at := from.lerp(to, ease_k)
	var look := _point(shot.get("look", shot.get("to", shot["from"]))).lerp(_point(shot.get("look_to", shot.get("look", shot.get("to", shot["from"])))), ease_k)
	camera.fov = shot.get("fov", 60.0)
	if at.distance_to(look) > 0.01:
		camera.global_transform = Transform3D(Basis.looking_at(look - at, Vector3.UP), at)
	if shot.get("roll", 0.0) != 0.0:
		camera.rotate_object_local(Vector3.FORWARD, shot["roll"] * ease_k)
	var shaking: float = view.shake
	if shaking > 0.0:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shaking * 0.08
	fade = shot.get("fade", 0.0) * k if shot.has("fade") else (1.0 - minf(cine_t * 2.0, 1.0) if shot.get("fade_in", false) else 0.0)
	if cine_t >= t:
		cine_t = 0.0
		cine_i += 1
		_cine_shot()
	return true


func _start_behemoth(from: String, to: String) -> void:
	if not markers.has(from) or not markers.has(to):
		return
	var route: PackedVector3Array = world.find_path(markers[from][0], markers[to][0])
	route.insert(0, markers[from][0])
	behemoth = BehemothScript.new()
	world.add_child(behemoth)
	behemoth.setup(world, self, game, route)
	behemoth.start()


func _ambient(name: String) -> void:
	if name == "" or not game.sfx.sounds.has(name):
		ambient.stop()
		return
	ambient.stream = game.sfx.sounds[name]
	ambient.play()
