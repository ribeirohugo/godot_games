extends Node3D
## The camera. While the player is alive it sits behind their eyes and shows the gun in their hands
## (bobbing, kicking, reloading); after they die it looks at the killer for a moment, then follows a
## living teammate from behind until the round ends. Fire switches to the next teammate.

const Models := preload("res://scripts/models.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Tex := preload("res://scripts/textures.gd")

const FOV := 74.0

var rules
var game
var camera: Camera3D
var hands: Node3D  # holds the first-person model
var model: Node3D
var model_id := ""
var model_team := ""
var sight := Vector3.INF  # where the eye lines up with the current gun's sights, in its own space
var ads := 0.0  # 0 hip, 1 aiming down the sights
var flash: MeshInstance3D
var flash_light: OmniLight3D
var target  # the soldier being watched after death
var dead_t := 0.0
var killer
var death_eye := Vector3.ZERO
var shake := 0.0
var bob := 0.0
var sway := Vector2.ZERO
var last_view := Vector2.ZERO
var torch: SpotLight3D  # the flashlight on the player's gun, in the campaign's dark places


func setup(rules_ref, game_ref) -> void:
	rules = rules_ref
	game = game_ref
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.04
	camera.far = 400.0
	add_child(camera)
	camera.current = true
	hands = Node3D.new()
	camera.add_child(hands)
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.8, 0.5)
	flash_light.omni_range = 6.0
	flash_light.light_energy = 0.0
	flash_light.shadow_enabled = false
	camera.add_child(flash_light)
	flash_light.position = Vector3(0.1, -0.1, -0.8)
	torch = SpotLight3D.new()
	torch.light_color = Color(1.0, 0.96, 0.88)
	torch.light_energy = 3.2
	torch.spot_range = 28.0
	torch.spot_angle = 24.0
	torch.spot_attenuation = 0.8
	torch.shadow_enabled = true
	torch.position = Vector3(-0.25, 0.12, 0.1)
	torch.visible = false
	camera.add_child(torch)


func set_torch(on: bool) -> void:
	torch.visible = on


func on_round_start() -> void:
	target = null
	killer = null
	dead_t = 0.0
	rules.human.set_first_person(true)


func on_player_died(by) -> void:
	killer = by
	dead_t = 2.5
	death_eye = rules.human.eye_position()
	rules.human.set_first_person(false)
	hands.visible = false


## Watches the next living teammate (or anyone, when the whole squad is down).
func next_target() -> void:
	var living := []
	for s in rules.soldiers:
		if s.alive and s.squad == 0 and s != rules.human:
			living.append(s)
	if living.is_empty():
		for s in rules.soldiers:
			if s.alive:
				living.append(s)
	if living.is_empty():
		return
	var i := living.find(target)
	if target != null:
		target.set_first_person(false)
	target = living[(i + 1) % living.size()]
	dead_t = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if rules.human.alive or not game.can_control():
		return
	if event.is_action_pressed("fire") and dead_t <= 0.0:
		next_target()


func _process(delta: float) -> void:
	shake = move_toward(shake, 0.0, delta * 2.5)
	if rules.has_method("camera_override") and rules.camera_override(camera, delta):
		hands.visible = false
		return
	var h = rules.human
	if h.alive:
		_first_person(h, delta)
		return
	if flash != null:
		flash.visible = false
	flash_light.light_energy = 0.0
	hands.visible = false
	camera.fov = FOV
	if dead_t > 0.0:
		dead_t -= delta
		# Rise from where the player fell and turn to face whoever did it.
		var eye := death_eye + Vector3(0, minf((2.5 - dead_t) * 0.8, 1.2), 0)
		camera.global_position = eye
		if killer != null and killer != h and eye.distance_to(killer.eye_position()) > 0.5:
			var want := camera.global_transform.looking_at(killer.eye_position(), Vector3.UP)
			camera.global_transform = camera.global_transform.interpolate_with(want, minf(delta * 4.0, 1.0))
		return
	if rules.get("campaign") != null:
		return  # the campaign restarts from a checkpoint instead
	if target == null or not target.alive:
		next_target()
	if target == null:
		return
	_chase(target)


func _chase(t) -> void:
	var eye: Vector3 = t.eye_position()
	var look: Basis = t.view_basis()
	var back := look * Vector3(0.45, 0.35, 2.3)
	var query := PhysicsRayQueryParameters3D.create(eye, eye + back, rules.world.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var pos := eye + back
	if not hit.is_empty():
		pos = hit["position"] - back.normalized() * 0.25
	camera.global_position = pos
	camera.global_basis = look


func _first_person(h, delta: float) -> void:
	var offset := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.04
	camera.global_position = h.eye_position()
	camera.global_basis = h.view_basis()
	camera.position += camera.basis * offset
	var fov: float = rules.scope_fov(h)
	camera.fov = fov if h.scope > 0 else lerpf(camera.fov, fov, minf(delta * 12.0, 1.0))
	if model_id != h.current or model_team != (h.faction if h.faction != "" else h.team):
		_build_model(h)
	var sniper: bool = Weapons.data(h.current).has("scope")
	hands.visible = (h.scope == 0 or not sniper) and h.current != ""
	var aiming: bool = h.scope > 0 and not sniper and sight != Vector3.INF
	ads = move_toward(ads, 1.0 if aiming else 0.0, delta * 7.0)
	# Sway: the gun lags a little behind the view.
	var view := Vector2(h.yaw, h.pitch)
	var turn := Vector2(angle_difference(last_view.x, view.x), view.y - last_view.y)
	last_view = view
	sway = sway.lerp(Vector2(clampf(turn.x * 3.0, -0.06, 0.06), clampf(turn.y * 3.0, -0.06, 0.06)), minf(delta * 10.0, 1.0))
	var speed := Vector2(h.velocity.x, h.velocity.z).length()
	if h.is_on_floor():
		bob += delta * speed * 1.9
	var moving := clampf(speed / 6.0, 0.0, 1.0)
	var d := Weapons.data(h.current)
	var kind: String = d["kind"]
	var pos := Vector3(0.19, -0.21, -0.46)
	if kind in ["pistol", "magnum"]:
		pos = Vector3(0.2, -0.2, -0.52)
	elif kind in ["knife", "he", "flash", "smoke", "bomb"]:
		pos = Vector3(0.22, -0.24, -0.46)
	var hip_z := pos.z
	var rot := Vector3.ZERO
	var loose := 1.0 - ads * 0.8  # aiming holds the gun steadier
	pos += Vector3(cos(bob) * 0.012, -absf(sin(bob)) * 0.012, 0) * moving * loose
	pos += Vector3(-sway.x * 0.3, sway.y * 0.3, 0) * loose
	# Recoil: kick back and up right after a shot.
	var kick := clampf(1.0 - h.since_shot / 0.12, 0.0, 1.0) if d.has("mag") else 0.0
	pos.z += kick * (0.06 if kind in ["shotgun", "sniper", "magnum"] else 0.03)
	rot.x += kick * (0.18 if kind in ["shotgun", "sniper", "magnum"] else 0.06)
	if kind == "knife" and h.since_shot < 0.3:
		var k: float = sin(h.since_shot / 0.3 * PI)
		pos += Vector3(-0.1, 0.04, -0.12) * k
		rot.y += k * 0.8
	if kind in ["he", "flash", "smoke"] and h.since_shot < 0.4:
		pos.y -= 0.3 * sin(h.since_shot / 0.4 * PI)
	# Drawing the weapon: up from below. Reloading: tilt down and to the side.
	var draw: float = clampf(h.deploy_t / h.DEPLOY, 0.0, 1.0)
	pos.y -= draw * 0.25
	rot.x -= draw * 0.7
	if h.reload_t > 0.0:
		var r: float = sin(clampf(1.0 - h.reload_t / h.reload_len, 0.0, 1.0) * PI)
		pos.y -= r * 0.08
		rot.x -= r * 0.35
		rot.z += r * 0.5
	if h.busy():
		pos.y -= 0.12
		rot.x -= 0.4
	if ads > 0.0:
		# Bring the gun up in the middle, its sights just under the aim point and far enough out that
		# nothing of it hides what is being aimed at.
		var eased := ads * ads * (3.0 - 2.0 * ads)
		var aim_pos := Vector3(-sight.x, -sight.y - 0.06, -maxf(Models.ads_distance(h.current), 0.32) - sight.z)
		aim_pos.z += pos.z - hip_z  # keep the kick
		pos = pos.lerp(aim_pos, eased)
		rot = rot.lerp(Vector3(rot.x * 0.4, 0, rot.z * 0.3), eased)
	hands.position = pos
	hands.rotation = rot
	var firing: bool = d.has("mag") and h.since_shot < 0.045
	if flash != null:
		flash.visible = firing
		flash.rotation.z = randf() * TAU
	flash_light.light_energy = 1.6 if firing else 0.0


func _build_model(h) -> void:
	if model != null:
		model.queue_free()
		model = null
		flash = null
	model_id = h.current
	model_team = h.faction if h.faction != "" else h.team
	sight = Vector3.INF
	h.view_muzzle = null
	if model_id == "":
		return
	model = Models.viewmodel(model_id, model_team)
	hands.add_child(model)
	var muzzle := model.get_node_or_null("Gun/Muzzle") as Node3D
	h.view_muzzle = muzzle
	var mark := model.get_node_or_null("Gun/Sight") as Node3D
	sight = mark.position if mark != null else Vector3.INF
	if muzzle != null and Weapons.is_gun(model_id):
		flash = MeshInstance3D.new()
		var star := QuadMesh.new()
		star.size = Vector2(0.12, 0.12)
		flash.mesh = star
		var mat := Tex.flat(Color(1.0, 0.85, 0.45), 5.0, 0.0, true)
		flash.material_override = mat
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		muzzle.add_child(flash)
		flash.position = Vector3(0, 0, -0.04)
		flash.visible = false
