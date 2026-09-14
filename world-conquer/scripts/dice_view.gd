extends Control
## Shows the dice of the last battle: attacker on top, defender below.

var attack: Array = []
var defend: Array = []
var attack_color := Color.WHITE
var defend_color := Color.WHITE
var shake := 0.0


func show_battle(attack_dice: Array, defend_dice: Array, attacker: Color, defender: Color) -> void:
	attack = attack_dice
	defend = defend_dice
	attack_color = attacker
	defend_color = defender
	shake = 0.25
	queue_redraw()


func _process(delta: float) -> void:
	if shake > 0.0:
		shake = maxf(shake - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	if attack.is_empty():
		return
	var s := 30.0
	for i in attack.size():
		var won: bool = i < defend.size() and attack[i] > defend[i]
		_die(Vector2(i * (s + 8), 0), s, attack[i], attack_color, won or i >= defend.size())
	for i in defend.size():
		var won: bool = i < attack.size() and defend[i] >= attack[i]
		_die(Vector2(i * (s + 8), s + 10), s, defend[i], defend_color, won)


func _die(at: Vector2, s: float, value: int, color: Color, won: bool) -> void:
	var jitter := Vector2(randf_range(-2, 2), randf_range(-2, 2)) * (shake / 0.25)
	var rect := Rect2(at + jitter, Vector2(s, s))
	var face := color if won else color.darkened(0.55)
	draw_rect(rect.grow(1.5), Color(0, 0, 0, 0.5))
	draw_rect(rect, face)
	var pips := {
		1: [Vector2(0.5, 0.5)],
		2: [Vector2(0.25, 0.25), Vector2(0.75, 0.75)],
		3: [Vector2(0.25, 0.25), Vector2(0.5, 0.5), Vector2(0.75, 0.75)],
		4: [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)],
		5: [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.5, 0.5), Vector2(0.25, 0.75), Vector2(0.75, 0.75)],
		6: [Vector2(0.25, 0.22), Vector2(0.75, 0.22), Vector2(0.25, 0.5), Vector2(0.75, 0.5), Vector2(0.25, 0.78), Vector2(0.75, 0.78)],
	}
	for p in pips[value]:
		draw_circle(rect.position + p * s, s * 0.09, Color(1, 1, 1, 0.95 if won else 0.5))
