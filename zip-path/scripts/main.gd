extends Node2D
## Zip Path: drag a single line from 1 through every cell, in increasing number order, to the
## last number. The line can't cross itself or a wall. Click and drag with the mouse; dragging
## back over your own line undoes it. Keys: arrows extend or retract (and reach the buttons),
## Enter / Space press, Backspace / Z undo, H hints, Esc goes back.
## Xbox gamepads work too (see _pad_input). Statistics and settings open from the header.

const GeneratorScript := preload("res://scripts/generator.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const StringsScript := preload("res://scripts/strings.gd")

const SCREEN := Vector2(700, 940)
const BOARD := Rect2(40, 196, 620, 620)
const PANEL := Rect2(32, 188, 636, 636)  # statistics and settings cover the board
## Difficulty levels: bigger boards and sparser checkpoints mean more open ground to reason
## about. `name` keys the saved data. `numbers` and `walls` come from the puzzle generator.
const LEVELS := [
	{"name": "Easy", "key": "level_easy", "size": 5, "numbers": 5, "walls": 6},
	{"name": "Medium", "key": "level_medium", "size": 6, "numbers": 5, "walls": 8},
	{"name": "Hard", "key": "level_hard", "size": 7, "numbers": 8, "walls": 10},
]
const SAVE_PATH := "user://zip_path.cfg"
const STICK_PRESS := 0.5  # left stick counts as a direction past this
const STICK_RELEASE := 0.3  # and lets go under this
const PAD_REPEAT_DELAY := 0.32  # holding a direction: wait this long, then
const PAD_REPEAT := 0.09  # move again this often
const SETTING_ROWS := ["set_sound", "set_vibration"]

# LinkedIn-like look.
const BG := Color("f4f2ee")
const CARD := Color.WHITE
const INK := Color(0, 0, 0, 0.9)
const MUTED := Color(0, 0, 0, 0.6)
const LINE := Color(0, 0, 0, 0.18)
const BLUE := Color("0a66c2")
const BLUE_SOFT := Color("e8f3ff")
const RED := Color("d5000f")
const GREEN := Color("057642")
const CONFETTI_COLORS := ["0a66c2", "057642", "d5000f", "f2b807", "6b46c1"]

var level := 1
var size := 6

# Settings.
var language := ""
var sound_on := true
var vibration_on := true

# The current puzzle: `path` is the one solution, used only for hints.
var path := PackedInt32Array()
var numbers := PackedInt32Array()
var number_index := {}  # cell -> checkpoint index (0-based)
var walls := {}  # edge key (see _edge_key) -> true

# The player's line so far, always starting with numbers[0].
var player_path := PackedInt32Array()
var in_path := {}  # cell -> true, mirrors player_path for fast lookups
var reached_count := 1  # how many checkpoints the line has reached so far

var generating := false
var elapsed := 0.0
var focused := true
var won := false
var win_clock := 0.0
var card_hidden := false
var hints_used := 0
var hint_cell := -1
var hint_key := ""
var hint_time := 0.0
var new_best := false
var best := {}  # level name -> seconds

# Statistics. A puzzle counts as played once the first move is made; leaving it unsolved ends the streak.
var stats := {}
var puzzle_started := false
var panel := ""  # "stats", "settings" or ""
var reset_armed := false

var hover_cell := -1
var hover_button := ""
var dragging := false
var last_drag_cell := -1

# Gamepad.
var using_pad := false
var pad_device := 0
var stick := Vector2.ZERO
var stick_dir := Vector2i.ZERO
var held_dir := Vector2i.ZERO  # direction held on the D-pad or stick
var repeat_timer := 0.0
var triggers := [false, false]
var focus := ""  # button selected with the gamepad or keyboard; "" when the board has focus
var nav_active := false  # gamepad or keyboard navigation in use (the mouse turns it off)
var confetti := []
var clock := 0.0

var font: Font
var bold: Font
var styles := {}
var sfx


func _ready() -> void:
	font = _font(400)
	bold = _font(700)
	sfx = SfxScript.new()
	add_child(sfx)
	StringsScript.install()
	stats = _empty_stats()
	_load()
	if language == "":
		language = StringsScript.system_language()
	_apply_settings()
	_new_game()


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


func _apply_settings() -> void:
	TranslationServer.set_locale(language)
	AudioServer.set_bus_mute(0, not sound_on)


# --- Puzzles -------------------------------------------------------------------------------

## A fresh random puzzle at the current difficulty level. Generating a large, sparse board can
## take a couple of seconds, so this yields two frames first to let a "Generating…" message show.
func _new_game() -> void:
	if puzzle_started and not won:
		stats.streak = 0  # gave up on a started puzzle
	generating = true
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_start_puzzle(randi())
	generating = false
	_save()


func _level_name() -> String:
	return LEVELS[level].name


func _level_label(index := -1) -> String:
	return tr(LEVELS[level if index < 0 else index].key)


func _start_puzzle(seed_value: int) -> void:
	var cfg: Dictionary = LEVELS[level]
	size = cfg.size
	var puzzle := {}
	for attempt in 5:
		puzzle = GeneratorScript.new().generate(size, cfg.numbers, cfg.walls, seed_value + attempt)
		if not puzzle.is_empty():
			break
	path = puzzle.get("path", PackedInt32Array())
	numbers = puzzle.get("numbers", PackedInt32Array())
	walls = puzzle.get("walls", {})
	number_index.clear()
	for i in numbers.size():
		number_index[numbers[i]] = i
	var start: int = numbers[0] if numbers.size() > 0 else 0
	player_path = PackedInt32Array([start])
	in_path = {start: true}
	reached_count = 1
	elapsed = 0.0
	won = false
	card_hidden = false
	new_best = false
	hints_used = 0
	hint_cell = -1
	hint_time = 0.0
	confetti.clear()
	dragging = false
	last_drag_cell = -1
	puzzle_started = false


func _empty_stats() -> Dictionary:
	var levels := {}
	for entry in LEVELS:
		levels[entry.name] = {"solved": 0, "total_time": 0, "no_hints": 0}
	return {"played": 0, "solved": 0, "streak": 0, "best_streak": 0, "levels": levels}


# --- Rules -----------------------------------------------------------------------------------

func _adjacent(a: int, b: int) -> bool:
	return absi(a / size - b / size) + absi(a % size - b % size) == 1


func _edge_key(a: int, b: int) -> int:
	return mini(a, b) * (size * size) + maxi(a, b)


## Tries to move the line's head onto `next_cell`. Returns what happened, for `_commit`.
func _attempt_move(next_cell: int) -> String:
	var head: int = player_path[player_path.size() - 1]
	if next_cell == head:
		return "none"
	if player_path.size() >= 2 and next_cell == player_path[player_path.size() - 2]:
		_pop_path()
		return "retract"
	if not _adjacent(head, next_cell) or in_path.has(next_cell) or walls.has(_edge_key(head, next_cell)):
		return "blocked"
	var index: int = number_index.get(next_cell, -1)
	if index != -1:
		if index != reached_count:
			return "blocked"
		# The last checkpoint can only be reached once nothing else is left to fill.
		if index == numbers.size() - 1 and player_path.size() + 1 != size * size:
			return "blocked"
	_push_path(next_cell, index)
	return "extend"


func _push_path(cell: int, index: int) -> void:
	player_path.append(cell)
	in_path[cell] = true
	if index != -1:
		reached_count += 1


func _pop_path() -> void:
	var cell: int = player_path[player_path.size() - 1]
	player_path.remove_at(player_path.size() - 1)
	in_path.erase(cell)
	if number_index.get(cell, -1) != -1:
		reached_count -= 1


## Retracts the line back to `cell`, which must already be on it.
func _truncate_to(cell: int) -> void:
	var idx: int = player_path.find(cell)
	if idx < 0 or idx == player_path.size() - 1:
		_commit("none")
		return
	while player_path.size() - 1 > idx:
		_pop_path()
	_commit("retract")


func _commit(result: String) -> void:
	match result:
		"none":
			return
		"blocked":
			sfx.play("blocked")
			_rumble(0.3, 0.5, 0.12)
			return
	if not puzzle_started:
		puzzle_started = true
		stats.played += 1
		_save()
	hint_time = 0.0
	sfx.play("connect" if result == "extend" else "undo")
	if result == "extend":
		_rumble(0.15, 0.0, 0.05)
	if player_path.size() == size * size:
		_win()


func _undo() -> void:
	if won or panel != "" or generating or player_path.size() <= 1:
		return
	_pop_path()
	sfx.play("undo")


func _clear() -> void:
	if won or generating:
		return
	var start: int = numbers[0]
	player_path = PackedInt32Array([start])
	in_path = {start: true}
	reached_count = 1
	sfx.play("remove")


## The route the player has drawn only stays a prefix of the one solution as long as every move
## was valid, but a valid move can still wander into a dead end. This finds where that happened.
func _hint() -> void:
	if won or panel != "" or generating:
		return
	hints_used += 1
	hint_time = 4.0
	sfx.play("hint")
	var mismatch := -1
	for i in player_path.size():
		if player_path[i] != path[i]:
			mismatch = i
			break
	if mismatch == -1:
		hint_cell = path[player_path.size()]
		hint_key = "z_hint_next"
	else:
		hint_cell = player_path[mismatch]
		hint_key = "z_hint_off"


func _win() -> void:
	won = true
	win_clock = 0.0
	var seconds := int(elapsed)
	var key := _level_name()
	if hints_used == 0 and (not best.has(key) or seconds < int(best[key])):
		new_best = best.has(key)
		best[key] = seconds
	stats.solved += 1
	stats.streak += 1
	stats.best_streak = maxi(int(stats.best_streak), int(stats.streak))
	var level_stats: Dictionary = stats.levels[key]
	level_stats.solved += 1
	level_stats.total_time += seconds
	if hints_used == 0:
		level_stats.no_hints += 1
	_save()
	sfx.play("win")
	_rumble(0.5, 0.7, 0.45)
	for i in 90:
		confetti.append({
			"pos": Vector2(BOARD.get_center().x + randf_range(-200, 200), BOARD.position.y + randf_range(-40, 40)),
			"vel": Vector2(randf_range(-240, 240), randf_range(-520, -160)),
			"color": Color(CONFETTI_COLORS[i % CONFETTI_COLORS.size()]).darkened(0.1), "spin": randf() * TAU, "size": randf_range(5, 10), "life": 2.6,
		})


# --- Update -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	clock += delta
	if not won and focused and panel == "" and not generating:
		elapsed += delta
	if won:
		win_clock += delta
	hint_time = maxf(0.0, hint_time - delta)
	if nav_active:
		_fix_focus()  # e.g. jump to the result card's buttons when it appears
	if held_dir != Vector2i.ZERO:
		repeat_timer -= delta
		if repeat_timer <= 0.0:
			repeat_timer = PAD_REPEAT
			_pad_move(held_dir)
	for c: Dictionary in confetti:
		c.vel.y += 700.0 * delta
		c.vel.x *= 0.99
		c.pos += c.vel * delta
		c.spin += delta * 8.0
		c.life -= delta
	confetti = confetti.filter(func(c: Dictionary) -> bool: return c.life > 0.0)
	queue_redraw()


# --- Input ----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if generating:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pad_input(event)
		return
	if event is InputEventKey:
		using_pad = false
	elif event is InputEventMouseButton:
		using_pad = false
		nav_active = false
		focus = ""
	if event is InputEventMouseMotion:
		hover_button = _button_at(event.position)
		var cell := _cell_at(event.position) if panel == "" else -1
		hover_cell = cell
		if dragging and cell >= 0 and cell != last_drag_cell and not won:
			last_drag_cell = cell
			_commit(_attempt_move(cell))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var id := _button_at(event.position)
			if id != "":
				_press(id)
				return
			if panel != "":
				if not PANEL.has_point(event.position):
					_press("close")
				return
			var cell := _cell_at(event.position)
			if cell >= 0 and not won:
				var head: int = player_path[player_path.size() - 1]
				if cell != head:
					if in_path.has(cell):
						_truncate_to(cell)
					else:
						_commit(_attempt_move(cell))
				dragging = true
				last_drag_cell = cell
		else:
			dragging = false
			last_drag_cell = -1
	elif event is InputEventKey and event.pressed:
		_key(event)


## Xbox-style gamepad: D-pad / left stick extend or retract the line, B also retracts, Y clears,
## LB undo, RB hint, LT / RT change level, Start new game.
func _pad_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		match event.axis:
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				if event.axis == JOY_AXIS_LEFT_X:
					stick.x = event.axis_value
				else:
					stick.y = event.axis_value
				var dir := Vector2i.ZERO
				if stick.length() >= STICK_PRESS:
					dir = Vector2i(int(signf(stick.x)), 0) if absf(stick.x) > absf(stick.y) else Vector2i(0, int(signf(stick.y)))
				elif stick.length() > STICK_RELEASE and stick_dir != Vector2i.ZERO:
					dir = stick_dir  # between the two thresholds: keep the current direction
				if dir != stick_dir:
					stick_dir = dir
					_pad_hold(dir)
			JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT:
				var index := 0 if event.axis == JOY_AXIS_TRIGGER_LEFT else 1
				var down: bool = event.axis_value > 0.6
				if down and not triggers[index] and panel == "":
					_use_pad(event)
					var next := clampi(level + (-1 if index == 0 else 1), 0, LEVELS.size() - 1)
					if next != level:
						_press("level_%d" % next)
				triggers[index] = event.axis_value > 0.3 if triggers[index] else down
		return

	var button := event as InputEventJoypadButton
	var dpad := {JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN,
			JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT}
	if dpad.has(button.button_index):
		if button.pressed:
			_pad_hold(dpad[button.button_index])
		elif held_dir == dpad[button.button_index]:
			_pad_hold(Vector2i.ZERO)
		return
	if not button.pressed:
		return
	_use_pad(event)
	if panel != "":
		match button.button_index:
			JOY_BUTTON_A:
				if focus != "":
					_press(focus)
					_fix_focus()
			JOY_BUTTON_B, JOY_BUTTON_START:
				_press("close")
		return
	match button.button_index:
		JOY_BUTTON_START:
			_press("new")
			return
		JOY_BUTTON_LEFT_SHOULDER:
			_undo()
			return
		JOY_BUTTON_RIGHT_SHOULDER:
			_hint()
			return
	if focus != "":
		match button.button_index:
			JOY_BUTTON_A:
				_press(focus)
				_fix_focus()
			JOY_BUTTON_B:
				if won and not card_hidden:
					_press("view")
					_fix_focus()
				elif not won:
					focus = ""
					_start_nav()
					sfx.play("click")
		return
	if won:
		return
	match button.button_index:
		JOY_BUTTON_B:
			_undo()
		JOY_BUTTON_Y:
			_clear()


## Marks the gamepad as the active input (for its hints and rumble), then starts navigation.
func _use_pad(event: InputEvent) -> void:
	using_pad = true
	pad_device = event.device
	_start_nav()


## Gamepad or keyboard navigation is in use: make sure something has the focus, the board or
## a button when the board isn't playable.
func _start_nav() -> void:
	nav_active = true
	_fix_focus()


## Starts (or stops, with ZERO) moving in a direction.
func _pad_hold(dir: Vector2i) -> void:
	held_dir = dir
	if dir == Vector2i.ZERO:
		return
	var had_focus := nav_active
	using_pad = true
	_start_nav()
	if had_focus or won or panel != "":
		_pad_move(dir)
	else:
		sfx.play("click")
	repeat_timer = PAD_REPEAT_DELAY


## Rows the gamepad and keyboard move through, top to bottom: arrays of button ids, and "board".
func _nav_rows() -> Array:
	var icons := ["stats", "settings"]
	if panel == "stats":
		return [icons, ["close"], ["reset"]]
	if panel == "settings":
		var langs := []
		for entry in StringsScript.LANGUAGES:
			langs.append("lang_" + entry[0])
		var rows := [icons, ["close"], langs]
		for id in SETTING_ROWS:
			rows.append([id])
		return rows
	if won and not card_hidden:
		return [["new", "view"]] if win_clock > 0.9 else []
	var list := _buttons()
	var header := []
	for i in LEVELS.size():
		header.append("level_%d" % i)
	header.append("new")
	var bottom := []
	for id in ["undo", "clear", "hint", "results"]:
		if list.has(id):
			bottom.append(id)
	return [icons, header, bottom] if won else [icons, header, "board", bottom]


## Keeps the focus on something that exists (buttons come and go as the game changes).
func _fix_focus() -> void:
	var rows := _nav_rows()
	if rows.is_empty():
		return
	var ids := []
	for row in rows:
		if row is Array:
			ids.append_array(row)
	if panel != "":
		if not ids.has(focus):
			focus = "close"
	elif focus == "" and not rows.has("board"):
		focus = ids[0] if won and not card_hidden else ids.back()
	elif focus != "" and not ids.has(focus):
		focus = "" if rows.has("board") else (ids[0] if won and not card_hidden else ids.back())


## Direction pressed while the board has focus: extends the line, retracts it (stepping back
## the way it came), or does nothing at the edge of the grid.
func _attempt_direction(dir: Vector2i) -> void:
	var head: int = player_path[player_path.size() - 1]
	var row := head / size + dir.y
	var col := head % size + dir.x
	if row < 0 or row >= size or col < 0 or col >= size:
		sfx.play("blocked")
		return
	_commit(_attempt_move(row * size + col))


func _pad_move(dir: Vector2i) -> void:
	var rows := _nav_rows()
	if rows.is_empty():
		return
	_fix_focus()
	var list := _buttons()
	var row_index := rows.find("board") if focus == "" else -1
	for i in rows.size():
		if rows[i] is Array and rows[i].has(focus):
			row_index = i
	if row_index < 0:
		return

	if focus == "":
		var head: int = player_path[player_path.size() - 1]
		if dir.x != 0:
			_attempt_direction(Vector2i(dir.x, 0))
			return
		var target_row := head / size + dir.y
		if target_row >= 0 and target_row < size:
			_attempt_direction(Vector2i(0, dir.y))
			return
		var target := row_index + dir.y
		if target < 0 or target >= rows.size():
			return
		focus = _nearest(rows[target], _cell_rect(head).get_center().x, list)
		sfx.play("click")
		return

	var at_x: float = list[focus].get_center().x
	if dir.x != 0:
		var row: Array = rows[row_index]
		var next: String = row[clampi(row.find(focus) + dir.x, 0, row.size() - 1)]
		if next != focus:
			focus = next
			sfx.play("click")
		return
	var target := row_index + dir.y
	if target < 0 or target >= rows.size():
		return
	focus = "" if rows[target] is String else _nearest(rows[target], at_x, list)
	sfx.play("click")


func _nearest(ids: Array, at_x: float, list: Dictionary) -> String:
	var best_id := ""
	for id: String in ids:
		if best_id == "" or absf(list[id].get_center().x - at_x) < absf(list[best_id].get_center().x - at_x):
			best_id = id
	return best_id


func _rumble(weak: float, strong: float, duration: float) -> void:
	if using_pad and vibration_on:
		Input.start_joy_vibration(pad_device, weak, strong, duration)


func _key(event: InputEventKey) -> void:
	var code := event.physical_keycode
	if panel != "":
		# Panels: arrows move between their buttons, Enter / Space press, Esc closes.
		var panel_moves := {KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0)}
		if panel_moves.has(code):
			var had_focus := nav_active and focus != ""
			_start_nav()
			if had_focus:
				_pad_move(panel_moves[code])
			else:
				sfx.play("click")  # the first press just shows the focus ring
		elif code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_start_nav()
			if focus != "":
				_press(focus)
				_fix_focus()
		elif code == KEY_ESCAPE:
			_press("close")
		return
	if code == KEY_Z:  # with or without Ctrl
		_undo()
		return
	match code:
		KEY_H:
			_hint()
			return
		KEY_N:
			_new_game()
			return
	# Arrows / WASD extend or retract the line, and past the grid's edge, reach the buttons.
	var moves := {KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0),
			KEY_W: Vector2i(0, -1), KEY_S: Vector2i(0, 1), KEY_A: Vector2i(-1, 0), KEY_D: Vector2i(1, 0)}
	if moves.has(code):
		var had_focus := nav_active
		_start_nav()
		if had_focus or won:
			_pad_move(moves[code])
		else:
			sfx.play("click")  # the first press just shows the cursor
		return
	match code:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if focus != "" or won:
				_start_nav()
				if focus != "":
					_press(focus)
					_fix_focus()
			return
		KEY_ESCAPE:
			if won and not card_hidden:
				_press("view")
				_fix_focus()
			elif focus != "" and not won:
				focus = ""  # back to the board
				_start_nav()
				sfx.play("click")
			return
		KEY_BACKSPACE, KEY_DELETE:
			_undo()


func _press(id: String) -> void:
	sfx.play("click")
	if id.begins_with("level_"):
		level = int(id.substr(6))
		_new_game()
		return
	if id.begins_with("lang_"):
		language = id.substr(5)
		_apply_settings()
		_save()
		return
	match id:
		"stats", "settings":
			panel = "" if panel == id else id
			reset_armed = false
			hint_time = 0.0
			if nav_active:
				focus = "close" if panel != "" else id
		"close":
			if nav_active:
				focus = panel
			panel = ""
			reset_armed = false
		"reset":
			if reset_armed:
				stats = _empty_stats()
				best.clear()
				reset_armed = false
				_save()
			else:
				reset_armed = true
		"set_sound":
			sound_on = not sound_on
			_apply_settings()
			_save()
			sfx.play("click")
		"set_vibration":
			vibration_on = not vibration_on
			_save()
			if vibration_on:
				_rumble(0.3, 0.3, 0.15)
		"undo":
			_undo()
		"clear":
			_clear()
		"hint":
			_hint()
		"new":
			_new_game()
		"view":
			card_hidden = true
		"results":
			card_hidden = false


# --- Layout -----------------------------------------------------------------------------------

func _cell_rect(cell: int) -> Rect2:
	var unit := BOARD.size.x / size
	return Rect2(BOARD.position + Vector2(cell % size, cell / size) * unit, Vector2(unit, unit))


func _cell_at(pos: Vector2) -> int:
	if not BOARD.has_point(pos):
		return -1
	var unit := BOARD.size.x / size
	var col := clampi(int((pos.x - BOARD.position.x) / unit), 0, size - 1)
	var row := clampi(int((pos.y - BOARD.position.y) / unit), 0, size - 1)
	return row * size + col


func _buttons() -> Dictionary:
	var list := {}
	list["stats"] = Rect2(SCREEN.x - 272, 50, 46, 46)
	list["settings"] = Rect2(SCREEN.x - 218, 50, 46, 46)
	if panel != "":
		list["close"] = Rect2(PANEL.end.x - 64, PANEL.position.y + 20, 44, 44)
		if panel == "stats":
			list["reset"] = Rect2(PANEL.get_center().x - 150, PANEL.end.y - 76, 300, 48)
		else:
			var x := PANEL.position.x + 28
			for entry in StringsScript.LANGUAGES:
				var width: float = bold.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0
				list["lang_" + entry[0]] = Rect2(x, PANEL.position.y + 124, width, 42)
				x += width + 8.0
			for i in SETTING_ROWS.size():
				list[SETTING_ROWS[i]] = Rect2(PANEL.position.x + 20, PANEL.position.y + 206 + i * 84, PANEL.size.x - 40, 72)
		return list
	# Difficulty chips on the left, New game on the right.
	var x := 40.0
	for i in LEVELS.size():
		var width: float = bold.get_string_size(_level_label(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0
		list["level_%d" % i] = Rect2(x, 132, width, 40)
		x += width + 6.0
	var new_width: float = maxf(124.0, bold.get_string_size(tr("new_game"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 36.0)
	list["new"] = Rect2(SCREEN.x - 40 - new_width, 132, new_width, 40)
	if won and not card_hidden and win_clock > 0.9:
		var card := _card_rect()
		list["new"] = Rect2(card.position.x + 32, card.end.y - 72, 190, 48)
		list["view"] = Rect2(card.end.x - 222, card.end.y - 72, 190, 48)
		return list
	var y := BOARD.end.y + 26
	list["undo"] = Rect2(40, y, 180, 48)
	list["clear"] = Rect2(230, y, 180, 48)
	list["hint"] = Rect2(420, y, 180, 48)
	if won and card_hidden:
		list.erase("undo")
		list.erase("clear")
		list.erase("hint")
		list["results"] = Rect2(40, y, 560, 48)
	return list


func _button_at(pos: Vector2) -> String:
	var list := _buttons()
	for id: String in list:
		if list[id].has_point(pos):
			return id
	return ""


func _card_rect() -> Rect2:
	return Rect2(BOARD.get_center() - Vector2(240, 170), Vector2(480, 340))


# --- Drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), BG)

	# Header.
	_path_icon(Vector2(62, 76), 34.0, INK)
	_text(Vector2(92, 92), "Zip Path", 34, INK, bold)
	var sub := "%s · %d×%d" % [_level_label(), size, size]
	if best.has(_level_name()):
		sub += "  ·  " + tr("best_short") % _time(int(best[_level_name()]))
	_text(Vector2(40, 118), sub, 16, MUTED, font)
	var timer_rect := Rect2(SCREEN.x - 160, 50, 120, 46)
	_box(timer_rect, CARD, Color(0, 0, 0, 0.15), 23)
	_clock_icon(timer_rect.position + Vector2(26, 23), 9.0, GREEN if won else INK)
	_text(timer_rect.position + Vector2(44, 31), _time(int(elapsed)), 20, GREEN if won else INK, bold)

	var buttons := _buttons()
	_icon_button(buttons.stats, "stats")
	_icon_button(buttons.settings, "settings")
	var play_buttons := buttons if panel == "" else _play_buttons()
	for i in LEVELS.size():
		_tab(play_buttons["level_%d" % i], _level_label(i), i == level, "level_%d" % i)
	if not (won and not card_hidden and win_clock > 0.9):
		_button(play_buttons.new, tr("new_game"), "new", true)

	_draw_board()

	# Bottom controls.
	var y := BOARD.end.y + 26
	if won and card_hidden:
		_button(play_buttons.results, tr("solved_results") % _time(int(elapsed)), "results", true)
	elif not won or card_hidden or win_clock <= 0.9:
		_button(Rect2(40, y, 180, 48), tr("undo"), "undo")
		_button(Rect2(230, y, 180, 48), tr("clear"), "clear")
		_button(Rect2(420, y, 180, 48), tr("hint"), "hint")

	if hint_time > 0.0 and hint_cell >= 0:
		_text(Vector2(SCREEN.x / 2, BOARD.position.y - 10), tr(hint_key), 16, BLUE, bold, true, 620)
	else:
		var help := tr("z_pad_help") if using_pad else tr("z_rules")
		_text(Vector2(SCREEN.x / 2, SCREEN.y - 26), help, 15, MUTED, font, true, 640)

	for c: Dictionary in confetti:
		draw_set_transform(c.pos, c.spin, Vector2.ONE)
		draw_rect(Rect2(Vector2(-c.size / 2, -c.size / 4), Vector2(c.size, c.size / 2)), Color(c.color, minf(1.0, c.life)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if won and not card_hidden and win_clock > 0.9 and panel == "":
		_draw_result_card()
	if panel == "stats":
		_draw_stats()
	elif panel == "settings":
		_draw_settings()

	# Focus ring on the button selected with the gamepad or keyboard.
	if nav_active and focus != "":
		if buttons.has(focus):
			var radius := 18 if SETTING_ROWS.has(focus) else 26
			_box(buttons[focus].grow(4), Color(0, 0, 0, 0), BLUE, radius, 3)


## The play screen's buttons, for drawing the header and footer under an open panel.
func _play_buttons() -> Dictionary:
	var open := panel
	panel = ""
	var list := _buttons()
	panel = open
	return list


func _draw_board() -> void:
	var unit := BOARD.size.x / size
	_box(BOARD.grow(6), CARD, Color(0, 0, 0, 0.08), 14)
	if generating:
		_text(BOARD.get_center(), "…", 40, MUTED, bold, true)
		return
	for cell in size * size:
		var rect := _cell_rect(cell)
		draw_rect(rect, Color("f3f2ef") if cell == hover_cell and not won and panel == "" else CARD)
	for i in range(1, size):
		draw_line(BOARD.position + Vector2(i * unit, 0), BOARD.position + Vector2(i * unit, BOARD.size.y), LINE, 1.0)
		draw_line(BOARD.position + Vector2(0, i * unit), BOARD.position + Vector2(BOARD.size.x, i * unit), LINE, 1.0)
	_box(BOARD, Color(0, 0, 0, 0), INK, 6, 3)

	for key: int in walls:
		_draw_wall(key / (size * size), key % (size * size), unit)
	_draw_path(unit)
	for i in numbers.size():
		_draw_number(numbers[i], i, unit)

	if hint_time > 0.0 and hint_cell >= 0:
		var pulse := 0.5 + 0.5 * sin(clock * 8.0)
		var rect := _cell_rect(hint_cell).grow(-2)
		draw_rect(rect, Color(BLUE, 0.15 + 0.15 * pulse))
		draw_rect(rect, BLUE, false, 4.0)
	if nav_active and focus == "" and panel == "" and not won:
		draw_rect(_cell_rect(player_path[player_path.size() - 1]).grow(-3), BLUE, false, 3.0)


## A short thick line across the shared edge between two cells that the path can't cross.
func _draw_wall(a: int, b: int, unit: float) -> void:
	var mid := (_cell_rect(a).get_center() + _cell_rect(b).get_center()) / 2.0
	var half := unit * 0.44
	if absi(a - b) == 1:  # side by side: the wall between them runs vertically
		draw_line(mid + Vector2(0, -half), mid + Vector2(0, half), INK, 5.0, true)
	else:  # one above the other: the wall runs horizontally
		draw_line(mid + Vector2(-half, 0), mid + Vector2(half, 0), INK, 5.0, true)


## The player's line so far, drawn as a rounded tube through the middle of each cell it crosses.
func _draw_path(unit: float) -> void:
	var color := GREEN if won else BLUE
	var width := unit * 0.22
	for i in range(player_path.size() - 1):
		draw_line(_cell_rect(player_path[i]).get_center(), _cell_rect(player_path[i + 1]).get_center(), color, width, true)
	for cell in player_path:
		draw_circle(_cell_rect(cell).get_center(), width / 2.0, color)
	if not won:
		draw_circle(_cell_rect(player_path[player_path.size() - 1]).get_center(), width * 0.62, color.lightened(0.15))


func _draw_number(cell: int, index: int, unit: float) -> void:
	var center := _cell_rect(cell).get_center()
	var radius := unit * 0.32
	var reached := index < reached_count
	if reached:
		draw_circle(center, radius, BLUE)
	else:
		draw_circle(center, radius, CARD)
		draw_arc(center, radius, 0.0, TAU, 32, BLUE, 2.5, true)
	_text(center + Vector2(0, 6), str(index + 1), 18, Color.WHITE if reached else BLUE, bold, true)


func _draw_result_card() -> void:
	var appear := clampf((win_clock - 0.9) / 0.25, 0.0, 1.0)
	draw_rect(BOARD.grow(8), Color(1, 1, 1, 0.55 * appear))
	var card := _card_rect()
	card.position.y += (1.0 - appear) * 20.0
	_box(Rect2(card.position + Vector2(0, 6), card.size), Color(0, 0, 0, 0.12 * appear), Color(0, 0, 0, 0), 18)
	_box(card, Color(1, 1, 1, appear), Color(0, 0, 0, 0.1 * appear), 18)
	var cx := card.get_center().x
	_path_icon(Vector2(cx, card.position.y + 52), 44.0, Color(GREEN, appear))
	_text(Vector2(cx, card.position.y + 118), tr("you_win"), 34, Color(INK, appear), bold, true)
	_text(Vector2(cx, card.position.y + 148), "%s · %d×%d" % [_level_label(), size, size], 16, Color(MUTED, appear), font, true)
	_text(Vector2(cx, card.position.y + 206), _time(int(elapsed)), 44, Color(INK, appear), bold, true)
	var detail := ""
	if hints_used == 1:
		detail = tr("hint_used_one")
	elif hints_used > 1:
		detail = tr("hints_used") % hints_used
	elif new_best:
		detail = tr("new_best") % _level_label()
	elif best.has(_level_name()):
		detail = tr("best_on") % [_level_label(), _time(int(best[_level_name()]))]
	_text(Vector2(cx, card.position.y + 238), detail, 15, Color(BLUE if new_best else MUTED, appear), font, true, 440)
	var buttons := _buttons()
	if buttons.has("new"):
		_button(buttons.new, tr("new_game"), "new", true)
	if buttons.has("view"):
		_button(buttons.view, tr("view_board"), "view")


func _draw_panel_frame(title: String) -> void:
	draw_rect(Rect2(Vector2(0, PANEL.position.y - 8), Vector2(SCREEN.x, SCREEN.y - PANEL.position.y + 8)), Color(BG, 0.7))
	_box(Rect2(PANEL.position + Vector2(0, 6), PANEL.size), Color(0, 0, 0, 0.1), Color(0, 0, 0, 0), 18)
	_box(PANEL, CARD, Color(0, 0, 0, 0.1), 18)
	_text(PANEL.position + Vector2(28, 56), title, 28, INK, bold)
	var close: Rect2 = _buttons().close
	_box(close, Color("ebebeb") if hover_button == "close" else CARD, Color(0, 0, 0, 0.35), 22)
	_close_icon(close.get_center(), 8.0, INK)


func _draw_stats() -> void:
	_draw_panel_frame(tr("statistics"))
	var x := PANEL.position.x + 28
	var width := PANEL.size.x - 56
	var played := int(stats.played)
	var solved := int(stats.solved)
	var tiles := [
		[str(played), tr("played")],
		[str(solved), tr("solved")],
		["%d%%" % (roundi(100.0 * solved / played) if played > 0 else 0), tr("win_rate")],
		[str(stats.streak), tr("current_streak")],
		[str(stats.best_streak), tr("best_streak")],
	]
	var tile_w := (width - 4 * 10.0) / 5.0
	for i in tiles.size():
		var tile := Rect2(x + i * (tile_w + 10.0), PANEL.position.y + 84, tile_w, 96)
		_box(tile, BG, Color(0, 0, 0, 0), 12)
		_text(Vector2(tile.get_center().x, tile.position.y + 50), tiles[i][0], 30, INK, bold, true)
		_text(Vector2(tile.get_center().x, tile.position.y + 78), tiles[i][1], 13, MUTED, font, true, tile_w - 10)

	# Per level table.
	var columns := [x + 12, x + 230, x + 340, x + 450, x + 545]
	var head_y := PANEL.position.y + 222
	var heads := [tr("level"), tr("solved"), tr("best_time"), tr("average"), tr("no_hints")]
	for i in heads.size():
		if i == 0:
			_text(Vector2(columns[i], head_y), heads[i], 13, MUTED, bold, false, 200)
		else:
			_text(Vector2(columns[i], head_y), heads[i], 13, MUTED, bold, true, 100)
	for i in LEVELS.size():
		var row := Rect2(x, head_y + 14 + i * 64, width, 56)
		_box(row, BG if i % 2 == 0 else CARD, Color(0, 0, 0, 0), 10)
		var data: Dictionary = stats.levels[LEVELS[i].name]
		var base_y := row.position.y + 35
		_text(Vector2(columns[0], base_y - 6), _level_label(i), 17, INK, bold)
		_text(Vector2(columns[0], base_y + 12), "%d×%d" % [LEVELS[i].size, LEVELS[i].size], 13, MUTED, font)
		var level_solved := int(data.solved)
		_text(Vector2(columns[1], base_y), str(level_solved), 17, INK, bold, true)
		var best_text := _time(int(best[LEVELS[i].name])) if best.has(LEVELS[i].name) else "—"
		_text(Vector2(columns[2], base_y), best_text, 17, GREEN if best.has(LEVELS[i].name) else MUTED, bold, true)
		var average := _time(int(data.total_time) / level_solved) if level_solved > 0 else "—"
		_text(Vector2(columns[3], base_y), average, 17, INK if level_solved > 0 else MUTED, bold, true)
		_text(Vector2(columns[4], base_y), str(data.no_hints), 17, INK, bold, true)

	if played == 0:
		_text(Vector2(PANEL.get_center().x, PANEL.position.y + 470), tr("stats_empty"), 16, MUTED, font, true, width)
	var reset: Rect2 = _buttons().reset
	var armed_color := RED if reset_armed else Color(0, 0, 0, 0.6)
	_box(reset, Color("fdecee") if reset_armed else (Color("ebebeb") if hover_button == "reset" else CARD), armed_color, 24)
	_text(reset.get_center() + Vector2(0, 6), tr("confirm_reset") if reset_armed else tr("reset_stats"), 16, RED if reset_armed else INK, bold, true, reset.size.x - 20)


func _draw_settings() -> void:
	_draw_panel_frame(tr("settings"))
	var buttons := _buttons()
	_text(PANEL.position + Vector2(28, 112), tr("language"), 15, MUTED, bold)
	for entry in StringsScript.LANGUAGES:
		var id: String = "lang_" + entry[0]
		_tab(buttons[id], entry[1], entry[0] == language, id)
	var rows := {
		"set_sound": [tr("sound"), tr("sound_desc"), sound_on],
		"set_vibration": [tr("vibration"), tr("vibration_desc"), vibration_on],
	}
	for id: String in SETTING_ROWS:
		var rect: Rect2 = buttons[id]
		_box(rect, Color("f3f2ef") if hover_button == id else CARD, Color(0, 0, 0, 0.12), 14)
		_text(rect.position + Vector2(20, 30), rows[id][0], 18, INK, bold, false, rect.size.x - 110)
		_text(rect.position + Vector2(20, 54), rows[id][1], 14, MUTED, font, false, rect.size.x - 110)
		var on: bool = rows[id][2]
		var track := Rect2(rect.end.x - 72, rect.get_center().y - 13, 52, 26)
		_box(track, BLUE if on else Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 13)
		draw_circle(Vector2(track.end.x - 13 if on else track.position.x + 13, track.get_center().y), 10.0, Color.WHITE)


# --- Drawing helpers -----------------------------------------------------------------------------

## A small zigzag line with a dot at each end: the game's logo, and the win card's icon.
func _path_icon(center: Vector2, width: float, color: Color) -> void:
	var w := width
	var points := PackedVector2Array()
	for p in [Vector2(-0.42, -0.32), Vector2(0.14, -0.32), Vector2(-0.14, 0.32), Vector2(0.42, 0.32)]:
		points.append(center + p * w)
	draw_polyline(points, color, w * 0.16, true)
	draw_circle(points[0], w * 0.11, color)
	draw_circle(points[3], w * 0.11, color)


func _close_icon(center: Vector2, arm: float, color: Color) -> void:
	var width := maxf(1.5, arm * 0.28)
	draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), color, width, true)
	draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), color, width, true)


func _clock_icon(center: Vector2, radius: float, color: Color) -> void:
	draw_arc(center, radius, 0.0, TAU, 24, color, 2.0, true)
	draw_line(center, center + Vector2(0, -radius * 0.6), color, 2.0)
	draw_line(center, center + Vector2(radius * 0.45, 0), color, 2.0)


## Round header button with a bar chart (statistics) or a gear (settings).
func _icon_button(rect: Rect2, id: String) -> void:
	var active := panel == id
	var fill := BLUE_SOFT if active else (Color("ebebeb") if hover_button == id else CARD)
	_box(rect, fill, BLUE if active else Color(0, 0, 0, 0.15), 23)
	var c := rect.get_center()
	var color := BLUE if active else INK
	if id == "stats":
		for i in 3:
			var h: float = [8.0, 14.0, 20.0][i]
			draw_rect(Rect2(c + Vector2(-11 + i * 8, 10 - h), Vector2(6, h)), color)
	else:
		for i in 8:
			var a := i * TAU / 8.0
			draw_line(c + Vector2.from_angle(a) * 8.0, c + Vector2.from_angle(a) * 12.5, color, 4.0)
		draw_circle(c, 8.5, color)
		draw_circle(c, 3.5, fill)


func _box(rect: Rect2, fill: Color, border: Color, radius: int, border_width := 1) -> void:
	var key := "%s|%s|%d|%d|%s" % [fill.to_html(), border.to_html(), radius, border_width, rect.size]
	var style: StyleBoxFlat = styles.get(key)
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = fill
		style.border_color = border
		style.set_border_width_all(border_width if border.a > 0.0 else 0)
		style.set_corner_radius_all(radius)
		style.anti_aliasing = true
		if styles.size() > 400:
			styles.clear()
		styles[key] = style
	style.draw(get_canvas_item(), rect)


func _button(rect: Rect2, label: String, id: String, primary := false) -> void:
	var hovered := hover_button == id
	if primary:
		_box(rect, BLUE.darkened(0.15) if hovered else BLUE, Color(0, 0, 0, 0), 24)
		_text(rect.get_center() + Vector2(0, 6), label, 17, Color.WHITE, bold, true, rect.size.x - 16)
	else:
		_box(rect, Color("ebebeb") if hovered else CARD, Color(0, 0, 0, 0.6), 24)
		_text(rect.get_center() + Vector2(0, 6), label, 17, INK, bold, true, rect.size.x - 16)


func _tab(rect: Rect2, label: String, active: bool, id: String) -> void:
	var hovered := hover_button == id
	if active:
		_box(rect, Color("01754f"), Color(0, 0, 0, 0), 20)
		_text(rect.get_center() + Vector2(0, 6), label, 16, Color.WHITE, bold, true)
	else:
		_box(rect, Color("ebebeb") if hovered else CARD, Color(0, 0, 0, 0.35), 20)
		_text(rect.get_center() + Vector2(0, 6), label, 16, INK, bold, true)


## Draws text; with `max_width`, long text (e.g. in other languages) shrinks to fit.
func _text(pos: Vector2, text: String, font_size: int, color: Color, face: Font, centered := false, max_width := 0.0) -> void:
	var fitted := font_size
	var width := face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
	if max_width > 0.0 and width > max_width:
		fitted = maxi(9, int(font_size * max_width / width))
		width = face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
	var at := pos
	if centered:
		at.x -= width / 2.0
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, color)


func _time(seconds: int) -> String:
	return "%02d:%02d" % [seconds / 60, seconds % 60]


# --- Save --------------------------------------------------------------------------------------

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	if config.has_section("best"):
		for key in config.get_section_keys("best"):
			best[key] = int(config.get_value("best", key))
	level = clampi(int(config.get_value("settings", "level", 1)), 0, LEVELS.size() - 1)
	language = str(config.get_value("settings", "language", ""))
	sound_on = bool(config.get_value("settings", "sound", true))
	vibration_on = bool(config.get_value("settings", "vibration", true))
	var saved: Variant = config.get_value("stats", "data", {})
	if saved is Dictionary and saved.has("levels"):
		for key in ["played", "solved", "streak", "best_streak"]:
			stats[key] = int(saved.get(key, 0))
		for entry in LEVELS:
			var data: Dictionary = saved.levels.get(entry.name, {})
			for key in ["solved", "total_time", "no_hints"]:
				stats.levels[entry.name][key] = int(data.get(key, 0))


func _save() -> void:
	var config := ConfigFile.new()
	for key in best:
		config.set_value("best", key, best[key])
	config.set_value("settings", "level", level)
	config.set_value("settings", "language", language)
	config.set_value("settings", "sound", sound_on)
	config.set_value("settings", "vibration", vibration_on)
	config.set_value("stats", "data", stats)
	config.save(SAVE_PATH)
