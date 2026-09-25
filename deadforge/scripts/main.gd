extends Node3D
## Deadforge: a fast retro first-person shooter in the spirit of Doom, set in a demon-infested
## foundry. Three levels drawn as ASCII maps (levels.gd) are built into 3D when they start
## (world.gd); every texture, model, sound and the music is generated in code.
##
## This node runs the game around the levels: the menus, starting and restarting levels, pause,
## death, the end-of-level tally, settings and the save file. The in-game overlay is hud.gd.
## The menus are Control nodes, so mouse, keyboard and a controller all work through Godot's focus
## navigation: arrows / D-pad move, Enter / A choose, Esc / B go back.

const StringsScript := preload("res://scripts/strings.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const LevelsScript := preload("res://scripts/levels.gd")
const WorldScript := preload("res://scripts/world.gd")
const HudScript := preload("res://scripts/hud.gd")
const IconScript := preload("res://scripts/icon.gd")

const SAVE_PATH := "user://deadforge.cfg"
const DIFFICULTIES := ["easy", "normal", "hard"]
const ORANGE := Color("ff7a1a")
const EMBER := Color("ffb347")
const TEXT := Color("f2e6d8")
const MUTED := Color("a8998a")
const PANEL := Color(0.07, 0.045, 0.04, 0.94)
## What the player carries into each level when starting it from the menu.
const LOADOUTS := [
	{"health": 100.0, "armor": 0.0, "owned": [true, true, false, false], "ammo": {"rivets": 50, "shells": 0, "slag": 0}, "weapon": 1},
	{"health": 100.0, "armor": 0.0, "owned": [true, true, true, false], "ammo": {"rivets": 80, "shells": 20, "slag": 0}, "weapon": 2},
	{"health": 100.0, "armor": 50.0, "owned": [true, true, true, true], "ammo": {"rivets": 100, "shells": 30, "slag": 15}, "weapon": 2},
]

# Settings and progress, saved.
var language := ""
var sound_on := true
var music_on := true
var mouse_sensitivity := 5
var stick_sensitivity := 5
var invert_y := false
var fullscreen := false
var difficulty := 1
var unlocked := 1  # levels that can be started from the menu
var best_times := {}  # level index -> seconds

var state := "menu"  # menu, playing, paused, dead, complete, victory
var screen := ""
var back_to := ""  # screen that Back / Esc returns to
var pending_level := 0  # level picked before choosing the difficulty
var level_index := 0
var carry := {}  # the player's health, armor, weapons and ammo when this level began
var world: Node3D
var had_capture := false
var dead_t := 0.0
var messages: Array = []  # [text, seconds left]
var using_pad := false
var quiet_focus := false

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
var embers: Array = []  # [position, speed, size, phase] for the menu backdrop


func _ready() -> void:
	if "--render-icon" in OS.get_cmdline_user_args():
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
	_show("main")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "playing":
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
	sfx.set_music(music_on)
	if _is_desktop():
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and not (mode == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(mode)


# --- Input ---------------------------------------------------------------------------------

func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"fire": [KEY_CTRL], "next_weapon": [KEY_E], "prev_weapon": [KEY_Q],
		"weapon_1": [KEY_1], "weapon_2": [KEY_2], "weapon_3": [KEY_3], "weapon_4": [KEY_4],
		"pause": [KEY_ESCAPE, KEY_P],
		"look_left": [], "look_right": [], "look_up": [], "look_down": [],
	}
	var axes := {
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	}
	var buttons := {
		"fire": [JOY_BUTTON_A], "next_weapon": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_Y],
		"prev_weapon": [JOY_BUTTON_LEFT_SHOULDER], "pause": [JOY_BUTTON_START],
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
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", click)
	for wheel: Array in [[MOUSE_BUTTON_WHEEL_DOWN, "next_weapon"], [MOUSE_BUTTON_WHEEL_UP, "prev_weapon"]]:
		var event := InputEventMouseButton.new()
		event.button_index = wheel[0]
		InputMap.action_add_event(wheel[1], event)
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
		if event.is_action_pressed("pause"):
			_pause()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture()
		return
	if state == "dead" and dead_t > 0.0:
		return
	if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("pause") and screen == "pause"):
		_back()
		get_viewport().set_input_as_handled()
	elif screen == "settings" and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
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


func _process(delta: float) -> void:
	for i in range(messages.size() - 1, -1, -1):
		messages[i][1] -= delta
		if messages[i][1] <= 0.0:
			messages.remove_at(i)
	if state == "playing" and had_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# The browser (or the system) let go of the mouse, e.g. Esc on the web.
		_pause()
	if state == "dead" and dead_t > 0.0:
		dead_t -= delta
		if dead_t <= 0.0:
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_show("dead")
	if backdrop.visible:
		backdrop.queue_redraw()
	if screen == "help" and help_scroll != null:
		var scroll := Input.get_axis("look_up", "look_down") + Input.get_axis("ui_up", "ui_down")
		help_scroll.scroll_vertical += int(scroll * 700.0 * delta)


# --- Game flow -----------------------------------------------------------------------------

func _start_level(index: int, loadout: Dictionary) -> void:
	get_tree().paused = false
	if world != null:
		world.queue_free()
		world = null
	level_index = index
	carry = loadout.duplicate(true)
	messages.clear()
	world = WorldScript.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.build(self, LevelsScript.LEVELS[index], carry)
	state = "playing"
	_show("")
	_capture()
	message(tr("level_n") % [index + 1, tr(LevelsScript.LEVELS[index]["name"])])


func _pause() -> void:
	if state != "playing":
		return
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
	if world != null:
		world.queue_free()
		world = null
	state = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	had_capture = false
	_show("main")


func on_player_died() -> void:
	state = "dead"
	dead_t = 1.8


func level_complete() -> void:
	state = "complete"
	sfx.play("exit")
	var key := str(level_index)
	if not best_times.has(key) or world.time < best_times[key]:
		best_times[key] = world.time
	unlocked = maxi(unlocked, mini(level_index + 2, LevelsScript.LEVELS.size()))
	_save()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	had_capture = false
	_show("complete" if level_index + 1 < LevelsScript.LEVELS.size() else "victory")


func _next_level() -> void:
	var next: Dictionary = world.player.snapshot()
	_start_level(level_index + 1, next)


func message(text: String) -> void:
	messages.append([text, 3.5])
	if messages.size() > 4:
		messages.remove_at(0)


func shake(amount: float) -> void:
	if world != null and world.player != null:
		world.player.shake = maxf(world.player.shake, amount)


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
	for i in 70:
		embers.append([Vector2(randf(), randf()), randf_range(0.03, 0.12), randf_range(1.0, 3.5), randf() * TAU])


func _build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 21
	var normal := _box(Color(0.16, 0.09, 0.07), Color(0.38, 0.17, 0.09))
	var hover := _box(Color(0.32, 0.12, 0.05), ORANGE)
	var pressed := _box(Color(0.5, 0.18, 0.05), EMBER)
	var disabled := _box(Color(0.1, 0.08, 0.07), Color(0.2, 0.14, 0.1))
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), EMBER, 3, false))
	theme.set_font("font", "Button", bold)
	theme.set_font_size("font_size", "Button", 24)
	for key in ["font_color", "font_focus_color"]:
		theme.set_color(key, "Button", TEXT)
	theme.set_color("font_hover_color", "Button", EMBER)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.45, 0.4, 0.36))
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, Color(0.45, 0.18, 0.08), 2, true, 34))
	return theme


func _box(bg: Color, border: Color, width := 2, filled := true, pad := 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.draw_center = filled
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(4)
	box.content_margin_left = pad * 1.6
	box.content_margin_right = pad * 1.6
	box.content_margin_top = pad
	box.content_margin_bottom = pad
	if not filled:
		box.set_expand_margin_all(3)
	return box


func _draw_backdrop() -> void:
	var rect := backdrop.get_rect()
	var t := Time.get_ticks_msec() / 1000.0
	var glow := Vector2(rect.size.x / 2.0, rect.size.y * 1.05)
	backdrop.draw_rect(rect, Color("0b0504"))
	for i in 30:
		var k := i / 29.0
		backdrop.draw_circle(glow, lerpf(rect.size.y * 1.1, rect.size.y * 0.15, k), Color(0.55, 0.12, 0.03, 0.035 + k * 0.02))
	for e: Array in embers:
		var p: Vector2 = e[0]
		var y := fposmod(p.y - t * e[1], 1.0)
		var x := p.x + sin(t * 0.8 + e[3]) * 0.02
		var alpha := clampf(y * 1.4, 0.0, 1.0) * (0.6 + 0.4 * sin(t * 3.0 + e[3]))
		backdrop.draw_circle(Vector2(x * rect.size.x, y * rect.size.y), e[2], Color(1.0, 0.55 + 0.3 * sin(e[3]), 0.15, alpha))


func _show(new_screen: String) -> void:
	screen = new_screen
	help_scroll = null
	if menu_root != null:
		menu_root.queue_free()
		menu_root = null
	emblem = null
	backdrop.visible = new_screen != "" and world == null
	if new_screen == "":
		return
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu_root)
	if world != null:
		var dim := ColorRect.new()
		dim.color = Color(0.04, 0.0, 0.0, 0.6)
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
		"difficulty":
			_build_difficulty(column)
		"levels":
			_build_levels(column)
		"help":
			_build_help(column)
		"settings":
			_build_settings(column)
		"pause":
			_build_pause(column)
		"dead":
			_build_dead(column)
		"complete", "victory":
			_build_complete(column, new_screen == "victory")
	_update_hint()
	# Focus the first button once the new buttons are in the tree.
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


func _title(parent: Control, text: String, font_size := 44) -> void:
	var label := _label(parent, text, font_size, ORANGE)
	label.add_theme_font_override("font", title_font)
	label.add_theme_color_override("font_outline_color", Color(0.25, 0.02, 0.0))
	label.add_theme_constant_override("outline_size", maxi(4, font_size / 8))


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


func _level_name(index: int) -> String:
	return tr(LevelsScript.LEVELS[index]["name"])


func _build_main(column: VBoxContainer) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(120, 120)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(holder)
	emblem = IconScript.new()
	emblem.background = false
	emblem.scale = Vector2.ONE * (120.0 / 512.0)
	holder.add_child(emblem)
	_title(column, "DEADFORGE", 84)
	_label(column, tr("tagline"), 19, MUTED, 640.0)
	_spacer(column, 4)
	if unlocked > 1:
		var last := unlocked - 1
		_button(column, tr("continue") % _level_name(last), func() -> void: _start_level(last, LOADOUTS[last]))
	_button(column, tr("new_game"), func() -> void:
		pending_level = 0
		back_to = "main"
		_show("difficulty"))
	if unlocked > 1:
		_button(column, tr("level_select"), func() -> void: _show("levels"))
	_button(column, tr("how_to_play"), func() -> void:
		back_to = "main"
		_show("help"))
	_button(column, tr("settings"), func() -> void:
		back_to = "main"
		_show("settings"))
	if _is_desktop():
		_button(column, tr("quit"), func() -> void: get_tree().quit())


func _build_difficulty(column: VBoxContainer) -> void:
	var box := _panel(column)
	_title(box, tr("choose_difficulty"), 40)
	_label(box, tr("level_n") % [pending_level + 1, _level_name(pending_level)], 19, MUTED)
	_spacer(box, 6)
	for i in DIFFICULTIES.size():
		var button := _button(box, tr("diff_" + DIFFICULTIES[i]), func() -> void:
			difficulty = i
			_save()
			_start_level(pending_level, LOADOUTS[pending_level]))
		if i == difficulty:
			button.add_theme_color_override("font_color", EMBER)
		_label(box, tr("diff_%s_detail" % DIFFICULTIES[i]), 16, MUTED)
	_spacer(box, 6)
	_button(box, tr("back"), _back)


func _build_levels(column: VBoxContainer) -> void:
	var box := _panel(column)
	_title(box, tr("choose_level"), 40)
	for i in LevelsScript.LEVELS.size():
		var text := tr("level_n") % [i + 1, _level_name(i)]
		var button := _button(box, text if i < unlocked else "%s · %s" % [text, tr("locked_level")], func() -> void:
			pending_level = i
			back_to = "levels"
			_show("difficulty"), 520.0)
		button.disabled = i >= unlocked
		if best_times.has(str(i)):
			_label(box, tr("best_time") % _clock(best_times[str(i)]), 15, MUTED)
	_spacer(box, 6)
	_button(box, tr("back"), _back, 520.0)


func _build_help(column: VBoxContainer) -> void:
	var box := _panel(column)
	_title(box, tr("how_to_play"), 40)
	help_scroll = ScrollContainer.new()
	help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	help_scroll.custom_minimum_size = Vector2(800, minf(470.0, get_viewport().get_visible_rect().size.y - 250.0))
	box.add_child(help_scroll)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 6)
	help_scroll.add_child(text)
	for section in [["help_goal", "help_goal_text"], ["help_weapons", "help_weapons_text"],
			["help_enemies", "help_enemies_text"], ["controls", "help_keyboard"], ["", "help_pad"]]:
		if section[0] != "":
			_spacer(text, 4)
			_label(text, tr(section[0]), 24, EMBER)
		var body := _label(text, tr(section[1]), 18, TEXT, 770.0)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button(box, tr("back"), _back)


func _build_settings(column: VBoxContainer) -> void:
	var box := _panel(column)
	_title(box, tr("settings"), 40)
	var rows := [
		["language", _language_name, _change_language],
		["sound", func() -> String: return tr("on") if sound_on else tr("off"), func(_step: int) -> void: sound_on = not sound_on],
		["music", func() -> String: return tr("on") if music_on else tr("off"), func(_step: int) -> void: music_on = not music_on],
		["mouse_sensitivity", func() -> String: return str(mouse_sensitivity),
			func(step: int) -> void: mouse_sensitivity = posmod(mouse_sensitivity - 1 + step, 10) + 1],
		["stick_sensitivity", func() -> String: return str(stick_sensitivity),
			func(step: int) -> void: stick_sensitivity = posmod(stick_sensitivity - 1 + step, 10) + 1],
		["invert_y", func() -> String: return tr("on") if invert_y else tr("off"), func(_step: int) -> void: invert_y = not invert_y],
	]
	if _is_desktop():
		rows.append(["fullscreen", func() -> String: return tr("on") if fullscreen else tr("off"), func(_step: int) -> void: fullscreen = not fullscreen])
	for row: Array in rows:
		var key: String = row[0]
		var value: Callable = row[1]
		var change: Callable = row[2]
		var button := _button(box, "", func() -> void: pass, 520.0)
		var refresh := func() -> void:
			button.text = "%s:  %s" % [tr(key), value.call()]
		var adjust := func(step: int) -> void:
			change.call(step)
			_apply_settings()
			_save()
			if key == "language":
				_show("settings")  # every label changes
				return
			refresh.call()
		button.set_meta("adjust", adjust)
		button.pressed.connect(func() -> void: adjust.call(1))
		refresh.call()
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
	_label(box, tr("level_n") % [level_index + 1, _level_name(level_index)], 19, MUTED)
	_spacer(box, 6)
	_button(box, tr("resume"), _resume)
	_button(box, tr("restart_level"), func() -> void: _start_level(level_index, carry))
	_button(box, tr("how_to_play"), func() -> void:
		back_to = "pause"
		_show("help"))
	_button(box, tr("settings"), func() -> void:
		back_to = "pause"
		_show("settings"))
	_button(box, tr("quit_to_menu"), _quit_to_menu)


func _build_dead(column: VBoxContainer) -> void:
	var box := _panel(column)
	_title(box, tr("you_died"), 64)
	_label(box, tr("died_text"), 19, MUTED)
	_spacer(box, 6)
	_button(box, tr("try_again"), func() -> void: _start_level(level_index, carry))
	_button(box, tr("quit_to_menu"), _quit_to_menu)


func _build_complete(column: VBoxContainer, victory: bool) -> void:
	var box := _panel(column)
	_title(box, tr("victory") if victory else tr("level_complete"), 56)
	_label(box, tr("level_n") % [level_index + 1, _level_name(level_index)], 19, MUTED)
	if victory:
		_label(box, tr("victory_text"), 19, TEXT, 520.0)
	_spacer(box, 6)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	var pct := func(a: int, b: int) -> String:
		return "%d / %d  (%d%%)" % [a, b, roundi(100.0 * a / b) if b > 0 else 100]
	var best: float = best_times.get(str(level_index), world.time)
	for row in [["kills", pct.call(world.kills, world.total_kills)], ["items", pct.call(world.items, world.total_items)],
			["time", _clock(world.time)], ["", tr("best_time") % _clock(best)]]:
		var name_label := _label(grid, tr(row[0]) if row[0] != "" else "", 24, EMBER)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var value_label := _label(grid, row[1], 24, TEXT)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_spacer(box, 8)
	if not victory:
		_button(box, tr("next_level"), _next_level)
	_button(box, tr("quit_to_menu"), _quit_to_menu)


func _back() -> void:
	match screen:
		"difficulty":
			_show(back_to if back_to == "levels" else "main")
		"levels":
			_show("main")
		"help", "settings":
			_show("pause" if state == "paused" else "main")
		"pause":
			_resume()


static func _clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


# --- Save ----------------------------------------------------------------------------------

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "language", language)
	config.set_value("settings", "sound", sound_on)
	config.set_value("settings", "music", music_on)
	config.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("settings", "stick_sensitivity", stick_sensitivity)
	config.set_value("settings", "invert_y", invert_y)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("progress", "difficulty", difficulty)
	config.set_value("progress", "unlocked", unlocked)
	config.set_value("progress", "best_times", best_times)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	language = config.get_value("settings", "language", "")
	sound_on = config.get_value("settings", "sound", true)
	music_on = config.get_value("settings", "music", true)
	mouse_sensitivity = clampi(config.get_value("settings", "mouse_sensitivity", 5), 1, 10)
	stick_sensitivity = clampi(config.get_value("settings", "stick_sensitivity", 5), 1, 10)
	invert_y = config.get_value("settings", "invert_y", false)
	fullscreen = config.get_value("settings", "fullscreen", false)
	difficulty = clampi(config.get_value("progress", "difficulty", 1), 0, DIFFICULTIES.size() - 1)
	unlocked = clampi(config.get_value("progress", "unlocked", 1), 1, LevelsScript.LEVELS.size())
	var times = config.get_value("progress", "best_times", {})
	if times is Dictionary:
		best_times = times


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
