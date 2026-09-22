extends Node2D
## One Microsoft Store display image (box, poster or hero art), drawn with the game's own board,
## animals and font in the current language. main.gd's _render_store() makes one per image and
## language; see store-listing/store-listing.md.

const Art := preload("res://scripts/art.gd")
const AnimalScript := preload("res://scripts/animal.gd")
const Tiles := preload("res://scripts/tiles.gd")

const YELLOW := Color(1.0, 0.85, 0.25)
const NAVY := Color(0.06, 0.16, 0.3)
const INK := Color(0.2, 0.13, 0.02)

var kind := "box"  # box, poster or hero
var art_size := Vector2(1080, 1080)

var board: Node2D
var text_layer: Node2D
var animals := []  # [animal node, points shown above it or 0]
var font: FontVariation
var bold: FontVariation


## Stand-in for main.gd: the board state board_view.gd reads while drawing.
class Scene:
	const START_CELL := Vector2i(-1, 1)
	var phase := "build"
	var hover_slot := 4
	var current_tile := 7  # T north-east-south, floating over the hovered slot
	var board := []
	var land := {}
	var goal_cell := Vector2i(7, 12)
	var island_cell := Vector2i(7, 13)
	var animal_kind := 0  # bananas wait on the island

	func _init() -> void:
		# A finished route from the start to the island (slots 0, 1, 5, 9, 10, 14), a few other
		# tiles around it, and some slots left empty.
		board = [1, 5, 0, 17, 0, 2, 0, 11, 18, 7, 5, 0, 13, 28, 2, 0]
		land = {START_CELL: true, goal_cell: true, island_cell: true}
		for slot in 16:
			if board[slot] == 0:
				continue
			for y in 3:
				for x in 3:
					if Tiles.is_land(board[slot], x, y):
						land[slot_cell(slot) + Vector2i(x, y)] = true

	func slot_cell(slot: int) -> Vector2i:
		return Vector2i((slot % 4) * 3, (slot / 4) * 3)

	func slot_of(cell: Vector2i) -> int:
		if cell.x < 0 or cell.x > 11 or cell.y < 0 or cell.y > 11:
			return -1
		return (cell.y / 3) * 4 + cell.x / 3


## board_view.gd frozen in time, over the art's own background instead of a flat sea.
class Board:
	extends "res://scripts/board_view.gd"

	func _process(_delta: float) -> void:
		pass

	func _draw_sea() -> void:
		draw_colored_polygon(PackedVector2Array([
			Art.cell_pos(Vector2(-1.5, -1.5)), Art.cell_pos(Vector2(12.5, -1.5)),
			Art.cell_pos(Vector2(12.5, 12.5)), Art.cell_pos(Vector2(-1.5, 12.5))]),
			Color(0.45, 0.8, 0.92, 0.3))

	func _draw_goal_ring(pos: Vector2) -> void:
		var r := ISLAND_RADIUS * Art.HW * 1.41
		draw_set_transform(pos + Vector2(0, Art.THICK), 0.0, Vector2(1, 0.5))
		for i in 3:
			draw_arc(Vector2.ZERO, r + 14.0 + i * 16.0, 0, TAU, 48, Color(1, 1, 0.8, 0.5 - i * 0.14), 2.5)
		draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	font = _font(0.5)
	bold = _font(0.9)

	board = Board.new()
	board.main = Scene.new()
	var layout: Array = {
		"box": [Vector2(540, 555), 1.3],
		"poster": [Vector2(360, 545), 0.86],
		"hero": [Vector2(1330, 590), 1.3],
	}[kind]
	board.scale = Vector2.ONE * layout[1]
	board.position = layout[0] - Vector2(0, 150) * layout[1]
	add_child(board)

	# The animals along the route, each with the points of the tile it stands on.
	for spec in [[AnimalScript.HORSE, Vector2i(1, 1), 0, 0], [AnimalScript.DOG, Vector2i(4, 2), 1, 20],
			[AnimalScript.CAT, Vector2i(4, 7), 0, 30], [AnimalScript.MONKEY, Vector2i(7, 10), 1, 0]]:
		var animal: Node2D = AnimalScript.new()
		animal.kind = spec[0]
		animal.dir = spec[2]
		animal.position = Art.cell_pos(Vector2(spec[1]))
		animal.z_index = 5
		animal.cheering = spec[0] == AnimalScript.MONKEY
		board.add_child(animal)
		animals.append([animal, spec[3]])

	text_layer = Node2D.new()
	text_layer.z_index = 20
	text_layer.draw.connect(_draw_text)
	add_child(text_layer)


func _font(embolden: float) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	variation.variation_embolden = embolden
	return variation


# --- Background --------------------------------------------------------------------------------

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, art_size)
	var top := Color(0.23, 0.64, 0.86)
	var bottom := Color(0.06, 0.22, 0.42)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
			PackedColorArray([top, top, bottom, bottom]))

	if kind == "hero":
		# A dark band on the left, behind the title, fading into the sea.
		var dark := Color(0.04, 0.12, 0.25, 0.9)
		var clear := Color(dark, 0.0)
		draw_rect(Rect2(0, 0, 700, art_size.y), dark)
		draw_polygon(PackedVector2Array([Vector2(700, 0), Vector2(1000, 0), Vector2(1000, art_size.y), Vector2(700, art_size.y)]),
				PackedColorArray([dark, clear, clear, dark]))

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in int(art_size.x * art_size.y / 5500.0):
		var p := Vector2(rng.randf() * art_size.x, rng.randf() * art_size.y)
		draw_arc(p, 7.0, deg_to_rad(20), deg_to_rad(160), 8, Color(1, 1, 1, rng.randf_range(0.12, 0.3)), 1.5)


# --- Text ----------------------------------------------------------------------------------------

func _draw_text() -> void:
	for entry in animals:
		if entry[1] > 0:
			var at: Vector2 = board.position + board.scale * (entry[0].position + Vector2(46, -30))
			_outlined("+%d" % entry[1], at, 30 * board.scale.x, Color(1, 0.95, 0.6), NAVY, 7, HORIZONTAL_ALIGNMENT_CENTER)

	var title := tr("game_name")
	var words := title.split(" ")
	var tag := tr("art_tagline")
	var cut := tag.find(". ") + 1
	var tag_lines := [tag.left(cut), tag.substr(cut + 1)] if cut > 0 else [tag]
	match kind:
		"box":
			_title([title], Vector2(540, 0), 150, 45, 980, HORIZONTAL_ALIGNMENT_CENTER)
			_tagline([tag], Vector2(540, 975), 46, 1000, HORIZONTAL_ALIGNMENT_CENTER)
		"poster":
			_title(words, Vector2(360, 0), 130, 30, 650, HORIZONTAL_ALIGNMENT_CENTER)
			_tagline(tag_lines, Vector2(360, 850), 40, 660, HORIZONTAL_ALIGNMENT_CENTER)
			_badge(Vector2(360, 990), 30, HORIZONTAL_ALIGNMENT_CENTER)
		"hero":
			var top := 230.0 if words.size() == 1 else 130.0  # keeps the text block vertically centred
			var bottom := _title(words, Vector2(90, 0), 150, top, 740, HORIZONTAL_ALIGNMENT_LEFT)
			var after := _tagline(tag_lines, Vector2(96, bottom + 120), 50, 740, HORIZONTAL_ALIGNMENT_LEFT)
			_badge(Vector2(96, after + 110), 34, HORIZONTAL_ALIGNMENT_LEFT)


## Big yellow title from `top` down, one line per entry of `lines`, all at one size that fits `max_width`.
## Returns the baseline of the last line.
func _title(lines: Array, anchor: Vector2, size: float, top: float, max_width: float,
		align: HorizontalAlignment) -> float:
	for line in lines:
		size = minf(size, size * max_width / bold.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x)
	var y := top + size * 0.95
	for line in lines:
		var at := Vector2(anchor.x, y)
		_outlined(line, at + Vector2(0, size * 0.07), size, NAVY, NAVY, int(size * 0.16), align)
		_outlined(line, at, size, YELLOW, NAVY, int(size * 0.13), align)
		y += size * 1.02
	return y - size * 1.02


## White sentence lines with a dark outline. Returns the baseline of the last line.
func _tagline(lines: Array, anchor: Vector2, size: float, max_width: float, align: HorizontalAlignment) -> float:
	for line in lines:
		size = minf(size, size * max_width / font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x)
	var y := anchor.y
	for line in lines:
		_outlined(line, Vector2(anchor.x, y), size, Color.WHITE, NAVY, int(size * 0.22), align, font)
		y += size * 1.45
	return y - size * 1.45


## Yellow pill with "4 animals • 3 difficulties".
func _badge(anchor: Vector2, size: float, align: HorizontalAlignment) -> void:
	var text := tr("art_badge")
	var width := bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	var rect := Rect2(anchor.x - (width * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0) - size * 0.8,
			anchor.y - size * 1.05, width + size * 1.6, size * 1.75)
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.3)
	shadow.set_corner_radius_all(int(rect.size.y / 2))
	text_layer.draw_style_box(shadow, Rect2(rect.position + Vector2(0, 5), rect.size))
	var pill := StyleBoxFlat.new()
	pill.bg_color = YELLOW
	pill.set_corner_radius_all(int(rect.size.y / 2))
	pill.border_color = NAVY
	pill.set_border_width_all(2)
	pill.anti_aliasing = true
	text_layer.draw_style_box(pill, rect)
	text_layer.draw_string(bold, Vector2(rect.position.x + size * 0.8, anchor.y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), INK)


func _outlined(text: String, at: Vector2, size: float, color: Color, outline: Color, outline_size: int,
		align: HorizontalAlignment, with: Font = null) -> void:
	var f: Font = with if with else bold
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	var pos := at - Vector2(width * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0, 0)
	text_layer.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), outline_size, outline)
	text_layer.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), color)
