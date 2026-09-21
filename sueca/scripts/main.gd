extends Node2D
## Jogo da Sueca: the Portuguese trick-taking card game, for four players in two teams.
## You (bottom) play with your partner (top) against the players on the sides. The deck has 40
## cards (no 8, 9 or 10), 10 each; the dealer's last card is shown and its suit is trump. Players
## must follow suit; a trick goes to the highest trump, or else to the highest card of the suit led.
## Cards rank A, 7, K, J, Q, 6, 5, 4, 3, 2 and are worth 11, 10, 4, 3, 2 (120 in the deck).
## A hand is won with 61 points: 1 game, 2 with 91 or more (capote), 4 with every trick (bandeira).
## The first team to 4 games wins the match. Play goes counterclockwise: you, right, partner, left.
## Keys: Left / Right pick a card, Enter / Space play it, Esc menu.
## Run with "-- --render-icon" (scene res://scenes/main.tscn) to redraw icon.png, or with
## "-- --render-store" to redraw the Box, Poster and Hero art in store-listing/.

const SfxScript := preload("res://scripts/sfx.gd")
const StringsScript := preload("res://scripts/strings.gd")

const SCREEN := Vector2(1280, 720)
const SAVE_PATH := "user://sueca.cfg"
const GAMES_TO_WIN := 4

# Cards are ints 0..39: suit * 10 + rank. Ranks go from the weakest (2) to the strongest (Ace).
# Suits: 0 copas (hearts), 1 ouros (diamonds), 2 espadas (spades), 3 paus (clubs).
const RANK_LABELS := ["2", "3", "4", "5", "6", "D", "V", "R", "7", "A"]
const RANK_POINTS := [0, 0, 0, 0, 0, 2, 3, 4, 10, 11]
const SUIT_KEYS := ["hearts", "diamonds", "spades", "clubs"]
const QUEEN := 5
const JACK := 6
const KING := 7
const ACE := 9
const TITLE_CARDS := [29, 9, 39, 19]  # the four aces

# Pip layouts of the number cards, in units of the pip grid.
const PIPS := {
	2: [Vector2(0, -1), Vector2(0, 1)],
	3: [Vector2(0, -1), Vector2(0, 0), Vector2(0, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
	7: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, -0.5), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}
const CLUB_LOBES := [Vector3(0, -0.46, 0.35), Vector3(-0.42, 0.1, 0.35), Vector3(0.42, 0.1, 0.35)]
const STEM := [Vector2(0, 0.1), Vector2(-0.34, 0.96), Vector2(0.34, 0.96)]

const CARD := Vector2(96, 134)
const SMALL := 0.62  # scale of the other players' cards

# Seats: 0 you (bottom), 1 right, 2 partner (top), 3 left. Play goes 0, 1, 2, 3.
const TRICK_POS := [Vector2(640, 414), Vector2(752, 330), Vector2(640, 246), Vector2(528, 330)]
const DECK_POS := [Vector2(640, 470), Vector2(890, 330), Vector2(640, 196), Vector2(390, 330)]
const TRUMP_POS := [Vector2(840, 470), Vector2(1070, 468), Vector2(812, 150), Vector2(210, 468)]
const TRUMP_ROT := [0.0, -0.2, 0.15, 0.2]
const SEAT_OUT := [Vector2(640, 840), Vector2(1400, 330), Vector2(640, -150), Vector2(-120, 330)]
const NAME_POS := [Vector2(1150, 688), Vector2(1200, 490), Vector2(640, 126), Vector2(80, 490)]
const FLOAT_POS := [Vector2(640, 500), Vector2(1060, 330), Vector2(640, 172), Vector2(220, 330)]
const HAND_Y := 638.0
const HAND_SPACING := 64.0
const LIFT := 30.0

# Timing, in seconds (the fast speed runs the clock 1.8 times quicker).
const DEAL_GAP := 0.05
const RESULT_DELAY := 0.6

# Interface.
const SCORE_RECT := Rect2(16, 14, 264, 110)
const TRUMP_RECT := Rect2(1016, 14, 186, 66)
const MENU_BUTTON := Rect2(1216, 22, 48, 48)
const LAST_RECT := Rect2(16, 588, 232, 118)
const MENU_RECT := Rect2(390, 60, 500, 600)
const RULES_RECT := Rect2(190, 76, 900, 568)
const RESULT_RECT := Rect2(360, 128, 560, 424)

# Colors.
const GOLD := Color("f2c94c")
const GOLD_DEEP := Color("a8761c")
const GOLD_LIGHT := Color("fff1bf")
const INK := Color("fdf8ea")
const MUTED := Color(1, 0.96, 0.86, 0.62)
const PANEL := Color(0.01, 0.07, 0.04, 0.72)
const US := Color("5cb8ff")
const THEM := Color("ff8a65")
const CARD_RED := Color("c8102e")
const CARD_BLACK := Color("1b1b22")
const ROBES := [Color("c8102e"), Color("dd8a1c"), Color("2c4a9a"), Color("237a4b")]
const CONFETTI := [Color("f2c94c"), Color("5cb8ff"), Color("ff6b6b"), Color("7ee081"), Color("ffffff"), Color("c58cff")]

# The hand being played.
var phase := "title"  # title, shuffle, deal, reveal, play, trick, collect, round_end
var phase_t := 0.0
var deck := []  # cards still to deal; the last one is on top
var hands := [[], [], [], []]
var trick := []  # {"seat", "card", "rot"} in playing order
var last_trick := []
var last_winner := -1  # index in last_trick
var piles := [[], []]  # cards won by each team
var pile_owner := {}  # card -> seat whose trick it went to
var points := [0, 0]
var tricks := [0, 0]
var dealer := 2
var trump := -1
var trump_card := -1
var trump_shown := false  # the dealer's trump card lies face up until the dealer's first play
var turn := 0
var deal_i := 0
var deal_t := 0.0
var ai_delay := 0.0
var played := {}  # every card played this hand, as the players remember them
var voids := []  # voids[seat][suit]: seat showed it has no cards of that suit

# The match.
var games := [0, 0]
var hand_number := 0
var result := {}
var result_shown := false
var match_over := false

# Settings and statistics.
var sound_on := true
var fast := false
var stats := {"matches": 0, "match_wins": 0, "hands": 0, "hand_wins": 0, "capotes": 0, "bandeiras": 0, "best_hand": 0}

# Interface.
var vis := {}  # card -> {"pos", "rot", "zoom", "face" (0 back to 1 face), "z"}
var wiggle := {}  # card -> seconds left shaking (tried an illegal card)
var hover_card := -1
var hover_button := ""
var kb_index := -1  # card picked with the keyboard, index in hands[0]
var legal_now := []
var mouse := Vector2.ZERO
var message := ""
var message_arg := ""
var message_t := 0.0
var menu_open := false
var rules_open := false
var confirm_new := false
var score_pulse := [0.0, 0.0]
var floats := []
var particles := []
var clock := 0.0
var rng := RandomNumberGenerator.new()
var rendering_icon := false
var art_kind := ""  # "box", "poster" or "hero" when this copy only draws Store art
var art_size := SCREEN

var serif: Font
var font: Font
var bold: Font
var sfx
var felt: ColorRect
var face_style: StyleBoxFlat
var shadow_style: StyleBoxFlat
var dim_style: StyleBoxFlat
var back_texture: ImageTexture
var icon_felt: GradientTexture2D
var heart_shape := PackedVector2Array()
var spade_shape := PackedVector2Array()
var diamond_shape := PackedVector2Array()


func _ready() -> void:
	serif = _font(["Georgia", "Times New Roman", "Cambria"], 700)
	font = _font(["Segoe UI", "Helvetica Neue", "Arial"], 400)
	bold = _font(["Segoe UI", "Helvetica Neue", "Arial"], 700)
	sfx = SfxScript.new()
	add_child(sfx)
	StringsScript.install()
	TranslationServer.set_locale(StringsScript.system_language())
	rng.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_make_styles()
	_make_suit_shapes()
	back_texture = _make_back()
	_add_felt()
	_load()
	AudioServer.set_bus_mute(0, not sound_on)
	for c in 40:
		deck.append(c)
		vis[c] = {"pos": Vector2(640, 330), "rot": 0.0, "zoom": 1.0, "face": 0.0, "z": c}
	for s in 4:
		voids.append([false, false, false, false])
	if art_kind != "":
		return
	if "--render-icon" in OS.get_cmdline_user_args():
		_render_icon()
	elif "--render-store" in OS.get_cmdline_user_args():
		_render_store()


func _font(names: Array, weight: int) -> Font:
	if OS.has_feature("web"):
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 0.7 if weight >= 700 else 0.0
		return variation
	var system := SystemFont.new()
	system.font_names = PackedStringArray(names)
	system.font_weight = weight
	# Store art is drawn scaled up, so its text needs a font that stays sharp at any size.
	system.multichannel_signed_distance_field = art_kind != ""
	return system


## Green card-table cloth behind everything, drawn by a shader so it has texture and a soft light.
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
	float d = length((UV - vec2(0.5, 0.46)) * vec2(1.3, 1.0));
	vec3 col = mix(vec3(0.07, 0.42, 0.24), vec3(0.012, 0.1, 0.055), smoothstep(0.05, 0.9, d));
	col += (hash(floor(p)) - 0.5) * 0.03;
	col += (noise(p * 0.035) - 0.5) * 0.045;
	col += (sin((p.x + p.y) * 1.7) + sin((p.x - p.y) * 1.7)) * 0.006;
	COLOR = vec4(col, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("size", art_size)
	felt = ColorRect.new()
	felt.size = art_size
	felt.material = material
	felt.show_behind_parent = true
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(felt)


func _make_styles() -> void:
	face_style = StyleBoxFlat.new()
	face_style.bg_color = Color("fbf8f1")
	face_style.border_color = Color("c9c0ab")
	face_style.set_border_width_all(1)
	face_style.set_corner_radius_all(8)
	face_style.shadow_color = Color(0, 0, 0, 0.32)
	face_style.shadow_size = 5
	face_style.shadow_offset = Vector2(1.5, 3)
	face_style.anti_aliasing = true
	shadow_style = StyleBoxFlat.new()
	shadow_style.draw_center = false
	shadow_style.set_corner_radius_all(8)
	shadow_style.shadow_color = Color(0, 0, 0, 0.32)
	shadow_style.shadow_size = 5
	shadow_style.shadow_offset = Vector2(1.5, 3)
	dim_style = StyleBoxFlat.new()
	dim_style.bg_color = Color(0.02, 0.08, 0.05, 0.5)
	dim_style.set_corner_radius_all(8)
	dim_style.anti_aliasing = true


## Suit symbols as polygons about 2 units tall, centered on the origin.
func _make_suit_shapes() -> void:
	for i in 48:
		var a := i * TAU / 48.0
		var s := sin(a)
		var x := 16.0 * s * s * s
		var y := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		heart_shape.append(Vector2(x, y) / 17.0 + Vector2(0, -0.14))
		spade_shape.append(Vector2(x, -y) / 17.0 * 0.92 + Vector2(0, -0.1))
	var tips := [Vector2(0, -1), Vector2(0.74, 0), Vector2(0, 1), Vector2(-0.74, 0)]
	for i in 4:
		var a: Vector2 = tips[i]
		var b: Vector2 = tips[(i + 1) % 4]
		for k in 4:
			var f := k / 4.0
			diamond_shape.append(a.lerp(b, f) * (1.0 - 0.09 * sin(PI * f)))


## The card back, painted pixel by pixel once at twice the card size: a red lattice in a cream frame.
func _make_back() -> ImageTexture:
	var s := 2.0
	var w := int(CARD.x * s)
	var h := int(CARD.y * s)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cream := Color("f7f1e3")
	var gold := Color("d9a93f")
	var base := Color("9e1a30")
	var light := Color("c93a52")
	var deep := Color("6a0e1f")
	for py in h:
		for px in w:
			var u := (px + 0.5) / s
			var v := (py + 0.5) / s
			var q := Vector2(absf(u - CARD.x / 2.0), absf(v - CARD.y / 2.0)) - (CARD / 2.0 - Vector2(8, 8))
			var dist := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 8.0
			var inside := -dist
			var col := cream
			if inside >= 6.4:
				var p := fposmod(u + v, 9.0)
				var r := fposmod(u - v, 9.0)
				var line := minf(minf(p, 9.0 - p), minf(r, 9.0 - r))
				col = base.lerp(light, clampf(1.3 - line, 0.0, 1.0) * 0.85)
				var c := Vector2(u - CARD.x / 2.0, v - CARD.y / 2.0)
				var ring := c.length()
				var rhomb := absf(c.x) * 1.3 + absf(c.y)
				if ring < 19.0:
					col = deep
				if ring >= 16.5 and ring < 19.0:
					col = gold
				if rhomb < 11.0:
					col = gold
				if rhomb < 5.0:
					col = cream
			elif inside >= 5.0:
				col = gold
			col.a = clampf(0.5 - dist * s, 0.0, 1.0)
			img.set_pixel(px, py, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# --- Cards and rules -------------------------------------------------------------------------

func _points(c: int) -> int:
	return RANK_POINTS[c % 10]


func _count_suit(cards: Array, suit: int) -> int:
	var n := 0
	for c: int in cards:
		if c / 10 == suit:
			n += 1
	return n


## True when card `a` beats `b`, the card winning the trick so far (led suit `led`).
func _beats(a: int, b: int, led: int) -> bool:
	if a / 10 == b / 10:
		return a % 10 > b % 10
	return a / 10 == trump


func _trick_winner_index() -> int:
	if trick.is_empty():
		return -1
	var led: int = trick[0].card / 10
	var best := 0
	for i in range(1, trick.size()):
		if _beats(trick[i].card, trick[best].card, led):
			best = i
	return best


func _led() -> int:
	return -1 if trick.is_empty() else trick[0].card / 10


## Cards `seat` may play: any card when leading, otherwise the led suit if it has any.
func _legal(seat: int) -> Array:
	var hand: Array = hands[seat]
	if trick.is_empty():
		return hand.duplicate()
	var led := _led()
	var follow := hand.filter(func(c: int) -> bool: return c / 10 == led)
	return follow if not follow.is_empty() else hand.duplicate()


func _my_turn() -> bool:
	return phase == "play" and turn == 0 and not menu_open and not rules_open


## Your hand grouped by suit with alternating colors, trumps on the right, low to high.
func _sort_hand() -> void:
	var others := []
	for s in [2, 0, 3, 1]:
		if s != trump:
			others.append(s)
	var order := others
	if others.size() == 3:
		var blacks := others.filter(func(s: int) -> bool: return s >= 2)
		var reds := others.filter(func(s: int) -> bool: return s < 2)
		order = [blacks[0], reds[0], blacks[1]] if blacks.size() == 2 else [reds[0], blacks[0], reds[1]]
		order.append(trump)
	hands[0].sort_custom(func(a: int, b: int) -> bool:
		var sa := order.find(a / 10)
		var sb := order.find(b / 10)
		if sa != sb:
			return sa < sb
		return a % 10 < b % 10)


# --- Game flow -------------------------------------------------------------------------------

func _start_hand() -> void:
	if match_over:
		games = [0, 0]
		hand_number = 0
		match_over = false
	hand_number += 1
	dealer = (dealer + 1) % 4
	hands = [[], [], [], []]
	trick = []
	last_trick = []
	last_winner = -1
	piles = [[], []]
	points = [0, 0]
	tricks = [0, 0]
	played = {}
	voids = []
	for s in 4:
		voids.append([false, false, false, false])
	trump = -1
	trump_card = -1
	trump_shown = false
	result = {}
	result_shown = false
	kb_index = -1
	deck = []
	for c in 40:
		deck.append(c)
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	phase = "shuffle"
	phase_t = 0.0
	sfx.play("shuffle")
	if dealer == 0:
		_say("dealer_you")
	else:
		_say("dealer_other", tr("name_%d" % dealer))


func _new_match() -> void:
	games = [0, 0]
	hand_number = 0
	match_over = false
	menu_open = false
	confirm_new = false
	_start_hand()


func _step(dt: float) -> void:
	match phase:
		"shuffle":
			if phase_t >= 1.0:
				phase = "deal"
				phase_t = 0.0
				deal_t = 0.0
				deal_i = 0
		"deal":
			deal_t += dt
			while deal_t >= DEAL_GAP and not deck.is_empty():
				deal_t -= DEAL_GAP
				_deal_one()
			if deck.is_empty():
				_reveal()
		"reveal":
			if phase_t >= 1.7:
				turn = (dealer + 1) % 4
				_begin_turn()
		"play":
			if turn != 0 and phase_t >= ai_delay:
				_play(turn, _ai_choose(turn))
		"trick":
			if phase_t >= 1.05:
				_collect()
		"collect":
			if phase_t >= 0.5:
				if hands[turn].is_empty():
					_end_hand()
				else:
					_begin_turn()
		"round_end":
			if not result_shown and phase_t >= RESULT_DELAY:
				result_shown = true
				_celebrate()


## Deals the top card of the deck, one at a time, starting at the dealer's right.
func _deal_one() -> void:
	var card: int = deck.pop_back()
	var seat := (dealer + 1 + deal_i) % 4
	deal_i += 1
	hands[seat].append(card)
	if deck.is_empty():
		trump_card = card  # the dealer's last card
	if seat == 0:
		_sort_hand()
	sfx.play("deal", rng.randf_range(0.9, 1.15))


func _reveal() -> void:
	trump = trump_card / 10
	trump_shown = true
	_sort_hand()
	phase = "reveal"
	phase_t = 0.0
	sfx.play("reveal")
	_burst(Vector2(640, 330), 26, GOLD)


func _begin_turn() -> void:
	phase = "play"
	phase_t = 0.0
	ai_delay = rng.randf_range(0.5, 0.95)
	if turn == 0:
		_say("your_turn")
		sfx.play("turn")
	else:
		message = ""


func _try_play(card: int) -> void:
	if card in _legal(0):
		_play(0, card)
	else:
		wiggle[card] = 0.4
		sfx.play("error")
		_say("must_follow", tr(SUIT_KEYS[_led()]))


func _play(seat: int, card: int) -> void:
	var led := _led()
	hands[seat].erase(card)
	if seat == dealer:
		trump_shown = false
	if led >= 0 and card / 10 != led:
		voids[seat][led] = true
	played[card] = true
	trick.append({"seat": seat, "card": card, "rot": rng.randf_range(-0.13, 0.13)})
	if led >= 0 and led != trump and card / 10 == trump and _trick_winner_index() == trick.size() - 1:
		sfx.play("trump")
		_burst(TRICK_POS[seat], 24, GOLD)
		_float(tr("cut"), TRICK_POS[seat] + Vector2(0, -80), GOLD_LIGHT, 30)
	else:
		sfx.play("play", rng.randf_range(0.9, 1.1))
	if seat == 0:
		message = ""
		if kb_index >= 0:
			kb_index = mini(kb_index, hands[0].size() - 1)
	if trick.size() == 4:
		phase = "trick"
		phase_t = 0.0
	else:
		turn = (seat + 1) % 4
		_begin_turn()


func _collect() -> void:
	var wi := _trick_winner_index()
	var winner: int = trick[wi].seat
	var team := winner % 2
	var pts := 0
	for e in trick:
		pts += _points(e.card)
		piles[team].append(e.card)
		pile_owner[e.card] = winner
	points[team] += pts
	tricks[team] += 1
	last_trick = trick.duplicate()
	last_winner = wi
	trick = []
	turn = winner
	phase = "collect"
	phase_t = 0.0
	sfx.play("collect")
	if pts > 0:
		var col := US if team == 0 else THEM
		sfx.play("trick_us" if team == 0 else "trick_them")
		_float("+%d" % pts, FLOAT_POS[winner], col, 26 + mini(pts, 30) / 2)
		score_pulse[team] = 1.0
		if pts >= 20:
			_burst(FLOAT_POS[winner], 16, col)


func _end_hand() -> void:
	stats.hands += 1
	var winner := -1
	if points[0] != points[1]:
		winner = 0 if points[0] > points[1] else 1
	var gained := 0
	var kind := ""
	if winner >= 0:
		gained = 1
		kind = "simple"
		if tricks[winner] == 10:
			gained = 4
			kind = "bandeira"
		elif points[winner] >= 91:
			gained = 2
			kind = "capote"
		games[winner] += gained
	stats.best_hand = maxi(stats.best_hand, points[0])
	if winner == 0:
		stats.hand_wins += 1
		if kind == "capote":
			stats.capotes += 1
		elif kind == "bandeira":
			stats.bandeiras += 1
	result = {"winner": winner, "gained": gained, "kind": kind}
	match_over = winner >= 0 and games[winner] >= GAMES_TO_WIN
	if match_over:
		stats.matches += 1
		if winner == 0:
			stats.match_wins += 1
	message = ""
	phase = "round_end"
	phase_t = 0.0
	_save()


## Sound and confetti when the result panel shows up.
func _celebrate() -> void:
	match result.winner:
		0:
			if match_over:
				sfx.play("match_win")
				_confetti(240)
			else:
				sfx.play("win")
				_confetti(70 if result.kind == "simple" else 150)
		1:
			sfx.play("lose")
		_:
			sfx.play("reveal")


func _say(key: String, arg := "") -> void:
	message = key
	message_arg = arg
	message_t = 0.0


# --- Computer players ------------------------------------------------------------------------

## Cards `seat` has not seen: not played yet and not in its own hand.
func _unseen(seat: int) -> Array:
	var out := []
	for c in 40:
		if not played.has(c) and not c in hands[seat]:
			out.append(c)
	return out


func _is_boss(card: int, unseen: Array) -> bool:
	for u: int in unseen:
		if u / 10 == card / 10 and u % 10 > card % 10:
			return false
	return true


## Whether an opponent of `seat` still to play in this trick could beat `card`, as far as `seat`
## can tell from the cards played and the suits the others have shown to be out of.
func _may_be_beaten(seat: int, card: int, led: int, unseen: Array) -> bool:
	var done := []
	for e in trick:
		done.append(e.seat)
	for s in 4:
		if s % 2 == seat % 2 or s in done:
			continue
		for u: int in unseen:
			if not _beats(u, card, led):
				continue
			if u / 10 == led:
				if not voids[s][led]:
					return true
			elif not voids[s][trump] and (voids[s][led] or _count_suit(unseen, led) <= 2):
				return true
	return false


func _ai_choose(seat: int) -> int:
	var legal := _legal(seat)
	if legal.size() == 1:
		return legal[0]
	var unseen := _unseen(seat)
	var best: int = legal[0]
	var best_score := -INF
	for c: int in legal:
		var score := _lead_score(seat, c, unseen) if trick.is_empty() else _follow_score(seat, c, unseen)
		score += rng.randf() * 0.4
		if score > best_score:
			best_score = score
			best = c
	return best


## How good `c` is as the first card of a trick.
func _lead_score(seat: int, c: int, unseen: Array) -> float:
	var suit := c / 10
	var rank := c % 10
	var pts := _points(c)
	var partner := (seat + 2) % 4
	var foes := [(seat + 1) % 4, (seat + 3) % 4]
	var safe := not _may_be_beaten(seat, c, suit, unseen)
	if suit == trump:
		# Draw the opponents' trumps when strong in them.
		var left := _count_suit(unseen, trump)
		var trump_score := -6.0 + _count_suit(hands[seat], trump) * 2.5 - left * 1.2
		if safe:
			trump_score += 5.0 + pts * 0.3
		else:
			trump_score -= pts * 1.5 + rank * 0.2
		if left == 0:
			trump_score -= 6.0
		return trump_score
	var score := 0.0
	if safe:
		score = 9.0 + pts  # a sure trick: cash it
	else:
		score = 3.0 - pts * 1.4 - rank * 0.3  # otherwise lead low
		var foes_follow: bool = not voids[foes[0]][suit] and not voids[foes[1]][suit]
		if voids[partner][suit] and not voids[partner][trump] and foes_follow:
			score += 6.0  # the partner can cut it
	for f: int in foes:
		if voids[f][suit] and not voids[f][trump]:
			score -= 5.0 + pts
	return score


## How good `c` is when following: roughly the points it swings to our team, minus the cost of
## spending a trump or a card that would win a trick later.
func _follow_score(seat: int, c: int, unseen: Array) -> float:
	var led := _led()
	var wi := _trick_winner_index()
	var best_card: int = trick[wi].card
	var partner_winning: bool = trick[wi].seat % 2 == seat % 2
	var last := trick.size() == 3
	var on_table := 0
	for e in trick:
		on_table += _points(e.card)
	var pts := _points(c)
	var rank := c % 10
	var spend := 0.0
	if c / 10 == trump and led != trump:
		spend = 2.0 + rank * 0.6 + pts * 0.8
	elif c / 10 != trump and pts >= 10 and _is_boss(c, unseen):
		spend = 5.0
	var take := 0.0  # our chance of taking the trick
	if _beats(c, best_card, led):
		take = 1.0 if last or not _may_be_beaten(seat, c, led, unseen) else 0.45
	elif partner_winning:
		take = 1.0 if last or not _may_be_beaten(seat, best_card, led, unseen) else 0.45
	return (2.0 * take - 1.0) * (on_table + pts + 3) - spend - rank * 0.03


# --- Frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	clock += delta
	message_t += delta
	if phase != "title" and not menu_open and not rules_open and not rendering_icon:
		var dt := delta * (1.8 if fast else 1.0)
		phase_t += dt
		_step(dt)
	legal_now = _legal(0) if _my_turn() else []
	_update_cards(delta)
	_update_effects(delta)
	_update_hover()
	queue_redraw()


## Where every card should be right now: card -> [pos, rotation, zoom, face up, z].
func _targets() -> Dictionary:
	var out := {}
	for i in deck.size():
		var pos: Vector2 = DECK_POS[dealer] + Vector2(-i * 0.22, -i * 0.3)
		var rot := 0.0
		if phase == "shuffle":
			var side := 1.0 if i % 2 == 0 else -1.0
			var split := absf(sin(clampf(phase_t, 0.0, 1.0) * TAU)) * 52.0
			pos += Vector2(side * split, -split * 0.12)
			rot = side * split * 0.004
		out[deck[i]] = [pos, rot, 0.85, false, i]
	var selected := _selected()
	for seat in 4:
		var cards: Array = hands[seat].duplicate()
		if trump_shown and seat == dealer and seat != 0:
			cards.erase(trump_card)
			out[trump_card] = [TRUMP_POS[seat], TRUMP_ROT[seat], 0.8, true, 150]
		var mid := (cards.size() - 1) / 2.0
		for i in cards.size():
			var off := i - mid
			match seat:
				0:
					var pos := Vector2(640 + off * HAND_SPACING, HAND_Y + off * off * 1.4)
					if cards[i] == selected:
						pos += Vector2(0, -(LIFT if cards[i] in legal_now else 10.0)).rotated(off * 0.03)
					out[cards[i]] = [pos, off * 0.03, 1.0, true, 300 + i]
				1:
					out[cards[i]] = [Vector2(1200, 330 + off * 22), -PI / 2, SMALL, false, 100 + i]
				2:
					out[cards[i]] = [Vector2(640 - off * 24, 58), PI, SMALL, false, 100 + i]
				3:
					out[cards[i]] = [Vector2(80, 330 - off * 22), PI / 2, SMALL, false, 100 + i]
	var wi := _trick_winner_index()
	for i in trick.size():
		var e: Dictionary = trick[i]
		var zoom := 1.08 if phase == "trick" and i == wi else 1.0
		out[e.card] = [TRICK_POS[e.seat], e.rot, zoom, true, 200 + i]
	for team in 2:
		for c: int in piles[team]:
			out[c] = [SEAT_OUT[pile_owner[c]], c * 0.7, 0.7, false, 50]
	return out


## Every card glides toward its target, and turns over when it should.
func _update_cards(delta: float) -> void:
	var targets := _targets()
	var k := 1.0 - exp(-delta * (22.0 if fast else 13.0))
	var flip := delta * (7.0 if fast else 4.5)
	for c in 40:
		if not targets.has(c):
			continue
		var t: Array = targets[c]
		var v: Dictionary = vis[c]
		v.pos = v.pos.lerp(t[0], k)
		v.rot = lerp_angle(v.rot, t[1], k)
		v.zoom = lerpf(v.zoom, t[2], k)
		v.face = move_toward(v.face, 1.0 if t[3] else 0.0, flip)
		v.z = t[4]


func _update_effects(delta: float) -> void:
	for p in particles:
		p.age += delta
		var vel: Vector2 = p.vel
		var pos: Vector2 = p.pos
		if p.kind == "spark":
			vel *= exp(-delta * 3.0)
			vel.y += 140.0 * delta
		else:
			vel.y = minf(vel.y + 60.0 * delta, 240.0)
			pos.x += sin(p.age * 3.0 + p.rot) * 40.0 * delta
		p.pos = pos + vel * delta
		p.vel = vel
		p.rot += p.spin * delta
	particles = particles.filter(func(p: Dictionary) -> bool: return p.age < p.life)
	for f in floats:
		f.age += delta
	floats = floats.filter(func(f: Dictionary) -> bool: return f.age < f.life)
	for c in wiggle.keys():
		wiggle[c] -= delta
		if wiggle[c] <= 0.0:
			wiggle.erase(c)
	for i in 2:
		score_pulse[i] = maxf(0.0, score_pulse[i] - delta * 2.0)


func _burst(at: Vector2, count: int, color: Color) -> void:
	for i in count:
		particles.append({
			"kind": "spark", "pos": at, "vel": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80, 330),
			"age": 0.0, "life": rng.randf_range(0.45, 0.9), "color": color, "size": rng.randf_range(3.0, 7.0),
			"rot": 0.0, "spin": 0.0,
		})


func _confetti(count: int) -> void:
	for i in count:
		particles.append({
			"kind": "confetti", "pos": Vector2(rng.randf_range(0, SCREEN.x), rng.randf_range(-300, -10)),
			"vel": Vector2(rng.randf_range(-60, 60), rng.randf_range(120, 240)), "age": 0.0, "life": rng.randf_range(3.5, 5.0),
			"color": CONFETTI[rng.randi() % CONFETTI.size()], "size": rng.randf_range(6.0, 11.0),
			"rot": rng.randf() * TAU, "spin": rng.randf_range(-8.0, 8.0),
		})
	sfx.play("pop")


func _float(text: String, at: Vector2, color: Color, size: int) -> void:
	floats.append({"text": text, "pos": at, "color": color, "size": size, "age": 0.0, "life": 1.3})


# --- Input -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if rendering_icon:
		return
	if event is InputEventMouseMotion:
		mouse = event.position
		kb_index = -1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse = event.position
		_update_hover()
		_click()
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)


func _key(code: int) -> void:
	if rules_open:
		if code in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			rules_open = false
			sfx.play("click")
		return
	if code == KEY_ESCAPE:
		_toggle_menu()
		return
	if menu_open:
		return
	match code:
		KEY_LEFT, KEY_RIGHT:
			var n: int = hands[0].size()
			if n == 0 or phase == "title":
				return
			var step := 1 if code == KEY_RIGHT else -1
			if kb_index < 0:
				var at: int = hands[0].find(hover_card)
				kb_index = at if at >= 0 else (0 if step > 0 else n - 1)
			else:
				kb_index = clampi(kb_index + step, 0, n - 1)
			sfx.play("hover")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if phase == "title":
				sfx.play("click")
				_start_hand()
			elif phase == "round_end" and phase_t >= RESULT_DELAY:
				sfx.play("click")
				_start_hand()
			elif _my_turn() and _selected() >= 0:
				_try_play(_selected())


func _selected() -> int:
	if kb_index >= 0 and kb_index < hands[0].size():
		return hands[0][kb_index]
	return hover_card


func _buttons() -> Dictionary:
	var out := {}
	if menu_open or rules_open:
		return out
	out["menu"] = MENU_BUTTON
	if phase == "title":
		out["play"] = Rect2(540, 566, 200, 58)
		if _in_progress():
			out["rules"] = Rect2(412, 640, 220, 40)
			out["new_match"] = Rect2(648, 640, 220, 40)
		else:
			out["rules"] = Rect2(530, 640, 220, 40)
	elif phase == "round_end" and phase_t >= RESULT_DELAY:
		out["next"] = Rect2(RESULT_RECT.get_center().x - 115, RESULT_RECT.end.y - 76, 230, 54)
	return out


func _in_progress() -> bool:
	return games[0] + games[1] > 0


func _update_hover() -> void:
	var old := hover_card
	hover_card = -1
	hover_button = ""
	if menu_open or rules_open or rendering_icon:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	var buttons := _buttons()
	for key: String in buttons:
		if buttons[key].has_point(mouse):
			hover_button = key
	if hover_button == "" and phase != "title":
		var n: int = hands[0].size()
		for i in range(n - 1, -1, -1):
			var off := i - (n - 1) / 2.0
			var pos := Vector2(640 + off * HAND_SPACING, HAND_Y + off * off * 1.4)
			var p := (mouse - pos).rotated(-off * 0.03)
			var top := -CARD.y / 2.0 - (LIFT if hands[0][i] == old else 0.0)
			if absf(p.x) <= CARD.x / 2.0 and p.y >= top and p.y <= CARD.y / 2.0:
				hover_card = hands[0][i]
				break
	if hover_card != old and hover_card in legal_now:
		sfx.play("hover", rng.randf_range(0.95, 1.1))
	var pointer := hover_button != "" or hover_card in legal_now
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if pointer else Input.CURSOR_ARROW)


func _click() -> void:
	if rules_open:
		rules_open = false
		sfx.play("click")
		return
	if menu_open:
		_menu_click()
		return
	if hover_button != "":
		_press(hover_button)
	elif _my_turn() and hover_card >= 0:
		_try_play(hover_card)


func _press(button: String) -> void:
	sfx.play("click")
	match button:
		"menu":
			_toggle_menu()
		"play", "next":
			confirm_new = false
			_start_hand()
		"rules":
			rules_open = true
		"new_match":
			if confirm_new:
				_new_match()
			else:
				confirm_new = true


func _toggle_menu() -> void:
	menu_open = not menu_open
	confirm_new = false
	sfx.play("click")


func _menu_rows() -> Dictionary:
	var x := MENU_RECT.position.x + 30
	var w := MENU_RECT.size.x - 60
	var y := MENU_RECT.position.y
	return {
		"close": Rect2(MENU_RECT.end.x - 60, y + 16, 44, 44),
		"sound": Rect2(x, y + 72, w, 48),
		"speed": Rect2(x, y + 128, w, 48),
		"rules": Rect2(x, y + 184, w, 48),
		"new_match": Rect2(x, y + 474, w, 48),
	}


func _menu_click() -> void:
	var rows := _menu_rows()
	if rows.close.has_point(mouse) or not MENU_RECT.has_point(mouse):
		_toggle_menu()
	elif rows.sound.has_point(mouse):
		sound_on = not sound_on
		AudioServer.set_bus_mute(0, not sound_on)
		sfx.play("click")
		_save()
	elif rows.speed.has_point(mouse):
		fast = not fast
		sfx.play("click")
		_save()
	elif rows.rules.has_point(mouse):
		rules_open = true
		sfx.play("click")
	elif rows.new_match.has_point(mouse):
		sfx.play("click")
		if confirm_new:
			_new_match()
		else:
			confirm_new = true


# --- Saving ----------------------------------------------------------------------------------

func _save() -> void:
	if rendering_icon:
		return
	# A hand cut short is dealt again, by the same dealer, when the game starts next time.
	var between := phase in ["title", "round_end"]
	var config := ConfigFile.new()
	config.set_value("match", "games", [0, 0] if match_over else games)
	config.set_value("match", "hand_number", 0 if match_over else (hand_number if between else hand_number - 1))
	config.set_value("match", "dealer", dealer if between else (dealer + 3) % 4)
	config.set_value("match", "stats", stats)
	config.set_value("settings", "sound", sound_on)
	config.set_value("settings", "fast", fast)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	var saved_games: Array = config.get_value("match", "games", [0, 0])
	if saved_games.size() == 2 and maxi(saved_games[0], saved_games[1]) < GAMES_TO_WIN:
		games = [int(saved_games[0]), int(saved_games[1])]
	hand_number = int(config.get_value("match", "hand_number", 0))
	dealer = int(config.get_value("match", "dealer", dealer)) % 4
	var saved: Dictionary = config.get_value("match", "stats", {})
	for key in stats:
		stats[key] = int(saved.get(key, stats[key]))
	sound_on = config.get_value("settings", "sound", true)
	fast = config.get_value("settings", "fast", false)


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


## Gold title lettering with an outline and a little depth.
func _text_fx(text: String, center: Vector2, size: int, color: Color, depth: int) -> void:
	var width := serif.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2(center.x - width / 2.0, center.y + (serif.get_ascent(size) - serif.get_descent(size)) / 2.0)
	var outline := maxi(2, int(size * 0.09))
	var edge := Color("2a1606")
	draw_string_outline(serif, base + Vector2(0, depth + 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, 0.45))
	for k in range(depth, 0, -1):
		draw_string_outline(serif, base + Vector2(0, k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, edge)
	for k in range(depth, 0, -1):
		draw_string(serif, base + Vector2(0, k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, GOLD_DEEP.darkened(0.3))
	draw_string_outline(serif, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, edge)
	draw_string(serif, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


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


func _button(rect: Rect2, label: String, primary: bool, hot: bool) -> void:
	if primary:
		var pulse := 0.5 + 0.5 * sin(clock * 3.0)
		_box(rect.grow(3.0 + pulse * 2.0), Color(GOLD, 0.12 + 0.1 * pulse), Color(0, 0, 0, 0), rect.size.y / 2.0 + 4.0, 0.0)
		_box(rect, GOLD.lightened(0.15) if hot else GOLD, GOLD_DEEP, rect.size.y / 2.0, 2.0, 8)
		_box(Rect2(rect.position + Vector2(8, 4), Vector2(rect.size.x - 16, rect.size.y * 0.42)), Color(1, 1, 1, 0.22), Color(0, 0, 0, 0), rect.size.y / 3.0, 0.0)
		_text(label, rect.get_center(), 22, Color("2a1606"), bold)
	else:
		_box(rect, Color(1, 1, 1, 0.16 if hot else 0.07), Color(GOLD, 0.7 if hot else 0.45), rect.size.y / 2.0, 1.5)
		_text(label, rect.get_center(), 16, GOLD_LIGHT if hot else INK, bold)


func _back_out(x: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3) + c * pow(x - 1.0, 2)


func _star(center: Vector2, r: float, color: Color) -> void:
	if r < 1.0:
		return
	var points := PackedVector2Array()
	for i in 8:
		points.append(center + Vector2.from_angle(i * TAU / 8.0 - PI / 2.0) * (r if i % 2 == 0 else r * 0.28))
	draw_colored_polygon(points, color)


func _place(shape: PackedVector2Array, center: Vector2, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(shape.size())
	for i in shape.size():
		out[i] = center + shape[i] * s
	return out


## A suit symbol about 2 * `size` tall; `flip` turns it upside down.
func _suit_shape(suit: int, center: Vector2, size: float, color: Color, flip := false) -> void:
	var s := -size if flip else size
	match suit:
		0:
			draw_colored_polygon(_place(heart_shape, center, s), color)
		1:
			draw_colored_polygon(_place(diamond_shape, center, s), color)
		2:
			draw_colored_polygon(_place(spade_shape, center, s), color)
			draw_colored_polygon(_place(PackedVector2Array(STEM), center, s), color)
		3:
			for lobe: Vector3 in CLUB_LOBES:
				draw_circle(center + Vector2(lobe.x, lobe.y) * s, lobe.z * size, color, true, -1.0, true)
			draw_circle(center + Vector2(0, -0.08) * s, 0.2 * size, color, true, -1.0, true)
			draw_colored_polygon(_place(PackedVector2Array(STEM), center, s), color)


func _glow_style(amount: float, halo: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_corner_radius_all(10)
	style.anti_aliasing = true
	if halo:
		style.shadow_color = Color(GOLD, 0.6 * amount)
		style.shadow_size = 16
	else:
		style.border_color = Color(GOLD_LIGHT, amount)
		style.set_border_width_all(3)
		style.set_expand_margin_all(2)
	return style


# --- Drawing cards ---------------------------------------------------------------------------

## Draws a card centered on `pos`. `face` goes from 0 (back up) to 1 (face up); in between the
## card is caught turning over.
func _draw_card(card: int, pos: Vector2, rot: float, zoom: float, face: float, dim := false, glow := 0.0) -> void:
	var squash := absf(face * 2.0 - 1.0)
	if squash < 0.03:
		return
	var t := Transform2D(rot, Vector2(zoom * squash, zoom), 0.0, pos)
	draw_set_transform_matrix(t)
	var rect := Rect2(-CARD / 2.0, CARD)
	if glow > 0.0:
		draw_style_box(_glow_style(glow, true), rect)
	if face >= 0.5:
		_draw_face(card, t)
	else:
		draw_style_box(shadow_style, rect)
		draw_texture_rect(back_texture, rect, false)
	if dim:
		draw_style_box(dim_style, rect)
	if glow > 0.0:
		draw_style_box(_glow_style(glow, false), rect)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_face(card: int, t: Transform2D) -> void:
	draw_style_box(face_style, Rect2(-CARD / 2.0, CARD))
	var suit := card / 10
	var rank := card % 10
	var ink := CARD_RED if suit < 2 else CARD_BLACK
	# Corner indices; the bottom one upside down.
	for turned in 2:
		draw_set_transform_matrix(t * Transform2D(PI * turned, Vector2.ZERO))
		_text(RANK_LABELS[rank], Vector2(-CARD.x / 2.0 + 12, -CARD.y / 2.0 + 16), 19, ink, serif)
		_suit_shape(suit, Vector2(-CARD.x / 2.0 + 12, -CARD.y / 2.0 + 33), 6.5, ink)
	draw_set_transform_matrix(t)
	if rank == ACE:
		draw_arc(Vector2.ZERO, 32, 0, TAU, 48, Color(ink, 0.18), 1.5, true)
		draw_arc(Vector2.ZERO, 36, 0, TAU, 48, Color(ink, 0.1), 1.0, true)
		_suit_shape(suit, Vector2.ZERO, 24, ink)
	elif rank >= QUEEN and rank <= KING:
		_draw_figure(suit, rank, ink, t)
	else:
		var count := rank + 2 if rank < QUEEN else 7
		for p: Vector2 in PIPS[count]:
			_suit_shape(suit, Vector2(p.x * 19.0, p.y * 36.0), 10.0, ink, p.y > 0.01)


## King, jack or queen: a framed double-headed figure, like on real cards.
func _draw_figure(suit: int, rank: int, ink: Color, t: Transform2D) -> void:
	var frame := Rect2(-27, -52, 54, 104)
	draw_rect(frame, Color("fdf1d8"))
	for turned in 2:
		draw_set_transform_matrix(t * Transform2D(PI * turned, Vector2.ZERO))
		_draw_figure_half(suit, rank, ink)
	draw_set_transform_matrix(t)
	draw_line(Vector2(-27, 0), Vector2(27, 0), Color(ink, 0.5), 1.0)
	draw_rect(frame, Color(ink, 0.8), false, 1.2)


func _draw_figure_half(suit: int, rank: int, ink: Color) -> void:
	var robe: Color = ROBES[suit]
	var skin := Color("f6d9b8")
	var dark := Color("2a2230")
	var grey := Color("e6e0d4")
	# Hair behind the head.
	match rank:
		QUEEN:
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -36), Vector2(10, -36), Vector2(12, -18), Vector2(-12, -18)]), Color("d9a23a"))
		JACK:
			draw_circle(Vector2(0, -30), 9.5, Color("7a4a26"), true, -1.0, true)
		KING:
			draw_circle(Vector2(0, -30), 9.5, grey, true, -1.0, true)
	# Robe with a white collar and gold trim.
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -19), Vector2(14, -19), Vector2(24, 0), Vector2(-24, 0)]), robe)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -19), Vector2(-9, -19), Vector2(-15, 0), Vector2(-24, 0)]), robe.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -19), Vector2(6, -19), Vector2(0, -8)]), Color("fbf5e6"))
	draw_line(Vector2(0, -8), Vector2(0, 0), GOLD, 2.5)
	draw_line(Vector2(-20, -6), Vector2(20, -6), Color(GOLD_DEEP, 0.9), 1.5)
	# Face.
	draw_circle(Vector2(0, -28), 8.0, skin, true, -1.0, true)
	draw_circle(Vector2(-3, -29), 1.1, dark, true, -1.0, true)
	draw_circle(Vector2(3, -29), 1.1, dark, true, -1.0, true)
	match rank:
		KING:
			draw_colored_polygon(PackedVector2Array([Vector2(-6.5, -25), Vector2(6.5, -25), Vector2(4, -19.5), Vector2(0, -18), Vector2(-4, -19.5)]), grey)
			draw_line(Vector2(-2, -25.5), Vector2(2, -25.5), Color("b04a44"), 1.2)
			var crown := PackedVector2Array([Vector2(-9, -34), Vector2(9, -34), Vector2(10, -46), Vector2(5, -39),
					Vector2(0, -48), Vector2(-5, -39), Vector2(-10, -46)])
			draw_colored_polygon(crown, GOLD)
			draw_line(Vector2(-9, -34.5), Vector2(9, -34.5), GOLD_DEEP, 1.5)
			draw_circle(Vector2(0, -48), 1.8, CARD_RED, true, -1.0, true)
			draw_circle(Vector2(0, -37), 1.4, Color("2c4a9a"), true, -1.0, true)
			draw_line(Vector2(18, -2), Vector2(18, -38), GOLD_DEEP, 2.5)
			draw_circle(Vector2(18, -40), 3.5, GOLD, true, -1.0, true)
		QUEEN:
			draw_line(Vector2(-2, -24.5), Vector2(2, -24.5), Color("c0404a"), 1.4)
			draw_colored_polygon(PackedVector2Array([Vector2(-7, -34), Vector2(7, -34), Vector2(5, -39), Vector2(0, -42), Vector2(-5, -39)]), GOLD)
			draw_circle(Vector2(0, -38), 1.4, CARD_RED, true, -1.0, true)
			# A flower in her hand.
			draw_line(Vector2(18, -4), Vector2(18, -26), Color("2f7d3a"), 1.8)
			for i in 5:
				draw_circle(Vector2(18, -30) + Vector2.from_angle(i * TAU / 5.0) * 3.2, 2.6, robe.lightened(0.35), true, -1.0, true)
			draw_circle(Vector2(18, -30), 1.8, GOLD, true, -1.0, true)
		JACK:
			draw_line(Vector2(-2, -24.5), Vector2(2, -24.5), Color("b04a44"), 1.2)
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -32), Vector2(10, -32), Vector2(9, -38), Vector2(0, -41), Vector2(-8, -39)]), robe.darkened(0.45))
			draw_polyline(PackedVector2Array([Vector2(6, -39), Vector2(11, -44), Vector2(17, -47), Vector2(22, -46)]), grey, 2.0, true)
			draw_line(Vector2(18, 0), Vector2(18, -40), Color("6b4a2a"), 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(18, -41), Vector2(24, -45), Vector2(24, -34), Vector2(18, -36)]), Color("c3ccd6"))
	_suit_shape(suit, Vector2(-19, -43), 5.0, ink)


# --- Drawing ---------------------------------------------------------------------------------

func _draw() -> void:
	if art_kind != "":
		_draw_art()
		return
	if rendering_icon:
		if icon_felt != null:
			_draw_icon()
		return
	if phase == "title":
		_draw_title()
	else:
		_draw_table()
		_draw_nameplates()
		_draw_cards()
		_draw_hud()
		_draw_message()
		_draw_banner()
	_draw_effects(false)
	if phase == "round_end" and phase_t >= RESULT_DELAY:
		_draw_result()
	_draw_effects(true)
	if menu_open:
		_draw_menu()
	if rules_open:
		_draw_rules()


func _draw_table() -> void:
	for ring in [[Vector2(304, 194), Color(GOLD, 0.14), 2.0], [Vector2(294, 184), Color(1, 1, 1, 0.05), 1.0]]:
		var radius: Vector2 = ring[0]
		var points := PackedVector2Array()
		for i in 97:
			var a := i * TAU / 96.0
			points.append(Vector2(640, 330) + Vector2(cos(a) * radius.x, sin(a) * radius.y))
		draw_polyline(points, ring[1], ring[2], true)
	_text("Sueca", Vector2(640, 330), 64, Color(1, 1, 1, 0.045), serif)


func _draw_cards() -> void:
	var order := range(40)
	order.sort_custom(func(a: int, b: int) -> bool: return vis[a].z < vis[b].z)
	var wi := _trick_winner_index()
	var winner_card: int = trick[wi].card if wi >= 0 else -1
	var selected := _selected()
	for c: int in order:
		var v: Dictionary = vis[c]
		var pos: Vector2 = v.pos
		if pos.x < -120 or pos.x > SCREEN.x + 120 or pos.y < -120 or pos.y > SCREEN.y + 120:
			continue
		var rot: float = v.rot
		if wiggle.has(c):
			rot += sin(wiggle[c] * 45.0) * 0.1 * wiggle[c] / 0.4
		var glow := 0.0
		if c == winner_card:
			if phase == "trick":
				glow = 0.65 + 0.35 * sin(clock * 9.0)
			elif trick.size() >= 2:
				glow = 0.35
		elif c == selected and c in legal_now:
			glow = 0.55
		elif trump_shown and c == trump_card:
			glow = 0.35 + 0.2 * sin(clock * 3.0)
		var dim: bool = not legal_now.is_empty() and c in hands[0] and not c in legal_now
		_draw_card(c, pos, rot, v.zoom, v.face, dim, glow)


func _draw_nameplates() -> void:
	for seat in 4:
		var center: Vector2 = NAME_POS[seat]
		var rect := Rect2(center - Vector2(58, 15), Vector2(128, 30))
		var col := US if seat % 2 == 0 else THEM
		var active := phase == "play" and turn == seat
		if active:
			var pulse := 0.5 + 0.5 * sin(clock * 5.0)
			_box(rect.grow(4.0 + 2.0 * pulse), Color(GOLD, 0.16 + 0.18 * pulse), Color(0, 0, 0, 0), 19, 0.0)
		_box(rect, PANEL, GOLD if active else Color(col, 0.6), 15, 2.0 if active else 1.5)
		var label := tr("name_%d" % seat)
		var avatar := Vector2(rect.position.x + 2, center.y)
		draw_circle(avatar, 19, col.darkened(0.45), true, -1.0, true)
		draw_arc(avatar, 19, 0, TAU, 40, GOLD if active else col, 2.0, true)
		_text(label.left(1), avatar, 18, INK, serif)
		if active and seat != 0:
			label += ".".repeat(int(clock * 3.0) % 4)
		_text_left(label, Vector2(rect.position.x + 28, center.y), 16, GOLD_LIGHT if active else INK, bold)
		if seat == dealer:
			# Small deck icon: this player dealt.
			var d := Vector2(rect.end.x - 18, center.y)
			for k in 2:
				var r := Rect2(d + Vector2(-6 + k * 4, -8 - k * 2), Vector2(11, 15))
				_box(r, Color("9e1a30"), Color("f7f1e3"), 2, 1.0)


func _draw_hud() -> void:
	# Score.
	_box(SCORE_RECT, PANEL, Color(GOLD, 0.45), 14, 1.5, 10)
	var x := SCORE_RECT.position.x
	var y := SCORE_RECT.position.y
	_text_left(tr("hand_n") % maxi(hand_number, 1), Vector2(x + 16, y + 18), 12, MUTED, bold)
	_text(tr("points"), Vector2(x + 166, y + 18), 11, MUTED, bold)
	_text(tr("games"), Vector2(x + 228, y + 18), 11, MUTED, bold)
	draw_line(Vector2(x + 12, y + 69), Vector2(SCORE_RECT.end.x - 12, y + 69), Color(1, 1, 1, 0.08), 1.0)
	for team in 2:
		var ry := y + 50 + team * 38
		var col := US if team == 0 else THEM
		draw_circle(Vector2(x + 22, ry), 6, col, true, -1.0, true)
		_text_left(tr("us" if team == 0 else "them"), Vector2(x + 36, ry), 18, INK, bold)
		var pulse: float = score_pulse[team]
		_text(str(points[team]), Vector2(x + 166, ry), int(22 + 9 * pulse), col.lerp(Color.WHITE, pulse * 0.6), bold)
		for g in GAMES_TO_WIN:
			var p := Vector2(x + 204 + g * 16, ry)
			if g < games[team]:
				draw_circle(p, 6, GOLD, true, -1.0, true)
				draw_circle(p + Vector2(-1.5, -1.5), 2, GOLD_LIGHT, true, -1.0, true)
			else:
				draw_arc(p, 5.5, 0, TAU, 24, Color(GOLD, 0.45), 1.5, true)
	# Trump.
	_box(TRUMP_RECT, PANEL, Color(GOLD, 0.45), 14, 1.5, 10)
	x = TRUMP_RECT.position.x
	y = TRUMP_RECT.position.y
	_text_left(tr("trump"), Vector2(x + 16, y + 16), 11, MUTED, bold)
	if trump >= 0:
		var c := Vector2(x + 36, y + 43)
		draw_circle(c, 16, Color("fbf8f1"), true, -1.0, true)
		_suit_shape(trump, c, 10, CARD_RED if trump < 2 else CARD_BLACK)
		_text_left(tr(SUIT_KEYS[trump]), Vector2(x + 62, y + 42), 24, GOLD_LIGHT, serif)
	else:
		_text_left("—", Vector2(x + 30, y + 42), 22, MUTED, serif)
	_draw_gear(MENU_BUTTON.get_center(), hover_button == "menu")
	# The last trick, small, with its winning card lit.
	if not last_trick.is_empty():
		_box(LAST_RECT, PANEL, Color(GOLD, 0.3), 12, 1.0, 8)
		_text_left(tr("last_trick"), Vector2(LAST_RECT.position.x + 14, LAST_RECT.position.y + 16), 12, MUTED, bold)
		for i in last_trick.size():
			var p := LAST_RECT.position + Vector2(40 + i * 51, 72)
			_draw_card(last_trick[i].card, p, 0.0, 0.42, 1.0, false, 0.8 if i == last_winner else 0.0)


func _draw_gear(center: Vector2, hot: bool) -> void:
	draw_circle(center, 22, Color(0, 0, 0, 0.35 if hot else 0.22), true, -1.0, true)
	var points := PackedVector2Array()
	for i in 48:
		var a := i * TAU / 48.0
		var tooth := fmod(float(i), 6.0) < 3.0
		points.append(center + Vector2.from_angle(a) * (13.0 if tooth else 10.0))
	draw_colored_polygon(points, GOLD_LIGHT if hot else GOLD)
	draw_circle(center, 5, Color(0.02, 0.1, 0.06), true, -1.0, true)


func _draw_message() -> void:
	if message == "":
		return
	var text := tr(message)
	if message_arg != "":
		text = text % message_arg
	var pop := _back_out(clampf(message_t / 0.3, 0.0, 1.0))
	var col := INK
	if message == "your_turn":
		col = GOLD_LIGHT.lerp(Color.WHITE, 0.3 + 0.3 * sin(clock * 4.0))
	elif message == "must_follow":
		col = Color("ffb4a8")
	_text(text, Vector2(640, 524), int(lerpf(15.0, 21.0, pop)), col, serif, true)


## The trump suit announced in the middle of the table after the deal.
func _draw_banner() -> void:
	if phase != "reveal" or trump < 0:
		return
	var s := _back_out(clampf(phase_t / 0.35, 0.0, 1.0))
	var alpha := clampf((1.7 - phase_t) / 0.3, 0.0, 1.0)
	draw_set_transform(Vector2(640, 330), 0.0, Vector2(s, s))
	_box(Rect2(-160, -72, 320, 144), Color(0.01, 0.07, 0.04, 0.85 * alpha), Color(GOLD, alpha), 18, 2.0, 16)
	_text(tr("trump"), Vector2(0, -44), 16, Color(MUTED, MUTED.a * alpha), bold)
	draw_circle(Vector2(-78, 14), 30, Color(Color("fbf8f1"), alpha), true, -1.0, true)
	_suit_shape(trump, Vector2(-78, 14), 19, Color(CARD_RED if trump < 2 else CARD_BLACK, alpha))
	_text(tr(SUIT_KEYS[trump]), Vector2(28, 14), 44, Color(GOLD_LIGHT, alpha), serif, true)
	draw_set_transform(Vector2.ZERO)


func _draw_effects(confetti: bool) -> void:
	for p in particles:
		if (p.kind == "confetti") != confetti:
			continue
		var fade := clampf((p.life - p.age) / 0.5, 0.0, 1.0)
		var col: Color = p.color
		if confetti:
			draw_set_transform(p.pos, p.rot, Vector2(1.0, maxf(absf(cos(p.age * 6.0 + p.rot)), 0.2)))
			draw_rect(Rect2(-p.size / 2.0, -p.size / 4.0, p.size, p.size / 2.0), Color(col, fade))
			draw_set_transform(Vector2.ZERO)
		else:
			_star(p.pos, p.size * (1.0 - p.age / p.life * 0.6), Color(col.lightened(0.3), fade))
	if confetti:
		return
	for f in floats:
		var k: float = f.age / f.life
		var pop := _back_out(clampf(f.age / 0.25, 0.0, 1.0))
		var col: Color = f.color
		_text(f.text, f.pos + Vector2(0, -50.0 * k), int(f.size * (0.6 + 0.4 * pop)), Color(col, 1.0 - k * k), serif, true)


func _draw_title() -> void:
	# Four aces fanned out above the logo.
	var pivot := Vector2(640, 394)
	for i in 4:
		var a := (i - 1.5) * 0.3 + sin(clock * 0.9 + i) * 0.025
		_draw_card(TITLE_CARDS[i], pivot + Vector2(0, -172).rotated(a), a, 1.22, 1.0)
	_draw_logo(Vector2(640, 460), 1.0)
	# Twinkles around the logo.
	for i in 8:
		var p := Vector2(640 + sin(i * 2.4) * 290, 450 + cos(i * 1.7) * 60)
		var k := sin(clock * 2.2 + i * 1.3)
		if k > 0.0:
			_star(p, 9.0 * k, Color(GOLD_LIGHT, k))
	_text(tr("subtitle"), Vector2(640, 540), 18, MUTED, font)
	var buttons := _buttons()
	for key: String in buttons:
		if key == "menu":
			continue
		var label := tr(key)
		if key == "play" and _in_progress():
			label = tr("continue")
		elif key == "new_match" and confirm_new:
			label = tr("sure")
		_button(buttons[key], label, key == "play", hover_button == key)
	if _in_progress():
		_text("%s %d  ·  %s %d" % [tr("us"), games[0], tr("them"), games[1]], Vector2(640, 700), 13, MUTED, bold)
	_draw_gear(MENU_BUTTON.get_center(), hover_button == "menu")


## "Jogo da Sueca!" in gold, with "Sueca!" centered on `center`.
func _draw_logo(center: Vector2, s: float) -> void:
	_text_fx("Jogo da", center + Vector2(0, -78) * s, int(44 * s), GOLD_LIGHT, int(3 * s))
	_text_fx("Sueca!", center, int(122 * s), GOLD, int(7 * s))


func _draw_result() -> void:
	var t := clampf((phase_t - RESULT_DELAY) / 0.35, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.45 * t))
	var s := _back_out(t)
	var center := RESULT_RECT.get_center()
	draw_set_transform(center, 0.0, Vector2(s, s))
	_box(Rect2(-RESULT_RECT.size / 2.0, RESULT_RECT.size), Color("0b2217"), GOLD, 20, 2.0, 22)
	var winner: int = result.winner
	var title := "draw_hand"
	var title_color := INK
	if winner == 0:
		title = "won_match" if match_over else "won_hand"
		title_color = GOLD_LIGHT
	elif winner == 1:
		title = "lost_match" if match_over else "lost_hand"
		title_color = Color("ffb4a8")
	_text(tr(title), Vector2(0, -150), 38, title_color, serif, true)
	if winner >= 0:
		var kind: String = result.kind
		if kind == "simple" and winner == 1:
			kind = "simple_loss"
		_text(tr(kind), Vector2(0, -104), 22 if kind.begins_with("simple") else 28, MUTED if kind.begins_with("simple") else GOLD, serif, not kind.begins_with("simple"))
	else:
		_text(tr("draw_note"), Vector2(0, -104), 18, MUTED, font)
	# Points.
	_text(tr("us"), Vector2(-180, -34), 18, US, bold)
	_text(str(points[0]), Vector2(-80, -34), 58, US, serif, true)
	_text("–", Vector2(0, -34), 40, MUTED, serif)
	_text(str(points[1]), Vector2(80, -34), 58, THEM, serif, true)
	_text(tr("them"), Vector2(180, -34), 18, THEM, bold)
	_text(tr("tricks_n") % tricks[0], Vector2(-80, 14), 13, MUTED, font)
	_text(tr("tricks_n") % tricks[1], Vector2(80, 14), 13, MUTED, font)
	if winner >= 0:
		var gained: int = result.gained
		var key := ("games_us_" if winner == 0 else "games_them_") + ("1" if gained == 1 else "n")
		_text(tr(key) % gained if gained > 1 else tr(key), Vector2(0, 52), 20, GOLD_LIGHT, bold)
	# Games so far.
	for team in 2:
		var x := -150.0 if team == 0 else 30.0
		_text_left(tr("us" if team == 0 else "them"), Vector2(x, 92), 14, US if team == 0 else THEM, bold)
		for g in GAMES_TO_WIN:
			var p := Vector2(x + 62 + g * 18, 92)
			if g < games[team]:
				draw_circle(p, 6.5, GOLD, true, -1.0, true)
			else:
				draw_arc(p, 6, 0, TAU, 24, Color(GOLD, 0.45), 1.5, true)
	if not match_over:
		_text(tr("match_to") % GAMES_TO_WIN, Vector2(0, 118), 12, MUTED, font)
	var button: Rect2 = _buttons().get("next", Rect2(RESULT_RECT.get_center().x - 115, RESULT_RECT.end.y - 76, 230, 54))
	_button(Rect2(button.position - center, button.size), tr("new_match") if match_over else tr("next_hand"), true, hover_button == "next")
	draw_set_transform(Vector2.ZERO)


func _draw_menu() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.6))
	_box(MENU_RECT, Color("0b2217"), GOLD, 18, 2.0, 18)
	var x := MENU_RECT.position.x + 30
	var right := MENU_RECT.end.x - 30
	var y := MENU_RECT.position.y
	_text_left(tr("settings"), Vector2(x, y + 38), 26, GOLD, serif)
	var rows := _menu_rows()
	var close: Rect2 = rows.close
	var hot_close := close.has_point(mouse)
	var c := close.get_center()
	draw_line(c + Vector2(-9, -9), c + Vector2(9, 9), GOLD_LIGHT if hot_close else INK, 2.5, true)
	draw_line(c + Vector2(9, -9), c + Vector2(-9, 9), GOLD_LIGHT if hot_close else INK, 2.5, true)
	for key in ["sound", "speed", "rules"]:
		var rect: Rect2 = rows[key]
		_box(rect, Color(1, 1, 1, 0.09 if rect.has_point(mouse) else 0.04), Color(GOLD, 0.25), 10, 1.0)
		_text_left(tr(key), Vector2(rect.position.x + 16, rect.get_center().y), 17, INK, bold)
	var sw := Rect2(rows.sound.end.x - 70, rows.sound.get_center().y - 13, 54, 26)
	_box(sw, Color("1f9d57") if sound_on else Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 13, 0.0)
	draw_circle(Vector2(sw.end.x - 13 if sound_on else sw.position.x + 13, sw.get_center().y), 10, Color.WHITE, true, -1.0, true)
	_text_right("‹  " + tr("speed_fast" if fast else "speed_normal") + "  ›", Vector2(rows.speed.end.x - 16, rows.speed.get_center().y), 17, GOLD_LIGHT, bold)
	_text_right("›", Vector2(rows.rules.end.x - 16, rows.rules.get_center().y), 22, GOLD_LIGHT, bold)

	_text_left(tr("statistics"), Vector2(x, y + 264), 20, GOLD, serif)
	var lines := ["matches", "match_wins", "hands", "hand_wins", "capotes", "bandeiras", "best_hand"]
	for i in lines.size():
		var ly := y + 296 + i * 24
		_text_left(tr(lines[i]), Vector2(x, ly), 15, MUTED, font)
		_text_right(str(stats[lines[i]]), Vector2(right, ly), 15, INK, bold)
		if i < lines.size() - 1:
			draw_line(Vector2(x, ly + 12), Vector2(right, ly + 12), Color(1, 1, 1, 0.06), 1.0)

	var reset: Rect2 = rows.new_match
	var hot := reset.has_point(mouse)
	_box(reset, Color("7a1a1a") if confirm_new else Color(1, 1, 1, 0.1 if hot else 0.05), Color(GOLD, 0.5), 10, 1.0)
	_text(tr("confirm_new") if confirm_new else tr("new_match"), reset.get_center(), 16, INK, bold)
	_text(tr("keys_help"), Vector2(MENU_RECT.get_center().x, y + 566), 12, MUTED, font)


func _draw_rules() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.65))
	_box(RULES_RECT, Color("0b2217"), GOLD, 18, 2.0, 18)
	var x := RULES_RECT.position.x + 64
	var width := RULES_RECT.size.x - 118
	var y := RULES_RECT.position.y + 44
	_text(tr("rules_title"), Vector2(RULES_RECT.get_center().x, y), 32, GOLD, serif, true)
	var close := Vector2(RULES_RECT.end.x - 38, RULES_RECT.position.y + 38)
	draw_line(close + Vector2(-9, -9), close + Vector2(9, 9), INK, 2.5, true)
	draw_line(close + Vector2(9, -9), close + Vector2(-9, 9), INK, 2.5, true)
	y += 42
	var size := 16
	for i in range(1, 8):
		var text := tr("rules_%d" % i)
		_suit_shape((i - 1) % 4, Vector2(x - 22, y + 11), 7.0, GOLD)
		draw_multiline_string(font, Vector2(x, y + font.get_ascent(size)), text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, INK)
		y += font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y + 13
	_text_left(tr("rules_cards"), Vector2(x, y + 8), 15, MUTED, bold)


# --- Icon ------------------------------------------------------------------------------------

## Draws the game icon (512x512) on screen, saves it to icon.png and quits.
func _render_icon() -> void:
	rendering_icon = true
	felt.visible = false
	var gradient := Gradient.new()
	gradient.set_color(0, Color("24864f"))
	gradient.set_color(1, Color("052a17"))
	icon_felt = GradientTexture2D.new()
	icon_felt.gradient = gradient
	icon_felt.fill = GradientTexture2D.FILL_RADIAL
	icon_felt.fill_from = Vector2(0.5, 0.4)
	icon_felt.fill_to = Vector2(1.15, 1.0)
	icon_felt.width = 256
	icon_felt.height = 256
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, 512, 512))
	img.convert(Image.FORMAT_RGBA8)
	# Round the corners.
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
	draw_texture_rect(icon_felt, Rect2(0, 0, 512, 512), false)
	var pivot := Vector2(256, 336)
	var cards := [8, 29, 17]  # 7 of hearts, ace of spades, king of diamonds
	for i in 3:
		var a := (i - 1) * 0.34
		_draw_card(cards[i], pivot + Vector2(0, -150).rotated(a), a, 1.5, 1.0)
	_draw_logo(Vector2(256, 424), 0.94)
	_box(Rect2(7, 7, 498, 498), Color(0, 0, 0, 0), GOLD, 86, 7.0)


# --- Store art -------------------------------------------------------------------------------

## Renders the Store display images into store-listing/ (each at full size and at half size)
## and quits. Each one is drawn by its own copy of this script, scaled 2x inside a SubViewport.
func _render_store() -> void:
	rendering_icon = true
	var folder := ProjectSettings.globalize_path("res://store-listing")
	for spec in [["BoxArt", Vector2(1080, 1080), "box"], ["PosterArt", Vector2(720, 1080), "poster"],
			["HeroArt", Vector2(1920, 1080), "hero"]]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(spec[1] * 2.0)
		viewport.msaa_2d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var art: Node2D = get_script().new()
		art.art_kind = spec[2]
		art.art_size = spec[1]
		art.rendering_icon = true
		art.scale = Vector2(2, 2)
		viewport.add_child(art)
		add_child(viewport)
		for i in 4:
			await RenderingServer.frame_post_draw
		var img := viewport.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		for half in 2:
			img.save_png("%s/%s.%dx%d.png" % [folder, spec[0], img.get_width(), img.get_height()])
			img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
		viewport.queue_free()
	get_tree().quit()


## Four aces fanned out around `pivot`.
func _draw_fan(cards: Array, pivot: Vector2, radius: float, zoom: float, spread: float) -> void:
	for i in cards.size():
		var a := (i - (cards.size() - 1) / 2.0) * spread
		_draw_card(cards[i], pivot + Vector2(0, -radius).rotated(a), a, zoom, 1.0)


func _draw_twinkles(center: Vector2, spread: Vector2, size: float) -> void:
	for i in 9:
		var p := center + Vector2(sin(i * 2.4) * spread.x, cos(i * 1.7) * spread.y)
		var k := 0.4 + 0.6 * absf(sin(i * 1.9))
		_star(p, size * k, Color(GOLD_LIGHT, k))


func _draw_art() -> void:
	match art_kind:
		"box":
			_draw_fan(TITLE_CARDS, Vector2(540, 660), 310, 2.3, 0.3)
			_draw_twinkles(Vector2(540, 790), Vector2(450, 110), 16)
			_draw_logo(Vector2(540, 820), 1.85)
			_text(tr("subtitle"), Vector2(540, 972), 34, MUTED, font)
		"poster":
			_draw_fan(TITLE_CARDS, Vector2(360, 560), 250, 1.8, 0.3)
			_draw_twinkles(Vector2(360, 690), Vector2(300, 90), 12)
			_draw_logo(Vector2(360, 720), 1.3)
			_text(tr("subtitle"), Vector2(360, 820), 24, MUTED, font)
			_draw_fan([7, 26, 15], Vector2(360, 1230), 280, 1.45, 0.32)  # king, jack and queen
		"hero":
			_draw_fan(TITLE_CARDS, Vector2(600, 760), 330, 2.3, 0.3)
			_draw_twinkles(Vector2(1320, 500), Vector2(420, 120), 16)
			_draw_logo(Vector2(1320, 540), 1.8)
			_text(tr("subtitle"), Vector2(1320, 690), 36, MUTED, font)
