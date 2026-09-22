extends Node2D
## Par ou Ímpar: the odds and evens hand game, against the computer or a friend.
## The main menu picks the play mode: against the CPU (the default) or two players taking turns on
## the same device. The first player picks EVEN or ODD (the other player has the other side) and
## shows 0 to 5 fingers; then the CPU, or the second player, shows theirs. The choices stay hidden
## until both hands shake three times to the chant and open together. The fingers are counted: if
## the sum is even, EVEN wins the round. The first to reach the match length wins the match.
## The "Random" CPU picks any number; the "Clever" CPU remembers which numbers you like to show.
## Keys: 0–5 show fingers, ← → / Tab switch side, Enter / Space new match, H main menu, Esc settings.

const SfxScript := preload("res://scripts/sfx.gd")
const StringsScript := preload("res://scripts/strings.gd")

const SCREEN := Vector2(1280, 720)
const SAVE_PATH := "user://par_ou_impar.cfg"
const MODES := ["cpu", "2p"]
const MATCH_LENGTHS := [3, 5, 7]
const HISTORY_SIZE := 14
const MEMORY := 16  # the clever CPU looks at this many of your last numbers

# Round timing, in seconds.
const BEAT := 0.46  # one shake of the hands
const COUNT_DELAY := 0.35  # from the hands opening to the first finger counted
const COUNT_STEP := 0.16
const VERDICT_PAUSE := 0.3
const OVERLAY_DELAY := 1.1  # the last round stays visible this long before the match result

# Hands. Drawn pointing up around the wrist, then turned to face each other.
const HAND_SCALE := 1.2
const PLAYER_HAND := Vector2(186, 292)
const CPU_HAND := Vector2(1094, 292)
const FINGER_X := [0.0, -36.0, -12.0, 12.0, 36.0]  # thumb, index, middle, ring, pinky
const FINGER_LEN := [0.0, 90.0, 100.0, 92.0, 72.0]
const FINGER_R := 12.5
const FINGER_BASE := -104.0
const KNUCKLE := -120.0  # where a folded finger's tip ends
const THUMB_BASE := Vector2(-44, -38)
const THUMB_FOLDED := Vector2(-2, -64)
const THUMB_OPEN := Vector2(-94, -94)
const THUMB_R := 14.0
## Which finger goes up for the 1st, 2nd... finger shown.
const RAISE_ORDER := [1, 2, 3, 4, 0]

# Game screen.
const PANEL := Rect2(40, 512, 1200, 188)
const SIDE_BUTTONS := [Rect2(70, 566, 160, 104), Rect2(244, 566, 160, 104)]
const FINGERS_X := 468.0
const FINGER_BUTTON := Vector2(112, 124)
const FINGER_GAP := 14.0
const FINGERS_Y := 556.0
const MENU_BUTTON := Rect2(1212, 11, 48, 44)
const HOME_BUTTON := Rect2(1156, 11, 48, 44)
const MENU_RECT := Rect2(390, 60, 500, 604)
const OVERLAY := Rect2(430, 150, 420, 250)
const OVERLAY_BUTTONS := {"new_match": Rect2(450, 318, 184, 56), "home": Rect2(646, 318, 184, 56)}

# Main menu.
const TITLE_HANDS := [Vector2(150, 330), Vector2(1130, 330)]
const MODE_CARDS := [Rect2(432, 282, 202, 176), Rect2(646, 282, 202, 176)]
const PLAY_BUTTON := Rect2(530, 490, 220, 64)
const TITLE_NEW_MATCH := Rect2(540, 566, 200, 34)

# Colors.
const INK := Color("f7f3ff")
const MUTED := Color(0.97, 0.95, 1, 0.6)
const GOLD := Color("ffd166")
const PLAYER := Color("4da3ff")
const CPU := Color("ff6b6b")
const PLAYER_SKIN := Color("f2c29b")
const CPU_SKIN := Color("b97a56")
const PLAYER_SLEEVE := Color("2f6fd0")
const CPU_SLEEVE := Color("d9464a")
const PANEL_FILL := Color(1, 1, 1, 0.05)
const PANEL_LINE := Color(1, 1, 1, 0.12)

# Match. Index 0 is you (or player 1), index 1 the CPU (or player 2).
var mode := "cpu"  # mode of the match being played
var player_side := 0  # 0 even, 1 odd; the other player has the other one
var score := [0, 0]
var match_length := 5
var history := []  # newest first: {"p": fingers, "c": fingers, "won": bool}
var memory := []  # your last numbers against the CPU, newest first

# Round.
var phase := "title"  # "title", "choose", "second" (player 2 to pick), "shake", "count", "result" or "over"
var player_fingers := 0
var cpu_fingers := 0
var round_t := 0.0
var count_t := 0.0
var counted := 0
var over_t := 0.0
var round_won := false
var streak := 0

# Hands: how far each finger is raised, 0 folded to 1 up.
var player_ext := [0.0, 0.0, 0.0, 0.0, 0.0]
var cpu_ext := [0.0, 0.0, 0.0, 0.0, 0.0]
var bob := 0.0

# Settings and statistics (statistics count games against the CPU only).
var language := ""
var sound_on := true
var clever := true
var stats := {"rounds": 0, "rounds_won": 0, "matches_won": 0, "matches_lost": 0, "best_streak": 0}

# Interface.
var title_mode := "cpu"  # mode picked in the main menu
var mouse := Vector2.ZERO
var hover := ""
var message := "pick"
var message_args := []
var message_t := 0.0
var menu_open := false
var reset_armed := false
var clock := 0.0
var confetti := []

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
	_add_background()
	_load()
	if language == "":
		language = StringsScript.system_language()
	_apply_settings()


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


## Deep violet background with a soft light in the middle and faint dots, drawn by a shader.
func _add_background() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 size = vec2(1280.0, 720.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 p = UV * size;
	float d = length((UV - vec2(0.5, 0.42)) * vec2(1.3, 1.0));
	vec3 col = mix(vec3(0.2, 0.15, 0.38), vec3(0.06, 0.045, 0.14), smoothstep(0.0, 0.8, d));
	col += (hash(floor(p)) - 0.5) * 0.02;
	vec2 cell = p / 34.0;
	vec2 q = fract(cell + vec2(0.5 * mod(floor(cell.y), 2.0), 0.0)) - 0.5;
	col += smoothstep(0.11, 0.07, length(q)) * 0.025;
	COLOR = vec4(col, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var rect := ColorRect.new()
	rect.size = SCREEN
	rect.material = material
	rect.show_behind_parent = true
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func _apply_settings() -> void:
	TranslationServer.set_locale(language)
	AudioServer.set_bus_mute(0, not sound_on)


# --- Game ------------------------------------------------------------------------------------

func _side_key(side: int) -> String:
	return "even" if side == 0 else "odd"


## Name of a player as the game shows it: "You" / "CPU", or "Player 1" / "Player 2".
func _name(who: int) -> String:
	if mode == "2p":
		return tr("player_1") if who == 0 else tr("player_2")
	return tr("you") if who == 0 else tr("cpu")


func _can_throw() -> bool:
	return phase == "choose" or phase == "second" or phase == "result"


## A match is in progress when it has started and nobody has won it yet.
func _match_in_progress() -> bool:
	return score != [0, 0] and phase != "over"


func _throw(fingers: int) -> void:
	if not _can_throw() or menu_open:
		return
	if mode == "2p":
		if phase != "second":
			# Player 1 picks first; the choice stays hidden while player 2 picks.
			player_fingers = fingers
			phase = "second"
			sfx.play("click")
			_say("second_turn", [tr("player_2"), tr("player_1")])
			return
		cpu_fingers = fingers
	else:
		player_fingers = fingers
		cpu_fingers = _cpu_pick()
		memory.push_front(fingers)
		if memory.size() > MEMORY:
			memory.resize(MEMORY)
	phase = "shake"
	round_t = 0.0
	counted = 0
	sfx.play("whoosh")
	_say("")


func _set_side(side: int) -> void:
	if (phase != "choose" and phase != "result") or side == player_side:
		return
	player_side = side
	sfx.play("switch")
	_save()


## The random CPU picks any number. The clever one guesses whether you will show an even or an odd
## number from your recent choices (newer ones count more) and picks a number that makes its own
## side win against that guess. It still plays at random a third of the time, so it can't be read.
func _cpu_pick() -> int:
	if not clever or memory.size() < 3 or randf() < 0.34:
		return randi() % 6
	var weights := [0.0, 0.0]
	var w := 1.0
	for n: int in memory:
		weights[n % 2] += w
		w *= 0.82
	var guess := 0 if weights[0] >= weights[1] else 1
	# When the guess is weak, fall back to chance.
	var confidence: float = absf(weights[0] - weights[1]) / (weights[0] + weights[1])
	if randf() > 0.55 + confidence:
		return randi() % 6
	var cpu_side := 1 - player_side
	var parity := (cpu_side - guess + 2) % 2
	return parity + 2 * (randi() % 3)


func _sum() -> int:
	return player_fingers + cpu_fingers


func _verdict() -> void:
	round_won = _sum() % 2 == player_side
	var winner := 0 if round_won else 1
	var vs_cpu := mode == "cpu"
	# Against a friend every round has a winner to cheer for.
	var cheer := round_won or not vs_cpu
	score[winner] += 1
	history.push_front({"p": player_fingers, "c": cpu_fingers, "won": round_won})
	if history.size() > HISTORY_SIZE:
		history.resize(HISTORY_SIZE)
	if vs_cpu:
		stats.rounds += 1
		if round_won:
			stats.rounds_won += 1
			streak += 1
			stats.best_streak = maxi(stats.best_streak, streak)
		else:
			streak = 0
	if score[winner] >= match_length:
		phase = "over"
		over_t = 0.0
		if vs_cpu:
			stats["matches_won" if round_won else "matches_lost"] += 1
		sfx.play("match_win" if cheer else "match_lose")
		if cheer:
			_burst(90)
		if vs_cpu:
			_say("you_win_match" if round_won else "cpu_wins_match")
		else:
			_say("wins_match", [_name(winner)])
	else:
		phase = "result"
		sfx.play("win" if cheer else "lose")
		if cheer:
			_burst(24)
		if vs_cpu:
			_say("you_win_round" if round_won else "cpu_wins_round")
		else:
			_say("wins_round", [_name(winner)])
	_save()


func _reset_match() -> void:
	score = [0, 0]
	history.clear()
	for i in 5:
		player_ext[i] = 0.0
		cpu_ext[i] = 0.0


## Starts playing: goes on with the saved match of the mode picked in the main menu, or a new one.
func _start(fresh: bool) -> void:
	if fresh or mode != title_mode or not _match_in_progress():
		mode = title_mode
		_reset_match()
		phase = "choose"
	elif history.is_empty():
		phase = "choose"
	else:
		# Back to the last round, hands open.
		player_fingers = history[0].p
		cpu_fingers = history[0].c
		round_won = history[0].won
		counted = _sum()
		phase = "result"
		for i in 5:
			player_ext[i] = _target_ext(player_fingers, i)
			cpu_ext[i] = _target_ext(cpu_fingers, i)
	_say_pick()
	sfx.play("click")
	_save()


func _new_match() -> void:
	_reset_match()
	phase = "choose"
	sfx.play("click")
	_say_pick()
	_save()


func _say_pick() -> void:
	if mode == "2p":
		_say("pick_2p", [tr("player_1")])
	else:
		_say("pick")


func _go_home() -> void:
	if phase == "shake" or phase == "count":
		return
	if phase == "second":
		phase = "choose"  # player 1 picks again when the game goes on
	# The main menu offers to go on with this match; with none, it starts again on the default mode.
	title_mode = mode if _match_in_progress() else "cpu"
	phase = "title"
	confetti.clear()
	sfx.play("click")
	_save()


func _say(key: String, args := []) -> void:
	message = key
	message_args = args
	message_t = 0.0


func _burst(count: int) -> void:
	var colors := [GOLD, PLAYER, INK, Color("7ee0a1"), Color("c69cff")]
	for i in count:
		var angle := randf_range(-PI * 0.95, -PI * 0.05)
		confetti.append({
			"pos": Vector2(640 + randf_range(-40, 40), 300),
			"vel": Vector2.from_angle(angle) * randf_range(260, 620),
			"spin": randf_range(-9, 9),
			"rot": randf() * TAU,
			"color": colors[i % colors.size()],
			"t": 0.0,
		})


func _target_ext(fingers: int, i: int) -> float:
	if phase != "count" and phase != "result" and phase != "over":
		return 0.0
	return 1.0 if RAISE_ORDER.find(i) < fingers else 0.0


func _process(delta: float) -> void:
	clock += delta
	message_t += delta
	match phase:
		"shake":
			var before := int(round_t / BEAT)
			round_t += delta
			var beat := int(round_t / BEAT)
			if beat != before and beat < 3:
				sfx.play("whoosh", 1.0 + beat * 0.08)
			bob = sin(fmod(round_t, BEAT) / BEAT * PI) * 34.0
			if round_t >= BEAT * 3.0:
				phase = "count"
				count_t = 0.0
				bob = 0.0
				sfx.play("pop")
		"count":
			count_t += delta
			var should := clampi(int((count_t - COUNT_DELAY) / COUNT_STEP) + 1, 0, _sum()) if count_t >= COUNT_DELAY else 0
			while counted < should:
				counted += 1
				sfx.play("tick", 0.9 + counted * 0.07)
			if count_t >= COUNT_DELAY + _sum() * COUNT_STEP + VERDICT_PAUSE:
				_verdict()
		"over":
			over_t += delta
	if phase != "shake":
		bob = lerpf(bob, 0.0, 1.0 - exp(-delta * 12.0))

	var speed := 1.0 - exp(-delta * (22.0 if phase == "count" else 16.0))
	for i in 5:
		player_ext[i] = lerpf(player_ext[i], _target_ext(player_fingers, i), speed)
		cpu_ext[i] = lerpf(cpu_ext[i], _target_ext(cpu_fingers, i), speed)

	for piece in confetti:
		piece.t += delta
		piece.vel.y += 700.0 * delta
		piece.vel.x *= 1.0 - delta * 0.8
		piece.pos += piece.vel * delta
		piece.rot += piece.spin * delta
	confetti = confetti.filter(func(p): return p.t < 3.0 and p.pos.y < SCREEN.y + 20)
	queue_redraw()


# --- Input -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		_update_hover()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse = event.position
		_update_hover()
		_click()
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)


func _key(code: int) -> void:
	if code == KEY_ESCAPE:
		_toggle_menu()
		return
	if menu_open:
		return
	if phase == "title":
		match code:
			KEY_LEFT, KEY_RIGHT, KEY_TAB:
				title_mode = MODES[1 - MODES.find(title_mode)]
				sfx.play("switch")
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_start(false)
		return
	if code >= KEY_0 and code <= KEY_5:
		_throw(code - KEY_0)
	elif code >= KEY_KP_0 and code <= KEY_KP_5:
		_throw(code - KEY_KP_0)
	match code:
		KEY_LEFT:
			_set_side(0)
		KEY_RIGHT:
			_set_side(1)
		KEY_TAB:
			_set_side(1 - player_side)
		KEY_H:
			_go_home()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if phase == "over" and over_t >= OVERLAY_DELAY:
				_new_match()


func _finger_button(i: int) -> Rect2:
	return Rect2(Vector2(FINGERS_X + i * (FINGER_BUTTON.x + FINGER_GAP), FINGERS_Y), FINGER_BUTTON)


func _update_hover() -> void:
	hover = ""
	if menu_open:
		return
	if MENU_BUTTON.has_point(mouse):
		hover = "menu"
	elif phase == "title":
		for i in 2:
			if MODE_CARDS[i].has_point(mouse):
				hover = "mode%d" % i
		if PLAY_BUTTON.has_point(mouse):
			hover = "play"
		elif TITLE_NEW_MATCH.has_point(mouse) and _can_continue():
			hover = "title_new_match"
	elif HOME_BUTTON.has_point(mouse):
		hover = "home"
	elif phase == "over":
		if over_t >= OVERLAY_DELAY:
			for key: String in OVERLAY_BUTTONS:
				if OVERLAY_BUTTONS[key].has_point(mouse):
					hover = "over_" + key
	else:
		for i in 2:
			if SIDE_BUTTONS[i].has_point(mouse):
				hover = "side%d" % i
		for i in 6:
			if _finger_button(i).has_point(mouse):
				hover = "fingers%d" % i


func _click() -> void:
	if menu_open:
		_menu_click()
		return
	match hover:
		"menu":
			_toggle_menu()
		"home", "over_home":
			_go_home()
		"over_new_match":
			_new_match()
		"play":
			_start(false)
		"title_new_match":
			_start(true)
		_:
			if hover.begins_with("mode"):
				var picked: String = MODES[int(hover.substr(4))]
				if picked != title_mode:
					title_mode = picked
					sfx.play("switch")
			elif hover.begins_with("side"):
				_set_side(int(hover.substr(4)))
			elif hover.begins_with("fingers"):
				_throw(int(hover.substr(7)))


## The main menu offers to go on when the picked mode has a match in progress.
func _can_continue() -> bool:
	return title_mode == mode and _match_in_progress()


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
		"language": Rect2(x, y + 72, w, 44),
		"sound": Rect2(x, y + 122, w, 44),
		"difficulty": Rect2(x, y + 172, w, 44),
		"match_length": Rect2(x, y + 244, w, 44),
		"reset": Rect2(x, y + 494, w, 42),
		"close": Rect2(MENU_RECT.end.x - 52, y + 12, 40, 40),
	}


func _menu_click() -> void:
	if not MENU_RECT.has_point(mouse):
		_toggle_menu()
		return
	var rows := _menu_rows()
	var was_armed := reset_armed
	reset_armed = false
	if rows.language.has_point(mouse):
		var codes := StringsScript.LANGUAGES.map(func(l): return l[0])
		var step := -1 if mouse.x < rows.language.get_center().x - 60 else 1
		language = codes[(codes.find(language) + step + codes.size()) % codes.size()]
		_apply_settings()
	elif rows.sound.has_point(mouse):
		sound_on = not sound_on
		_apply_settings()
	elif rows.difficulty.has_point(mouse):
		clever = not clever
	elif rows.match_length.has_point(mouse):
		match_length = MATCH_LENGTHS[(MATCH_LENGTHS.find(match_length) + 1) % MATCH_LENGTHS.size()]
		# A new length starts a new match, unless nothing has been played yet or a round is on.
		if phase != "shake" and phase != "count" and (score != [0, 0] or phase == "over"):
			_reset_match()
			if phase != "title":
				phase = "choose"
				_say_pick()
	elif rows.reset.has_point(mouse):
		if not was_armed:
			reset_armed = true
			sfx.play("click")
			return
		stats = {"rounds": 0, "rounds_won": 0, "matches_won": 0, "matches_lost": 0, "best_streak": 0}
		streak = 0
	elif rows.close.has_point(mouse):
		_toggle_menu()
		return
	else:
		return
	sfx.play("click")
	_save()


# --- Saving ----------------------------------------------------------------------------------

func _save() -> void:
	var config := ConfigFile.new()
	# A round still being shown counts as not played.
	var in_round := phase == "shake" or phase == "count"
	config.set_value("game", "mode", mode)
	config.set_value("game", "score", score)
	config.set_value("game", "history", history)
	config.set_value("game", "memory", memory.slice(1) if in_round and mode == "cpu" else memory)
	config.set_value("game", "side", player_side)
	config.set_value("game", "streak", streak)
	config.set_value("game", "stats", stats)
	config.set_value("settings", "language", language)
	config.set_value("settings", "sound", sound_on)
	config.set_value("settings", "clever", clever)
	config.set_value("settings", "match_length", match_length)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	match_length = int(config.get_value("settings", "match_length", 5))
	if not MATCH_LENGTHS.has(match_length):
		match_length = 5
	mode = config.get_value("game", "mode", "cpu")
	if not MODES.has(mode):
		mode = "cpu"
	var saved_score: Array = config.get_value("game", "score", [0, 0])
	if saved_score.size() == 2 and saved_score.max() < match_length:
		score = [int(saved_score[0]), int(saved_score[1])]
		history = config.get_value("game", "history", [])
	memory = config.get_value("game", "memory", [])
	player_side = clampi(int(config.get_value("game", "side", 0)), 0, 1)
	streak = int(config.get_value("game", "streak", 0))
	var saved: Dictionary = config.get_value("game", "stats", {})
	for key in stats:
		stats[key] = int(saved.get(key, stats[key]))
	language = config.get_value("settings", "language", "")
	sound_on = config.get_value("settings", "sound", true)
	clever = config.get_value("settings", "clever", true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


# --- Drawing helpers -------------------------------------------------------------------------

## Draws text centered on `center` (both ways).
func _text(text: String, center: Vector2, size: int, color: Color, f: Font = null, shadow := false) -> void:
	if f == null:
		f = bold
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2(center.x - width / 2.0, center.y + (f.get_ascent(size) - f.get_descent(size)) / 2.0)
	if shadow:
		draw_string(f, base + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.45 * color.a))
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


func _text_width(text: String, size: int, f: Font) -> float:
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## The largest size up to `size` at which `text` fits in `width`.
func _fit(text: String, size: int, width: float, f: Font) -> int:
	while size > 10 and _text_width(text, size, f) > width:
		size -= 1
	return size


func _box(rect: Rect2, fill: Color, border: Color, radius: float, width := 1.5, shadow := 0.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(int(width) if width >= 1.0 else 0)
	style.set_corner_radius_all(int(radius))
	style.anti_aliasing = true
	if shadow > 0.0:
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = int(shadow)
		style.shadow_offset = Vector2(0, shadow * 0.4)
	draw_style_box(style, rect)


## A stadium shape from `a` to `b`: a line of width 2r with round ends.
func _capsule(a: Vector2, b: Vector2, r: float, color: Color) -> void:
	draw_circle(a, r, color)
	draw_circle(b, r, color)
	if a.distance_to(b) > 0.01:
		var n := (b - a).normalized().orthogonal() * r
		draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), color)


## A button with a centered label, lit when hovered.
func _button(rect: Rect2, label: String, color: Color, hot: bool, size := 20) -> void:
	_box(rect, Color(color, 0.55 if hot else 0.35), color, 14, 2.0)
	_text(label, rect.get_center(), _fit(label, size, rect.size.x - 20, bold), INK, bold)


# --- Hands -----------------------------------------------------------------------------------

func _finger_tip(i: int, e: float) -> Vector2:
	if i == 0:
		return THUMB_FOLDED.lerp(THUMB_OPEN, e)
	# Raised fingers fan out a little.
	return Vector2(FINGER_X[i] * (1.0 + 0.45 * e), lerpf(KNUCKLE, FINGER_BASE - FINGER_LEN[i], e))


func _finger_root(i: int) -> Vector2:
	return THUMB_BASE if i == 0 else Vector2(FINGER_X[i], FINGER_BASE)


## How far each finger is raised for a hand showing `fingers`.
func _ext_for(fingers: int) -> Array:
	var ext := []
	for i in 5:
		ext.append(1.0 if RAISE_ORDER.find(i) < fingers else 0.0)
	return ext


## Screen transform of a hand: drawn pointing up at the origin, then turned so the fingers point
## `dir` (+1 right, -1 left, 0 up). Hands pointing left are mirrored so both thumbs are on top.
func _hand_transform(origin: Vector2, dir: int, s: float) -> Transform2D:
	if dir == 0:
		return Transform2D(0.0, Vector2(s, s), 0.0, origin)
	if dir > 0:
		return Transform2D(PI / 2.0, Vector2(s, s), 0.0, origin)
	return Transform2D(-PI / 2.0, Vector2(-s, s), 0.0, origin)


func _draw_hand(xform: Transform2D, ext: Array, skin: Color, sleeve: Color, sleeve_len: float, glow := 0) -> void:
	draw_set_transform_matrix(xform)
	var line := skin.darkened(0.5)
	var shade := skin.darkened(0.12)
	# Sleeve and cuff.
	_box(Rect2(-56, 4, 112, sleeve_len), sleeve, sleeve.darkened(0.35), 12, 3.0)
	_box(Rect2(-60, -6, 120, 26), sleeve.lightened(0.25), sleeve.darkened(0.3), 10, 3.0)
	# Palm outline, then each finger with its own outline so raised fingers stay apart, then the
	# palm over the finger roots.
	var palm := Rect2(-58, -116, 116, 112)
	_box(palm.grow(3), line, line, 36, 0.0)
	for i in range(4, 0, -1):
		_capsule(_finger_root(i), _finger_tip(i, ext[i]), FINGER_R + 3.0, line)
		_capsule(_finger_root(i), _finger_tip(i, ext[i]), FINGER_R, skin)
	_box(palm, skin, skin, 34, 0.0)
	_box(Rect2(-50, -40, 100, 34), shade, shade, 16, 0.0)
	for i in range(1, 5):
		var tip := _finger_tip(i, ext[i])
		if ext[i] < 0.5:
			# A folded finger: a knuckle bump with a crease under it.
			var x: float = FINGER_X[i]
			draw_line(Vector2(x - 8, FINGER_BASE + 4), Vector2(x + 8, FINGER_BASE + 4), Color(line, 0.45 * (1.0 - ext[i] * 2.0)), 2.0, true)
		else:
			# Nail on a raised finger.
			var a: float = (ext[i] - 0.5) * 2.0
			_box(Rect2(tip.x - 7, tip.y - 6, 14, 17), Color(skin.lightened(0.35), a), Color(line, 0.35 * a), 6, 1.0)
	# Thumb, over the palm when folded.
	_capsule(THUMB_BASE, _finger_tip(0, ext[0]), THUMB_R + 3.0, line)
	_capsule(THUMB_BASE, _finger_tip(0, ext[0]), THUMB_R, skin)
	if ext[0] > 0.5:
		var tip := _finger_tip(0, ext[0])
		var a: float = (ext[0] - 0.5) * 2.0
		var d := (THUMB_OPEN - THUMB_BASE).normalized()
		var n := tip - d * 4.0
		draw_set_transform_matrix(xform * Transform2D(d.angle() + PI / 2.0, n))
		_box(Rect2(-7.5, -8, 15, 18), Color(skin.lightened(0.35), a), Color(line, 0.35 * a), 6, 1.0)
		draw_set_transform_matrix(xform)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Counted fingers light up.
	var order := RAISE_ORDER.slice(0, glow)
	for k in order.size():
		var i: int = order[k]
		var tip := xform * _finger_tip(i, ext[i])
		draw_circle(tip, 17, Color(GOLD, 0.25))
		draw_arc(tip, 17, 0, TAU, 32, GOLD, 2.5, true)


# --- Drawing ---------------------------------------------------------------------------------

func _draw() -> void:
	if phase == "title":
		_draw_title()
	else:
		_draw_header()
		_draw_history()
		_draw_hands()
		_draw_center()
		_draw_panel()
		_draw_confetti()
		if phase == "over" and over_t >= OVERLAY_DELAY:
			_draw_match_over()
	_draw_menu_button()
	if menu_open:
		_draw_menu()


func _draw_title() -> void:
	# Two hands, one showing 2 and the other 3, around the title.
	var breathe := sin(clock * 2.1) * 3.0
	_draw_hand(_hand_transform(TITLE_HANDS[0] + Vector2(0, breathe), 1, HAND_SCALE), _ext_for(2), PLAYER_SKIN, PLAYER_SLEEVE, 240)
	_draw_hand(_hand_transform(TITLE_HANDS[1] + Vector2(0, -breathe), -1, HAND_SCALE), _ext_for(3), CPU_SKIN, CPU_SLEEVE, 240)
	var title := tr("title")
	_text(title, Vector2(640, 128), _fit(title, 76, 1160, serif_bold), INK, serif_bold, true)
	var chant := "%s %s %s" % [tr("chant_1"), tr("chant_2"), tr("chant_3")]
	_text(chant, Vector2(640, 196), 24, GOLD, serif_bold)

	for i in 2:
		var rect: Rect2 = MODE_CARDS[i]
		var on: bool = title_mode == MODES[i]
		var hot := hover == "mode%d" % i
		_box(rect, Color(PLAYER, 0.26) if on else Color(1, 1, 1, 0.1 if hot else 0.05), PLAYER if on else Color(1, 1, 1, 0.18),
				16, 2.5 if on else 1.0)
		var c := rect.get_center()
		# Icon: your hand next to a screen, or two hands.
		_draw_hand(_hand_transform(c + Vector2(-26, -8), 0, 0.3), _ext_for(2), PLAYER_SKIN, PLAYER_SLEEVE, 16)
		if i == 0:
			var screen := Rect2(c.x + 4, c.y - 62, 50, 36)
			_box(screen, Color("2a2350"), CPU, 6, 2.5)
			draw_circle(screen.get_center() + Vector2(-9, -3), 3.5, CPU)
			draw_circle(screen.get_center() + Vector2(9, -3), 3.5, CPU)
			draw_line(screen.get_center() + Vector2(-8, 8), screen.get_center() + Vector2(8, 8), CPU, 2.5, true)
			draw_rect(Rect2(c.x + 25, screen.end.y, 8, 8), CPU)
			draw_rect(Rect2(c.x + 16, screen.end.y + 7, 26, 4), CPU)
		else:
			_draw_hand(_hand_transform(c + Vector2(26, -8), 0, 0.3), _ext_for(3), CPU_SKIN, CPU_SLEEVE, 16)
		var label := tr("vs_cpu") if i == 0 else tr("two_players")
		var hint := tr("vs_cpu_hint") if i == 0 else tr("two_players_hint")
		_text(label, Vector2(c.x, rect.end.y - 52), _fit(label, 22, rect.size.x - 16, bold), INK if on else MUTED, bold)
		_text(hint, Vector2(c.x, rect.end.y - 24), _fit(hint, 13, rect.size.x - 16, font), MUTED, font)

	var cont := _can_continue()
	_button(PLAY_BUTTON, tr("continue") if cont else tr("play"), PLAYER, hover == "play", 24)
	if cont:
		var hot := hover == "title_new_match"
		var label := tr("new_match")
		_text(label, TITLE_NEW_MATCH.get_center(), 16, INK if hot else MUTED, bold)
		var w := _text_width(label, 16, bold)
		var y := TITLE_NEW_MATCH.get_center().y + 12
		draw_line(Vector2(640 - w / 2.0, y), Vector2(640 + w / 2.0, y), Color(INK if hot else MUTED, 0.6), 1.0)
		_text("%s %d : %d %s" % [_name(0), score[0], score[1], _name(1)], Vector2(640, 626), 14, MUTED, font)


func _draw_menu_button() -> void:
	var hot := hover == "menu"
	_box(MENU_BUTTON, Color(1, 1, 1, 0.12 if hot else 0.05), Color(1, 1, 1, 0.2), 10, 1.0)
	for i in 3:
		var y := MENU_BUTTON.get_center().y - 9 + i * 9
		draw_line(Vector2(MENU_BUTTON.position.x + 14, y), Vector2(MENU_BUTTON.end.x - 14, y), INK if hot else MUTED, 2.5, true)


func _draw_header() -> void:
	draw_rect(Rect2(0, 0, SCREEN.x, 66), Color(0, 0, 0, 0.28))
	draw_line(Vector2(0, 66), Vector2(SCREEN.x, 66), Color(1, 1, 1, 0.1), 1.0)
	# Emblem: two fingertips, one of each color.
	_capsule(Vector2(34, 42), Vector2(34, 22), 7, PLAYER)
	_capsule(Vector2(52, 44), Vector2(52, 18), 7, CPU)
	var title := tr("title")
	_text_left(title, Vector2(72, 33), _fit(title, 26, 290, serif_bold), INK, serif_bold)

	# Score, with one dot per point needed.
	var c := Vector2(640, 28)
	_text(str(score[0]), Vector2(c.x - 28, c.y), 30, INK, bold)
	_text(":", Vector2(c.x, c.y - 2), 26, MUTED, bold)
	_text(str(score[1]), Vector2(c.x + 28, c.y), 30, INK, bold)
	for i in match_length:
		draw_circle(Vector2(c.x - 64 - i * 14, c.y), 5, PLAYER if i < score[0] else Color(1, 1, 1, 0.14))
		draw_circle(Vector2(c.x + 64 + i * 14, c.y), 5, CPU if i < score[1] else Color(1, 1, 1, 0.14))
	var gap := 64.0 + match_length * 14.0
	_text_right(_name(0).to_upper(), Vector2(c.x - gap, c.y), 16, PLAYER, bold)
	_text_left(_name(1).to_upper(), Vector2(c.x + gap, c.y), 16, CPU, bold)
	_text(tr("first_to") % match_length, Vector2(c.x, 54), 12, MUTED, font)

	# Main menu button: a little house.
	var hot := hover == "home"
	var busy := phase == "shake" or phase == "count"
	_box(HOME_BUTTON, Color(1, 1, 1, 0.12 if hot and not busy else 0.05), Color(1, 1, 1, 0.2), 10, 1.0)
	var h := HOME_BUTTON.get_center()
	var col := INK if hot and not busy else Color(MUTED, 0.3 if busy else 0.6)
	draw_polyline(PackedVector2Array([h + Vector2(-12, -1), h + Vector2(0, -12), h + Vector2(12, -1)]), col, 2.5, true)
	draw_polyline(PackedVector2Array([h + Vector2(-8, -4), h + Vector2(-8, 11), h + Vector2(8, 11), h + Vector2(8, -4)]), col, 2.5, true)
	draw_rect(Rect2(h + Vector2(-2.5, 3), Vector2(5, 8)), col)


## Sums of the last rounds, colored by who won them.
func _draw_history() -> void:
	if history.is_empty():
		return
	var n := history.size()
	var step := 32.0
	var x0 := 640.0 - (n - 1) * step / 2.0
	for i in n:
		var h: Dictionary = history[n - 1 - i]
		var pos := Vector2(x0 + i * step, 96)
		var col := PLAYER if h.won else CPU
		var newest := i == n - 1
		draw_circle(pos, 13, Color(col, 0.9 if newest else 0.5))
		if newest:
			draw_arc(pos, 16, 0, TAU, 32, Color(col, 0.6), 1.5, true)
		_text(str(h.p + h.c), pos, 14, INK, bold)


func _draw_hands() -> void:
	var idle := phase == "choose" or phase == "second" or phase == "result"
	var breathe := sin(clock * 2.1) * 2.0 if idle else 0.0
	var shown := phase == "count" or phase == "result" or phase == "over"
	var glow_p := mini(counted, player_fingers) if shown else 0
	var glow_c := clampi(counted - player_fingers, 0, cpu_fingers) if shown else 0
	var decided := phase == "result" or phase == "over"
	_draw_hand(_hand_transform(PLAYER_HAND + Vector2(0, breathe - bob), 1, HAND_SCALE), player_ext, PLAYER_SKIN, PLAYER_SLEEVE, 240, glow_p)
	_draw_hand(_hand_transform(CPU_HAND + Vector2(0, -breathe - bob), -1, HAND_SCALE), cpu_ext, CPU_SKIN, CPU_SLEEVE, 240, glow_c)

	# Name and side under each hand; a check mark once a player has picked.
	for who in 2:
		var x := 200.0 if who == 0 else 1080.0
		var col := PLAYER if who == 0 else CPU
		var side := player_side if who == 0 else 1 - player_side
		var winner := decided and (round_won == (who == 0))
		var name := _name(who).to_upper()
		_text(name, Vector2(x, 420), 18, col, bold)
		if phase == "second" and who == 0:
			var w := _text_width(name, 18, bold)
			var m := Vector2(x + w / 2.0 + 16, 420)
			draw_polyline(PackedVector2Array([m + Vector2(-6, 0), m + Vector2(-1, 5), m + Vector2(7, -6)]), col, 3.0, true)
		var label := tr(_side_key(side))
		var w := _text_width(label, 17, bold) + 34
		var pill := Rect2(x - w / 2.0, 440, w, 32)
		_box(pill, Color(col, 0.28 if winner else 0.12), Color(col, 0.9 if winner else 0.4), 16, 2.0 if winner else 1.0)
		_text(label, pill.get_center(), 17, INK, bold)


func _draw_center() -> void:
	var c := Vector2(640, 272)
	match phase:
		"choose", "second":
			_text("?", c, 110, Color(1, 1, 1, 0.12), serif_bold)
		"shake":
			var beat := mini(int(round_t / BEAT), 2)
			var local := fmod(round_t, BEAT) / BEAT if round_t < BEAT * 3.0 else 1.0
			var pop := 1.0 + (1.0 - clampf(local * 3.0, 0.0, 1.0)) * 0.25
			_text(tr("chant_%d" % (beat + 1)), c, int(54 * pop), GOLD, serif_bold, true)
		"count", "result", "over":
			var done := phase != "count"
			var number := _sum() if done else counted
			var col := INK
			if done:
				col = PLAYER if round_won else CPU
			_text(str(number), c + Vector2(0, -6), 118, col, serif_bold, true)
			_text("%d + %d" % [player_fingers, cpu_fingers], c + Vector2(0, -92), 22, MUTED, bold)
			if done:
				_text(tr(_side_key(_sum() % 2)), c + Vector2(0, 78), 34, col, bold, true)

	# Message line, in the color of the player it is about.
	if message != "":
		var a := clampf(message_t * 5.0, 0.0, 1.0)
		var col := INK
		if phase == "result" or phase == "over":
			col = (PLAYER if round_won else CPU).lightened(0.3)
		elif phase == "second":
			col = CPU.lightened(0.3)
		var text := tr(message) % message_args if not message_args.is_empty() else tr(message)
		_text(text, Vector2(640, 482), _fit(text, 20, 620, bold), Color(col, a), bold)


func _draw_panel() -> void:
	_box(PANEL, PANEL_FILL, PANEL_LINE, 18, 1.0)
	var active := _can_throw() and not menu_open
	var second := phase == "second"
	var sides_active := (phase == "choose" or phase == "result") and not menu_open
	var call := tr("your_call") if mode == "cpu" else tr("player_1")
	_text_left(call, Vector2(SIDE_BUTTONS[0].position.x, 538), 15, MUTED, bold)
	var turn := tr("show_fingers")
	var turn_col := MUTED
	if mode == "2p" and active:
		turn = tr("turn_fingers") % _name(1 if second else 0)
		turn_col = (CPU if second else PLAYER).lightened(0.25)
	_text_left(turn, Vector2(FINGERS_X, 538), 15, turn_col, bold)
	draw_line(Vector2(436, 530), Vector2(436, 684), PANEL_LINE, 1.0)

	for i in 2:
		var rect: Rect2 = SIDE_BUTTONS[i]
		var on := player_side == i
		var hot := hover == "side%d" % i and sides_active
		var fill := Color(PLAYER, 0.32) if on else Color(1, 1, 1, 0.1 if hot else 0.04)
		_box(rect, fill, PLAYER if on else Color(1, 1, 1, 0.18), 14, 2.0 if on else 1.0)
		var label := tr(_side_key(i))
		_text(label, rect.get_center() + Vector2(0, -14), _fit(label, 22, rect.size.x - 20, bold), INK if on else MUTED, bold)
		# Example dots: two for even, three for odd.
		var dots := 2 + i
		for k in dots:
			var dx := (k - (dots - 1) / 2.0) * 16.0
			draw_circle(rect.get_center() + Vector2(dx, 24), 5, Color(INK if on else MUTED, 0.9 if on else 0.5))
		if not sides_active and not on:
			_box(rect, Color(0.08, 0.06, 0.17, 0.5), Color(0, 0, 0, 0), 14, 0.0)

	# The finger buttons use the hand of whoever picks now.
	var skin := CPU_SKIN if second else PLAYER_SKIN
	var sleeve := CPU_SLEEVE if second else PLAYER_SLEEVE
	var accent := CPU if second else PLAYER
	for i in 6:
		var rect := _finger_button(i)
		var hot := hover == "fingers%d" % i and active
		# Against the CPU your pick stays lit during the round; between two players it stays secret.
		var picked := mode == "cpu" and not _can_throw() and player_fingers == i
		var fill := Color(1, 1, 1, 0.12 if hot else 0.05)
		if picked:
			fill = Color(accent, 0.3)
		_box(rect, fill, accent if picked or hot else Color(1, 1, 1, 0.16), 14, 2.0 if picked or hot else 1.0)
		var lift := -4.0 if hot else 0.0
		_draw_hand(_hand_transform(rect.position + Vector2(rect.size.x / 2.0, 86 + lift), 0, 0.3), _ext_for(i), skin, sleeve, 18)
		_text(str(i), Vector2(rect.get_center().x, rect.end.y - 18), 20, INK, bold)
		if not active and not picked:
			_box(rect, Color(0.08, 0.06, 0.17, 0.55), Color(0, 0, 0, 0), 14, 0.0)


func _draw_confetti() -> void:
	for piece in confetti:
		var a := clampf(3.0 - piece.t, 0.0, 1.0)
		draw_set_transform(piece.pos, piece.rot)
		draw_rect(Rect2(-5, -3, 10, 6), Color(piece.color, a))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_match_over() -> void:
	var a := clampf((over_t - OVERLAY_DELAY) * 4.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.45 * a))
	var col := PLAYER if round_won else CPU
	var shift := Vector2(0, (1.0 - a) * 20.0)
	var rect := OVERLAY
	rect.position += shift
	_box(rect, Color(Color("1b1535"), a), Color(col, a), 20, 2.0, 18)
	var title := ""
	if mode == "cpu":
		title = tr("you_win_match") if round_won else tr("cpu_wins_match")
	else:
		title = tr("wins_match") % _name(0 if round_won else 1)
	_text(title, rect.position + Vector2(rect.size.x / 2.0, 56), _fit(title, 30, rect.size.x - 30, serif_bold),
			Color(col.lightened(0.2), a), serif_bold)
	_text("%d : %d" % score, rect.position + Vector2(rect.size.x / 2.0, 118), 44, Color(INK, a), bold)
	for key: String in OVERLAY_BUTTONS:
		var button: Rect2 = OVERLAY_BUTTONS[key]
		button.position += shift
		var tint := col if key == "new_match" else Color(1, 1, 1, 0.5)
		_button(button, tr("new_match") if key == "new_match" else tr("main_menu"), Color(tint, tint.a * a), hover == "over_" + key, 18)


func _draw_menu() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.6))
	_box(MENU_RECT, Color("1b1535"), Color(1, 1, 1, 0.25), 18, 1.5, 18)
	var x := MENU_RECT.position.x + 30
	var right := MENU_RECT.end.x - 30
	var y := MENU_RECT.position.y
	_text_left(tr("settings"), Vector2(x, y + 38), 26, GOLD, serif_bold)
	var rows := _menu_rows()
	var close: Rect2 = rows.close
	var close_col := GOLD if close.has_point(mouse) else INK
	draw_line(close.get_center() + Vector2(-9, -9), close.get_center() + Vector2(9, 9), close_col, 2.5, true)
	draw_line(close.get_center() + Vector2(9, -9), close.get_center() + Vector2(-9, 9), close_col, 2.5, true)

	for key in ["language", "sound", "difficulty", "match_length"]:
		var rect: Rect2 = rows[key]
		_box(rect, Color(1, 1, 1, 0.08 if rect.has_point(mouse) else 0.04), Color(1, 1, 1, 0.14), 10, 1.0)
		_text_left(tr(key), Vector2(rect.position.x + 16, rect.get_center().y), 17, INK, bold)
	var lang_name := ""
	for entry in StringsScript.LANGUAGES:
		if entry[0] == language:
			lang_name = entry[1]
	var cy := func(key: String) -> float: return rows[key].get_center().y
	_text_right("‹   " + lang_name + "   ›", Vector2(right - 16, cy.call("language")), 17, GOLD, bold)
	var sw := Rect2(right - 70, cy.call("sound") - 13, 54, 26)
	_box(sw, PLAYER if sound_on else Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 13, 0.0)
	draw_circle(Vector2(sw.end.x - 13 if sound_on else sw.position.x + 13, sw.get_center().y), 10, Color.WHITE)
	_text_right(tr("hard") if clever else tr("easy"), Vector2(right - 16, cy.call("difficulty")), 17, GOLD, bold)
	_text_left(tr("hard_hint"), Vector2(x + 16, y + 228), 13, MUTED, font)
	_text_right(tr("first_to") % match_length, Vector2(right - 16, cy.call("match_length")), 17, GOLD, bold)

	_text_left("%s · %s" % [tr("statistics"), tr("vs_cpu")], Vector2(x, y + 322), 20, GOLD, serif_bold)
	var lines := [
		["rounds", str(stats.rounds)],
		["rounds_won", str(stats.rounds_won)],
		["matches", "%d / %d" % [stats.matches_won, stats.matches_lost]],
		["best_streak", str(stats.best_streak)],
	]
	for i in lines.size():
		var ly := y + 356 + i * 30
		_text_left(tr(lines[i][0]), Vector2(x, ly), 16, MUTED, font)
		_text_right(lines[i][1], Vector2(right, ly), 16, INK, bold)
		if i < lines.size() - 1:
			draw_line(Vector2(x, ly + 15), Vector2(right, ly + 15), Color(1, 1, 1, 0.06), 1.0)

	var reset: Rect2 = rows.reset
	var hot := reset.has_point(mouse)
	_box(reset, Color("7a1a2a") if reset_armed else Color(1, 1, 1, 0.1 if hot else 0.05), Color(1, 1, 1, 0.25), 10, 1.0)
	_text(tr("confirm_reset") if reset_armed else tr("reset"), reset.get_center(), 16, INK, bold)
	var keys := tr("keys_help")
	_text(keys, Vector2(MENU_RECT.get_center().x, y + 570), _fit(keys, 12, MENU_RECT.size.x - 30, font), MUTED, font)
