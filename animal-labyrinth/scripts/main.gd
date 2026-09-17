extends Node2D
## Animal Labyrinth: place tiles on a 4x4 island grid, then the chosen animal walks on its own,
## always keeping to its left, and has to reach its food.

const Art := preload("res://scripts/art.gd")
const Tiles := preload("res://scripts/tiles.gd")
const StringsScript := preload("res://scripts/strings.gd")
const BoardViewScript := preload("res://scripts/board_view.gd")
const AnimalScript := preload("res://scripts/animal.gd")
const TilePreviewScript := preload("res://scripts/tile_preview.gd")
const IconWidgetScript := preload("res://scripts/icon_widget.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const GAME_TITLE := "Animal Labyrinth"  # not localized, like this developer's other games
const START_CELL := Vector2i(-1, 1)  # start block left of the top-left slot's middle row
const STEP_TIME := 0.16
const START_DELAY := 0.5
const MAX_STEPS := 2000  # safety net; the wall-follower always ends at the goal or back at the start
const ROUND_BONUS := 50
const SAVE_PATH := "user://save.cfg"

# Same order as the animal kinds in animal.gd and the goal food in art.gd. Text is looked up
# through scripts/strings.gd, with "who_key" the subject phrase (e.g. "the monkey").
const ANIMALS := [
	{"name_key": "animal_monkey", "who_key": "who_monkey", "win_key": "win_bananas"},
	{"name_key": "animal_horse", "who_key": "who_horse", "win_key": "win_carrots"},
	{"name_key": "animal_cat", "who_key": "who_cat", "win_key": "win_fish"},
	{"name_key": "animal_dog", "who_key": "who_dog", "win_key": "win_bone"},
]

# Each difficulty deals from its own subset of tiles.gd's pieces (Tiles.POOLS): Fácil keeps to
# simple straights, bends and dead ends with more of them per round; Difícil adds the zigzags
# and the stepping-stone trap tile, with fewer tiles and a path that reaches its full length
# sooner. goal_cap must never exceed tiles_per_round: _guaranteed_route_tiles() below needs at
# least one tile per slot on the longest possible route, or a round could be unsolvable.
const DIFFICULTIES := [
	{"name_key": "difficulty_easy", "tiles_per_round": 10, "goal_start": 3, "goal_cap": 5},
	{"name_key": "difficulty_medium", "tiles_per_round": 8, "goal_start": 3, "goal_cap": 7},
	{"name_key": "difficulty_hard", "tiles_per_round": 6, "goal_start": 4, "goal_cap": 6},
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
var language := ""  # resolved to a real code (see StringsScript.system_language) once loaded
var sound_on := true
var settings_open := false
var overlay_kind := ""  # "title", "won" or "lost"; lets a language change redraw the right text
var lose_title_key := ""
var lose_body_key := ""
var lose_was_record := false

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
var home_button: Button
var game_bar: Control
var overlay_settings_button: Button
var settings_overlay: Control
var overlay_box: Control
var language_row: HBoxContainer
var sound_button: Button


func _ready() -> void:
	randomize()
	StringsScript.install()
	_load_save()
	if language == "":
		language = StringsScript.system_language()
	TranslationServer.set_locale(language)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_on)

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
	if phase == "build" and not settings_open:
		var slot := slot_of(Art.cell_at(board_view.get_local_mouse_position()))
		if slot >= 0 and board[slot] == 0:
			hover_slot = slot


func _unhandled_input(event: InputEvent) -> void:
	if phase != "build" or settings_open:
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

	# The route tiles guarantee a solution exists in this hand; the rest is random filler so the
	# player still has to work out which tiles they are and where they go.
	deck = _guaranteed_route_tiles()
	var filler := Tiles.pool(difficulty_kind)
	filler.shuffle()
	for tile in filler:
		if deck.size() >= difficulty.tiles_per_round:
			break
		deck.append(tile)
	deck.shuffle()
	tiles_left = deck.size()
	current_tile = deck.pop_back()

	animal.reset(Art.cell_pos(Vector2(START_CELL)), 0)
	_update_hud()


## The tile.gd pattern number that connects `entry` to `exit`, one of "W" (west), "N" (north),
## "E" (east) or "S" (south). Only the four combinations _guaranteed_route_tiles() can produce
## are handled: a route only ever moves east or south, since the goal is always down-and-right
## of the start slot.
func _connector_tile(entry: String, exit: String) -> int:
	if entry == "W" and exit == "E":
		return 1  # straight west-east
	if entry == "N" and exit == "S":
		return 2  # straight north-south
	if entry == "N" and exit == "E":
		return 3  # bend north-east
	return 5  # bend south-west (entry == "W" and exit == "S")


## Builds the exact tiles needed for one route from the start to the goal, following a random
## sequence of east/south moves through the slots. Adding these straights and bends to the deck
## (see _reset_round) guarantees every round has a solution, without telling the player which
## tiles they are or where they go — the deck is shuffled like any other tile.
func _guaranteed_route_tiles() -> Array:
	var south_exit := goal_cell.y > 11
	var goal_col := (goal_cell.x / 3) if south_exit else 3
	var goal_row := 3 if south_exit else (goal_cell.y / 3)

	var moves := []
	for i in goal_col:
		moves.append("E")
	for i in goal_row:
		moves.append("S")
	moves.shuffle()

	var tiles := []
	var entry := "W"  # the route always enters the first slot from the start, to the west
	for move in moves:
		tiles.append(_connector_tile(entry, move))
		entry = "W" if move == "E" else "N"
	tiles.append(_connector_tile(entry, "S" if south_exit else "E"))
	return tiles


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
				_lose("lose_title_splash", "lose_body_splash")
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
			_lose("lose_title_noway", "lose_body_noway")
			return

	_lose("lose_title_lost", "lose_body_lost")


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
	_float_text(tr("bonus_float") % bonus, animal.position + Vector2(0, -24), Color(0.6, 1, 0.5))
	_save()
	_update_hud()
	await get_tree().create_timer(1.6).timeout
	if token != round_token:
		return
	_show_win_overlay()


func _show_win_overlay() -> void:
	var bonus := ROUND_BONUS * round_num
	_show_overlay(ANIMALS[animal_kind].win_key,
		tr("win_body") % [_who(true), bonus, score],
		tr("round_button") % (round_num + 1), _next_round, false, "won")


func _lose(title_key: String, body_key: String) -> void:
	phase = "lost"
	sfx.play("lose")
	lose_title_key = title_key
	lose_body_key = body_key
	lose_was_record = score > high_score and score > 0
	_save()
	_update_hud()
	_show_lose_overlay()


func _show_lose_overlay() -> void:
	var body := "%s\n\n%s" % [tr(lose_body_key) % _who(true), tr("final_score") % score]
	if lose_was_record:
		body += "\n" + tr("new_record")
	_show_overlay(lose_title_key, body, "play_again", _start_game, true, "lost")


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
	left_box.add_child(_label("next_tile_header", 14, Color(0.75, 0.88, 1.0)))
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
	right_box.add_child(_label("score_header", 14, Color(0.75, 0.88, 1.0)))
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
	overlay_box = box
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
	# Play/Next round/Play again, with a softer Settings button below it.
	var action_col := VBoxContainer.new()
	action_col.alignment = BoxContainer.ALIGNMENT_CENTER
	action_col.add_theme_constant_override("separation", 10)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(200, 48)
	overlay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_button.pressed.connect(func() -> void:
		sfx.play("click")
		overlay.visible = false
		if overlay_action.is_valid():
			overlay_action.call())
	action_col.add_child(overlay_button)
	overlay_settings_button = _labeled_icon_button("gear", "settings", 200.0, true, true)
	overlay_settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_settings_button.pressed.connect(_open_settings)
	action_col.add_child(overlay_settings_button)
	vbox.add_child(action_col)

	# Top-center bar, shown only while actually playing: Settings and back-to-menu. Small and
	# translucent so it doesn't compete with the score panel next to it.
	# Added after the overlay so it stays on top and clickable even while the overlay is dimmed.
	game_bar = HBoxContainer.new()
	game_bar.add_theme_constant_override("separation", 6)
	game_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 14)
	game_bar.visible = false
	root.add_child(game_bar)
	var game_settings_button := _labeled_icon_button("gear", "settings", 118.0, true)
	game_settings_button.pressed.connect(_open_settings)
	game_bar.add_child(game_settings_button)
	home_button = _labeled_icon_button("home", "menu", 96.0, true)
	home_button.pressed.connect(_go_to_menu)
	game_bar.add_child(home_button)

	_build_settings_overlay(root)


## A button with a small code-drawn icon on the left and a translated label on the right.
## `soft` trades the bold yellow action-button look for a small, translucent pill.
func _labeled_icon_button(kind: String, key: String, width: float, soft := false, center_text := false) -> Button:
	var button := Button.new()
	var height := 30.0 if soft else 44.0
	button.custom_minimum_size = Vector2(width, height)
	button.focus_mode = Control.FOCUS_NONE
	if soft:
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.set_corner_radius_all(8)
			match state:
				"hover":
					style.bg_color = Color(1, 1, 1, 0.18)
				"pressed":
					style.bg_color = Color(1, 1, 1, 0.26)
				_:
					style.bg_color = Color(1, 1, 1, 0.1)
			button.add_theme_stylebox_override(state, style)
	var icon_size := 16.0 if soft else 22.0
	var icon_x := 10.0 if soft else 16.0
	var icon := IconWidgetScript.new()
	icon.kind = kind
	icon.color = Color(0.9, 0.94, 1.0) if soft else Color(0.25, 0.14, 0.02)
	icon.position = Vector2(icon_x, (height - icon_size) * 0.5)
	icon.size = Vector2(icon_size, icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var label := _label(key, 13 if soft else 16, Color(0.85, 0.92, 1.0) if soft else Color(0.25, 0.14, 0.02))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center_text else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 0 if center_text else icon_x + icon_size + 6.0
	label.offset_right = 0 if center_text else -8
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button


## Small modal for language and sound, reachable from any screen via the gear icon.
func _build_settings_overlay(root: Control) -> void:
	settings_overlay = ColorRect.new()
	settings_overlay.color = Color(0.02, 0.08, 0.15, 0.65)
	settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.visible = false
	root.add_child(settings_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(center)
	var box := _panel(center)
	box.custom_minimum_size = Vector2(360, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	box.add_child(vbox)
	vbox.add_child(_label("settings", 28, Color(1, 0.9, 0.4)))

	vbox.add_child(_label("language", 15, Color(0.75, 0.88, 1.0)))
	language_row = HBoxContainer.new()
	language_row.alignment = BoxContainer.ALIGNMENT_CENTER
	language_row.add_theme_constant_override("separation", 8)
	var lang_group := ButtonGroup.new()
	for entry in StringsScript.LANGUAGES:
		var code: String = entry[0]
		var lang_button := Button.new()
		lang_button.text = entry[1]  # native language name; never translated
		lang_button.toggle_mode = true
		lang_button.button_group = lang_group
		lang_button.button_pressed = code == language
		lang_button.focus_mode = Control.FOCUS_NONE
		lang_button.custom_minimum_size = Vector2(0, 40)
		lang_button.set_meta("code", code)
		lang_button.pressed.connect(_choose_language.bind(code))
		language_row.add_child(lang_button)
	vbox.add_child(language_row)

	vbox.add_child(_label("sound", 15, Color(0.75, 0.88, 1.0)))
	sound_button = Button.new()
	sound_button.text = "sound_on" if sound_on else "sound_off"
	sound_button.custom_minimum_size = Vector2(200, 44)
	sound_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sound_button.pressed.connect(_toggle_sound)
	vbox.add_child(sound_button)

	var close_button := Button.new()
	close_button.text = "close"
	close_button.custom_minimum_size = Vector2(160, 44)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_close_settings)
	vbox.add_child(close_button)


func _open_settings() -> void:
	sfx.play("click")
	settings_open = true
	overlay_box.visible = false
	settings_overlay.visible = true


func _close_settings() -> void:
	sfx.play("click")
	settings_open = false
	overlay_box.visible = true
	settings_overlay.visible = false


func _choose_language(code: String) -> void:
	sfx.play("click")
	language = code
	TranslationServer.set_locale(language)
	for button: Button in language_row.get_children():
		button.set_pressed_no_signal(button.get_meta("code", "") == code)
	_update_hud()
	_refresh_overlay_text()
	_save()


func _toggle_sound() -> void:
	sound_on = not sound_on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_on)
	sound_button.text = "sound_on" if sound_on else "sound_off"
	if sound_on:
		sfx.play("click")
	_save()


## Cancels the current round (if any) and returns to the title screen.
func _go_to_menu() -> void:
	sfx.play("click")
	round_token += 1
	phase = "title"
	_update_hud()
	_show_title()


## Redraws the currently open title/win/lose overlay after a language change.
func _refresh_overlay_text() -> void:
	if not overlay.visible:
		return
	match overlay_kind:
		"title":
			_show_title()
		"won":
			_show_win_overlay()
		"lost":
			_show_lose_overlay()


func _show_title() -> void:
	_show_overlay(GAME_TITLE, "title_body", "play", _start_game, true, "title")


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
		var name_label := _label(ANIMALS[i].name_key, 15, Color.WHITE)
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
		button.text = DIFFICULTIES[i].name_key
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


## "the cat", or "The cat" at the start of a sentence.
func _who(capital := false) -> String:
	var who: String = tr(ANIMALS[animal_kind].who_key)
	return who.left(1).to_upper() + who.substr(1) if capital else who


func _show_overlay(title: String, body: String, button: String, action: Callable, picker := false, kind := "") -> void:
	overlay_kind = kind
	animal_picker.visible = picker
	difficulty_picker.visible = picker
	overlay_settings_button.visible = kind != "won"
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
	points_label.text = tr("points_suffix") % Tiles.points(current_tile) if current_tile > 0 else " "
	tiles_label.text = tr("tiles_left") % tiles_left
	score_label.text = str(score)
	round_label.text = tr("round_label") % [round_num, tr(DIFFICULTIES[difficulty_kind].name_key)]
	best_label.text = tr("best") % maxi(high_score, score)
	match phase:
		"build":
			hint_label.text = tr("hint_build") % tiles_left
		"walk":
			hint_label.text = tr("hint_walk") % _who(true)
		_:
			hint_label.text = ""
	game_bar.visible = phase == "build" or phase == "walk"


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
		language = str(cfg.get_value("settings", "language", ""))
		sound_on = bool(cfg.get_value("settings", "sound", true))


## Stores the best score and the chosen animal, difficulty, language and sound setting.
func _save() -> void:
	high_score = maxi(high_score, score)
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", high_score)
	cfg.set_value("settings", "animal", animal_kind)
	cfg.set_value("settings", "difficulty", difficulty_kind)
	cfg.set_value("settings", "language", language)
	cfg.set_value("settings", "sound", sound_on)
	cfg.save(SAVE_PATH)
