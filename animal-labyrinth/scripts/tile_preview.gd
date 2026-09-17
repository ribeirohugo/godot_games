extends Control
## Shows the tile the player is about to place.

const Art := preload("res://scripts/art.gd")
const Tiles := preload("res://scripts/tiles.gd")

var tile := 0:
	set(value):
		tile = value
		pop = 0.0
		queue_redraw()
var pop := 1.0


func _process(delta: float) -> void:
	if pop < 1.0:
		pop = minf(pop + delta * 5.0, 1.0)
		queue_redraw()


func _draw() -> void:
	if tile <= 0:
		return
	var s := 0.55 + 0.1 * sin(pop * PI)
	var center := size * 0.5
	draw_set_transform(center, 0.0, Vector2(s, s))
	# Put the middle cell of the tile at the centre of this control.
	Art.draw_tile(self, -Art.cell_pos(Vector2(1, 1)) - Vector2(0, Art.THICK * 0.5), tile, 1.0, Tiles)
	draw_set_transform(Vector2.ZERO)
