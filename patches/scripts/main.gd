extends Node2D
## Patches: cover the whole grid with rectangular patches. Each patch holds exactly one clue
## and must match it: the number is the patch's area, the shape says square, wide or tall.
## Drag to draw a patch (drawing over patches replaces them). Tap a patch to remove it.
## Keys: arrows move, Space starts and finishes a patch, Backspace removes, Z undoes, H hints.

const GeneratorScript := preload("res://scripts/generator.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const SCREEN := Vector2(700, 940)
const BOARD := Rect2(40, 196, 620, 620)
## Difficulty levels: bigger boards, and fewer clues that show both their number and shape.
const LEVELS := [
	{"name": "Easy", "size": 5, "full_clues": 0.6},
	{"name": "Medium", "size": 7, "full_clues": 0.3},
	{"name": "Hard", "size": 9, "full_clues": 0.1},
]
const SAVE_PATH := "user://patches.cfg"

enum Shape { SQUARE, WIDE, TALL }

# LinkedIn-like look.
const BG := Color("f4f2ee")
const CARD := Color.WHITE
const INK := Color(0, 0, 0, 0.9)
const MUTED := Color(0, 0, 0, 0.6)
const LINE := Color(0, 0, 0, 0.12)
const BLUE := Color("0a66c2")
const RED := Color("d5000f")
const GREEN := Color("057642")
const EMPTY_PATCH := Color("d9d6d0")
const PALETTE := ["6f5ce0", "f08a24", "2f8fd8", "3fae6a", "e05297", "d9a21b", "1f9e9e", "d64545", "8c6bd6", "6f9e2c",
		"4b6fd8", "c96b2c", "b04fb0", "2c9c86", "e07a5f", "5a7d9a", "a67c52", "c2410c", "0e7490", "9333ea"]

var level := 1
var size := 7

var clues := []  # {cell, area, shape, show_area, show_shape}
var clue_colors: Array[Color] = []
var clue_at := PackedInt32Array()
var solution := []  # Rect2i per clue
var patches: Array[Rect2i] = []
var cell_patch := PackedInt32Array()  # patch index per cell, or -1
var patch_clue := PackedInt32Array()  # clue index per patch; -1 none, -2 several
var patch_ok := PackedByteArray()
var undo_stack := []

var elapsed := 0.0
var focused := true
var won := false
var win_clock := 0.0
var card_hidden := false
var hints_used := 0
var hint_rect := Rect2i()
var hint_text := ""
var hint_time := 0.0
var new_best := false
var best := {}  # level name -> seconds

var hover_cell := -1
var hover_button := ""
var anchor := -1  # where the patch being drawn started (mouse or keyboard)
var drag_cell := -1
var dragging := false
var moved := false
var cursor := -1
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


# --- Puzzles -------------------------------------------------------------------------------

## A fresh random puzzle at the current difficulty level.
func _new_game() -> void:
	_start_puzzle(LEVELS[level].size, randi())
	_save()


func _level_name() -> String:
	return LEVELS[level].name


func _start_puzzle(new_size: int, seed_value: int) -> void:
	size = new_size
	var puzzle: Dictionary = GeneratorScript.new().generate(size, seed_value, LEVELS[level].full_clues)
	clues = puzzle.clues
	solution = puzzle.solution
	clue_at = PackedInt32Array()
	clue_at.resize(size * size)
	clue_at.fill(-1)
	for i in clues.size():
		clue_at[clues[i].cell] = i
	_color_clues(seed_value)
	patches.clear()
	undo_stack.clear()
	elapsed = 0.0
	won = false
	card_hidden = false
	new_best = false
	hints_used = 0
	hint_time = 0.0
	confetti.clear()
	cursor = -1
	anchor = -1
	dragging = false
	_refresh()


## Neighboring patches of the solution get different colors, so the finished board reads clearly.
func _color_clues(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette := PALETTE.duplicate()
	for i in range(palette.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = palette[i]
		palette[i] = palette[j]
		palette[j] = tmp
	var picked := PackedInt32Array()
	picked.resize(clues.size())
	picked.fill(-1)
	var uses := PackedInt32Array()
	uses.resize(palette.size())
	for i in clues.size():
		var near := {}
		var a: Rect2i = solution[i]
		for j in i:
			if a.grow(1).intersects(solution[j]):
				near[picked[j]] = true
		var choice := -1
		for k in palette.size():
			if not near.has(k) and (choice < 0 or uses[k] < uses[choice]):
				choice = k
		picked[i] = maxi(choice, 0)
		uses[picked[i]] += 1
	clue_colors.clear()
	for i in clues.size():
		clue_colors.append(Color(palette[picked[i]]))


# --- Rules -----------------------------------------------------------------------------------

func _refresh() -> void:
	cell_patch = PackedInt32Array()
	cell_patch.resize(size * size)
	cell_patch.fill(-1)
	patch_clue = PackedInt32Array()
	patch_ok = PackedByteArray()
	for p in patches.size():
		var rect := patches[p]
		var clue := -1
		for y in rect.size.y:
			for x in rect.size.x:
				var cell := (rect.position.y + y) * size + rect.position.x + x
				cell_patch[cell] = p
				if clue_at[cell] >= 0:
					clue = clue_at[cell] if clue == -1 else -2
		patch_clue.append(clue)
		patch_ok.append(1 if clue >= 0 and GeneratorScript.fits(clues[clue], rect.size) else 0)


func _is_solved() -> bool:
	if cell_patch.has(-1):
		return false
	return not patch_ok.has(0)


func _rect_between(a: int, b: int) -> Rect2i:
	var ax := a % size
	var ay := a / size
	var bx := b % size
	var by := b / size
	return Rect2i(mini(ax, bx), mini(ay, by), absi(ax - bx) + 1, absi(ay - by) + 1)


## Draws a patch, replacing any patches it overlaps.
func _place(rect: Rect2i) -> void:
	undo_stack.append(patches.duplicate())
	var kept: Array[Rect2i] = []
	for p in patches:
		if not p.intersects(rect):
			kept.append(p)
	kept.append(rect)
	patches = kept
	hint_time = 0.0
	_refresh()
	var index := patches.size() - 1
	if patch_ok[index]:
		sfx.play("queen")
	elif patch_clue[index] == -2 or (patch_clue[index] >= 0 and not patch_ok[index]):
		sfx.play("conflict")
	else:
		sfx.play("mark")
	if _is_solved():
		_win()


func _remove_at(cell: int) -> void:
	if cell_patch[cell] < 0:
		return
	undo_stack.append(patches.duplicate())
	patches.remove_at(cell_patch[cell])
	hint_time = 0.0
	_refresh()
	sfx.play("remove")


func _undo() -> void:
	if undo_stack.is_empty() or won:
		return
	patches = undo_stack.pop_back()
	_refresh()
	sfx.play("undo")


func _clear() -> void:
	if won or patches.is_empty():
		return
	undo_stack.append(patches.duplicate())
	patches.clear()
	_refresh()
	sfx.play("remove")


func _hint() -> void:
	if won:
		return
	hints_used += 1
	hint_time = 4.0
	sfx.play("hint")
	for p in patches:
		if not solution.has(p):
			hint_rect = p
			hint_text = "This patch isn't right. Try reshaping it."
			return
	# Suggest the smallest missing patch.
	var pick := -1
	for i in solution.size():
		if patches.has(solution[i]):
			continue
		if pick < 0 or solution[i].get_area() < solution[pick].get_area():
			pick = i
	if pick >= 0:
		hint_rect = solution[pick]
		hint_text = "A patch fits exactly here."


func _win() -> void:
	won = true
	win_clock = 0.0
	cursor = -1
	anchor = -1
	var seconds := int(elapsed)
	var key := _level_name()
	if hints_used == 0 and (not best.has(key) or seconds < int(best[key])):
		new_best = best.has(key)
		best[key] = seconds
	_save()
	sfx.play("win")
	for i in 90:
		confetti.append({
			"pos": Vector2(BOARD.get_center().x + randf_range(-200, 200), BOARD.position.y + randf_range(-40, 40)),
			"vel": Vector2(randf_range(-240, 240), randf_range(-520, -160)),
			"color": clue_colors[i % clue_colors.size()], "spin": randf() * TAU, "size": randf_range(5, 10), "life": 2.6,
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
		hover_cell = _cell_at(event.position)
		if dragging:
			var cell := _cell_at(event.position, true)
			if cell != drag_cell:
				drag_cell = cell
				moved = moved or cell != anchor
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var id := _button_at(event.position)
			if id != "":
				_press(id)
				return
			var cell := _cell_at(event.position)
			if cell >= 0 and not won:
				cursor = -1
				anchor = cell
				drag_cell = cell
				dragging = true
				moved = false
		elif dragging:
			dragging = false
			if moved:
				_place(_rect_between(anchor, drag_cell))
			elif cell_patch[anchor] >= 0:
				_remove_at(anchor)
			else:
				_place(Rect2i(anchor % size, anchor / size, 1, 1))
			anchor = -1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var cell := _cell_at(event.position)
		if dragging:
			dragging = false
			anchor = -1
		elif cell >= 0 and not won:
			_remove_at(cell)
	elif event is InputEventKey and event.pressed:
		_key(event)


func _key(event: InputEventKey) -> void:
	var code := event.physical_keycode
	match code:
		KEY_Z:
			_undo()
			return
		KEY_H:
			_hint()
			return
		KEY_N:
			_new_game()
			return
		KEY_ESCAPE:
			if won and not card_hidden:
				card_hidden = true
			anchor = -1
			return
	if won:
		return
	var moves := {KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0),
			KEY_W: Vector2i(0, -1), KEY_S: Vector2i(0, 1), KEY_A: Vector2i(-1, 0), KEY_D: Vector2i(1, 0)}
	if moves.has(code):
		if cursor < 0:
			cursor = (size / 2) * size + size / 2
		else:
			var step: Vector2i = moves[code]
			cursor = clampi(cursor / size + step.y, 0, size - 1) * size + clampi(cursor % size + step.x, 0, size - 1)
		sfx.play("click")
		return
	if cursor < 0:
		return
	match code:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if anchor < 0:
				anchor = cursor
				sfx.play("click")
			else:
				_place(_rect_between(anchor, cursor))
				anchor = -1
		KEY_BACKSPACE, KEY_DELETE:
			_remove_at(cursor)


func _press(id: String) -> void:
	sfx.play("click")
	if id.begins_with("level_"):
		level = int(id.substr(6))
		_new_game()
		return
	match id:
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


func _grid_rect(rect: Rect2i) -> Rect2:
	var unit := BOARD.size.x / size
	return Rect2(BOARD.position + Vector2(rect.position) * unit, Vector2(rect.size) * unit)


## Cell under a point; with `snap`, points outside the board snap to the nearest cell.
func _cell_at(pos: Vector2, snap := false) -> int:
	if not snap and not BOARD.has_point(pos):
		return -1
	var unit := BOARD.size.x / size
	var col := clampi(floori((pos.x - BOARD.position.x) / unit), 0, size - 1)
	var row := clampi(floori((pos.y - BOARD.position.y) / unit), 0, size - 1)
	return row * size + col


func _buttons() -> Dictionary:
	var list := {}
	# Difficulty chips on the left, New game on the right.
	var x := 40.0
	for i in LEVELS.size():
		var width: float = bold.get_string_size(LEVELS[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0
		list["level_%d" % i] = Rect2(x, 132, width, 40)
		x += width + 6.0
	list["new"] = Rect2(SCREEN.x - 40 - 124, 132, 124, 40)
	if won and not card_hidden and win_clock > 0.9:
		var card := _card_rect()
		list["new"] = Rect2(card.position.x + 32, card.end.y - 72, 180, 48)
		list["view"] = Rect2(card.end.x - 212, card.end.y - 72, 180, 48)
		return list
	var y := BOARD.end.y + 26
	if won and card_hidden:
		list["results"] = Rect2(40, y, 620, 48)
		return list
	list["undo"] = Rect2(40, y, 200, 48)
	list["clear"] = Rect2(250, y, 200, 48)
	list["hint"] = Rect2(460, y, 200, 48)
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
	_logo(Vector2(40, 52), 34.0)
	_text(Vector2(84, 92), "Patches", 38, INK, bold)
	var sub := "%s · %d×%d" % [_level_name(), size, size]
	if best.has(_level_name()):
		sub += "  ·  best %s" % _time(int(best[_level_name()]))
	_text(Vector2(40, 118), sub, 16, MUTED, font)
	var timer_rect := Rect2(SCREEN.x - 160, 50, 120, 46)
	_box(timer_rect, CARD, Color(0, 0, 0, 0.15), 23)
	_clock_icon(timer_rect.position + Vector2(26, 23), 9.0, GREEN if won else INK)
	_text(timer_rect.position + Vector2(44, 31), _time(int(elapsed)), 20, GREEN if won else INK, bold)

	var buttons := _buttons()
	for i in LEVELS.size():
		_tab(buttons["level_%d" % i], LEVELS[i].name, i == level, "level_%d" % i)
	if not (won and not card_hidden and win_clock > 0.9):
		_button(buttons.new, "New game", "new", true)

	_draw_board()

	if won and card_hidden:
		_button(buttons.results, "Solved in %s  ·  See results" % _time(int(elapsed)), "results", true)
	elif not won or win_clock <= 0.9:
		var y := BOARD.end.y + 26
		_button(buttons.get("undo", Rect2(40, y, 200, 48)), "Undo", "undo")
		_button(buttons.get("clear", Rect2(250, y, 200, 48)), "Clear", "clear")
		_button(buttons.get("hint", Rect2(460, y, 200, 48)), "Hint", "hint")

	if hint_time > 0.0:
		_text(Vector2(SCREEN.x / 2, BOARD.position.y - 10), hint_text, 16, BLUE, bold, true)
	else:
		_text(Vector2(SCREEN.x / 2, SCREEN.y - 26), "Fill the grid with rectangles. Each holds one clue: its size and its shape.", 15, MUTED, font, true)

	for c: Dictionary in confetti:
		draw_set_transform(c.pos, c.spin, Vector2.ONE)
		draw_rect(Rect2(Vector2(-c.size / 2, -c.size / 4), Vector2(c.size, c.size / 2)), Color(c.color, minf(1.0, c.life)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if won and not card_hidden and win_clock > 0.9:
		_draw_result_card()


func _draw_board() -> void:
	var unit := BOARD.size.x / size
	_box(BOARD.grow(6), CARD, Color(0, 0, 0, 0.08), 14)
	draw_rect(BOARD, CARD)
	if hover_cell >= 0 and not dragging and not won and cell_patch[hover_cell] < 0:
		draw_rect(_cell_rect(hover_cell), Color(0, 0, 0, 0.04))
	for i in range(1, size):
		draw_line(BOARD.position + Vector2(i * unit, 0), BOARD.position + Vector2(i * unit, BOARD.size.y), LINE, 1.0)
		draw_line(BOARD.position + Vector2(0, i * unit), BOARD.position + Vector2(BOARD.size.x, i * unit), LINE, 1.0)

	# Placed patches.
	for p in patches.size():
		var clue := patch_clue[p]
		var base := clue_colors[clue] if clue >= 0 else EMPTY_PATCH
		var rect := _grid_rect(patches[p]).grow(-3)
		var pop := 1.0
		if won:
			var t := win_clock - (patches[p].position.y + patches[p].position.x) * 0.045
			if t > 0.0 and t < 0.3:
				pop = 1.0 + 0.05 * sin(t / 0.3 * PI)
		rect = rect.grow((pop - 1.0) * rect.size.x * 0.5)
		_box(rect, base.lerp(Color.WHITE, 0.62), base.darkened(0.05), 10, 3)
		if not patch_ok[p]:
			_stripes(rect.grow(-3), Color(RED, 0.35))

	# Patch being drawn.
	var drawing := Rect2i()
	var drawing_active := false
	if dragging and anchor >= 0:
		drawing = _rect_between(anchor, drag_cell)
		drawing_active = true
	elif anchor >= 0 and cursor >= 0:
		drawing = _rect_between(anchor, cursor)
		drawing_active = true
	if drawing_active:
		var clue := -1
		for y in drawing.size.y:
			for x in drawing.size.x:
				var c := clue_at[(drawing.position.y + y) * size + drawing.position.x + x]
				if c >= 0:
					clue = c if clue == -1 else -2
		var base := clue_colors[clue] if clue >= 0 else Color("9a9a9a")
		var rect := _grid_rect(drawing).grow(-3)
		_box(rect, Color(base.lerp(Color.WHITE, 0.45), 0.75), base, 10, 3)
		var label := "%d×%d" % [drawing.size.x, drawing.size.y]
		var width := bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 16
		var chip := Rect2(rect.position + Vector2(6, 6), Vector2(width, 24))
		_box(chip, INK, Color(0, 0, 0, 0), 12)
		_text(chip.position + Vector2(8, 17), label, 15, Color.WHITE, bold)

	# Clues on top.
	for i in clues.size():
		_clue(i)

	_box(BOARD, Color(0, 0, 0, 0), INK, 6, 3)

	if hint_time > 0.0:
		var pulse := 0.5 + 0.5 * sin(clock * 8.0)
		var rect := _grid_rect(hint_rect).grow(-1)
		draw_rect(rect, Color(BLUE, 0.12 + 0.12 * pulse))
		_box(rect, Color(0, 0, 0, 0), BLUE, 10, 4)
	if cursor >= 0:
		draw_rect(_cell_rect(cursor).grow(-4), BLUE, false, 3.0)


func _clue(index: int) -> void:
	var clue: Dictionary = clues[index]
	var rect := _cell_rect(clue.cell)
	var unit := rect.size.x
	var center := rect.get_center()
	var color := clue_colors[index]
	var badge := Rect2(center - Vector2(unit, unit) * 0.34, Vector2(unit, unit) * 0.68)
	_box(badge, color, Color(0, 0, 0, 0), int(unit * 0.16))
	var number_size := int(unit * (0.3 if not clue.show_shape else 0.24))
	if clue.show_shape:
		var dims := Vector2(0.4, 0.4)
		match int(clue.shape):
			Shape.WIDE:
				dims = Vector2(0.5, 0.3)
			Shape.TALL:
				dims = Vector2(0.3, 0.5)
		var outline := Rect2(center - dims * unit * 0.5, dims * unit)
		_box(outline, Color(0, 0, 0, 0), Color.WHITE, int(unit * 0.05), maxi(2, int(unit * 0.035)))
	if clue.show_area:
		var label := str(clue.area)
		if label.length() > 1 and clue.show_shape and int(clue.shape) == Shape.TALL:
			number_size = int(number_size * 0.78)  # two digits inside the narrow tall outline
		var width := bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
		draw_string(bold, center + Vector2(-width / 2.0, number_size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, Color.WHITE)


func _draw_result_card() -> void:
	var appear := clampf((win_clock - 0.9) / 0.25, 0.0, 1.0)
	draw_rect(BOARD.grow(8), Color(1, 1, 1, 0.55 * appear))
	var card := _card_rect()
	card.position.y += (1.0 - appear) * 20.0
	_box(Rect2(card.position + Vector2(0, 6), card.size), Color(0, 0, 0, 0.12 * appear), Color(0, 0, 0, 0), 18)
	_box(card, Color(1, 1, 1, appear), Color(0, 0, 0, 0.1 * appear), 18)
	var cx := card.get_center().x
	_logo(Vector2(cx - 22, card.position.y + 30), 44.0, appear)
	_text(Vector2(cx, card.position.y + 118), "You win!", 34, Color(INK, appear), bold, true)
	_text(Vector2(cx, card.position.y + 148), "%s · %d×%d" % [_level_name(), size, size], 16, Color(MUTED, appear), font, true)
	_text(Vector2(cx, card.position.y + 206), _time(int(elapsed)), 44, Color(INK, appear), bold, true)
	var detail := ""
	if hints_used > 0:
		detail = "%d hint%s used · not counted for best time" % [hints_used, "" if hints_used == 1 else "s"]
	elif new_best:
		detail = "New best time on %s!" % _level_name()
	elif best.has(_level_name()):
		detail = "Best on %s: %s" % [_level_name(), _time(int(best[_level_name()]))]
	_text(Vector2(cx, card.position.y + 238), detail, 15, Color(BLUE if new_best else MUTED, appear), font, true)
	var buttons := _buttons()
	if buttons.has("new"):
		_button(buttons.new, "New game", "new", true)
	if buttons.has("view"):
		_button(buttons.view, "View board", "view")


# --- Drawing helpers -----------------------------------------------------------------------------

## The game's mark: four colored patches in a rounded square.
func _logo(origin: Vector2, extent: float, alpha := 1.0) -> void:
	var g := extent * 0.06
	var half := (extent - g) / 2.0
	var parts := [
		[Rect2(origin, Vector2(half, extent)), Color("6f5ce0")],
		[Rect2(origin + Vector2(half + g, 0), Vector2(half, half)), Color("f08a24")],
		[Rect2(origin + Vector2(half + g, half + g), Vector2(half, half)), Color("3fae6a")],
	]
	for part in parts:
		_box(part[0], Color(part[1], alpha), Color(0, 0, 0, 0), int(extent * 0.14))


func _stripes(rect: Rect2, color: Color) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var d := -h
	while d < w:
		var t0 := maxf(0.0, -d)
		var t1 := minf(h, w - d)
		if t0 < t1:
			draw_line(rect.position + Vector2(d + t0, h - t0), rect.position + Vector2(d + t1, h - t1), color, 2.5)
		d += 10.0


func _clock_icon(center: Vector2, radius: float, color: Color) -> void:
	draw_arc(center, radius, 0.0, TAU, 24, color, 2.0, true)
	draw_line(center, center + Vector2(0, -radius * 0.6), color, 2.0)
	draw_line(center, center + Vector2(radius * 0.45, 0), color, 2.0)


func _box(rect: Rect2, fill: Color, border: Color, radius: int, border_width := 1) -> void:
	var key := "%s|%s|%d|%d" % [fill.to_html(), border.to_html(), radius, border_width]
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


func _tab(rect: Rect2, label: String, active: bool, id: String) -> void:
	if active:
		_box(rect, Color("01754f") if id.begins_with("level_") else INK, Color(0, 0, 0, 0), 20)
		_text(rect.get_center() + Vector2(0, 6), label, 16, Color.WHITE, bold, true)
	else:
		_box(rect, Color("ebebeb") if hover_button == id else CARD, Color(0, 0, 0, 0.35), 20)
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
	level = clampi(int(config.get_value("settings", "level", 1)), 0, LEVELS.size() - 1)


func _save() -> void:
	var config := ConfigFile.new()
	for key in best:
		config.set_value("best", key, best[key])
	config.set_value("settings", "level", level)
	config.save(SAVE_PATH)
