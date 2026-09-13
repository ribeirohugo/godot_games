extends Node2D
## The walking animal (monkey, horse, cat or dog), drawn in code.
## Its position is the point on the ground between its feet.

const MONKEY := 0
const HORSE := 1
const CAT := 2
const DOG := 3

const INK := Color(0.12, 0.08, 0.05)

var kind := MONKEY
var dir := 0  # grid direction, see Art.DIRS
var walking := false
var anim := 0.0
var hop := 0.0  # extra height while hopping, in pixels
var sink := 0.0  # 0 on land, 1 fully under water
var cheering := false
var splash_time := -1.0

var _fade := 1.0


func _process(delta: float) -> void:
	if walking or cheering:
		anim += delta
	if splash_time >= 0.0:
		splash_time += delta
	queue_redraw()


func reset(at: Vector2, new_dir: int) -> void:
	position = at
	dir = new_dir
	walking = false
	cheering = false
	hop = 0.0
	sink = 0.0
	splash_time = -1.0


func step_to(target: Vector2, new_dir: int, duration: float) -> void:
	dir = new_dir
	walking = true
	var tw := create_tween()
	tw.tween_property(self, "position", target, duration)
	await tw.finished
	walking = false


## Jumps forward into the water and sinks.
func fall_to(target: Vector2, duration: float) -> void:
	walking = true
	var tw := create_tween()
	tw.tween_property(self, "position", target, duration)
	tw.parallel().tween_method(func(t: float) -> void: hop = sin(t * PI) * 18.0, 0.0, 1.0, duration)
	await tw.finished
	walking = false
	hop = 0.0
	splash_time = 0.0
	var sink_tw := create_tween()
	sink_tw.tween_property(self, "sink", 1.0, 0.6)
	await sink_tw.finished


func cheer() -> void:
	cheering = true


func _draw() -> void:
	if splash_time >= 0.0:
		_draw_splash()
	if sink >= 1.0:
		return

	var lift := hop
	if walking:
		lift += absf(sin(anim * 14.0)) * 3.0
	if cheering:
		lift += absf(sin(anim * 7.0)) * 14.0

	var shadow := 14.0 if kind == HORSE else 11.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, shadow - minf(lift, 10.0) * 0.4, Color(0, 0, 0, 0.25 * (1.0 - sink)))
	draw_set_transform(Vector2.ZERO)

	_fade = 1.0 - sink
	var o := Vector2(0, -lift + sink * 40.0)
	var side := 1.0 if dir == 0 or dir == 3 else -1.0  # which way it looks on screen
	var swing := sin(anim * 14.0) if walking else 0.0
	match kind:
		MONKEY:
			_draw_monkey(o, side, swing * 4.0)
		HORSE:
			_draw_horse(o, side, swing * 4.0)
		CAT:
			_draw_cat(o, side, swing * 3.0)
		DOG:
			_draw_dog(o, side, swing * 3.0)


# --- Monkey: upright, seen from the front when walking toward the viewer ----------

func _draw_monkey(o: Vector2, side: float, swing: float) -> void:
	var fur := Color(0.55, 0.33, 0.16)
	var dark := Color(0.4, 0.22, 0.1)
	var skin := Color(0.96, 0.8, 0.6)
	var front := dir == 0 or dir == 1

	var tail := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		tail.append(o + Vector2(-side * (8 + t * 10), -10 - t * 16 + sin(t * 5.0 + anim * 3.0) * 3.0))
	draw_polyline(tail, _c(dark), 3.0, true)

	_limb(o + Vector2(-4, -10), o + Vector2(-4 + swing, 0), dark, 4.0)
	_limb(o + Vector2(4, -10), o + Vector2(4 - swing, 0), dark, 4.0)
	_ellipse(o + Vector2(0, -17), Vector2(9, 10), fur)
	if front:
		_ellipse(o + Vector2(side * 1.5, -16), Vector2(5.5, 7), skin)

	if cheering:
		var wave := sin(anim * 14.0) * 3.0
		_limb(o + Vector2(-7, -22), o + Vector2(-13, -36 + wave), dark, 4.0)
		_limb(o + Vector2(7, -22), o + Vector2(13, -36 - wave), dark, 4.0)
	else:
		_limb(o + Vector2(-7, -22), o + Vector2(-10 - swing, -11), dark, 4.0)
		_limb(o + Vector2(7, -22), o + Vector2(10 + swing, -11), dark, 4.0)

	var head := o + Vector2(side, -34)
	for s in [-1.0, 1.0]:
		_circle(head + Vector2(s * 10.5, 0), 4.5, fur)
		_circle(head + Vector2(s * 10.5, 0), 2.5, skin)
	_circle(head, 10.0, fur)
	if front:
		var face := head + Vector2(side * 2.5, 2)
		_ellipse(face, Vector2(7, 6.5), skin)
		_circle(face + Vector2(-2.6 + side, -2), 1.5, INK)
		_circle(face + Vector2(2.6 + side, -2), 1.5, INK)
		_mouth(face + Vector2(side, 1.5))
	else:
		_circle(head + Vector2(0, -3), 3.0, fur.lightened(0.15))


# --- Four-legged animals, always drawn in profile -------------------------------

## Four legs; the diagonal pairs swing together like a trot.
func _legs(o: Vector2, side: float, xs: Array, top: float, swing: float, color: Color, width: float,
		hoof: Color = Color(0, 0, 0, 0)) -> void:
	for i in 4:
		var x: float = xs[i] * side
		var s := swing if i == 0 or i == 3 else -swing
		var near := i >= 2  # the legs on the viewer's side are drawn lighter
		var col := color.lightened(0.08) if near else color.darkened(0.12)
		_limb(o + Vector2(x, top), o + Vector2(x + s, 0), col, width)
		if hoof.a > 0.0:
			_limb(o + Vector2(x + s, -2.5), o + Vector2(x + s, 0), hoof, width + 0.5)


func _draw_horse(o: Vector2, side: float, swing: float) -> void:
	var coat := Color(0.62, 0.36, 0.2)
	var mane := Color(0.25, 0.14, 0.08)

	# Tail hangs off the rump and sways.
	var tail := PackedVector2Array()
	for i in 7:
		var t := i / 6.0
		tail.append(o + Vector2(-side * (15 + t * 5 + sin(anim * 6.0 + t * 3.0) * 2.0), -24 + t * 18))
	draw_polyline(tail, _c(mane), 4.0, true)

	_legs(o, side, [-10.0, 8.0, -7.0, 11.0], -18.0, swing, coat, 3.5, INK)
	_ellipse(o + Vector2(0, -23), Vector2(16, 8), coat)

	# Neck and head, raised higher while cheering.
	var rear := -4.0 if cheering else 0.0
	var neck_base := o + Vector2(side * 11, -25)
	var head := o + Vector2(side * 19, -41 + rear)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-side * 6, 2), neck_base + Vector2(side * 5, 3),
		head + Vector2(side * 2, 4), head + Vector2(-side * 5, -2)]), _c(coat))
	draw_line(neck_base + Vector2(-side * 6, 0), head + Vector2(-side * 5, -3), _c(mane), 3.5, true)
	draw_set_transform(head + Vector2(side * 3, 1), side * 0.5, Vector2(1, 0.55))
	draw_circle(Vector2.ZERO, 8.0, _c(coat))
	draw_set_transform(Vector2.ZERO)
	_circle(head + Vector2(side * 9, 4), 2.8, coat.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-side * 3, -5), head + Vector2(-side * 1, -12), head + Vector2(side * 1, -5)]), _c(coat))
	_circle(head + Vector2(side * 2, -2), 1.4, INK)
	_circle(head + Vector2(-side * 2, -1), 1.8, Color(1, 1, 1, 0.9))  # blaze


func _draw_cat(o: Vector2, side: float, swing: float) -> void:
	var fur := Color(0.95, 0.6, 0.25)
	var stripe := Color(0.8, 0.42, 0.13)

	var tail := PackedVector2Array()
	var flick := sin(anim * 5.0) * 3.0
	for i in 8:
		var t := i / 7.0
		tail.append(o + Vector2(-side * (10 + t * 6 + sin(t * 3.0) * 3.0 + flick * t), -12 - t * 20))
	draw_polyline(tail, _c(fur), 3.5, true)

	_legs(o, side, [-7.0, 6.0, -5.0, 8.0], -10.0, swing, fur, 3.0)
	_ellipse(o + Vector2(0, -13), Vector2(11, 6.5), fur)
	for i in 3:
		var x := -5.0 + i * 4.5
		draw_line(o + Vector2(x * side, -19), o + Vector2(x * side + side, -14), _c(stripe), 2.0, true)

	var head := o + Vector2(side * 12, -22)
	for e in [-4.0, 4.0]:
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(e - 3.5, -4), head + Vector2(e * 1.2, -12), head + Vector2(e + 3.5, -4)]), _c(fur))
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(e - 1.5, -5), head + Vector2(e * 1.1, -9.5), head + Vector2(e + 1.5, -5)]),
			_c(Color(1, 0.75, 0.75)))
	_circle(head, 7.5, fur)
	_ellipse(head + Vector2(side * 3, 2.5), Vector2(4, 3), Color(1, 0.92, 0.82))
	_circle(head + Vector2(side * 1, -1.5), 1.4, INK)
	_circle(head + Vector2(side * 5, -1.5), 1.4, INK)
	_circle(head + Vector2(side * 3.5, 1.5), 1.1, Color(0.9, 0.4, 0.5))
	for w in [-1.0, 1.0]:
		draw_line(head + Vector2(side * 5, 2.5), head + Vector2(side * 12, 2.5 + w * 2.5), _c(Color(1, 1, 1, 0.8)), 1.0, true)


func _draw_dog(o: Vector2, side: float, swing: float) -> void:
	var coat := Color(0.85, 0.72, 0.5)
	var patch := Color(0.5, 0.32, 0.18)

	var wag := sin(anim * (22.0 if cheering else 10.0)) * 4.0
	draw_line(o + Vector2(-side * 11, -17), o + Vector2(-side * (16 + wag * 0.3), -28 + wag), _c(coat), 3.5, true)

	_legs(o, side, [-8.0, 7.0, -6.0, 9.0], -12.0, swing, coat, 3.5)
	_ellipse(o + Vector2(0, -16), Vector2(12, 7.5), coat)
	_ellipse(o + Vector2(-side * 3, -19), Vector2(5, 4), patch)

	var head := o + Vector2(side * 13, -26)
	_circle(head, 7.5, coat)
	_ellipse(head + Vector2(side * 7, 2.5), Vector2(5, 3.5), coat.lightened(0.15))
	_circle(head + Vector2(side * 11.5, 1.5), 1.8, INK)
	_circle(head + Vector2(side * 2.5, -2.5), 1.4, INK)
	# Floppy ear.
	draw_set_transform(head + Vector2(-side * 3, 0), -side * 0.3, Vector2(0.55, 1))
	draw_circle(Vector2.ZERO, 6.0, _c(patch))
	draw_set_transform(Vector2.ZERO)
	if cheering:
		_ellipse(head + Vector2(side * 8, 7), Vector2(1.8, 3), Color(0.95, 0.4, 0.45))


# --- Shared helpers --------------------------------------------------------------

func _mouth(at: Vector2) -> void:
	if cheering:
		_circle(at + Vector2(0, 1.5), 2.0, INK)
	else:
		draw_arc(at, 2.5, 0.3, PI - 0.3, 6, _c(INK), 1.2)


func _draw_splash() -> void:
	var t := splash_time
	for i in 3:
		var r := 8.0 + (t - i * 0.15) * 40.0
		var alpha := clampf(0.8 - (t - i * 0.15) * 0.9, 0.0, 0.8)
		if r > 0.0 and alpha > 0.0:
			draw_set_transform(Vector2(0, 8), 0.0, Vector2(1, 0.5))
			draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color(1, 1, 1, alpha), 2.5)
			draw_set_transform(Vector2.ZERO)
	if t < 0.5:
		for i in 6:
			var a := -PI * (i + 0.5) / 6.0
			var p := Vector2(cos(a) * 30.0 * t / 0.5, 8 + sin(a) * 40.0 * t - 60.0 * t * t)
			draw_circle(p, 2.5, Color(0.85, 0.95, 1.0, 1.0 - t * 2.0))


func _limb(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, _c(color), width, true)


func _circle(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, _c(color))


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1, radius.y / radius.x))
	draw_circle(Vector2.ZERO, radius.x, _c(color))
	draw_set_transform(Vector2.ZERO)


## Applies the fade used while sinking.
func _c(color: Color) -> Color:
	return Color(color, color.a * _fade)
