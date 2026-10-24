class_name TrackMap
extends Control

signal point_selected(index: int)
signal edit_started
signal point_moved(index: int, point: Vector2)
signal point_added(point: Vector2, after: int)
signal delete_requested(index: int)
signal freehand_finished(points: Array[Vector2])
signal undo_requested
signal redo_requested

var definition: Dictionary = {}
var selected: int = 0
var zoom: float = 0.65
var center: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _panning: bool = false
var _sampler: TrackSampler = TrackSampler.new()
var tool: String = "select"
var _freehand: Array[Vector2] = []

func set_tool(value: String) -> void:
	tool = value
	mouse_default_cursor_shape = Control.CURSOR_CROSS if tool != "select" else Control.CURSOR_ARROW
	queue_redraw()

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	custom_minimum_size = Vector2(360.0, 260.0)
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(fit)

func set_definition(value: Dictionary, index: int = 0) -> void:
	definition = value
	selected = index
	_sampler.rebuild(definition)
	queue_redraw()

func fit() -> void:
	var points: Array = definition.get("points", [])
	if points.is_empty():
		return
	var bounds: Rect2 = Rect2(_xz(points[0]), Vector2.ZERO)
	for point: Dictionary in points:
		bounds = bounds.expand(_xz(point))
	center = bounds.get_center()
	zoom = clampf(minf(size.x / maxf(200.0, bounds.size.x + 140.0), size.y / maxf(200.0, bounds.size.y + 140.0)), 0.008, 8.0)
	queue_redraw()

func _draw() -> void:
	TrackMapPaint.draw(self, _sampler)
	if _freehand.size() > 1:
		var preview: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in _freehand:
			preview.append(to_screen(point))
		draw_polyline(preview, ApexUI.ACCENT, 4.0, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mouse.pressed
		elif mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before: Vector2 = to_world(mouse.position)
			zoom = clampf(zoom * (1.15 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.008, 8.0)
			center += before - to_world(mouse.position)
			queue_redraw()
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			if mouse.pressed and tool == "draw":
				_freehand = [to_world(mouse.position)]
				queue_redraw()
			elif mouse.pressed and tool == "add":
				point_added.emit(to_world(mouse.position), _nearest_segment(to_world(mouse.position)))
			elif mouse.pressed and mouse.double_click:
				point_added.emit(to_world(mouse.position), _nearest_segment(to_world(mouse.position)))
			elif mouse.pressed:
				var hit: int = _hit_point(mouse.position)
				if hit >= 0:
					selected = hit
					point_selected.emit(hit)
					edit_started.emit()
					_dragging = true
					queue_redraw()
			else:
				if tool == "draw" and not _freehand.is_empty():
					if _freehand.size() > 1:
						freehand_finished.emit(_freehand.duplicate())
					_freehand.clear()
				_dragging = false
		accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _panning:
			center -= motion.relative / zoom
			queue_redraw()
		elif _dragging:
			var world: Vector2 = to_world(motion.position)
			if motion.shift_pressed:
				world = world.snapped(Vector2(10.0, 10.0))
			point_moved.emit(selected, world)
		elif tool == "draw" and not _freehand.is_empty():
			var world: Vector2 = to_world(motion.position)
			if _freehand[-1].distance_to(world) >= maxf(2.0, 8.0 / zoom):
				_freehand.append(world)
				queue_redraw()
	elif event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed:
			if key.keycode == KEY_DELETE:
				delete_requested.emit(selected)
				accept_event()
			elif key.ctrl_pressed and key.keycode == KEY_Z:
				redo_requested.emit() if key.shift_pressed else undo_requested.emit()
				accept_event()
			elif key.keycode == KEY_F:
				fit()
				accept_event()

func to_screen(world: Vector2) -> Vector2:
	return (world - center) * zoom + size * 0.5

func to_world(screen: Vector2) -> Vector2:
	return (screen - size * 0.5) / zoom + center

func _hit_point(screen: Vector2) -> int:
	var points: Array = definition.get("points", [])
	var found: int = -1
	var distance: float = 17.0
	for index: int in range(points.size()):
		var current: float = to_screen(_xz(points[index])).distance_to(screen)
		if current < distance:
			distance = current
			found = index
	return found

func _nearest_segment(world: Vector2) -> int:
	var points: Array = definition.get("points", [])
	var best: float = INF
	var index: int = 0
	var closed: bool = bool(definition.get("closed", true))
	for i: int in range(points.size() if closed else points.size() - 1):
		var a: Vector2 = _xz(points[i])
		var b: Vector2 = _xz(points[(i + 1) % points.size()])
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(world, a, b)
		if closest.distance_squared_to(world) < best:
			best = closest.distance_squared_to(world)
			index = i
	if not closed and points.size() > 1:
		var end: Vector2 = _xz(points[-1])
		if (world - end).dot(end - _xz(points[-2])) > 0 and world.distance_squared_to(end) <= best + 1.0:
			return points.size() - 1
	return index

func _xz(point: Dictionary) -> Vector2:
	return Vector2(float(point["x"]), float(point["z"]))

func _background() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.09)
	style.set_corner_radius_all(12)
	return style
