extends RefCounted
## Shared look for menus and the in-game panels, plus small helpers to build controls in code.

const GOLD := Color(1.0, 0.84, 0.4)
const TEXT := Color(0.93, 0.95, 1.0)
const MUTED := Color(0.65, 0.72, 0.82)
const PANEL := Color(0.05, 0.09, 0.16, 0.9)

const PLAYER_COLORS := [
	{"name": "Azul", "color": Color("#3b82f6")},
	{"name": "Vermelho", "color": Color("#e5484d")},
	{"name": "Verde", "color": Color("#30a46c")},
	{"name": "Amarelo", "color": Color("#e5b000")},
	{"name": "Roxo", "color": Color("#8e4ec6")},
	{"name": "Laranja", "color": Color("#f76b15")},
]


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 17

	var panel := _box(PANEL, 12)
	panel.border_color = Color(1, 1, 1, 0.1)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(14)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var states := {
		"normal": Color(0.16, 0.24, 0.36),
		"hover": Color(0.22, 0.32, 0.47),
		"pressed": Color(0.85, 0.66, 0.2),
		"disabled": Color(0.12, 0.15, 0.2),
		"focus": Color(0, 0, 0, 0),
	}
	for state in states:
		var style := _box(states[state], 8)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		if state == "focus":
			style.border_color = Color(1, 1, 1, 0.5)
			style.set_border_width_all(2)
		theme.set_stylebox(state, "Button", style)
	theme.set_stylebox("hover_pressed", "Button", theme.get_stylebox("pressed", "Button"))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color(0.1, 0.08, 0.02))
	theme.set_color("font_hover_pressed_color", "Button", Color(0.1, 0.08, 0.02))
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	theme.set_color("font_color", "Label", TEXT)
	return theme


## A bright "call to action" style for the main button on a screen.
static func primary(button: Button) -> Button:
	button.add_theme_stylebox_override("normal", _padded(_box(Color(0.9, 0.7, 0.2), 8)))
	button.add_theme_stylebox_override("hover", _padded(_box(Color(1.0, 0.8, 0.32), 8)))
	button.add_theme_stylebox_override("pressed", _padded(_box(Color(0.75, 0.56, 0.12), 8)))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(c, Color(0.12, 0.08, 0.02))
	return button


static func label(text: String, size: int = 17, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_pressed)
	return b


static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style


static func _padded(style: StyleBoxFlat) -> StyleBoxFlat:
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
