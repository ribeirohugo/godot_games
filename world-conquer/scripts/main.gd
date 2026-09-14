extends Node
## World Conquer: switches between the main menu and a match. The map data and sounds are
## loaded once and shared.

const MapData := preload("res://scripts/map_data.gd")
const MenuScript := preload("res://scripts/menu.gd")
const GameScript := preload("res://scripts/game.gd")
const SfxScript := preload("res://scripts/sfx.gd")

var data
var sfx
var screen: Node


func _ready() -> void:
	data = MapData.load_map()
	sfx = SfxScript.new()
	add_child(sfx)
	show_menu()


func show_menu() -> void:
	var menu = MenuScript.new(data, sfx)
	menu.start_game.connect(start_game)
	_swap(menu)


func start_game(config: Dictionary) -> void:
	var game = GameScript.new(data, sfx, config)
	game.exit_to_menu.connect(show_menu)
	game.restart.connect(start_game)
	_swap(game)


func _swap(next: Node) -> void:
	if screen:
		screen.queue_free()
	screen = next
	add_child.call_deferred(next)
