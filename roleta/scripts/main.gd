extends Node2D
## Roleta: European roulette (single zero) with play money.
## Pick a chip, click the table to bet. Clicking a cell bets on that number; clicking on an edge
## between numbers bets on both (split), on a corner on four, on the bottom edge on the three
## numbers of that column (street) and on a bottom corner on six. Right click takes chips back.
## Every bet pays 36 / (numbers covered), stake included: a number pays 35 to 1, red pays 1 to 1.
## Keys: Space / Enter spin, Backspace clear, Z undo, R rebet, D double, 1–6 pick a chip, Esc menu.

const SfxScript := preload("res://scripts/sfx.gd")
const StringsScript := preload("res://scripts/strings.gd")

const SCREEN := Vector2(1280, 720)
const SAVE_PATH := "user://roleta.cfg"
const START_BALANCE := 1000
const MAX_STAKE := 10000  # table limit on a single spot
const HISTORY_SIZE := 14

## Numbers in wheel order, clockwise from zero.
const WHEEL_ORDER := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16,
		33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const REDS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

# Wheel.
const WHEEL_CENTER := Vector2(300, 392)
const WHEEL_R := 245.0
const POCKET := TAU / 37.0
const IDLE_SPEED := 0.3  # radians per second while betting
const SPIN_SPEED := 3.3
const LAND_TIME := 5.5  # seconds from launch until the ball settles in a pocket
const RESOLVE_TIME := 5.9  # bets are paid at this point
const RESULT_TIME := 3.4  # the result stays on screen this long

# Table: a zero column, 12 columns of three numbers and a 2 to 1 column.
const TABLE := Vector2(592, 150)
const CELL := Vector2(47, 66)
const GRID_X := 639.0  # TABLE.x + CELL.x, where number 1 starts
const EDGE := 0.24  # clicks this close to a cell edge (as a fraction of the cell) bet on the edge
const OUTSIDE_H := 50.0

# Chips and buttons.
const CHIPS := [1, 5, 25, 100, 500, 1000]
const CHIP_COLORS := ["f1efe8", "d42a2a", "1e9e57", "1c1c1e", "7b3fc4", "e3a21a"]
const CHIP_STRIPES := ["2f6fd6", "ffffff", "ffffff", "e8e8e8", "ffe08a", "fff4d0"]
const CHIP_Y := 530.0
const CHIP_R := 29.0
const BUTTONS := {
	"undo": Rect2(592, 590, 112, 46),
	"clear": Rect2(712, 590, 112, 46),
	"rebet": Rect2(832, 590, 112, 46),
	"double": Rect2(952, 590, 112, 46),
	"spin": Rect2(1082, 498, 168, 138),
	"menu": Rect2(1212, 11, 48, 44),
}
const MENU_RECT := Rect2(390, 120, 500, 480)

# Colors.
const GOLD := Color("e9c15a")
const GOLD_DEEP := Color("a87b22")
const GOLD_LIGHT := Color("fff0b8")
const RED := Color("c8102e")
const BLACK := Color("141416")
const GREEN := Color("0b8a42")
const INK := Color("fdf8ea")
const MUTED := Color(1, 0.96, 0.85, 0.6)
const WOOD := Color("4a1f0e")
const WOOD_LIGHT := Color("8a4a22")

# Money. The balance is what is not on the table.
var balance := START_BALANCE
var shown_balance := float(START_BALANCE)
var last_win := 0
var bets := {}  # key -> {"nums": Array, "anchor": Vector2, "amount": int}
var last_bets := {}
var undo_stack := []  # each entry: Array of {"key", "nums", "anchor", "amount"}
var history := []  # newest first

# Round.
var phase := "bet"  # "bet", "spin" or "result"
var result := -1
var payout := 0
var spin_t := 0.0
var result_t := 0.0
var landed := false

# Wheel and ball.
var wheel_angle := 0.0
var wheel_speed := IDLE_SPEED
var ball_state := "rest"  # "rest" on the track, "spin", or "pocket" riding with the wheel
var ball_world := -PI / 4.0  # ball angle on screen while resting on the track
var ball_rel0 := 0.0
var ball_rel_target := 0.0
var ball_r0 := 0.0
var ball_pos := Vector2.ZERO
var last_tick_pocket := 0
var tick_cooldown := 0.0

# Settings and statistics.
var language := ""
var sound_on := true
var stats := {"spins": 0, "wins": 0, "biggest": 0, "best_balance": START_BALANCE}

# Interface.
var chip := 1  # index in CHIPS
var hover_spot := {}
var hover_button := ""
var hover_chip := -1
var mouse := Vector2.ZERO
var message := "place_bets"
var message_arg := ""
var message_t := 0.0
var menu_open := false
var reset_armed := false
var clock := 0.0
var coins := []

var outside_spots := []
var pocket_index := {}
var serif_bold: Font
var font: Font
var bold: Font
var sfx


func _ready() -> void:
	serif_bold = _font(["Georgia", "Times New Roman", "Cambria"], 700)
	font = _font(["Segoe UI", "Helvetica Neue", "Arial"], 400)
	bold = _font(["Segoe UI", "Helvetica Neue", "Arial"], 700)
	sfx = SfxScript.new()
	add_child(sfx)
	StringsScript.install()
	for i in WHEEL_ORDER.size():
		pocket_index[WHEEL_ORDER[i]] = i
	_build_outside_spots()
	_add_felt()
	_load()
	if language == "":
		language = StringsScript.system_language()
	_apply_settings()
	shown_balance = balance
	if not history.is_empty():
		ball_state = "pocket"


func _font(names: Array, weight: int) -> Font:
	if OS.has_feature("web"):
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 0.7 if weight >= 700 else 0.0
		return variation
	var system := SystemFont.new()
	system.font_names = PackedStringArray(names)
	system.font_weight = weight
	return system


## Green casino felt behind everything, drawn by a shader so it has texture and a soft vignette.
func _add_felt() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 size = vec2(1280.0, 720.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * size;
	float d = length((UV - vec2(0.55, 0.5)) * vec2(1.25, 1.0));
	vec3 col = mix(vec3(0.05, 0.36, 0.2), vec3(0.01, 0.1, 0.055), smoothstep(0.1, 0.85, d));
	col += (hash(floor(p)) - 0.5) * 0.035;
	col += (noise(p * 0.03) - 0.5) * 0.05;
	vec2 q = fract(p / 46.0) - 0.5;
	float diamond = abs(abs(q.x) + abs(q.y) - 0.32);
	col += smoothstep(0.035, 0.0, diamond) * 0.022;
	COLOR = vec4(col, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var felt := ColorRect.new()
	felt.size = SCREEN
	felt.material = material
	felt.show_behind_parent = true
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(felt)


func _apply_settings() -> void:
	TranslationServer.set_locale(language)
	AudioServer.set_bus_mute(0, not sound_on)


# --- Numbers and bets ------------------------------------------------------------------------

func _color_of(n: int) -> Color:
	if n == 0:
		return GREEN
	return RED if n in REDS else BLACK


func _color_key(n: int) -> String:
	if n == 0:
		return "green"
	return "red" if n in REDS else "black"


## Number in grid column c (0 = numbers 1 to 3) and row r (0 = top row: 3, 6, 9...).
func _num(c: int, r: int) -> int:
	return c * 3 + (3 - r)


func _cell_rect(n: int) -> Rect2:
	if n == 0:
		return Rect2(TABLE, Vector2(CELL.x, CELL.y * 3))
	var c := (n - 1) / 3
	var r := 2 - (n - 1) % 3
	return Rect2(GRID_X + c * CELL.x, TABLE.y + r * CELL.y, CELL.x, CELL.y)


func _build_outside_spots() -> void:
	outside_spots.clear()
	outside_spots.append({"key": "n:0", "nums": [0], "rect": _cell_rect(0), "label": "0"})
	for r in 3:
		var nums := []
		for c in 12:
			nums.append(_num(c, r))
		var rect := Rect2(GRID_X + 12 * CELL.x, TABLE.y + r * CELL.y, CELL.x, CELL.y)
		outside_spots.append({"key": "col:%d" % r, "nums": nums, "rect": rect, "label": "2:1"})
	var dozen_y := TABLE.y + CELL.y * 3
	for d in 3:
		var nums := []
		for n in range(d * 12 + 1, d * 12 + 13):
			nums.append(n)
		var rect := Rect2(GRID_X + d * 4 * CELL.x, dozen_y, CELL.x * 4, OUTSIDE_H)
		outside_spots.append({"key": "doz:%d" % d, "nums": nums, "rect": rect, "label": "dozen_%d" % (d + 1)})
	var names := ["low", "even", "red", "black", "odd", "high"]
	for i in names.size():
		var nums := []
		for n in range(1, 37):
			var take := false
			match names[i]:
				"low": take = n <= 18
				"high": take = n >= 19
				"even": take = n % 2 == 0
				"odd": take = n % 2 == 1
				"red": take = n in REDS
				"black": take = not n in REDS
			if take:
				nums.append(n)
		var rect := Rect2(GRID_X + i * 2 * CELL.x, dozen_y + OUTSIDE_H, CELL.x * 2, OUTSIDE_H)
		outside_spots.append({"key": names[i], "nums": nums, "rect": rect, "label": names[i]})


## The bet spot under `pos`: {"key", "nums", "anchor"}, or {} when there is none.
func _spot_at(pos: Vector2) -> Dictionary:
	var grid := Rect2(GRID_X - 9, TABLE.y, CELL.x * 12 + 9, CELL.y * 3 + 9)
	if grid.has_point(pos):
		var fx := (pos.x - GRID_X) / CELL.x
		var fy := (pos.y - TABLE.y) / CELL.y
		var c := clampi(floori(fx), 0, 11)
		var r := clampi(floori(fy), 0, 2)
		var dx := fx - c
		var dy := fy - r
		# Nearest line the click is on: vx between columns (0 = next to zero), hy between rows (3 = bottom).
		var vx := c if dx < EDGE else (c + 1 if dx > 1.0 - EDGE else -1)
		var hy := r if dy < EDGE else (r + 1 if dy > 1.0 - EDGE else -1)
		if vx == 12:
			vx = -1
		if hy == 0:
			hy = -1
		var nums := []
		if vx == -1 and hy == -1:
			nums = [_num(c, r)]
		elif vx == -1 and hy < 3:
			nums = [_num(c, hy - 1), _num(c, hy)]
		elif vx == -1:
			nums = [_num(c, 0), _num(c, 1), _num(c, 2)]
		elif vx == 0 and hy == -1:
			nums = [0, _num(0, r)]
		elif vx == 0 and hy < 3:
			nums = [0, _num(0, hy - 1), _num(0, hy)]
		elif vx == 0:
			nums = [0, 1, 2, 3]
		elif hy == -1:
			nums = [_num(vx - 1, r), _num(vx, r)]
		elif hy < 3:
			nums = [_num(vx - 1, hy - 1), _num(vx, hy - 1), _num(vx - 1, hy), _num(vx, hy)]
		else:
			nums = [_num(vx - 1, 0), _num(vx - 1, 1), _num(vx - 1, 2), _num(vx, 0), _num(vx, 1), _num(vx, 2)]
		nums.sort()
		var anchor := Vector2(
				GRID_X + (vx * CELL.x if vx >= 0 else (c + 0.5) * CELL.x),
				TABLE.y + (hy * CELL.y if hy >= 0 else (r + 0.5) * CELL.y))
		return {"key": "n:" + "-".join(nums.map(func(n): return str(n))), "nums": nums, "anchor": anchor}
	for spot in outside_spots:
		if spot.rect.has_point(pos):
			return {"key": spot.key, "nums": spot.nums, "anchor": spot.rect.get_center()}
	return {}


func _total_bet() -> int:
	var total := 0
	for key in bets:
		total += bets[key].amount
	return total


## Changes the stake on a spot by `amount` (negative takes chips back). Returns false if it can't.
func _change_bet(key: String, nums: Array, anchor: Vector2, amount: int) -> bool:
	var current: int = bets[key].amount if bets.has(key) else 0
	if amount > balance or current + amount < 0:
		return false
	if current + amount > MAX_STAKE:
		return false
	if current + amount == 0:
		bets.erase(key)
	else:
		bets[key] = {"nums": nums, "anchor": anchor, "amount": current + amount}
	balance -= amount
	return true


func _place(spot: Dictionary) -> void:
	var amount: int = CHIPS[chip]
	var current: int = bets[spot.key].amount if bets.has(spot.key) else 0
	if current + amount > MAX_STAKE:
		_say("table_max")
		sfx.play("error")
		return
	if amount > balance:
		_say("no_money" if balance > 0 or not bets.is_empty() else "broke")
		sfx.play("error")
		return
	_change_bet(spot.key, spot.nums, spot.anchor, amount)
	undo_stack.append([{"key": spot.key, "nums": spot.nums, "anchor": spot.anchor, "amount": amount}])
	sfx.play("chip", randf_range(0.92, 1.08))
	_say("place_bets")


func _take_back(spot: Dictionary) -> void:
	if not bets.has(spot.key):
		return
	var amount: int = mini(CHIPS[chip], bets[spot.key].amount)
	_change_bet(spot.key, spot.nums, spot.anchor, -amount)
	undo_stack.append([{"key": spot.key, "nums": spot.nums, "anchor": spot.anchor, "amount": -amount}])
	sfx.play("remove")


func _undo() -> void:
	if phase != "bet" or undo_stack.is_empty():
		return
	var changes: Array = undo_stack.pop_back()
	for i in range(changes.size() - 1, -1, -1):
		var change: Dictionary = changes[i]
		_change_bet(change.key, change.nums, change.anchor, -change.amount)
	sfx.play("remove")


func _clear() -> void:
	if phase != "bet" or bets.is_empty():
		return
	var changes := []
	for key in bets.keys():
		var bet: Dictionary = bets[key]
		changes.append({"key": key, "nums": bet.nums, "anchor": bet.anchor, "amount": -bet.amount})
		_change_bet(key, bet.nums, bet.anchor, -bet.amount)
	undo_stack.append(changes)
	sfx.play("remove")


func _rebet() -> void:
	if phase != "bet" or last_bets.is_empty() or not bets.is_empty():
		return
	var total := 0
	for key in last_bets:
		total += last_bets[key].amount
	if total > balance:
		_say("no_money")
		sfx.play("error")
		return
	var changes := []
	for key in last_bets:
		var bet: Dictionary = last_bets[key]
		_change_bet(key, bet.nums, bet.anchor, bet.amount)
		changes.append({"key": key, "nums": bet.nums, "anchor": bet.anchor, "amount": bet.amount})
	undo_stack.append(changes)
	sfx.play("chip")


func _double() -> void:
	if phase != "bet" or bets.is_empty():
		return
	if _total_bet() > balance:
		_say("no_money")
		sfx.play("error")
		return
	var changes := []
	for key in bets.keys():
		var bet: Dictionary = bets[key]
		var amount := mini(bet.amount, MAX_STAKE - bet.amount)
		if amount > 0:
			_change_bet(key, bet.nums, bet.anchor, amount)
			changes.append({"key": key, "nums": bet.nums, "anchor": bet.anchor, "amount": amount})
	if changes.is_empty():
		_say("table_max")
		sfx.play("error")
		return
	undo_stack.append(changes)
	sfx.play("chip")


func _say(key: String, arg := "") -> void:
	message = key
	message_arg = arg
	message_t = 0.0


# --- Round -----------------------------------------------------------------------------------

func _spin() -> void:
	if phase == "result":
		_finish_round()
	if phase != "bet":
		return
	if bets.is_empty():
		if balance < CHIPS[0]:
			_refill()
		else:
			_say("need_bet")
			sfx.play("error")
		return
	result = randi() % 37
	payout = 0
	for key in bets:
		var bet: Dictionary = bets[key]
		if result in bet.nums:
			payout += bet.amount * 36 / bet.nums.size()
	phase = "spin"
	spin_t = 0.0
	landed = false
	wheel_speed = SPIN_SPEED
	# The ball is thrown from where it is, against the wheel's turn.
	ball_r0 = ball_pos.distance_to(WHEEL_CENTER) if ball_state == "pocket" else _track_r()
	var world := (ball_pos - WHEEL_CENTER).angle() if ball_state == "pocket" else ball_world
	ball_rel0 = world - wheel_angle
	var target: float = pocket_index[result] * POCKET
	ball_rel_target = ball_rel0 - fposmod(ball_rel0 - target, TAU) - 5.0 * TAU
	ball_state = "spin"
	last_tick_pocket = 0
	stats.spins += 1
	_say("no_more_bets")
	sfx.play("spin")
	_save()


func _resolve() -> void:
	phase = "result"
	result_t = 0.0
	history.push_front(result)
	if history.size() > HISTORY_SIZE:
		history.resize(HISTORY_SIZE)
	balance += payout
	last_win = payout
	if payout > 0:
		stats.wins += 1
		stats.biggest = maxi(stats.biggest, payout)
		_say("you_win", _money(payout))
		sfx.play("win")
		var total := _total_bet()
		if payout >= total * 5:
			sfx.play("coins")
		_burst(clampi(int(10.0 + 4.0 * payout / maxf(total, 1.0)), 14, 90))
	else:
		_say("you_lose")
		sfx.play("lose")
	stats.best_balance = maxi(stats.best_balance, balance)
	_save()


func _finish_round() -> void:
	if phase != "result":
		return
	last_bets = bets.duplicate(true)
	bets.clear()
	undo_stack.clear()
	phase = "bet"
	if balance < CHIPS[0]:
		_say("broke")
	else:
		_say("place_bets")


func _refill() -> void:
	balance += START_BALANCE
	shown_balance = balance
	sfx.play("coins")
	_say("place_bets")
	_save()


func _burst(count: int) -> void:
	for i in count:
		var angle := randf_range(-PI * 0.95, -PI * 0.05)
		coins.append({
			"pos": WHEEL_CENTER + Vector2.from_angle(angle) * WHEEL_R * 0.42,
			"vel": Vector2.from_angle(angle) * randf_range(260, 620),
			"spin": randf_range(6, 14),
			"phase": randf() * TAU,
			"t": 0.0,
		})


func _track_r() -> float:
	return WHEEL_R * 0.855


func _pocket_r() -> float:
	return WHEEL_R * 0.575


# --- Frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	clock += delta
	message_t += delta
	tick_cooldown -= delta
	wheel_speed = lerpf(wheel_speed, IDLE_SPEED, 1.0 - exp(-delta * (0.32 if phase == "spin" else 1.5)))
	wheel_angle = fmod(wheel_angle + wheel_speed * delta, TAU)
	shown_balance = lerpf(shown_balance, balance, 1.0 - exp(-delta * 3.5))
	if absf(shown_balance - balance) < 0.5:
		shown_balance = balance

	if phase == "spin":
		spin_t += delta
		if spin_t >= LAND_TIME and not landed:
			landed = true
			ball_state = "pocket"
			sfx.play("land")
		if spin_t >= RESOLVE_TIME:
			_resolve()
	elif phase == "result":
		result_t += delta
		if result_t >= RESULT_TIME:
			_finish_round()
	_update_ball()

	for coin in coins:
		coin.t += delta
		coin.vel.y += 900.0 * delta
		coin.pos += coin.vel * delta
	coins = coins.filter(func(c): return c.t < 2.5 and c.pos.y < SCREEN.y + 40)
	queue_redraw()


func _update_ball() -> void:
	match ball_state:
		"rest":
			ball_pos = WHEEL_CENTER + Vector2.from_angle(ball_world) * _track_r()
		"pocket":
			var shown: int = result if result >= 0 else (history[0] if not history.is_empty() else 0)
			var angle: float = wheel_angle + pocket_index[shown] * POCKET
			ball_pos = WHEEL_CENTER + Vector2.from_angle(angle) * _pocket_r()
		"spin":
			var u := clampf(spin_t / LAND_TIME, 0.0, 1.0)
			var eased := 1.0 - pow(1.0 - u, 3.0)
			var rel := lerpf(ball_rel0, ball_rel_target, eased)
			# Drop from the track into the pockets, bouncing over the frets.
			var d := clampf((u - 0.5) / 0.42, 0.0, 1.0)
			var r := _track_r()
			if spin_t < 0.3:
				r = lerpf(ball_r0, _track_r(), smoothstep(0.0, 0.3, spin_t))
			if d > 0.0:
				r = lerpf(_track_r(), _pocket_r(), smoothstep(0.0, 1.0, d))
				r += absf(sin(d * PI * 3.0)) * WHEEL_R * 0.07 * (1.0 - d)
				rel += sin(d * PI * 5.0) * 0.12 * (1.0 - d) * d
				var pocket := floori(rel / POCKET + 0.5)
				if pocket != last_tick_pocket and tick_cooldown <= 0.0 and d < 0.97:
					sfx.play("tick", randf_range(0.85, 1.2))
					tick_cooldown = 0.045
				last_tick_pocket = pocket
			ball_pos = WHEEL_CENTER + Vector2.from_angle(wheel_angle + rel) * r


# --- Input -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		_update_hover()
	elif event is InputEventMouseButton and event.pressed:
		mouse = event.position
		_update_hover()
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not menu_open:
			if phase == "result":
				_finish_round()
			if phase == "bet" and not hover_spot.is_empty():
				_take_back(hover_spot)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)


func _key(code: int) -> void:
	if code == KEY_ESCAPE:
		_toggle_menu()
		return
	if menu_open:
		return
	match code:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_spin()
		KEY_BACKSPACE, KEY_DELETE:
			_clear()
		KEY_Z:
			_undo()
		KEY_R:
			_rebet()
		KEY_D:
			_double()
		_:
			if code >= KEY_1 and code < KEY_1 + CHIPS.size():
				chip = code - KEY_1
				sfx.play("click")


func _update_hover() -> void:
	hover_button = ""
	hover_chip = -1
	hover_spot = {}
	if menu_open:
		return
	for button: String in BUTTONS:
		if BUTTONS[button].has_point(mouse):
			hover_button = button
			return
	for i in CHIPS.size():
		if mouse.distance_to(_chip_center(i)) <= CHIP_R + 4:
			hover_chip = i
			return
	if phase != "spin":
		hover_spot = _spot_at(mouse)


func _click() -> void:
	if menu_open:
		_menu_click()
		return
	if hover_button != "":
		if hover_button == "menu":
			_toggle_menu()
			return
		if phase == "result" and hover_button != "spin":
			_finish_round()
		if not _button_enabled(hover_button):
			return
		sfx.play("click")
		match hover_button:
			"spin": _spin()
			"undo": _undo()
			"clear": _clear()
			"rebet": _rebet()
			"double": _double()
	elif hover_chip >= 0:
		chip = hover_chip
		sfx.play("click")
	elif not hover_spot.is_empty():
		if phase == "result":
			_finish_round()
		if phase == "bet":
			_place(hover_spot)


func _button_enabled(name: String) -> bool:
	var betting := phase != "spin"
	match name:
		"spin": return betting
		"undo": return phase == "bet" and not undo_stack.is_empty()
		"clear": return phase == "bet" and not bets.is_empty()
		"rebet": return (phase == "result" and not bets.is_empty()) or (phase == "bet" and bets.is_empty() and not last_bets.is_empty())
		"double": return phase == "bet" and not bets.is_empty()
	return true


func _toggle_menu() -> void:
	menu_open = not menu_open
	reset_armed = false
	sfx.play("click")
	_update_hover()


func _menu_rows() -> Dictionary:
	var x := MENU_RECT.position.x + 30
	var w := MENU_RECT.size.x - 60
	var y := MENU_RECT.position.y
	return {
		"language": Rect2(x, y + 76, w, 46),
		"sound": Rect2(x, y + 128, w, 46),
		"reset": Rect2(x, y + 370, w, 44),
		"close": Rect2(MENU_RECT.end.x - 52, y + 12, 40, 40),
	}


func _menu_click() -> void:
	if not MENU_RECT.has_point(mouse):
		_toggle_menu()
		return
	var rows := _menu_rows()
	if rows.language.has_point(mouse):
		var codes := StringsScript.LANGUAGES.map(func(l): return l[0])
		var step := -1 if mouse.x < rows.language.get_center().x - 60 else 1
		language = codes[(codes.find(language) + step + codes.size()) % codes.size()]
		_apply_settings()
		sfx.play("click")
		_save()
	elif rows.sound.has_point(mouse):
		sound_on = not sound_on
		_apply_settings()
		sfx.play("click")
		_save()
	elif rows.reset.has_point(mouse):
		if not reset_armed:
			reset_armed = true
			sfx.play("click")
			return
		bets.clear()
		last_bets.clear()
		undo_stack.clear()
		history.clear()
		balance = START_BALANCE
		shown_balance = balance
		last_win = 0
		stats = {"spins": 0, "wins": 0, "biggest": 0, "best_balance": START_BALANCE}
		if phase != "spin":
			phase = "bet"
			result = -1
			ball_state = "rest"
		reset_armed = false
		menu_open = false
		sfx.play("coins")
		_say("place_bets")
		_save()
	elif rows.close.has_point(mouse):
		_toggle_menu()
	reset_armed = false


# --- Saving ----------------------------------------------------------------------------------

## Chips still on the table go back to the balance; a spin in progress counts as already paid.
func _settled_balance() -> int:
	match phase:
		"bet": return balance + _total_bet()
		"spin": return balance + payout
	return balance


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "balance", _settled_balance())
	config.set_value("game", "history", history)
	config.set_value("game", "stats", stats)
	config.set_value("settings", "language", language)
	config.set_value("settings", "sound", sound_on)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	balance = int(config.get_value("game", "balance", START_BALANCE))
	history = config.get_value("game", "history", [])
	var saved: Dictionary = config.get_value("game", "stats", {})
	for key in stats:
		stats[key] = int(saved.get(key, stats[key]))
	language = config.get_value("settings", "language", "")
	sound_on = config.get_value("settings", "sound", true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


# --- Drawing helpers -------------------------------------------------------------------------

func _money(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


func _short(value: int) -> String:
	if value >= 10000:
		return "%dK" % (value / 1000)
	if value >= 1000:
		var text := "%.1fK" % (value / 1000.0)
		return text.replace(".0K", "K")
	return str(value)


## Draws text centered on `center` (both ways).
func _text(text: String, center: Vector2, size: int, color: Color, f: Font = null, shadow := false) -> void:
	if f == null:
		f = bold
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2(center.x - width / 2.0, center.y + (f.get_ascent(size) - f.get_descent(size)) / 2.0)
	if shadow:
		draw_string(f, base + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.55 * color.a))
	draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_left(text: String, pos: Vector2, size: int, color: Color, f: Font = null) -> void:
	if f == null:
		f = font
	draw_string(f, Vector2(pos.x, pos.y + (f.get_ascent(size) - f.get_descent(size)) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_right(text: String, pos: Vector2, size: int, color: Color, f: Font = null) -> void:
	if f == null:
		f = bold
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text_left(text, Vector2(pos.x - width, pos.y), size, color, f)


## A slice of a ring between radii r0 and r1, shaded from `inner` to `outer`.
func _ring(center: Vector2, r0: float, r1: float, a0: float, a1: float, inner: Color, outer: Color, steps := 3) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / steps)
		points.append(center + Vector2.from_angle(a) * r1)
		colors.append(outer)
	for i in range(steps, -1, -1):
		var a := lerpf(a0, a1, float(i) / steps)
		points.append(center + Vector2.from_angle(a) * r0)
		colors.append(inner)
	draw_polygon(points, colors)


## A full ring, split into slices so every polygon stays simple.
func _full_ring(center: Vector2, r0: float, r1: float, inner: Color, outer: Color) -> void:
	for i in 48:
		_ring(center, r0, r1, i * TAU / 48.0, (i + 1) * TAU / 48.0 + 0.002, inner, outer, 2)


func _box(rect: Rect2, fill: Color, border: Color, radius: float, width := 1.5, shadow := 0.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(int(width) if width >= 1.0 else 0)
	style.set_corner_radius_all(int(radius))
	style.anti_aliasing = true
	if shadow > 0.0:
		style.shadow_color = Color(0, 0, 0, 0.45)
		style.shadow_size = int(shadow)
		style.shadow_offset = Vector2(0, shadow * 0.4)
	draw_style_box(style, rect)


func _gradient_rect(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
			PackedColorArray([top, top, bottom, bottom]))


# --- Drawing ---------------------------------------------------------------------------------

func _draw() -> void:
	_draw_header()
	_draw_wheel()
	_draw_result_badge()
	_draw_history()
	_draw_table()
	_draw_bets()
	_draw_chip_rack()
	_draw_buttons()
	_draw_message()
	_draw_coins()
	if menu_open:
		_draw_menu()


func _draw_header() -> void:
	_gradient_rect(Rect2(0, 0, SCREEN.x, 66), Color(0.02, 0.04, 0.03, 0.92), Color(0.03, 0.09, 0.06, 0.85))
	draw_line(Vector2(0, 66), Vector2(SCREEN.x, 66), GOLD_DEEP, 2.0)
	draw_line(Vector2(0, 69), Vector2(SCREEN.x, 69), Color(GOLD, 0.25), 1.0)
	# Emblem: a small wheel.
	var e := Vector2(46, 33)
	for i in 12:
		var col := GREEN if i == 0 else (RED if i % 2 == 0 else BLACK)
		_ring(e, 9, 21, i * TAU / 12.0 + clock * 0.4, (i + 1) * TAU / 12.0 + clock * 0.4, col.darkened(0.2), col.lightened(0.1), 2)
	draw_arc(e, 21.5, 0, TAU, 40, GOLD, 2.5, true)
	draw_circle(e, 9, GOLD_DEEP)
	draw_circle(e, 5, GOLD)
	# Title in gold, letter by letter.
	var x := 80.0
	for letter in "ROLETA":
		var width := serif_bold.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		draw_string(serif_bold, Vector2(x + 2, 49), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0, 0, 0, 0.6))
		draw_string(serif_bold, Vector2(x, 47), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, GOLD_DEEP)
		draw_string(serif_bold, Vector2(x, 46), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, GOLD)
		x += width + 5.0
	# Money.
	var balance_rect := Rect2(560, 9, 200, 48)
	if shown_balance < balance - 0.5:
		_box(balance_rect.grow(4), Color(GOLD, 0.35 + 0.2 * sin(clock * 20.0)), Color(0, 0, 0, 0), 14, 0.0)
	_pill(balance_rect, tr("balance"), _money(roundi(shown_balance)), GOLD_LIGHT)
	_pill(Rect2(772, 9, 150, 48), tr("total_bet"), _money(_total_bet()), INK)
	_pill(Rect2(934, 9, 150, 48), tr("last_win"), _money(last_win), Color("7dffb0") if last_win > 0 else INK)
	_draw_gear(BUTTONS.menu.get_center(), hover_button == "menu")


func _pill(rect: Rect2, label: String, value: String, color: Color) -> void:
	_box(rect, Color(0, 0, 0, 0.45), Color(GOLD, 0.45), 10, 1.0)
	_text(label, Vector2(rect.get_center().x, rect.position.y + 13), 11, MUTED, bold)
	_text(value, Vector2(rect.get_center().x, rect.position.y + 32), 21, color, bold)


func _draw_gear(center: Vector2, hot: bool) -> void:
	var points := PackedVector2Array()
	for i in 48:
		var a := i * TAU / 48.0
		var tooth := fmod(float(i), 6.0) < 3.0
		points.append(center + Vector2.from_angle(a) * (13.0 if tooth else 10.0))
	var col := GOLD_LIGHT if hot else GOLD
	draw_colored_polygon(points, col)
	draw_circle(center, 5, Color(0.02, 0.06, 0.04))


func _draw_wheel() -> void:
	var c := WHEEL_CENTER
	var R := WHEEL_R
	# Shadow and wooden bowl.
	draw_circle(c + Vector2(0, 14), R + 22, Color(0, 0, 0, 0.25))
	draw_circle(c + Vector2(0, 8), R + 16, Color(0, 0, 0, 0.35))
	_full_ring(c, R * 0.99, R + 16, Color("2a0e05"), WOOD_LIGHT)
	draw_arc(c, R + 16, 0, TAU, 128, GOLD_DEEP, 2.0, true)
	draw_arc(c, R + 12.5, 0, TAU, 128, Color(GOLD, 0.35), 1.0, true)
	# Ball track, polished and bright near the rim.
	_full_ring(c, R * 0.8, R, Color("2d1309"), Color("b98a5a"))
	draw_arc(c, R, 0, TAU, 128, GOLD, 2.0, true)
	# Deflectors on the bowl.
	for i in 8:
		var a := i * TAU / 8.0 + PI / 8.0
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal()
		var p := c + dir * R * 0.9
		var diamond := PackedVector2Array([p + dir * 9, p + side * 4.5, p - dir * 9, p - side * 4.5])
		draw_colored_polygon(diamond, GOLD)
		draw_line(p - dir * 7, p + dir * 7, GOLD_LIGHT, 1.0, true)

	# Rotor: numbers, pockets and the cone, all turning with the wheel.
	var w := wheel_angle
	for i in 37:
		var n: int = WHEEL_ORDER[i]
		var a0 := w + (i - 0.5) * POCKET
		var a1 := w + (i + 0.5) * POCKET
		var col := _color_of(n)
		var won := phase == "result" and n == result
		var number_col := col.lerp(GOLD, 0.45 + 0.25 * sin(clock * 8.0)) if won else col
		_ring(c, R * 0.635, R * 0.79, a0, a1, number_col.darkened(0.25), number_col.lightened(0.12))
		_ring(c, R * 0.52, R * 0.635, a0, a1, col.darkened(0.7), col.darkened(0.35))
		var fret := Vector2.from_angle(a0)
		draw_line(c + fret * R * 0.52, c + fret * R * 0.79, GOLD, 1.6, true)
		# Number, reading outwards.
		var mid := w + i * POCKET
		draw_set_transform(c + Vector2.from_angle(mid) * R * 0.712, mid + PI / 2.0)
		var label := str(n)
		var size := 17
		var width := serif_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(serif_bold, Vector2(-width / 2.0, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	draw_arc(c, R * 0.79, 0, TAU, 128, GOLD, 2.0, true)
	draw_arc(c, R * 0.635, 0, TAU, 128, GOLD, 1.6, true)
	draw_arc(c, R * 0.52, 0, TAU, 128, GOLD_DEEP, 3.0, true)
	# Cone.
	_full_ring(c, R * 0.16, R * 0.515, Color("c98b4a"), Color("3a1508"))
	for i in 4:
		var a := w + i * TAU / 4.0 + POCKET * 0.5
		var dir := Vector2.from_angle(a)
		draw_line(c + dir * R * 0.2, c + dir * R * 0.5, Color(GOLD, 0.55), 2.0, true)
	draw_arc(c, R * 0.33, 0, TAU, 96, Color(GOLD, 0.35), 1.2, true)
	# Turret with its four arms.
	for i in 4:
		var dir := Vector2.from_angle(w + i * TAU / 4.0 + POCKET * 0.5 + PI / 4.0)
		draw_line(c, c + dir * R * 0.3, GOLD_DEEP, 9.0, true)
		draw_line(c, c + dir * R * 0.3, GOLD, 5.0, true)
		draw_circle(c + dir * R * 0.3, 7.5, GOLD_DEEP)
		draw_circle(c + dir * R * 0.3, 5.5, GOLD)
		draw_circle(c + dir * R * 0.3 + Vector2(-1.5, -1.5), 2.0, GOLD_LIGHT)
	draw_circle(c, R * 0.12, GOLD_DEEP)
	draw_circle(c, R * 0.1, GOLD)
	draw_circle(c + Vector2(-5, -6), R * 0.045, GOLD_LIGHT)
	# Glass-like shine over the top left of the wheel.
	draw_arc(c, R * 0.9, PI * 1.05, PI * 1.45, 32, Color(1, 1, 1, 0.1), R * 0.12, true)
	draw_arc(c, R * 0.72, PI * 1.1, PI * 1.35, 24, Color(1, 1, 1, 0.06), R * 0.08, true)
	_draw_ball()


func _draw_ball() -> void:
	var p := ball_pos
	draw_circle(p + Vector2(2.5, 3.5), 8.5, Color(0, 0, 0, 0.4))
	draw_circle(p, 8.5, Color("c9ccd2"))
	draw_circle(p + Vector2(-0.8, -0.8), 7.3, Color("f4f5f7"))
	draw_circle(p + Vector2(-2.6, -2.8), 3.0, Color.WHITE)


## The winning number grows out of the middle of the wheel.
func _draw_result_badge() -> void:
	if phase != "result":
		return
	var show := _back_out(clampf(result_t / 0.45, 0.0, 1.0)) * clampf((RESULT_TIME - result_t) / 0.3, 0.0, 1.0)
	if show <= 0.0:
		return
	var c := WHEEL_CENTER
	var r := WHEEL_R * 0.36 * show
	var col := _color_of(result)
	draw_circle(c + Vector2(0, 6), r + 8, Color(0, 0, 0, 0.45))
	draw_circle(c, r + 6, GOLD_DEEP)
	draw_circle(c, r + 3, GOLD)
	_full_ring(c, 0, r, col.lightened(0.25), col.darkened(0.35))
	if show > 0.6:
		_text(str(result), c + Vector2(0, -10), int(64 * show), Color.WHITE, serif_bold, true)
		_text(tr(_color_key(result)), c + Vector2(0, 36 * show), int(15 * show), Color(1, 1, 1, 0.85), bold)


func _back_out(x: float) -> float:
	var s := 1.7
	x -= 1.0
	return x * x * ((s + 1.0) * x + s) + 1.0


func _draw_history() -> void:
	var y := 102.0
	_text_left(tr("history"), Vector2(TABLE.x, 84), 11, MUTED, bold)
	if history.is_empty():
		for i in HISTORY_SIZE:
			draw_arc(Vector2(TABLE.x + 17 + i * 43, y + 11), 15, 0, TAU, 32, Color(1, 1, 1, 0.12), 1.5, true)
		return
	for i in history.size():
		var n: int = history[i]
		var r := 17.0 if i == 0 else 15.0
		var p := Vector2(TABLE.x + 17 + i * 43, y + 11)
		var fade := 1.0 - i * 0.04
		draw_circle(p + Vector2(0, 2), r, Color(0, 0, 0, 0.4))
		draw_circle(p, r, _color_of(n).lightened(0.05))
		draw_arc(p, r, 0, TAU, 32, GOLD if i == 0 else Color(GOLD, 0.35), 2.0 if i == 0 else 1.0, true)
		_text(str(n), p, 16 if i == 0 else 14, Color(1, 1, 1, fade), bold)


func _draw_table() -> void:
	# Wooden frame around the felt.
	var frame := Rect2(TABLE.x - 14, TABLE.y - 14, CELL.x * 14 + 28, CELL.y * 3 + OUTSIDE_H * 2 + 28)
	_box(frame, WOOD, GOLD_DEEP, 14, 2.0, 12)
	_box(frame.grow(-6), Color("0f6a3c"), Color(GOLD, 0.6), 9, 1.0)

	var pulse := 0.5 + 0.5 * sin(clock * 7.0)
	var highlight := {}
	if not hover_spot.is_empty() and phase != "spin":
		for n in hover_spot.nums:
			highlight[n] = true

	# Numbers.
	for n in range(1, 37):
		var rect := _cell_rect(n).grow(-2)
		var col := _color_of(n)
		_gradient_rect(rect, col.lightened(0.12), col.darkened(0.2))
		if highlight.has(n):
			draw_rect(rect, Color(1, 1, 1, 0.22))
		_text(str(n), rect.get_center(), 22, Color.WHITE, serif_bold, true)
	# Zero, pointed on the left.
	var z := _cell_rect(0)
	var zero := PackedVector2Array([Vector2(z.end.x - 2, z.position.y + 2), Vector2(z.position.x + 16, z.position.y + 2),
			Vector2(z.position.x + 2, z.get_center().y), Vector2(z.position.x + 16, z.end.y - 2), Vector2(z.end.x - 2, z.end.y - 2)])
	draw_polygon(zero, PackedColorArray([GREEN.lightened(0.15), GREEN.lightened(0.15), GREEN, GREEN.darkened(0.2), GREEN.darkened(0.2)]))
	if highlight.has(0):
		draw_colored_polygon(zero, Color(1, 1, 1, 0.22))
	var zero_line := zero.duplicate()
	zero_line.append(zero[0])
	draw_polyline(zero_line, GOLD, 2.0, true)
	_text("0", z.get_center() + Vector2(3, 0), 26, Color.WHITE, serif_bold, true)

	# Outside bets.
	for spot in outside_spots:
		if spot.key == "n:0":
			continue
		var rect: Rect2 = spot.rect
		var hovered: bool = not hover_spot.is_empty() and hover_spot.key == spot.key
		if hovered:
			draw_rect(rect, Color(1, 1, 1, 0.14))
		if phase == "result" and result in spot.nums:
			draw_rect(rect, Color(GOLD, 0.16 + 0.12 * pulse))
		match spot.key:
			"red", "black":
				var col := RED if spot.key == "red" else BLACK
				var p := rect.get_center()
				var diamond := PackedVector2Array([p + Vector2(0, -17), p + Vector2(30, 0), p + Vector2(0, 17), p + Vector2(-30, 0)])
				draw_polygon(diamond, PackedColorArray([col.lightened(0.2), col, col.darkened(0.3), col]))
				diamond.append(diamond[0])
				draw_polyline(diamond, GOLD, 1.5, true)
			_:
				var label: String = spot.label if spot.label == "2:1" else tr(spot.label)
				var size := 16 if spot.key.begins_with("col") else 15
				_text(label, rect.get_center(), size, INK, bold)

	# Gold lines.
	var bottom := TABLE.y + CELL.y * 3
	for c in 14:
		var x := GRID_X + c * CELL.x
		draw_line(Vector2(x, TABLE.y), Vector2(x, bottom), GOLD, 2.0)
	for r in 4:
		var y := TABLE.y + r * CELL.y
		draw_line(Vector2(GRID_X, y), Vector2(GRID_X + CELL.x * 13, y), GOLD, 2.0)
	for d in 4:
		var x := GRID_X + d * 4 * CELL.x
		draw_line(Vector2(x, bottom), Vector2(x, bottom + OUTSIDE_H), GOLD, 2.0)
	for i in 7:
		var x := GRID_X + i * 2 * CELL.x
		draw_line(Vector2(x, bottom + OUTSIDE_H), Vector2(x, bottom + OUTSIDE_H * 2), GOLD, 2.0)
	for y in [bottom + OUTSIDE_H, bottom + OUTSIDE_H * 2]:
		draw_line(Vector2(GRID_X, y), Vector2(GRID_X + CELL.x * 12, y), GOLD, 2.0)

	# Winning number glows.
	if phase == "result":
		var rect := _cell_rect(result)
		for k in 3:
			draw_rect(rect.grow(2 + k * 3), Color(GOLD_LIGHT, (0.5 - k * 0.15) * (0.6 + 0.4 * pulse)), false, 3.0)
		# The dolly marks the winning number.
		var p := rect.get_center() + Vector2(0, -2)
		draw_circle(p + Vector2(0, 4), 12, Color(0, 0, 0, 0.35))
		draw_circle(p, 12, Color(1, 1, 1, 0.9))
		draw_circle(p, 9, Color(0.85, 0.9, 1.0, 0.95))
		draw_circle(p + Vector2(-3, -3), 3.5, Color.WHITE)

	# Help line, or what the hovered spot pays.
	var help := tr("bet_help")
	if not hover_spot.is_empty() and phase != "spin":
		var nums: Array = hover_spot.nums
		var names := ""
		if nums.size() <= 6:
			names = " – ".join(nums.map(func(n): return str(n))) + "   ·   "
		help = names + tr("pays") % (36 / nums.size() - 1)
	_text(help, Vector2(TABLE.x + CELL.x * 7, 474), 13, MUTED, font)


func _draw_bets() -> void:
	var fade := 1.0
	if phase == "result":
		fade = 1.0 - clampf((result_t - 0.4) / 0.5, 0.0, 1.0)
	for key in bets:
		var bet: Dictionary = bets[key]
		var wins: bool = phase == "result" and result in bet.nums
		var alpha := 1.0 if (phase != "result" or wins) else fade
		if alpha <= 0.0:
			continue
		if wins:
			draw_circle(bet.anchor, 23 + 3 * sin(clock * 8.0), Color(GOLD_LIGHT, 0.35))
		_draw_stack(bet.anchor, bet.amount, 17.0, alpha)
	# Ghost chip where a click would bet.
	if phase != "spin" and not hover_spot.is_empty() and not menu_open:
		var current: int = bets[hover_spot.key].amount if bets.has(hover_spot.key) else 0
		if current == 0:
			_draw_chip(hover_spot.anchor, 17.0, chip, _short(CHIPS[chip]), 0.55)


## A pile of chips worth `amount`, largest at the bottom, labeled with the total on top.
func _draw_stack(pos: Vector2, amount: int, radius: float, alpha: float) -> void:
	var pile := []
	var left := amount
	for i in range(CHIPS.size() - 1, -1, -1):
		while left >= CHIPS[i] and pile.size() < 6:
			pile.append(i)
			left -= CHIPS[i]
	if pile.is_empty():
		pile.append(0)
	for i in pile.size():
		var p := pos - Vector2(0, i * 3.5)
		var top := i == pile.size() - 1
		_draw_chip(p, radius, pile[i], _short(amount) if top else "", alpha)


func _draw_chip(pos: Vector2, radius: float, index: int, label: String, alpha := 1.0) -> void:
	var base := Color(CHIP_COLORS[index])
	var stripe := Color(CHIP_STRIPES[index])
	base.a = alpha
	stripe.a = alpha
	draw_circle(pos + Vector2(0, 3), radius, Color(0, 0, 0, 0.4 * alpha))
	draw_circle(pos + Vector2(0, 1.5), radius, base.darkened(0.35))
	draw_circle(pos, radius, base)
	for k in 6:
		var a := k * TAU / 6.0 + 0.2
		_ring(pos, radius * 0.74, radius, a, a + 0.34, stripe, stripe, 2)
	draw_circle(pos, radius * 0.66, base.lightened(0.08))
	draw_arc(pos, radius * 0.66, 0, TAU, 32, Color(stripe, 0.8 * alpha), maxf(1.0, radius * 0.07), true)
	draw_arc(pos, radius, 0, TAU, 40, Color(0, 0, 0, 0.35 * alpha), 1.0, true)
	if label != "":
		var ink := Color("1c1c1e") if index == 0 or index == 5 else Color.WHITE
		ink.a = alpha
		var size := int(radius * (0.72 if label.length() <= 2 else (0.6 if label.length() == 3 else 0.5)))
		_text(label, pos, size, ink, bold)


func _chip_center(i: int) -> Vector2:
	return Vector2(TABLE.x + 40 + i * 80, CHIP_Y)


func _draw_chip_rack() -> void:
	for i in CHIPS.size():
		var p := _chip_center(i)
		var selected := i == chip
		var lift := -8.0 if selected else (-3.0 if i == hover_chip else 0.0)
		if selected:
			draw_circle(p + Vector2(0, lift), CHIP_R + 7 + sin(clock * 5.0), Color(GOLD_LIGHT, 0.25))
			draw_arc(p + Vector2(0, lift), CHIP_R + 4, 0, TAU, 48, GOLD, 2.5, true)
		var dim := 1.0 if CHIPS[i] <= balance or phase != "bet" else 0.45
		_draw_chip(p + Vector2(0, lift), CHIP_R, i, _short(CHIPS[i]), dim)


func _draw_buttons() -> void:
	for button: String in ["undo", "clear", "rebet", "double"]:
		var rect: Rect2 = BUTTONS[button]
		var enabled := _button_enabled(button)
		var hot := enabled and hover_button == button
		var fill := Color(0, 0, 0, 0.5) if not hot else Color(0.18, 0.12, 0.02, 0.8)
		_box(rect, fill, Color(GOLD, 0.8 if enabled else 0.25), 12, 1.5, 4)
		_text(tr(button), rect.get_center(), 16, Color(INK, 1.0 if enabled else 0.35), bold)

	# The big spin button, or a refill when the player is out of chips.
	var rect: Rect2 = BUTTONS.spin
	var refill := phase == "bet" and bets.is_empty() and balance < CHIPS[0]
	var enabled := _button_enabled("spin")
	var hot := enabled and hover_button == "spin"
	var glow := 0.0
	if enabled and (not bets.is_empty() or refill):
		glow = 0.5 + 0.5 * sin(clock * 4.0)
		_box(rect.grow(3 + glow * 3), Color(GOLD, 0.15 + 0.15 * glow), Color(0, 0, 0, 0), 26, 0.0)
	_box(rect, GOLD_DEEP, GOLD_LIGHT if hot else GOLD, 22, 2.0, 10)
	var inner := rect.grow(-5)
	_box(inner, Color("f2c14e") if enabled else Color("7b6a3c"), Color(0, 0, 0, 0), 18, 0.0)
	_box(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.5)), Color(1, 1, 1, 0.18 if hot else 0.12), Color(0, 0, 0, 0), 18, 0.0)
	var ink := Color("3a2203") if enabled else Color("3a2203", 0.5)
	if refill:
		_text(tr("refill"), rect.get_center(), 15, ink, bold)
		return
	# A circular arrow above the word.
	var icon := rect.get_center() + Vector2(0, -20)
	var turn := clock * 1.5 if enabled and not bets.is_empty() else 0.0
	if phase == "spin":
		turn = clock * 8.0
	draw_arc(icon, 17, turn + 0.3, turn + TAU - 0.9, 32, ink, 4.0, true)
	var tip := icon + Vector2.from_angle(turn + TAU - 0.9) * 17
	var along := Vector2.from_angle(turn + TAU - 0.9 + PI / 2.0)
	var out := Vector2.from_angle(turn + TAU - 0.9)
	draw_colored_polygon(PackedVector2Array([tip + along * 8, tip + out * 7, tip - out * 7]), ink)
	_text(tr("spin"), rect.get_center() + Vector2(0, 30), 28, ink, serif_bold)


func _draw_message() -> void:
	var text := tr(message)
	if message_arg != "":
		text = text % message_arg
	var pop := _back_out(clampf(message_t / 0.3, 0.0, 1.0))
	var color := INK
	if message == "you_win":
		color = Color("9dffbf")
	elif message in ["need_bet", "no_money", "table_max", "broke"]:
		color = Color("ffb4a8")
	elif message == "no_more_bets":
		color = GOLD_LIGHT
	var size := int(lerpf(18.0, 26.0, pop)) if message == "you_win" else int(lerpf(16.0, 22.0, pop))
	_text(text, Vector2(WHEEL_CENTER.x, 688), size, color, serif_bold, true)


func _draw_coins() -> void:
	for coin in coins:
		var squash := absf(cos(coin.phase + coin.t * coin.spin))
		var alpha := clampf(2.5 - coin.t, 0.0, 1.0)
		var p: Vector2 = coin.pos
		draw_set_transform(p, 0.0, Vector2(maxf(squash, 0.12), 1.0))
		draw_circle(Vector2.ZERO, 11, Color(GOLD_DEEP, alpha))
		draw_circle(Vector2(-1, -1), 9, Color(GOLD, alpha))
		draw_circle(Vector2(-3, -3), 3, Color(GOLD_LIGHT, alpha))
		draw_set_transform(Vector2.ZERO)


func _draw_menu() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.6))
	_box(MENU_RECT, Color("0b1f15"), GOLD, 18, 2.0, 18)
	var x := MENU_RECT.position.x + 30
	var right := MENU_RECT.end.x - 30
	var y := MENU_RECT.position.y
	_text_left(tr("settings"), Vector2(x, y + 38), 26, GOLD, serif_bold)
	var rows := _menu_rows()
	var close: Rect2 = rows.close
	var hot_close := close.has_point(mouse)
	draw_line(close.get_center() + Vector2(-9, -9), close.get_center() + Vector2(9, 9), GOLD_LIGHT if hot_close else INK, 2.5, true)
	draw_line(close.get_center() + Vector2(9, -9), close.get_center() + Vector2(-9, 9), GOLD_LIGHT if hot_close else INK, 2.5, true)

	for key in ["language", "sound"]:
		var rect: Rect2 = rows[key]
		_box(rect, Color(1, 1, 1, 0.08 if rect.has_point(mouse) else 0.04), Color(GOLD, 0.25), 10, 1.0)
		_text_left(tr(key), Vector2(rect.position.x + 16, rect.get_center().y), 17, INK, bold)
	var lang_rect: Rect2 = rows.language
	var lang_name := ""
	for entry in StringsScript.LANGUAGES:
		if entry[0] == language:
			lang_name = entry[1]
	_text_right("‹   " + lang_name + "   ›", Vector2(lang_rect.end.x - 16, lang_rect.get_center().y), 17, GOLD_LIGHT, bold)
	# Sound switch.
	var sw := Rect2(rows.sound.end.x - 70, rows.sound.get_center().y - 13, 54, 26)
	_box(sw, GREEN if sound_on else Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 13, 0.0)
	draw_circle(Vector2(sw.end.x - 13 if sound_on else sw.position.x + 13, sw.get_center().y), 10, Color.WHITE)

	_text_left(tr("statistics"), Vector2(x, y + 214), 20, GOLD, serif_bold)
	var lines := [
		["spins", _money(stats.spins)],
		["wins", _money(stats.wins)],
		["biggest_win", _money(stats.biggest)],
		["best_balance", _money(stats.best_balance)],
	]
	for i in lines.size():
		var ly := y + 250 + i * 28
		_text_left(tr(lines[i][0]), Vector2(x, ly), 16, MUTED, font)
		_text_right(lines[i][1], Vector2(right, ly), 16, INK, bold)
		if i < lines.size() - 1:
			draw_line(Vector2(x, ly + 14), Vector2(right, ly + 14), Color(1, 1, 1, 0.06), 1.0)

	var reset: Rect2 = rows.reset
	var hot := reset.has_point(mouse)
	_box(reset, Color("7a1a1a") if reset_armed else Color(1, 1, 1, 0.1 if hot else 0.05), Color(GOLD, 0.5), 10, 1.0)
	_text(tr("confirm_reset") if reset_armed else tr("reset"), reset.get_center(), 16, INK, bold)
	_text(tr("keys_help"), Vector2(MENU_RECT.get_center().x, y + 436), 12, MUTED, font)
	_text(tr("play_money"), Vector2(MENU_RECT.get_center().x, y + 458), 12, MUTED, font)
