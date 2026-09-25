extends Control
## The buy menu: one column per category, a button per item with its price. Items the player can't
## buy (other side's weapons, too expensive, already owned) are greyed out. Works with the mouse, and
## with arrows / D-pad and Enter / A through focus navigation.

const Weapons := preload("res://scripts/weapons.gd")

var game  # main.gd
var buttons := {}  # item id -> Button
var money_label: Label
var refresh_t := 0.0


func build(game_ref) -> void:
	game = game_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var title := Label.new()
	title.text = tr("buy_title")
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_font_override("font", game.title_font)
	title.add_theme_color_override("font_color", game.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 28)
	money_label.add_theme_font_override("font", game.bold)
	money_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.45))
	top.add_child(money_label)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	box.add_child(columns)
	var first: Button = null
	for column: Array in Weapons.SHOP:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		columns.add_child(col)
		var head := Label.new()
		head.text = tr(column[0])
		head.add_theme_color_override("font_color", game.MUTED)
		head.add_theme_font_size_override("font_size", 17)
		col.add_child(head)
		for id: String in column[1]:
			var button := Button.new()
			button.custom_minimum_size = Vector2(230, 44)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override("font_size", 17)
			button.pressed.connect(func() -> void:
				if game.rules != null and game.rules.buy(game.rules.human, id):
					_refresh())
			button.mouse_entered.connect(func() -> void:
				if not button.disabled:
					button.grab_focus())
			col.add_child(button)
			buttons[id] = button
			if first == null:
				first = button
	var hint := Label.new()
	hint.text = tr("buy_close_hint")
	hint.add_theme_color_override("font_color", game.MUTED)
	hint.add_theme_font_size_override("font_size", 15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_refresh()
	for id: String in buttons:
		if not buttons[id].disabled:
			buttons[id].grab_focus.call_deferred()
			break


func _process(delta: float) -> void:
	refresh_t -= delta
	if refresh_t <= 0.0:
		refresh_t = 0.25
		_refresh()


func _refresh() -> void:
	var rules = game.rules
	if rules == null:
		return
	var h = rules.human
	money_label.text = "$ %d" % h.money
	for id: String in buttons:
		var button: Button = buttons[id]
		var problem: String = rules.buy_problem(h, id)
		var price: int = rules.price_for(h, id)
		var label := "%s   $%d" % [Weapons.name_of(id), price]
		if problem == "other_side":
			label = "%s   (%s)" % [Weapons.name_of(id), tr("side_att") if Weapons.team_of(id) == "att" else tr("side_def")]
		elif problem == "owned":
			label = "%s   (%s)" % [Weapons.name_of(id), tr("owned")]
		button.text = label
		var was_focused := button.has_focus()
		button.disabled = problem != ""
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		if was_focused and button.disabled:
			for other: String in buttons:
				if not buttons[other].disabled:
					buttons[other].grab_focus()
					break
