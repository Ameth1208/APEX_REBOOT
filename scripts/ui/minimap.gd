class_name ApexMinimap
extends Control
## A free-standing track outline, fitted to its real bounds and current HUD size.

var track: Node3D
var vehicles: Array = []
var _raw := PackedVector2Array()
var _points := PackedVector2Array()
var _minimum := Vector2.ZERO
var _dimensions := Vector2.ONE
var _origin := Vector2.ZERO
var _scale: float = 1.0

func configure(circuit: Node3D) -> void:
	track = circuit
	custom_minimum_size = Vector2(228, 176)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raw.clear()
	_points.clear()
	var maximum := Vector2(-INF, -INF)
	_minimum = Vector2(INF, INF)
	for index: int in 220:
		var position_3d: Vector3 = track.sample_at(index * track.get_length() / 219.0).position
		var point := Vector2(position_3d.x, position_3d.z)
		_raw.append(point)
		_minimum = _minimum.min(point)
		maximum = maximum.max(point)
	_dimensions = (maximum - _minimum).max(Vector2.ONE)
	if not resized.is_connected(_fit):
		resized.connect(_fit)
	_fit()

func _fit() -> void:
	var area := (size - Vector2(30, 30)).max(Vector2.ONE)
	_scale = minf(area.x / _dimensions.x, area.y / _dimensions.y)
	_origin = (size - _dimensions * _scale) * 0.5
	_points.clear()
	for point: Vector2 in _raw:
		_points.append(_project(point))
	queue_redraw()

func _project(point: Vector2) -> Vector2:
	return (point - _minimum) * _scale + _origin

func _draw() -> void:
	if _points.size() < 2:
		return
	draw_polyline(_points, Color(0.015, 0.02, 0.03, 0.85), 8.0, true)
	draw_polyline(_points, Color(0.9, 0.93, 0.97, 0.9), 2.8, true)
	var start: Vector2 = _points[0]
	draw_circle(start, 4.0, Color("f3f5f8"))
	if not track.closed:
		draw_rect(Rect2(_points[-1] - Vector2(4, 4), Vector2(8, 8)), Color("f3f5f8"))
	# Draw the player last so tightly packed grid markers never cover its arrow.
	for index: int in range(vehicles.size() - 1, -1, -1):
		if not is_instance_valid(vehicles[index]):
			continue
		var position_3d: Vector3 = vehicles[index].global_position
		var point: Vector2 = _project(Vector2(position_3d.x, position_3d.z))
		point = point.clamp(Vector2(9, 9), size - Vector2(9, 9))
		if index == 0:
			_draw_player(point, vehicles[index].global_basis)
		else:
			draw_circle(point, 4.6, Color(0.015, 0.02, 0.03, 0.9))
			draw_circle(point, 3.0, Color("f3f5f8"))

func _draw_player(point: Vector2, orientation: Basis) -> void:
	var forward: Vector3 = -orientation.z
	var direction := Vector2(forward.x, forward.z).normalized()
	if direction.length_squared() < 0.1:
		direction = Vector2.UP
	var side := Vector2(-direction.y, direction.x)
	var arrow := PackedVector2Array([
		point + direction * 8, point - direction * 5 + side * 5,
		point - direction * 3, point - direction * 5 - side * 5])
	draw_colored_polygon(arrow, Color("ff4b55"))
	arrow.append(arrow[0])
	draw_polyline(arrow, Color("10151e"), 1.5, true)
