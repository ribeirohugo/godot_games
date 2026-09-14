extends Camera2D
## Zoom with the mouse wheel (towards the cursor), drag to scroll, click to pick.

signal zoom_changed(value: float)
signal clicked(world_position: Vector2)

const DRAG_THRESHOLD := 6.0
const MAX_ZOOM := 4.0

var map_size := Vector2(2000, 858)
var min_zoom := 0.5
var _press_position := Vector2.ZERO
var _pressed := false
var _dragging := false


func fit() -> void:
	var view := get_viewport_rect().size
	min_zoom = minf(view.x / map_size.x, view.y / map_size.y) * 0.95
	_set_zoom(min_zoom)
	position = map_size * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_at(event.position, 1.15)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(event.position, 1.0 / 1.15)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					_pressed = true
					_dragging = event.button_index != MOUSE_BUTTON_LEFT
					_press_position = event.position
				else:
					if _pressed and not _dragging and event.button_index == MOUSE_BUTTON_LEFT:
						clicked.emit(get_global_mouse_position())
					_pressed = false
					_dragging = false
	elif event is InputEventMouseMotion and _pressed:
		if not _dragging and event.position.distance_to(_press_position) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			position -= event.relative / zoom.x
			_clamp()
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:
		position += event.delta * 8.0 / zoom.x
		_clamp()


func _process(delta: float) -> void:
	var move := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if move != Vector2.ZERO:
		position += move * 700.0 * delta / zoom.x
		_clamp()


func _zoom_at(screen_point: Vector2, factor: float) -> void:
	var before := _screen_to_world(screen_point)
	_set_zoom(clampf(zoom.x * factor, min_zoom, MAX_ZOOM))
	position += before - _screen_to_world(screen_point)
	_clamp()


func _set_zoom(value: float) -> void:
	zoom = Vector2(value, value)
	zoom_changed.emit(value)


func _screen_to_world(point: Vector2) -> Vector2:
	return position + (point - get_viewport_rect().size * 0.5) / zoom.x


## Keeps the map on screen: centred when it fits, otherwise no gaps past its edges.
func _clamp() -> void:
	var half := get_viewport_rect().size * 0.5 / zoom.x
	for axis in 2:
		var lo := half[axis] - 60.0 / zoom.x
		var hi := map_size[axis] - half[axis] + 60.0 / zoom.x
		position[axis] = map_size[axis] * 0.5 if lo > hi else clampf(position[axis], lo, hi)
