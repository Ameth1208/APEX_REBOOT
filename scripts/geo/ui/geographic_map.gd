class_name GeographicMap
extends Control

signal point_added(lat: float, lon: float)
signal undo_requested
signal message(text: String)

var coordinates: Array = []
var closed: bool = false
var level: int = 14
var latitude: float = 4.651
var longitude: float = -74.092
var tiles: MapTileCache
var _panning: bool = false

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	custom_minimum_size = Vector2(480, 320)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	tiles = MapTileCache.new()
	add_child(tiles)
	tiles.changed.connect(queue_redraw)
	tiles.message.connect(func(text: String) -> void: message.emit(text))
	resized.connect(_view_changed)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree(): _view_changed()
		else: tiles.stop())

func center_on(lat: float, lon: float) -> void:
	latitude = clampf(lat, -80.0, 80.0)
	longitude = clampf(lon, -180.0, 180.0)
	_view_changed()

func fit_route() -> void:
	if coordinates.is_empty():
		return
	var bounds: Rect2 = Rect2(MercatorTiles.pixel(float(coordinates[0].lat), float(coordinates[0].lon), 18), Vector2.ZERO)
	for point: Dictionary in coordinates:
		bounds = bounds.expand(MercatorTiles.pixel(float(point.lat), float(point.lon), 18))
	var center: Vector2 = MercatorTiles.coordinate(bounds.get_center(), 18)
	latitude = center.x
	longitude = center.y
	level = 18
	while level > 4 and (bounds.size.x / pow(2.0, 18 - level) > size.x - 90.0 or bounds.size.y / pow(2.0, 18 - level) > size.y - 90.0):
		level -= 1
	_view_changed()

func _view_changed() -> void:
	if not is_instance_valid(tiles) or not is_visible_in_tree():
		return
	var top: Vector2 = _top_left()
	var keys: Array[String] = []
	for x: int in range(floori(top.x / 256.0), ceili((top.x + size.x) / 256.0)):
		for y: int in range(floori(top.y / 256.0), ceili((top.y + size.y) / 256.0)):
			if y >= 0 and y < (1 << level):
				keys.append(MercatorTiles.tile_key(level, x, y))
	tiles.show_tiles(keys)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("17242d"))
	if not is_instance_valid(tiles):
		return
	var top: Vector2 = _top_left()
	for x: int in range(floori(top.x / 256.0), ceili((top.x + size.x) / 256.0)):
		for y: int in range(floori(top.y / 256.0), ceili((top.y + size.y) / 256.0)):
			var rect: Rect2 = Rect2(Vector2(x, y) * 256.0 - top, Vector2(256, 256))
			var key: String = MercatorTiles.tile_key(level, x, y)
			if tiles.textures.has(key):
				draw_texture_rect(tiles.textures[key], rect, false, Color(0.82, 0.87, 0.88))
			else:
				draw_rect(rect, Color("293a44"), false, 1.0)
	var path: PackedVector2Array = PackedVector2Array()
	for point: Dictionary in coordinates:
		path.append(MercatorTiles.pixel(float(point.lat), float(point.lon), level) - top)
	if closed and path.size() > 2:
		path.append(path[0])
	if path.size() > 1:
		draw_polyline(path, Color("142021"), 8.0, true)
		draw_polyline(path, Color("caff62"), 4.0, true)
	for index: int in range(coordinates.size()):
		var point: Vector2 = path[index]
		draw_circle(point, 5.0, Color("102229"))
		draw_circle(point, 3.0, Color("f1ffe0"))
		if index == 0 or index == coordinates.size() - 1:
			draw_circle(point, 11.0, Color("152029"))
			draw_string(ThemeDB.fallback_font, point + Vector2(-4, 5), "S" if index == 0 else "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("caff62"))
	draw_rect(Rect2(10, 10, 210, 27), Color(0.04, 0.08, 0.10, 0.88))
	draw_string(ThemeDB.fallback_font, Vector2(18, 29), "%.5f, %.5f · z%d" % [latitude, longitude, level], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mouse.pressed
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			var coordinate: Vector2 = MercatorTiles.coordinate(_top_left() + mouse.position, level)
			point_added.emit(coordinate.x, coordinate.y)
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
			undo_requested.emit()
		elif mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var anchor: Vector2 = MercatorTiles.coordinate(_top_left() + mouse.position, level)
			level = clampi(level + (1 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 4, 19)
			var center: Vector2 = MercatorTiles.coordinate(MercatorTiles.pixel(anchor.x, anchor.y, level) - mouse.position + size * 0.5, level)
			latitude = center.x
			longitude = center.y
			_view_changed()
		accept_event()
	elif event is InputEventMouseMotion and _panning:
		var center: Vector2 = MercatorTiles.coordinate(MercatorTiles.pixel(latitude, longitude, level) - event.relative, level)
		latitude = clampf(center.x, -80.0, 80.0)
		longitude = center.y
		_view_changed()

func _top_left() -> Vector2:
	return MercatorTiles.pixel(latitude, longitude, level) - size * 0.5
