extends Node2D
## Old Flags: a flag is shown and you pick which country or state it belonged to from 4 choices,
## 10 rounds per game. Ported from the React Native app in desktop_apps/old-flags.
##
## The screens are built from Control nodes, so mouse, touch, keyboard and an Xbox (or any other)
## controller each work on their own through Godot's focus navigation: arrows / D-pad / left stick
## move, Enter / Space / A choose, Esc / B go back, Start plays or moves on, the right stick scrolls.
## The focus ring shows while a keyboard or controller is in use and hides after a click or touch.

const FlagsScript := preload("res://scripts/flags.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const StringsScript := preload("res://scripts/strings.gd")

const ROUNDS := 10
const OPTIONS := 4
const PASS_RATIO := 0.7
const MAX_WIDTH := 680.0  # widest the page column gets
const SAVE_PATH := "user://old-flags.cfg"
const MAX_RESULTS := 500  # quiz results kept in the save file
const RECENT := 20  # results listed under Recent History
const STICK_SCROLL := 1100.0  # pixels per second at full right-stick tilt
const STICK_DEADZONE := 0.25
const TYPES := ["old", "classic"]
const MODES := ["name", "flag"]  # "name": see the flag, pick the name. "flag": see the name, pick the flag
const DIFFICULTIES := ["all", "easy", "medium", "hard"]  # only for "old"
const MENU_SCREENS := ["menu", "mode", "difficulty", "help", "stats", "settings"]  # the ones with the bottom bar
const TABS := [["home", "menu"], ["play", "mode"], ["stats", "stats"], ["settings", "settings"]]  # [id, screen]

# A vintage palette: aged paper, bronze and oxidized ink.
const BG := Color("f3e9d2")
const PAPER := Color("fbf6e6")
const INK := Color("231a12")
const MUTED := Color("7a6c56")
const SEPIA := Color("3b2a1a")
const SEPIA_LIGHT := Color("5a4530")
const SEPIA_DARK := Color("241a10")
const GOLD := Color("c08a2e")
const GOLD_LIGHT := Color("d9a94a")
const GOLD_DARK := Color("9c6f22")
const TAN := Color("efe4c8")
const TAN_HOVER := Color("f8f0da")
const TAN_DARK := Color("c9b998")
const GREEN := Color("5c7a52")
const RED := Color("8c3a3a")
const BAR := Color("ebdcb9")  # bottom bar, a shade under the page

# Settings and choices, saved.
var language := ""
var sound_on := true
var vibration_on := true
var game_type := "old"
var mode := "name"
var difficulty := "all"
var results := []  # finished quizzes, oldest first: {type, mode, difficulty, score, total, time}

# The quiz being played.
var quiz_type := "old"
var quiz_mode := "name"
var quiz_difficulty := "all"
var rounds := []  # one {flag, options, picked} per round
var round_index := 0
var score := 0
var answered := false
var animate_card := false  # fade the flag / name card in when a new round starts

# "menu" (pick Old or Classic), "mode", "difficulty" (Old only), "game", "result", "help", "stats" or "settings"
var screen := "menu"
var clear_armed := false
var nav_active := false  # keyboard or controller in use: show the focus ring
var using_pad := false
var quiet_focus := false  # no focus sound while the game moves the focus itself
var scroll_carry := 0.0
var column_width := 0.0

var font: Font
var bold: Font
var ui_theme: Theme
var focus_style: StyleBox
var tab_focus_style: StyleBox
var textures := {}
var sfx

var ui_root: Control
var scroll: ScrollContainer
var bar: PanelContainer  # bottom bar of the menu screens, outside the scrolling page
var bar_row: HBoxContainer
var margin: MarginContainer
var page: VBoxContainer
var buttons := {}  # id -> Button on the current page, to find the focus again after a rebuild
var default_focus := ""
var hint_label: Label
var confirm: Control  # the "leave this quiz?" dialog while it's open
var confirm_buttons: Array[Button] = []
var confirm_return := ""  # button focused before the dialog opened


func _ready() -> void:
	font = _font(400)
	bold = _font(700)
	sfx = SfxScript.new()
	add_child(sfx)
	StringsScript.install()
	_load()
	if language == "":
		language = StringsScript.system_language()
	nav_active = not _is_mobile()
	_bind_pad()
	_build_theme()
	_build_ui()
	_apply_settings()
	get_viewport().size_changed.connect(_on_resize)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_on_resize()
	_show("menu", "type_old")


func _notification(what: int) -> void:
	# Android's back button / gesture.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if confirm != null:
			_close_confirm()
		elif screen == "menu":
			get_tree().quit()
		else:
			_back()


func _font(weight: int) -> Font:
	if OS.has_feature("web"):
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 0.7 if weight >= 700 else 0.0
		return variation
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Noto Serif", "Times New Roman", "serif"])
	system.font_weight = weight
	return system


func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _apply_settings() -> void:
	TranslationServer.set_locale(language)
	AudioServer.set_bus_mute(0, not sound_on)


# --- Look ----------------------------------------------------------------------------------

func _draw() -> void:
	var rect := get_viewport_rect()
	draw_rect(rect, BG)
	# A thin double frame, like an old certificate.
	draw_rect(rect.grow(-8.0), TAN_DARK, false, 2.0)
	draw_rect(rect.grow(-14.0), Color(TAN_DARK, 0.55), false, 1.0)


func _box(bg: Color, border: Color, width := 2, radius := 10, pad := Vector2(14, 10)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad.x
	box.content_margin_right = pad.x
	box.content_margin_top = pad.y
	box.content_margin_bottom = pad.y
	return box


func _build_theme() -> void:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 22

	t.set_stylebox("normal", "Button", _box(TAN, TAN_DARK))
	t.set_stylebox("hover", "Button", _box(TAN_HOVER, GOLD))
	t.set_stylebox("pressed", "Button", _box(TAN_DARK, SEPIA_LIGHT))
	t.set_stylebox("hover_pressed", "Button", _box(TAN_DARK, SEPIA_LIGHT))
	t.set_stylebox("disabled", "Button", _box(TAN, TAN_DARK))
	focus_style = _box(Color.TRANSPARENT, SEPIA, 3, 13)
	focus_style.draw_center = false
	focus_style.set_expand_margin_all(4)
	t.set_stylebox("focus", "Button", focus_style if nav_active else StyleBoxEmpty.new())
	for item in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		t.set_color(item, "Button", INK)

	# A choice in a row of options; the chosen one is dark.
	t.set_type_variation("Choice", "Button")
	t.set_stylebox("pressed", "Choice", _box(SEPIA_LIGHT, SEPIA))
	t.set_stylebox("hover_pressed", "Choice", _box(SEPIA_LIGHT, GOLD))
	t.set_color("font_pressed_color", "Choice", PAPER)
	t.set_color("font_hover_pressed_color", "Choice", PAPER)

	t.set_type_variation("Primary", "Button")
	t.set_stylebox("normal", "Primary", _box(GOLD, GOLD_DARK))
	t.set_stylebox("hover", "Primary", _box(GOLD_LIGHT, GOLD_DARK))
	t.set_stylebox("pressed", "Primary", _box(GOLD_DARK, GOLD_DARK))
	t.set_stylebox("hover_pressed", "Primary", _box(GOLD_DARK, GOLD_DARK))
	t.set_font("font", "Primary", bold)
	t.set_font_size("font_size", "Primary", 26)
	for item in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(item, "Primary", SEPIA_DARK)

	# Bottom bar, as in the original app: icon over a small label, muted, the current tab in gold.
	t.set_type_variation("Tab", "Button")
	var flat := StyleBoxEmpty.new()
	for item in ["normal", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(item, "Tab", flat)
	t.set_stylebox("hover", "Tab", _box(Color(SEPIA, 0.05), Color.TRANSPARENT, 0, 0, Vector2.ZERO))
	tab_focus_style = _box(Color.TRANSPARENT, GOLD_DARK, 2, 8)
	tab_focus_style.draw_center = false
	tab_focus_style.set_expand_margin_all(-4)
	t.set_stylebox("focus", "Tab", tab_focus_style if nav_active else StyleBoxEmpty.new())
	var bar_style := _box(BAR, TAN_DARK, 0, 0, Vector2.ZERO)
	bar_style.border_width_top = 1
	bar_style.shadow_color = Color(SEPIA, 0.08)
	bar_style.shadow_size = 8
	t.set_type_variation("Bar", "PanelContainer")
	t.set_stylebox("panel", "Bar", bar_style)

	t.set_type_variation("Small", "Button")
	t.set_font_size("font_size", "Small", 19)

	t.set_color("font_color", "Label", INK)
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", bold)
	t.set_font_size("font_size", "Title", 40)
	t.set_color("font_color", "Title", SEPIA)
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", bold)
	t.set_color("font_color", "Heading", SEPIA_LIGHT)
	t.set_type_variation("Strong", "Label")
	t.set_font("font", "Strong", bold)
	t.set_type_variation("Muted", "Label")
	t.set_font_size("font_size", "Muted", 18)
	t.set_color("font_color", "Muted", MUTED)

	t.set_stylebox("panel", "PanelContainer", _box(PAPER, TAN_DARK, 2, 12, Vector2(16, 14)))

	var bar := _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 4, Vector2(4, 0))
	t.set_stylebox("scroll", "VScrollBar", bar)
	t.set_stylebox("grabber", "VScrollBar", _box(Color(SEPIA, 0.3), Color.TRANSPARENT, 0, 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", _box(Color(SEPIA, 0.45), Color.TRANSPARENT, 0, 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", _box(Color(SEPIA, 0.6), Color.TRANSPARENT, 0, 4))

	t.set_stylebox("background", "ProgressBar", _box(TAN, TAN_DARK, 1, 6, Vector2.ZERO))
	t.set_stylebox("fill", "ProgressBar", _box(GREEN, GREEN, 0, 6, Vector2.ZERO))
	ui_theme = t


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = ui_theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	ui_root = root
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	root.add_child(column)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	bar = PanelContainer.new()
	bar.theme_type_variation = "Bar"
	column.add_child(bar)
	bar_row = HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 0)
	bar.add_child(bar_row)
	margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	page = VBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)


func _on_resize() -> void:
	var view := get_viewport_rect().size
	var side := maxf(24.0, (view.x - MAX_WIDTH) / 2.0)
	margin.add_theme_constant_override("margin_left", int(side))
	margin.add_theme_constant_override("margin_right", int(side))
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	queue_redraw()
	# Flag sizes depend on the column width, so rebuild when it changes.
	var width := view.x - side * 2.0
	if not is_equal_approx(width, column_width):
		column_width = width
		if page.get_child_count() > 0:
			_rebuild()


# --- Input ---------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		var pad := event is InputEventJoypadButton
		if pad != using_pad:
			using_pad = pad
			_update_hint()
		if not nav_active and _is_nav_event(event):
			# The first press only shows where the focus is.
			_set_nav(true)
			_ensure_focus()
			get_viewport().set_input_as_handled()
			return
		_set_nav(true)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5 \
			and (event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y):
		if not using_pad:
			using_pad = true
			_update_hint()
		_set_nav(true)
	elif (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		_set_nav(false)
	if nav_active and _is_nav_event(event) and get_viewport().gui_get_focus_owner() == null:
		_ensure_focus()
		get_viewport().set_input_as_handled()


## Godot's ui_* directions already take the D-pad and left stick, but accept and cancel only take
## keys: add A and B, and let the bumpers step through the buttons like Tab / Shift+Tab.
func _bind_pad() -> void:
	var binds := {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B,
			"ui_focus_prev": JOY_BUTTON_LEFT_SHOULDER, "ui_focus_next": JOY_BUTTON_RIGHT_SHOULDER}
	for action: String in binds:
		var event := InputEventJoypadButton.new()
		event.button_index = binds[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _is_nav_event(event: InputEvent) -> bool:
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev", "ui_accept"]:
		if event.is_action_pressed(action):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if confirm != null:
		# Only the dialog's buttons work while it's open; B / Esc keeps playing.
		if event.is_action_pressed("ui_cancel"):
			_close_confirm()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_back()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		_start_button()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if screen == "game" and not answered and key >= KEY_1 and key < KEY_1 + OPTIONS:
			_answer(rounds[round_index].options[key - KEY_1])
		elif screen == "game" and not answered and key >= KEY_KP_1 and key < KEY_KP_1 + OPTIONS:
			_answer(rounds[round_index].options[key - KEY_KP_1])
		elif key == KEY_PAGEDOWN or key == KEY_PAGEUP:
			var step := int(scroll.size.y * 0.8) * (1 if key == KEY_PAGEDOWN else -1)
			scroll.scroll_vertical += step
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# The right stick scrolls long pages (help, stats, results).
	var tilt := 0.0
	for device in Input.get_connected_joypads():
		var axis := Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		if absf(axis) > absf(tilt):
			tilt = axis
	if absf(tilt) < STICK_DEADZONE:
		scroll_carry = 0.0
		return
	scroll_carry += tilt * STICK_SCROLL * delta
	var step := int(scroll_carry)
	scroll_carry -= step
	scroll.scroll_vertical += step


func _set_nav(active: bool) -> void:
	if active == nav_active:
		return
	nav_active = active
	ui_theme.set_stylebox("focus", "Button", focus_style if active else StyleBoxEmpty.new())
	ui_theme.set_stylebox("focus", "Tab", tab_focus_style if active else StyleBoxEmpty.new())


func _ensure_focus() -> void:
	if get_viewport().gui_get_focus_owner() == null:
		if confirm != null:
			confirm_buttons[0].grab_focus()
		else:
			_focus(default_focus)


func _focus(id: String) -> void:
	if buttons.has(id) and buttons[id].is_visible_in_tree():
		quiet_focus = true
		buttons[id].grab_focus()
		quiet_focus = false


func _on_focus_changed(_control: Control) -> void:
	if nav_active and not quiet_focus:
		sfx.play("move")


func _start_button() -> void:
	match screen:
		"game":
			if answered:
				_next()
		"result":
			_start_game()


## The game's logo, at the top of every menu screen (largest on the first one).
func _add_logo() -> void:
	var view := get_viewport_rect().size
	var logo := TextureRect.new()
	logo.texture = preload("res://icon.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var share := 0.2 if screen == "menu" else 0.14
	var height := clampf(view.y * share, 90.0, 220.0)
	if screen == "menu":
		logo.custom_minimum_size.y = height
		page.add_child(logo)
		return
	# Past the first screen: a Back button in the top-left corner, beside the logo.
	var top := Control.new()
	top.custom_minimum_size.y = height
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.add_child(logo)
	var back := _button("back", "‹  " + tr("back"), _back, "Small", "")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.position = Vector2.ZERO
	back.custom_minimum_size = Vector2(130, 48)
	top.add_child(back)
	page.add_child(top)


## The bottom bar of the menu screens: Home, How to Play, Stats, Settings.
func _build_bar() -> void:
	for child in bar_row.get_children():
		bar_row.remove_child(child)
		child.queue_free()
	bar.visible = screen in MENU_SCREENS
	if not bar.visible:
		return
	var current := screen
	if screen == "difficulty":
		current = "mode"
	elif screen == "help":
		current = "menu"
	for tab: Array in TABS:
		var target: String = tab[1]
		var here := target == current
		var color := GOLD_DARK if here else MUTED
		var button := _button("tab_" + tab[0], "", _show.bind(target, "tab_" + tab[0]), "Tab")
		button.custom_minimum_size.y = 72
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 4)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon := TabIcon.new()
		icon.kind = tab[0]
		icon.color = color
		icon.hole = BAR
		icon.custom_minimum_size = Vector2(28, 28)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		var label := _label(tr(tab[0]), "Strong")
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", color)
		box.add_child(label)
		button.add_child(box)
		if here:
			# A short gold line on top of the current tab.
			var mark := ColorRect.new()
			mark.color = GOLD
			mark.anchor_left = 0.5
			mark.anchor_right = 0.5
			mark.offset_left = -22
			mark.offset_right = 22
			mark.offset_bottom = 3
			button.add_child(mark)
		_ignore_mouse(button)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		bar_row.add_child(button)


## One step back: difficulty -> mode -> game type (the menu).
func _back() -> void:
	if screen == "menu":
		return
	sfx.play("click")
	match screen:
		"difficulty":
			_show("mode", "mode_" + mode)
		"game":
			_ask_leave()
			return
		"help":
			_show("menu", "help")
		_:
			_show("menu", "type_" + game_type)


## Asks before leaving a quiz in the middle: "Keep playing" (focused) or "Leave".
func _ask_leave() -> void:
	if confirm != null:
		return
	confirm_return = ""
	var focused := get_viewport().gui_get_focus_owner()
	for id: String in buttons:
		if buttons[id] == focused:
			confirm_return = id
	var shade := ColorRect.new()
	shade.color = Color(SEPIA_DARK, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		# A click or tap outside the box keeps playing.
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
			_close_confirm())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(column_width, 480.0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := _label(tr("leave_title"), "Heading")
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	box.add_child(_label(tr("leave_text")))
	var row := _row()
	var stay := _button("", tr("keep_playing"), _close_confirm, "Primary")
	var leave := _button("", tr("leave"), func() -> void:
		_close_confirm()
		_show("menu", "type_" + game_type))
	buttons.erase("")
	row.add_child(stay)
	row.add_child(leave)
	box.add_child(row)
	ui_root.add_child(shade)
	confirm = shade
	confirm_buttons = [stay, leave]
	# Keep the focus inside the dialog.
	for button in confirm_buttons:
		var other: Button = leave if button == stay else stay
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			button.set_focus_neighbor(side, button.get_path())
		button.set_focus_neighbor(SIDE_LEFT, stay.get_path())
		button.set_focus_neighbor(SIDE_RIGHT, leave.get_path())
		button.focus_next = other.get_path()
		button.focus_previous = other.get_path()
	quiet_focus = true
	stay.grab_focus()
	quiet_focus = false


func _close_confirm() -> void:
	if confirm == null:
		return
	confirm.queue_free()
	confirm = null
	confirm_buttons.clear()
	_focus(confirm_return if buttons.has(confirm_return) else default_focus)


func _buzz() -> void:
	if not vibration_on:
		return
	if _is_mobile():
		Input.vibrate_handheld(80)
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, 0.35, 0.7, 0.25)


func _update_hint() -> void:
	if hint_label != null and is_instance_valid(hint_label):
		hint_label.text = tr("hint_pad") if using_pad else tr("hint_keys")


# --- Quiz ----------------------------------------------------------------------------------

## The flags the current choices draw from.
func _pool(type: String, diff: String) -> Array:
	if type == "classic":
		return FlagsScript.CLASSIC.duplicate()
	var pool := []
	for slug: String in FlagsScript.OLD:
		if diff == "all" or FlagsScript.OLD[slug] == diff:
			pool.append(slug)
	return pool


func _start_game() -> void:
	sfx.play("click")
	quiz_type = game_type
	quiz_mode = mode
	quiz_difficulty = difficulty if game_type == "old" else "all"
	var pool := _pool(quiz_type, quiz_difficulty)
	var order := pool.duplicate()
	order.shuffle()
	rounds.clear()
	for slug: String in order.slice(0, ROUNDS):
		var wrong := pool.filter(func(other: String) -> bool: return other != slug)
		wrong.shuffle()
		var options: Array = [slug] + wrong.slice(0, OPTIONS - 1)
		options.shuffle()
		rounds.append({"flag": slug, "options": options, "picked": ""})
	round_index = 0
	score = 0
	answered = false
	animate_card = true
	_show("game")


func _answer(slug: String) -> void:
	if answered:
		return
	answered = true
	var turn: Dictionary = rounds[round_index]
	turn.picked = slug
	if slug == turn.flag:
		score += 1
		sfx.play("correct")
	else:
		sfx.play("wrong")
		_buzz()
	_rebuild("next")


func _next() -> void:
	if not answered:
		return
	sfx.play("click")
	round_index += 1
	if round_index >= rounds.size():
		_finish()
		return
	answered = false
	animate_card = true
	_show("game")


func _finish() -> void:
	var pass_ok := _passed()
	results.append({"type": quiz_type, "mode": quiz_mode, "difficulty": quiz_difficulty,
			"score": score, "total": rounds.size(), "time": int(Time.get_unix_time_from_system())})
	if results.size() > MAX_RESULTS:
		results = results.slice(results.size() - MAX_RESULTS)
	_save()
	sfx.play("pass" if pass_ok else "fail")
	if not pass_ok:
		_buzz()
	_show("result")


func _passed() -> bool:
	return score >= _pass_mark(rounds.size())


func _pass_mark(total: int) -> int:
	return ceili(total * PASS_RATIO - 0.001)


func _name(slug: String, type: String) -> String:
	var index := 0
	for i in StringsScript.LANGUAGES.size():
		if StringsScript.LANGUAGES[i][0] == language:
			index = i
	return FlagsScript.NAMES[type][slug][index]


func _texture(slug: String, type: String) -> Texture2D:
	var path := "res://flags/%s/%s.png" % [type, slug]
	if not textures.has(path):
		textures[path] = load(path)
	return textures[path]


func _quiz_label(type: String, quiz_mode_name: String, diff: String) -> String:
	var text := tr("type_" + type) + " · " + tr("mode_" + quiz_mode_name)
	if type == "old":
		text += " · " + tr("diff_" + diff)
	return text


# --- Pages ---------------------------------------------------------------------------------

## Opens a page with `focus_id` (or the page's default button) focused.
func _show(new_screen: String, focus_id := "") -> void:
	screen = new_screen
	clear_armed = false
	_rebuild(focus_id, false)
	scroll.scroll_vertical = 0
	_scroll_top.call_deferred()


func _scroll_top() -> void:
	scroll.scroll_vertical = 0


## Builds the current page again from the state, keeping (or moving) the focus.
func _rebuild(focus_id := "", keep_focus := true) -> void:
	if focus_id == "" and keep_focus:
		var focused := get_viewport().gui_get_focus_owner()
		for id: String in buttons:
			if buttons[id] == focused:
				focus_id = id
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	buttons.clear()
	hint_label = null
	default_focus = ""
	_build_bar()
	if screen in MENU_SCREENS:
		_add_logo()
	match screen:
		"menu":
			_build_menu()
		"mode":
			_build_mode()
		"difficulty":
			_build_difficulty()
		"game":
			_build_game()
		"result":
			_build_result()
		"help":
			_build_help()
		"stats":
			_build_stats()
		"settings":
			_build_settings()
	if confirm != null:
		return  # the dialog keeps the focus
	if not buttons.has(focus_id) or buttons[focus_id].focus_mode == Control.FOCUS_NONE:
		focus_id = default_focus
	_focus(focus_id)


func _label(text: String, variation := "", align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(id: String, text: String, callback: Callable, variation := "", sound := "click") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 56
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		if sound != "":
			sfx.play(sound)
		callback.call())
	buttons[id] = button
	return button


func _row(separation := 10) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box


## A flag in a thin frame, as big as fits in `max_size` without changing its shape.
func _flag_view(slug: String, type: String, max_size: Vector2) -> Control:
	var texture := _texture(slug, type)
	var aspect := float(texture.get_width()) / float(texture.get_height())
	var fit := Vector2(max_size.x, max_size.x / aspect)
	if fit.y > max_size.y:
		fit = Vector2(max_size.y * aspect, max_size.y)
	var frame := PanelContainer.new()
	var style := _box(Color.WHITE, Color(SEPIA, 0.35), 1, 2, Vector2.ZERO)
	style.shadow_color = Color(SEPIA, 0.22)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	frame.add_theme_stylebox_override("panel", style)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.custom_minimum_size = fit.floor()
	frame.add_child(picture)
	var center := CenterContainer.new()
	center.add_child(frame)
	_ignore_mouse(center)
	return center


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


## A big choice that leads to the next step: a name with a line of detail under it.
func _step(id: String, title: String, detail: String, callback: Callable) -> void:
	var button := _button(id, "", callback)
	button.custom_minimum_size.y = 92
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	var name_label := _label(title, "Strong")
	name_label.add_theme_font_size_override("font_size", 26)
	box.add_child(name_label)
	box.add_child(_label(detail, "Muted"))
	button.add_child(box)
	_ignore_mouse(box)
	page.add_child(button)


## Step 1: Old or Classic.
func _build_menu() -> void:
	page.add_child(_label(tr("title"), "Title"))
	page.add_child(_label(tr("tagline")))
	page.add_child(_label(tr("choose_game"), "Heading"))
	for type: String in TYPES:
		_step("type_" + type, tr("type_" + type), tr("type_%s_detail" % type), func() -> void:
			game_type = type
			_save()
			_show("mode", "mode_" + mode))
	page.add_child(_button("help", tr("how_to_play"), _show.bind("help"), "Small"))
	if not _is_mobile():
		hint_label = _label("", "Muted")
		page.add_child(hint_label)
		_update_hint()
	default_focus = "type_old"


## Step 2: Guess the Name or Guess the Flag. Classic starts from here.
func _build_mode() -> void:
	page.add_child(_label(tr("choose_mode"), "Title"))
	page.add_child(_label(tr("type_" + game_type), "Heading"))
	for value: String in MODES:
		_step("mode_" + value, tr("mode_" + value), tr("mode_%s_detail" % value), func() -> void:
			mode = value
			_save()
			if game_type == "old":
				_show("difficulty", "diff_" + difficulty)
			else:
				_start_game())
	var rules := tr("rules_old") if game_type == "old" else tr("rules_classic")
	page.add_child(_label(rules % [ROUNDS, OPTIONS], "Muted"))
	default_focus = "mode_name"


## Step 3 (Old only): how hard the pool of flags is. Picking one starts the quiz.
func _build_difficulty() -> void:
	page.add_child(_label(tr("choose_difficulty"), "Title"))
	page.add_child(_label(tr("type_old") + " · " + tr("mode_" + mode), "Heading"))
	for value: String in DIFFICULTIES:
		var detail := tr("pool_size") % _pool("old", value).size()
		_step("diff_" + value, tr("diff_" + value), detail, func() -> void:
			difficulty = value
			_save()
			_start_game())
	default_focus = "diff_all"


func _build_game() -> void:
	var view := get_viewport_rect().size
	var turn: Dictionary = rounds[round_index]

	var top := _row()
	var quit := _button("quit", "‹  " + tr("menu"), _back, "Small")
	quit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quit.custom_minimum_size.x = 140
	top.add_child(quit)
	var status := VBoxContainer.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_constant_override("separation", 0)
	status.add_child(_label(tr("status") % [round_index + 1, rounds.size(), score], "Strong", HORIZONTAL_ALIGNMENT_RIGHT))
	status.add_child(_label(_quiz_label(quiz_type, quiz_mode, quiz_difficulty), "Muted", HORIZONTAL_ALIGNMENT_RIGHT))
	top.add_child(status)
	page.add_child(top)
	page.add_child(_progress_dots())

	var card: Control
	if quiz_mode == "name":
		var flag_height := clampf(view.y * 0.25, 130.0, 300.0)
		card = _flag_view(turn.flag, quiz_type, Vector2(column_width, flag_height))
		card.custom_minimum_size.y = flag_height + 12.0
	else:
		var panel := PanelContainer.new()
		var label := _label(_name(turn.flag, quiz_type), "Title")
		label.add_theme_font_size_override("font_size", 30)
		label.custom_minimum_size.y = 80
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(label)
		card = panel
	page.add_child(card)
	if animate_card:
		animate_card = false
		card.modulate.a = 0.0
		create_tween().tween_property(card, "modulate:a", 1.0, 0.22)

	var options: Container
	if quiz_mode == "name":
		options = VBoxContainer.new()
		options.add_theme_constant_override("separation", 10)
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		options = grid
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tile := Vector2((column_width - 10.0) / 2.0, clampf((column_width - 10.0) / 2.0 * 0.66, 100.0, 210.0))
	for i in turn.options.size():
		var slug: String = turn.options[i]
		var button: Button
		if quiz_mode == "name":
			var number := "" if _is_mobile() else "%d.  " % (i + 1)
			button = _button("opt%d" % i, number + _name(slug, quiz_type), _answer.bind(slug), "", "")
			button.custom_minimum_size.y = 56
		else:
			button = _button("opt%d" % i, "", _answer.bind(slug), "", "")
			button.custom_minimum_size = tile
			var view_node := _flag_view(slug, quiz_type, tile - Vector2(24, 24))
			view_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			button.add_child(view_node)
		if answered:
			button.focus_mode = Control.FOCUS_NONE
			button.disabled = true
			if slug == turn.flag:
				_tint(button, GREEN)
			elif slug == turn.picked:
				_tint(button, RED)
			elif quiz_mode == "name":
				button.modulate.a = 0.5  # (fading a flag would change its colors)
		options.add_child(button)
	page.add_child(options)

	var feedback := _label(" ", "Strong")
	feedback.custom_minimum_size.y = 50
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if answered:
		if turn.picked == turn.flag:
			feedback.text = tr("correct")
			feedback.add_theme_color_override("font_color", GREEN)
		else:
			var key := "wrong_name" if quiz_mode == "name" else "wrong_flag"
			feedback.text = tr(key) % _name(turn.flag, quiz_type)
			feedback.add_theme_color_override("font_color", RED)
	page.add_child(feedback)

	var last := round_index + 1 >= rounds.size()
	var next := _button("next", tr("see_result") if last else tr("next"), _next, "Primary", "")
	next.custom_minimum_size.y = 58
	if not answered:
		# Keeps its place so nothing jumps when it appears.
		next.modulate.a = 0.0
		next.focus_mode = Control.FOCUS_NONE
		next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(next)
	default_focus = "next" if answered else "opt0"


func _tint(button: Button, color: Color) -> void:
	var style := _box(color.lerp(PAPER, 0.75), color, 3)
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_stylebox_override("normal", style)


func _progress_dots() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for i in rounds.size():
		var color := TAN_DARK
		if i < round_index or (i == round_index and answered):
			color = GREEN if rounds[i].picked == rounds[i].flag else RED
		elif i == round_index:
			color = GOLD
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(26, 8)
		dot.add_theme_stylebox_override("panel", _box(color, color, 0, 4, Vector2.ZERO))
		row.add_child(dot)
	return row


func _build_result() -> void:
	var total := rounds.size()
	var pass_ok := _passed()
	page.add_child(_label(tr("scored") % [score, total], "Title"))
	var verdict := _label(tr("passed") if pass_ok else tr("failed"), "Heading")
	verdict.add_theme_font_size_override("font_size", 28)
	verdict.add_theme_color_override("font_color", GREEN if pass_ok else RED)
	page.add_child(verdict)
	page.add_child(_label(_quiz_label(quiz_type, quiz_mode, quiz_difficulty), "Muted"))
	page.add_child(_label(tr("pass_note") % _pass_mark(total), "Muted"))
	var row := _row()
	row.add_child(_button("again", tr("play_again"), _start_game, "Primary", ""))
	row.add_child(_button("menu", tr("menu"), _show.bind("menu", "type_" + quiz_type)))
	page.add_child(row)

	page.add_child(_label(tr("your_answers"), "Heading"))
	for turn: Dictionary in rounds:
		var right: bool = turn.picked == turn.flag
		var panel := PanelContainer.new()
		var style := _box(PAPER, TAN_DARK, 1, 10, Vector2(12, 8))
		style.border_width_left = 8
		style.border_color = GREEN if right else RED
		panel.add_theme_stylebox_override("panel", style)
		var line := _row(14)
		line.add_child(_flag_view(turn.flag, quiz_type, Vector2(96, 60)))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_child(_label(_name(turn.flag, quiz_type), "Strong", HORIZONTAL_ALIGNMENT_LEFT))
		if not right:
			var picked := _label(tr("you_picked") % _name(turn.picked, quiz_type), "Muted", HORIZONTAL_ALIGNMENT_LEFT)
			picked.add_theme_color_override("font_color", RED)
			texts.add_child(picked)
		line.add_child(texts)
		panel.add_child(line)
		page.add_child(panel)
	var bottom := _row()
	bottom.add_child(_button("again2", tr("play_again"), _start_game, "Primary", ""))
	bottom.add_child(_button("menu2", tr("menu"), _show.bind("menu", "type_" + quiz_type)))
	page.add_child(bottom)
	default_focus = "again"


func _build_help() -> void:
	page.add_child(_label(tr("how_to_play"), "Title"))
	page.add_child(_label(tr("help_intro") % [OPTIONS, ROUNDS], "", HORIZONTAL_ALIGNMENT_LEFT))
	var sections := [
		["game_types", [tr("type_old") + ": " + tr("type_old_detail"), tr("type_classic") + ": " + tr("type_classic_detail")]],
		["modes", [tr("mode_name") + ": " + tr("mode_name_detail"), tr("mode_flag") + ": " + tr("mode_flag_detail")]],
		["difficulty", [tr("help_difficulty")]],
		["controls", [tr("help_touch"), tr("help_keyboard"), tr("help_pad")]],
	]
	for section: Array in sections:
		var card := _card()
		card.add_child(_label(tr(section[0]), "Heading", HORIZONTAL_ALIGNMENT_LEFT))
		for text: String in section[1]:
			card.add_child(_label(text, "", HORIZONTAL_ALIGNMENT_LEFT))
	default_focus = "tab_home"


func _build_stats() -> void:
	page.add_child(_label(tr("stats"), "Title"))
	if results.is_empty():
		page.add_child(_label(tr("no_games")))
		default_focus = "tab_stats"
		return
	var all := _bucket(func(_r: Dictionary) -> bool: return true)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var tiles := [
		["games_played", str(all.games)],
		["average_score", "%.1f" % all.average],
		["best_score", str(all.best)],
		["pass_rate", "%d%%" % roundi(all.pass_rate * 100.0)],
	]
	for tile: Array in tiles:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		var value := _label(tile[1], "Title")
		value.add_theme_font_size_override("font_size", 34)
		box.add_child(value)
		box.add_child(_label(tr(tile[0]), "Muted"))
		panel.add_child(box)
		grid.add_child(panel)
	page.add_child(grid)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 14
	bar.value = all.pass_rate * 100.0
	page.add_child(bar)

	var groups := [
		["by_game", "type", TYPES.map(func(v: String) -> Array: return [v, "type_" + v])],
		["by_mode", "mode", MODES.map(func(v: String) -> Array: return [v, "mode_" + v])],
		["by_difficulty", "difficulty", DIFFICULTIES.map(func(v: String) -> Array: return [v, "diff_" + v])],
	]
	for group: Array in groups:
		var card := _card()
		card.add_child(_label(tr(group[0]), "Heading", HORIZONTAL_ALIGNMENT_LEFT))
		for entry: Array in group[2]:
			var field: String = group[1]
			var bucket := _bucket(func(r: Dictionary) -> bool:
				return r.get(field) == entry[0] and (field != "difficulty" or r.get("type") == "old"))
			var line := _row()
			line.add_child(_label(tr(entry[1]), "Strong", HORIZONTAL_ALIGNMENT_LEFT))
			var best: String = "—" if bucket.games == 0 else str(bucket.best)
			line.add_child(_label(tr("bucket") % [bucket.games, "%.1f" % bucket.average, best], "Muted", HORIZONTAL_ALIGNMENT_RIGHT))
			card.add_child(line)

	var recent := _card()
	recent.add_child(_label(tr("recent"), "Heading", HORIZONTAL_ALIGNMENT_LEFT))
	var shown := results.slice(maxi(0, results.size() - RECENT))
	shown.reverse()
	for result: Dictionary in shown:
		var line := _row()
		line.add_child(_label(_quiz_label(result.type, result.mode, result.difficulty), "", HORIZONTAL_ALIGNMENT_LEFT))
		var ok: bool = result.score >= _pass_mark(result.total)
		var score_label := _label("%d/%d · %s" % [result.score, result.total, tr("passed") if ok else tr("failed")], "Strong", HORIZONTAL_ALIGNMENT_RIGHT)
		score_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		score_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		score_label.add_theme_color_override("font_color", GREEN if ok else RED)
		line.add_child(score_label)
		recent.add_child(line)

	var clear_pressed := func() -> void:
		if clear_armed:
			results.clear()
			_save()
		clear_armed = not clear_armed
		_rebuild("tab_stats" if results.is_empty() else "clear")
	var clear := _button("clear", tr("confirm_clear") if clear_armed else tr("clear_stats"), clear_pressed, "Small")
	if clear_armed:
		clear.add_theme_color_override("font_color", RED)
		clear.add_theme_color_override("font_focus_color", RED)
		clear.add_theme_color_override("font_hover_color", RED)
	page.add_child(clear)
	default_focus = "clear"


## Games, average, best and pass rate of the results that match `filter`.
func _bucket(filter: Callable) -> Dictionary:
	var games := 0
	var total := 0
	var best := 0
	var passes := 0
	for result: Dictionary in results:
		if not filter.call(result):
			continue
		games += 1
		total += result.score
		best = maxi(best, result.score)
		if result.score >= _pass_mark(result.total):
			passes += 1
	return {"games": games, "average": float(total) / maxi(games, 1), "best": best,
			"pass_rate": float(passes) / maxi(games, 1)}


func _build_settings() -> void:
	page.add_child(_label(tr("settings"), "Title"))
	var card := _card()
	card.add_child(_label(tr("language"), "Heading", HORIZONTAL_ALIGNMENT_LEFT))
	var row := _row()
	var pick_language := func(code: String) -> void:
		language = code
		_apply_settings()
		_save()
		_rebuild()
	for entry: Array in StringsScript.LANGUAGES:
		var button := _button("lang_" + entry[0], entry[1], pick_language.bind(entry[0]), "Choice")
		button.toggle_mode = true
		button.set_pressed_no_signal(entry[0] == language)
		row.add_child(button)
	card.add_child(row)
	card.add_child(_label(tr("sound"), "Heading", HORIZONTAL_ALIGNMENT_LEFT))
	_on_off(card, "sound_", sound_on, func(value: bool) -> void:
		sound_on = value
		_apply_settings()
		_save()
		_rebuild())
	card.add_child(_label(tr("vibration"), "Heading", HORIZONTAL_ALIGNMENT_LEFT))
	_on_off(card, "vibration_", vibration_on, func(value: bool) -> void:
		vibration_on = value
		_save()
		if value:
			_buzz()
		_rebuild())

	var about := _card()
	about.add_child(_label(tr("about"), "Heading", HORIZONTAL_ALIGNMENT_LEFT))
	about.add_child(_label(tr("about_text"), "", HORIZONTAL_ALIGNMENT_LEFT))
	about.add_child(_label(tr("developed_by"), "Muted", HORIZONTAL_ALIGNMENT_LEFT))
	default_focus = "lang_" + language


func _on_off(parent: Control, prefix: String, current: bool, callback: Callable) -> void:
	var row := _row()
	for value in [true, false]:
		var button := _button(prefix + ("on" if value else "off"), tr("on" if value else "off"), callback.bind(value), "Choice")
		button.toggle_mode = true
		button.set_pressed_no_signal(value == current)
		row.add_child(button)
	parent.add_child(row)


# --- Saving --------------------------------------------------------------------------------

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "language", language)
	config.set_value("settings", "sound", sound_on)
	config.set_value("settings", "vibration", vibration_on)
	config.set_value("choice", "type", game_type)
	config.set_value("choice", "mode", mode)
	config.set_value("choice", "difficulty", difficulty)
	config.set_value("stats", "results", results)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	language = config.get_value("settings", "language", "")
	sound_on = config.get_value("settings", "sound", true)
	vibration_on = config.get_value("settings", "vibration", true)
	var saved_type: String = config.get_value("choice", "type", "old")
	var saved_mode: String = config.get_value("choice", "mode", "name")
	var saved_difficulty: String = config.get_value("choice", "difficulty", "all")
	game_type = saved_type if saved_type in TYPES else "old"
	mode = saved_mode if saved_mode in MODES else "name"
	difficulty = saved_difficulty if saved_difficulty in DIFFICULTIES else "all"
	for result in config.get_value("stats", "results", []):
		if result is Dictionary and result.get("type") in TYPES and result.get("mode") in MODES \
				and result.get("difficulty") in DIFFICULTIES and result.has("score") and result.has("total"):
			results.append(result)


## A bottom-bar icon drawn in code (Material Design shapes, on a 24 x 24 grid).
class TabIcon extends Control:
	var kind := "home"
	var color := Color.WHITE
	var hole := Color.BLACK  # gear hole, in the bar's color

	func _draw() -> void:
		var k := size.x / 24.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		match kind:
			"home":
				draw_colored_polygon(PackedVector2Array([Vector2(10, 20), Vector2(10, 14), Vector2(14, 14),
						Vector2(14, 20), Vector2(19, 20), Vector2(19, 12), Vector2(22, 12), Vector2(12, 3),
						Vector2(2, 12), Vector2(5, 12), Vector2(5, 20)]), color)
			"play":
				draw_colored_polygon(PackedVector2Array([Vector2(8, 5), Vector2(8, 19), Vector2(19, 12)]), color)
			"stats":
				draw_rect(Rect2(4.5, 10, 3.5, 9.5), color)
				draw_rect(Rect2(10.25, 4.5, 3.5, 15), color)
				draw_rect(Rect2(16, 13, 3.5, 6.5), color)
			"settings":
				var center := Vector2(12, 12)
				for i in 8:
					var angle := i * TAU / 8.0
					var along := Vector2.from_angle(angle)
					var across := along.orthogonal() * 1.9
					draw_colored_polygon(PackedVector2Array([center + along * 6.0 - across, center + along * 10.5 - across,
							center + along * 10.5 + across, center + along * 6.0 + across]), color)
				draw_circle(center, 7.6, color)
				draw_circle(center, 3.2, hole)
