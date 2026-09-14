extends Node2D
## WebPlatinum studio intro shown before the game. Any key, click or touch skips it.
## Lives in the root common/intro folder; _config.bat copies it into every game.
## A game uses it by setting run/main_scene to res://common/intro/intro.tscn.
## The text follows common/design/intro_text_design.png.
## Sizes below are for a 1000x760 screen; everything scales to fit the game's screen.

const TITLE := "WebPlatinum"
const TITLE_SIZE := 76
const TITLE_SPACING := -2.0
const WEBSITE := "wplatinum.com"
const WEBSITE_SIZE := 21
const WEBSITE_COLOR := Color(0.62, 0.72, 0.84, 0.7)

# Layout, as offsets from the middle of the screen.
const LOGO_OFFSET := -100.0
const LOGO_SIZE := 300.0
const TITLE_OFFSET := 150.0
const WEBSITE_OFFSET := 204.0
## Area the intro needs; it is scaled to fit inside the screen.
const CONTENT := Vector2(540, 620)
const REFERENCE_SCALE := 1.226  # scale of the 1000x760 screen, where the sizes above apply

# Timeline, in seconds.
const LOGO_IN := 0.0
const TITLE_IN := 0.7
const WEBSITE_IN := 1.3
const FADE_OUT := 3.4
const FADE_TIME := 0.6
const SHINE_SPEED := 2.4  # radians per second

const BG := Color("070b12")
const BG_GLOW := Color("0f2238")
const BLUE := Color("3aa0ff")
const SHADOW := Color(0.0, 0.02, 0.05, 0.85)

## Scene opened when the intro ends.
@export_file("*.tscn") var next_scene := "res://scenes/main.tscn"

var clock := 0.0
var fade_start := FADE_OUT
var title_font: Font
var website_font: Font

# Current layout, refreshed every frame so window resizes are followed.
var screen := Vector2.ZERO
var u := 1.0
var logo_center := Vector2.ZERO
var title_size := TITLE_SIZE
var website_size := WEBSITE_SIZE

@onready var logo: Sprite2D = $Logo
@onready var text_back: Node2D = $TextBack
@onready var title: Node2D = $Title
@onready var fade: Node2D = $Fade


func _ready() -> void:
	title_font = _font(700)
	website_font = _font(400)
	text_back.draw.connect(_draw_text_back)
	title.draw.connect(_draw_title)
	fade.draw.connect(_draw_fade)
	_update()


func _process(delta: float) -> void:
	clock += delta
	if clock >= fade_start + FADE_TIME:
		set_process(false)
		get_tree().change_scene_to_file(next_scene)
		return
	_update()


func _unhandled_input(event: InputEvent) -> void:
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton) and event.is_pressed()
	if pressed and clock < fade_start:
		fade_start = clock


func _layout() -> void:
	screen = get_viewport_rect().size
	u = minf(screen.x / CONTENT.x, screen.y / CONTENT.y) / REFERENCE_SCALE
	logo_center = Vector2(screen.x / 2.0, screen.y / 2.0 + LOGO_OFFSET * u)
	title_size = maxi(1, roundi(TITLE_SIZE * u))
	website_size = maxi(1, roundi(WEBSITE_SIZE * u))


func _update() -> void:
	_layout()
	var t := _ease(clock, LOGO_IN, 1.0)
	var size := LOGO_SIZE * u * lerpf(0.82, 1.0, t)
	logo.position = logo_center
	logo.scale = Vector2.ONE * size / logo.texture.get_width()
	logo.modulate.a = t
	var logo_material := logo.material as ShaderMaterial
	logo_material.set_shader_parameter("angle", -PI / 2.0 + clock * SHINE_SPEED)
	logo_material.set_shader_parameter("strength", t * (0.9 + 0.3 * sin(clock * 3.0)))

	var title_material := title.material as ShaderMaterial
	var title_y := _title_y()
	title_material.set_shader_parameter("text_top", title_y - title_size * 0.74)
	title_material.set_shader_parameter("text_bottom", title_y + title_size * 0.02)
	# Highlight sweeping across the title, left to right.
	var width := _text_width(title_font, TITLE, title_size, TITLE_SPACING * u)
	var sweep := clampf((clock - TITLE_IN - 0.5) / 1.2, 0.0, 1.0)
	title_material.set_shader_parameter("sweep_x", screen.x / 2.0 - width / 2.0 - 120.0 * u + (width + 240.0 * u) * sweep)
	title_material.set_shader_parameter("sweep_width", 60.0 * u)

	queue_redraw()
	text_back.queue_redraw()
	title.queue_redraw()
	fade.queue_redraw()


## Arial like the design; the web build has no system fonts, so it uses the default one (emboldened for bold).
func _font(weight: int) -> Font:
	if OS.has_feature("web"):
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 0.9 if weight >= 700 else 0.0
		return variation
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Arial", "Helvetica", "Liberation Sans"])
	system.font_weight = weight
	return system


## Background, drawn behind the logo.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), BG)
	var t := _ease(clock, LOGO_IN, 1.0)
	for i in 12:
		draw_circle(logo_center, lerpf(420.0, 140.0, i / 11.0) * u, Color(BG_GLOW, 0.12 * t))
	var pulse := 0.5 + 0.5 * sin(clock * 2.2)
	draw_circle(logo_center, (LOGO_SIZE / 2.0 + 14.0) * u, Color(BLUE, 0.10 * t * (0.6 + 0.4 * pulse)))


## Title shadow and the website, under the chrome title.
func _draw_text_back() -> void:
	_draw_letters(text_back, title_font, TITLE, title_size, TITLE_SPACING * u, _title_y() + 3.0 * u, SHADOW, TITLE_IN, 0.8)
	_draw_website()


## Small muted web address with a globe icon, fading in as one piece.
func _draw_website() -> void:
	var t := _ease(clock, WEBSITE_IN, 0.9)
	if t <= 0.0:
		return
	var color := Color(WEBSITE_COLOR, WEBSITE_COLOR.a * t)
	var icon_radius := website_size * 0.36
	var gap := 8.0 * u
	var text_width := website_font.get_string_size(WEBSITE, HORIZONTAL_ALIGNMENT_LEFT, -1, website_size).x
	var x := screen.x / 2.0 - (icon_radius * 2.0 + gap + text_width) / 2.0
	var y := screen.y / 2.0 + (WEBSITE_OFFSET + (1.0 - t) * 8.0) * u
	_draw_globe(text_back, Vector2(x + icon_radius, y - website_size * 0.36), icon_radius, color)
	text_back.draw_string(website_font, Vector2(x + icon_radius * 2.0 + gap, y), WEBSITE, HORIZONTAL_ALIGNMENT_LEFT, -1, website_size, color)


## Thin outline globe: circle, equator and two meridians.
func _draw_globe(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var line := maxf(1.0, 1.3 * u)
	canvas.draw_arc(center, radius, 0.0, TAU, 32, color, line, true)
	canvas.draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), color, line, true)
	var meridian := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		meridian.append(center + Vector2(cos(a) * radius * 0.42, sin(a) * radius))
	canvas.draw_polyline(meridian, color, line, true)


## Drawn white; the chrome shader on this node gives it the metal gradient.
func _draw_title() -> void:
	_draw_letters(title, title_font, TITLE, title_size, TITLE_SPACING * u, _title_y(), Color.WHITE, TITLE_IN, 0.8)


## Fade in from black at the start and out to black at the end.
func _draw_fade() -> void:
	var dark := maxf(1.0 - clock / 0.4, clampf((clock - fade_start) / FADE_TIME, 0.0, 1.0))
	if dark > 0.0:
		fade.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, dark))


func _title_y() -> float:
	return screen.y / 2.0 + (TITLE_OFFSET + (1.0 - _ease(clock, TITLE_IN, 0.8)) * 24.0) * u


## Centered text, revealed letter by letter from `start` over `length` seconds.
func _draw_letters(canvas: CanvasItem, font: Font, text: String, size: int, spacing: float, y: float, color: Color, start: float, length: float) -> void:
	var t := _ease(clock, start, length)
	if t <= 0.0:
		return
	var x := screen.x / 2.0 - _text_width(font, text, size, spacing) / 2.0
	for i in text.length():
		var letter := text[i]
		var letter_t := clampf(t * text.length() - i * 0.5, 0.0, 1.0)
		canvas.draw_string(font, Vector2(x, y), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, color.a * letter_t))
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing


func _text_width(font: Font, text: String, size: int, spacing: float) -> float:
	var width := 0.0
	for letter in text:
		width += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing
	return width - spacing


## 0 before `start`, easing up to 1 over `length` seconds.
func _ease(now: float, start: float, length: float) -> float:
	var t := clampf((now - start) / length, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)
