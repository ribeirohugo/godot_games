extends Control
## A small code-drawn icon (gear or house) for a button, so the project needs no image files.

const Art := preload("res://scripts/art.gd")

var kind := "gear"  # "gear" or "home"
var color := Color(0.25, 0.14, 0.02)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	if kind == "gear":
		Art.draw_gear_icon(self, c, r, color)
	else:
		Art.draw_home_icon(self, c, r * 1.7, color)
