extends Control
## Dot-matrix style display in the backbox: score, ball info and flashing messages.

const AMBER := Color(1.0, 0.55, 0.12)
const HEIGHT := 100.0

var score_label: Label
var message_label: Label
var info_label: Label
var message_time := 0.0
var clock := 0.0


func _ready() -> void:
	size = Vector2(480, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "monospace"])
	font.font_weight = 700

	score_label = _make_label(font, 46, Vector2(14, 10), Vector2(452, 58))
	message_label = _make_label(font, 38, Vector2(14, 10), Vector2(452, 58))
	message_label.visible = false
	info_label = _make_label(font, 18, Vector2(14, 64), Vector2(452, 24))

	# Dark grid over the text turns it into little "dots", like a real DMD.
	var grid := Control.new()
	grid.size = size
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.draw.connect(_draw_grid.bind(grid))
	add_child(grid)


func _make_label(font: Font, font_size: int, pos: Vector2, box: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = box
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", AMBER)
	# A shadow with no offset acts as a soft glow around the letters.
	label.add_theme_color_override("font_shadow_color", Color(1, 0.35, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 8)
	add_child(label)
	return label


func set_score(value: int) -> void:
	score_label.text = format_number(value)


func set_info(text: String) -> void:
	info_label.text = text


## Shows a flashing message instead of the score. Use a huge `seconds` to keep it up.
func show_message(text: String, seconds := 2.0) -> void:
	message_label.text = text
	message_time = seconds


func clear_message() -> void:
	message_time = 0.0


func _process(delta: float) -> void:
	clock += delta
	if message_time > 0.0:
		message_time -= delta
		message_label.visible = fmod(clock, 0.5) < 0.38
		score_label.visible = false
	else:
		message_label.visible = false
		score_label.visible = true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.06))
	draw_rect(Rect2(7, 7, 466, 86), Color(0.3, 0.31, 0.35), false, 3.0)
	draw_rect(Rect2(10, 10, 460, 80), Color(0.03, 0.015, 0.0))
	# Unlit dots across the whole screen.
	for x in range(10, 470, 4):
		for y in range(10, 90, 4):
			draw_rect(Rect2(x, y, 2, 2), Color(AMBER, 0.07))


func _draw_grid(grid: Control) -> void:
	var gap := Color(0.03, 0.015, 0.0, 0.75)
	for x in range(12, 470, 4):
		grid.draw_rect(Rect2(x, 10, 2, 80), gap)
	for y in range(12, 90, 4):
		grid.draw_rect(Rect2(10, y, 460, 2), gap)


static func format_number(value: int) -> String:
	var digits := str(value)
	var result := ""
	while digits.length() > 3:
		result = "," + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return digits + result
