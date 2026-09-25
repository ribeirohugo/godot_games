extends Control
## The in-game overlay, all drawn in _draw(): the weapon in the player's hands, the crosshair, the
## damage and pickup flashes, messages, and the status bar along the bottom. Sizes are for a
## 1280 x 720 screen and scale with its height.

const BAR_HEIGHT := 88.0
const RED := Color("e0402a")
const AMBER := Color("ffb02e")
const STEEL := Color(0.24, 0.25, 0.27)
const STEEL_LIGHT := Color(0.48, 0.49, 0.52)
const STEEL_DARK := Color(0.09, 0.09, 0.10)
const WOOD := Color(0.36, 0.2, 0.1)
const GLOVE := Color(0.26, 0.16, 0.1)
const GLOVE_LIGHT := Color(0.4, 0.26, 0.16)
const HOT := Color(1.0, 0.55, 0.12)

var game  # main.gd


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var world = game.world
	if world == null or world.player == null or size.y < 100.0:
		return
	var p = world.player
	var s := size.y / 720.0
	var light: Color = world.light_level(p.position)
	var shade := clampf((light.r + light.g + light.b) / 3.0 * 1.4 + 0.25, 0.35, 1.3)
	if p.alive:
		_draw_weapon(p, s, shade)
		_draw_crosshair(s)
	if p.hurt_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.0, 0.0, p.hurt_flash * 0.45))
	if p.bonus_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.8, 0.2, p.bonus_flash * 0.25))
	if not p.alive:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.0, 0.0, 0.35))
	_draw_bar(p, world, s)
	_draw_messages(s)
	if game.state == "playing" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not game.using_pad:
		var text: String = tr("click_to_play")
		var font: Font = game.bold
		var at := Vector2(0, size.y * 0.38)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(34 * s), int(8 * s), Color(0, 0, 0, 0.8))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(34 * s), AMBER)


func _draw_crosshair(s: float) -> void:
	var c := Vector2(size.x / 2.0, (size.y - BAR_HEIGHT * s) / 2.0)
	var col := Color(1.0, 0.85, 0.6, 0.8)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(c + d * 4.0 * s, c + d * 10.0 * s, col, maxf(2.0 * s, 1.0))


func _draw_messages(s: float) -> void:
	var font: Font = game.bold
	var y := 34.0 * s
	for m: Array in game.messages:
		var alpha := clampf(m[1], 0.0, 1.0)
		draw_string_outline(font, Vector2(20 * s, y), m[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s), int(6 * s), Color(0, 0, 0, 0.8 * alpha))
		draw_string(font, Vector2(20 * s, y), m[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s), Color(1.0, 0.85, 0.55, alpha))
		y += 28.0 * s


# --- Status bar ----------------------------------------------------------------------------

func _draw_bar(p, world, s: float) -> void:
	var h := BAR_HEIGHT * s
	var top := size.y - h
	var rect := Rect2(0, top, size.x, h)
	draw_rect(rect, Color(0.13, 0.11, 0.10))
	for i in 6:
		draw_rect(Rect2(0, top + h * i / 6.0, size.x, h / 6.0), Color(0, 0, 0, i * 0.035))
	draw_rect(Rect2(0, top, size.x, 3.0 * s), Color(0.55, 0.22, 0.08))
	draw_rect(Rect2(0, top + 3.0 * s, size.x, 1.0 * s), Color(1.0, 0.55, 0.2, 0.5))
	var w := minf(size.x, 1280.0 * s)
	var left := (size.x - w) / 2.0
	var cells := [0.15, 0.17, 0.17, 0.2, 0.13, 0.18]
	var x := left
	var font: Font = game.bold
	var weapon_info: Dictionary = p.WEAPONS[p.weapon]
	var ammo_kind: String = weapon_info["ammo"]
	for i in cells.size():
		var cw: float = cells[i] * w
		var box := Rect2(x + 4 * s, top + 10 * s, cw - 8 * s, h - 16 * s)
		draw_rect(box, Color(0.06, 0.05, 0.05))
		draw_rect(box, Color(0.3, 0.16, 0.1), false, maxf(1.0, 1.5 * s))
		for corner: Vector2 in [box.position, box.position + Vector2(box.size.x, 0), box.end, box.position + Vector2(0, box.size.y)]:
			draw_circle(corner + (box.get_center() - corner).normalized() * 6.0 * s, 2.0 * s, Color(0.45, 0.4, 0.36))
		var label_at := Vector2(box.position.x, box.end.y - 8 * s)
		match i:
			0:
				_big(font, box, "--" if ammo_kind == "" else str(p.ammo[ammo_kind]), s, RED)
				_small(font, label_at, box.size.x, tr("hud_ammo"), s)
			1:
				_big(font, box, "%d%%" % ceili(p.health), s, RED if p.health > 25 else Color(1.0, 0.2, 0.1, 0.6 + 0.4 * sin(Time.get_ticks_msec() / 90.0)))
				_small(font, label_at, box.size.x, tr("hud_health"), s)
			2:
				_big(font, box, "%d%%" % ceili(p.armor), s, Color(0.45, 0.9, 0.6) if p.armor > 0 else RED)
				_small(font, label_at, box.size.x, tr("hud_armor"), s)
			3:
				for n in 4:
					var slot := Vector2(box.position.x + box.size.x * (n + 0.5) / 4.0, box.position.y + box.size.y * 0.42)
					var current: bool = n == (p.next_weapon if p.next_weapon >= 0 else p.weapon)
					var col := AMBER if current else (Color(0.85, 0.8, 0.7) if p.owned[n] else Color(0.3, 0.27, 0.25))
					if current:
						draw_rect(Rect2(slot - Vector2(15, 17) * s, Vector2(30, 34) * s), Color(1.0, 0.5, 0.1, 0.18))
					draw_string(font, slot + Vector2(-20 * s, 10 * s), str(n + 1), HORIZONTAL_ALIGNMENT_CENTER, 40 * s, int(28 * s), col)
				_small(font, label_at, box.size.x, tr("hud_arms"), s)
			4:
				for n in 2:
					var color := Color(0.9, 0.15, 0.1) if n == 0 else Color(0.2, 0.4, 1.0)
					var has: bool = p.keys.has("red" if n == 0 else "blue")
					var key_rect := Rect2(box.position + Vector2(box.size.x * (0.22 + n * 0.36), box.size.y * 0.2), Vector2(22, 30) * s)
					if has:
						draw_rect(key_rect, color)
						draw_rect(key_rect.grow(-5 * s), color.lightened(0.4))
					else:
						draw_rect(key_rect, Color(color, 0.35), false, maxf(1.0, 1.5 * s))
				_small(font, label_at, box.size.x, tr("hud_keys"), s)
			5:
				_big(font, box, "%d/%d" % [world.kills, world.total_kills], s, AMBER, 34)
				_small(font, label_at, box.size.x, tr("hud_kills"), s)
		x += cw


func _big(font: Font, box: Rect2, text: String, s: float, color: Color, font_size := 40) -> void:
	var at := Vector2(box.position.x, box.position.y + box.size.y * 0.58)
	draw_string(font, at + Vector2(2, 2) * s, text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, int(font_size * s), Color(0, 0, 0, 0.7))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, int(font_size * s), color)


func _small(font: Font, at: Vector2, width: float, text: String, s: float) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, int(13 * s), Color(0.7, 0.62, 0.55))


# --- The weapon in hand --------------------------------------------------------------------

func _draw_weapon(p, s: float, shade: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var bob_x: float = cos(p.bob) * 22.0 * p.bob_amount
	var bob_y: float = absf(sin(p.bob)) * 16.0 * p.bob_amount + sin(t * 1.8) * 3.0
	var drop: float = p.lower * 420.0
	var base := Vector2(size.x / 2.0 + bob_x * s, size.y - BAR_HEIGHT * s + (bob_y + drop) * s)
	var w: Dictionary = p.WEAPONS[p.weapon]
	var shot := clampf(1.0 - p.since_shot / minf(w["delay"], 0.35), 0.0, 1.0)  # 1 right after firing
	var lit := func(c: Color) -> Color:
		return Color(c.r * shade, c.g * shade, c.b * shade, c.a)
	match w["id"]:
		"hammer":
			var swing: float = clampf(p.since_shot / 0.45, 0.0, 1.0)
			var arc := sin(swing * PI) if swing < 1.0 else 0.0
			draw_set_transform(base + Vector2(230 - arc * 260, 30 - arc * 60) * s, -0.35 - arc * 1.1, Vector2(s, s))
			_rect(Vector2(-13, -300), Vector2(26, 300), lit.call(WOOD))
			_rect(Vector2(-13, -300), Vector2(7, 300), lit.call(WOOD.lightened(0.15)))
			_rect(Vector2(-80, -360), Vector2(160, 80), lit.call(STEEL))
			_rect(Vector2(-80, -360), Vector2(160, 12), lit.call(STEEL_LIGHT))
			_rect(Vector2(-80, -292), Vector2(160, 12), lit.call(STEEL_DARK))
			_rect(Vector2(-92, -350), Vector2(12, 60), HOT)  # the striking face glows from the forge
			_rect(Vector2(-92, -350), Vector2(5, 60), Color(1.0, 0.9, 0.5))
			_fist(Vector2(0, -90), lit)
		"rivet":
			var kick := shot * 40.0
			draw_set_transform(base + Vector2(130, kick) * s, -0.06, Vector2(s, s))
			if shot > 0.6:
				_flash(Vector2(0, -300), 60.0 * shot)
			# Frame and grip.
			_poly([Vector2(-40, -150), Vector2(40, -150), Vector2(52, 0), Vector2(-52, 0)], lit.call(STEEL_DARK))
			for i in 5:
				_rect(Vector2(-44 + i, -120 + i * 22), Vector2(88 - i * 2, 4), lit.call(STEEL_DARK.lightened(0.12)))
			# Slide, beveled: lit on the left, in shadow on the right.
			_poly([Vector2(-30, -290), Vector2(30, -290), Vector2(50, -140), Vector2(-50, -140)], lit.call(STEEL))
			_poly([Vector2(-30, -290), Vector2(-18, -290), Vector2(-30, -140), Vector2(-50, -140)], lit.call(STEEL_LIGHT))
			_poly([Vector2(20, -290), Vector2(30, -290), Vector2(50, -140), Vector2(34, -140)], lit.call(STEEL.darkened(0.35)))
			for i in 4:
				_rect(Vector2(-22 - i * 3, -200 + i * 14), Vector2(44 + i * 6, 3), lit.call(STEEL.darkened(0.45)))  # grip serrations
			# The feed of glowing-hot rivets down the right side.
			for i in 5:
				draw_circle(Vector2(44 + i * 2.5, -270 + i * 26), 7.0, lit.call(Color(0.78, 0.6, 0.28)))
				draw_circle(Vector2(42 + i * 2.5, -272 + i * 26), 3.0, lit.call(Color(1.0, 0.85, 0.5)))
			_rect(Vector2(-5, -304), Vector2(10, 16), lit.call(STEEL_DARK))  # front sight
			draw_circle(Vector2(0, -284), 12.0, Color(0.02, 0.02, 0.02))
			_fist(Vector2(0, -40), lit)
		"scatter":
			var kick := shot * 70.0
			draw_set_transform(base + Vector2(0, kick) * s, 0.0, Vector2(s, s) * (1.0 + shot * 0.04))
			if shot > 0.55:
				_flash(Vector2(0, -350), 110.0 * shot)
			for side in [-1, 1]:
				_poly([Vector2(side * 4, -340), Vector2(side * 34, -340), Vector2(side * 66, -40), Vector2(side * 6, -40)], lit.call(STEEL))
				_poly([Vector2(side * 30, -340), Vector2(side * 34, -340), Vector2(side * 66, -40), Vector2(side * 56, -40)], lit.call(STEEL_LIGHT))
				draw_circle(Vector2(side * 19, -338), 12.0, Color(0.02, 0.02, 0.02))
			_poly([Vector2(-58, -210), Vector2(58, -210), Vector2(78, -120), Vector2(-78, -120)], lit.call(WOOD))
			for i in 4:
				_rect(Vector2(-60 + i * 4, -196 + i * 20), Vector2(120 - i * 8, 5), lit.call(WOOD.darkened(0.3)))
			_poly([Vector2(-60, -40), Vector2(60, -40), Vector2(90, 20), Vector2(-90, 20)], lit.call(WOOD.darkened(0.15)))
			_fist(Vector2(-110, -150), lit)
			_fist(Vector2(80, -20), lit)
		"slag":
			var kick := shot * 55.0
			draw_set_transform(base + Vector2(10, kick) * s, 0.0, Vector2(s, s))
			if shot > 0.5:
				_flash(Vector2(0, -330), 90.0 * shot, Color(1.0, 0.5, 0.1))
			_poly([Vector2(-62, -310), Vector2(62, -310), Vector2(120, 0), Vector2(-120, 0)], lit.call(STEEL))
			_poly([Vector2(-62, -310), Vector2(-40, -310), Vector2(-80, 0), Vector2(-120, 0)], lit.call(STEEL_LIGHT))
			_poly([Vector2(44, -310), Vector2(62, -310), Vector2(120, 0), Vector2(86, 0)], lit.call(STEEL.darkened(0.4)))
			_poly([Vector2(-10, -318), Vector2(10, -318), Vector2(14, -150), Vector2(-14, -150)], lit.call(STEEL_DARK))  # top rail
			var pulse := 0.75 + 0.25 * sin(t * 6.0) + shot * 0.4
			for i in 3:
				var y := -250.0 + i * 80.0
				var half := 64.0 + i * 20.0 + (y + 250.0) * 0.1
				_rect(Vector2(-half, y), Vector2(half * 2.0, 18), Color(HOT.r * pulse, HOT.g * pulse, HOT.b * pulse))
				_rect(Vector2(-half, y + 6), Vector2(half * 2.0, 5), Color(1.0, 0.9, 0.5, pulse))
			draw_circle(Vector2(0, -306), 40.0, Color(0.02, 0.02, 0.02))
			draw_circle(Vector2(0, -306), 26.0, Color(1.0, 0.45, 0.1, 0.5 + 0.3 * sin(t * 5.0)))
			_fist(Vector2(-140, -60), lit)
			_fist(Vector2(140, -60), lit)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _rect(pos: Vector2, rect_size: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos, rect_size), color)


func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)


## A gloved fist around a grip, centered on `at`.
func _fist(at: Vector2, lit: Callable) -> void:
	_poly([at + Vector2(-50, -40), at + Vector2(50, -46), at + Vector2(60, 40), at + Vector2(40, 90), at + Vector2(-40, 90), at + Vector2(-60, 30)], lit.call(GLOVE))
	for i in 4:
		var y := -34.0 + i * 20.0
		_poly([at + Vector2(-52, y), at + Vector2(-30, y - 4), at + Vector2(-28, y + 14), at + Vector2(-54, y + 16)], lit.call(GLOVE_LIGHT))
	_rect(at + Vector2(-44, 70), Vector2(88, 60), lit.call(GLOVE.darkened(0.3)))


func _flash(at: Vector2, radius: float, color := Color(1.0, 0.85, 0.4)) -> void:
	var points := PackedVector2Array()
	for i in 16:
		var r := radius * (1.0 if i % 2 == 0 else 0.45) * randf_range(0.8, 1.15)
		var a := TAU * i / 16.0
		points.append(at + Vector2(cos(a), sin(a) * 0.8) * r)
	draw_colored_polygon(points, Color(color, 0.85))
	draw_circle(at, radius * 0.35, Color(1.0, 1.0, 0.85))
