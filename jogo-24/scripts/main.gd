extends Node2D
## 24 Game Pro (Jogo do 24 Pro): combine the four numbers on the card with + − × ÷ until one is left. Reach exactly 24 to win.
## Double Cards mode deals a figure-8 card with six numbers, and all six must be used.
## Click a number, an operation, then another number (or use the arrow keys for the numbers, + - * / for the
## operations). U / Backspace undoes, N starts a new game, Esc goes back. Statistics are kept per difficulty.

const SolverScript := preload("res://scripts/solver.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const StringsScript := preload("res://scripts/strings.gd")

const SCREEN := Vector2(1000, 720)
const SAVE_PATH := "user://jogo24.cfg"
const MAX_RESULTS := 500

## Difficulty levels: number range and the operations that may be needed.
const LEVELS := [
	{"key": "level_easy", "lo": 1, "hi": 6, "ops": ["+", "-", "*"]},
	{"key": "level_medium", "lo": 1, "hi": 9, "ops": ["+", "-", "*", "/"]},
	{"key": "level_hard", "lo": 1, "hi": 13, "ops": ["+", "-", "*", "/"]},
	{"key": "level_very_hard", "lo": 2, "hi": 20, "ops": ["+", "-", "*", "/"]},
]
## Hard levels sometimes disguise a number as its square root ("√16" for 4) up to this value ...
const RADICAL_MAX := {2: 8, 3: 15}
## ... or as an unreduced fraction ("10/2" for 5) with a denominator in this range.
const FRACTION_DEN := {2: [2, 3], 3: [2, 5]}
const OPS := ["+", "-", "*", "/"]
## Game modes: how many numbers are dealt. The card's layout follows the count (4 = classic, 6 = double).
const MODES := [{"key": "mode_classic", "count": 4}, {"key": "mode_double", "count": 6}]
## Double card slots, clockwise from the top: top, upper right, lower right, bottom, lower left, upper left.
const DOUBLE_ANGLES := [0.0, PI / 2.0, PI / 2.0, PI, -PI / 2.0, -PI / 2.0]
## The four numbers sit at the top, right, bottom and left of the card.
## Numbers are turned so their tops face the card's edges, like on the printed card.
const SLOT_ANGLES := [0.0, PI / 2.0, PI, -PI / 2.0]
const SLOT_DIRS := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

const BG := Color("f4f5f7")
const NAVY := Color("201f7d")
const NAVY_LIGHT := Color("2e2da3")
const YELLOW := Color("f6b622")
const YELLOW_LIGHT := Color("ffca4d")
const RED := Color("dd2743")
const RED_LIGHT := Color("ef5a75")
const CREAM := Color("faf8ea")
const INK := Color("17181c")
const MUTED := Color("5b6b7c")
const LINE := Color(0, 0, 0, 0.14)
const GREEN := Color("1f9d55")

const SOUND_ROW := Rect2(150, 100, 700, 100)
const VOLUME_ROW := Rect2(150, 216, 700, 110)
const VOLUME_TRACK := Rect2(190, 288, 620, 12)
const CARD_CENTER := Vector2(330, 415)
const CARD_RADIUS := 268.0  # half the side of the square card
## One red arm (top-left one; the others are turned), in units of half the card: two points at the white
## square, then the flat top edge, the outer corner (it pokes out past the yellow disc) and the flat side edge.
const ARM := [Vector2(-0.16, -0.214), Vector2(-0.37, -0.71), Vector2(-0.71, -0.71), Vector2(-0.71, -0.37), Vector2(-0.214, -0.16)]
const ARM_APEX := Vector2(-0.19, -0.19)  # the pinstripes fan out from here
## Double Cards: radius of each disc and how far their centers sit above and below the card's center,
## in units of half the card.
const DOUBLE_R := 0.5
const DOUBLE_D := 0.46
const STRIPE := Color("f8a9ba")
const DIGIT := Color("15142e")

var screen := "menu"  # "menu", "game", "stats" or "settings"
var level := 0
var mode := 0  # index into MODES
var language := ""
var sound_on := true
var volume := 1.0  # 0..1
var dragging_volume := false

var slots: Array = []  # four or six entries: {"v": Vector2i, "e": expression, "label": disguise} or null
var original: Array = []
var history: Array = []
var first := -1
var op := ""
var over := false
var status := {"key": "status_start", "arg": ""}
var solution_text := ""
var elapsed := 0.0
var results: Array = []  # mode * 8 + level * 2 + (1 if won), oldest first
var confirm_clear := false

var hover := ""
var focused := true
var confetti: Array = []
var clock := 0.0

var font: Font
var bold: Font
var numfont: Font  # serif digits, like the printed cards
var sfx
var icon_mode := false  # this copy only draws the app icon (see _render_icon)


func _ready() -> void:
	font = _font(400)
	bold = _font(700)
	numfont = _serif()
	if icon_mode:
		return
	if "--render-icon" in OS.get_cmdline_user_args():
		hide()  # only the icon sub-viewport draws
		_render_icon()
		return
	sfx = SfxScript.new()
	add_child(sfx)
	StringsScript.install()
	_load()
	if language == "":
		language = StringsScript.system_language()
	_apply_settings()
	_deal()
	set_process(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true


func _font(weight: int) -> Font:
	if OS.has_feature("web"):
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 0.7 if weight >= 700 else 0.0
		return variation
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Segoe UI", "Helvetica Neue", "Arial"])
	system.font_weight = weight
	return system


func _serif() -> Font:
	if OS.has_feature("web"):
		return bold
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Cambria", "Times New Roman", "Georgia", "Segoe UI"])
	system.font_weight = 700
	return system


func _apply_settings() -> void:
	TranslationServer.set_locale(language)
	if is_inside_tree():
		get_window().title = tr("title")
	AudioServer.set_bus_mute(0, not sound_on)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))


func _play(sound: String) -> void:
	if sfx:
		sfx.play(sound)


# --- Rounds ----------------------------------------------------------------------------------

## Deals four (or six in Double Cards) numbers that can make 24 with the level's operations.
func _deal() -> void:
	var cfg: Dictionary = LEVELS[level]
	var numbers: Array = []
	while true:
		numbers.clear()
		for i in MODES[mode].count:
			numbers.append(randi_range(cfg.lo, cfg.hi))
		if SolverScript.solve_numbers(numbers, cfg.ops) != "":
			break
	original = numbers.duplicate()
	slots.clear()
	for n: int in numbers:
		slots.append({"v": Vector2i(n, 1), "e": str(n), "label": _disguise(n)})
	history.clear()
	first = -1
	op = ""
	over = false
	status = {"key": "status_start", "arg": ""}
	solution_text = ""
	elapsed = 0.0
	confetti.clear()


## How a freshly dealt number is drawn on the hard levels: plain, as a square root or as an unreduced
## fraction. Its value stays the plain integer.
func _disguise(n: int) -> String:
	var radical_max: int = RADICAL_MAX.get(level, 0)
	var can_radical := n >= 2 and n <= radical_max
	var den: Array = FRACTION_DEN.get(level, [])
	var can_fraction := not den.is_empty()
	var roll := randf()
	if can_radical and can_fraction:
		if roll < 1.0 / 3.0:
			return "√%d" % (n * n)
		if roll < 2.0 / 3.0:
			return _fraction(n, den)
	elif can_radical and roll < 0.5:
		return "√%d" % (n * n)
	elif can_fraction and roll < 0.5:
		return _fraction(n, den)
	return ""


func _fraction(n: int, den: Array) -> String:
	var d := randi_range(den[0], den[1])
	return "%d/%d" % [n * d, d]


func _filled() -> Array:
	var out: Array = []
	for i in slots.size():
		if slots[i] != null:
			out.append(i)
	return out


func _click_slot(index: int) -> void:
	if over or slots[index] == null:
		return
	if first == index:
		first = -1
		op = ""
		_play("select")
	elif first < 0 or op == "":
		first = index
		op = ""
		status = {"key": "status_operator", "arg": ""}
		_play("select")
	else:
		_combine(index)


func _select_op(symbol: String) -> void:
	if over or first < 0 or not symbol in LEVELS[level].ops:
		return
	op = symbol
	status = {"key": "status_second", "arg": ""}
	_play("op")


func _combine(second: int) -> void:
	var a: Dictionary = slots[first]
	var b: Dictionary = slots[second]
	var result: Variant = SolverScript.compute(a.v, b.v, op)
	if result == null:
		first = -1
		op = ""
		status = {"key": "status_div0", "arg": ""}
		_play("error")
		return
	history.append(_snapshot())
	var expr := "%s %s %s" % [a.e, SolverScript.SYMBOLS[op], b.e]
	slots[first] = {"v": result, "e": expr, "label": ""}
	slots[second] = null
	first = -1
	op = ""
	status = {"key": "status_continue", "arg": ""}
	_play("combine")
	var filled := _filled()
	if filled.size() != 1:
		return
	var value: Vector2i = slots[filled[0]].v
	if SolverScript.is_24(value):
		over = true
		status = {"key": "status_win", "arg": ""}
		_record(true)
		_start_confetti()
		_play("win")
	else:
		status = {"key": "status_wrong", "arg": SolverScript.to_text(value)}
		_record(false)
		_play("error")


func _snapshot() -> Array:
	var copy: Array = []
	for slot in slots:
		copy.append(null if slot == null else slot.duplicate())
	return copy


func _undo() -> void:
	if over or history.is_empty():
		return
	slots = history.pop_back()
	first = -1
	op = ""
	status = {"key": "status_continue", "arg": ""}
	_play("undo")


func _show_solution() -> void:
	var found := SolverScript.solve_numbers(original, LEVELS[level].ops)
	solution_text = tr("solution_found") % found if found != "" else tr("solution_none")
	_play("op")


func _new_round() -> void:
	_deal()
	_play("deal")


func _start_level(index: int) -> void:
	level = index
	screen = "game"
	_deal()
	_play("deal")
	_save()


func _status_text() -> String:
	var text := tr(status.key)
	if status.arg != "":
		text = text % status.arg
	if over:
		return tr("won_elapsed") % _clock_text(elapsed)
	return text


func _clock_text(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


# --- Statistics ------------------------------------------------------------------------------

func _record(won: bool) -> void:
	results.append(mode * 8 + level * 2 + (1 if won else 0))
	if results.size() > MAX_RESULTS:
		results = results.slice(results.size() - MAX_RESULTS)
	_save()


func _summary() -> Dictionary:
	var by_level := []
	for i in LEVELS.size():
		by_level.append({"games": 0, "wins": 0})
	var double := {"games": 0, "wins": 0}
	var wins := 0
	var best := 0
	var running := 0
	for code: int in results:
		var won := code % 2 == 1
		var row: Dictionary = double if code >= 8 else by_level[(code % 8) / 2]
		row.games += 1
		if won:
			row.wins += 1
			wins += 1
			running += 1
			best = maxi(best, running)
		else:
			running = 0
	var current := 0
	for i in range(results.size() - 1, -1, -1):
		if results[i] % 2 == 0:
			break
		current += 1
	return {"games": results.size(), "wins": wins, "best": best, "current": current, "by_level": by_level, "double": double}


# --- Layout and input ------------------------------------------------------------------------

## Every button of the current screen. Used for drawing and for hit testing.
func _buttons() -> Array:
	var list: Array = []
	match screen:
		"menu":
			for i in MODES.size():
				list.append(_btn("mode%d" % i, Rect2(560 + i * 195, 226, 185, 46), tr(MODES[i].key), "ghost", true, mode == i, 19))
			for i in LEVELS.size():
				list.append(_btn("lvl%d" % i, Rect2(560, 320 + i * 76, 380, 64), tr(LEVELS[i].key), "level", true, false, 26))
			list.append(_btn("stats", Rect2(560, 640, 185, 52), tr("statistics"), "ghost", true, false, 18))
			list.append(_btn("settings", Rect2(755, 640, 185, 52), tr("settings"), "ghost", true, false, 18))
		"game":
			list.append(_btn("back", Rect2(24, 20, 130, 48), tr("menu"), "ghost", true, false, 20))
			var allowed: Array = LEVELS[level].ops
			for i in OPS.size():
				var symbol: String = OPS[i]
				var rect := Rect2(660 + (i % 2) * 168, 290 + (i / 2) * 106, 158, 96)
				list.append(_btn("op" + symbol, rect, SolverScript.SYMBOLS[symbol], "op", symbol in allowed and not over, op == symbol, 58))
			list.append(_btn("undo", Rect2(660, 512, 158, 52), tr("undo"), "ghost", not history.is_empty() and not over, false, 19))
			list.append(_btn("solution", Rect2(828, 512, 158, 52), tr("view_solution"), "ghost", true, false, 19))
			list.append(_btn("new", Rect2(660, 576, 326, 62), tr("next_game") if over else tr("new_game"), "good" if over else "primary", true, false, 24))
		"stats":
			list.append(_btn("back", Rect2(24, 20, 130, 48), tr("menu"), "ghost", true, false, 20))
			var label := tr("confirm_clear") if confirm_clear else tr("clear_stats")
			list.append(_btn("clear", Rect2(340, 640, 320, 52), label, "danger" if confirm_clear else "ghost", not results.is_empty(), false, 18))
		"settings":
			list.append(_btn("back", Rect2(24, 20, 130, 48), tr("menu"), "ghost", true, false, 20))
			list.append(_btn("sound", SOUND_ROW, "", "hit", true, false, 0))
			list.append(_btn("volume", VOLUME_TRACK.grow_individual(14, 16, 14, 16), "", "hit", sound_on, false, 0))
			for i in StringsScript.LANGUAGES.size():
				var rect := Rect2(172 + (i % 3) * 222, 408 + (i / 3) * 56, 212, 48)
				var entry: Array = StringsScript.LANGUAGES[i]
				list.append(_btn("lang" + entry[0], rect, entry[1], "ghost", true, language == entry[0], 18))
	return list


func _btn(id: String, rect: Rect2, label: String, kind: String, enabled: bool, selected: bool, size: int) -> Dictionary:
	return {"id": id, "rect": rect, "label": label, "kind": kind, "on": enabled, "sel": selected, "size": size}


## Where number `index` sits on a card of `count` numbers centered on `c`, `h` being half its side.
func _slot_center(index: int, count := 4, c := CARD_CENTER, h := CARD_RADIUS) -> Vector2:
	if count == 4:
		return c + SLOT_DIRS[index] * h * 0.56
	var r := h * DOUBLE_R
	var upper := c - Vector2(0, h * DOUBLE_D)
	var lower := c + Vector2(0, h * DOUBLE_D)
	match index:
		0:
			return upper + Vector2(0, -r * 0.62)
		1:
			return upper + Vector2(r * 0.62, 0)
		2:
			return lower + Vector2(r * 0.62, 0)
		3:
			return lower + Vector2(0, r * 0.62)
		4:
			return lower + Vector2(-r * 0.62, 0)
	return upper + Vector2(-r * 0.62, 0)


func _slot_radius(count: int, h: float) -> float:
	return h * (0.28 if count == 4 else 0.16)


func _hit(p: Vector2) -> String:
	for b: Dictionary in _buttons():
		if b.on and b.rect.has_point(p):
			return b.id
	if screen == "game" and not over:
		for i in slots.size():
			if slots[i] != null and p.distance_to(_slot_center(i, slots.size())) <= _slot_radius(slots.size(), CARD_RADIUS) + 4.0:
				return "t%d" % i
	return ""


func _press(id: String) -> void:
	confirm_clear = confirm_clear and id == "clear"
	if id.begins_with("mode"):
		mode = int(id.substr(4))
		_deal()
		_save()
		_play("select")
	elif id.begins_with("lvl"):
		_start_level(int(id.substr(3)))
	elif id.begins_with("t"):
		_click_slot(int(id.substr(1)))
	elif id.begins_with("lang"):
		language = id.substr(4)
		_apply_settings()
		solution_text = ""
		_save()
		_play("select")
	elif id.begins_with("op"):
		_select_op(id.substr(2))
	else:
		match id:
			"back":
				screen = "menu"
				_play("select")
			"stats":
				screen = "stats"
				_play("select")
			"settings":
				screen = "settings"
				_play("select")
			"volume":
				dragging_volume = true
				_drag_volume()
			"sound":
				sound_on = not sound_on
				_apply_settings()
				_save()
				_play("select")
			"undo":
				_undo()
			"solution":
				_show_solution()
			"new":
				_new_round()
			"clear":
				if confirm_clear:
					results.clear()
					confirm_clear = false
					_save()
				else:
					confirm_clear = true
				_play("select")


func _input(event: InputEvent) -> void:
	if icon_mode:
		return
	if event is InputEventMouseMotion:
		hover = _hit(get_global_mouse_position())
		if dragging_volume:
			_drag_volume()
	elif event is InputEventMouseButton and not event.pressed and dragging_volume:
		dragging_volume = false
		_save()
		_play("select")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hover = _hit(get_global_mouse_position())
		if hover != "":
			_press(hover)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _drag_volume() -> void:
	volume = clampf((get_global_mouse_position().x - VOLUME_TRACK.position.x) / VOLUME_TRACK.size.x, 0.0, 1.0)
	_apply_settings()


func _key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		if screen == "game" and first >= 0:
			first = -1
			op = ""
		elif screen != "menu":
			screen = "menu"
		return
	if screen == "menu":
		var digit := event.keycode - KEY_1
		if digit >= 0 and digit < LEVELS.size():
			_start_level(digit)
		return
	if screen != "game":
		return
	if slots.size() != 4 and event.keycode in [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]:
		return
	match event.keycode:
		KEY_UP:
			_click_slot(0)
		KEY_RIGHT:
			_click_slot(1)
		KEY_DOWN:
			_click_slot(2)
		KEY_LEFT:
			_click_slot(3)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			var index: int = event.keycode - KEY_1
			if index < slots.size():
				_click_slot(index)
		KEY_BACKSPACE, KEY_U, KEY_Z:
			_undo()
		KEY_N, KEY_ENTER, KEY_KP_ENTER:
			if over or event.keycode == KEY_N:
				_new_round()
		KEY_S:
			_show_solution()
		KEY_KP_ADD:
			_select_op("+")
		KEY_KP_SUBTRACT:
			_select_op("-")
		KEY_KP_MULTIPLY:
			_select_op("*")
		KEY_KP_DIVIDE:
			_select_op("/")
		_:
			var typed := char(event.unicode)
			if typed in ["+", "-", "*", "/"]:
				_select_op(typed)
			elif typed == "×" or typed == "x":
				_select_op("*")
			elif typed == "÷":
				_select_op("/")


func _process(delta: float) -> void:
	if icon_mode:
		return
	clock += delta
	if screen == "game" and not over and focused:
		elapsed += delta
	for piece: Dictionary in confetti:
		piece.v.y += 700.0 * delta
		piece.p += piece.v * delta
		piece.a += piece.spin * delta
	confetti = confetti.filter(func(piece: Dictionary) -> bool: return piece.p.y < SCREEN.y + 20.0)
	queue_redraw()


func _start_confetti() -> void:
	var colors := [YELLOW, RED, NAVY_LIGHT, GREEN, RED_LIGHT, YELLOW_LIGHT]
	for i in 140:
		var angle := randf_range(-PI * 0.95, -PI * 0.05)
		var speed := randf_range(250.0, 800.0)
		confetti.append({"p": CARD_CENTER + Vector2(0, 40), "v": Vector2.from_angle(angle) * speed, "a": randf() * TAU,
				"spin": randf_range(-8.0, 8.0), "c": colors[randi() % colors.size()], "s": randf_range(6.0, 12.0)})


# --- Drawing ---------------------------------------------------------------------------------

func _draw() -> void:
	if icon_mode:
		_draw_icon()
		return
	match screen:
		"menu":
			_draw_menu()
		"game":
			_draw_game()
		"stats":
			_draw_stats()
		"settings":
			_draw_settings()
	for piece: Dictionary in confetti:
		draw_set_transform(piece.p, piece.a)
		draw_rect(Rect2(-piece.s * 0.5, -piece.s * 0.3, piece.s, piece.s * 0.6), piece.c)
	draw_set_transform(Vector2.ZERO)


func _draw_menu() -> void:
	_draw_logo(Vector2(SCREEN.x / 2, 80))
	_para(tr("instructions_double" if mode == 1 else "instructions"), Rect2(140, 150, 720, 90), 22, MUTED)
	var demo: Array = []
	for n: int in original:
		demo.append({"v": Vector2i(n, 1), "e": "", "label": ""})
	var dots := int(hover.substr(3)) + 1 if hover.begins_with("lvl") else 0
	_draw_card(Vector2(280, 470), 200.0, demo, -1, "", dots)
	_text(tr("choose_difficulty"), Vector2(750, 290), 24, INK, 1, true)
	for b: Dictionary in _buttons():
		_draw_button(b)


func _draw_game() -> void:
	for b: Dictionary in _buttons():
		_draw_button(b)
	var title := tr(LEVELS[level].key)
	if mode == 1:
		title = tr("mode_double") + "  ·  " + title
	_text(title, Vector2(SCREEN.x / 2, 44), 30, NAVY, 1, true)
	_text(_clock_text(elapsed), Vector2(SCREEN.x - 28, 44), 28, MUTED, 2, true)
	_draw_card(CARD_CENTER, CARD_RADIUS, slots, first, hover, level + 1)
	var status_color := GREEN if over else (RED if status.key == "status_wrong" or status.key == "status_div0" else INK)
	_para(_status_text(), Rect2(660, 110, 326, 96), 22, status_color, HORIZONTAL_ALIGNMENT_LEFT, true)
	if solution_text != "":
		_para(solution_text, Rect2(660, 222, 326, 60), 18, MUTED, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_settings() -> void:
	_text(tr("settings"), Vector2(SCREEN.x / 2, 44), 34, NAVY, 1, true)
	# Sound switch.
	_round(SOUND_ROW, 18, Color("e8edf5") if hover == "sound" else Color.WHITE, LINE, 1)
	_text(tr("sound"), SOUND_ROW.position + Vector2(40, 34), 26, INK, 0, true)
	_text(tr("sound_desc"), SOUND_ROW.position + Vector2(40, 68), 18, MUTED, 0)
	var switch := Rect2(SOUND_ROW.end.x - 116, SOUND_ROW.position.y + 33, 76, 40)
	_round(switch, 20, GREEN if sound_on else Color("c4c9d2"))
	draw_circle(switch.position + Vector2(switch.size.x - 20 if sound_on else 20, 20), 15.0, Color.WHITE)
	# Volume slider.
	_round(VOLUME_ROW, 18, Color.WHITE, LINE, 1)
	var tone := INK if sound_on else Color(INK, 0.4)
	_text(tr("volume"), VOLUME_ROW.position + Vector2(40, 34), 26, tone, 0, true)
	_text("%d%%" % roundi(volume * 100.0), VOLUME_ROW.position + Vector2(VOLUME_ROW.size.x - 40, 34), 24, MUTED if sound_on else Color(MUTED, 0.4), 2, true)
	_round(VOLUME_TRACK, 6, Color("e4e7ec"))
	var knob_x := VOLUME_TRACK.position.x + VOLUME_TRACK.size.x * volume
	var fill_color := NAVY if sound_on else Color("c4c9d2")
	_round(Rect2(VOLUME_TRACK.position, Vector2(knob_x - VOLUME_TRACK.position.x, VOLUME_TRACK.size.y)), 6, fill_color)
	var knob := Vector2(knob_x, VOLUME_TRACK.position.y + 6)
	draw_circle(knob + Vector2(0, 2), 17.0, Color(0, 0, 0, 0.18))
	draw_circle(knob, 16.0, fill_color)
	draw_circle(knob, 8.0, CREAM)
	# Language.
	_round(Rect2(150, 342, 700, 300 + 20), 18, Color.WHITE, LINE, 1)
	_text(tr("language"), Vector2(190, 382), 26, INK, 0, true)
	for b: Dictionary in _buttons():
		if b.kind != "hit":
			_draw_button(b)


func _draw_stats() -> void:
	for b: Dictionary in _buttons():
		_draw_button(b)
	_text(tr("statistics"), Vector2(SCREEN.x / 2, 44), 34, NAVY, 1, true)
	var s := _summary()
	if s.games == 0:
		_text(tr("no_games"), Vector2(SCREEN.x / 2, 340), 26, MUTED, 1)
		return
	var rate := "%d%%" % roundi(100.0 * s.wins / s.games)
	var boxes := [[tr("wins"), str(s.wins)], [tr("win_rate"), rate], [tr("current_streak"), str(s.current)], [tr("best_streak"), str(s.best)]]
	for i in 4:
		var rect := Rect2(30 + i * 240, 100, 220, 112)
		_round(rect, 16, Color.WHITE, LINE, 1)
		_text(boxes[i][1], rect.get_center() + Vector2(0, -12), 46, NAVY, 1, true)
		_text(boxes[i][0], rect.get_center() + Vector2(0, 34), 18, MUTED, 1)
	_text(tr("by_difficulty"), Vector2(30, 258), 24, INK, 0, true)
	for i in LEVELS.size() + 1:
		var row: Dictionary = s.double if i == LEVELS.size() else s.by_level[i]
		var y := 288 + i * 44
		_text(tr(MODES[1].key) if i == LEVELS.size() else tr(LEVELS[i].key), Vector2(30, y + 20), 21, INK, 0)
		var bar := Rect2(250, y + 6, 420, 28)
		_round(bar, 14, Color("e4e7ec"))
		if row.games > 0 and row.wins > 0:
			_round(Rect2(bar.position, Vector2(maxf(bar.size.x * row.wins / row.games, 28.0), bar.size.y)), 14, GREEN)
		_text(tr("level_detail") % [row.wins, row.games], Vector2(690, y + 20), 19, MUTED, 0)
	_text(tr("recent_history"), Vector2(30, 520), 24, INK, 0, true)
	var recent: Array = results.slice(maxi(results.size() - 20, 0))
	recent.reverse()
	for i in recent.size():
		var won: bool = recent[i] % 2 == 1
		var rect := Rect2(30 + i * 48, 550, 40, 40)
		_round(rect, 10, GREEN if won else RED)
		if recent[i] >= 8:  # Double Cards: a yellow frame
			_round(rect.grow(-3), 8, Color.TRANSPARENT, YELLOW, 3)
		_text(str((recent[i] % 8) / 2 + 1), rect.get_center(), 20, Color.WHITE, 1, true)
	_text(tr("won_lost_hint"), Vector2(30, 614), 16, MUTED, 0)


## The traditional card: navy square, yellow disc, four red pinstriped arms around a white square, the
## numbers on the sides with their tops facing outward, and `dots` yellow dots in every corner (the difficulty).
## Six tiles draw the Double Cards card instead: two such discs joined in a figure 8. `h` is half the card's side.
func _draw_card(c: Vector2, h: float, tiles: Array, selected: int, hovered := "", dots := 0) -> void:
	for i in 5:
		_round(Rect2(c - Vector2(h, h) - Vector2(i, i) * 2.0 + Vector2(0, 8), Vector2(h, h) * 2.0 + Vector2(i, i) * 4.0), h * 0.09 + i * 2.0, Color(0, 0, 0, 0.04))
	_round(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), h * 0.09, NAVY)
	var count := tiles.size()
	if count == 4:
		draw_circle(c, h * 0.9, YELLOW)
		_draw_arms(c, h)
		_draw_square(c, h)
	else:
		# Each disc is a classic card scaled so its disc has radius DOUBLE_R.
		var k := h * DOUBLE_R / 0.9
		var upper := c - Vector2(0, h * DOUBLE_D)
		var lower := c + Vector2(0, h * DOUBLE_D)
		draw_circle(upper, k * 0.9, YELLOW)
		draw_circle(lower, k * 0.9, YELLOW)
		_draw_arms(upper, k)
		_draw_arms(lower, k)
		# The inner arms meet in a red band across the waist, like on the printed card.
		var band := PackedVector2Array([upper + Vector2(-0.12, 0.2) * k, upper + Vector2(0.12, 0.2) * k, c + Vector2(0.2, 0) * k,
				lower + Vector2(0.12, -0.2) * k, lower + Vector2(-0.12, -0.2) * k, c + Vector2(-0.2, 0) * k])
		draw_colored_polygon(band, RED)
		_draw_square(upper, k)
		_draw_square(lower, k)
	# Difficulty dots, turned around the card like the numbers.
	for k in 4:
		for i in dots:
			var dot := _rot(Vector2(-0.84, -0.88 + i * 0.1), k * PI / 2.0)
			draw_circle(c + dot * h, h * 0.034, YELLOW)
	var radius := _slot_radius(count, h)
	for i in count:
		if tiles[i] == null:
			continue
		var pos := _slot_center(i, count, c, h)
		var is_selected := i == selected
		if is_selected:
			draw_circle(pos, radius, NAVY)
		elif hovered == "t%d" % i:
			draw_circle(pos, radius, Color(1, 1, 1, 0.55))
		draw_set_transform(pos, SLOT_ANGLES[i] if count == 4 else DOUBLE_ANGLES[i])
		_draw_value(Vector2.ZERO, tiles[i], radius * 1.64, CREAM if is_selected else DIGIT)
		draw_set_transform(Vector2.ZERO)


## The four red arms around a disc centered on `c`: wedges from the white square out past the disc's rim.
func _draw_arms(c: Vector2, h: float) -> void:
	for k in 4:
		var turn := k * PI / 2.0
		var polygon := PackedVector2Array()
		for point: Vector2 in ARM:
			polygon.append(c + _rot(point, turn) * h)
		draw_colored_polygon(polygon, RED)
		# Pinstripes fan out along the two outer edges.
		for step in range(1, 16):
			var t := step / 16.0 * 2.0
			var edge := ARM[1].lerp(ARM[2], t) if t < 1.0 else ARM[2].lerp(ARM[3], t - 1.0)
			var from := ARM_APEX + (edge - ARM_APEX).normalized() * 0.2
			draw_line(c + _rot(from, turn) * h, c + _rot(edge, turn) * h, STRIPE, maxf(h * 0.004, 1.0), true)


## The white square with its thin red outline in the middle of a disc.
func _draw_square(c: Vector2, h: float) -> void:
	_round(Rect2(c - Vector2(h, h) * 0.214, Vector2(h, h) * 0.428), h * 0.006, RED)
	_round(Rect2(c - Vector2(h, h) * 0.2, Vector2(h, h) * 0.4), h * 0.004, Color("fffdf6"))


func _rot(v: Vector2, angle: float) -> Vector2:
	return v.rotated(angle)


func _draw_value(pos: Vector2, tile: Dictionary, size: float, color: Color) -> void:
	var v: Vector2i = tile.v
	var label: String = tile.label
	if label.contains("/"):
		var parts := label.split("/")
		_stacked(pos, parts[0], parts[1], size * 0.58, color)
	elif label != "":
		_text(label, pos, int(size * (0.72 if label.length() < 4 else 0.5)), color, 1, true, numfont)
	elif v.y != 1:
		_stacked(pos, str(v.x), str(v.y), size * 0.58, color)
	else:
		var text := str(v.x)
		_text(text, pos, int(size * (1.0 if text.length() < 2 else (0.82 if text.length() == 2 else 0.66))), color, 1, true, numfont)


## A fraction: numerator over denominator with a bar of fixed weight, centered between them.
func _stacked(pos: Vector2, top: String, bottom: String, size: float, color: Color) -> void:
	var size_px := int(size)
	var width := maxf(numfont.get_string_size(top, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x, numfont.get_string_size(bottom, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x)
	var half_bar := maxf(width + size * 0.36, size * 1.1) * 0.5
	var gap := size * 0.62
	_text(top, pos + Vector2(0, -gap), size_px, color, 1, true, numfont)
	_text(bottom, pos + Vector2(0, gap), size_px, color, 1, true, numfont)
	draw_rect(Rect2(pos + Vector2(-half_bar, -size * 0.045), Vector2(half_bar * 2.0, size * 0.09)), color)


func _draw_button(b: Dictionary) -> void:
	var rect: Rect2 = b.rect
	var enabled: bool = b.on
	var hot: bool = hover == b.id and enabled
	var fill := Color.WHITE
	var border := LINE
	var text_color := NAVY
	match b.kind:
		"primary":
			fill = NAVY_LIGHT if hot else NAVY
			border = NAVY
			text_color = CREAM
		"good":
			fill = GREEN.lightened(0.1) if hot else GREEN
			border = GREEN
			text_color = Color.WHITE
		"danger":
			fill = RED_LIGHT if hot else RED
			border = RED
			text_color = Color.WHITE
		"op":
			fill = Color("e8edf5") if hot else Color.WHITE
			border = NAVY
		_:
			fill = Color("e8edf5") if hot else Color.WHITE
	if b.sel:
		fill = NAVY
		text_color = CREAM
	if not enabled:
		fill = Color("eceef2")
		text_color = Color(text_color, 0.35)
		border = Color(0, 0, 0, 0.08)
	_round(rect, 16 if b.kind != "op" else 22, fill, border, 2 if b.kind == "op" and enabled else 1)
	if b.kind == "level":
		var band := Rect2(rect.position + Vector2(14, 14), Vector2(8, rect.size.y - 28))
		_round(band, 4, [GREEN, YELLOW, Color("f07c2a"), RED][int(b.id.substr(3))])
		_text(b.label, rect.position + Vector2(44, rect.size.y * 0.5), b.size, text_color, 0, true)
		for i in int(b.id.substr(3)) + 1:
			var dot := rect.position + Vector2(rect.size.x - 32 - i * 24, rect.size.y * 0.5)
			draw_circle(dot, 8.0, NAVY)
			draw_circle(dot, 6.5, YELLOW)
	else:
		# Shrink long labels (some languages) until they fit the button.
		var label_font := bold if b.kind != "ghost" else font
		var label_size: int = b.size
		while label_size > 10 and label_font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x > rect.size.x - 18.0:
			label_size -= 1
		_text(b.label, rect.get_center() + Vector2(0, -2 if b.kind == "op" else 0), label_size, text_color, 1, b.kind != "ghost")


func _round(rect: Rect2, radius: float, fill: Color, border := Color.TRANSPARENT, border_width := 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(int(radius))
	style.anti_aliasing = true
	if border_width > 0:
		style.border_color = border
		style.set_border_width_all(border_width)
	draw_style_box(style, rect)


## Text centered (align 1), left (0) or right (2) of pos, vertically centered on pos.y.
func _text(s: String, pos: Vector2, size: int, color: Color, align := 1, is_bold := false, custom: Font = null) -> void:
	var f: Font = custom if custom else (bold if is_bold else font)
	var width := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x - width * 0.5 * align
	var baseline := pos.y + (f.get_ascent(size) - f.get_descent(size)) * 0.5
	draw_string(f, Vector2(x, baseline), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _para(s: String, rect: Rect2, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, is_bold := false) -> void:
	var f := bold if is_bold else font
	draw_multiline_string(f, Vector2(rect.position.x, rect.position.y + f.get_ascent(size)), s, align, rect.size.x, size, -1, color)


# --- Icon ------------------------------------------------------------------------------------

## Run with:  Godot --path <game> -- --render-icon   (writes icon.png and icon.ico).
func _render_icon() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.msaa_2d = Viewport.MSAA_8X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var art: Node2D = get_script().new()
	art.icon_mode = true
	viewport.add_child(art)
	add_child(viewport)
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var radius := 92.0
	for py in 512:
		for px in 512:
			var q := Vector2(absf(px + 0.5 - 256.0), absf(py + 0.5 - 256.0)) - Vector2(256.0 - radius, 256.0 - radius)
			var dist := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() - radius
			if dist > -1.0:
				var col := img.get_pixel(px, py)
				col.a = clampf(0.5 - dist, 0.0, 1.0)
				img.set_pixel(px, py, col)
	img.save_png(ProjectSettings.globalize_path("res://icon.png"))
	_write_ico(img, ProjectSettings.globalize_path("res://icon.ico"))
	get_tree().quit()


## The printed card of image.png filling the icon, with "24 PRO" on the white square.
func _draw_icon() -> void:
	draw_rect(Rect2(0, 0, 512, 512), NAVY)
	var tiles: Array = []
	for n in [8, 4, 1, 5]:  # (5 - 1) × 4 + 8
		tiles.append({"v": Vector2i(n, 1), "e": "", "label": ""})
	_draw_card(Vector2(256, 256), 250.0, tiles, -1, "", 3)
	_draw_plate(Vector2(256, 256), 250.0, true)


## The white centre square of the logo with "24" (and "PRO" when it is big enough to read).
func _draw_plate(c: Vector2, h: float, with_pro: bool) -> void:
	var half := h * 0.272
	var plate := Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0)
	_round(plate.grow(h * 0.024), h * 0.032, RED)
	_round(plate, h * 0.02, Color("fffdf6"))
	if with_pro:
		_text("24", c + Vector2(0, -h * 0.072), int(h * 0.32), NAVY, 1, true, numfont)
		_text("PRO", c + Vector2(0, h * 0.16), int(h * 0.12), RED, 1, true)
	else:
		_text("24", c, int(h * 0.36), NAVY, 1, true, numfont)


## The in-game logo: the card emblem, the name and a red PRO badge, centered on `center`.
func _draw_logo(center: Vector2) -> void:
	var h := 50.0
	var name := tr("title_name")
	var name_size := 58
	var name_width := bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var badge_width := bold.get_string_size("PRO", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 28.0
	var total := h * 2.0 + 22.0 + name_width + 14.0 + badge_width
	var x := center.x - total * 0.5
	var emblem := Vector2(x + h, center.y)
	var tiles: Array = []
	for n in [8, 4, 1, 5]:
		tiles.append({"v": Vector2i(n, 1), "e": "", "label": ""})
	_draw_card(emblem, h, tiles, -1, "", 3)
	_draw_plate(emblem, h, false)
	x += h * 2.0 + 22.0
	_text(name, Vector2(x, center.y), name_size, NAVY, 0, true)
	x += name_width + 14.0
	_round(Rect2(x, center.y - 23, badge_width, 46), 12, RED)
	_text("PRO", Vector2(x + badge_width * 0.5, center.y), 30, Color.WHITE, 1, true)


## Windows .ico with PNG images at several sizes.
func _write_ico(img: Image, path: String) -> void:
	var sizes := [16, 24, 32, 48, 64, 128, 256]
	var pngs: Array = []
	for s: int in sizes:
		var copy: Image = img.duplicate()
		copy.resize(s, s, Image.INTERPOLATE_LANCZOS)
		pngs.append(copy.save_png_to_buffer())
	var out := PackedByteArray()
	out.resize(6 + 16 * sizes.size())
	out.encode_u16(2, 1)
	out.encode_u16(4, sizes.size())
	var offset := out.size()
	for i in sizes.size():
		var base := 6 + 16 * i
		var dimension: int = sizes[i]
		out.encode_u8(base, 0 if dimension >= 256 else dimension)
		out.encode_u8(base + 1, 0 if dimension >= 256 else dimension)
		out.encode_u16(base + 4, 1)
		out.encode_u16(base + 6, 32)
		out.encode_u32(base + 8, pngs[i].size())
		out.encode_u32(base + 12, offset)
		offset += pngs[i].size()
	for png: PackedByteArray in pngs:
		out.append_array(png)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(out)


# --- Saving ----------------------------------------------------------------------------------

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	level = clampi(int(config.get_value("settings", "level", 0)), 0, LEVELS.size() - 1)
	mode = clampi(int(config.get_value("settings", "mode", 0)), 0, MODES.size() - 1)
	language = str(config.get_value("settings", "language", ""))
	sound_on = bool(config.get_value("settings", "sound", true))
	volume = clampf(float(config.get_value("settings", "volume", 1.0)), 0.0, 1.0)
	var saved: Variant = config.get_value("stats", "results", [])
	if saved is Array:
		for code in saved:
			if code is int and code >= 0 and code < 16:
				results.append(code)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "level", level)
	config.set_value("settings", "mode", mode)
	config.set_value("settings", "language", language)
	config.set_value("settings", "sound", sound_on)
	config.set_value("settings", "volume", volume)
	config.set_value("stats", "results", results)
	config.save(SAVE_PATH)
