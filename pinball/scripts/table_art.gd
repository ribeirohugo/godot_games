extends Node2D
## Draws the playfield artwork: cabinet, printed art, and the insert lights.
## Reads game state from main.gd (`game`) to decide which lights are on.

var game  # main.gd node, set before this is added to the tree
var clock := 0.0
var stars := PackedVector2Array()
var font: Font

var playfield := PackedVector2Array([
	Vector2(20, 800), Vector2(20, 110), Vector2(45, 55), Vector2(100, 25),
	Vector2(380, 25), Vector2(435, 50), Vector2(460, 100), Vector2(460, 800),
])
var left_apron := PackedVector2Array([Vector2(20, 592), Vector2(158, 695), Vector2(158, 800), Vector2(20, 800)])
var right_apron := PackedVector2Array([Vector2(420, 592), Vector2(322, 695), Vector2(322, 800), Vector2(420, 800)])


func _ready() -> void:
	font = ThemeDB.fallback_font
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		stars.append(Vector2(rng.randf_range(35, 410), rng.randf_range(40, 580)))


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _draw() -> void:
	_draw_cabinet()
	_draw_playfield()
	_draw_aprons()
	if game != null:
		_draw_lights()


func _draw_cabinet() -> void:
	draw_rect(Rect2(0, 0, 480, 800), Color(0.24, 0.12, 0.05))
	for i in 14:
		var y := i * 60.0
		draw_line(Vector2(0, y), Vector2(480, y + 25), Color(0.19, 0.09, 0.035), 3)


func _draw_playfield() -> void:
	var colors := PackedColorArray()
	for p in playfield:
		colors.append(Color(0.2, 0.05, 0.32).lerp(Color(0.02, 0.04, 0.16), p.y / 800.0))
	draw_polygon(playfield, colors)

	# Sunburst behind the bumpers.
	var center := Vector2(230, 270)
	for i in 18:
		var a := i * TAU / 18.0
		draw_colored_polygon(PackedVector2Array([
			center, center + Vector2.from_angle(a) * 200, center + Vector2.from_angle(a + TAU / 36.0) * 200,
		]), Color(0.65, 0.35, 1.0, 0.07))

	for i in stars.size():
		var twinkle := 0.35 + 0.35 * sin(clock * 2.0 + i)
		draw_circle(stars[i], 1.3, Color(1, 1, 1, twinkle))

	# Shooter lane stripe with chevrons pointing up.
	draw_rect(Rect2(420, 170, 40, 610), Color(0, 0, 0, 0.25))
	for i in 5:
		var y := 330.0 + i * 90.0
		var alpha := 0.15 + 0.6 * maxf(0.0, sin(clock * 5.0 - i * 0.8))
		draw_polyline(PackedVector2Array([Vector2(430, y + 8), Vector2(440, y), Vector2(450, y + 8)]),
			Color(1, 0.6, 0.2, alpha), 3.0)

	# Table name.
	draw_string_outline(font, Vector2(0, 545), "STARLIGHT", HORIZONTAL_ALIGNMENT_CENTER, 460, 34, 8, Color(0.1, 0, 0.2))
	draw_string(font, Vector2(0, 545), "STARLIGHT", HORIZONTAL_ALIGNMENT_CENTER, 460, 34, Color(1, 0.45, 0.9))

	# Slots where the drop targets sink.
	for x in game.TARGET_X if game != null else []:
		draw_rect(Rect2(x - 19, game.TARGET_Y - 8, 38, 16), Color(0, 0, 0, 0.55))


func _draw_aprons() -> void:
	for apron in [left_apron, right_apron]:
		var colors := PackedColorArray()
		for p in apron:
			colors.append(Color(0.2, 0.21, 0.25).lerp(Color(0.08, 0.08, 0.1), (p.y - 590.0) / 210.0))
		draw_polygon(apron, colors)
	# The drain between the flippers.
	draw_rect(Rect2(158, 740, 164, 60), Color(0, 0, 0, 0.35))

	var text_color := Color(0.75, 0.78, 0.85)
	draw_string(font, Vector2(24, 735), "SPACE  LAUNCH", HORIZONTAL_ALIGNMENT_CENTER, 134, 11, text_color)
	draw_string(font, Vector2(24, 755), "ARROWS  FLIP", HORIZONTAL_ALIGNMENT_CENTER, 134, 11, text_color)
	draw_string(font, Vector2(24, 775), "UP  NUDGE", HORIZONTAL_ALIGNMENT_CENTER, 134, 11, text_color)
	draw_string(font, Vector2(326, 790), "POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_color)


func _draw_lights() -> void:
	# Top lane rollovers.
	for i in 3:
		_insert(Vector2(game.LANE_X[i], 128), 8, Color(1, 0.9, 0.2), game.lane_lit[i])

	# Arrow pointing at the drop targets.
	var arrow_on := fmod(clock, 0.8) < 0.4
	_arrow(Vector2(240, 470), Color(1, 0.5, 0.1), arrow_on)

	# Score multiplier lights.
	for i in 4:
		var pos := Vector2(180 + i * 40, 585)
		var level := i + 2
		_insert(pos, 12, Color(0.3, 0.8, 1), game.multiplier >= level)
		draw_string(font, pos + Vector2(-12, 4), "%dx" % level, HORIZONTAL_ALIGNMENT_CENTER, 24, 11, Color.WHITE)

	# Shoot again light (blinks while ball save is active).
	var save_on: bool = game.ball_save > 0.0 and fmod(clock, 0.4) < 0.25
	_insert(Vector2(240, 768), 11, Color(1, 0.15, 0.2), save_on)
	draw_string(font, Vector2(190, 794), "SHOOT AGAIN", HORIZONTAL_ALIGNMENT_CENTER, 100, 9, Color(1, 1, 1, 0.7))

	# Plunger and power meter.
	var charge: float = game.charge
	draw_rect(Rect2(426, 781 + charge * 12, 28, 5), Color(0.8, 0.82, 0.88))
	draw_rect(Rect2(395, 700, 12, 80), Color(0, 0, 0, 0.6))
	if charge > 0.0:
		draw_rect(Rect2(396, 779 - 78 * charge, 10, 78 * charge), Color(0.3, 1, 0.3).lerp(Color(1, 0.2, 0.1), charge))


## A round playfield light: dim when off, bright with a halo when on.
func _insert(pos: Vector2, radius: float, color: Color, lit: bool) -> void:
	if lit:
		draw_circle(pos, radius * 2.0, Color(color, 0.18))
		draw_circle(pos, radius, color)
		draw_circle(pos - Vector2(radius, radius) * 0.3, radius * 0.4, Color(1, 1, 1, 0.8))
	else:
		draw_circle(pos, radius, color.darkened(0.75))
	draw_arc(pos, radius, 0, TAU, 24, Color(0, 0, 0, 0.6), 1.5)


func _arrow(pos: Vector2, color: Color, lit: bool) -> void:
	var shape := PackedVector2Array([pos + Vector2(0, -14), pos + Vector2(13, 10), pos + Vector2(-13, 10)])
	if lit:
		draw_circle(pos, 22, Color(color, 0.15))
	draw_colored_polygon(shape, color if lit else color.darkened(0.75))
