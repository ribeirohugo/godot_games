extends Node2D
## Slot Machine Pro: a lobby of slot machines played with coins that aren't real money.
## Pick a machine, choose a bet and spin. Wins pay left to right along the paylines; WILD
## stands in for any symbol except BONUS. Three BONUS anywhere start free spins with doubled
## wins, and a full line of WILDs wins the machine's progressive jackpot (in proportion to the bet).
## Keys: Space spin / stop, Up / Down bet, M max bet, A auto, T turbo, I pay table, Esc back.
## Xbox gamepads: A spin, LB / RB bet, Y auto, X turbo, Back pay table, B back, Start menu.

const SfxScript := preload("res://scripts/sfx.gd")
const StringsScript := preload("res://scripts/strings.gd")
const Machines := preload("res://scripts/machines.gd")
const Slots := preload("res://scripts/slots.gd")
const SymbolsScript := preload("res://scripts/symbols.gd")

const SCREEN := Vector2(1280, 720)
const SAVE_PATH := "user://slot-machine-pro.cfg"
const START_BALANCE := 5000
const LINE_BETS := [1, 2, 5, 10, 20, 50, 100]
const ROWS := 3
const CELL_H := 130.0
const REEL_GAP := 8.0
const REELS_Y := 118.0
const SPEED := 22.0  # reel speed in symbols per second
const TURBO_SPEED := 34.0
const ACCEL := 0.12
const BOUNCE := 0.18
const JACKPOT_SHARE := 0.01  # part of every bet that feeds the jackpot
const JACKPOT_SEED := 25  # jackpots restart at this many max bets

# Lobby cards: five across, two down.
const CARD := Vector2(228, 276)
const CARD_GAP := 16.0
const CARDS_Y := 96.0

const BUTTONS := {
	"back": Rect2(14, 10, 120, 40),
	"menu": Rect2(1212, 8, 48, 44),
	"info": Rect2(40, 604, 60, 60),
	"minus": Rect2(232, 610, 48, 48),
	"plus": Rect2(472, 610, 48, 48),
	"max": Rect2(530, 610, 104, 48),
	"auto": Rect2(924, 610, 90, 48),
	"turbo": Rect2(1022, 610, 90, 48),
	"spin": Rect2(1130, 572, 124, 124),
}
const MENU_RECT := Rect2(390, 110, 500, 500)
const TABLE_RECT := Rect2(120, 64, 1040, 612)

const GOLD := Color("ffd24a")
const GOLD_DEEP := Color("b8860b")
const GOLD_LIGHT := Color("fff3c0")
const INK := Color("fffaf0")
const MUTED := Color(1, 0.97, 0.9, 0.62)
const PANEL := Color(0.04, 0.02, 0.07, 0.82)
const WIN_GREEN := Color("8dffb0")

var machines := []  # built machines, see Slots.build
var screen := "lobby"  # "lobby" or "machine"
var m := {}  # the machine being played
var mi := 0  # its index

# Money and saved progress.
var balance := START_BALANCE
var shown_balance := float(START_BALANCE)
var jackpots := {}  # machine id -> float
var bet_index := {}  # machine id -> index in LINE_BETS
var stats := {"spins": 0, "biggest": 0, "jackpots": 0, "free_rounds": 0}
var language := ""
var sound_on := true
var turbo := false
var auto := false

# Reels.
var stops := []
var reels := []  # per reel: {"tape", "pos", "start", "t", "speed", "delay", "state", "bounce_t", "tease"}
var reel_nodes: Array[Control] = []
var cell_w := 150.0
var reels_x := 0.0
var spinning := false
var landed_scatters := 0

# Result of the last spin.
var outcome := {}
var win_total := 0
var shown_win := 0.0
var show_t := 0.0
var idle_t := 0.0
var spin_bet := 0  # total bet of the spin, kept through free spins
var multiplier := 1

# Free spins.
var fs_left := 0
var fs_total := 0
var fs_played := 0
var fs_win := 0

var overlays := []  # queue of {"kind", "amount", "t"}
var message := ""
var menu_open := false
var table_open := false
var reset_armed := false
var hover := ""
var hover_card := -1
var hover_line := -1
var focus_card := 0
var mouse := Vector2.ZERO
var clock := 0.0
var coins := []

var art
var sfx
var serif: Font
var font: Font
var bold: Font
var cv: CanvasItem  # canvas the drawing helpers paint on
var overlay: Node2D
var background: ColorRect


func _ready() -> void:
	serif = _font(["Georgia", "Times New Roman", "Cambria"], 800)
	font = _font(["Segoe UI", "Helvetica Neue", "Arial"], 400)
	bold = _font(["Segoe UI", "Helvetica Neue", "Arial"], 800)
	art = SymbolsScript.new()
	art.font = serif
	art.ui_font = bold
	sfx = SfxScript.new()
	add_child(sfx)
	StringsScript.install()
	for i in Machines.LIST.size():
		var machine := Slots.build(i)
		machines.append(machine)
		# Each jackpot starts somewhere above its seed, as if others had been playing.
		jackpots[machine.id] = _jackpot_seed(machine) * randf_range(1.05, 1.9)
		bet_index[machine.id] = 1
	_add_background()
	overlay = Node2D.new()
	overlay.z_index = 10
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	_load()
	if language == "":
		language = StringsScript.system_language()
	_apply_settings()
	shown_balance = balance


func _font(names: Array, weight: int) -> Font:
	if OS.has_feature("web"):
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 0.8 if weight >= 700 else 0.0
		return variation
	var system := SystemFont.new()
	system.font_names = PackedStringArray(names)
	system.font_weight = weight
	return system


## Casino backdrop drawn by a shader: a gradient in the machine's colors with slow light rays.
func _add_background() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 top : source_color = vec4(0.25, 0.05, 0.4, 1.0);
uniform vec4 bottom : source_color = vec4(0.03, 0.01, 0.08, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float boost = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top.rgb, bottom.rgb, smoothstep(0.0, 1.0, uv.y));
	vec2 from = vec2(0.5, -0.15);
	vec2 d = (uv - from) * vec2(1.78, 1.0);
	float angle = atan(d.x, d.y);
	float rays = pow(0.5 + 0.5 * sin(angle * 18.0 + TIME * 0.25), 6.0);
	col += glow.rgb * rays * (0.05 + 0.08 * boost) * smoothstep(1.4, 0.1, length(d));
	vec2 cell = floor(uv * vec2(64.0, 36.0));
	float star = hash(cell);
	float twinkle = 0.5 + 0.5 * sin(TIME * (1.0 + star * 3.0) + star * 40.0);
	vec2 f = fract(uv * vec2(64.0, 36.0)) - 0.5;
	col += glow.rgb * step(0.985, star) * twinkle * smoothstep(0.12, 0.0, length(f)) * 0.7;
	col *= 1.0 - 0.45 * pow(length((uv - 0.5) * vec2(1.1, 1.3)), 2.0);
	COLOR = vec4(col, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	background = ColorRect.new()
	background.size = SCREEN
	background.material = material
	background.show_behind_parent = true
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_theme_background()


func _theme_background() -> void:
	var material := background.material as ShaderMaterial
	if screen == "lobby":
		material.set_shader_parameter("top", Color("3b0a5c"))
		material.set_shader_parameter("bottom", Color("07020f"))
		material.set_shader_parameter("glow", GOLD)
	else:
		material.set_shader_parameter("top", _color("bg"))
		material.set_shader_parameter("bottom", _color("bg2"))
		material.set_shader_parameter("glow", _color("trim"))


func _apply_settings() -> void:
	TranslationServer.set_locale(language)
	AudioServer.set_bus_mute(0, not sound_on)


func _color(key: String) -> Color:
	return Color(m.colors[key])


func _jackpot_seed(machine: Dictionary) -> int:
	return LINE_BETS[-1] * machine.lines * JACKPOT_SEED


func _line_bet() -> int:
	return LINE_BETS[bet_index[m.id]]


func _total_bet() -> int:
	return _line_bet() * m.lines


# --- Screens ---------------------------------------------------------------------------------

func _open_machine(index: int) -> void:
	mi = index
	m = machines[index]
	screen = "machine"
	cell_w = 180.0 if m.reels == 3 else 150.0
	reels_x = SCREEN.x / 2.0 - (m.reels * cell_w + (m.reels - 1) * REEL_GAP) / 2.0
	for node in reel_nodes:
		node.queue_free()
	reel_nodes.clear()
	reels.clear()
	stops.clear()
	for i in m.reels:
		stops.append(randi() % m.strips[i].size())
		reels.append({"state": "idle", "pos": 0.0, "tape": [], "tease": false})
		var node := Control.new()
		node.position = Vector2(_reel_x(i), REELS_Y)
		node.size = Vector2(cell_w, CELL_H * ROWS)
		node.clip_contents = true
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.draw.connect(_draw_reel.bind(i, node))
		add_child(node)
		move_child(node, overlay.get_index())
		reel_nodes.append(node)
	outcome = {}
	win_total = 0
	shown_win = 0.0
	auto = false
	fs_left = 0
	overlays.clear()
	table_open = false
	message = tr("good_luck")
	_theme_background()
	sfx.play("click")


func _back_to_lobby() -> void:
	if spinning or fs_left > 0 or not overlays.is_empty():
		return
	for node in reel_nodes:
		node.queue_free()
	reel_nodes.clear()
	screen = "lobby"
	auto = false
	table_open = false
	_theme_background()
	sfx.play("click")
	_save()


func _reel_x(i: int) -> float:
	return reels_x + i * (cell_w + REEL_GAP)


func _cell_center(reel: int, row: int) -> Vector2:
	return Vector2(_reel_x(reel) + cell_w / 2.0, REELS_Y + (row + 0.5) * CELL_H)


func _card_rect(i: int) -> Rect2:
	var x := (SCREEN.x - 5 * CARD.x - 4 * CARD_GAP) / 2.0 + (i % 5) * (CARD.x + CARD_GAP)
	return Rect2(x, CARDS_Y + (i / 5) * (CARD.y + CARD_GAP), CARD.x, CARD.y)


# --- Spinning --------------------------------------------------------------------------------

func _spin() -> void:
	if screen != "machine" or menu_open:
		return
	if table_open:
		table_open = false
		return
	if not overlays.is_empty():
		_skip_overlay()
		return
	if spinning:
		_slam()
		return
	var free := fs_left > 0
	if not free:
		var bet := _total_bet()
		if balance < bet:
			auto = false
			if balance < LINE_BETS[0] * m.lines:
				balance += START_BALANCE
				sfx.play("coins")
				message = tr("good_luck")
				_save()
			else:
				message = tr("no_money")
				sfx.play("error")
			return
		balance -= bet
		shown_balance = balance
		spin_bet = bet
		multiplier = 1
		jackpots[m.id] += bet * JACKPOT_SHARE
		stats.spins += 1
	else:
		fs_left -= 1
		fs_played += 1
		multiplier = Machines.FREE_SPIN_MULTIPLIER
	# The result is decided now; the reels only show it.
	var old_stops := stops.duplicate()
	for i in m.reels:
		stops[i] = randi() % m.strips[i].size()
	var grid := Slots.grid_for(m, stops)
	outcome = Slots.evaluate(m, grid)
	var line_bet: int = spin_bet / m.lines
	win_total = 0
	for win in outcome.lines:
		win["amount"] = win.units * line_bet * multiplier
		win_total += win.amount
	outcome["scatter_amount"] = outcome.scatter_units * spin_bet * multiplier
	win_total += outcome.scatter_amount
	shown_win = 0.0
	show_t = 0.0
	# Reels spin longer when two BONUS symbols already showed on the reels before.
	var speed := TURBO_SPEED if turbo else SPEED
	var scatters_before := 0
	var extra := 0.0
	for i in m.reels:
		var tease: bool = not m.scatter.is_empty() and scatters_before >= 2
		if tease:
			extra += 1.1
		var duration: float = (0.35 + 0.08 * i if turbo else 0.75 + 0.22 * i) + extra
		var distance := maxi(int(speed * (duration - ACCEL / 2.0)), ROWS + 3)
		var strip: Array = m.strips[i]
		var tape := []
		for row in ROWS:
			tape.append(strip[(stops[i] + row) % strip.size()])
		for n in range(distance - ROWS, 0, -1):
			tape.append(strip[posmod(old_stops[i] - n, strip.size())])
		for row in ROWS + 1:
			tape.append(strip[(old_stops[i] + row) % strip.size()])
		reels[i] = {"tape": tape, "pos": float(distance), "start": float(distance), "t": 0.0, "speed": speed,
				"accel": ACCEL, "state": "spin", "bounce_t": 0.0, "tease": tease}
		if grid[i].has("scatter"):
			scatters_before += 1
	spinning = true
	landed_scatters = 0
	message = ""
	coins.clear()
	sfx.play("spin")
	_save()


## Stops every spinning reel almost at once.
func _slam() -> void:
	for i in reels.size():
		var reel: Dictionary = reels[i]
		if reel.state != "spin":
			continue
		var target := minf(reel.pos, 2.0 + i * 1.2 + fposmod(reel.pos, 1.0))
		reel.start = target
		reel.pos = target
		reel.t = 0.0
		reel.accel = 0.0
		reel.speed = TURBO_SPEED
		reel.tease = false


func _update_reels(delta: float) -> void:
	var all_done := true
	for i in reels.size():
		var reel: Dictionary = reels[i]
		match reel.state:
			"spin":
				all_done = false
				reel.t += delta
				var t: float = reel.t
				var a: float = reel.accel
				var dist: float = reel.speed * t * t / (2.0 * a) if t < a else reel.speed * (a / 2.0 + t - a)
				reel.pos = reel.start - dist
				if reel.pos <= 0.0:
					reel.pos = 0.0
					reel.state = "bounce"
					reel.bounce_t = 0.0
					_reel_landed(i)
			"bounce":
				all_done = false
				reel.bounce_t += delta
				var v := clampf(reel.bounce_t / BOUNCE, 0.0, 1.0)
				reel.pos = -0.22 * sin(PI * v) * (1.0 - v * 0.5)
				if v >= 1.0:
					reel.pos = 0.0
					reel.state = "idle"
					reel.tape = []
	if spinning and all_done:
		spinning = false
		_spin_finished()


func _reel_landed(i: int) -> void:
	sfx.play("stop", randf_range(0.95, 1.05))
	var column: Array = reels[i].tape.slice(0, ROWS)
	if column.has("scatter") and not m.scatter.is_empty():
		landed_scatters += 1
		sfx.play("scatter", 1.0 + 0.12 * (landed_scatters - 1))
	if i + 1 < reels.size() and reels[i + 1].tease:
		sfx.play("tease")


func _spin_finished() -> void:
	idle_t = 0.0
	show_t = 0.0
	var free_round := multiplier > 1
	if win_total > 0:
		balance += win_total
		stats.biggest = maxi(stats.biggest, win_total)
		message = tr("total_win") % _money(win_total)
		if free_round:
			fs_win += win_total
	else:
		message = tr("no_win")
	if outcome.jackpot:
		var share := float(spin_bet / m.lines) / LINE_BETS[-1]
		var prize := int(jackpots[m.id] * share)
		# A max bet takes it all; smaller bets take their share and leave the rest.
		jackpots[m.id] = maxf(jackpots[m.id] - prize, float(_jackpot_seed(m)))
		balance += prize
		win_total += prize
		stats.jackpots += 1
		stats.biggest = maxi(stats.biggest, win_total)
		overlays.append({"kind": "jackpot", "amount": prize, "t": 0.0})
		sfx.play("jackpot")
	var ratio := float(win_total) / maxf(spin_bet, 1.0)
	if ratio >= 15.0 and not outcome.jackpot:
		var level := "big_win"
		if ratio >= 60.0:
			level = "epic_win"
		elif ratio >= 30.0:
			level = "mega_win"
		overlays.append({"kind": "big", "level": level, "amount": win_total, "t": 0.0})
		sfx.play("big")
		sfx.play("coins")
		_burst(60 if level == "big_win" else 120)
	elif win_total > 0:
		sfx.play("win")
		if ratio >= 3.0:
			_burst(int(clampf(ratio * 4.0, 10.0, 50.0)))
	# Free spins start or come back.
	if outcome.scatters.size() >= 3 and not m.scatter.is_empty():
		if free_round:
			fs_left += Machines.FREE_SPINS
			fs_total += Machines.FREE_SPINS
			overlays.append({"kind": "more", "amount": Machines.FREE_SPINS, "t": 0.0})
		else:
			fs_left = Machines.FREE_SPINS
			fs_total = Machines.FREE_SPINS
			fs_played = 0
			fs_win = 0
			stats.free_rounds += 1
			overlays.append({"kind": "free", "amount": Machines.FREE_SPINS, "t": 0.0})
		sfx.play("free")
	elif free_round and fs_left == 0:
		overlays.append({"kind": "free_end", "amount": fs_win, "t": 0.0})
		sfx.play("big")
		multiplier = 1
	if balance < _total_bet() and fs_left == 0:
		auto = false
		if balance < LINE_BETS[0] * m.lines:
			message = tr("broke")
	_save()


func _skip_overlay() -> void:
	if overlays.is_empty():
		return
	if overlays[0].t < 0.6:
		return
	overlays.pop_front()
	sfx.play("click")


func _burst(count: int) -> void:
	for i in count:
		coins.append({
			"pos": Vector2(randf_range(200, 1080), randf_range(-60, -10)) if i % 2 == 0 else Vector2(640, 380),
			"vel": Vector2(randf_range(-80, 80), randf_range(0, 120)) if i % 2 == 0 else Vector2.from_angle(randf_range(-PI * 0.9, -PI * 0.1)) * randf_range(350, 750),
			"spin": randf_range(6, 14),
			"phase": randf() * TAU,
			"t": -randf() * 0.6,
		})


# --- Frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	clock += delta
	idle_t += delta
	for id in jackpots:
		jackpots[id] += delta * _jackpot_seed(machines[_machine_index(id)]) * 0.0004  # other players feed it too
	if screen == "machine":
		_update_reels(delta)
		if not spinning:
			show_t += delta
			var count_time := 0.6 if win_total < spin_bet * 5 else 2.0
			shown_win = minf(win_total, shown_win + win_total * delta / count_time)
			if shown_win < win_total and int(clock * 20.0) != int((clock - delta) * 20.0):
				sfx.play("tick", 1.0 + shown_win / maxf(win_total, 1.0) * 0.5)
		if not overlays.is_empty():
			overlays[0].t += delta
			var limit: float = {"big": 5.0, "jackpot": 6.0, "free": 3.0, "more": 2.2, "free_end": 4.0}[overlays[0].kind]
			if overlays[0].t >= limit:
				overlays.pop_front()
		elif not spinning and not menu_open and not table_open and (fs_left > 0 or auto):
			var wait := 0.5 if win_total == 0 else (1.2 if turbo else 1.8)
			if fs_left > 0 and fs_played == 0:
				wait = 0.4
			if idle_t >= wait:
				_spin()
	shown_balance = lerpf(shown_balance, balance, 1.0 - exp(-delta * 4.0))
	if absf(shown_balance - balance) < 0.5:
		shown_balance = balance
	var material := background.material as ShaderMaterial
	material.set_shader_parameter("boost", 1.0 if fs_left > 0 or multiplier > 1 else 0.0)
	for coin in coins:
		coin.t += delta
		if coin.t > 0.0:
			coin.vel.y += 900.0 * delta
			coin.pos += coin.vel * delta
	coins = coins.filter(func(c): return c.t < 3.5 and c.pos.y < SCREEN.y + 40)
	queue_redraw()
	overlay.queue_redraw()
	for node in reel_nodes:
		node.queue_redraw()


func _machine_index(id: String) -> int:
	for i in machines.size():
		if machines[i].id == id:
			return i
	return 0


# --- Input -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		_update_hover()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse = event.position
		_update_hover()
		_click()
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)
	elif event is InputEventJoypadButton and event.pressed:
		_pad(event.button_index)


func _key(code: int) -> void:
	if code == KEY_ESCAPE:
		if menu_open or table_open:
			menu_open = false
			table_open = false
			sfx.play("click")
		elif screen == "machine":
			_back_to_lobby()
		else:
			_toggle_menu()
		return
	if menu_open:
		return
	if screen == "lobby":
		match code:
			KEY_LEFT: _move_focus(-1)
			KEY_RIGHT: _move_focus(1)
			KEY_UP, KEY_DOWN: _move_focus(5 if focus_card < 5 else -5)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _open_machine(focus_card)
		return
	match code:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: _spin()
		KEY_UP: _change_bet(1)
		KEY_DOWN: _change_bet(-1)
		KEY_M: _max_bet()
		KEY_A: _toggle_auto()
		KEY_T: _toggle_turbo()
		KEY_I: _toggle_table()


func _pad(button: int) -> void:
	match button:
		JOY_BUTTON_START:
			_toggle_menu()
			return
		JOY_BUTTON_B:
			_key(KEY_ESCAPE)
			return
	if menu_open:
		return
	if screen == "lobby":
		match button:
			JOY_BUTTON_DPAD_LEFT: _move_focus(-1)
			JOY_BUTTON_DPAD_RIGHT: _move_focus(1)
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN: _move_focus(5 if focus_card < 5 else -5)
			JOY_BUTTON_A: _open_machine(focus_card)
		return
	match button:
		JOY_BUTTON_A: _spin()
		JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_UP: _change_bet(1)
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_DOWN: _change_bet(-1)
		JOY_BUTTON_Y: _toggle_auto()
		JOY_BUTTON_X: _toggle_turbo()
		JOY_BUTTON_BACK: _toggle_table()


func _move_focus(step: int) -> void:
	focus_card = posmod(focus_card + step, machines.size())
	sfx.play("click")


func _update_hover() -> void:
	hover = ""
	hover_card = -1
	hover_line = -1
	if menu_open or table_open:
		return
	if BUTTONS.menu.has_point(mouse):
		hover = "menu"
		return
	if screen == "lobby":
		for i in machines.size():
			if _card_rect(i).has_point(mouse):
				hover_card = i
				focus_card = i
		return
	for button in BUTTONS:
		if button == "spin":
			if mouse.distance_to(BUTTONS.spin.get_center()) <= 62:
				hover = button
		elif BUTTONS[button].has_point(mouse):
			hover = button
	for i in m.lines:
		if _line_tab(i, true).has_point(mouse) or _line_tab(i, false).has_point(mouse):
			hover_line = i


func _click() -> void:
	if menu_open:
		_menu_click()
		return
	if table_open:
		table_open = false
		sfx.play("click")
		return
	if hover == "menu":
		_toggle_menu()
		return
	if screen == "lobby":
		if hover_card >= 0:
			_open_machine(hover_card)
		return
	if not overlays.is_empty():
		_skip_overlay()
		return
	match hover:
		"back": _back_to_lobby()
		"info": _toggle_table()
		"minus": _change_bet(-1)
		"plus": _change_bet(1)
		"max": _max_bet()
		"auto": _toggle_auto()
		"turbo": _toggle_turbo()
		"spin": _spin()


func _bet_locked() -> bool:
	return spinning or fs_left > 0 or multiplier > 1


func _change_bet(step: int) -> void:
	if _bet_locked():
		return
	var next := clampi(bet_index[m.id] + step, 0, LINE_BETS.size() - 1)
	if next != bet_index[m.id]:
		bet_index[m.id] = next
		sfx.play("click", 1.0 + next * 0.05)
		_save()


func _max_bet() -> void:
	if _bet_locked():
		return
	var best := 0
	for i in LINE_BETS.size():
		if LINE_BETS[i] * m.lines <= balance:
			best = i
	bet_index[m.id] = best
	sfx.play("click", 1.3)
	_save()


func _toggle_auto() -> void:
	auto = not auto
	idle_t = 0.0
	sfx.play("click")


func _toggle_turbo() -> void:
	turbo = not turbo
	sfx.play("click")
	_save()


func _toggle_table() -> void:
	if screen != "machine":
		return
	table_open = not table_open
	sfx.play("click")
	_update_hover()


func _toggle_menu() -> void:
	menu_open = not menu_open
	reset_armed = false
	sfx.play("click")
	_update_hover()


func _menu_rows() -> Dictionary:
	var x := MENU_RECT.position.x + 30
	var w := MENU_RECT.size.x - 60
	var y := MENU_RECT.position.y
	return {
		"language": Rect2(x, y + 76, w, 46),
		"sound": Rect2(x, y + 128, w, 46),
		"reset": Rect2(x, y + 380, w, 44),
		"close": Rect2(MENU_RECT.end.x - 52, y + 12, 40, 40),
	}


func _menu_click() -> void:
	if not MENU_RECT.has_point(mouse):
		_toggle_menu()
		return
	var rows := _menu_rows()
	if rows.language.has_point(mouse):
		var codes := StringsScript.LANGUAGES.map(func(l): return l[0])
		var step := -1 if mouse.x < rows.language.get_center().x - 60 else 1
		language = codes[(codes.find(language) + step + codes.size()) % codes.size()]
		_apply_settings()
		sfx.play("click")
		_save()
	elif rows.sound.has_point(mouse):
		sound_on = not sound_on
		_apply_settings()
		sfx.play("click")
		_save()
	elif rows.reset.has_point(mouse):
		if not reset_armed:
			reset_armed = true
			sfx.play("click")
			return
		if spinning or fs_left > 0:
			return
		balance = START_BALANCE
		shown_balance = balance
		stats = {"spins": 0, "biggest": 0, "jackpots": 0, "free_rounds": 0}
		for machine in machines:
			jackpots[machine.id] = float(_jackpot_seed(machine))
			bet_index[machine.id] = 1
		overlays.clear()
		multiplier = 1
		win_total = 0
		shown_win = 0.0
		outcome = {}
		menu_open = false
		sfx.play("coins")
		_save()
	elif rows.close.has_point(mouse):
		_toggle_menu()
	reset_armed = false


# --- Saving ----------------------------------------------------------------------------------

## A spin that is still rolling counts as already paid.
func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "balance", balance + (win_total if spinning else 0))
	config.set_value("game", "jackpots", jackpots)
	config.set_value("game", "bets", bet_index)
	config.set_value("game", "stats", stats)
	config.set_value("settings", "language", language)
	config.set_value("settings", "sound", sound_on)
	config.set_value("settings", "turbo", turbo)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	balance = int(config.get_value("game", "balance", START_BALANCE))
	var saved_jackpots: Dictionary = config.get_value("game", "jackpots", {})
	for id in jackpots:
		jackpots[id] = maxf(float(saved_jackpots.get(id, jackpots[id])), jackpots[id])
	var saved_bets: Dictionary = config.get_value("game", "bets", {})
	for id in bet_index:
		bet_index[id] = clampi(int(saved_bets.get(id, 1)), 0, LINE_BETS.size() - 1)
	var saved_stats: Dictionary = config.get_value("game", "stats", {})
	for key in stats:
		stats[key] = int(saved_stats.get(key, stats[key]))
	language = config.get_value("settings", "language", "")
	sound_on = config.get_value("settings", "sound", true)
	turbo = config.get_value("settings", "turbo", false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


# --- Drawing helpers -------------------------------------------------------------------------

func _money(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


func _text(text: String, center: Vector2, size: int, color: Color, f: Font = null, outline := 0, outline_color := Color(0, 0, 0, 0.7)) -> void:
	if f == null:
		f = bold
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2(center.x - width / 2.0, center.y + (f.get_ascent(size) - f.get_descent(size)) / 2.0)
	if outline > 0:
		cv.draw_string_outline(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(outline_color, outline_color.a * color.a))
	cv.draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_left(text: String, pos: Vector2, size: int, color: Color, f: Font = null) -> void:
	if f == null:
		f = font
	cv.draw_string(f, Vector2(pos.x, pos.y + (f.get_ascent(size) - f.get_descent(size)) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_right(text: String, pos: Vector2, size: int, color: Color, f: Font = null) -> void:
	if f == null:
		f = bold
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text_left(text, Vector2(pos.x - width, pos.y), size, color, f)


func _box(rect: Rect2, fill: Color, border: Color, radius: float, width := 1.5, shadow := 0.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(int(width) if width >= 1.0 else 0)
	style.set_corner_radius_all(int(radius))
	style.anti_aliasing = true
	if shadow > 0.0:
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = int(shadow)
		style.shadow_offset = Vector2(0, shadow * 0.4)
	cv.draw_style_box(style, rect)


func _gradient_rect(rect: Rect2, top: Color, bottom: Color) -> void:
	cv.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
			PackedColorArray([top, top, bottom, bottom]))


func _line_color(i: int) -> Color:
	return Color.from_hsv(fmod(i * 0.137 + 0.02, 1.0), 0.75, 1.0)


# --- Drawing: shared -------------------------------------------------------------------------

func _draw() -> void:
	cv = self
	if screen == "lobby":
		_draw_lobby()
	else:
		_draw_machine()


func _draw_header(title: String, color: Color) -> void:
	_gradient_rect(Rect2(0, 0, SCREEN.x, 60), Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.45))
	cv.draw_line(Vector2(0, 60), Vector2(SCREEN.x, 60), Color(GOLD, 0.7), 2.0)
	_text(title, Vector2(SCREEN.x / 2.0, 30), 30, color, serif, 8, Color(0, 0, 0, 0.8))
	var pill := Rect2(960, 8, 236, 44)
	var counting := shown_balance < balance - 0.5
	if counting:
		_box(pill.grow(4), Color(GOLD, 0.3 + 0.2 * sin(clock * 20.0)), Color(0, 0, 0, 0), 14, 0.0)
	_box(pill, Color(0, 0, 0, 0.55), Color(GOLD, 0.6), 12, 1.5)
	_coin_icon(Vector2(pill.position.x + 24, pill.get_center().y), 13)
	_text_left(tr("balance"), Vector2(pill.position.x + 46, pill.position.y + 13), 10, MUTED, bold)
	_text_left(_money(roundi(shown_balance)), Vector2(pill.position.x + 46, pill.position.y + 30), 20, GOLD_LIGHT, bold)
	# Menu gear.
	var center: Vector2 = BUTTONS.menu.get_center()
	var points := PackedVector2Array()
	for i in 48:
		var tooth := fmod(float(i), 6.0) < 3.0
		points.append(center + Vector2.from_angle(i * TAU / 48.0) * (13.0 if tooth else 10.0))
	cv.draw_colored_polygon(points, GOLD_LIGHT if hover == "menu" else GOLD)
	cv.draw_circle(center, 5, Color(0.05, 0.02, 0.08))


func _coin_icon(center: Vector2, r: float) -> void:
	cv.draw_circle(center, r, GOLD_DEEP)
	cv.draw_circle(center + Vector2(-0.8, -0.8), r * 0.82, GOLD)
	cv.draw_arc(center, r * 0.6, 0, TAU, 20, GOLD_DEEP, 1.5, true)


func _draw_coins(canvas: CanvasItem) -> void:
	for coin in coins:
		if coin.t < 0.0:
			continue
		var squash := absf(cos(coin.phase + coin.t * coin.spin))
		var alpha := clampf(3.5 - coin.t, 0.0, 1.0)
		canvas.draw_set_transform(coin.pos, 0.0, Vector2(maxf(squash, 0.12), 1.0))
		canvas.draw_circle(Vector2.ZERO, 12, Color(GOLD_DEEP, alpha))
		canvas.draw_circle(Vector2(-1, -1), 10, Color(GOLD, alpha))
		canvas.draw_circle(Vector2(-3, -3), 3.5, Color(GOLD_LIGHT, alpha))
		canvas.draw_set_transform(Vector2.ZERO)


# --- Drawing: lobby --------------------------------------------------------------------------

func _draw_lobby() -> void:
	_draw_header("", INK)
	# Logo: three mini reels and the name.
	for i in 3:
		var r := Rect2(20 + i * 26, 12, 24, 36)
		_box(r, Color("fff8e8"), GOLD, 4, 1.5)
		_text("7", r.get_center(), 22, Color("e0102a"), serif)
	_text_left("SLOT MACHINE", Vector2(106, 22), 22, GOLD, serif)
	_text_left("PRO", Vector2(106, 44), 16, Color("ff5ec4"), bold)
	_text(tr("choose"), Vector2(SCREEN.x / 2.0, 30), 24, INK, serif, 6)
	for i in machines.size():
		_draw_card(i)
	_text(tr("play_money"), Vector2(SCREEN.x / 2.0, 700), 12, MUTED, font)


func _draw_card(i: int) -> void:
	var machine: Dictionary = machines[i]
	var colors: Dictionary = machine.colors
	var hot := i == hover_card or (hover_card < 0 and i == focus_card and not menu_open)
	var rect := _card_rect(i)
	if hot:
		rect.position.y -= 6
		_box(rect.grow(5), Color(Color(colors.trim), 0.35 + 0.15 * sin(clock * 5.0)), Color(0, 0, 0, 0), 20, 0.0)
	_box(rect, Color(colors.bg2), Color(colors.trim), 16, 2.0, 10)
	# Art: the machine's colors behind three of its best symbols.
	var art_rect := Rect2(rect.position + Vector2(8, 8), Vector2(rect.size.x - 16, 146))
	_gradient_rect(art_rect, Color(colors.bg).lightened(0.15), Color(colors.bg2))
	var window := Rect2(art_rect.position + Vector2(10, 34), Vector2(art_rect.size.x - 20, 76))
	_gradient_rect(window, Color(colors.reel), Color(colors.reel2))
	cv.draw_rect(window, Color(colors.trim), false, 2.0)
	var picks := _showcase(machine)
	for k in 3:
		var center := Vector2(window.position.x + window.size.x * (k + 0.5) / 3.0, window.get_center().y)
		var bob := sin(clock * 3.0 + k + i) * 2.0 if hot else 0.0
		art.draw(cv, picks[k], center + Vector2(0, bob), 56, Color(colors.accent))
	_text(machine.name, Vector2(art_rect.get_center().x, art_rect.position.y + 18), 19, INK, serif, 6)
	var badge := tr("classic_badge") if machine.reels == 3 else tr("free_spins_badge")
	_text(badge, Vector2(art_rect.get_center().x, art_rect.end.y - 16), 11, Color(colors.trim), bold, 4)
	# Details.
	var y := art_rect.end.y + 13
	_text(tr("format") % [machine.reels, machine.lines], Vector2(rect.get_center().x, y), 13, MUTED, font)
	_text(tr("jackpot"), Vector2(rect.get_center().x, y + 20), 10, Color(colors.trim), bold)
	_text(_money(int(jackpots[machine.id])), Vector2(rect.get_center().x, y + 38), 22, GOLD_LIGHT, bold, 4)
	var play := Rect2(rect.position.x + 34, rect.end.y - 50, rect.size.x - 68, 38)
	_box(play, Color(colors.accent).darkened(0.1) if hot else Color(colors.frame), Color(colors.trim), 19, 1.5)
	_text(tr("play"), play.get_center(), 16, INK, bold, 4)


## The three symbols shown on a machine's card: its best paying ones.
func _showcase(machine: Dictionary) -> Array:
	if machine.id == "classic":
		return ["seven_red", "seven_red", "seven_red"]
	if machine.id == "hot":
		return ["seven_blue", "seven_red", "seven_blue"]
	var ids := []
	for entry in machine.symbols:
		if entry[0] != "wild" and entry[0] != "scatter":
			ids.append(entry[0])
	return [ids[-2], ids[-1], "wild"]


# --- Drawing: machine ------------------------------------------------------------------------

func _draw_machine() -> void:
	_draw_header(m.name, _color("trim"))
	# Back button.
	var back: Rect2 = BUTTONS.back
	var enabled := not (spinning or fs_left > 0 or not overlays.is_empty())
	_box(back, Color(0, 0, 0, 0.5 if hover != "back" else 0.75), Color(GOLD, 0.7 if enabled else 0.25), 12, 1.5)
	_text("‹  " + tr("lobby"), back.get_center(), 16, Color(INK, 1.0 if enabled else 0.4), bold)
	_draw_banner()
	_draw_cabinet()
	_draw_panel()


func _draw_banner() -> void:
	var rect := Rect2(SCREEN.x / 2.0 - 190, 66, 380, 42)
	var free := fs_left > 0 or multiplier > 1
	var glow := 0.5 + 0.5 * sin(clock * 4.0)
	_box(rect.grow(3), Color(_color("trim"), 0.2 + 0.2 * glow), Color(0, 0, 0, 0), 16, 0.0)
	_box(rect, Color(0, 0, 0, 0.65), _color("trim"), 14, 2.0)
	if free:
		var current := fs_played
		_text(tr("free_left") % [current, fs_total] + "   ×%d" % Machines.FREE_SPIN_MULTIPLIER, rect.get_center(), 20, GOLD_LIGHT, bold, 4)
	else:
		_text(tr("jackpot"), Vector2(rect.position.x + 64, rect.get_center().y), 15, _color("trim"), bold)
		_text(_money(int(jackpots[m.id])), Vector2(rect.get_center().x + 44, rect.get_center().y), 24, GOLD_LIGHT, bold, 5)


func _draw_cabinet() -> void:
	var width: float = m.reels * cell_w + (m.reels - 1) * REEL_GAP
	var inner := Rect2(reels_x, REELS_Y, width, CELL_H * ROWS)
	var frame := inner.grow(18)
	frame.position.x -= 34
	frame.size.x += 68
	_box(frame.grow(4), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 26, 0.0, 16)
	_box(frame, _color("frame"), _color("trim"), 24, 3.0)
	_box(frame.grow(-6), _color("frame").darkened(0.3), Color(_color("trim"), 0.5), 20, 1.0)
	# Studs along the frame, lighting up in turn.
	for i in 14:
		var t := float(i) / 13.0
		var on := int(clock * 6.0 + i) % 3 == 0 or spinning and int(clock * 14.0 + i) % 2 == 0
		for y in [frame.position.y + 9, frame.end.y - 9]:
			var p := Vector2(lerpf(frame.position.x + 30, frame.end.x - 30, t), y)
			cv.draw_circle(p, 3.5, GOLD_LIGHT if on else Color(_color("trim"), 0.35))
	# Reel backgrounds.
	for i in m.reels:
		var r := Rect2(_reel_x(i), REELS_Y, cell_w, CELL_H * ROWS)
		_gradient_rect(r.grow(3), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6))
		_gradient_rect(r, _color("reel"), _color("reel2"))
	# Line numbers on both sides.
	for i in m.lines:
		for left in [true, false]:
			var tab := _line_tab(i, left)
			var col := _line_color(i)
			var lit: bool = hover_line == i or _line_winning(i)
			_box(tab, col if lit else col.darkened(0.45), Color(0, 0, 0, 0.6), 4, 1.0)
			_text(str(i + 1), tab.get_center(), 11 if m.lines > 10 else 14, INK if lit else Color(INK, 0.8), bold)


func _line_tab(i: int, left: bool) -> Rect2:
	var width: float = m.reels * cell_w + (m.reels - 1) * REEL_GAP
	var height: float = CELL_H * ROWS / m.lines
	var h := minf(height - 2.0, 26.0)
	var y: float = REELS_Y + (i + 0.5) * height - h / 2.0
	var x: float = reels_x - 40 if left else reels_x + width + 12
	return Rect2(x, y, 28, h)


func _line_winning(i: int) -> bool:
	if spinning or outcome.is_empty():
		return false
	for win in outcome.lines:
		if win.line == i:
			return true
	return false


## Draws one reel's symbols; `node` is the clipped reel window.
func _draw_reel(i: int, node: Control) -> void:
	if i >= reels.size():
		return
	var reel: Dictionary = reels[i]
	var pos: float = reel.pos
	var top := floori(pos)
	var frac := pos - top
	var moving: bool = reel.state == "spin"
	var blur: bool = moving and reel.t > ACCEL
	for r in range(-1, ROWS + 1):
		var id := _reel_symbol(i, top + r)
		var center := Vector2(cell_w / 2.0, (r - frac + 0.5) * CELL_H)
		var size := minf(cell_w, CELL_H) * 0.78
		var cell := Vector2i(i, top + r)
		if not moving and not spinning and _is_winning_cell(cell):
			size *= 1.0 + 0.08 * sin(show_t * 9.0)
		if blur:
			# Stretched while it races past, like motion blur.
			node.draw_set_transform(center, 0.0, Vector2(0.9, 1.35))
			art.draw(node, id, Vector2.ZERO, size, _color("accent"))
			node.draw_set_transform(Vector2.ZERO)
		else:
			art.draw(node, id, center, size, _color("accent"))
	# Soft shading at the top and bottom of the window, like a curved drum.
	var h := CELL_H * ROWS
	node.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(cell_w, 0), Vector2(cell_w, 26), Vector2(0, 26)]),
			PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	node.draw_polygon(PackedVector2Array([Vector2(0, h - 26), Vector2(cell_w, h - 26), Vector2(cell_w, h), Vector2(0, h)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35)]))


func _reel_symbol(i: int, index: int) -> String:
	var strip: Array = m.strips[i]
	var tape: Array = reels[i].tape
	if tape.is_empty() or index < 0:
		return strip[posmod(stops[i] + index, strip.size())]
	if index < tape.size():
		return tape[index]
	return strip[posmod(stops[i] + index, strip.size())]


func _is_winning_cell(cell: Vector2i) -> bool:
	if outcome.is_empty() or cell.y < 0 or cell.y >= ROWS:
		return false
	for win in _shown_wins():
		if cell in win.cells:
			return true
	if outcome.scatter_amount > 0 and cell in outcome.scatters:
		return true
	return false


## The line wins being shown right now: all of them first, then one at a time.
func _shown_wins() -> Array:
	if outcome.is_empty() or spinning:
		return []
	var wins: Array = outcome.lines
	if wins.is_empty() or show_t < 1.6:
		return wins
	return [wins[int((show_t - 1.6) / 1.4) % wins.size()]]


func _draw_panel() -> void:
	var panel := Rect2(20, 578, SCREEN.x - 40, 124)
	_box(panel, PANEL, Color(_color("trim"), 0.6), 18, 1.5, 10)
	var locked := _bet_locked()
	# Pay table.
	var info: Rect2 = BUTTONS.info
	cv.draw_circle(info.get_center(), 28, Color(_color("trim"), 0.9 if hover == "info" else 0.7))
	cv.draw_circle(info.get_center(), 24, _color("frame").darkened(0.2))
	_text("i", info.get_center() + Vector2(0, -1), 30, INK, serif)
	# Lines.
	var lines_box := Rect2(116, 600, 100, 68)
	_text(tr("lines"), Vector2(lines_box.get_center().x, lines_box.position.y + 16), 11, MUTED, bold)
	_text(str(m.lines), Vector2(lines_box.get_center().x, lines_box.position.y + 44), 28, INK, bold)
	# Bet.
	var bet_box := Rect2(286, 598, 180, 72)
	_box(bet_box, Color(0, 0, 0, 0.45), Color(_color("trim"), 0.5), 12, 1.0)
	_text(tr("bet"), Vector2(bet_box.get_center().x, bet_box.position.y + 16), 11, MUTED, bold)
	_text(_money(spin_bet if multiplier > 1 or fs_left > 0 else _total_bet()), Vector2(bet_box.get_center().x, bet_box.position.y + 46), 28, GOLD_LIGHT, bold)
	for button in ["minus", "plus"]:
		var rect: Rect2 = BUTTONS[button]
		var can: bool = not locked and (bet_index[m.id] > 0 if button == "minus" else bet_index[m.id] < LINE_BETS.size() - 1)
		cv.draw_circle(rect.get_center(), 24, Color(_color("trim"), (0.95 if hover == button else 0.75) if can else 0.25))
		cv.draw_circle(rect.get_center(), 20, _color("frame").darkened(0.2))
		var c := rect.get_center()
		cv.draw_line(c - Vector2(9, 0), c + Vector2(9, 0), Color(INK, 1.0 if can else 0.35), 4.0)
		if button == "plus":
			cv.draw_line(c - Vector2(0, 9), c + Vector2(0, 9), Color(INK, 1.0 if can else 0.35), 4.0)
	_pill_button("max", tr("max_bet"), false, not locked)
	# Win.
	var win_box := Rect2(648, 594, 260, 80)
	var winning := shown_win > 0.0
	_box(win_box, Color(0, 0, 0, 0.55), Color(GOLD, 0.8) if winning else Color(_color("trim"), 0.4), 14, 2.0 if winning else 1.0)
	_text(tr("win"), Vector2(win_box.get_center().x, win_box.position.y + 16), 11, MUTED, bold)
	_text(_money(int(shown_win)), Vector2(win_box.get_center().x, win_box.position.y + 48), 34 if winning else 28,
			WIN_GREEN if winning else Color(INK, 0.5), bold, 4 if winning else 0)
	_pill_button("auto", tr("auto"), auto, true)
	_pill_button("turbo", tr("turbo"), turbo, true)
	_draw_spin_button()
	# Message above the panel: the line being shown, or news about the spin.
	if not overlays.is_empty():
		return
	var wins := _shown_wins()
	if wins.size() == 1 and (show_t >= 1.6 or outcome.lines.size() == 1):
		var win: Dictionary = wins[0]
		_draw_message_with_icon(tr("line_win") % [win.line + 1, win.count, _money(win.amount)], win.symbol)
	else:
		_text(message, Vector2(SCREEN.x / 2.0, 552), 20, INK, serif, 6)


func _draw_message_with_icon(text: String, symbol: String) -> void:
	var width := serif.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var x := SCREEN.x / 2.0 - (width + 40) / 2.0
	art.draw(cv, symbol, Vector2(x + 16, 552), 34, _color("accent"))
	_text(text, Vector2(x + 40 + width / 2.0, 552), 20, INK, serif, 6)


func _pill_button(button: String, label: String, on: bool, enabled: bool) -> void:
	var rect: Rect2 = BUTTONS[button]
	var hot := enabled and hover == button
	var fill := _color("accent").darkened(0.15) if on else Color(0, 0, 0, 0.5)
	if hot and not on:
		fill = Color(_color("frame"), 0.9)
	_box(rect, fill, Color(_color("trim"), 0.9 if enabled else 0.25), 24, 1.5)
	_text(label, rect.get_center(), 15 if label.length() <= 8 else 12, Color(INK, 1.0 if enabled else 0.35), bold, 3 if on else 0)


func _draw_spin_button() -> void:
	var c: Vector2 = BUTTONS.spin.get_center()
	var hot := hover == "spin"
	var refill: bool = not spinning and fs_left == 0 and balance < LINE_BETS[0] * m.lines
	var pulse := 0.5 + 0.5 * sin(clock * 4.0)
	cv.draw_circle(c, 66 + pulse * 3.0, Color(_color("trim"), 0.18 + 0.1 * pulse))
	cv.draw_circle(c + Vector2(0, 4), 60, Color(0, 0, 0, 0.5))
	cv.draw_circle(c, 60, _color("trim").darkened(0.35))
	cv.draw_circle(c, 55, _color("accent").lightened(0.15 if hot else 0.0))
	cv.draw_circle(c + Vector2(0, 4), 46, _color("accent").darkened(0.2))
	cv.draw_arc(c, 50, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.35), 6.0, true)
	var label := tr("spin")
	if spinning:
		label = tr("stop")
	elif refill:
		label = tr("refill")
	if not spinning and not refill:
		var turn := clock * 2.0 if auto or fs_left > 0 else 0.0
		cv.draw_arc(c + Vector2(0, -14), 13, turn + 0.4, turn + TAU - 0.8, 24, INK, 4.0, true)
		var tip := c + Vector2(0, -14) + Vector2.from_angle(turn + TAU - 0.8) * 13
		var out := Vector2.from_angle(turn + TAU - 0.8)
		cv.draw_colored_polygon(PackedVector2Array([tip + out.orthogonal() * -7, tip + out * 6, tip - out * 6]), INK)
		_text(label, c + Vector2(0, 18), 18, INK, bold, 5, Color(0, 0, 0, 0.5))
	else:
		_text(label, c, 20, INK, bold, 5, Color(0, 0, 0, 0.5))


# --- Drawing: overlay (above the reels) ------------------------------------------------------

func _draw_overlay() -> void:
	cv = overlay
	if screen == "machine":
		_draw_wins()
		if table_open:
			_draw_table()
		if not overlays.is_empty():
			_draw_big(overlays[0])
	_draw_coins(overlay)
	if menu_open:
		_draw_menu()


func _draw_wins() -> void:
	# Glow around reels that are teasing a bonus.
	for i in reels.size():
		if reels[i].state == "spin" and reels[i].tease and reels[i].t > 0.0:
			var r := Rect2(_reel_x(i), REELS_Y, cell_w, CELL_H * ROWS).grow(4)
			var pulse := 0.5 + 0.5 * sin(clock * 16.0)
			cv.draw_rect(r, Color(GOLD, 0.5 + 0.5 * pulse), false, 5.0)
			cv.draw_rect(r.grow(5), Color(GOLD, 0.25 * pulse), false, 6.0)
	if spinning:
		return
	if hover_line >= 0 and _shown_wins().is_empty():
		_draw_payline(hover_line, 0.9)
		return
	var wins := _shown_wins()
	var scatter_win: bool = not outcome.is_empty() and outcome.scatter_amount > 0
	if wins.is_empty() and not scatter_win:
		return
	# Dim what didn't win.
	for reel in m.reels:
		for row in ROWS:
			if not _is_winning_cell(Vector2i(reel, row)):
				var center := _cell_center(reel, row)
				cv.draw_rect(Rect2(center - Vector2(cell_w, CELL_H) / 2.0, Vector2(cell_w, CELL_H)), Color(0, 0, 0, 0.42))
	for win in wins:
		_draw_payline(win.line, 1.0)
		for cell in win.cells:
			var center := _cell_center(cell.x, cell.y)
			var rect := Rect2(center - Vector2(cell_w, CELL_H) / 2.0, Vector2(cell_w, CELL_H)).grow(-4)
			cv.draw_rect(rect, Color(0, 0, 0, 0.6), false, 7.0)
			cv.draw_rect(rect, _line_color(win.line), false, 4.0)
	if scatter_win:
		for cell in outcome.scatters:
			var center := _cell_center(cell.x, cell.y)
			var r := minf(cell_w, CELL_H) * 0.48 + 4.0 * sin(clock * 8.0)
			cv.draw_arc(center, r, 0, TAU, 40, Color(GOLD_LIGHT, 0.9), 4.0, true)


func _draw_payline(i: int, alpha: float) -> void:
	var rows: Array = m.paylines[i]
	var points := PackedVector2Array()
	points.append(_line_tab(i, true).get_center() + Vector2(14, 0))
	for reel in rows.size():
		points.append(_cell_center(reel, rows[reel]))
	points.append(_line_tab(i, false).get_center() - Vector2(14, 0))
	cv.draw_polyline(points, Color(0, 0, 0, 0.55 * alpha), 10.0, true)
	cv.draw_polyline(points, Color(_line_color(i), alpha), 5.0, true)
	cv.draw_polyline(points, Color(1, 1, 1, 0.5 * alpha), 1.5, true)


## Big wins, jackpots and free spins announcements.
func _draw_big(item: Dictionary) -> void:
	var t: float = item.t
	var fade := clampf(t / 0.25, 0.0, 1.0)
	cv.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.6 * fade))
	var center := Vector2(SCREEN.x / 2.0, 330)
	# Turning rays.
	for i in 16:
		var a := i * TAU / 16.0 + t * 0.4
		var tri := PackedVector2Array([center, center + Vector2.from_angle(a - 0.08) * 700, center + Vector2.from_angle(a + 0.08) * 700])
		cv.draw_colored_polygon(tri, Color(GOLD, 0.08 * fade))
	var pop := _back_out(clampf(t / 0.45, 0.0, 1.0))
	var title := ""
	var sub := ""
	var amount := -1
	match item.kind:
		"big":
			title = tr(item.level)
			amount = int(item.amount * clampf(t / 3.0, 0.0, 1.0))
		"jackpot":
			title = tr("jackpot")
			amount = int(item.amount * clampf(t / 3.5, 0.0, 1.0))
		"free":
			title = tr("free_spins")
			sub = tr("free_spins_won") % [item.amount, Machines.FREE_SPIN_MULTIPLIER]
		"more":
			title = tr("more_spins") % item.amount
		"free_end":
			title = tr("free_total")
			amount = int(item.amount * clampf(t / 2.0, 0.0, 1.0))
	var size := int(84 * pop)
	if size > 4:
		var wobble := sin(t * 5.0) * 0.03
		cv.draw_set_transform(center + Vector2(0, -40), wobble)
		_text(title, Vector2.ZERO, size, GOLD, serif, 16, Color("3a1a00"))
		_text(title, Vector2(0, -3), size, GOLD_LIGHT, serif, 0)
		cv.draw_set_transform(Vector2.ZERO)
	if amount >= 0 and t > 0.3:
		_text(_money(amount), center + Vector2(0, 60), 64, WIN_GREEN, bold, 12, Color(0, 0.15, 0.05))
	if sub != "" and t > 0.3:
		_text(sub, center + Vector2(0, 50), 28, INK, bold, 8)
	if item.kind == "free":
		for i in 3:
			art.draw(cv, "scatter", center + Vector2((i - 1) * 100, 128), 76 * pop, _color("accent"))
	if t > 1.0:
		_text(tr("tap_continue"), Vector2(SCREEN.x / 2.0, 548), 15, Color(INK, 0.5 + 0.3 * sin(clock * 4.0)), font)


func _back_out(x: float) -> float:
	var s := 1.7
	x -= 1.0
	return x * x * ((s + 1.0) * x + s) + 1.0


func _draw_table() -> void:
	cv.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.7))
	var rect := TABLE_RECT
	_box(rect, _color("bg2").lerp(Color.BLACK, 0.3), _color("trim"), 20, 2.0, 16)
	_text(m.name + "  ·  " + tr("paytable"), Vector2(rect.get_center().x, rect.position.y + 32), 26, _color("trim"), serif, 6)
	_text(tr("paytable_note"), Vector2(rect.get_center().x, rect.position.y + 62), 13, MUTED, font)
	var line_bet := _line_bet()
	var entries := []
	for entry in m.symbols:
		if entry[0] != "wild" and entry[0] != "scatter":
			entries.append(entry[0])
	entries.reverse()
	var columns := 4
	var tile := Vector2(240, 88)
	var origin := Vector2(rect.get_center().x - columns * (tile.x + 10) / 2.0 + 5, rect.position.y + 84)
	for i in entries.size():
		var id: String = entries[i]
		var pos := origin + Vector2((i % columns) * (tile.x + 10), (i / columns) * (tile.y + 8))
		var r := Rect2(pos, tile)
		_box(r, Color(1, 1, 1, 0.05), Color(_color("trim"), 0.3), 10, 1.0)
		_gradient_rect(Rect2(pos + Vector2(6, 6), Vector2(76, 76)), _color("reel"), _color("reel2"))
		art.draw(cv, id, pos + Vector2(44, 44), 64, _color("accent"))
		_pays_text(m.pays[id], pos + Vector2(96, 0), tile.y, line_bet)
	# Specials.
	var y := origin.y + ceili(entries.size() / float(columns)) * (tile.y + 8) + 4
	var special := Rect2(rect.position.x + 30, y, rect.size.x - 60, 86)
	_box(special, Color(1, 1, 1, 0.05), Color(_color("trim"), 0.3), 10, 1.0)
	_gradient_rect(Rect2(special.position + Vector2(6, 5), Vector2(76, 76)), _color("reel"), _color("reel2"))
	art.draw(cv, "wild", special.position + Vector2(44, 43), 70, _color("accent"))
	_pays_text(m.pays["wild"], special.position + Vector2(96, 0), 86, line_bet)
	_text_left(tr("wild_rule") % m.reels, special.position + Vector2(250, 43), 15, INK, font)
	if not m.scatter.is_empty():
		var sc := Rect2(special.position + Vector2(0, 94), special.size)
		_box(sc, Color(1, 1, 1, 0.05), Color(_color("trim"), 0.3), 10, 1.0)
		_gradient_rect(Rect2(sc.position + Vector2(6, 5), Vector2(76, 76)), _color("reel"), _color("reel2"))
		art.draw(cv, "scatter", sc.position + Vector2(44, 43), 70, _color("accent"))
		var scatter_pays := []
		for p in m.scatter:
			scatter_pays.append(p * m.lines)
		_pays_text(scatter_pays, sc.position + Vector2(96, 0), 86, line_bet)
		_text_left(tr("scatter_rule") % [Machines.FREE_SPINS, Machines.FREE_SPIN_MULTIPLIER], sc.position + Vector2(250, 43), 15, INK, font)
		y = sc.end.y + 10
	else:
		y = special.end.y + 10
	# Payline diagrams.
	_text_left(tr("paylines"), Vector2(rect.position.x + 30, y + 10), 14, _color("trim"), bold)
	_text_right(tr("return"), Vector2(rect.end.x - 30, y + 10), 12, MUTED, font)
	var mini := Vector2(92, 40) if m.reels == 5 else Vector2(60, 40)
	for i in m.lines:
		var p := Vector2(rect.position.x + 30 + (i % 10) * (mini.x + 6), y + 24 + (i / 10) * (mini.y + 6))
		_box(Rect2(p, mini), Color(0, 0, 0, 0.35), Color(_line_color(i), 0.6), 6, 1.0)
		var step := Vector2((mini.x - 20) / (m.reels - 1), 12)
		var points := PackedVector2Array()
		for reel in m.reels:
			for row in ROWS:
				cv.draw_circle(p + Vector2(10, 8) + Vector2(reel * step.x, row * step.y), 2.0, Color(1, 1, 1, 0.25))
			points.append(p + Vector2(10, 8) + Vector2(reel * step.x, m.paylines[i][reel] * step.y))
		cv.draw_polyline(points, _line_color(i), 2.5, true)
		_text(str(i + 1), p + Vector2(mini.x - 8, 7), 9, Color(INK, 0.7), bold)


## "5×  500 / 4×  100 / 3×  20" in coins at the current line bet.
func _pays_text(pays: Array, pos: Vector2, height: float, line_bet: int) -> void:
	var count := pays.size()
	for k in count:
		var n := count - k + 2
		var y := pos.y + height / 2.0 + (k - (count - 1) / 2.0) * 20.0
		_text_left("%d×" % n, Vector2(pos.x, y), 14, MUTED, bold)
		_text_left(_money(pays[count - 1 - k] * line_bet), Vector2(pos.x + 30, y), 16, GOLD_LIGHT, bold)


func _draw_menu() -> void:
	cv.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.65))
	_box(MENU_RECT, Color("150a22"), GOLD, 18, 2.0, 18)
	var x := MENU_RECT.position.x + 30
	var right := MENU_RECT.end.x - 30
	var y := MENU_RECT.position.y
	_text_left(tr("settings"), Vector2(x, y + 38), 26, GOLD, serif)
	var rows := _menu_rows()
	var close: Rect2 = rows.close
	var hot_close := close.has_point(mouse)
	cv.draw_line(close.get_center() + Vector2(-9, -9), close.get_center() + Vector2(9, 9), GOLD_LIGHT if hot_close else INK, 2.5, true)
	cv.draw_line(close.get_center() + Vector2(9, -9), close.get_center() + Vector2(-9, 9), GOLD_LIGHT if hot_close else INK, 2.5, true)
	for key in ["language", "sound"]:
		var rect: Rect2 = rows[key]
		_box(rect, Color(1, 1, 1, 0.08 if rect.has_point(mouse) else 0.04), Color(GOLD, 0.25), 10, 1.0)
		_text_left(tr(key), Vector2(rect.position.x + 16, rect.get_center().y), 17, INK, bold)
	var lang_name := ""
	for entry in StringsScript.LANGUAGES:
		if entry[0] == language:
			lang_name = entry[1]
	_text_right("‹   " + lang_name + "   ›", Vector2(rows.language.end.x - 16, rows.language.get_center().y), 17, GOLD_LIGHT, bold)
	var sw := Rect2(rows.sound.end.x - 70, rows.sound.get_center().y - 13, 54, 26)
	_box(sw, Color("2fae5a") if sound_on else Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 13, 0.0)
	cv.draw_circle(Vector2(sw.end.x - 13 if sound_on else sw.position.x + 13, sw.get_center().y), 10, Color.WHITE)

	_text_left(tr("statistics"), Vector2(x, y + 214), 20, GOLD, serif)
	var lines := [
		["spins", _money(stats.spins)],
		["biggest_win", _money(stats.biggest)],
		["free_rounds", _money(stats.free_rounds)],
		["jackpots_won", _money(stats.jackpots)],
	]
	for i in lines.size():
		var ly := y + 250 + i * 28
		_text_left(tr(lines[i][0]), Vector2(x, ly), 16, MUTED, font)
		_text_right(lines[i][1], Vector2(right, ly), 16, INK, bold)
		if i < lines.size() - 1:
			cv.draw_line(Vector2(x, ly + 14), Vector2(right, ly + 14), Color(1, 1, 1, 0.06), 1.0)
	var reset: Rect2 = rows.reset
	var hot := reset.has_point(mouse)
	_box(reset, Color("7a1a1a") if reset_armed else Color(1, 1, 1, 0.1 if hot else 0.05), Color(GOLD, 0.5), 10, 1.0)
	_text(tr("confirm_reset") if reset_armed else tr("reset"), reset.get_center(), 16, INK, bold)
	_text(tr("help"), Vector2(MENU_RECT.get_center().x, y + 448), 12, MUTED, font)
	_text(tr("play_money"), Vector2(MENU_RECT.get_center().x, y + 472), 12, MUTED, font)
