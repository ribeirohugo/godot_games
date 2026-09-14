extends Node
## Main menu: the world map drifting in the background, with New game, How to play and Quit.

signal start_game(config: Dictionary)

const WorldMapScript := preload("res://scripts/world_map.gd")
const UI := preload("res://scripts/ui.gd")
const SETTINGS_PATH := "user://settings.cfg"

var data
var sfx
var config := {"opponents": 3, "color": 0, "difficulty": 1, "fast": false}

var world_map: Node2D
var camera: Camera2D
var drift := 0.0
var home: Control
var setup: Control
var rules: Control


func _init(map_data, sound) -> void:
	data = map_data
	sfx = sound


func _ready() -> void:
	_load_settings()
	world_map = WorldMapScript.new()
	add_child(world_map)
	world_map.build(data)
	var palette := UI.PLAYER_COLORS.map(func(c): return c.color)
	for id in data.ids:
		world_map.colors[id] = palette[randi() % palette.size()].darkened(0.15)
	world_map.refresh()

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.make_theme()
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.1, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	home = _screen(root, _build_home())
	setup = _screen(root, _build_setup())
	rules = _screen(root, _build_rules())
	_show(home)


func _process(delta: float) -> void:
	# Slow pan across the world behind the menu.
	drift += delta * 0.03
	var view := get_viewport().get_visible_rect().size
	var zoom := maxf(view.y / data.size.y, view.x / data.size.x) * 1.35
	if not is_equal_approx(zoom, camera.zoom.x):
		camera.zoom = Vector2(zoom, zoom)
		world_map.set_zoom(zoom)
	var half := view * 0.5 / zoom
	var span: Vector2 = data.size - half * 2.0
	camera.position = half + Vector2((sin(drift) * 0.5 + 0.5) * span.x, (cos(drift * 0.7) * 0.5 + 0.5) * span.y)


func _screen(root: Control, content: Control) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	center.add_child(content)
	return center


func _show(screen: Control) -> void:
	for s in [home, setup, rules]:
		s.visible = s == screen


func _build_home() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := UI.label("WORLD CONQUER", 50, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)
	var subtitle := UI.label("Conquista o mundo, região a região.", 18, UI.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(_spacer(10))

	box.add_child(_big(UI.primary(UI.button("Novo jogo", func() -> void:
		sfx.play("click")
		_show(setup)))))
	box.add_child(_big(UI.button("Como jogar", func() -> void:
		sfx.play("click")
		_show(rules))))
	if not OS.has_feature("web"):
		box.add_child(_big(UI.button("Sair", func() -> void: get_tree().quit())))
	return panel


func _build_setup() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := UI.label("Novo jogo", 34, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(UI.label("Adversários (computador)", 16, UI.MUTED))
	box.add_child(_choice(["1", "2", "3", "4", "5"], config.opponents - 1, func(i: int) -> void: config.opponents = i + 1))

	box.add_child(UI.label("A tua cor", 16, UI.MUTED))
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for i in UI.PLAYER_COLORS.size():
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.button_group = group
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.custom_minimum_size = Vector2(64, 40)
		swatch.tooltip_text = UI.PLAYER_COLORS[i].name
		var color: Color = UI.PLAYER_COLORS[i].color
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = color if state != "hover" else color.lightened(0.15)
			style.set_corner_radius_all(8)
			if state.contains("pressed"):
				style.border_color = Color.WHITE
				style.set_border_width_all(4)
			swatch.add_theme_stylebox_override(state, style)
		swatch.button_pressed = i == config.color
		swatch.pressed.connect(func() -> void:
			config.color = i
			sfx.play("click"))
		colors.add_child(swatch)
	box.add_child(colors)

	box.add_child(UI.label("Dificuldade", 16, UI.MUTED))
	box.add_child(_choice(["Fácil", "Normal", "Difícil"], config.difficulty, func(i: int) -> void: config.difficulty = i))
	box.add_child(UI.label("Velocidade dos adversários", 16, UI.MUTED))
	box.add_child(_choice(["Normal", "Rápida"], 1 if config.fast else 0, func(i: int) -> void: config.fast = i == 1))

	box.add_child(_spacer(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UI.button("Voltar", func() -> void:
		sfx.play("click")
		_show(home)))
	row.add_child(_big(UI.primary(UI.button("Começar", func() -> void:
		sfx.play("click")
		_save_settings()
		start_game.emit(config.duplicate())))))
	box.add_child(row)
	return panel


func _build_rules() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := UI.label("Como jogar", 34, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var text := UI.label("""O objetivo é eliminar todos os adversários. Cada turno tem três fases:

1. Reforços — recebes 1 exército por cada 3 regiões (mínimo 3), mais o bónus de cada continente que controlas por inteiro. Clica nas tuas regiões para os colocar.

2. Ataque — escolhe uma região tua com 2 ou mais exércitos e depois uma vizinha inimiga. O atacante lança até 3 dados, o defensor até 2; os dados mais altos comparam-se e, em empate, ganha a defesa. Ao conquistar, escolhes quantos exércitos entram.

3. Mover — uma vez por turno, podes mover exércitos entre regiões tuas ligadas.

Se conquistares pelo menos uma região num turno, ganhas uma carta. Três iguais ou três diferentes trocam-se por exércitos extra, cada vez mais valiosos.

Roda do rato para zoom, arrastar para mover o mapa, Esc para o menu.""", 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(580, 0)
	box.add_child(text)
	var back := UI.primary(UI.button("Voltar", func() -> void:
		sfx.play("click")
		_show(home)))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	return panel


func _choice(options: Array, current: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for i in options.size():
		var b := UI.button(options[i], func() -> void:
			on_pick.call(i)
			sfx.play("click"))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == current
		b.custom_minimum_size = Vector2(72, 38)
		row.add_child(b)
	return row


func _big(button: Button) -> Button:
	button.custom_minimum_size = Vector2(220, 48)
	button.add_theme_font_size_override("font_size", 20)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in config:
		config[key] = cfg.get_value("new_game", key, config[key])
	config.opponents = clampi(config.opponents, 1, 5)
	config.color = clampi(config.color, 0, UI.PLAYER_COLORS.size() - 1)
	config.difficulty = clampi(config.difficulty, 0, 2)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in config:
		cfg.set_value("new_game", key, config[key])
	cfg.save(SETTINGS_PATH)
