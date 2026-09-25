extends Node3D
## Dead Sector: a round-based tactical shooter in the style of the classic bomb-defusal games.
## Two squads (you and your bots against bots) play a match of rounds on one of two maps; every
## model, texture and sound is made in code.
##
## This node runs everything around the match: the menus, match setup, input bindings, pause, the buy
## menu, the end-of-match screen, settings and the save file. The match itself is rules.gd, the
## in-game overlay hud.gd. The menus are Control nodes, so mouse, keyboard and a controller all work
## through Godot's focus navigation: arrows / D-pad move, Enter / A choose, Esc / B go back.
##
## Test runs: "-- --autotest" plays a whole match with a bot in the player's place at 4x speed and
## prints each round; "-- --screenshot" saves a frame of a match to the user folder and quits.

const StringsScript := preload("res://scripts/strings.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const RulesScript := preload("res://scripts/rules.gd")
const HudScript := preload("res://scripts/hud.gd")
const BuyMenuScript := preload("res://scripts/buy_menu.gd")
const BotScript := preload("res://scripts/bot.gd")
const IconScript := preload("res://scripts/icon.gd")
const Maps := preload("res://scripts/maps.gd")

const SAVE_PATH := "user://dead_sector.cfg"
const ACCENT := Color("f0a830")
const TEXT := Color("e9edf0")
const MUTED := Color("93a0ab")
const PANEL := Color(0.05, 0.065, 0.08, 0.94)
const SIDES := ["att", "def", "auto"]

# Settings and records, saved.
var language := ""
var sound_on := true
var mouse_sensitivity := 5
var stick_sensitivity := 5
var invert_y := false
var fullscreen := false
var options := {"map": 0, "side": 2, "size": 5, "skill": 1, "length": 0}
var wins := 0
var losses := 0
var draws := 0

var state := "menu"  # menu, playing, paused, over
var screen := ""
var back_to := ""
var rules: Node3D
var buy_open := false
var buy_menu: Control
var had_capture := false
var messages: Array = []  # [text, seconds left]
var using_pad := false
var quiet_focus := false
var final := [0, 0]
var autotest := false
var screenshot := false
var test_round := 0
var test_reported := 0
var shot_t := 0.0
var shot_n := 0

var sfx
var font: Font
var bold: Font
var title_font: Font
var hud: Control
var ui: Control
var backdrop: Control
var emblem: Node2D
var menu_root: Control
var help_scroll: ScrollContainer


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--render-icon" in args:
		set_process(false)
		_render_icon()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = _font(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"], 400)
	bold = _font(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"], 700)
	title_font = _font(["Impact", "Haettenschweiler", "Arial Black", "sans-serif"], 800)
	sfx = SfxScript.new()
	add_child(sfx)
	StringsScript.install()
	_load()
	if language == "":
		language = StringsScript.system_language()
	_setup_input()
	_build_ui()
	_apply_settings()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	autotest = "--autotest" in args
	screenshot = "--screenshot" in args
	for arg in args:
		if arg.begins_with("--map="):
			options["map"] = clampi(int(arg.substr(6)), 0, Maps.MAPS.size() - 1)
	if autotest or screenshot:
		if autotest:
			Engine.time_scale = 6.0
			sound_on = false
			_apply_settings()
		_start_match()
		return
	_show("main")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "playing" and not autotest and not screenshot:
		_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == "playing":
			_pause()
		else:
			_back()


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


func _is_desktop() -> bool:
	return not OS.has_feature("web") and not OS.has_feature("mobile")


func _apply_settings() -> void:
	TranslationServer.set_locale(language)
	AudioServer.set_bus_mute(0, not sound_on)
	if _is_desktop():
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and not (mode == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(mode)


## True while the player's own controls should reach their soldier.
func can_control() -> bool:
	return state == "playing" and not buy_open and not autotest


# --- Input ---------------------------------------------------------------------------------

func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "crouch": [KEY_CTRL, KEY_C], "walk": [KEY_SHIFT],
		"fire": [], "scope": [], "reload": [KEY_R], "use": [KEY_E], "drop": [KEY_G],
		"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3], "slot_4": [KEY_4], "slot_5": [KEY_5],
		"next_weapon": [], "prev_weapon": [], "last_weapon": [KEY_Q],
		"buy": [KEY_B], "scores": [KEY_TAB], "pause": [KEY_ESCAPE, KEY_P],
		"look_left": [], "look_right": [], "look_up": [], "look_down": [],
	}
	var axes := {
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "scope": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	}
	var buttons := {
		"jump": [JOY_BUTTON_A], "crouch": [JOY_BUTTON_B], "reload": [JOY_BUTTON_X], "walk": [JOY_BUTTON_LEFT_STICK],
		"next_weapon": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_Y], "prev_weapon": [JOY_BUTTON_LEFT_SHOULDER],
		"use": [JOY_BUTTON_DPAD_UP], "scores": [JOY_BUTTON_DPAD_DOWN], "drop": [JOY_BUTTON_DPAD_LEFT],
		"last_weapon": [JOY_BUTTON_DPAD_RIGHT], "buy": [JOY_BUTTON_BACK], "pause": [JOY_BUTTON_START],
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key: Key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action: String in axes:
		var event := InputEventJoypadMotion.new()
		event.axis = axes[action][0]
		event.axis_value = axes[action][1]
		InputMap.action_add_event(action, event)
	for action: String in buttons:
		for button: JoyButton in buttons[action]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
	for pair: Array in [[MOUSE_BUTTON_LEFT, "fire"], [MOUSE_BUTTON_RIGHT, "scope"],
			[MOUSE_BUTTON_WHEEL_DOWN, "next_weapon"], [MOUSE_BUTTON_WHEEL_UP, "prev_weapon"]]:
		var event := InputEventMouseButton.new()
		event.button_index = pair[0]
		InputMap.action_add_event(pair[1], event)
	# Menus: A chooses, B goes back.
	for pair: Array in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var event := InputEventJoypadButton.new()
		event.button_index = pair[1]
		if not InputMap.action_has_event(pair[0], event):
			InputMap.action_add_event(pair[0], event)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		if not using_pad:
			using_pad = true
			_update_hint()
	elif event is InputEventKey or event is InputEventMouseButton:
		if using_pad:
			using_pad = false
			_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if state == "playing":
		if buy_open:
			if event.is_action_pressed("buy") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
				_close_buy()
				get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("pause"):
			_pause()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("buy"):
			if rules.can_buy(rules.human):
				_open_buy()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture()
		return
	if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("pause") and screen == "pause"):
		_back()
		get_viewport().set_input_as_handled()
	elif screen in ["settings", "setup"] and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and focused.has_meta("adjust"):
			sfx.play("click")
			focused.get_meta("adjust").call(-1 if event.is_action_pressed("ui_left") else 1)
			get_viewport().set_input_as_handled()


func _capture() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	had_capture = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func vibrate(strength: float, duration: float) -> void:
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, strength * 0.6, strength, duration)


func shake(amount: float) -> void:
	if rules != null:
		rules.view.shake = maxf(rules.view.shake, amount)


func message(text: String) -> void:
	messages.append([text, 4.0])
	if messages.size() > 4:
		messages.remove_at(0)


func _process(delta: float) -> void:
	for i in range(messages.size() - 1, -1, -1):
		messages[i][1] -= delta
		if messages[i][1] <= 0.0:
			messages.remove_at(i)
	if state == "playing" and had_capture and not buy_open and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# The browser (or the system) let go of the mouse, e.g. Esc on the web.
		_pause()
	if buy_open and (rules == null or not rules.can_buy(rules.human)):
		_close_buy()
	if backdrop.visible:
		backdrop.queue_redraw()
	if screen == "help" and help_scroll != null:
		var scroll := Input.get_axis("look_up", "look_down") + Input.get_axis("ui_up", "ui_down")
		help_scroll.scroll_vertical += int(scroll * 700.0 * delta)
	if autotest and rules != null:
		_autotest_report()
	if screenshot and rules != null:
		_screenshot_step()


# --- Match flow ----------------------------------------------------------------------------

func _start_match() -> void:
	_end_match()
	get_tree().paused = false
	messages.clear()
	rules = RulesScript.new()
	rules.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rules)
	var picked := options.duplicate()
	picked["side"] = SIDES[options["side"]]
	if screenshot:
		picked["side"] = "att"
	rules.start(self, picked)
	if screenshot:
		rules.human.money = 16000
		rules.buy(rules.human, "ar7")
	if autotest:
		var brain = BotScript.new()
		brain.setup(rules.human, rules, rules.world, 2)
		rules.human.brain = brain
		brain.new_round()
	state = "playing"
	_show("")
	if not autotest and not screenshot:
		_capture()


func _end_match() -> void:
	_close_buy()
	if rules != null:
		rules.queue_free()
		rules = null


func _pause() -> void:
	if state != "playing":
		return
	_close_buy()
	state = "paused"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	had_capture = false
	_show("pause")


func _resume() -> void:
	state = "playing"
	get_tree().paused = false
	_show("")
	_capture()


func _quit_to_menu() -> void:
	get_tree().paused = false
	_end_match()
	state = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	had_capture = false
	_show("main")


## Called by rules.gd when the last round is over.
func match_over(ours: int, theirs: int) -> void:
	final = [ours, theirs]
	if autotest:
		print("MATCH OVER %d - %d" % [ours, theirs])
		get_tree().quit()
		return
	if ours > theirs:
		wins += 1
	elif ours < theirs:
		losses += 1
	else:
		draws += 1
	_save()
	state = "over"
	_close_buy()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	had_capture = false
	_show("over")


func _open_buy() -> void:
	buy_open = true
	buy_menu = BuyMenuScript.new()
	buy_menu.theme = ui.theme
	ui.add_child(buy_menu)
	buy_menu.build(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	had_capture = false


func _close_buy() -> void:
	if not buy_open:
		return
	buy_open = false
	if buy_menu != null:
		buy_menu.queue_free()
		buy_menu = null
	if state == "playing":
		_capture()


# --- Test runs -----------------------------------------------------------------------------

func _autotest_report() -> void:
	if rules.round_n != test_round and rules.phase == "freeze":
		test_round = rules.round_n
		var money := []
		for s in rules.soldiers:
			money.append("%s%s:$%d" % [s.nick, "*" if s.team == "att" else "", s.money])
		print("round %d  score %d-%d  sides %s  %s" % [rules.round_n, rules.score[0], rules.score[1], rules.side_of, " ".join(money)])
	if rules.phase == "over" and test_reported != rules.round_n:
		test_reported = rules.round_n
		var alive := []
		for s in rules.soldiers:
			alive.append("%s:%s/%d-%d" % [s.nick, "up" if s.alive else "dead", s.kills, s.deaths])
		print("  -> %s wins (%s)  bomb %s  clock %.1f  %s" % [rules.round_winner, rules.banner["sub"], rules.bomb_state, rules.round_clock, " ".join(alive)])


## Saves a few frames of a match: first person at freeze time, then while the bots move out.
func _screenshot_step() -> void:
	shot_t += get_process_delta_time()
	var times := [1.0, 9.0, 16.0, 24.0]
	if shot_n < times.size() and shot_t >= times[shot_n]:
		var img := get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("user://shot_%d.png" % shot_n)
		img.save_png(path)
		print("saved ", path)
		shot_n += 1
		if shot_n == 2:
			_open_buy()
		elif shot_n == 3:
			_close_buy()
	if shot_n >= times.size():
		get_tree().quit()


# --- Menus ---------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	hud = HudScript.new()
	hud.game = self
	layer.add_child(hud)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = _build_theme()
	menu_layer.add_child(ui)
	backdrop = Control.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.draw.connect(_draw_backdrop)
	ui.add_child(backdrop)


func _build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 21
	var normal := _box(Color(0.1, 0.12, 0.14), Color(0.24, 0.28, 0.32))
	var hover := _box(Color(0.2, 0.17, 0.1), ACCENT)
	var pressed := _box(Color(0.32, 0.24, 0.08), Color(1.0, 0.85, 0.5))
	var disabled := _box(Color(0.07, 0.08, 0.09), Color(0.14, 0.16, 0.18))
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT, 3, false))
	theme.set_font("font", "Button", bold)
	theme.set_font_size("font_size", "Button", 22)
	for key in ["font_color", "font_focus_color"]:
		theme.set_color(key, "Button", TEXT)
	theme.set_color("font_hover_color", "Button", ACCENT)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.38, 0.41, 0.44))
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, Color(0.25, 0.29, 0.33), 2, true, 30))
	return theme


func _box(bg: Color, border: Color, width := 2, filled := true, pad := 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.draw_center = filled
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.content_margin_left = pad * 1.6
	box.content_margin_right = pad * 1.6
	box.content_margin_top = pad
	box.content_margin_bottom = pad
	if not filled:
		box.set_expand_margin_all(3)
	return box


## The menu background: a dark map grid with a radar sweep turning over it.
func _draw_backdrop() -> void:
	var rect := backdrop.get_rect()
	var t := Time.get_ticks_msec() / 1000.0
	backdrop.draw_rect(rect, Color("0a0d10"))
	var c := Vector2(rect.size.x * 0.5, rect.size.y * 0.52)
	var radius := rect.size.length() * 0.6
	for i in 24:
		var k := i / 23.0
		backdrop.draw_circle(c, lerpf(radius, 40.0, k), Color(0.16, 0.2, 0.24, 0.04 + k * 0.01))
	var step := 48.0
	var off := fmod(t * 6.0, step)
	for x in range(0, int(rect.size.x / step) + 2):
		backdrop.draw_line(Vector2(x * step - off, 0), Vector2(x * step - off, rect.size.y), Color(1, 1, 1, 0.03), 1.0)
	for y in range(0, int(rect.size.y / step) + 2):
		backdrop.draw_line(Vector2(0, y * step - off), Vector2(rect.size.x, y * step - off), Color(1, 1, 1, 0.03), 1.0)
	var sweep := fmod(t * 0.9, TAU)
	for i in 30:
		var a := sweep - i * 0.025
		var wedge := PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * radius, c + Vector2(cos(a - 0.03), sin(a - 0.03)) * radius])
		backdrop.draw_colored_polygon(wedge, Color(0.94, 0.66, 0.19, 0.05 * (1.0 - i / 30.0)))
	for ring in 5:
		backdrop.draw_arc(c, 120.0 + ring * 140.0, 0.0, TAU, 96, Color(0.94, 0.66, 0.19, 0.05), 1.5)


func _show(new_screen: String) -> void:
	screen = new_screen
	help_scroll = null
	if menu_root != null:
		menu_root.queue_free()
		menu_root = null
	emblem = null
	backdrop.visible = new_screen != "" and rules == null
	if new_screen == "":
		return
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu_root)
	if rules != null:
		var dim := ColorRect.new()
		dim.color = Color(0.0, 0.0, 0.0, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		menu_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)
	var hint := Label.new()
	hint.name = "Hint"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 30
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", MUTED)
	hint.add_theme_font_size_override("font_size", 16)
	menu_root.add_child(hint)
	quiet_focus = true
	match new_screen:
		"main":
			_build_main(column)
		"setup":
			_build_setup(column)
		"help":
			_build_help(column)
		"settings":
			_build_settings(column)
		"pause":
			_build_pause(column)
		"over":
			_build_over(column)
	_update_hint()
	for node in column.find_children("*", "Button", true, false):
		var button := node as Button
		if not button.disabled:
			button.grab_focus.call_deferred()
			break
	set_deferred("quiet_focus", false)


func _update_hint() -> void:
	if menu_root == null:
		return
	var hint := menu_root.get_node_or_null("Hint") as Label
	if hint != null:
		hint.text = tr("hint_pad") if using_pad else tr("hint_keys")


func _on_focus_changed(_control: Control) -> void:
	if not quiet_focus:
		sfx.play("move")


func _label(parent: Control, text: String, font_size := 21, color := TEXT, width := 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = width
	parent.add_child(label)
	return label


func _title(parent: Control, text: String, font_size := 44, color := ACCENT) -> void:
	var label := _label(parent, text, font_size, color)
	label.add_theme_font_override("font", title_font)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", maxi(4, font_size / 9))


func _button(parent: Control, text: String, callback: Callable, width := 420.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 46)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void:
		sfx.play("click")
		callback.call())
	button.mouse_entered.connect(func() -> void:
		if not button.disabled and button.get_viewport().gui_get_focus_owner() != button:
			quiet_focus = true
			button.grab_focus()
			quiet_focus = false)
	parent.add_child(button)
	return button


func _panel(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


func _spacer(parent: Control, height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	parent.add_child(gap)


func _build_main(column: VBoxContainer) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(130, 130)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(holder)
	emblem = IconScript.new()
	emblem.background = false
	emblem.scale = Vector2.ONE * (130.0 / 512.0)
	holder.add_child(emblem)
	_title(column, "DEAD SECTOR", 84)
	_label(column, tr("tagline"), 19, MUTED, 640.0)
	if wins + losses + draws > 0:
		_label(column, tr("record") % [wins, losses, draws], 16, MUTED)
	_spacer(column, 4)
	_button(column, tr("play"), func() -> void: _show("setup"))
	_button(column, tr("how_to_play"), func() -> void:
		back_to = "main"
		_show("help"))
	_button(column, tr("settings"), func() -> void:
		back_to = "main"
		_show("settings"))
	if _is_desktop():
		_button(column, tr("quit"), func() -> void: get_tree().quit())


## Rows that change with left / right or a click, for match setup and settings.
func _rows(box: VBoxContainer, rows: Array, width: float, after_change: Callable) -> void:
	for row: Array in rows:
		var key: String = row[0]
		var value: Callable = row[1]
		var change: Callable = row[2]
		var button := _button(box, "", func() -> void: pass, width)
		var refresh := func() -> void:
			button.text = "%s:  %s" % [tr(key), value.call()]
		var adjust := func(step: int) -> void:
			change.call(step)
			after_change.call(key)
			refresh.call()
		button.set_meta("adjust", adjust)
		button.pressed.connect(func() -> void: adjust.call(1))
		refresh.call()


func _build_setup(column: VBoxContainer) -> void:
	var box := _panel(column)
	_title(box, tr("match_setup"), 40)
	var rows := [
		["map", func() -> String: return tr(Maps.MAPS[options["map"]]["name"]),
			func(step: int) -> void: options["map"] = posmod(options["map"] + step, Maps.MAPS.size())],
		["side", func() -> String: return tr("side_" + SIDES[options["side"]]),
			func(step: int) -> void: options["side"] = posmod(options["side"] + step, SIDES.size())],
		["team_size", func() -> String: return tr("size_n") % [options["size"], options["size"]],
			func(step: int) -> void: options["size"] = posmod(options["size"] - 1 + step, 5) + 1],
		["bot_skill", func() -> String: return tr("skill_%d" % options["skill"]),
			func(step: int) -> void: options["skill"] = posmod(options["skill"] + step, 4)],
		["match_length", func() -> String: return tr("length_%d" % options["length"]),
			func(step: int) -> void: options["length"] = posmod(options["length"] + step, 2)],
	]
	_rows(box, rows, 560.0, func(_key: String) -> void: _save())
	_spacer(box, 6)
	_button(box, tr("start_match"), _start_match, 560.0)
	_button(box, tr("back"), _back, 560.0)


func _build_help(column: VBoxContainer) -> void:
	var box := _panel(column)
	_title(box, tr("how_to_play"), 40)
	help_scroll = ScrollContainer.new()
	help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	help_scroll.custom_minimum_size = Vector2(820, minf(470.0, get_viewport().get_visible_rect().size.y - 250.0))
	box.add_child(help_scroll)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 6)
	help_scroll.add_child(text)
	for section in [["help_goal", "help_goal_text"], ["help_money", "help_money_text"],
			["help_shooting", "help_shooting_text"], ["controls", "help_keyboard"], ["", "help_pad"]]:
		if section[0] != "":
			_spacer(text, 4)
			_label(text, tr(section[0]), 24, ACCENT)
		var body := _label(text, tr(section[1]), 18, TEXT, 790.0)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button(box, tr("back"), _back)


func _build_settings(column: VBoxContainer) -> void:
	var box := _panel(column)
	_title(box, tr("settings"), 40)
	var rows := [
		["language", _language_name, _change_language],
		["sound", func() -> String: return tr("on") if sound_on else tr("off"), func(_step: int) -> void: sound_on = not sound_on],
		["mouse_sensitivity", func() -> String: return str(mouse_sensitivity),
			func(step: int) -> void: mouse_sensitivity = posmod(mouse_sensitivity - 1 + step, 10) + 1],
		["stick_sensitivity", func() -> String: return str(stick_sensitivity),
			func(step: int) -> void: stick_sensitivity = posmod(stick_sensitivity - 1 + step, 10) + 1],
		["invert_y", func() -> String: return tr("on") if invert_y else tr("off"), func(_step: int) -> void: invert_y = not invert_y],
	]
	if _is_desktop():
		rows.append(["fullscreen", func() -> String: return tr("on") if fullscreen else tr("off"), func(_step: int) -> void: fullscreen = not fullscreen])
	_rows(box, rows, 520.0, func(key: String) -> void:
		_apply_settings()
		_save()
		if key == "language":
			_show.call_deferred("settings"))  # every label changes
	_spacer(box, 4)
	_label(box, tr("about_text"), 15, MUTED, 520.0)
	_label(box, tr("developed_by"), 15, MUTED)
	_button(box, tr("back"), _back, 520.0)


func _change_language(step: int) -> void:
	var i := 0
	for n in StringsScript.LANGUAGES.size():
		if StringsScript.LANGUAGES[n][0] == language:
			i = n
	language = StringsScript.LANGUAGES[posmod(i + step, StringsScript.LANGUAGES.size())][0]


func _language_name() -> String:
	for entry in StringsScript.LANGUAGES:
		if entry[0] == language:
			return entry[1]
	return language


func _build_pause(column: VBoxContainer) -> void:
	var box := _panel(column)
	_title(box, tr("paused"), 48)
	_label(box, "%s · %s" % [tr(Maps.MAPS[options["map"]]["name"]), tr("round_short") % [rules.round_n, rules.max_rounds]], 19, MUTED)
	_spacer(box, 6)
	_button(box, tr("resume"), _resume)
	_button(box, tr("how_to_play"), func() -> void:
		back_to = "pause"
		_show("help"))
	_button(box, tr("settings"), func() -> void:
		back_to = "pause"
		_show("settings"))
	_button(box, tr("quit_to_menu"), _quit_to_menu)


func _build_over(column: VBoxContainer) -> void:
	var box := _panel(column)
	var ours: int = final[0]
	var theirs: int = final[1]
	var title := tr("victory") if ours > theirs else (tr("defeat") if ours < theirs else tr("draw"))
	var color := Color(0.5, 1.0, 0.5) if ours > theirs else (Color(1.0, 0.4, 0.3) if ours < theirs else ACCENT)
	_title(box, title, 64, color)
	_label(box, "%d  –  %d" % [ours, theirs], 44, TEXT)
	_label(box, tr("your_stats") % [rules.human.kills, rules.human.deaths], 19, MUTED)
	_spacer(box, 6)
	_button(box, tr("play_again"), _start_match)
	_button(box, tr("main_menu"), _quit_to_menu)


func _back() -> void:
	match screen:
		"setup":
			_show("main")
		"help", "settings":
			_show("pause" if state == "paused" else "main")
		"pause":
			_resume()


# --- Save ----------------------------------------------------------------------------------

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "language", language)
	config.set_value("settings", "sound", sound_on)
	config.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("settings", "stick_sensitivity", stick_sensitivity)
	config.set_value("settings", "invert_y", invert_y)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("match", "options", options)
	config.set_value("record", "wins", wins)
	config.set_value("record", "losses", losses)
	config.set_value("record", "draws", draws)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	language = config.get_value("settings", "language", "")
	sound_on = config.get_value("settings", "sound", true)
	mouse_sensitivity = clampi(config.get_value("settings", "mouse_sensitivity", 5), 1, 10)
	stick_sensitivity = clampi(config.get_value("settings", "stick_sensitivity", 5), 1, 10)
	invert_y = config.get_value("settings", "invert_y", false)
	fullscreen = config.get_value("settings", "fullscreen", false)
	var saved = config.get_value("match", "options", {})
	if saved is Dictionary:
		for key: String in options:
			if saved.has(key) and saved[key] is int:
				options[key] = saved[key]
	options["map"] = clampi(options["map"], 0, Maps.MAPS.size() - 1)
	options["side"] = clampi(options["side"], 0, SIDES.size() - 1)
	options["size"] = clampi(options["size"], 1, 5)
	options["skill"] = clampi(options["skill"], 0, 3)
	options["length"] = clampi(options["length"], 0, 1)
	wins = config.get_value("record", "wins", 0)
	losses = config.get_value("record", "losses", 0)
	draws = config.get_value("record", "draws", 0)


# --- Icon ----------------------------------------------------------------------------------

## Renders icon.png (512x512, rounded corners) and quits. Run: play the game with "-- --render-icon".
func _render_icon() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.msaa_2d = Viewport.MSAA_8X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(IconScript.new())
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
	get_tree().quit()
