extends Control
## The in-game overlay, all drawn in _draw(): crosshair or sniper scope, score and round clock, radar,
## money, health and armor, ammo, the kill feed, round banners, hints, progress bars for planting and
## defusing, flash and damage effects, and the scoreboard (held Tab). Sizes are for a 1280 x 720
## screen and scale with its height.

const Weapons := preload("res://scripts/weapons.gd")
const Campaign := preload("res://scripts/campaign.gd")

const ATT := Color(1.0, 0.72, 0.3)
const DEF := Color(0.45, 0.7, 1.0)
const GREEN := Color(0.45, 1.0, 0.45)
const WHITE := Color(0.95, 0.95, 0.92)
const DIM := Color(0.65, 0.65, 0.62)
const PANEL := Color(0.0, 0.0, 0.0, 0.45)
const RADAR := 190.0
const RADAR_RANGE := 36.0  # meters from the middle of the radar to its edge

var game  # main.gd
var radar_box: Control
var radar_tex: ImageTexture
var radar_rules  # the map the radar image was made for


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radar_box = Control.new()
	radar_box.clip_contents = true
	radar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_box.draw.connect(_draw_radar)
	add_child(radar_box)


func _process(_delta: float) -> void:
	queue_redraw()
	radar_box.queue_redraw()


func _color(team: String) -> Color:
	return ATT if team == "att" else DEF


func _draw() -> void:
	var rules = game.rules
	radar_box.visible = rules != null and game.state != "menu"
	if rules == null or size.y < 100.0 or game.state == "menu":
		return
	var s := size.y / 720.0
	var h = rules.human
	var view = rules.view
	var font: Font = game.bold
	if rules.get("campaign") != null:
		_draw_campaign(rules, h, s, font)
		return
	if h.alive:
		if h.scope > 0 and Weapons.data(h.current).has("scope"):
			_draw_scope(s)
		elif h.scope > 0:
			_draw_dot(s)  # aiming down the sights
		else:
			_draw_crosshair(h, s)
		_draw_hurt(h, s)
	_draw_top(rules, s, font)
	radar_box.position = Vector2(14, 14) * s
	radar_box.size = Vector2(RADAR, RADAR) * s
	_draw_money(h, s, font)
	if h.alive:
		_draw_status(h, s, font)
		_draw_ammo(h, s, font)
		_draw_progress(h, rules, s, font)
		_draw_hints(h, rules, s)
	else:
		_draw_spectating(rules, view, s, font)
	_draw_feed(rules, s, font)
	_draw_banner(rules, s)
	_draw_messages(s)
	if h.alive and h.flash_t > 0.0:
		var a: float = clampf(h.flash_t / maxf(h.flash_len * 0.55, 0.01), 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, a))
	if Input.is_action_pressed("scores") or rules.phase == "done":
		_draw_scores(rules, s, font)
	if game.state == "playing" and not game.buy_open and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not game.using_pad:
		_text(Vector2(0, size.y * 0.42), tr("click_to_play"), 30 * s, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _text(at: Vector2, text: String, font_size: float, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := true) -> void:
	var font: Font = game.bold
	if outline:
		draw_string_outline(font, at, text, align, width, int(font_size), maxi(int(font_size / 5.0), 2), Color(0, 0, 0, 0.75 * color.a))
	draw_string(font, at, text, align, width, int(font_size), color)


# --- Campaign ------------------------------------------------------------------------------

func _draw_campaign(rules, h, s: float, font: Font) -> void:
	var cam := get_viewport().get_camera_3d()
	var cine: bool = not rules.cine.is_empty()
	radar_box.visible = not cine and h.alive and game.state == "playing"
	radar_box.position = Vector2(14, 14) * s
	radar_box.size = Vector2(RADAR, RADAR) * s
	if not cine and h.alive and h != null:
		if h.scope > 0 and Weapons.data(h.current).has("scope"):
			_draw_scope(s)
		elif h.scope > 0:
			_draw_dot(s)
		else:
			_draw_crosshair(h, s)
		if rules.hitmark_t > 0.0:
			var c := size / 2.0
			var col := Color(1.0, 0.25, 0.2) if rules.kill_mark else Color(1, 1, 1, 0.9)
			for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 6.0 * s, c + d * 13.0 * s, col, maxf(2.0 * s, 1.5))
		_draw_hurt(h, s)
		# Low health: the edges of the view go red.
		if h.health < 35.0:
			var a: float = (1.0 - h.health / 35.0) * (0.35 + 0.1 * sin(Time.get_ticks_msec() / 200.0))
			for i in 6:
				var k := i * 18.0 * s
				draw_rect(Rect2(k, k, size.x - k * 2.0, size.y - k * 2.0), Color(0.6, 0.0, 0.0, a * (1.0 - i / 6.0)), false, 20.0 * s)
		_draw_status(h, s, font)
		_draw_ammo(h, s, font)
		# Allies: their names over their heads.
		for name: String in rules.allies:
			var a = rules.allies[name]
			var at: Vector3 = a.eye_position() + Vector3(0, 0.45, 0)
			if cam != null and not cam.is_position_behind(at) and at.distance_to(h.position) < 40.0:
				var p := cam.unproject_position(at)
				_text(p - Vector2(100, 0) * s, a.nick, 14 * s, Color(0.5, 1.0, 0.5, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 200 * s)
		_draw_objective(rules, h, s, cam)
		var hint: String = rules.hint
		if hint == "":
			for d in rules.world.drops:
				if Vector2(d.position.x - h.position.x, d.position.z - h.position.z).length() < 1.8 and Weapons.LIST.has(d.get_meta("id")):
					hint = tr("hint_pickup") % [_key("use"), Weapons.name_of(d.get_meta("id"))]
					break
		if hint != "":
			_text(Vector2(0, size.y * 0.62), hint, 19 * s, Color(1.0, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER, size.x)
			var u = rules.uses.get(rules.interact_id, {})
			if not u.is_empty() and u["t"] > 0.0:
				var w := 300.0 * s
				var r := Rect2(size.x / 2.0 - w / 2.0, size.y * 0.64, w, 10 * s)
				draw_rect(r.grow(2 * s), PANEL)
				draw_rect(Rect2(r.position, Vector2(w * clampf(u["t"] / u["hold"], 0.0, 1.0), r.size.y)), Color(1.0, 0.8, 0.3))
		if h.flash_t > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, clampf(h.flash_t / maxf(h.flash_len * 0.55, 0.01), 0.0, 1.0)))
	if rules.countdown >= 0.0 and not cine:
		var t: float = ceilf(rules.countdown)
		var col := Color(1.0, 0.35, 0.3) if t < 60.0 else WHITE
		_text(Vector2(size.x - 240 * s, 46 * s), "%d:%02d" % [int(t) / 60, int(t) % 60], 36 * s, col, HORIZONTAL_ALIGNMENT_RIGHT, 220 * s)
	if rules.boss != null and rules.boss.alive and not cine:
		var w := 520.0 * s
		var r := Rect2(size.x / 2.0 - w / 2.0, 92 * s, w, 12 * s)
		draw_rect(r.grow(3 * s), PANEL)
		draw_rect(Rect2(r.position, Vector2(w * clampf(rules.boss.health / 1600.0, 0.0, 1.0), r.size.y)), Color(0.3, 0.85, 1.0))
		_text(Vector2(0, r.position.y - 6 * s), tr("enemy_first"), 16 * s, Color(0.6, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	# Letterbox in cinematics.
	if cine:
		draw_rect(Rect2(0, 0, size.x, size.y * 0.11), Color.BLACK)
		draw_rect(Rect2(0, size.y * 0.89, size.x, size.y * 0.11), Color.BLACK)
	if not h.alive and not cine:
		_text(Vector2(0, size.y * 0.5), tr("you_died"), 44 * s, Color(1.0, 0.3, 0.25), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_draw_messages(s)
	_draw_line(rules, s, font, cine)
	if rules.toast_t > 0.0 and rules.toast != "":
		var a := clampf(rules.toast_t * 2.0, 0.0, 1.0)
		_text(Vector2(0, size.y * 0.2), rules.toast, 24 * s, Color(1.0, 0.85, 0.4, a), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf(rules.fade, 0.0, 1.0)))
	if rules.title_t > 0.0:
		var a := clampf(minf(rules.title_t, 6.0 - rules.title_t) * 1.2, 0.0, 1.0)
		_text(Vector2(0, size.y * 0.44), rules.title[0], 52 * s, Color(ACCENT_TITLE, a), HORIZONTAL_ALIGNMENT_CENTER, size.x)
		_text(Vector2(0, size.y * 0.44 + 42 * s), rules.title[1], 21 * s, Color(WHITE, a), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if game.state == "playing" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not game.using_pad and not cine:
		_text(Vector2(0, size.y * 0.42), tr("click_to_play"), 30 * s, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER, size.x)


const ACCENT_TITLE := Color(0.94, 0.66, 0.19)


func _draw_objective(rules, h, s: float, cam: Camera3D) -> void:
	if rules.objective == "":
		return
	var text: String = tr(rules.objective)
	if rules.objective_group != "":
		var left := 0
		for m in rules.groups.get(rules.objective_group, []):
			if m.alive:
				left += 1
		if left > 0:
			text += "  (" + tr("remaining") % left + ")"
	var font: Font = game.bold
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * s)).x + 40 * s
	var box := Rect2(size.x / 2.0 - w / 2.0, 10 * s, w, 50 * s)
	draw_rect(box, PANEL)
	draw_rect(Rect2(box.position, Vector2(4 * s, box.size.y)), ACCENT_TITLE)
	_text(Vector2(box.position.x, box.position.y + 18 * s), tr("objective").to_upper(), 12 * s, ACCENT_TITLE, HORIZONTAL_ALIGNMENT_CENTER, w)
	_text(Vector2(box.position.x, box.position.y + 40 * s), text, 18 * s, WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)
	# The waypoint: a diamond on the spot, with the distance.
	var mark: String = rules.objective_mark
	if mark == "" or not rules.markers.has(mark) or cam == null:
		return
	var at: Vector3 = rules.markers[mark][0] + Vector3(0, 1.5, 0)
	var dist: float = at.distance_to(h.position)
	var p: Vector2
	if cam.is_position_behind(at):
		p = Vector2(size.x / 2.0, size.y - 90 * s)
		var side := (at - cam.global_position).dot(cam.global_basis.x)
		p.x = 40 * s if side < 0.0 else size.x - 40 * s
	else:
		p = cam.unproject_position(at)
		p = p.clamp(Vector2(40, 80) * s, size - Vector2(40, 100) * s)
	var r := 9.0 * s
	var diamond := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	draw_colored_polygon(diamond, Color(ACCENT_TITLE, 0.85))
	_text(p + Vector2(-60 * s, 26 * s), "%d m" % int(dist), 14 * s, Color(WHITE, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 120 * s)


## The line being spoken, with the speaker's name.
func _draw_line(rules, s: float, font: Font, cine: bool) -> void:
	if rules.line.is_empty():
		return
	var who: String = rules.line[0]
	var text: String = tr(rules.line[1])
	var name_text: String = tr("spk_" + who)
	var width := minf(size.x - 80 * s, 900 * s)
	var y := size.y * (0.84 if cine else 0.78)
	var lines_n := ceili(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * s)).x / width)
	draw_rect(Rect2(size.x / 2.0 - width / 2.0 - 14 * s, y - 26 * s, width + 28 * s, (34 + lines_n * 24) * s), Color(0, 0, 0, 0.55))
	_text(Vector2(0, y - 6 * s), name_text, 16 * s, Campaign.SPEAKERS.get(who, WHITE), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	draw_multiline_string(font, Vector2(size.x / 2.0 - width / 2.0, y + 18 * s), text, HORIZONTAL_ALIGNMENT_CENTER, width, int(19 * s), -1, WHITE)


# --- Aim -----------------------------------------------------------------------------------

func _draw_crosshair(h, s: float) -> void:
	var c := size / 2.0
	var d := Weapons.data(h.current)
	if d["slot"] >= 2:
		draw_circle(c, 2.0 * s, Color(GREEN, 0.9))
		return
	# The gap grows with how far off a shot can go (moving, jumping, spraying).
	var gap: float = 4.0 * s + h.inaccuracy() * size.y * 0.9
	var length := 8.0 * s
	var width := maxf(2.0 * s, 1.0)
	for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var a := c + dir * gap
		var b := c + dir * (gap + length)
		draw_line(a, b, Color(0, 0, 0, 0.6), width + 2.0)
		draw_line(a, b, GREEN, width)


## Aiming down the sights: a clear dot where the shots go, outlined so it shows on anything.
func _draw_dot(s: float) -> void:
	var c := size / 2.0
	draw_circle(c, maxf(4.0 * s, 3.0), Color(0, 0, 0, 0.7))
	draw_circle(c, maxf(2.6 * s, 2.0), GREEN)


func _draw_scope(s: float) -> void:
	var c := size / 2.0
	var r := size.y * 0.46
	var black := Color(0, 0, 0)
	draw_rect(Rect2(0, 0, c.x - r, size.y), black)
	draw_rect(Rect2(c.x + r, 0, size.x - c.x - r, size.y), black)
	# Fill the corners around the circle with a ring of thick arcs.
	for i in 14:
		var k := r + 20.0 * s + i * 30.0 * s
		draw_arc(c, k, 0.0, TAU, 96, black, 32.0 * s)
	draw_arc(c, r, 0.0, TAU, 96, Color(0, 0, 0, 0.9), 6.0 * s)
	draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), black, maxf(1.0, 1.4 * s))
	draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), black, maxf(1.0, 1.4 * s))


## A red arc on the side the last hit came from.
func _draw_hurt(h, s: float) -> void:
	if h.hurt_t <= 0.0 or h.hurt_from == Vector3.ZERO:
		return
	var to: Vector3 = h.hurt_from - h.position
	var angle: float = atan2(-to.x, -to.z) - h.yaw
	var screen_angle := -angle - PI / 2.0
	var c := size / 2.0
	draw_arc(c, size.y * 0.2, screen_angle - 0.35, screen_angle + 0.35, 20, Color(1.0, 0.1, 0.05, 0.7 * h.hurt_t), 10.0 * s)


# --- Top: score, clock, feed, banner -------------------------------------------------------

func _draw_top(rules, s: float, font: Font) -> void:
	var c := size.x / 2.0
	var box := Rect2(c - 170 * s, 8 * s, 340 * s, 52 * s)
	draw_rect(box, PANEL)
	var ours: String = rules.side_of[0]
	var theirs: String = rules.side_of[1]
	_text(Vector2(box.position.x, box.position.y + 38 * s), str(rules.score[0]), 32 * s, _color(ours), HORIZONTAL_ALIGNMENT_CENTER, 80 * s)
	_text(Vector2(box.end.x - 80 * s, box.position.y + 38 * s), str(rules.score[1]), 32 * s, _color(theirs), HORIZONTAL_ALIGNMENT_CENTER, 80 * s)
	var clock := ""
	var clock_color := WHITE
	if rules.bomb_state == "planted" and rules.phase != "done":
		clock = tr("hud_bomb")
		clock_color = Color(1.0, 0.25, 0.2, 0.55 + 0.45 * sin(Time.get_ticks_msec() / 120.0))
	else:
		var t: float = ceilf(rules.time_left())
		clock = "%d:%02d" % [int(t) / 60, int(t) % 60]
		if rules.phase == "freeze":
			clock_color = Color(1.0, 0.85, 0.4)
		elif t <= 10.0 and rules.phase == "live":
			clock_color = Color(1.0, 0.35, 0.3)
	_text(Vector2(box.position.x, box.position.y + 36 * s), clock, 30 * s, clock_color, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	# Living players on each side, as little bars.
	for squad in 2:
		var team: String = rules.side_of[squad]
		var list: Array = []
		for p in rules.soldiers:
			if p.squad == squad:
				list.append(p)
		for i in list.size():
			var x := box.position.x - (i + 1) * 16 * s - 6 * s if squad == 0 else box.end.x + i * 16 * s + 6 * s + 4 * s
			var r := Rect2(x, box.position.y + 6 * s, 12 * s, 40 * s)
			var alive: bool = list[i].alive
			draw_rect(r, Color(_color(team), 0.85) if alive else Color(0.2, 0.2, 0.2, 0.6))
			if alive and list[i].has_bomb and squad == 0:
				draw_rect(Rect2(r.position.x, r.end.y - 8 * s, r.size.x, 8 * s), Color(1.0, 0.25, 0.2))
	_text(Vector2(box.position.x, box.end.y + 18 * s), tr("round_short") % [rules.round_n, rules.max_rounds], 14 * s, DIM, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)


func _draw_feed(rules, s: float, font: Font) -> void:
	var y := 14.0 * s
	var fs := int(17 * s)
	for entry: Dictionary in rules.feed:
		var killer = entry["killer"]
		var victim = entry["victim"]
		var weapon: String = Weapons.name_of(entry["weapon"]) if Weapons.LIST.has(entry["weapon"]) else tr("weapon_" + entry["weapon"])
		var parts := []
		if killer != null and killer != victim:
			parts.append([killer.nick, _color(entry["killer_team"])])
		parts.append([" [%s]%s " % [weapon, " HS" if entry["headshot"] else ""], WHITE])
		parts.append([victim.nick, _color(entry["victim_team"])])
		var width := 0.0
		for p: Array in parts:
			width += font.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := size.x - width - 22 * s
		var row := Rect2(x - 8 * s, y, width + 16 * s, 26 * s)
		var alpha := clampf(entry["t"], 0.0, 1.0)
		draw_rect(row, Color(0, 0, 0, 0.5 * alpha))
		if killer == rules.human or victim == rules.human:
			draw_rect(row, Color(1.0, 0.25, 0.2, 0.8 * alpha), false, maxf(1.5 * s, 1.0))
		for p: Array in parts:
			draw_string(font, Vector2(x, y + 19 * s), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p[1], alpha))
			x += font.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		y += 30 * s


func _draw_banner(rules, s: float) -> void:
	var b: Dictionary = rules.banner
	if b["t"] <= 0.0 or b["text"] == "":
		return
	var alpha := clampf(b["t"] * 2.0, 0.0, 1.0)
	var y := size.y * 0.26
	draw_rect(Rect2(0, y - 46 * s, size.x, 74 * s if b["sub"] == "" else 100 * s), Color(0, 0, 0, 0.45 * alpha))
	_text(Vector2(0, y + 4 * s), b["text"], 44 * s, Color(b["color"], alpha), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if b["sub"] != "":
		_text(Vector2(0, y + 38 * s), b["sub"], 20 * s, Color(WHITE, alpha), HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_messages(s: float) -> void:
	var y := (RADAR + 80.0) * s
	for m: Array in game.messages:
		var alpha := clampf(m[1], 0.0, 1.0)
		_text(Vector2(16 * s, y), m[0], 18 * s, Color(1.0, 0.9, 0.6, alpha))
		y += 26 * s


# --- Radar ---------------------------------------------------------------------------------

## The map drawn once into an image, 4 pixels per cell.
func _make_radar(world) -> void:
	var px := 4
	var img := Image.create(world.width * px, world.depth * px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for z in world.depth:
		for x in world.width:
			var c := Vector2i(x, z)
			var col := Color(0.42, 0.42, 0.4, 0.9)
			if world.is_wall(c):
				continue
			if world.is_solid(c):
				col = Color(0.62, 0.6, 0.55, 0.95)
			elif world.water.has(c):
				col = Color(0.3, 0.42, 0.5, 0.9)
			if world.site_at(world.center(c)) != "":
				col = col.lerp(Color(0.75, 0.25, 0.2, 0.95), 0.35)
			img.fill_rect(Rect2i(x * px, z * px, px, px), col)
	radar_tex = ImageTexture.create_from_image(img)


func _draw_radar() -> void:
	var rules = game.rules
	if rules == null:
		return
	if radar_rules != rules.world:
		radar_rules = rules.world
		_make_radar(rules.world)
	var world = rules.world
	var s := size.y / 720.0
	var box := radar_box.size
	radar_box.draw_rect(Rect2(Vector2.ZERO, box), Color(0.05, 0.06, 0.06, 0.7))
	var h = rules.human
	var viewer = h if h.alive or rules.view.target == null else rules.view.target
	var centre := box / 2.0
	var scale := (box.x / 2.0) / RADAR_RANGE  # pixels per meter
	var yaw: float = viewer.yaw
	var origin := Vector2(viewer.position.x, viewer.position.z)
	# Rotate so that the way the viewer faces points up.
	var turn := yaw
	var to_screen := func(p: Vector3) -> Vector2:
		return centre + (Vector2(p.x, p.z) - origin).rotated(turn) * scale
	radar_box.draw_set_transform(centre, turn, Vector2.ONE * scale * world.CELL / 4.0)
	var offset: Vector2 = -origin / (world.CELL / 4.0)
	radar_box.draw_texture(radar_tex, offset)
	radar_box.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for key: String in world.sites:
		var at: Vector2 = to_screen.call(world.site_center(key))
		radar_box.draw_string(game.bold, at + Vector2(-8, 8) * s, key.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * s), Color(1.0, 0.4, 0.3, 0.9))
	for p in rules.soldiers:
		if not p.alive:
			continue
		var at: Vector2 = to_screen.call(p.position)
		if p.squad == 0:
			var col := Color(1, 1, 1) if p == viewer else _color(p.team)
			var facing: Vector2 = Vector2(0, -1).rotated(turn - p.yaw)
			radar_box.draw_line(at, at + facing * 9.0 * s, col, 2.0 * s)
			radar_box.draw_circle(at, 4.5 * s, col)
		elif rules.spotted.has(p):
			radar_box.draw_circle(at, 4.5 * s, Color(1.0, 0.2, 0.15))
	var bomb: Vector3 = rules.bomb_position()
	if bomb != Vector3.INF and (rules.side_of[0] == "att" or rules.bomb_state == "planted"):
		var at: Vector2 = to_screen.call(bomb)
		var blink: bool = rules.bomb_state != "planted" or sin(Time.get_ticks_msec() / 100.0) > 0.0
		radar_box.draw_rect(Rect2(at - Vector2(5, 4) * s, Vector2(10, 8) * s), Color(1.0, 0.3, 0.2) if blink else Color(0.4, 0.1, 0.1))
	radar_box.draw_rect(Rect2(Vector2.ZERO, box), Color(1, 1, 1, 0.25), false, maxf(1.0, 1.5 * s))


func _draw_money(h, s: float, _font: Font) -> void:
	var at := Vector2(16, RADAR + 44) * s
	_text(at, "$ %d" % h.money, 26 * s, GREEN)
	if game.rules.can_buy(h):
		_text(at + Vector2(0, 24 * s), tr("hud_buy") % _key("buy"), 15 * s, DIM)


# --- Bottom: health, armor, ammo -----------------------------------------------------------

func _draw_status(h, s: float, _font: Font) -> void:
	var y := size.y - 22 * s
	draw_rect(Rect2(10 * s, y - 44 * s, 300 * s, 54 * s), PANEL)
	# A cross for health, a shield for armor.
	var c := Vector2(38 * s, y - 17 * s)
	var hp_col := WHITE if h.health > 25 else Color(1.0, 0.3, 0.25)
	draw_rect(Rect2(c - Vector2(4, 13) * s, Vector2(8, 26) * s), hp_col)
	draw_rect(Rect2(c - Vector2(13, 4) * s, Vector2(26, 8) * s), hp_col)
	_text(Vector2(58 * s, y), str(ceili(h.health)), 38 * s, hp_col)
	var sc := Vector2(178 * s, y - 17 * s)
	var shield := PackedVector2Array([sc + Vector2(-12, -14) * s, sc + Vector2(12, -14) * s, sc + Vector2(12, 2) * s, sc + Vector2(0, 14) * s, sc + Vector2(-12, 2) * s])
	draw_colored_polygon(shield, WHITE if h.armor > 0 else Color(0.4, 0.4, 0.4))
	if h.helmet:
		_text(sc + Vector2(-5, 6) * s, "H", 14 * s, Color(0.1, 0.1, 0.1), HORIZONTAL_ALIGNMENT_LEFT, -1, false)
	_text(Vector2(198 * s, y), str(ceili(h.armor)), 38 * s, WHITE if h.armor > 0 else DIM)


func _draw_ammo(h, s: float, font: Font) -> void:
	var y := size.y - 22 * s
	var right := size.x - 16 * s
	draw_rect(Rect2(size.x - 330 * s, y - 44 * s, 320 * s, 54 * s), PANEL)
	var d := Weapons.data(h.current)
	if d.has("mag"):
		var reserve := "/ %d" % h.reserves[h.current]
		var rw := font.get_string_size(reserve, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s)).x
		_text(Vector2(right - rw, y), reserve, 22 * s, DIM)
		var mag: int = h.mags[h.current]
		var low: bool = mag <= int(d["mag"]) / 5
		_text(Vector2(right - rw - 120 * s, y), str(mag), 40 * s, Color(1.0, 0.35, 0.3) if low else WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 112 * s)
	var name_text: String = Weapons.name_of(h.current) if h.current != "" else ""
	_text(Vector2(size.x - 322 * s, y - 24 * s), name_text, 17 * s, DIM)
	# Grenades, the bomb and the kit, as small tags above the ammo.
	var tags: Array = []
	for g in h.grenades:
		tags.append([{"he": "HE", "flash": "FL", "smoke": "SM"}[g], WHITE])
	if h.has_bomb:
		tags.append(["C4", Color(1.0, 0.4, 0.3)])
	if h.has_kit:
		tags.append(["KIT", DEF])
	var x := right
	for tag: Array in tags:
		var w := font.get_string_size(tag[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * s)).x + 12 * s
		x -= w + 6 * s
		var r := Rect2(x, y - 72 * s, w, 22 * s)
		draw_rect(r, PANEL)
		draw_rect(r, Color(tag[1], 0.7), false, maxf(1.0, s))
		draw_string(font, r.position + Vector2(6 * s, 16 * s), tag[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * s), tag[1])


func _draw_progress(h, rules, s: float, _font: Font) -> void:
	var k := 0.0
	var text := ""
	if h.plant_t > 0.0:
		k = h.plant_t / h.PLANT_TIME
		text = tr("planting")
	elif h.defuse_t > 0.0:
		k = h.defuse_t / h.defuse_length()
		text = tr("defusing")
	elif h.reload_t > 0.0:
		return
	if text == "":
		return
	var w := 320.0 * s
	var r := Rect2(size.x / 2.0 - w / 2.0, size.y * 0.66, w, 14 * s)
	draw_rect(r.grow(3 * s), PANEL)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y)), Color(1.0, 0.8, 0.3))
	_text(Vector2(0, r.position.y - 10 * s), text, 20 * s, WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if rules.bomb_state == "planted" and h.defuse_t > 0.0 and rules.bomb_t < h.defuse_length() - h.defuse_t:
		_text(Vector2(0, r.end.y + 26 * s), tr("no_time"), 16 * s, Color(1.0, 0.4, 0.3), HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_hints(h, rules, s: float) -> void:
	var hint := ""
	if h.team == "def" and rules.bomb_state == "planted" and h.defuse_t <= 0.0 and h.position.distance_to(rules.bomb_node.position) < 2.5:
		hint = tr("hint_defuse") % _key("use")
	elif h.has_bomb and h.current != "bomb" and rules.world.site_at(h.position) != "" and rules.phase == "live":
		hint = tr("hint_take_bomb") % _key("slot_5")
	elif h.current == "bomb" and h.plant_t <= 0.0:
		hint = tr("hint_plant") if rules.world.site_at(h.position) != "" else tr("plant_on_site")
	else:
		for d in rules.world.drops:
			if Vector2(d.position.x - h.position.x, d.position.z - h.position.z).length() < 1.8 and d.get_meta("id") != "bomb":
				hint = tr("hint_pickup") % [_key("use"), Weapons.name_of(d.get_meta("id"))]
				break
	if hint != "":
		_text(Vector2(0, size.y * 0.62), hint, 18 * s, Color(1.0, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_spectating(rules, view, s: float, _font: Font) -> void:
	var y := size.y - 40 * s
	if view.dead_t > 0.0:
		var killer = view.killer
		var text: String = tr("you_died")
		if killer != null and killer != rules.human:
			text = tr("killed_by") % [killer.nick, int(ceilf(killer.health))]
		_text(Vector2(0, y), text, 24 * s, Color(1.0, 0.4, 0.3), HORIZONTAL_ALIGNMENT_CENTER, size.x)
		return
	var t = view.target
	if t == null:
		return
	draw_rect(Rect2(size.x / 2.0 - 220 * s, y - 34 * s, 440 * s, 52 * s), PANEL)
	_text(Vector2(0, y - 8 * s), tr("spectating") % t.nick, 22 * s, _color(t.team), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_text(Vector2(0, y + 12 * s), "%d HP  ·  %s  ·  %s" % [ceili(t.health), Weapons.name_of(t.current) if t.current != "" else "", tr("hint_next")], 14 * s, DIM, HORIZONTAL_ALIGNMENT_CENTER, size.x)


# --- Scoreboard ----------------------------------------------------------------------------

func _draw_scores(rules, s: float, font: Font) -> void:
	var w := 720.0 * s
	var left := size.x / 2.0 - w / 2.0
	var y := size.y * 0.16
	var rows := 0
	for squad in 2:
		for p in rules.soldiers:
			if p.squad == squad:
				rows += 1
	draw_rect(Rect2(left, y, w, (rows * 30 + 150) * s), Color(0.02, 0.03, 0.04, 0.85))
	y += 34 * s
	for squad in 2:
		var team: String = rules.side_of[squad]
		var col := _color(team)
		var title := "%s  %d" % [tr("side_att") if team == "att" else tr("side_def"), rules.score[squad]]
		_text(Vector2(left + 20 * s, y), title, 22 * s, col)
		_text(Vector2(left + w - 250 * s, y), tr("col_kills"), 15 * s, DIM, HORIZONTAL_ALIGNMENT_CENTER, 60 * s)
		_text(Vector2(left + w - 190 * s, y), tr("col_deaths"), 15 * s, DIM, HORIZONTAL_ALIGNMENT_CENTER, 60 * s)
		if squad == 0:
			_text(Vector2(left + w - 120 * s, y), tr("col_money"), 15 * s, DIM, HORIZONTAL_ALIGNMENT_CENTER, 100 * s)
		y += 10 * s
		var list: Array = []
		for p in rules.soldiers:
			if p.squad == squad:
				list.append(p)
		list.sort_custom(func(a, b) -> bool: return a.kills > b.kills)
		for p in list:
			y += 30 * s
			var c := col if p.alive else Color(col, 0.4)
			if p == rules.human:
				draw_rect(Rect2(left + 10 * s, y - 21 * s, w - 20 * s, 28 * s), Color(1, 1, 1, 0.08))
			var name_text: String = p.nick + ("  [C4]" if p.has_bomb and squad == 0 else "")
			draw_string(font, Vector2(left + 30 * s, y), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * s), c)
			draw_string(font, Vector2(left + w - 250 * s, y), str(p.kills), HORIZONTAL_ALIGNMENT_CENTER, 60 * s, int(18 * s), c)
			draw_string(font, Vector2(left + w - 190 * s, y), str(p.deaths), HORIZONTAL_ALIGNMENT_CENTER, 60 * s, int(18 * s), c)
			if squad == 0:
				draw_string(font, Vector2(left + w - 120 * s, y), "$%d" % p.money, HORIZONTAL_ALIGNMENT_CENTER, 100 * s, int(18 * s), Color(GREEN, c.a))
		y += 50 * s


## The first key bound to an action, for hints ("B", "E", ...).
func _key(action: String) -> String:
	if game.using_pad:
		return {"use": "X", "buy": "Back", "slot_5": "D-pad"}.get(action, "?")
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string((event as InputEventKey).physical_keycode)
	return "?"
