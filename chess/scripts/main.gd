extends Node2D
## Chess against the computer (three levels) or for two players on one screen. Every rule is in:
## castling, en passant, promotion, check, checkmate and the draws (stalemate, threefold repetition,
## the fifty-move rule and insufficient material). Drag a piece, or click it and then its target.
## Keys: arrows move the cursor, Enter / Space pick up and put down, Esc cancels, U undoes, H hints,
## F flips the board, N opens a new game. Xbox gamepads work too (see _pad_input).
## The computer searches in a thread (scripts/engine.gd), so the window keeps responding.
## The game in progress, the settings and the statistics are saved after every move.

const ChessEngine := preload("res://scripts/engine.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const StringsScript := preload("res://scripts/strings.gd")

const WHITE := ChessEngine.WHITE
const BLACK := ChessEngine.BLACK
const PAWN := ChessEngine.PAWN
const KNIGHT := ChessEngine.KNIGHT
const BISHOP := ChessEngine.BISHOP
const ROOK := ChessEngine.ROOK
const QUEEN := ChessEngine.QUEEN
const KING := ChessEngine.KING

const SCREEN := Vector2(1280, 720)
const SQ := 80.0
const BOARD := Rect2(48, 40, 640, 640)
const SIDE := Rect2(728, 40, 504, 640)  # everything right of the board
const TOP_CARD := Rect2(728, 108, 504, 64)
const MOVE_LIST := Rect2(728, 184, 504, 360)
const BOTTOM_CARD := Rect2(728, 556, 504, 64)
const PANEL := Rect2(340, 84, 600, 552)  # new game, settings and statistics
const ROW_H := 30.0
const SAVE_PATH := "user://chess.cfg"
## Computer levels: search depth, time limit (ms) and random noise (centipawns) on its choices.
## `name` keys the saved statistics.
const LEVELS := [
	{"name": "Easy", "key": "level_easy", "depth": 1, "time": 500, "noise": 150},
	{"name": "Medium", "key": "level_medium", "depth": 3, "time": 1500, "noise": 25},
	{"name": "Hard", "key": "level_hard", "depth": 32, "time": 2500, "noise": 0},
]
const HINT_SEARCH := {"depth": 32, "time": 1200, "noise": 0}
const THEMES := [
	{"key": "theme_wood", "light": Color("f0d9b5"), "dark": Color("b58863")},
	{"key": "theme_green", "light": Color("ebecd0"), "dark": Color("739552")},
	{"key": "theme_blue", "light": Color("dee3e6"), "dark": Color("8ca2ad")},
]
const SETTING_ROWS := ["set_sound", "set_moves", "set_coords"]
const COLOR_CHOICES := ["white", "random", "black"]
const PROMOTIONS := [QUEEN, KNIGHT, ROOK, BISHOP]  # in the order the picker shows them
const MIN_THINK := 0.55  # the computer never answers faster than this (seconds)
const ANIM_TIME := 0.2
const CARD_DELAY := 0.8  # the result card shows this long after the last move
const STICK_PRESS := 0.5  # left stick counts as a direction past this
const STICK_RELEASE := 0.3  # and lets go under this
const PAD_REPEAT_DELAY := 0.32  # holding a direction: wait this long, then
const PAD_REPEAT := 0.1  # move again this often
const OUTLINE := 0.034  # piece outline width; piece shapes are in units of one square

const BG := Color("211f1c")
const CARD := Color("2e2b27")
const RAISED := Color("3b3732")
const RAISED_HOVER := Color("48433d")
const INK := Color("eeeae3")
const MUTED := Color("9d968c")
const ACCENT := Color("81b64c")
const GOLD := Color("f0c05a")
const RED := Color("e8625a")
const FOCUS := Color("5aa9ff")
const LAST_MOVE := Color(0.98, 0.86, 0.25, 0.42)
const SELECTED := Color(0.42, 0.78, 0.3, 0.6)
const TARGET := Color(0.1, 0.18, 0.05, 0.3)
const HINT_ARROW := Color(0.3, 0.62, 1.0, 0.85)
const WHITE_FILL := Color("fbf8f1")
const WHITE_EDGE := Color("25221f")
const BLACK_FILL := Color("36322e")
const BLACK_EDGE := Color("110f0d")
const BLACK_DETAIL := Color("d9d1c5")
const BLACK_FILL_UI := Color("4d4843")  # black pieces drawn on the dark side panel
const BLACK_EDGE_UI := Color("cfc6b9")

var engine  # the game on screen
var ai  # a copy of it that the computer searches
var thread: Thread
var use_threads := true
var thinking := ""  # "", "move" or "hint": what the computer is looking for
var think_clock := 0.0
var think_args := []
var think_result := -1  # -1 while the search runs

# The game on screen.
var mode := "computer"  # "computer" or "two"
var level := 1
var human := WHITE  # the player's color against the computer
var color_pick := "white"  # how `human` was chosen, for Play again
var flipped := false
var moves_played: Array[int] = []
var records := []  # the notation of every move, see engine.notation()
var legal := PackedInt32Array()
var result := ""  # "", "white", "black" or "draw"
var reason := ""  # how it ended: checkmate, stalemate, repetition, fifty or material
var recorded := false  # the result is in the statistics, so undo and replay don't count it twice
var over_clock := 0.0
var card_hidden := false

# New game choices, remembered for next time.
var pick_mode := "computer"
var pick_level := 1
var pick_color := "white"

# Settings and statistics.
var language := ""
var sound_on := true
var show_moves := true
var show_coords := true
var theme := 0
var stats := {}
var reset_armed := false

# Board interaction.
var selected := -1
var drag_from := -1
var dragging := false
var drag_pos := Vector2.ZERO
var press_pos := Vector2.ZERO
var press_was_selected := false
var promo_from := -1  # a pawn waiting for the player to pick its promotion
var promo_to := -1
var promo_animate := true
var promo_focus := 0
var hover_square := -1
var hint_move := 0
var cursor := -1  # keyboard / gamepad cursor on the board
var anims := []  # pieces sliding to their new squares: {piece, from, to}
var anim_t := 1.0
var fading := {}  # the captured piece, shown until the capturing piece arrives: {piece, square}
var move_scroll := 0  # move list rows scrolled up from the newest

# Screen and navigation.
var panel := ""  # "new", "settings", "stats" or ""
var hover_button := ""
var focus := ""  # button selected with the keyboard or gamepad
var nav_active := false  # keyboard or gamepad navigation in use (the mouse turns it off)
var using_pad := false
var pad_device := 0
var stick := Vector2.ZERO
var stick_dir := Vector2i.ZERO
var held_dir := Vector2i.ZERO
var repeat_timer := 0.0
var clock := 0.0

var font: Font
var bold: Font
var styles := {}
var shapes := {}  # piece type -> its drawing, see _build_pieces()
var sfx
var icon_mode := false  # this copy only draws the app icon (see _render_icon)


func _ready() -> void:
	_build_pieces()
	if icon_mode:
		return
	if "--render-icon" in OS.get_cmdline_user_args():
		_render_icon()
		return
	font = _font(400)
	bold = _font(700)
	sfx = SfxScript.new()
	add_child(sfx)
	StringsScript.install()
	engine = ChessEngine.new()
	use_threads = not OS.has_feature("web") or OS.has_feature("threads")
	stats = _empty_stats()
	var saved := _load()
	if language == "":
		language = StringsScript.system_language()
	_apply_settings()
	if saved.is_empty():
		_start_game(false)
		panel = "new"  # first run: choose how to play
	else:
		_restore(saved)


func _exit_tree() -> void:
	if engine != null:
		_stop_think()


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


# --- Game --------------------------------------------------------------------------------------

## A new game with the choices from the New game panel.
func _start_game(announce := true) -> void:
	_stop_think()
	mode = pick_mode
	level = pick_level
	color_pick = pick_color
	match pick_color:
		"white":
			human = WHITE
		"black":
			human = BLACK
		_:
			human = randi() % 2
	flipped = mode == "computer" and human == BLACK
	engine.reset()
	moves_played.clear()
	records.clear()
	result = ""
	reason = ""
	recorded = false
	card_hidden = false
	cursor = -1
	_clear_board_state()
	legal = engine.legal_moves()
	if announce:
		sfx.play("start")
	_save()
	_after_turn()


## Replays a saved game.
func _restore(game: Dictionary) -> void:
	mode = game.mode
	level = game.level
	human = game.human
	color_pick = game.color_pick
	flipped = game.flipped
	engine.reset()
	for text: String in game.moves:
		var m: int = engine.find_uci(text)
		if m == 0:
			break
		records.append(engine.notation(m))
		engine.make_move(m)
		moves_played.append(m)
	legal = engine.legal_moves()
	recorded = game.recorded
	_check_end(false)
	_after_turn()


func _clear_board_state() -> void:
	selected = -1
	drag_from = -1
	dragging = false
	promo_from = -1
	promo_to = -1
	hint_move = 0
	anims.clear()
	fading = {}
	anim_t = 1.0
	move_scroll = 0


func _computer_turn() -> bool:
	return mode == "computer" and result == "" and engine.side != human


## The player may move a piece now.
func _can_play() -> bool:
	return result == "" and panel == "" and promo_to < 0 and thinking != "move" and not _computer_turn()


func _can_undo() -> bool:
	if mode == "two":
		return not moves_played.is_empty()
	# Keep at least one move of the player's to take back.
	return moves_played.size() >= (1 if human == WHITE else 2)


func _own_piece(sq: int) -> bool:
	var p: int = engine.board[sq]
	return p > 0 and (p >> 3) == engine.side


func _find_move(from: int, to: int) -> int:
	for m in legal:
		if ChessEngine.move_from(m) == from and ChessEngine.move_to(m) == to:
			return m
	return 0


## Moves from `from` to `to`, first asking which piece a promoting pawn becomes.
func _try_move(from: int, to: int, animate: bool) -> void:
	var options := []
	for m in legal:
		if ChessEngine.move_from(m) == from and ChessEngine.move_to(m) == to:
			options.append(m)
	if options.is_empty():
		return
	if options.size() > 1:
		promo_from = from
		promo_to = to
		promo_animate = animate
		promo_focus = 0
		selected = -1
		sfx.play("select")
		return
	_do_move(options[0], animate)


func _promote(index: int) -> void:
	for m in legal:
		if ChessEngine.move_from(m) == promo_from and ChessEngine.move_to(m) == promo_to \
				and ChessEngine.move_promo(m) == PROMOTIONS[index]:
			promo_from = -1
			promo_to = -1
			# The pawn already stands on the last row while the picker is open.
			_do_move(m, false)
			return


func _cancel_promo() -> void:
	if promo_to >= 0:
		selected = promo_from
		promo_from = -1
		promo_to = -1
		sfx.play("click")


func _do_move(m: int, animate: bool) -> void:
	if thinking == "hint":
		_stop_think()
	var from := ChessEngine.move_from(m)
	var to := ChessEngine.move_to(m)
	var flags := ChessEngine.move_flags(m)
	var mover: int = engine.side
	var taken_at := to
	if flags & ChessEngine.FLAG_EP:
		taken_at = to + (10 if mover == WHITE else -10)
	var captured: int = engine.board[taken_at]
	records.append(engine.notation(m))
	engine.make_move(m)
	moves_played.append(m)

	anims.clear()
	fading = {}
	if animate:
		anims.append({"piece": engine.board[to], "from": from, "to": to})
		if captured > 0:
			fading = {"piece": captured, "square": taken_at}
	if flags & ChessEngine.FLAG_CASTLE:
		# The rook always slides, even when the king was dropped by hand.
		var rook_from := to + 1 if to % 10 == 7 else to - 2
		var rook_to := to - 1 if to % 10 == 7 else to + 1
		anims.append({"piece": engine.board[rook_to], "from": rook_from, "to": rook_to})
	anim_t = 0.0 if not anims.is_empty() else 1.0

	selected = -1
	hint_move = 0
	move_scroll = 0
	legal = engine.legal_moves()
	var checked: bool = engine.in_check()
	if checked:
		sfx.play("check")
		_rumble(0.4, 0.4, 0.15)
	elif ChessEngine.move_promo(m):
		sfx.play("promote")
	elif flags & ChessEngine.FLAG_CASTLE:
		sfx.play("castle")
	elif captured > 0:
		sfx.play("capture")
		_rumble(0.3, 0.1, 0.08)
	else:
		sfx.play("move")
	_check_end()
	_save()
	_after_turn()


func _after_turn() -> void:
	if _computer_turn():
		_start_think("move")


## Ends the game if the position is checkmate or a draw. `announce` false: restoring a saved game.
func _check_end(announce := true) -> void:
	var status: String = engine.status(legal.size())
	if status == "":
		return
	reason = status
	if status == "checkmate":
		result = "black" if engine.side == WHITE else "white"
	else:
		result = "draw"
	card_hidden = false
	selected = -1
	hint_move = 0
	cursor = -1
	if not announce:
		over_clock = CARD_DELAY + 1.0
		return
	over_clock = 0.0
	if not recorded:
		_record()
	if result == "draw":
		sfx.play("draw")
	elif mode == "two" or result == _color_name(human):
		sfx.play("win")
		_rumble(0.5, 0.6, 0.4)
	else:
		sfx.play("lose")


func _record() -> void:
	recorded = true
	if mode == "two":
		stats.two_player += 1
	else:
		var data: Dictionary = stats.levels[LEVELS[level].name]
		data.played += 1
		if result == "draw":
			data.drawn += 1
		elif result == _color_name(human):
			data.won += 1
		else:
			data.lost += 1


func _undo() -> void:
	if panel != "" or promo_to >= 0 or not _can_undo():
		return
	_stop_think()
	var count := 1
	if mode == "computer" and engine.side == human:
		count = 2  # the computer's answer and the player's move
	for i in count:
		engine.unmake_move()
		moves_played.pop_back()
		records.pop_back()
	result = ""
	reason = ""
	card_hidden = false
	_clear_board_state()
	legal = engine.legal_moves()
	sfx.play("undo")
	_save()
	_after_turn()


func _hint() -> void:
	if not _can_play() or thinking != "":
		return
	hint_move = 0
	_start_think("hint")


func _color_name(color: int) -> String:
	return "white" if color == WHITE else "black"


func _empty_stats() -> Dictionary:
	var levels := {}
	for entry in LEVELS:
		levels[entry.name] = {"played": 0, "won": 0, "drawn": 0, "lost": 0}
	return {"levels": levels, "two_player": 0}


# --- Computer ----------------------------------------------------------------------------------

func _start_think(kind: String) -> void:
	_stop_think()
	ai = ChessEngine.new()
	ai.copy_from(engine)
	var search: Dictionary = LEVELS[level] if kind == "move" else HINT_SEARCH
	thinking = kind
	think_clock = 0.0
	think_result = -1
	think_args = [search.depth, search.time, search.noise, randi()]
	if use_threads:
		thread = Thread.new()
		thread.start(ai.think.bindv(think_args))
	# Without threads (some web builds) _process runs the search on the next frame.


func _stop_think() -> void:
	if thread != null:
		ai.stop = true
		thread.wait_to_finish()
		thread = null
	thinking = ""
	think_result = -1


func _poll_think(delta: float) -> void:
	think_clock += delta
	if thread != null:
		if not thread.is_alive():
			think_result = thread.wait_to_finish()
			thread = null
	elif think_result == -1 and think_clock > 0.05:
		think_result = ai.callv("think", think_args)
	if think_result == -1:
		return
	var kind := thinking
	if kind == "move" and (think_clock < MIN_THINK or anim_t < 1.0):
		return
	var m := think_result
	thinking = ""
	think_result = -1
	if m == 0:
		return
	if kind == "move":
		_do_move(m, true)
	else:
		hint_move = m
		sfx.play("hint")


# --- Update ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if engine == null:
		return  # the icon copy, or the game while it renders the icon
	clock += delta
	if anim_t < 1.0:
		anim_t = minf(1.0, anim_t + delta / ANIM_TIME)
		if anim_t >= 1.0:
			anims.clear()
			fading = {}
	if result != "":
		over_clock += delta
	if thinking != "":
		_poll_think(delta)
	if nav_active:
		_fix_focus()
	if held_dir != Vector2i.ZERO:
		repeat_timer -= delta
		if repeat_timer <= 0.0:
			repeat_timer = PAD_REPEAT
			_direction(held_dir)
	queue_redraw()


func _card_visible() -> bool:
	return result != "" and not card_hidden and over_clock > CARD_DELAY


# --- Input -------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if engine == null:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pad_input(event)
		return
	if event is InputEventKey:
		if event.pressed:
			_key(event)
		return
	if event is InputEventMouseMotion:
		hover_button = _button_at(event.position)
		hover_square = _square_at(event.position)
		if drag_from >= 0:
			drag_pos = event.position
			if not dragging and event.position.distance_to(press_pos) > 6.0:
				dragging = true
		return
	if not event is InputEventMouseButton:
		return
	var button := event as InputEventMouseButton
	using_pad = false
	nav_active = false
	focus = ""
	cursor = -1
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			if button.pressed:
				_mouse_down(button.position)
			else:
				_mouse_up(button.position)
		MOUSE_BUTTON_RIGHT:
			if button.pressed and panel == "":
				if promo_to >= 0:
					_cancel_promo()
				selected = -1
				drag_from = -1
				dragging = false
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed and panel == "" and MOVE_LIST.has_point(button.position):
				var step := 1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1
				move_scroll = clampi(move_scroll + step, 0, maxi(0, _move_rows() - _visible_rows()))


func _mouse_down(pos: Vector2) -> void:
	var id := _button_at(pos)
	if id != "":
		_press(id)
		return
	if panel != "":
		if not PANEL.has_point(pos):
			_press("close")
		return
	if promo_to >= 0:
		var choice := _promo_at(pos)
		if choice >= 0:
			_promote(choice)
		else:
			_cancel_promo()
		return
	if _card_visible():
		return
	var sq := _square_at(pos)
	if sq < 0:
		selected = -1
		return
	if not _can_play():
		return
	if selected >= 0 and _find_move(selected, sq) != 0:
		_try_move(selected, sq, true)
	elif _own_piece(sq):
		press_was_selected = sq == selected
		if sq != selected:
			sfx.play("select")
		selected = sq
		drag_from = sq
		press_pos = pos
		drag_pos = pos
		dragging = false
	else:
		selected = -1


func _mouse_up(pos: Vector2) -> void:
	if drag_from < 0:
		return
	var from := drag_from
	drag_from = -1
	if dragging:
		dragging = false
		var to := _square_at(pos)
		if to >= 0 and to != from and _find_move(from, to) != 0:
			_try_move(from, to, false)
		elif to >= 0 and to != from:
			sfx.play("error")  # not a square this piece can go to; it stays picked up
	elif press_was_selected:
		selected = -1  # a second click on the picked piece puts it back


func _key(event: InputEventKey) -> void:
	var code := event.physical_keycode
	var moves := {KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN, KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT,
			KEY_W: Vector2i.UP, KEY_S: Vector2i.DOWN, KEY_A: Vector2i.LEFT, KEY_D: Vector2i.RIGHT}
	if event.echo and not moves.has(code):
		return
	using_pad = false
	if moves.has(code):
		_start_nav(moves[code])
		return
	match code:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			nav_active = true
			_accept()
		KEY_ESCAPE:
			_back()
		KEY_N:
			if panel == "":
				_press("new")
		KEY_U, KEY_Z, KEY_BACKSPACE:
			_undo()
		KEY_H:
			_hint()
		KEY_F:
			if panel == "":
				_press("flip")


func _pad_input(event: InputEvent) -> void:
	using_pad = true
	pad_device = event.device
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y:
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
	nav_active = true
	match button.button_index:
		JOY_BUTTON_A:
			_accept()
		JOY_BUTTON_B:
			_back()
		JOY_BUTTON_X:
			_hint()
		JOY_BUTTON_Y:
			if panel == "":
				_press("flip")
		JOY_BUTTON_LEFT_SHOULDER:
			_undo()
		JOY_BUTTON_START:
			_press("close" if panel == "new" else "new")
		JOY_BUTTON_BACK:
			_press("settings")


## Starts (or stops, with ZERO) holding a direction on the gamepad.
func _pad_hold(dir: Vector2i) -> void:
	held_dir = dir
	repeat_timer = PAD_REPEAT_DELAY
	if dir != Vector2i.ZERO:
		_start_nav(dir)


## A direction from the keyboard or gamepad. The first one only shows the cursor.
func _start_nav(dir: Vector2i) -> void:
	var was_active := nav_active
	nav_active = true
	if not was_active and panel == "" and not _card_visible() and promo_to < 0:
		if cursor < 0:
			cursor = _default_cursor()
		sfx.play("click")
		return
	_direction(dir)


func _direction(dir: Vector2i) -> void:
	if panel != "" or _card_visible():
		_nav_move(dir)
	elif promo_to >= 0:
		var down := 1 if _promo_rect(0).position.y < BOARD.get_center().y else -1
		promo_focus = clampi(promo_focus + dir.y * down, 0, PROMOTIONS.size() - 1)
		sfx.play("click")
	elif cursor < 0:
		cursor = _default_cursor()
		sfx.play("click")
	else:
		var r := _square_rect(cursor)
		var target := r.get_center() + Vector2(dir) * SQ
		if BOARD.has_point(target):
			cursor = _square_at(target)
			sfx.play("click")


## Enter / Space / A.
func _accept() -> void:
	if panel != "" or _card_visible():
		if focus == "":
			_fix_focus()
		elif focus != "":
			_press(focus)
			_fix_focus()
	elif promo_to >= 0:
		_promote(promo_focus)
	elif cursor < 0:
		cursor = _default_cursor()
		sfx.play("click")
	elif _can_play():
		if selected >= 0 and _find_move(selected, cursor) != 0:
			_try_move(selected, cursor, true)
		elif _own_piece(cursor) and cursor != selected:
			selected = cursor
			sfx.play("select")
		elif selected >= 0:
			selected = -1
			sfx.play("click")


## Esc / B.
func _back() -> void:
	if panel != "":
		_press("close")
	elif promo_to >= 0:
		_cancel_promo()
	elif _card_visible():
		_press("view")
	elif selected >= 0:
		selected = -1
		sfx.play("click")
	elif cursor >= 0:
		cursor = -1


func _default_cursor() -> int:
	return engine.kings[human if mode == "computer" else engine.side]


## Rows of buttons the keyboard and gamepad move between, for the open panel or result card.
func _nav_rows() -> Array:
	match panel:
		"new":
			var rows := [["close"], ["opp_computer", "opp_two"]]
			if pick_mode == "computer":
				rows.append(["level_0", "level_1", "level_2"])
				rows.append(["color_white", "color_random", "color_black"])
			rows.append(["start"])
			return rows
		"settings":
			var langs := []
			for entry in StringsScript.LANGUAGES:
				langs.append("lang_" + entry[0])
			return [["close"], langs, ["theme_0", "theme_1", "theme_2"], ["set_sound"], ["set_moves"], ["set_coords"]]
		"stats":
			return [["close"], ["reset"]]
	if _card_visible():
		return [["again", "view"]]
	return []


func _fix_focus() -> void:
	var rows := _nav_rows()
	if rows.is_empty():
		focus = ""
		return
	for row in rows:
		if focus in row:
			return
	match panel:
		"new":
			focus = "start"
		"settings":
			focus = "set_sound"
		"stats":
			focus = "close"
		_:
			focus = "again"


func _nav_move(dir: Vector2i) -> void:
	var rows := _nav_rows()
	var row := -1
	var col := 0
	for i in rows.size():
		if focus in rows[i]:
			row = i
			col = rows[i].find(focus)
	if row < 0:
		_fix_focus()
		sfx.play("click")
		return
	if dir.y != 0:
		var next := clampi(row + dir.y, 0, rows.size() - 1)
		# Keep roughly the same horizontal place when rows have different lengths.
		col = clampi(roundi(float(col) * (rows[next].size() - 1) / maxf(1.0, rows[row].size() - 1)), 0, rows[next].size() - 1)
		row = next
	else:
		col = clampi(col + dir.x, 0, rows[row].size() - 1)
	if rows[row][col] != focus:
		focus = rows[row][col]
		sfx.play("click")


func _rumble(weak: float, strong: float, duration: float) -> void:
	if using_pad:
		Input.start_joy_vibration(pad_device, weak, strong, duration)


func _press(id: String) -> void:
	sfx.play("click")
	if id.begins_with("lang_"):
		language = id.substr(5)
		_apply_settings()
		_save()
		return
	if id.begins_with("theme_"):
		theme = int(id.substr(6))
		_save()
		return
	if id.begins_with("level_"):
		pick_level = int(id.substr(6))
		return
	if id.begins_with("color_"):
		pick_color = id.substr(6)
		return
	match id:
		"opp_computer":
			pick_mode = "computer"
		"opp_two":
			pick_mode = "two"
		"start":
			panel = ""
			_start_game()
		"again":
			pick_mode = mode
			pick_level = level
			pick_color = color_pick
			_start_game()
		"new", "stats", "settings":
			if panel == id:
				panel = ""
			else:
				panel = id
				reset_armed = false
				_cancel_promo()
				selected = -1
				drag_from = -1
				dragging = false
				focus = ""
				if nav_active:
					_fix_focus()
		"close":
			panel = ""
			reset_armed = false
		"reset":
			if reset_armed:
				stats = _empty_stats()
				reset_armed = false
				_save()
			else:
				reset_armed = true
		"set_sound":
			sound_on = not sound_on
			_apply_settings()
			_save()
			sfx.play("click")
		"set_moves":
			show_moves = not show_moves
			_save()
		"set_coords":
			show_coords = not show_coords
			_save()
		"undo":
			_undo()
		"hint":
			_hint()
		"flip":
			flipped = not flipped
			_save()
		"view":
			card_hidden = true
		"result":
			card_hidden = false


# --- Layout ------------------------------------------------------------------------------------

func _square_rect(sq: int) -> Rect2:
	var col := sq % 10 - 1
	var row := sq / 10 - 2
	if flipped:
		col = 7 - col
		row = 7 - row
	return Rect2(BOARD.position + Vector2(col, row) * SQ, Vector2(SQ, SQ))


func _square_at(pos: Vector2) -> int:
	if not BOARD.has_point(pos):
		return -1
	var col := clampi(int((pos.x - BOARD.position.x) / SQ), 0, 7)
	var row := clampi(int((pos.y - BOARD.position.y) / SQ), 0, 7)
	if flipped:
		col = 7 - col
		row = 7 - row
	return 21 + row * 10 + col


## The promotion picker: a column of four squares from the promotion square toward the middle.
func _promo_rect(index: int) -> Rect2:
	var target := _square_rect(promo_to)
	var down := target.position.y < BOARD.get_center().y
	return Rect2(target.position + Vector2(0, (index if down else -index) * SQ), target.size)


func _promo_at(pos: Vector2) -> int:
	for i in PROMOTIONS.size():
		if _promo_rect(i).has_point(pos):
			return i
	return -1


func _card_rect() -> Rect2:
	return Rect2(BOARD.get_center() - Vector2(230, 130), Vector2(460, 260))


func _buttons() -> Dictionary:
	var list := {}
	list["stats"] = Rect2(SIDE.end.x - 102, 44, 46, 46)
	list["settings"] = Rect2(SIDE.end.x - 46, 44, 46, 46)
	if panel != "":
		var top := PANEL.position
		list["close"] = Rect2(PANEL.end.x - 64, top.y + 20, 44, 44)
		match panel:
			"new":
				var half := (PANEL.size.x - 64 - 12) / 2.0
				list["opp_computer"] = Rect2(top.x + 32, top.y + 122, half, 48)
				list["opp_two"] = Rect2(top.x + 32 + half + 12, top.y + 122, half, 48)
				if pick_mode == "computer":
					var third := (PANEL.size.x - 64 - 24) / 3.0
					for i in 3:
						list["level_%d" % i] = Rect2(top.x + 32 + i * (third + 12), top.y + 218, third, 48)
						list["color_" + COLOR_CHOICES[i]] = Rect2(top.x + 32 + i * (third + 12), top.y + 314, third, 48)
				list["start"] = Rect2(PANEL.get_center().x - 150, PANEL.end.y - 88, 300, 56)
			"settings":
				var x := top.x + 32
				for entry in StringsScript.LANGUAGES:
					var width: float = bold.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 30.0
					list["lang_" + entry[0]] = Rect2(x, top.y + 120, width, 44)
					x += width + 8.0
				var third := (PANEL.size.x - 64 - 24) / 3.0
				for i in 3:
					list["theme_%d" % i] = Rect2(top.x + 32 + i * (third + 12), top.y + 212, third, 44)
				for i in SETTING_ROWS.size():
					list[SETTING_ROWS[i]] = Rect2(top.x + 24, top.y + 282 + i * 80, PANEL.size.x - 48, 70)
			"stats":
				list["reset"] = Rect2(PANEL.get_center().x - 160, PANEL.end.y - 76, 320, 48)
		return list
	var width := (SIDE.size.x - 30) / 4.0
	var ids := ["new", "undo", "hint", "flip"]
	for i in ids.size():
		list[ids[i]] = Rect2(SIDE.position.x + i * (width + 10), 632, width, 48)
	if result != "":
		list["result"] = Rect2(MOVE_LIST.position.x + 12, MOVE_LIST.end.y - 56, MOVE_LIST.size.x - 24, 44)
	if _card_visible():
		var card := _card_rect()
		list["again"] = Rect2(card.position.x + 30, card.end.y - 78, 190, 50)
		list["view"] = Rect2(card.end.x - 220, card.end.y - 78, 190, 50)
	return list


func _button_at(pos: Vector2) -> String:
	var list := _buttons()
	# The result card sits on top of the board and the move list's result row.
	for id in ["again", "view"]:
		if list.has(id) and list[id].has_point(pos):
			return id
	for id: String in list:
		if list[id].has_point(pos):
			return id
	return ""


func _move_rows() -> int:
	return (records.size() + 1) / 2


func _visible_rows() -> int:
	var height := MOVE_LIST.size.y - 24 - (60 if result != "" else 0)
	return int(height / ROW_H)


# --- Drawing -----------------------------------------------------------------------------------

func _draw() -> void:
	if icon_mode:
		_draw_icon()
		return
	if engine == null:
		return
	draw_rect(Rect2(Vector2.ZERO, SCREEN), BG)
	_draw_board()
	_draw_side()
	if _card_visible() and panel == "":
		_draw_card()
	match panel:
		"new":
			_draw_new_game()
		"settings":
			_draw_settings()
		"stats":
			_draw_stats()
	if nav_active and focus != "":
		var buttons := _buttons()
		if buttons.has(focus):
			var radius := 16 if SETTING_ROWS.has(focus) else 12
			_box(buttons[focus].grow(4), Color(0, 0, 0, 0), FOCUS, radius, 3)


func _draw_board() -> void:
	var colors: Dictionary = THEMES[theme]
	_box(BOARD.grow(8), Color("2a2622"), Color(0, 0, 0, 0), 10)
	for row in 8:
		for col in 8:
			var sq := 21 + row * 10 + col
			draw_rect(_square_rect(sq), colors.light if (row + col) % 2 == 0 else colors.dark)
	if not moves_played.is_empty():
		var last: int = moves_played.back()
		draw_rect(_square_rect(ChessEngine.move_from(last)), LAST_MOVE)
		draw_rect(_square_rect(ChessEngine.move_to(last)), LAST_MOVE)
	if selected >= 0:
		draw_rect(_square_rect(selected), SELECTED)
	if promo_from >= 0:
		draw_rect(_square_rect(promo_from), SELECTED)
	if engine.in_check():
		var center := _square_rect(engine.kings[engine.side]).get_center()
		for i in 7:
			draw_circle(center, SQ * (0.62 - i * 0.075), Color(0.95, 0.1, 0.05, 0.13), true, -1.0, true)
	if show_coords:
		for i in 8:
			var bottom := _square_at(BOARD.position + Vector2(i + 0.5, 7.5) * SQ)
			var left := _square_at(BOARD.position + Vector2(0.5, i + 0.5) * SQ)
			var file_rect := _square_rect(bottom)
			var rank_rect := _square_rect(left)
			var file_light := (bottom / 10 + bottom % 10) % 2 == 1
			var rank_light := (left / 10 + left % 10) % 2 == 1
			_text(file_rect.end - Vector2(13, 6), ChessEngine.square_name(bottom)[0], 14,
					colors.dark if file_light else colors.light, bold)
			_text(rank_rect.position + Vector2(5, 18), ChessEngine.square_name(left)[1], 14,
					colors.dark if rank_light else colors.light, bold)

	# Pieces, except the ones sliding, lifted or waiting for their promotion.
	var moving := {}
	for a: Dictionary in anims:
		moving[a.to] = true
	for sq in range(21, 99):
		var p: int = engine.board[sq]
		if p <= 0 or moving.has(sq) or (dragging and sq == drag_from) or sq == promo_from:
			continue
		_draw_piece(p, _square_rect(sq).get_center(), SQ)
	if not fading.is_empty():
		_draw_piece(fading.piece, _square_rect(fading.square).get_center(), SQ)

	if show_moves and _can_play():
		var from := drag_from if dragging else selected
		if from >= 0:
			for m in legal:
				if ChessEngine.move_from(m) != from:
					continue
				var to := ChessEngine.move_to(m)
				var rect := _square_rect(to)
				if engine.board[to] > 0:
					draw_arc(rect.get_center(), SQ * 0.44, 0.0, TAU, 40, TARGET, SQ * 0.08, true)
				else:
					draw_circle(rect.get_center(), SQ * 0.15, TARGET, true, -1.0, true)
	if dragging and hover_square >= 0 and hover_square != drag_from and _find_move(drag_from, hover_square) != 0:
		_box(_square_rect(hover_square).grow(-2), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.75), 2, 4)

	if hint_move != 0:
		_arrow(_square_rect(ChessEngine.move_from(hint_move)).get_center(),
				_square_rect(ChessEngine.move_to(hint_move)).get_center(), HINT_ARROW)

	var t := ease(anim_t, -2.0)
	for a: Dictionary in anims:
		var pos: Vector2 = _square_rect(a.from).get_center().lerp(_square_rect(a.to).get_center(), t)
		_draw_piece(a.piece, pos, SQ)

	if cursor >= 0 and nav_active and panel == "" and promo_to < 0 and not _card_visible():
		_box(_square_rect(cursor).grow(-3), Color(0, 0, 0, 0), FOCUS, 4, 5)
	if dragging:
		_draw_piece(engine.board[drag_from], drag_pos, SQ * 1.12)
	if promo_to >= 0:
		_draw_promotion()


func _draw_promotion() -> void:
	draw_rect(BOARD, Color(0, 0, 0, 0.45))
	var color: int = engine.side << 3
	for i in PROMOTIONS.size():
		var rect := _promo_rect(i)
		var hot := _promo_at(get_local_mouse_position()) == i or (nav_active and promo_focus == i)
		_box(rect.grow(-3), Color("f4f1ea") if hot else Color("c9c3b8"), FOCUS if hot else Color(0, 0, 0, 0.3), 40, 3 if hot else 1)
		_draw_piece(PROMOTIONS[i] | color, rect.get_center(), SQ * (1.0 if hot else 0.9))


func _draw_card() -> void:
	var t := clampf((over_clock - CARD_DELAY) / 0.25, 0.0, 1.0)
	draw_rect(BOARD, Color(0, 0, 0, 0.35 * t))
	var card := _card_rect()
	_box(Rect2(card.position + Vector2(0, 8), card.size), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 18)
	_box(card, CARD, Color(1, 1, 1, 0.08), 18)
	var title := tr("draw")
	var color := INK
	if result != "draw":
		if mode == "two":
			title = tr("white_wins") if result == "white" else tr("black_wins")
			color = GOLD
		elif result == _color_name(human):
			title = tr("you_win")
			color = GOLD
		else:
			title = tr("you_lose")
	var center := card.get_center()
	if result == "draw":
		_draw_piece(KING, Vector2(center.x - 30, card.position.y + 58), 64, true)
		_draw_piece(KING | ChessEngine.BLACK_BIT, Vector2(center.x + 30, card.position.y + 58), 64, true)
	else:
		var winner := KING | (0 if result == "white" else ChessEngine.BLACK_BIT)
		_draw_piece(winner, Vector2(center.x, card.position.y + 56), 70, true)
	_text(Vector2(center.x, card.position.y + 130), title, 34, color, bold, true, card.size.x - 40)
	var detail := tr(reason)
	if reason == "checkmate":
		detail += "  ·  " + tr("in_moves") % ((moves_played.size() + 1) / 2)
	_text(Vector2(center.x, card.position.y + 162), detail, 17, MUTED, font, true, card.size.x - 40)
	var buttons := _buttons()
	_button(buttons.again, tr("play_again"), "again", true)
	_button(buttons.view, tr("view_board"), "view")


func _draw_side() -> void:
	_draw_piece(KNIGHT, Vector2(SIDE.position.x + 24, 68), 54, true)
	_text(Vector2(SIDE.position.x + 58, 82), "Chess", 34, INK, bold)
	var buttons := _buttons() if panel == "" else _play_buttons()
	_icon_button(buttons.stats, "stats")
	_icon_button(buttons.settings, "settings")
	var top_color := WHITE if flipped else BLACK
	_draw_player(TOP_CARD, top_color)
	_draw_player(BOTTOM_CARD, top_color ^ 1)
	_draw_moves(buttons)
	_button(buttons.new, tr("new_game"), "new", true)
	_button(buttons.undo, tr("undo"), "undo", false, _can_undo() and promo_to < 0)
	_button(buttons.hint, tr("hint"), "hint", false, _can_play() and thinking == "")
	_button(buttons.flip, tr("flip"), "flip")


## The play screen's buttons, to draw the side panel under an open panel.
func _play_buttons() -> Dictionary:
	var open := panel
	panel = ""
	var list := _buttons()
	panel = open
	return list


func _draw_player(rect: Rect2, color: int) -> void:
	var active: bool = result == "" and engine.side == color
	_box(rect, CARD, ACCENT if active else Color(0, 0, 0, 0), 12, 2)
	_draw_piece(KING | (color << 3), rect.position + Vector2(34, 32), 50, true)
	var label := tr("white") if color == WHITE else tr("black")
	if mode == "computer":
		label = tr("you") if color == human else tr("computer_level") % tr(LEVELS[level].key)
	_text(rect.position + Vector2(66, 27), label, 18, INK, bold, false, 250)

	# Pieces this side has taken, and its material lead.
	var x := rect.position.x + 66.0
	var previous := 0
	for p: int in _captured_by(color):
		if previous != 0 and p != previous:
			x += 7.0
		_draw_piece(p, Vector2(x + 9, rect.position.y + 47), 22, true)
		x += 12.0
		previous = p
	var lead := roundi((_material(color) - _material(color ^ 1)) / 100.0)
	if lead > 0:
		_text(Vector2(x + 16, rect.position.y + 53), "+%d" % lead, 14, MUTED, bold)

	var status := ""
	var status_color := MUTED
	if result == "":
		if engine.side == color:
			if thinking != "":
				status = tr("thinking") + ".".repeat(int(clock * 3.0) % 4)
			elif mode == "two":
				status = tr("to_move")
			elif color == human:
				status = tr("your_turn")
				status_color = ACCENT
			if engine.in_check():
				status = tr("check")
				status_color = RED
	else:
		status = "½" if result == "draw" else ("1" if result == _color_name(color) else "0")
		status_color = GOLD if result == _color_name(color) else MUTED
	if status != "":
		var size := 26 if result != "" else 16
		var width := bold.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_text(Vector2(rect.end.x - 20 - width, rect.get_center().y + size * 0.36), status, size, status_color, bold)


## The other side's pieces missing from the board, most valuable first.
func _captured_by(color: int) -> Array:
	var other := color ^ 1
	var count := {}
	for sq in range(21, 99):
		var p: int = engine.board[sq]
		if p > 0 and (p >> 3) == other:
			count[p & 7] = count.get(p & 7, 0) + 1
	var start := {QUEEN: 1, ROOK: 2, BISHOP: 2, KNIGHT: 2, PAWN: 8}
	var list := []
	for type: int in start:
		for i in maxi(0, start[type] - count.get(type, 0)):
			list.append(type | (other << 3))
	return list


func _material(color: int) -> int:
	var total := 0
	for sq in range(21, 99):
		var p: int = engine.board[sq]
		if p > 0 and (p >> 3) == color:
			total += ChessEngine.VALUE[p & 7]
	return total


func _draw_moves(buttons: Dictionary) -> void:
	_box(MOVE_LIST, CARD, Color(0, 0, 0, 0), 12)
	var x := MOVE_LIST.position.x
	if records.is_empty():
		var mid := MOVE_LIST.get_center()
		_draw_piece(PAWN, mid - Vector2(0, 56), 64, true)
		_text(mid + Vector2(0, 8), tr("help_mouse"), 16, INK, font, true, MOVE_LIST.size.x - 40)
		_text(mid + Vector2(0, 40), tr("help_pad") if using_pad else tr("help_keys"), 14, MUTED, font, true, MOVE_LIST.size.x - 40)
	var total := _move_rows()
	var shown := _visible_rows()
	move_scroll = clampi(move_scroll, 0, maxi(0, total - shown))
	var first := maxi(0, total - shown - move_scroll)
	for r in range(first, mini(total, first + shown)):
		var y := MOVE_LIST.position.y + 12 + (r - first) * ROW_H
		if r % 2 == 1:
			draw_rect(Rect2(x + 8, y, MOVE_LIST.size.x - 16, ROW_H), Color(1, 1, 1, 0.03))
		_text(Vector2(x + 22, y + 21), "%d." % (r + 1), 15, MUTED, font)
		for c in 2:
			var i := r * 2 + c
			if i < records.size():
				_draw_record(records[i], Vector2(x + 84 + c * 190, y + 21), i == records.size() - 1)
	if total > shown:
		# A thin scroll bar on the right edge.
		var track := Rect2(MOVE_LIST.end.x - 8, MOVE_LIST.position.y + 12, 3, shown * ROW_H)
		var size := track.size.y * shown / total
		var offset := (track.size.y - size) * (1.0 - float(move_scroll) / (total - shown))
		_box(Rect2(track.position.x, track.position.y + offset, 3, size), Color(1, 1, 1, 0.25), Color(0, 0, 0, 0), 2)
	if result != "":
		var rect: Rect2 = buttons.result
		var score := "½-½" if result == "draw" else ("1-0" if result == "white" else "0-1")
		var hovered := hover_button == "result" and card_hidden
		_box(rect, RAISED_HOVER if hovered else RAISED, Color(0, 0, 0, 0), 10)
		_text(rect.get_center() + Vector2(0, 7), "%s  ·  %s" % [score, tr(reason)], 18, GOLD if result != "draw" else INK, bold, true, rect.size.x - 20)


## One move of the list: the piece as a small figure, then the rest of the notation.
func _draw_record(record: Dictionary, pos: Vector2, latest: bool) -> void:
	var width := 0.0
	if record.piece:
		width += 20.0
	width += font.get_string_size(record.text + record.suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	if record.promo:
		width += 20.0
	if latest:
		_box(Rect2(pos.x - 8, pos.y - 20, width + 16, 27), Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 6)
	var x := pos.x
	if record.piece:
		_draw_piece(record.piece, Vector2(x + 9, pos.y - 7), 22, true)
		x += 20.0
	_text(Vector2(x, pos.y), record.text, 17, INK, font)
	x += font.get_string_size(record.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	if record.promo:
		_draw_piece(record.promo, Vector2(x + 10, pos.y - 7), 22, true)
		x += 20.0
	_text(Vector2(x, pos.y), record.suffix, 17, INK, font)


func _arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var dir := (to - from).normalized()
	var start := from + dir * SQ * 0.2
	var tip := to - dir * SQ * 0.12
	var head := tip - dir * SQ * 0.34
	draw_line(start, head, color, SQ * 0.16)
	var side := dir.orthogonal() * SQ * 0.22
	draw_colored_polygon(PackedVector2Array([tip, head + side, head - side]), color)


# --- Panels ------------------------------------------------------------------------------------

func _draw_panel_frame(title: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.55))
	_box(Rect2(PANEL.position + Vector2(0, 8), PANEL.size), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 18)
	_box(PANEL, CARD, Color(1, 1, 1, 0.08), 18)
	_text(PANEL.position + Vector2(32, 60), title, 30, INK, bold)
	var close: Rect2 = _buttons().close
	_box(close, RAISED_HOVER if hover_button == "close" else RAISED, Color(0, 0, 0, 0), 22)
	_cross(close.get_center(), 8.0, INK)


func _draw_new_game() -> void:
	_draw_panel_frame(tr("new_game"))
	var b := _buttons()
	var top := PANEL.position
	_text(top + Vector2(32, 110), tr("opponent"), 15, MUTED, bold)
	_tab(b.opp_computer, tr("vs_computer"), pick_mode == "computer", "opp_computer")
	_tab(b.opp_two, tr("two_players"), pick_mode == "two", "opp_two")
	if pick_mode == "computer":
		_text(top + Vector2(32, 206), tr("level"), 15, MUTED, bold)
		for i in 3:
			_tab(b["level_%d" % i], tr(LEVELS[i].key), pick_level == i, "level_%d" % i)
		_text(top + Vector2(32, 302), tr("play_as"), 15, MUTED, bold)
		var pieces := [KING, -1, KING | ChessEngine.BLACK_BIT]
		for i in 3:
			var id: String = "color_" + COLOR_CHOICES[i]
			_tab(b[id], tr(COLOR_CHOICES[i]), pick_color == COLOR_CHOICES[i], id, pieces[i])
	else:
		var mid := Vector2(PANEL.get_center().x, top.y + 290)
		_draw_piece(KING, mid + Vector2(-40, -30), 76, true)
		_draw_piece(KING | ChessEngine.BLACK_BIT, mid + Vector2(40, -30), 76, true)
		_text(mid + Vector2(0, 50), tr("two_players_note"), 16, MUTED, font, true, PANEL.size.x - 80)
	_button(b.start, tr("start"), "start", true)


func _draw_settings() -> void:
	_draw_panel_frame(tr("settings"))
	var b := _buttons()
	var top := PANEL.position
	_text(top + Vector2(32, 108), tr("language"), 15, MUTED, bold)
	for entry in StringsScript.LANGUAGES:
		var id: String = "lang_" + entry[0]
		_tab(b[id], entry[1], entry[0] == language, id)
	_text(top + Vector2(32, 200), tr("board"), 15, MUTED, bold)
	for i in THEMES.size():
		var id := "theme_%d" % i
		var rect: Rect2 = b[id]
		_tab(rect, "", theme == i, id)
		# A little 2x2 board of the theme's colors, then its name.
		var swatch := Rect2(rect.position + Vector2(14, 10), Vector2(24, 24))
		for q in 4:
			var cell := Rect2(swatch.position + Vector2(q % 2, q / 2) * 12.0, Vector2(12, 12))
			draw_rect(cell, THEMES[i].light if (q % 2 + q / 2) % 2 == 0 else THEMES[i].dark)
		_text(Vector2(rect.position.x + 48, rect.get_center().y + 6), tr(THEMES[i].key), 16,
				Color.WHITE if theme == i else INK, bold, false, rect.size.x - 56)
	var rows := {
		"set_sound": [tr("sound"), tr("sound_desc"), sound_on],
		"set_moves": [tr("legal_moves"), tr("legal_moves_desc"), show_moves],
		"set_coords": [tr("coordinates"), tr("coordinates_desc"), show_coords],
	}
	for id: String in SETTING_ROWS:
		var rect: Rect2 = b[id]
		_box(rect, RAISED_HOVER if hover_button == id else RAISED, Color(0, 0, 0, 0), 14)
		_text(rect.position + Vector2(20, 30), rows[id][0], 18, INK, bold, false, rect.size.x - 110)
		_text(rect.position + Vector2(20, 53), rows[id][1], 14, MUTED, font, false, rect.size.x - 110)
		var on: bool = rows[id][2]
		var track := Rect2(rect.end.x - 72, rect.get_center().y - 13, 52, 26)
		_box(track, ACCENT if on else Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 13)
		draw_circle(Vector2(track.end.x - 13 if on else track.position.x + 13, track.get_center().y), 10.0, Color.WHITE, true, -1.0, true)


func _draw_stats() -> void:
	_draw_panel_frame(tr("statistics"))
	var top := PANEL.position
	var width := PANEL.size.x - 64
	var totals := {"played": 0, "won": 0, "drawn": 0, "lost": 0}
	for entry in LEVELS:
		var data: Dictionary = stats.levels[entry.name]
		for key: String in totals:
			totals[key] += int(data[key])
	var played: int = totals.played
	var tiles := [
		[str(played), tr("played")],
		[str(totals.won), tr("won")],
		[str(totals.drawn), tr("drawn")],
		[str(totals.lost), tr("lost")],
		["%d%%" % (roundi(100.0 * totals.won / played) if played > 0 else 0), tr("win_rate")],
	]
	var tile_w := (width - 4 * 10.0) / 5.0
	for i in tiles.size():
		var tile := Rect2(top.x + 32 + i * (tile_w + 10.0), top.y + 88, tile_w, 92)
		_box(tile, RAISED, Color(0, 0, 0, 0), 12)
		_text(Vector2(tile.get_center().x, tile.position.y + 48), tiles[i][0], 30, INK, bold, true)
		_text(Vector2(tile.get_center().x, tile.position.y + 74), tiles[i][1], 13, MUTED, font, true, tile_w - 10)

	# One row per level.
	var columns := [top.x + 48, top.x + 250, top.x + 340, top.x + 430, top.x + 520]
	var head_y := top.y + 216
	var heads := [tr("level"), tr("played"), tr("won"), tr("drawn"), tr("lost")]
	for i in heads.size():
		_text(Vector2(columns[i], head_y), heads[i], 13, MUTED, bold, i > 0, 150 if i == 0 else 84)
	for i in LEVELS.size():
		var row := Rect2(top.x + 32, head_y + 14 + i * 56, width, 48)
		_box(row, RAISED if i % 2 == 0 else CARD, Color(0, 0, 0, 0), 10)
		var data: Dictionary = stats.levels[LEVELS[i].name]
		var y := row.position.y + 31
		_text(Vector2(columns[0], y), tr(LEVELS[i].key), 17, INK, bold, false, 180)
		_text(Vector2(columns[1], y), str(data.played), 17, INK, bold, true)
		_text(Vector2(columns[2], y), str(data.won), 17, ACCENT if int(data.won) > 0 else INK, bold, true)
		_text(Vector2(columns[3], y), str(data.drawn), 17, INK, bold, true)
		_text(Vector2(columns[4], y), str(data.lost), 17, INK, bold, true)
	var note := ""
	if int(stats.two_player) > 0:
		note = tr("two_player_games") % int(stats.two_player)
	elif played == 0:
		note = tr("stats_empty")
	_text(Vector2(PANEL.get_center().x, top.y + 430), note, 15, MUTED, font, true, width)
	var reset: Rect2 = _buttons().reset
	_box(reset, Color(RED, 0.18) if reset_armed else (RAISED_HOVER if hover_button == "reset" else RAISED),
			RED if reset_armed else Color(0, 0, 0, 0), 24)
	_text(reset.get_center() + Vector2(0, 6), tr("confirm_reset") if reset_armed else tr("reset_stats"), 16,
			RED if reset_armed else INK, bold, true, reset.size.x - 20)


# --- Drawing helpers ---------------------------------------------------------------------------

## Round header button with a bar chart (statistics) or a gear (settings).
func _icon_button(rect: Rect2, id: String) -> void:
	var active := panel == id
	_box(rect, ACCENT if active else (RAISED_HOVER if hover_button == id else RAISED), Color(0, 0, 0, 0), 23)
	var c := rect.get_center()
	var color := Color.WHITE if active else INK
	if id == "stats":
		for i in 3:
			var h: float = [8.0, 14.0, 20.0][i]
			draw_rect(Rect2(c + Vector2(-11 + i * 8, 10 - h), Vector2(6, h)), color)
	else:
		var fill := ACCENT if active else (RAISED_HOVER if hover_button == id else RAISED)
		for i in 8:
			var a := i * TAU / 8.0
			draw_line(c + Vector2.from_angle(a) * 8.0, c + Vector2.from_angle(a) * 12.5, color, 4.0)
		draw_circle(c, 8.5, color)
		draw_circle(c, 3.5, fill)


func _cross(center: Vector2, arm: float, color: Color) -> void:
	draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), color, 2.5, true)
	draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), color, 2.5, true)


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


func _button(rect: Rect2, label: String, id: String, primary := false, enabled := true) -> void:
	var hovered := hover_button == id and enabled
	if primary:
		_box(rect, ACCENT.lightened(0.1) if hovered else ACCENT, Color(0, 0, 0, 0), 12)
		_text(rect.get_center() + Vector2(0, 6), label, 17, Color.WHITE, bold, true, rect.size.x - 16)
	else:
		_box(rect, RAISED_HOVER if hovered else RAISED, Color(0, 0, 0, 0), 12)
		_text(rect.get_center() + Vector2(0, 6), label, 17, INK if enabled else Color(INK, 0.3), bold, true, rect.size.x - 16)


## A choice among several; `piece` draws a small piece before the label (-1: a half white,
## half black king for "random").
func _tab(rect: Rect2, label: String, active: bool, id: String, piece := 0) -> void:
	var hovered := hover_button == id
	if active:
		_box(rect, ACCENT, Color(0, 0, 0, 0), 12)
	else:
		_box(rect, RAISED_HOVER if hovered else RAISED, Color(0, 0, 0, 0), 12)
	if label == "":
		return
	var color := Color.WHITE if active else INK
	if piece == 0:
		_text(rect.get_center() + Vector2(0, 6), label, 16, color, bold, true, rect.size.x - 16)
		return
	var text_w := minf(bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, rect.size.x - 60)
	var x := rect.get_center().x - (text_w + 32) / 2.0
	var icon := Vector2(x + 12, rect.get_center().y)
	if piece < 0:
		_draw_piece(KING, icon + Vector2(-5, 0), 30, true)
		_draw_piece(KING | ChessEngine.BLACK_BIT, icon + Vector2(5, 0), 30, true)
	else:
		_draw_piece(piece, icon, 30, true)
	_text(Vector2(x + 32, rect.get_center().y + 6), label, 16, color, bold, false, rect.size.x - 60)


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


# --- Pieces ------------------------------------------------------------------------------------

## Builds the piece drawings, in units of one square around its center (y grows downward).
## Each piece is filled shapes (polygons, or Vector3(x, y, radius) circles), an outline made by
## growing every shape, and detail lines drawn on top.
func _build_pieces() -> void:
	var base := _poly([[-0.31, 0.43], [0.31, 0.43], [0.31, 0.36], [0.26, 0.31], [-0.26, 0.31], [-0.31, 0.36]])
	var base_line := _line([[-0.26, 0.31], [0.26, 0.31]])

	shapes[PAWN] = _piece([
		_poly([[-0.27, 0.43], [0.27, 0.43], [0.27, 0.36], [0.22, 0.31], [-0.22, 0.31], [-0.27, 0.36]]),
		_poly([[-0.19, 0.32], [-0.13, 0.19], [-0.09, 0.05], [0.09, 0.05], [0.13, 0.19], [0.19, 0.32]]),
		_rect(-0.15, -0.01, 0.15, 0.06),
		Vector3(0, -0.14, 0.135),
	], [_line([[-0.22, 0.31], [0.22, 0.31]]), _line([[-0.1, 0.06], [0.1, 0.06]])])

	shapes[ROOK] = _piece([
		base,
		_rect(-0.25, 0.23, 0.25, 0.31),
		_poly([[-0.18, 0.24], [0.18, 0.24], [0.155, -0.12], [-0.155, -0.12]]),
		_poly([[-0.25, -0.1], [0.25, -0.1], [0.25, -0.37], [0.14, -0.37], [0.14, -0.29], [0.055, -0.29],
				[0.055, -0.37], [-0.055, -0.37], [-0.055, -0.29], [-0.14, -0.29], [-0.14, -0.37], [-0.25, -0.37]]),
	], [base_line, _line([[-0.18, 0.235], [0.18, 0.235]]), _line([[-0.155, -0.1], [0.155, -0.1]]),
			_line([[-0.25, -0.2], [0.25, -0.2]])])

	shapes[KNIGHT] = _piece([
		base,
		_poly([[-0.24, 0.32], [-0.21, 0.16], [-0.12, 0.05], [-0.05, -0.01], [-0.16, 0.02], [-0.27, 0.01],
				[-0.34, -0.04], [-0.37, -0.1], [-0.33, -0.16], [-0.2, -0.25], [-0.12, -0.33], [-0.09, -0.45],
				[-0.02, -0.34], [0.1, -0.31], [0.21, -0.2], [0.28, -0.02], [0.3, 0.16], [0.28, 0.32]]),
	], [base_line, _line([[-0.01, -0.3], [0.12, -0.22], [0.2, -0.06], [0.23, 0.12], [0.22, 0.3]])],
			[Vector3(-0.17, -0.18, 0.03), Vector3(-0.31, -0.08, 0.018)])

	var mitre := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		mitre.append(Vector2(0.155 * sin(a), -0.35 if i == 0 else -0.15 - 0.165 * cos(a)))
	shapes[BISHOP] = _piece([
		base,
		_poly([[-0.2, 0.32], [-0.12, 0.17], [-0.08, 0.06], [0.08, 0.06], [0.12, 0.17], [0.2, 0.32]]),
		_rect(-0.16, 0.0, 0.16, 0.075),
		mitre,
		Vector3(0, -0.39, 0.045),
	], [base_line, _line([[-0.16, 0.0], [0.16, 0.0]]), _line([[-0.09, 0.075], [0.09, 0.075]]),
			_line([[0, -0.25], [0, -0.1]]), _line([[-0.065, -0.175], [0.065, -0.175]])])

	var queen := _piece([
		base,
		_poly([[-0.21, 0.32], [-0.15, 0.1], [-0.28, -0.22], [-0.16, -0.08], [-0.14, -0.3], [-0.06, -0.1],
				[0, -0.34], [0.06, -0.1], [0.14, -0.3], [0.16, -0.08], [0.28, -0.22], [0.15, 0.1], [0.21, 0.32]]),
		Vector3(-0.28, -0.245, 0.045), Vector3(-0.14, -0.325, 0.045), Vector3(0, -0.37, 0.045),
		Vector3(0.14, -0.325, 0.045), Vector3(0.28, -0.245, 0.045),
	], [base_line, _line([[-0.15, 0.1], [0.15, 0.1]]), _line([[-0.18, 0.2], [0.18, 0.2]])])
	shapes[QUEEN] = queen

	shapes[KING] = _piece([
		base,
		_poly([[-0.21, 0.32], [-0.14, 0.1], [-0.27, -0.07], [-0.25, -0.17], [-0.13, -0.2], [0, -0.13],
				[0.13, -0.2], [0.25, -0.17], [0.27, -0.07], [0.14, 0.1], [0.21, 0.32]]),
		_rect(-0.035, -0.44, 0.035, -0.12),
		_rect(-0.1, -0.37, 0.1, -0.3),
	], [base_line, _line([[-0.14, 0.1], [0.14, 0.1]]), _line([[-0.175, 0.2], [0.175, 0.2]])])


func _poly(points: Array) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for p in points:
		poly.append(Vector2(p[0], p[1]))
	return poly


func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


func _line(points: Array) -> PackedVector2Array:
	return _poly(points)


func _piece(fills: Array, lines: Array, dots := []) -> Dictionary:
	var outlines := []
	for s in fills:
		if s is Vector3:
			outlines.append(Vector3(s.x, s.y, s.z + OUTLINE))
			continue
		var grown := Geometry2D.offset_polygon(s, OUTLINE, Geometry2D.JOIN_ROUND)
		# Clipper grows or shrinks depending on the winding: keep the bigger result.
		if grown.is_empty() or _area(grown[0]) < _area(s):
			grown = Geometry2D.offset_polygon(s, -OUTLINE, Geometry2D.JOIN_ROUND)
		outlines.append_array(grown)
	return {"fill": fills, "outline": outlines, "lines": lines, "dots": dots}


func _area(poly: PackedVector2Array) -> float:
	var total := 0.0
	for i in poly.size():
		total += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(total) / 2.0


## Draws a piece centered on `center`, `size` pixels per square. `on_panel`: drawn on the dark
## side panel, where black pieces need a lighter edge to stand out.
func _draw_piece(piece: int, center: Vector2, size: float, on_panel := false) -> void:
	var shape: Dictionary = shapes[piece & 7]
	var black := piece >= ChessEngine.BLACK_BIT
	var fill := (BLACK_FILL_UI if on_panel else BLACK_FILL) if black else WHITE_FILL
	var edge := (BLACK_EDGE_UI if on_panel else BLACK_EDGE) if black else WHITE_EDGE
	var detail := BLACK_DETAIL if black else WHITE_EDGE
	var units := size * 0.92
	draw_set_transform(center + Vector2(0, size * 0.01), 0.0, Vector2(units, units))
	for s in shape.outline:
		_shape(s, edge)
	for s in shape.fill:
		_shape(s, fill)
	for line: PackedVector2Array in shape.lines:
		draw_polyline(line, detail, 0.028)
	for d: Vector3 in shape.dots:
		draw_circle(Vector2(d.x, d.y), d.z, detail)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A piece in one flat color (its shadow on the icon).
func _draw_piece_flat(piece: int, center: Vector2, size: float, color: Color) -> void:
	var shape: Dictionary = shapes[piece & 7]
	var units := size * 0.92
	draw_set_transform(center + Vector2(0, size * 0.01), 0.0, Vector2(units, units))
	for s in shape.outline:
		_shape(s, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shape(s: Variant, color: Color) -> void:
	if s is Vector3:
		draw_circle(Vector2(s.x, s.y), s.z, color)
	else:
		draw_colored_polygon(s, color)


# --- Icon --------------------------------------------------------------------------------------

## Renders icon.png (512x512, rounded corners) and quits. Run: play the game with "-- --render-icon".
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
	get_tree().quit()


func _draw_icon() -> void:
	# A 4x4 corner of a wooden board, a little darker than the game's so the white knight stands out.
	for i in 16:
		var cell := Rect2(Vector2(i % 4, i / 4) * 128.0, Vector2(128, 128))
		draw_rect(cell, Color("c29a6b") if (i % 4 + i / 4) % 2 == 0 else Color("8e6340"))
	_draw_piece_flat(KNIGHT, Vector2(270, 276), 470, Color(0, 0, 0, 0.35))
	_draw_piece(KNIGHT, Vector2(256, 262), 470)


# --- Save --------------------------------------------------------------------------------------

## Loads the settings and statistics, and returns the saved game ({} if there is none).
func _load() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return {}
	language = str(config.get_value("settings", "language", ""))
	sound_on = bool(config.get_value("settings", "sound", true))
	show_moves = bool(config.get_value("settings", "show_moves", true))
	show_coords = bool(config.get_value("settings", "show_coords", true))
	theme = clampi(int(config.get_value("settings", "theme", 0)), 0, THEMES.size() - 1)
	pick_mode = "two" if config.get_value("settings", "pick_mode", "") == "two" else "computer"
	pick_level = clampi(int(config.get_value("settings", "pick_level", 1)), 0, LEVELS.size() - 1)
	pick_color = str(config.get_value("settings", "pick_color", "white"))
	if not pick_color in COLOR_CHOICES:
		pick_color = "white"
	var saved: Variant = config.get_value("stats", "data", {})
	if saved is Dictionary and saved.has("levels"):
		stats.two_player = int(saved.get("two_player", 0))
		for entry in LEVELS:
			var data: Dictionary = saved.levels.get(entry.name, {})
			for key in ["played", "won", "drawn", "lost"]:
				stats.levels[entry.name][key] = int(data.get(key, 0))
	if not config.has_section("game"):
		return {}
	var saved_color := str(config.get_value("game", "color_pick", "white"))
	return {
		"mode": "two" if config.get_value("game", "mode", "") == "two" else "computer",
		"level": clampi(int(config.get_value("game", "level", 1)), 0, LEVELS.size() - 1),
		"human": clampi(int(config.get_value("game", "human", WHITE)), WHITE, BLACK),
		"color_pick": saved_color if saved_color in COLOR_CHOICES else "white",
		"flipped": bool(config.get_value("game", "flipped", false)),
		"recorded": bool(config.get_value("game", "recorded", false)),
		"moves": PackedStringArray(config.get_value("game", "moves", PackedStringArray())),
	}


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "language", language)
	config.set_value("settings", "sound", sound_on)
	config.set_value("settings", "show_moves", show_moves)
	config.set_value("settings", "show_coords", show_coords)
	config.set_value("settings", "theme", theme)
	config.set_value("settings", "pick_mode", pick_mode)
	config.set_value("settings", "pick_level", pick_level)
	config.set_value("settings", "pick_color", pick_color)
	var list := PackedStringArray()
	for m in moves_played:
		list.append(engine.uci(m))
	config.set_value("game", "mode", mode)
	config.set_value("game", "level", level)
	config.set_value("game", "human", human)
	config.set_value("game", "color_pick", color_pick)
	config.set_value("game", "flipped", flipped)
	config.set_value("game", "recorded", recorded)
	config.set_value("game", "moves", list)
	config.set_value("stats", "data", stats)
	config.save(SAVE_PATH)
