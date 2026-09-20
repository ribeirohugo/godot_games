extends Node2D
## Bus Park: a "car jam" puzzle. Parked cars and vans block your bus in; drag them out of the
## way (each only slides along its own length) until the bus can slide out through the gap.

const Generator := preload("res://scripts/generator.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const CELL := 58.0
const BOARD_TOP := 190.0
const GAP_DEPTH := 46.0  # how far the exit lane extends past the boundary, for the "drive away"
const SAVE_PATH := "user://save.cfg"
const DIFF_NAMES := ["Fácil", "Médio", "Difícil"]
# Which side of the board each exit_side opens onto, and the outward direction.
const EXIT_DIR := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const ASPHALT := Color(0.24, 0.25, 0.28)
const ASPHALT_LINE := Color(1, 1, 1, 0.08)
const CURB := Color(0.82, 0.8, 0.74)
const CURB_DARK := Color(0.6, 0.58, 0.53)
const EXIT_COLOR := Color(0.35, 0.78, 0.42)

var size := 6
var exit_side := 0
var vehicles: Array = []
var grid: Array = []
var moves := 0
var puzzle_num := 1
var difficulty_kind := 0
var best := {}  # difficulty -> fewest moves to solve
var phase := "title"  # title, play, won
var history: Array = []  # {"idx","delta"} per completed drag gesture, for undo
var initial_state: Array = []  # deep copy of `vehicles` at the start of the current puzzle

var drag_idx := -1
var drag_start_mouse := Vector2.ZERO
var drag_delta := 0
var sfx: Node

var board_pos := Vector2.ZERO
var moves_label: Label
var puzzle_label: Label
var diff_label: Label
var best_label: Label
var hint_label: Label
var undo_button: Button
var overlay: Control
var overlay_action := Callable()
var overlay_kind := ""
var overlay_box: Control
var overlay_title: Label
var overlay_body: Label
var overlay_button: Button
var difficulty_picker: HBoxContainer
var game_bar: Control
var home_button: Button


func _ready() -> void:
	randomize()
	sfx = SfxScript.new()
	add_child(sfx)
	_load_save()
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_title()


func _layout() -> void:
	var view := get_viewport_rect().size
	board_pos = Vector2((view.x - size * CELL) * 0.5, BOARD_TOP)
	queue_redraw()


# --- Puzzle lifecycle -----------------------------------------------------------------

func _new_puzzle() -> void:
	var built := Generator.generate(difficulty_kind)
	size = built.size
	exit_side = built.exit_side
	vehicles = built.vehicles
	grid = Generator.build_grid(vehicles, size)
	initial_state = _clone_vehicles()
	history.clear()
	moves = 0
	phase = "play"
	drag_idx = -1
	_layout()
	_update_hud()


func _clone_vehicles() -> Array:
	var out := []
	for v in vehicles:
		out.append(v.duplicate())
	return out


func _restart_puzzle() -> void:
	sfx.play("click")
	vehicles = _clone_vehicles_from(initial_state)
	grid = Generator.build_grid(vehicles, size)
	history.clear()
	moves = 0
	phase = "play"
	drag_idx = -1
	queue_redraw()
	_update_hud()


func _clone_vehicles_from(source: Array) -> Array:
	var out := []
	for v in source:
		out.append(v.duplicate())
	return out


func _skip_puzzle() -> void:
	sfx.play("click")
	puzzle_num += 1
	_new_puzzle()


func _undo() -> void:
	if history.is_empty() or phase != "play":
		return
	sfx.play("click")
	var move: Dictionary = history.pop_back()
	var step: int = -1 if move.delta > 0 else 1
	for i in absi(move.delta):
		Generator.slide(grid, size, vehicles, move.idx, step, true)
	moves = maxi(moves - 1, 0)
	queue_redraw()
	_update_hud()


# --- Input -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if phase != "play":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventMouseMotion and drag_idx >= 0:
		_update_drag(event.position)


func _start_drag(mouse: Vector2) -> void:
	var local := (mouse - board_pos) / CELL
	var col := int(floor(local.x))
	var row := int(floor(local.y))
	if row < 0 or row >= size or col < 0 or col >= size:
		return
	var idx: int = grid[row][col]
	if idx < 0:
		return
	drag_idx = idx
	drag_start_mouse = mouse
	drag_delta = 0


func _update_drag(mouse: Vector2) -> void:
	var v: Dictionary = vehicles[drag_idx]
	var d := mouse - drag_start_mouse
	var wanted := int(round((d.x if v.horizontal else d.y) / CELL))
	var blocked := false
	while wanted > drag_delta:
		if Generator.slide(grid, size, vehicles, drag_idx, 1, true):
			drag_delta += 1
			sfx.play("slide")
		else:
			blocked = true
			break
	while wanted < drag_delta:
		if Generator.slide(grid, size, vehicles, drag_idx, -1, true):
			drag_delta -= 1
			sfx.play("slide")
		else:
			blocked = true
			break
	if blocked:
		sfx.play("bump")
	queue_redraw()
	if v.is_bus and _bus_exited():
		_win()


func _end_drag() -> void:
	if drag_idx >= 0 and drag_delta != 0 and phase == "play":
		history.append({"idx": drag_idx, "delta": drag_delta})
		moves += 1
		_update_hud()
	drag_idx = -1


func _bus_exited() -> bool:
	for v in vehicles:
		if not v.is_bus:
			continue
		for c in Generator.cells(v):
			if v.horizontal:
				if c.x >= 0 and c.x < size:
					return false
			else:
				if c.y >= 0 and c.y < size:
					return false
		return true
	return false


func _win() -> void:
	phase = "won"
	drag_idx = -1
	sfx.play("win")
	var key := str(difficulty_kind)
	var record: bool = not best.has(key) or moves < best[key]
	if record:
		best[key] = moves
	_save()
	_update_hud()
	await get_tree().create_timer(0.5).timeout
	_show_overlay("Conseguiste!",
		"A tua carrinha saiu do parque.\nJogadas: %d%s" % [moves, "\nNovo recorde!" if record else ""],
		"Próximo", func() -> void:
			puzzle_num += 1
			_new_puzzle(), false, "won")


# --- HUD ---------------------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	layer.add_child(root)

	var left := _panel(root)
	left.position = Vector2(14, 14)
	var left_box := VBoxContainer.new()
	left.add_child(left_box)
	left_box.add_child(_label("JOGADAS", 14, Color(0.85, 0.9, 0.95)))
	moves_label = _label("0", 30, Color(1, 0.85, 0.3))
	left_box.add_child(moves_label)
	best_label = _label("", 13, Color(0.8, 0.85, 0.9))
	left_box.add_child(best_label)

	var right := _panel(root)
	var right_box := VBoxContainer.new()
	right.add_child(right_box)
	right_box.add_child(_label("PUZZLE", 14, Color(0.85, 0.9, 0.95)))
	puzzle_label = _label("1", 30, Color.WHITE)
	right_box.add_child(puzzle_label)
	diff_label = _label(DIFF_NAMES[difficulty_kind], 13, Color(0.8, 0.85, 0.9))
	right_box.add_child(diff_label)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)

	hint_label = _label("", 15, Color(1, 1, 1, 0.9))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -34
	hint_label.offset_bottom = -10
	hint_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06))
	hint_label.add_theme_constant_override("outline_size", 5)
	root.add_child(hint_label)

	# In-game action bar: undo, restart, skip, menu.
	game_bar = HBoxContainer.new()
	game_bar.add_theme_constant_override("separation", 6)
	root.add_child(game_bar)
	undo_button = _soft_button("Desfazer", 100.0)
	undo_button.pressed.connect(_undo)
	game_bar.add_child(undo_button)
	var restart_button := _soft_button("Reiniciar", 110.0)
	restart_button.pressed.connect(_restart_puzzle)
	game_bar.add_child(restart_button)
	var skip_button := _soft_button("Novo", 90.0)
	skip_button.pressed.connect(_skip_puzzle)
	game_bar.add_child(skip_button)
	home_button = _soft_button("Menu", 90.0)
	home_button.pressed.connect(_go_to_menu)
	game_bar.add_child(home_button)
	game_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 90)
	game_bar.visible = false

	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.02, 0.03, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	overlay_box = _panel(center)
	overlay_box.custom_minimum_size = Vector2(380, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	overlay_box.add_child(vbox)
	overlay_title = _label("", 32, Color(1, 0.85, 0.3))
	vbox.add_child(overlay_title)
	overlay_body = _label("", 17, Color.WHITE)
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.custom_minimum_size = Vector2(380, 0)
	vbox.add_child(overlay_body)
	difficulty_picker = _build_difficulty_picker()
	vbox.add_child(difficulty_picker)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(200, 48)
	overlay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_button.pressed.connect(func() -> void:
		sfx.play("click")
		overlay.visible = false
		if overlay_action.is_valid():
			overlay_action.call())
	vbox.add_child(overlay_button)


func _show_title() -> void:
	_show_overlay("Bus Park",
		"A tua carrinha ficou presa no parque. Arrasta os outros carros — cada um só anda na sua direção — até abrires caminho até à saída.",
		"Jogar", func() -> void:
			puzzle_num = 1
			_new_puzzle(), true, "title")


func _show_overlay(title: String, body: String, button: String, action: Callable, picker: bool, kind: String) -> void:
	overlay_kind = kind
	overlay_title.text = title
	overlay_body.text = body
	overlay_button.text = button
	overlay_action = action
	difficulty_picker.visible = picker
	overlay.visible = true
	game_bar.visible = false
	overlay_button.grab_focus()


func _build_difficulty_picker() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for i in DIFF_NAMES.size():
		var button := Button.new()
		button.text = DIFF_NAMES[i]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == difficulty_kind
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(96, 40)
		button.pressed.connect(_choose_difficulty.bind(i))
		row.add_child(button)
	return row


func _choose_difficulty(kind: int) -> void:
	sfx.play("click")
	difficulty_kind = kind
	for i in difficulty_picker.get_child_count():
		var button: Button = difficulty_picker.get_child(i)
		button.set_pressed_no_signal(i == kind)
	_save()


func _go_to_menu() -> void:
	sfx.play("click")
	phase = "title"
	_show_title()


func _update_hud() -> void:
	if moves_label == null:
		return
	moves_label.text = str(moves)
	puzzle_label.text = str(puzzle_num)
	diff_label.text = DIFF_NAMES[difficulty_kind]
	var key := str(difficulty_kind)
	best_label.text = ("Recorde: %d" % best[key]) if best.has(key) else "Recorde: -"
	undo_button.disabled = history.is_empty()
	hint_label.text = "Arrasta a carrinha amarela até à saída." if phase == "play" else ""
	game_bar.visible = phase == "play"


func _soft_button(text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 34)
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		match state:
			"hover":
				style.bg_color = Color(1, 1, 1, 0.2)
			"pressed":
				style.bg_color = Color(1, 1, 1, 0.28)
			"disabled":
				style.bg_color = Color(1, 1, 1, 0.05)
			_:
				style.bg_color = Color(1, 1, 1, 0.12)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	button.add_theme_font_size_override("font_size", 14)
	return button


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.07, 0.1, 0.85)
	panel.set_corner_radius_all(14)
	panel.set_content_margin_all(14)
	panel.border_color = Color(1, 1, 1, 0.12)
	panel.set_border_width_all(2)
	theme.set_stylebox("panel", "PanelContainer", panel)
	var states := {
		"normal": Color(1.0, 0.78, 0.24),
		"hover": Color(1.0, 0.85, 0.4),
		"pressed": Color(0.9, 0.66, 0.12),
		"focus": Color(1.0, 0.78, 0.24),
	}
	for state in states:
		var style := StyleBoxFlat.new()
		style.bg_color = states[state]
		style.set_corner_radius_all(10)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		if state == "focus":
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(1, 1, 1, 0.6)
			style.set_border_width_all(2)
		theme.set_stylebox(state, "Button", style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "Button", Color(0.15, 0.1, 0.02))
	return theme


func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# --- Drawing -------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if phase == "play":
		queue_redraw()


func _draw() -> void:
	if vehicles.is_empty():
		return
	_draw_board()
	for i in vehicles.size():
		_draw_vehicle(vehicles[i], i == drag_idx)


func _draw_board() -> void:
	var origin := board_pos
	var total := Vector2(size, size) * CELL
	draw_rect(Rect2(origin, total), ASPHALT)
	for i in range(1, size):
		draw_line(origin + Vector2(i * CELL, 0), origin + Vector2(i * CELL, total.y), ASPHALT_LINE, 1.0)
		draw_line(origin + Vector2(0, i * CELL), origin + Vector2(total.x, i * CELL), ASPHALT_LINE, 1.0)

	var dir: Vector2i = EXIT_DIR[exit_side]
	var horizontal := exit_side == 0 or exit_side == 1
	var lane := 0
	for v in vehicles:
		if v.is_bus:
			lane = v.row if horizontal else v.col

	# Curb around all four sides, with a gap (and an arrow leading out) at the exit lane.
	const T := 8.0
	var sides := [
		[Vector2(0, 0), Vector2(total.x, 0), 3],  # top
		[Vector2(0, total.y), Vector2(total.x, total.y), 2],  # bottom
		[Vector2(0, 0), Vector2(0, total.y), 1],  # left
		[Vector2(total.x, 0), Vector2(total.x, total.y), 0],  # right
	]
	for side in sides:
		var a: Vector2 = origin + side[0]
		var b: Vector2 = origin + side[1]
		var side_id: int = side[2]
		if side_id == exit_side:
			var gap_a := origin + (Vector2(0, lane * CELL) if horizontal else Vector2(lane * CELL, 0))
			var along: Vector2 = (b - a).normalized()
			var before := gap_a - a
			var after := b - (gap_a + along * CELL)
			if before.length() > 1.0:
				draw_line(a, gap_a, CURB, T)
			if after.length() > 1.0:
				draw_line(gap_a + along * CELL, b, CURB, T)
		else:
			draw_line(a, b, CURB, T)
			draw_line(a, b, CURB_DARK, 2.0)

	# Exit lane + arrow, drawn outside the board on the exit side.
	var lane_center := origin + (Vector2(total.x if exit_side == 0 else 0.0, (lane + 0.5) * CELL) if horizontal
		else Vector2((lane + 0.5) * CELL, total.y if exit_side == 2 else 0.0))
	var out := Vector2(dir)
	var perp := Vector2(-out.y, out.x)
	var half := CELL * 0.5 - 3.0
	var far := lane_center + out * GAP_DEPTH
	draw_colored_polygon(PackedVector2Array([
		lane_center - perp * half, lane_center + perp * half, far + perp * half, far - perp * half]), EXIT_COLOR)
	var tip := far + out * 14.0
	draw_colored_polygon(PackedVector2Array([
		tip, tip - out * 16.0 + perp * 10.0, tip - out * 16.0 - perp * 10.0]), Color(1, 1, 1, 0.9))


func _draw_vehicle(v: Dictionary, dragging: bool) -> void:
	var rect := Rect2(
		board_pos + Vector2(v.col, v.row) * CELL + Vector2(4, 4),
		Vector2(v.len * CELL if v.horizontal else CELL, CELL if v.horizontal else v.len * CELL) - Vector2(8, 8))

	var body := StyleBoxFlat.new()
	body.bg_color = v.color
	body.set_corner_radius_all(int(CELL * 0.28))
	body.border_color = Color(v.color).darkened(0.45)
	body.set_border_width_all(3)
	body.shadow_color = Color(0, 0, 0, 0.35 if dragging else 0.22)
	body.shadow_size = 8 if dragging else 4
	body.anti_aliasing = true
	draw_style_box(body, rect)

	# Window band, across the vehicle's length.
	var inset := CELL * 0.16
	var window := StyleBoxFlat.new()
	window.bg_color = Color(0.72, 0.86, 0.95, 0.9) if not v.is_bus else Color(0.35, 0.38, 0.42, 0.95)
	window.set_corner_radius_all(int(CELL * 0.12))
	if v.horizontal:
		draw_style_box(window, Rect2(rect.position + Vector2(inset, inset), Vector2(rect.size.x - inset * 2, rect.size.y * 0.42)))
	else:
		draw_style_box(window, Rect2(rect.position + Vector2(inset, inset), Vector2(rect.size.x * 0.42, rect.size.y - inset * 2)))

	if v.is_bus:
		var stripe := Color(0.15, 0.13, 0.05, 0.85)
		if v.horizontal:
			draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.62), Vector2(rect.size.x, 4)), stripe)
		else:
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.62, 0), Vector2(4, rect.size.y)), stripe)

	# Wheels along the long sides.
	var wheel := Color(0.08, 0.08, 0.09)
	var wr := CELL * 0.11
	if v.horizontal:
		for i in v.len:
			var cx: float = rect.position.x + (i + 0.5) * CELL - 4
			draw_circle(Vector2(cx, rect.position.y - 1), wr, wheel)
			draw_circle(Vector2(cx, rect.position.y + rect.size.y + 1), wr, wheel)
	else:
		for i in v.len:
			var cy: float = rect.position.y + (i + 0.5) * CELL - 4
			draw_circle(Vector2(rect.position.x - 1, cy), wr, wheel)
			draw_circle(Vector2(rect.position.x + rect.size.x + 1, cy), wr, wheel)


# --- Saved data -------------------------------------------------------------------------

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		difficulty_kind = clampi(cfg.get_value("settings", "difficulty", 0), 0, DIFF_NAMES.size() - 1)
		var raw: Dictionary = cfg.get_value("score", "best", {})
		for key in raw:
			best[str(key)] = int(raw[key])


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "difficulty", difficulty_kind)
	cfg.set_value("score", "best", best)
	cfg.save(SAVE_PATH)
