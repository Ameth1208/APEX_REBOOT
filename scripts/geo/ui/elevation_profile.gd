class_name ElevationProfile
extends Control

signal sample_selected(sample: Dictionary)

var profile: Array = []
var selected: int = -1
var absolute_elevation: bool = false
var _bounds: Vector2 = Vector2.ZERO
var _distance: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(360, 150)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func set_profile(points: Array, absolute: bool) -> void:
	profile = points
	absolute_elevation = absolute
	_bounds = Vector2(INF, -INF)
	_distance = 0.0
	for point: Dictionary in points:
		_distance = maxf(_distance, float(point.get("distance_m", 0.0)))
		if point.get("elevation_m") != null:
			_bounds.x = minf(_bounds.x, float(point.elevation_m))
			_bounds.y = maxf(_bounds.y, float(point.elevation_m))
	if not is_finite(_bounds.x):
		_bounds = Vector2(0, 1)
	selected = clampi(selected, -1, profile.size() - 1)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101a22"))
	var rect: Rect2 = _plot()
	for i: int in range(4):
		var ratio: float = float(i) / 3.0
		var y: float = rect.end.y - ratio * rect.size.y
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("26353d"))
		draw_string(ThemeDB.fallback_font, Vector2(6, y + 4), "%.0f" % lerpf(_bounds.x, _bounds.y, ratio), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8da2ad"))
	if profile.size() < 2:
		draw_string(ThemeDB.fallback_font, Vector2(70, 65), "Añade una ruta para analizar su perfil.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	for index: int in range(1, profile.size()):
		var a: Dictionary = profile[index - 1]
		var b: Dictionary = profile[index]
		if a.get("elevation_m") == null or b.get("elevation_m") == null:
			continue
		var grade: float = float(b.grade_pct) if b.get("grade_pct") != null else 0.0
		draw_line(_position(a), _position(b), grade_color(grade), 2.5, true)
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, size.y - 6), "0 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8da2ad"))
	draw_string(ThemeDB.fallback_font, Vector2(rect.end.x - 70, size.y - 6), "%.2f km" % (_distance / 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8da2ad"))
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 45, size.y - 6), "Distancia horizontal · cota " + ("del archivo/proveedor" if absolute_elevation else "local") + " en m", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8da2ad"))
	if selected >= 0 and selected < profile.size():
		var point: Dictionary = profile[selected]
		var x: float = rect.position.x + float(point.distance_m) / maxf(1.0, _distance) * rect.size.x
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color("ffffff"), 1.0)
		if point.get("elevation_m") != null:
			draw_circle(_position(point), 4, Color("ffffff"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var distance: float = clampf((event.position.x - _plot().position.x) / _plot().size.x, 0, 1) * _distance
		var error: float = INF
		for index: int in range(profile.size()):
			var delta: float = absf(float(profile[index].distance_m) - distance)
			if delta < error:
				error = delta
				selected = index
		if selected >= 0:
			sample_selected.emit(profile[selected])
		queue_redraw()
		accept_event()

func _plot() -> Rect2:
	return Rect2(55, 12, maxf(1, size.x - 72), maxf(1, size.y - 36))

func _position(point: Dictionary) -> Vector2:
	var rect: Rect2 = _plot()
	return Vector2(rect.position.x + float(point.distance_m) / maxf(1.0, _distance) * rect.size.x,
		rect.end.y - (float(point.elevation_m) - _bounds.x) / maxf(1.0, _bounds.y - _bounds.x) * rect.size.y)

static func grade_color(grade: float) -> Color:
	if grade < -1.0:
		return Color("63d4f5").lerp(Color("8381ff"), clampf(-grade / 20.0, 0, 1))
	return Color("caff62").lerp(Color("ff795f"), clampf(grade / 18.0, 0, 1))
