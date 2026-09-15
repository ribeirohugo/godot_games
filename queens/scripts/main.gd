extends Node2D
## Queens: place one queen in every row, column and colored region. Queens can't touch,
## not even diagonally. Tap a cell once for ×, twice for a queen; drag to mark many ×.
## Right click places or removes a queen. Keys: arrows move, Space cycles, Q queen, X mark,
## Backspace clears, Z undoes, H gives a hint.

const GeneratorScript := preload("res://scripts/generator.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const SCREEN := Vector2(700, 940)
const BOARD := Rect2(40, 196, 620, 620)
const SIZES := [6, 7, 8, 9, 10]
const DAILY_SIZES := [7, 8, 9, 8, 9, 10, 8]  # by weekday, Monday first
const DAILY_EPOCH := "2026-01-01"
const SAVE_PATH := "user://queens.cfg"

enum Mark { EMPTY, CROSS, QUEEN }

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
const REGION_COLORS := ["bba3e2", "ffc992", "96beff", "b3dfa0", "dfdfdf", "ff7b60", "e6f388", "b9b29e", "dfa0bf", "a3d2d8", "f1c4e4", "8fe3c4"]

var mode := "daily"
var size := 8
var practice_size := 8
var auto_cross := true
var puzzle_label := ""
var daily_key := ""

var regions := PackedInt32Array()
var solution := PackedInt32Array()
var colors: Array[Color] = []
var marks := PackedInt32Array()
var undo_stack := []

var elapsed := 0.0
var focused := true
var won := false
var win_clock := 0.0
var card_hidden := false
var hints_used := 0
var hint_cell := -1
var hint_text := ""
var hint_time := 0.0
var new_best := false
var best := {}  # "size" -> seconds
var daily_done := {}  # date -> seconds

var conflict_cells := {}
var bad_queens := {}

var hover_cell := -1
var hover_button := ""
var cursor := -1  # keyboard cursor, shown once the keyboard is used
var stroke_cell := -1
var stroke_prev := Mark.EMPTY
var stroke_mode := ""  # "" while it's still a tap, "mark" or "erase" once dragging
var stroke_changes := []
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
	_load()
	if mode == "daily":
		_new_daily()
	else:
		_new_practice()


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


# --- Puzzles -------------------------------------------------------------------------------

func _today() -> Dictionary:
	var date := Time.get_date_dict_from_system()
	var key := "%04d-%02d-%02d" % [date.year, date.month, date.day]
	var day := int(Time.get_unix_time_from_datetime_string(key) / 86400.0)
	var epoch := int(Time.get_unix_time_from_datetime_string(DAILY_EPOCH) / 86400.0)
	return {"key": key, "day": day, "number": day - epoch + 1, "weekday": date.weekday}


func _new_daily() -> void:
	var today := _today()
	mode = "daily"
	daily_key = today.key
	var weekday: int = (int(today.weekday) + 6) % 7
	_start_puzzle(DAILY_SIZES[weekday], today.day * 7919 + 17)
	puzzle_label = "Daily #%d" % today.number
	_save()


func _new_practice() -> void:
	mode = "practice"
	_start_puzzle(practice_size, randi())
	puzzle_label = "Practice"
	_save()


func _start_puzzle(new_size: int, seed_value: int) -> void:
	size = new_size
	var puzzle: Dictionary = GeneratorScript.new().generate(size, seed_value)
	regions = puzzle.regions
	solution = puzzle.solution
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette := REGION_COLORS.duplicate()
	for i in range(palette.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = palette[i]
		palette[i] = palette[j]
		palette[j] = tmp
	colors.clear()
	for i in size:
		colors.append(Color(palette[i]))
	marks = PackedInt32Array()
	marks.resize(size * size)
	undo_stack.clear()
	elapsed = 0.0
	won = false
	card_hidden = false
	new_best = false
	hints_used = 0
	hint_cell = -1
	hint_time = 0.0
	confetti.clear()
	cursor = -1
	stroke_cell = -1
	_update_conflicts()


# --- Rules -----------------------------------------------------------------------------------

func _update_conflicts() -> void:
	conflict_cells.clear()
	bad_queens.clear()
	var by_row := {}
	var by_col := {}
	var by_region := {}
	var queens := []
	for cell in size * size:
		if marks[cell] != Mark.QUEEN:
			continue
		queens.append(cell)
		by_row[cell / size] = by_row.get(cell / size, []) + [cell]
		by_col[cell % size] = by_col.get(cell % size, []) + [cell]
		by_region[regions[cell]] = by_region.get(regions[cell], []) + [cell]
	for row: int in by_row:
		if by_row[row].size() > 1:
			for col in size:
				conflict_cells[row * size + col] = true
			for q in by_row[row]:
				bad_queens[q] = true
	for col: int in by_col:
		if by_col[col].size() > 1:
			for row in size:
				conflict_cells[row * size + col] = true
			for q in by_col[col]:
				bad_queens[q] = true
	for region: int in by_region:
		if by_region[region].size() > 1:
			for cell in size * size:
				if regions[cell] == region:
					conflict_cells[cell] = true
			for q in by_region[region]:
				bad_queens[q] = true
	for i in queens.size():
		for j in range(i + 1, queens.size()):
			var a: int = queens[i]
			var b: int = queens[j]
			if absi(a / size - b / size) <= 1 and absi(a % size - b % size) <= 1:
				conflict_cells[a] = true
				conflict_cells[b] = true
				bad_queens[a] = true
				bad_queens[b] = true


func _queen_count() -> int:
	var count := 0
	for m in marks:
		if m == Mark.QUEEN:
			count += 1
	return count


## A cell a placed queen already rules out (shown as a faint × when auto-× is on).
func _ruled_out(cell: int) -> bool:
	var row := cell / size
	var col := cell % size
	for other in size * size:
		if other == cell or marks[other] != Mark.QUEEN:
			continue
		var r := other / size
		var c := other % size
		if r == row or c == col or regions[other] == regions[cell] or (absi(r - row) <= 1 and absi(c - col) <= 1):
			return true
	return false


func _set_mark(cell: int, value: int) -> void:
	if marks[cell] == value:
		return
	stroke_changes.append([cell, marks[cell], value])
	marks[cell] = value


func _commit(sound: String) -> void:
	if stroke_changes.is_empty():
		return
	var had_conflicts := not bad_queens.is_empty()
	undo_stack.append(stroke_changes)
	stroke_changes = []
	hint_time = 0.0
	_update_conflicts()
	if not had_conflicts and not bad_queens.is_empty():
		sfx.play("conflict")
	else:
		sfx.play(sound)
	if _queen_count() == size and bad_queens.is_empty():
		_win()


func _undo() -> void:
	if undo_stack.is_empty() or won:
		return
	var changes: Array = undo_stack.pop_back()
	for i in range(changes.size() - 1, -1, -1):
		marks[changes[i][0]] = changes[i][1]
	_update_conflicts()
	sfx.play("undo")


func _clear() -> void:
	if won:
		return
	for cell in size * size:
		_set_mark(cell, Mark.EMPTY)
	_commit("remove")


func _hint() -> void:
	if won:
		return
	hints_used += 1
	hint_time = 4.0
	sfx.play("hint")
	for cell in size * size:
		if marks[cell] == Mark.QUEEN and solution[cell / size] != cell % size:
			hint_cell = cell
			hint_text = "This queen isn't in the right spot."
			return
	for row in size:
		var cell := row * size + solution[row]
		if marks[cell] == Mark.CROSS:
			hint_cell = cell
			hint_text = "This cell was marked ×, but a queen goes here."
			return
	# Point at the queen of the smallest region still missing one.
	var best_cell := -1
	var best_count := 1 << 30
	for row in size:
		var cell := row * size + solution[row]
		if marks[cell] == Mark.QUEEN:
			continue
		var count := 0
		for other in size * size:
			if regions[other] == regions[cell]:
				count += 1
		if count < best_count:
			best_count = count
			best_cell = cell
	hint_cell = best_cell
	hint_text = "Look here: this is where a queen belongs."


func _win() -> void:
	won = true
	win_clock = 0.0
	cursor = -1
	var seconds := int(elapsed)
	var key := str(size)
	if hints_used == 0 and (not best.has(key) or seconds < int(best[key])):
		new_best = best.has(key)
		best[key] = seconds
	if mode == "daily" and not daily_done.has(daily_key):
		daily_done[daily_key] = seconds
	_save()
	sfx.play("win")
	for i in 90:
		confetti.append({
			"pos": Vector2(BOARD.get_center().x + randf_range(-200, 200), BOARD.position.y + randf_range(-40, 40)),
			"vel": Vector2(randf_range(-240, 240), randf_range(-520, -160)),
			"color": colors[i % colors.size()].darkened(0.1), "spin": randf() * TAU, "size": randf_range(5, 10), "life": 2.6,
		})


# --- Update -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	clock += delta
	if not won and focused:
		elapsed += delta
	if won:
		win_clock += delta
	hint_time = maxf(0.0, hint_time - delta)
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
	if event is InputEventMouseMotion:
		hover_button = _button_at(event.position)
		var cell := _cell_at(event.position)
		hover_cell = cell
		if stroke_cell >= 0 and cell >= 0 and cell != stroke_cell and stroke_mode == "" and not won:
			# The press became a drag: mark (or erase) × on every cell passed over.
			stroke_mode = "erase" if stroke_prev == Mark.CROSS else "mark"
			_stroke_apply(stroke_cell)
		if stroke_mode != "" and cell >= 0:
			_stroke_apply(cell)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var id := _button_at(event.position)
			if id != "":
				_press(id)
				return
			var cell := _cell_at(event.position)
			if cell >= 0 and not won:
				cursor = -1
				stroke_cell = cell
				stroke_prev = marks[cell]
				stroke_mode = ""
				stroke_changes = []
		elif stroke_cell >= 0:
			if stroke_mode == "":
				_cycle(stroke_cell)
			else:
				_commit("mark")
			stroke_cell = -1
			stroke_mode = ""
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var cell := _cell_at(event.position)
		if cell >= 0 and not won:
			_set_mark(cell, Mark.EMPTY if marks[cell] == Mark.QUEEN else Mark.QUEEN)
			_commit("queen" if marks[cell] == Mark.QUEEN else "remove")
	elif event is InputEventKey and event.pressed:
		_key(event)


func _stroke_apply(cell: int) -> void:
	if stroke_mode == "mark" and marks[cell] == Mark.EMPTY:
		_set_mark(cell, Mark.CROSS)
	elif stroke_mode == "erase" and marks[cell] == Mark.CROSS:
		_set_mark(cell, Mark.EMPTY)


## Tap: empty -> × -> queen -> empty.
func _cycle(cell: int) -> void:
	var next: int = (marks[cell] + 1) % 3
	_set_mark(cell, next)
	_commit(["remove", "mark", "queen"][next])


func _key(event: InputEventKey) -> void:
	var code := event.physical_keycode
	if code == KEY_Z:  # with or without Ctrl
		_undo()
		return
	match code:
		KEY_H:
			_hint()
		KEY_N:
			if mode == "practice":
				_new_practice()
		KEY_ESCAPE:
			if won and not card_hidden:
				card_hidden = true
	if won:
		return
	var moves := {KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0),
			KEY_W: Vector2i(0, -1), KEY_S: Vector2i(0, 1), KEY_A: Vector2i(-1, 0), KEY_D: Vector2i(1, 0)}
	if moves.has(code):
		if cursor < 0:
			cursor = (size / 2) * size + size / 2
		else:
			var step: Vector2i = moves[code]
			var col := clampi(cursor % size + step.x, 0, size - 1)
			var row := clampi(cursor / size + step.y, 0, size - 1)
			cursor = row * size + col
		sfx.play("click")
		return
	if cursor < 0:
		return
	match code:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_cycle(cursor)
		KEY_Q:
			_set_mark(cursor, Mark.EMPTY if marks[cursor] == Mark.QUEEN else Mark.QUEEN)
			_commit("queen" if marks[cursor] == Mark.QUEEN else "remove")
		KEY_X:
			_set_mark(cursor, Mark.EMPTY if marks[cursor] == Mark.CROSS else Mark.CROSS)
			_commit("mark" if marks[cursor] == Mark.CROSS else "remove")
		KEY_BACKSPACE, KEY_DELETE:
			_set_mark(cursor, Mark.EMPTY)
			_commit("remove")


func _press(id: String) -> void:
	sfx.play("click")
	if id.begins_with("size_"):
		practice_size = int(id.substr(5))
		_new_practice()
		return
	match id:
		"daily":
			if mode != "daily":
				_new_daily()
		"practice", "go_practice":
			if mode != "practice":
				_new_practice()
		"undo":
			_undo()
		"clear":
			_clear()
		"hint":
			_hint()
		"auto":
			auto_cross = not auto_cross
			_save()
		"new":
			_new_practice()
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
	list["daily"] = Rect2(40, 132, 96, 40)
	list["practice"] = Rect2(144, 132, 118, 40)
	if mode == "practice":
		for i in SIZES.size():
			list["size_%d" % SIZES[i]] = Rect2(SCREEN.x - 40 - (SIZES.size() - i) * 52 + 6, 132, 46, 40)
	if won and not card_hidden and win_clock > 0.9:
		var card := _card_rect()
		list["new" if mode == "practice" else "go_practice"] = Rect2(card.position.x + 32, card.end.y - 72, 180, 48)
		list["view"] = Rect2(card.end.x - 212, card.end.y - 72, 180, 48)
		return list
	var y := BOARD.end.y + 26
	list["undo"] = Rect2(40, y, 140, 48)
	list["clear"] = Rect2(190, y, 140, 48)
	list["hint"] = Rect2(340, y, 140, 48)
	list["auto"] = Rect2(490, y, 170, 48)
	if won and card_hidden:
		list.erase("undo")
		list.erase("clear")
		list.erase("hint")
		list["results"] = Rect2(40, y, 290, 48)
		if mode == "practice":
			list["new"] = Rect2(340, y, 140, 48)
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
	_crown(Vector2(62, 76), 38.0, INK)
	_text(Vector2(92, 92), "Queens", 38, INK, bold)
	var sub := "%s · %d×%d" % [puzzle_label, size, size]
	if mode == "daily" and daily_done.has(daily_key) and not won:
		sub += "  ·  solved today in %s" % _time(int(daily_done[daily_key]))
	_text(Vector2(40, 118), sub, 16, MUTED, font)
	var timer_rect := Rect2(SCREEN.x - 160, 50, 120, 46)
	_box(timer_rect, CARD, Color(0, 0, 0, 0.15), 23)
	_clock_icon(timer_rect.position + Vector2(26, 23), 9.0, GREEN if won else INK)
	_text(timer_rect.position + Vector2(44, 31), _time(int(elapsed)), 20, GREEN if won else INK, bold)

	var buttons := _buttons()
	_tab(buttons.get("daily", Rect2()), "Daily", mode == "daily")
	_tab(buttons.get("practice", Rect2()), "Practice", mode == "practice")
	if mode == "practice":
		for s in SIZES:
			_tab(buttons["size_%d" % s], "%d" % s, s == size)

	_draw_board()

	# Bottom controls.
	if won and card_hidden:
		_button(buttons.results, "Solved in %s  ·  See results" % _time(int(elapsed)), "results", true)
		if buttons.has("new"):
			_button(buttons.new, "New puzzle", "new")
	elif not won or card_hidden or win_clock <= 0.9:
		_button(buttons.get("undo", Rect2(40, BOARD.end.y + 26, 140, 48)), "Undo", "undo")
		_button(buttons.get("clear", Rect2(190, BOARD.end.y + 26, 140, 48)), "Clear", "clear")
		_button(buttons.get("hint", Rect2(340, BOARD.end.y + 26, 140, 48)), "Hint", "hint")
	var auto_rect: Rect2 = buttons.get("auto", Rect2(490, BOARD.end.y + 26, 170, 48))
	_toggle(auto_rect, "Auto ×", auto_cross)

	if hint_time > 0.0 and hint_cell >= 0:
		_text(Vector2(SCREEN.x / 2, BOARD.position.y - 10), hint_text, 16, BLUE, bold, true)
	else:
		_text(Vector2(SCREEN.x / 2, SCREEN.y - 26), "One queen in each row, column and color. Queens can't touch, not even diagonally.", 15, MUTED, font, true)

	for c: Dictionary in confetti:
		draw_set_transform(c.pos, c.spin, Vector2.ONE)
		draw_rect(Rect2(Vector2(-c.size / 2, -c.size / 4), Vector2(c.size, c.size / 2)), Color(c.color, minf(1.0, c.life)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if won and not card_hidden and win_clock > 0.9:
		_draw_result_card()


func _draw_board() -> void:
	var unit := BOARD.size.x / size
	_box(BOARD.grow(6), CARD, Color(0, 0, 0, 0.08), 14)
	for cell in size * size:
		var rect := _cell_rect(cell)
		var color: Color = colors[regions[cell]]
		if cell == hover_cell and not won:
			color = color.darkened(0.06)
		draw_rect(rect, color)
		if conflict_cells.has(cell):
			_stripes(rect, Color(RED, 0.32))

	# Thin grid, then thick lines where regions meet.
	for i in range(1, size):
		draw_line(BOARD.position + Vector2(i * unit, 0), BOARD.position + Vector2(i * unit, BOARD.size.y), LINE, 1.0)
		draw_line(BOARD.position + Vector2(0, i * unit), BOARD.position + Vector2(BOARD.size.x, i * unit), LINE, 1.0)
	var thick := 3.0 if size <= 8 else 2.5
	for cell in size * size:
		var rect := _cell_rect(cell)
		# Lines overlap by half their width so corners meet, but stop at the board's edge.
		if cell % size < size - 1 and regions[cell] != regions[cell + 1]:
			draw_line(Vector2(rect.end.x, maxf(rect.position.y - thick / 2, BOARD.position.y)),
					Vector2(rect.end.x, minf(rect.end.y + thick / 2, BOARD.end.y)), INK, thick)
		if cell / size < size - 1 and regions[cell] != regions[cell + size]:
			draw_line(Vector2(maxf(rect.position.x - thick / 2, BOARD.position.x), rect.end.y),
					Vector2(minf(rect.end.x + thick / 2, BOARD.end.x), rect.end.y), INK, thick)
	_box(BOARD, Color(0, 0, 0, 0), INK, 6, 3)

	for cell in size * size:
		var rect := _cell_rect(cell)
		var center := rect.get_center()
		match marks[cell]:
			Mark.QUEEN:
				var pop := 1.0
				if won:
					var t := win_clock - (cell / size) * 0.07
					if t > 0.0 and t < 0.35:
						pop = 1.0 + 0.35 * sin(t / 0.35 * PI)
				_crown(center, unit * 0.56 * pop, RED if bad_queens.has(cell) else INK)
			Mark.CROSS:
				_cross(center, unit * 0.13, Color(0, 0, 0, 0.62))
			_:
				if auto_cross and not won and _ruled_out(cell):
					_cross(center, unit * 0.11, Color(0, 0, 0, 0.26))

	if hint_time > 0.0 and hint_cell >= 0:
		var pulse := 0.5 + 0.5 * sin(clock * 8.0)
		var rect := _cell_rect(hint_cell).grow(-2)
		draw_rect(rect, Color(BLUE, 0.15 + 0.15 * pulse))
		draw_rect(rect, BLUE, false, 4.0)
	if cursor >= 0:
		draw_rect(_cell_rect(cursor).grow(-3), BLUE, false, 3.0)


func _draw_result_card() -> void:
	var appear := clampf((win_clock - 0.9) / 0.25, 0.0, 1.0)
	draw_rect(BOARD.grow(8), Color(1, 1, 1, 0.55 * appear))
	var card := _card_rect()
	card.position.y += (1.0 - appear) * 20.0
	_box(Rect2(card.position + Vector2(0, 6), card.size), Color(0, 0, 0, 0.12 * appear), Color(0, 0, 0, 0), 18)
	_box(card, Color(1, 1, 1, appear), Color(0, 0, 0, 0.1 * appear), 18)
	var cx := card.get_center().x
	_crown(Vector2(cx, card.position.y + 52), 44.0, Color(GREEN, appear))
	_text(Vector2(cx, card.position.y + 118), "You win!", 34, Color(INK, appear), bold, true)
	_text(Vector2(cx, card.position.y + 148), "%s · %d×%d" % [puzzle_label, size, size], 16, Color(MUTED, appear), font, true)
	_text(Vector2(cx, card.position.y + 206), _time(int(elapsed)), 44, Color(INK, appear), bold, true)
	var detail := ""
	if hints_used > 0:
		detail = "%d hint%s used · not counted for best time" % [hints_used, "" if hints_used == 1 else "s"]
	elif new_best:
		detail = "New best time for %d×%d!" % [size, size]
	elif best.has(str(size)):
		detail = "Best %d×%d: %s" % [size, size, _time(int(best[str(size)]))]
	_text(Vector2(cx, card.position.y + 238), detail, 15, Color(BLUE if new_best else MUTED, appear), font, true)
	var buttons := _buttons()
	if buttons.has("new"):
		_button(buttons.new, "New puzzle", "new", true)
	if buttons.has("go_practice"):
		_button(buttons.go_practice, "Play practice", "go_practice", true)
	if buttons.has("view"):
		_button(buttons.view, "View board", "view")


# --- Drawing helpers -----------------------------------------------------------------------------

func _crown(center: Vector2, width: float, color: Color) -> void:
	var w := width
	var points := PackedVector2Array()
	for p in [Vector2(-0.46, 0.26), Vector2(-0.5, -0.26), Vector2(-0.22, 0.0), Vector2(0.0, -0.4),
			Vector2(0.22, 0.0), Vector2(0.5, -0.26), Vector2(0.46, 0.26)]:
		points.append(center + p * w)
	draw_colored_polygon(points, color)
	draw_rect(Rect2(center + Vector2(-0.46, 0.32) * w, Vector2(0.92, 0.12) * w), color)
	for p in [Vector2(-0.5, -0.3), Vector2(0.0, -0.44), Vector2(0.5, -0.3)]:
		draw_circle(center + p * w, 0.075 * w, color)


func _cross(center: Vector2, arm: float, color: Color) -> void:
	var width := maxf(1.5, arm * 0.28)
	draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), color, width, true)
	draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), color, width, true)


## Red diagonal stripes over a cell, marking a broken rule.
func _stripes(rect: Rect2, color: Color) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var d := -h
	while d < w:
		var t0 := maxf(0.0, -d)
		var t1 := minf(h, w - d)
		if t0 < t1:
			draw_line(rect.position + Vector2(d + t0, h - t0), rect.position + Vector2(d + t1, h - t1), color, 2.5)
		d += 9.0


func _clock_icon(center: Vector2, radius: float, color: Color) -> void:
	draw_arc(center, radius, 0.0, TAU, 24, color, 2.0, true)
	draw_line(center, center + Vector2(0, -radius * 0.6), color, 2.0)
	draw_line(center, center + Vector2(radius * 0.45, 0), color, 2.0)


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
		_text(rect.get_center() + Vector2(0, 6), label, 17, Color.WHITE, bold, true)
	else:
		_box(rect, Color("ebebeb") if hovered else CARD, Color(0, 0, 0, 0.6), 24)
		_text(rect.get_center() + Vector2(0, 6), label, 17, INK, bold, true)


func _toggle(rect: Rect2, label: String, on: bool) -> void:
	var hovered := hover_button == "auto"
	_box(rect, (BLUE_SOFT.darkened(0.04) if hovered else BLUE_SOFT) if on else (Color("ebebeb") if hovered else CARD), BLUE if on else Color(0, 0, 0, 0.6), 24)
	_text(rect.position + Vector2(20, 30), label, 17, BLUE if on else INK, bold)
	var track := Rect2(rect.end.x - 62, rect.position.y + 14, 42, 20)
	_box(track, BLUE if on else Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 10)
	draw_circle(Vector2(track.end.x - 10 if on else track.position.x + 10, track.get_center().y), 7.0, Color.WHITE)


func _tab(rect: Rect2, label: String, active: bool) -> void:
	if rect.size == Vector2.ZERO:
		return
	var id := ""
	var buttons := _buttons()
	for key: String in buttons:
		if buttons[key] == rect:
			id = key
	var hovered := hover_button == id and id != ""
	if active:
		_box(rect, Color("01754f") if id.begins_with("size_") else INK, Color(0, 0, 0, 0), 20)
		_text(rect.get_center() + Vector2(0, 6), label, 16, Color.WHITE, bold, true)
	else:
		_box(rect, Color("ebebeb") if hovered else CARD, Color(0, 0, 0, 0.35), 20)
		_text(rect.get_center() + Vector2(0, 6), label, 16, INK, bold, true)


func _text(pos: Vector2, text: String, font_size: int, color: Color, face: Font, centered := false) -> void:
	var at := pos
	if centered:
		at.x -= face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


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
	if config.has_section("daily"):
		for key in config.get_section_keys("daily"):
			daily_done[key] = int(config.get_value("daily", key))
	auto_cross = bool(config.get_value("settings", "auto_cross", true))
	practice_size = int(config.get_value("settings", "practice_size", 8))
	if not SIZES.has(practice_size):
		practice_size = 8
	mode = str(config.get_value("settings", "mode", "daily"))


func _save() -> void:
	var config := ConfigFile.new()
	for key in best:
		config.set_value("best", key, best[key])
	for key in daily_done:
		config.set_value("daily", key, daily_done[key])
	config.set_value("settings", "auto_cross", auto_cross)
	config.set_value("settings", "practice_size", practice_size)
	config.set_value("settings", "mode", mode)
	config.save(SAVE_PATH)
