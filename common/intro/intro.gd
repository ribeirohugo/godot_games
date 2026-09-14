extends Node2D
## WPlatinum studio intro shown before the game. Any key, click or touch skips it.
## Lives in the root common/intro folder; _config.bat copies it into every game.
## A game uses it by setting run/main_scene to res://common/intro/intro.tscn.

const SCREEN := Vector2(1000, 760)

const TITLE := "WPlatinum"
const SUBTITLE := "Apps and Gaming"
const TITLE_SIZE := 78
const SUBTITLE_SIZE := 28
const SUBTITLE_SPACING := 6.0

const LOGO_CENTER := Vector2(500, 280)
const LOGO_SIZE := 300.0
const TITLE_Y := 520.0
const SUBTITLE_Y := 580.0

# Timeline, in seconds.
const LOGO_IN := 0.0
const TITLE_IN := 0.7
const SUBTITLE_IN := 1.3
const FADE_OUT := 3.4
const FADE_TIME := 0.6
const SHINE_SPEED := 2.4  # radians per second

const BG := Color("070b12")
const BG_GLOW := Color("0f2238")
const BLUE := Color("3fa9ff")
const SILVER := Color("c9d3de")
const WHITE := Color("f4f8fc")
const INK := Color(0.02, 0.03, 0.06)

## Scene opened when the intro ends.
@export_file("*.tscn") var next_scene := "res://scenes/main.tscn"

var clock := 0.0
var fade_start := FADE_OUT
var font: Font

@onready var logo: Sprite2D = $Logo
@onready var overlay: Node2D = $Overlay


func _ready() -> void:
	font = ThemeDB.fallback_font
	logo.position = LOGO_CENTER
	overlay.draw.connect(_draw_overlay)
	_update_logo()


func _process(delta: float) -> void:
	clock += delta
	if clock >= fade_start + FADE_TIME:
		set_process(false)
		get_tree().change_scene_to_file(next_scene)
		return
	_update_logo()
	queue_redraw()
	overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton) and event.is_pressed()
	if pressed and clock < fade_start:
		fade_start = clock


func _update_logo() -> void:
	var t := _ease(clock, LOGO_IN, 1.0)
	var size := LOGO_SIZE * lerpf(0.82, 1.0, t)
	logo.scale = Vector2.ONE * size / logo.texture.get_width()
	logo.modulate.a = t
	var material := logo.material as ShaderMaterial
	material.set_shader_parameter("angle", -PI / 2.0 + clock * SHINE_SPEED)
	material.set_shader_parameter("strength", t * (0.9 + 0.3 * sin(clock * 3.0)))


## Background, drawn behind the logo.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), BG)
	var t := _ease(clock, LOGO_IN, 1.0)
	for i in 12:
		draw_circle(LOGO_CENTER, lerpf(420.0, 140.0, i / 11.0), Color(BG_GLOW, 0.12 * t))
	var pulse := 0.5 + 0.5 * sin(clock * 2.2)
	draw_circle(LOGO_CENTER, LOGO_SIZE / 2.0 + 14.0, Color(BLUE, 0.10 * t * (0.6 + 0.4 * pulse)))


## Text and the fade, drawn in front of the logo.
func _draw_overlay() -> void:
	_draw_title()
	_draw_subtitle()
	# Fade in from black at the start and out to black at the end.
	var dark := maxf(1.0 - clock / 0.4, clampf((clock - fade_start) / FADE_TIME, 0.0, 1.0))
	if dark > 0.0:
		overlay.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, dark))


func _draw_title() -> void:
	var t := _ease(clock, TITLE_IN, 0.8)
	if t <= 0.0:
		return
	var width := font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var x := SCREEN.x / 2.0 - width / 2.0
	var y := TITLE_Y + (1.0 - t) * 24.0
	# Light sweep across the letters, left to right.
	var sweep := (clock - TITLE_IN - 0.4) * 1.1
	for i in TITLE.length():
		var letter := TITLE[i]
		var letter_t := clampf(t * TITLE.length() - i * 0.5, 0.0, 1.0)
		var shine := clampf(1.0 - absf(sweep - float(i) / TITLE.length()) * 5.0, 0.0, 1.0)
		var color := SILVER.lerp(WHITE, shine)
		var at := Vector2(x, y)
		overlay.draw_string_outline(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 12, Color(INK, letter_t))
		overlay.draw_string_outline(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 4, Color(BLUE, 0.35 * letter_t))
		overlay.draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Color(color, letter_t))
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x


func _draw_subtitle() -> void:
	var t := _ease(clock, SUBTITLE_IN, 0.7)
	if t <= 0.0:
		return
	var width := 0.0
	for letter in SUBTITLE:
		width += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, SUBTITLE_SIZE).x + SUBTITLE_SPACING
	width -= SUBTITLE_SPACING
	# Accent lines growing out from both sides of the subtitle.
	var line_y := SUBTITLE_Y - SUBTITLE_SIZE * 0.35
	var gap := width / 2.0 + 24.0
	var reach := 110.0 * t
	overlay.draw_line(Vector2(SCREEN.x / 2.0 - gap - reach, line_y), Vector2(SCREEN.x / 2.0 - gap, line_y), Color(BLUE, t), 2.0, true)
	overlay.draw_line(Vector2(SCREEN.x / 2.0 + gap, line_y), Vector2(SCREEN.x / 2.0 + gap + reach, line_y), Color(BLUE, t), 2.0, true)

	var x := SCREEN.x / 2.0 - width / 2.0
	for letter in SUBTITLE:
		overlay.draw_string(font, Vector2(x, SUBTITLE_Y), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, SUBTITLE_SIZE, Color(BLUE.lerp(WHITE, 0.35), t))
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, SUBTITLE_SIZE).x + SUBTITLE_SPACING


## 0 before `start`, easing up to 1 over `length` seconds.
func _ease(now: float, start: float, length: float) -> float:
	var t := clampf((now - start) / length, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)
