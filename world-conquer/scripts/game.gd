extends Node
## One match: the map, the in-game panels, the player's clicks and the computer turns.

signal exit_to_menu
signal restart(config: Dictionary)

const WorldMapScript := preload("res://scripts/world_map.gd")
const MapCameraScript := preload("res://scripts/map_camera.gd")
const GameStateScript := preload("res://scripts/game_state.gd")
const AIScript := preload("res://scripts/ai.gd")
const DiceViewScript := preload("res://scripts/dice_view.gd")
const UI := preload("res://scripts/ui.gd")

const PHASE_NAMES := {
	"reinforce": "Reforços", "attack": "Ataque", "occupy": "Ocupar", "fortify": "Mover exércitos", "over": "Fim",
}
const HUMAN := 0

var data
var sfx
var config := {}  # opponents, color, difficulty, fast
var state
var ai
var world_map: Node2D
var camera: Camera2D

var selected := ""
var target := ""
var place_amount := 1  # 1, 5 or 0 for "all"
var busy := false  # a computer turn or an all-out attack is running
var game_token := 0
var log_lines: Array[String] = []

var ui_root: Control
var turn_swatch: ColorRect
var turn_label: Label
var phase_label: Label
var help_label: Label
var region_label: Label
var players_box: VBoxContainer
var log_label: Label
var dice: Control
var actions: HBoxContainer
var actions_panel: PanelContainer
var popup: PanelContainer
var popup_title: Label
var popup_slider: HSlider
var popup_value: Label
var popup_confirm := Callable()
var popup_cancel: Button
var overlay: ColorRect
var overlay_title: Label
var overlay_body: Label
var overlay_buttons: HBoxContainer


func _init(map_data, sound, match_config: Dictionary) -> void:
	data = map_data
	sfx = sound
	config = match_config


func _ready() -> void:
	world_map = WorldMapScript.new()
	add_child(world_map)
	world_map.build(data)

	camera = MapCameraScript.new()
	camera.map_size = data.size
	add_child(camera)
	camera.make_current()
	camera.zoom_changed.connect(world_map.set_zoom)
	camera.clicked.connect(_on_map_clicked)
	camera.fit()

	_build_hud()

	var players := []
	var colors: Array = UI.PLAYER_COLORS.duplicate()
	var mine: Dictionary = colors[config.color]
	colors.remove_at(config.color)
	players.append({"name": "Tu", "color": mine.color, "human": true, "alive": true, "cards": []})
	for i in config.opponents:
		players.append({"name": colors[i].name, "color": colors[i].color, "human": false, "alive": true, "cards": []})

	state = GameStateScript.new()
	state.changed.connect(_refresh)
	state.message.connect(_log)
	state.setup(data, players)
	ai = AIScript.new(state, config.difficulty)
	_log("O jogo começou. Joga primeiro: %s." % players[state.current].name)
	_begin_turn()


func _process(_delta: float) -> void:
	actions_panel.size = actions_panel.get_combined_minimum_size()
	actions_panel.position = ui_root.size - actions_panel.size - Vector2(12, 12)
	var id: String = data.region_at(camera.get_global_mouse_position())
	if id != world_map.hovered:
		world_map.hovered = id
		world_map.refresh()
		_update_region_info()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if selected != "":
			_deselect()
		elif not overlay.visible:
			_show_pause()
		get_viewport().set_input_as_handled()


# --- Turn flow -------------------------------------------------------------------

func _begin_turn() -> void:
	_deselect()
	if state.phase == "over":
		return
	sfx.play("turn")
	if state.players[state.current].human:
		if state.must_trade():
			_log("Tens %d cartas: troca antes de colocar reforços." % state.players[HUMAN].cards.size())
		_refresh()
	else:
		_run_computer_turn()


func _run_computer_turn() -> void:
	busy = true
	var token := game_token
	var p: int = state.current
	_refresh()
	await _wait(0.5)

	while not state.find_card_set(p).is_empty() and state.players[p].cards.size() >= 3:
		state.trade_cards()
		sfx.play("card")
		await _wait(0.4)
		if token != game_token:
			return

	while state.phase == "reinforce":
		var step: Array = ai.reinforce_step()
		state.place(step[0], step[1])
		sfx.play("place")
		_flash(step[0])
		await _wait(0.25)
		if token != game_token:
			return

	while state.phase == "attack":
		var step: Array = ai.attack_step()
		if step.is_empty():
			break
		_flash(step[0], step[1])
		state.attack(step[0], step[1])
		_show_battle()
		await _wait(0.35)
		if token != game_token:
			return
		if state.phase == "occupy":
			state.occupy_with(ai.occupy_count())
			if _check_game_end():
				return
			await _wait(0.2)

	state.end_attacks()
	var move: Array = ai.fortify_step()
	world_map.selected = ""
	world_map.targets = []
	if move.is_empty():
		state.end_turn()
	else:
		_flash(move[0], move[1])
		await _wait(0.3)
		if token != game_token:
			return
		state.fortify(move[0], move[1], move[2])
	busy = false
	_begin_turn()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * (0.3 if config.fast else 1.0)).timeout
	# Hold the computer turn while the pause menu is open.
	while overlay.visible and state.phase != "over":
		await get_tree().process_frame


func _check_game_end() -> bool:
	if not state.players[HUMAN].alive:
		busy = false
		state.phase = "over"
		sfx.play("defeat")
		_show_game_over("Derrota", "Foste eliminado no turno %d." % state.turn)
		return true
	if state.winner >= 0:
		busy = false
		sfx.play("victory")
		_show_game_over("Vitória!", "Conquistaste o mundo em %d turnos." % state.turn)
		return true
	return false


# --- Player input ----------------------------------------------------------------

func _on_map_clicked(at: Vector2) -> void:
	if busy or overlay.visible or popup.visible or not state.players[state.current].human:
		return
	var id: String = data.region_at(at)
	if id == "":
		_deselect()
		return
	match state.phase:
		"reinforce":
			if state.owner[id] != HUMAN:
				return
			if state.must_trade():
				_log("Tens de trocar cartas primeiro.")
				return
			var count: int = state.reinforcements if place_amount == 0 else place_amount
			if state.place(id, count):
				sfx.play("place")
		"attack":
			if selected != "" and id in world_map.targets:
				target = id
				_attack_once()
			elif state.can_attack_from(id):
				_select(id, state.enemy_neighbours(id))
			else:
				_deselect()
		"fortify":
			if selected != "" and id in world_map.targets:
				_open_popup("Mover para %s" % data.regions[id].name, 1, state.armies[selected] - 1,
					state.armies[selected] - 1, func(n: int) -> void: _fortify(id, n), true)
			elif state.owner[id] == HUMAN and state.armies[id] >= 2 and not state.reachable(id).is_empty():
				_select(id, state.reachable(id))
			else:
				_deselect()


func _select(id: String, targets: Array) -> void:
	sfx.play("click")
	selected = id
	target = ""
	world_map.selected = id
	world_map.targets = targets
	_refresh()


func _deselect() -> void:
	selected = ""
	target = ""
	if world_map:
		world_map.selected = ""
		world_map.targets = []
		world_map.refresh()
	if actions:
		_refresh()


func _attack_once() -> void:
	if not state.attack(selected, target):
		return
	_show_battle()
	_after_attack()


func _attack_all_out() -> void:
	if selected == "" or target == "" or busy:
		return
	busy = true
	var token := game_token
	while state.can_attack(selected, target):
		state.attack(selected, target)
		_show_battle()
		await get_tree().create_timer(0.12).timeout
		if token != game_token:
			return
		if state.phase == "occupy":
			break
	busy = false
	_after_attack()


func _after_attack() -> void:
	if state.phase == "occupy":
		var info: Dictionary = state.occupy
		if info.max <= info.min:
			_occupy(info.min)
		else:
			_open_popup("Ocupar %s" % data.regions[info.to].name, info.min, info.max, info.max,
				func(n: int) -> void: _occupy(n), false)
		return
	if not state.can_attack(selected, target):
		if state.can_attack_from(selected):
			_select(selected, state.enemy_neighbours(selected))
		else:
			_deselect()
	_refresh()


func _occupy(count: int) -> void:
	var to: String = state.occupy.to
	state.occupy_with(count)
	sfx.play("conquer")
	if _check_game_end():
		return
	# Keep attacking from the new region if it can.
	if state.can_attack_from(to):
		_select(to, state.enemy_neighbours(to))
	else:
		_deselect()


func _fortify(to: String, count: int) -> void:
	if state.fortify(selected, to, count):
		sfx.play("place")
		_begin_turn()


func _end_attacks() -> void:
	sfx.play("click")
	_deselect()
	state.end_attacks()


func _end_turn() -> void:
	sfx.play("click")
	_deselect()
	state.end_turn()
	_begin_turn()


func _trade() -> void:
	if state.trade_cards():
		sfx.play("card")


# --- Display ---------------------------------------------------------------------

func _refresh() -> void:
	if state == null or players_box == null:
		return
	for id in data.ids:
		var color: Color = state.players[state.owner[id]].color
		world_map.colors[id] = color
		world_map.badges[id] = {"text": str(state.armies[id]), "color": color.darkened(0.45)}
	world_map.refresh()

	var player: Dictionary = state.players[state.current]
	turn_swatch.color = player.color
	turn_label.text = "Turno %d · %s" % [state.turn, player.name]
	phase_label.text = PHASE_NAMES[state.phase]
	help_label.text = _help_text()
	_update_players()
	_update_actions()
	_update_region_info()


func _help_text() -> String:
	var player: Dictionary = state.players[state.current]
	if state.phase == "over":
		return "O jogo terminou."
	if not player.human:
		return "%s está a jogar..." % player.name
	match state.phase:
		"reinforce":
			if state.must_trade():
				return "Tens 5 cartas ou mais: troca 3 antes de colocar reforços."
			return "Tens %s para colocar. Clica nas tuas regiões." % _armies_text(state.reinforcements)
		"attack":
			if selected == "":
				return "Escolhe uma região tua com 2 ou mais exércitos para atacar."
			if target == "":
				return "Escolhe a região inimiga a atacar (contorno branco)."
			return "A atacar %s. Clica de novo para outro ataque, ou usa Ataque total." % data.regions[target].name
		"occupy":
			return "Escolhe quantos exércitos entram na região conquistada."
		"fortify":
			if selected == "":
				return "Podes mover exércitos uma vez: escolhe a região de origem, ou termina o turno."
			return "Escolhe para onde mover (regiões tuas ligadas)."
	return ""


func _armies_text(count: int) -> String:
	return "1 exército" if count == 1 else "%d exércitos" % count


func _update_players() -> void:
	for child in players_box.get_children():
		child.queue_free()
	for i in state.players.size():
		var player: Dictionary = state.players[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var marker := UI.label("▶" if i == state.current else " ", 14, UI.GOLD)
		marker.custom_minimum_size = Vector2(14, 0)
		row.add_child(marker)
		var swatch := ColorRect.new()
		swatch.color = player.color if player.alive else player.color.darkened(0.7)
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var name_label := UI.label(player.name, 16, UI.TEXT if player.alive else UI.MUTED)
		name_label.custom_minimum_size = Vector2(84, 0)
		row.add_child(name_label)
		var stats := "eliminado" if not player.alive else "%d reg · %d exér · %d cartas" % [
			state.regions_of(i).size(), state.armies_of(i), player.cards.size()]
		row.add_child(UI.label(stats, 14, UI.MUTED))
		players_box.add_child(row)


func _update_actions() -> void:
	for child in actions.get_children():
		child.queue_free()
	var human_turn: bool = state.players[state.current].human and not busy and state.phase != "over"
	if human_turn:
		match state.phase:
			"reinforce":
				var set_size: int = state.find_card_set(HUMAN).size()
				if set_size > 0:
					actions.add_child(UI.primary(UI.button("Trocar cartas (+%d)" % state.next_trade_value(), _trade)))
				for option in [[1, "Colocar 1"], [5, "Colocar 5"], [0, "Colocar todos"]]:
					var b := UI.button(option[1], func() -> void:
						place_amount = option[0]
						sfx.play("click")
						_update_actions())
					b.toggle_mode = true
					b.button_pressed = place_amount == option[0]
					actions.add_child(b)
			"attack":
				if selected != "" and target != "" and state.can_attack(selected, target):
					actions.add_child(UI.primary(UI.button("Ataque total", _attack_all_out)))
				actions.add_child(UI.button("Terminar ataques", _end_attacks))
			"fortify":
				actions.add_child(UI.button("Terminar turno", _end_turn))
	actions.add_child(UI.button("Menu", _show_pause))


func _update_region_info() -> void:
	if region_label == null or state == null:
		return
	var id: String = world_map.hovered if world_map.hovered != "" else selected
	if id == "":
		region_label.text = "Cartas: %s" % _cards_text()
		return
	var region: Dictionary = data.regions[id]
	var continent: Dictionary = data.continents[region.continent]
	region_label.text = "%s — %s, %s\n%s (bónus +%d)" % [
		region.name, state.players[state.owner[id]].name, _armies_text(state.armies[id]), continent.name, continent.bonus]


func _cards_text() -> String:
	var cards: Array = state.players[HUMAN].cards
	if cards.is_empty():
		return "nenhuma (ganhas uma ao conquistar num turno)"
	var counts := [0, 0, 0]
	for c in cards:
		counts[c] += 1
	var parts := []
	for i in 3:
		if counts[i] > 0:
			parts.append("%d %s" % [counts[i], state.CARD_NAMES[i]])
	return ", ".join(parts)


func _show_battle() -> void:
	var b: Dictionary = state.last_battle
	var attacker: Color = state.players[state.current].color
	var defender_owner: int = state.owner[b.to] if not b.conquered else state.current
	var defender: Color = Color(0.6, 0.6, 0.6) if b.conquered else state.players[defender_owner].color
	dice.show_battle(b.attack, b.defend, attacker, defender)
	sfx.play("dice")
	if b.defender_lost > 0 and b.attacker_lost == 0:
		sfx.play("hit")


func _flash(from: String, to: String = "") -> void:
	world_map.selected = from
	world_map.targets = [to] if to != "" else []
	world_map.refresh()


func _log(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > 5:
		log_lines.pop_front()
	if log_label:
		log_label.text = "\n".join(log_lines)


# --- HUD construction ------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UI.make_theme()
	layer.add_child(ui_root)

	# Turn panel, top left.
	var turn_panel := _panel(Vector2(12, 12), 340)
	var turn_box := VBoxContainer.new()
	turn_panel.add_child(turn_box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	turn_swatch = ColorRect.new()
	turn_swatch.custom_minimum_size = Vector2(18, 18)
	turn_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(turn_swatch)
	turn_label = UI.label("", 20)
	head.add_child(turn_label)
	turn_box.add_child(head)
	phase_label = UI.label("", 16, UI.GOLD)
	turn_box.add_child(phase_label)
	help_label = UI.label("", 15)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.custom_minimum_size = Vector2(312, 0)
	turn_box.add_child(help_label)
	turn_box.add_child(HSeparator.new())
	region_label = UI.label("", 14, UI.MUTED)
	region_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	region_label.custom_minimum_size = Vector2(312, 0)
	turn_box.add_child(region_label)

	# Players, top right.
	var players_panel := PanelContainer.new()
	players_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(players_panel)
	players_box = VBoxContainer.new()
	players_panel.add_child(players_box)
	players_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	players_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)

	# Dice and battle log, bottom left.
	var log_panel := PanelContainer.new()
	log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(log_panel)
	var log_box := HBoxContainer.new()
	log_box.add_theme_constant_override("separation", 14)
	log_panel.add_child(log_box)
	dice = DiceViewScript.new()
	dice.custom_minimum_size = Vector2(106, 70)
	log_box.add_child(dice)
	log_label = UI.label("", 13, UI.MUTED)
	log_label.custom_minimum_size = Vector2(300, 70)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_box.add_child(log_label)
	log_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	log_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)

	# Actions, bottom right.
	# Placed by hand each frame, since its width changes with the buttons it holds.
	actions_panel = PanelContainer.new()
	actions_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(actions_panel)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions_panel.add_child(actions)

	_build_popup()
	_build_overlay()


func _panel(at: Vector2, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.custom_minimum_size = Vector2(width, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(panel)
	return panel


func _build_popup() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(center)
	popup = PanelContainer.new()
	popup.custom_minimum_size = Vector2(360, 0)
	popup.visible = false
	center.add_child(popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	popup.add_child(box)
	popup_title = UI.label("", 22, UI.GOLD)
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(popup_title)
	popup_value = UI.label("", 30)
	popup_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(popup_value)
	popup_slider = HSlider.new()
	popup_slider.step = 1
	popup_slider.custom_minimum_size = Vector2(300, 24)
	popup_slider.value_changed.connect(func(v: float) -> void: popup_value.text = _armies_text(int(v)))
	box.add_child(popup_slider)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	popup_cancel = UI.button("Cancelar", func() -> void:
		popup.visible = false
		_deselect())
	row.add_child(popup_cancel)
	row.add_child(UI.primary(UI.button("Mover", func() -> void:
		popup.visible = false
		sfx.play("click")
		popup_confirm.call(int(popup_slider.value)))))


func _open_popup(title: String, lo: int, hi: int, value: int, on_confirm: Callable, can_cancel: bool) -> void:
	popup_title.text = title
	popup_slider.min_value = lo
	popup_slider.max_value = hi
	popup_slider.value = value
	popup_value.text = _armies_text(value)
	popup_confirm = on_confirm
	popup_cancel.visible = can_cancel
	popup.visible = true


func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.05, 0.1, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	ui_root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	overlay_title = UI.label("", 40, UI.GOLD)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(overlay_title)
	overlay_body = UI.label("", 17)
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(overlay_body)
	overlay_buttons = HBoxContainer.new()
	overlay_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_buttons.add_theme_constant_override("separation", 10)
	box.add_child(overlay_buttons)


func _show_overlay(title: String, body: String, buttons: Array) -> void:
	overlay_title.text = title
	overlay_body.text = body
	for child in overlay_buttons.get_children():
		child.queue_free()
	for b in buttons:
		overlay_buttons.add_child(b)
	overlay.visible = true


func _show_pause() -> void:
	if state.phase == "over":
		return
	sfx.play("click")
	_show_overlay("Pausa", "Turno %d." % state.turn, [
		UI.button("Menu principal", _quit_to_menu),
		UI.primary(UI.button("Continuar", func() -> void: overlay.visible = false)),
	])


func _show_game_over(title: String, body: String) -> void:
	_deselect()
	_refresh()
	_show_overlay(title, body, [
		UI.button("Menu principal", _quit_to_menu),
		UI.primary(UI.button("Jogar outra vez", func() -> void:
			game_token += 1
			restart.emit(config))),
	])


func _quit_to_menu() -> void:
	game_token += 1
	exit_to_menu.emit()
