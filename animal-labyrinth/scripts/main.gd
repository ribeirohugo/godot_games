extends Node2D
## Animal Labyrinth: place tiles on a 4x4 island grid, then the chosen animal walks on its own,
## always keeping to its left, and has to reach its food.

const Art := preload("res://scripts/art.gd")
const Tiles := preload("res://scripts/tiles.gd")
const BoardViewScript := preload("res://scripts/board_view.gd")
const AnimalScript := preload("res://scripts/animal.gd")
const TilePreviewScript := preload("res://scripts/tile_preview.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const START_CELL := Vector2i(-1, 1)  # start block left of the top-left slot's middle row
const STEP_TIME := 0.16
const START_DELAY := 0.5
const MAX_STEPS := 2000  # safety net; the wall-follower always ends at the goal or back at the start
const ROUND_BONUS := 50
const SAVE_PATH := "user://save.cfg"

# Same order as the animal kinds in animal.gd and the goal food in art.gd.
const ANIMALS := [
	{"name": "Macaco", "who": "o macaco", "food": "às bananas", "win": "Bananas!"},
	{"name": "Cavalo", "who": "o cavalo", "food": "às cenouras", "win": "Cenouras!"},
	{"name": "Gato", "who": "o gato", "food": "ao peixe", "win": "Peixe!"},
	{"name": "Cão", "who": "o cão", "food": "ao osso", "win": "Osso!"},
]

# Each difficulty deals from its own subset of tiles.gd's pieces (Tiles.POOLS): Fácil keeps to
# simple straights, bends and dead ends with more of them per round; Difícil adds the zigzags
# and the stepping-stone trap tile, with fewer tiles and a longer path to the goal.
const DIFFICULTIES := [
	{"name": "Fácil", "tiles_per_round": 10, "goal_start": 3, "goal_cap": 5},
	{"name": "Médio", "tiles_per_round": 8, "goal_start": 3, "goal_cap": 7},
	{"name": "Difícil", "tiles_per_round": 6, "goal_start": 4, "goal_cap": 7},
]

# Land cells just outside the grid that connect to the goal island, grouped by how many
# tiles a shortest path needs. The island itself lies one cell further out.
const GOALS := {
	4: [Vector2i(1, 12), Vector2i(12, 1)],
	5: [Vector2i(4, 12), Vector2i(12, 4)],
	6: [Vector2i(7, 12), Vector2i(12, 7)],
	7: [Vector2i(10, 12), Vector2i(12, 10)],
}

var board_view: Node2D
var animal: Node2D
var sfx: Node

var board := []  # 16 slots, tile number or 0 when empty
var land := {}  # Vector2i -> true for every walkable cell
var deck := []
var current_tile := 0
var tiles_left := 0
var phase := "title"  # title, build, walk, won, lost
var hover_slot := -1
var goal_cell := Vector2i(12, 1)  # connector block next to the grid
var island_cell := Vector2i(13, 1)  # where the food is; reaching it wins
var scored_slots := {}
var score := 0
var high_score := 0
var round_num := 1
var animal_kind := 0
var difficulty_kind := 1
var round_token := 0  # bumped every round so a walk left over from an old round stops

var score_label: Label
var round_label: Label
var best_label: Label
var tiles_label: Label
var points_label: Label
var preview: Control
var hint_label: Label
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var overlay_button: Button
var animal_picker: HBoxContainer
var difficulty_picker: HBoxContainer
var overlay_action := Callable()


func _ready() -> void:
	randomize()
	_load_save()

	board_view = BoardViewScript.new()
	board_view.main = self
	add_child(board_view)

	animal = AnimalScript.new()
	animal.kind = animal_kind
	animal.z_index = 5
	board_view.add_child(animal)

	sfx = SfxScript.new()
	add_child(sfx)

	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()

	board.resize(16)
	_reset_round()
	_show_title()


func _process(_delta: float) -> void:
	hover_slot = -1
	if phase == "build":
		var slot := slot_of(Art.cell_at(board_view.get_local_mouse_position()))
		if slot >= 0 and board[slot] == 0:
			hover_slot = slot


func _unhandled_input(event: InputEvent) -> void:
	if phase != "build":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var slot := slot_of(Art.cell_at(board_view.get_local_mouse_position()))
		if slot >= 0 and board[slot] == 0:
			_place(slot)


# --- Grid helpers -------------------------------------------------------------

func slot_of(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x > 11 or cell.y < 0 or cell.y > 11:
		return -1
	return (cell.y / 3) * 4 + cell.x / 3


## Uses `connector` as the goal connector and puts the island one cell further from the grid.
func _set_goal(connector: Vector2i) -> void:
	goal_cell = connector
	island_cell = connector + (Vector2i(0, 1) if connector.y > 11 else Vector2i(1, 0))
	land = {START_CELL: true, goal_cell: true, island_cell: true}


func slot_cell(slot: int) -> Vector2i:
	return Vector2i((slot % 4) * 3, (slot / 4) * 3)


# --- Rounds -------------------------------------------------------------------

func _start_game() -> void:
	overlay.visible = false
	score = 0
	round_num = 1
	_reset_round()
	phase = "build"
	_update_hud()


func _next_round() -> void:
	overlay.visible = false
	round_num += 1
	_reset_round()
	phase = "build"
	_update_hud()


func _reset_round() -> void:
	round_token += 1
	board.fill(0)
	scored_slots.clear()
	board_view.clear_drops()

	var difficulty: Dictionary = DIFFICULTIES[difficulty_kind]
	var options: Array = GOALS[mini(difficulty.goal_start + round_num, difficulty.goal_cap)]
	_set_goal(options[randi() % options.size()])

	deck = Tiles.pool(difficulty_kind)
	deck.shuffle()
	tiles_left = difficulty.tiles_per_round
	current_tile = deck.pop_back()

	animal.reset(Art.cell_pos(Vector2(START_CELL)), 0)
	_update_hud()


func _place(slot: int) -> void:
	board[slot] = current_tile
	var origin := slot_cell(slot)
	for y in 3:
		for x in 3:
			var cell := origin + Vector2i(x, y)
			if Tiles.is_land(current_tile, x, y):
				land[cell] = true
			else:
				land.erase(cell)
	board_view.mark_dropped(slot)
	sfx.play("place")

	tiles_left -= 1
	if tiles_left > 0:
		current_tile = deck.pop_back()
		_update_hud()
	else:
		current_tile = 0
		phase = "walk"
		_update_hud()
		_walk()


# --- The walk -----------------------------------------------------------------

func _walk() -> void:
	var token := round_token
	var pos := START_CELL
	var dir := 0
	await get_tree().create_timer(START_DELAY).timeout
	if token != round_token:
		return

	for _step in MAX_STEPS:
		# Left-hand rule: try turning left, then straight on, then right, then turning back.
		var next_dir := -1
		for turn in [3, 0, 1, 2]:
			var d: int = (dir + turn) % 4
			if land.has(pos + Art.DIRS[d]):
				next_dir = d
				break

		if next_dir < 0:
			# Only happens on the start block when the first cell is water.
			sfx.play("jump")
			await animal.fall_to(Art.cell_pos(Vector2(pos + Art.DIRS[dir])), STEP_TIME * 1.5)
			if token != round_token:
				return
			sfx.play("splash")
			await get_tree().create_timer(0.8).timeout
			if token == round_token:
				_lose("Splash!", "%s saltou para a água: não havia terra à frente." % _who(true))
			return

		dir = next_dir
		pos += Art.DIRS[dir]
		await animal.step_to(Art.cell_pos(Vector2(pos)), dir, STEP_TIME)
		if token != round_token:
			return
		sfx.play("step")
		_score_cell(pos)

		if pos == island_cell:
			_win()
			return
		if pos == START_CELL:
			_lose("Sem saída!", "%s não encontrou caminho até %s e voltou ao início." % [_who(true), ANIMALS[animal_kind].food])
			return

	_lose("Perdido!", "%s andou às voltas sem chegar %s." % [_who(true), ANIMALS[animal_kind].food])


func _score_cell(cell: Vector2i) -> void:
	var slot := slot_of(cell)
	if slot < 0 or scored_slots.has(slot):
		return
	scored_slots[slot] = true
	var points := Tiles.points(board[slot])
	score += points
	sfx.play("points")
	_float_text("+%d" % points, animal.position, Color(1, 0.95, 0.5))
	_update_hud()


func _win() -> void:
	phase = "won"
	var token := round_token
	var bonus := ROUND_BONUS * round_num
	score += bonus
	sfx.play("win")
	animal.cheer()
	_float_text("BÓNUS +%d" % bonus, animal.position + Vector2(0, -24), Color(0.6, 1, 0.5))
	_save()
	_update_hud()
	await get_tree().create_timer(1.6).timeout
	if token != round_token:
		return
	_show_overlay(ANIMALS[animal_kind].win,
		"%s chegou à ilha.\nBónus da ronda: +%d\nPontuação: %d" % [_who(true), bonus, score],
		"Ronda %d" % (round_num + 1), _next_round)


func _lose(title: String, reason: String) -> void:
	phase = "lost"
	sfx.play("lose")
	var record := score > high_score
	_save()
	_update_hud()
	var body := "%s\n\nPontuação final: %d" % [reason, score]
	if record and score > 0:
		body += "\nNovo recorde!"
	_show_overlay(title, body, "Jogar outra vez", _start_game, true)


func _float_text(text: String, at: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 30)
	label.position = at + Vector2(-80, -80)
	label.z_index = 10
	board_view.add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 40.0, 0.9)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.tween_callback(label.queue_free)


# --- HUD ----------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	layer.add_child(root)

	# Next tile, top left.
	var left := _panel(root)
	left.position = Vector2(14, 14)
	var left_box := VBoxContainer.new()
	left_box.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(left_box)
	left_box.add_child(_label("PRÓXIMA PEÇA", 14, Color(0.75, 0.88, 1.0)))
	preview = TilePreviewScript.new()
	preview.custom_minimum_size = Vector2(150, 96)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_box.add_child(preview)
	points_label = _label("", 20, Color(1, 0.9, 0.4))
	left_box.add_child(points_label)
	tiles_label = _label("", 16, Color.WHITE)
	left_box.add_child(tiles_label)

	# Score, top right.
	var right := _panel(root)
	right.custom_minimum_size = Vector2(150, 0)
	var right_box := VBoxContainer.new()
	right.add_child(right_box)
	right_box.add_child(_label("PONTUAÇÃO", 14, Color(0.75, 0.88, 1.0)))
	score_label = _label("0", 34, Color(1, 0.9, 0.4))
	right_box.add_child(score_label)
	round_label = _label("", 16, Color.WHITE)
	right_box.add_child(round_label)
	best_label = _label("", 14, Color(0.75, 0.88, 1.0))
	right_box.add_child(best_label)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)

	hint_label = _label("", 15, Color(1, 1, 1, 0.9))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -36
	hint_label.offset_bottom = -12
	hint_label.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.35))
	hint_label.add_theme_constant_override("outline_size", 5)
	root.add_child(hint_label)

	# Message box for the title, win and game-over screens.
	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.08, 0.15, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := _panel(center)
	box.custom_minimum_size = Vector2(380, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	box.add_child(vbox)
	overlay_title = _label("", 34, Color(1, 0.9, 0.4))
	vbox.add_child(overlay_title)
	overlay_body = _label("", 17, Color.WHITE)
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.custom_minimum_size = Vector2(380, 0)
	vbox.add_child(overlay_body)
	animal_picker = _build_animal_picker()
	vbox.add_child(animal_picker)
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
	_show_overlay("Animal Labyrinth",
		"Escolhe um animal e uma dificuldade, e coloca as peças no mar para lhe fazer um caminho até %s.\n" % ANIMALS[animal_kind].food
		+ "Depois ele anda sozinho e vira sempre para a esquerda quando pode.",
		"Jogar", _start_game, true)


func _build_animal_picker() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for i in ANIMALS.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == animal_kind
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(90, 100)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style := StyleBoxFlat.new()
			style.set_corner_radius_all(10)
			match state:
				"normal":
					style.bg_color = Color(1, 1, 1, 0.08)
				"hover":
					style.bg_color = Color(1, 1, 1, 0.18)
				_:
					style.bg_color = Color(1.0, 0.76, 0.2, 0.35)
					style.border_color = Color(1.0, 0.8, 0.3)
					style.set_border_width_all(3)
			button.add_theme_stylebox_override(state, style)

		var look := AnimalScript.new()
		look.kind = i
		look.position = Vector2(45, 70)
		look.walking = i == animal_kind
		button.add_child(look)
		var name_label := _label(ANIMALS[i].name, 15, Color.WHITE)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		name_label.offset_top = -26
		name_label.offset_bottom = -4
		button.add_child(name_label)

		button.pressed.connect(_choose_animal.bind(i))
		row.add_child(button)
	return row


func _choose_animal(kind: int) -> void:
	sfx.play("click")
	animal_kind = kind
	animal.kind = kind
	for i in animal_picker.get_child_count():
		var button: Button = animal_picker.get_child(i)
		button.set_pressed_no_signal(i == kind)
		var look: Node2D = button.get_child(0)
		look.walking = i == kind
	_save()
	if phase == "title":
		_show_title()
	_update_hud()


func _build_difficulty_picker() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for i in DIFFICULTIES.size():
		var button := Button.new()
		button.text = DIFFICULTIES[i].name
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == difficulty_kind
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(90, 36)
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


## "o gato", or "O gato" at the start of a sentence.
func _who(capital := false) -> String:
	var who: String = ANIMALS[animal_kind].who
	return who.left(1).to_upper() + who.substr(1) if capital else who


func _show_overlay(title: String, body: String, button: String, action: Callable, picker := false) -> void:
	animal_picker.visible = picker
	difficulty_picker.visible = picker
	overlay_title.text = title
	overlay_body.text = body
	overlay_button.text = button
	overlay_action = action
	overlay.visible = true
	overlay_button.grab_focus()


func _update_hud() -> void:
	if score_label == null:
		return
	preview.tile = current_tile
	points_label.text = "+%d pontos" % Tiles.points(current_tile) if current_tile > 0 else " "
	tiles_label.text = "Peças: %d" % tiles_left
	score_label.text = str(score)
	round_label.text = "Ronda %d · %s" % [round_num, DIFFICULTIES[difficulty_kind].name]
	best_label.text = "Recorde: %d" % maxi(high_score, score)
	match phase:
		"build":
			hint_label.text = "Clica num espaço para pôr a peça. Faltam %d." % tiles_left
		"walk":
			hint_label.text = "%s vira sempre para a esquerda quando pode..." % _who(true)
		_:
			hint_label.text = ""


func _layout() -> void:
	var view := get_viewport_rect().size
	board_view.position = Vector2(view.x * 0.5, 140.0 + maxf(view.y - 600.0, 0.0) * 0.5)


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.05, 0.14, 0.26, 0.82)
	panel.set_corner_radius_all(14)
	panel.set_content_margin_all(14)
	panel.border_color = Color(1, 1, 1, 0.12)
	panel.set_border_width_all(2)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var states := {
		"normal": Color(1.0, 0.76, 0.2),
		"hover": Color(1.0, 0.84, 0.35),
		"pressed": Color(0.9, 0.62, 0.1),
		"focus": Color(1.0, 0.76, 0.2),
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
		theme.set_color(color_name, "Button", Color(0.25, 0.14, 0.02))
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


# --- Saved data -----------------------------------------------------------------

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = cfg.get_value("score", "best", 0)
		animal_kind = clampi(cfg.get_value("settings", "animal", 0), 0, ANIMALS.size() - 1)
		difficulty_kind = clampi(cfg.get_value("settings", "difficulty", 1), 0, DIFFICULTIES.size() - 1)


## Stores the best score, the chosen animal and the chosen difficulty.
func _save() -> void:
	high_score = maxi(high_score, score)
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", high_score)
	cfg.set_value("settings", "animal", animal_kind)
	cfg.set_value("settings", "difficulty", difficulty_kind)
	cfg.save(SAVE_PATH)
