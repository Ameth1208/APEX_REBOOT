class_name RealRouteDialog
extends Control

signal created(definition: Dictionary)

var ui: Dictionary = {}
var draft: Dictionary = {}
var _points: Array = []
var _original: Array = []
var _text: String = ""
var _filename: String = ""
var _loading: bool = false
var _original_closed: bool = false
var _sample_spacing: float = 0.0
var _elevation_source: String = ""
var _terrain_grid_spacing: int = 0
var _pending_sample_spacing: float = 0.0
var _pending_grid_spacing: int = 0
var _source_needs_terrain: bool = false
var _picker: RouteFilePicker
var _elevation: ElevationProvider
var _planner: RoutePlanner

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui = RouteDialogLayout.build(self)
	_picker = RouteFilePicker.new()
	add_child(_picker)
	_elevation = ElevationProvider.new()
	add_child(_elevation)
	_planner = RoutePlanner.new()
	add_child(_planner)
	ui.close.pressed.connect(_close)
	ui.import_button.pressed.connect(_picker.choose)
	ui.go.pressed.connect(func() -> void: ui.map.center_on(ui.lat.value, ui.lon.value))
	ui.fit.pressed.connect(func() -> void: ui.map.fit_route())
	ui.layer.toggled.connect(func(value: bool) -> void: ui.map.set_satellite(value))
	ui.map.call_deferred("set_satellite", true)
	ui.undo.pressed.connect(_undo)
	ui.clear.pressed.connect(_clear_route)
	ui.closed.toggled.connect(func(_value: bool) -> void: _refresh())
	ui.elevate.pressed.connect(_lookup)
	ui.cancel.pressed.connect(func() -> void: _elevation.cancel(); _busy(false); _message("Consulta cancelada. Tu trazado se conserva."))
	ui.create.pressed.connect(_create)
	ui.plan.pressed.connect(_plan_route)
	ui.routes.item_selected.connect(_select_route)
	ui.map.point_added.connect(_add_point)
	ui.map.undo_requested.connect(_undo)
	ui.map.message.connect(_message)
	_picker.loaded.connect(_import_text)
	_picker.failed.connect(_message)
	_elevation.message.connect(_message)
	_elevation.failed.connect(func(text: String) -> void: _busy(false); _message(text))
	_elevation.completed.connect(_elevated)
	_planner.route_ready.connect(_planned_route)
	_planner.failed.connect(func(text: String) -> void: _busy(false); _message(text))
	hide()

func open(definition: Dictionary = {}) -> void:
	_filename = ""
	_text = ""
	draft = {}
	_points.clear()
	_original.clear()
	_original_closed = false
	_source_needs_terrain = false
	_reset_elevation()
	ui.routes.hide()
	ui.name.text = "Mi ruta real"
	ui.start.text = "Baranoa, Atlántico"
	ui.finish.text = "Juan de Acosta, Atlántico"
	ui.plan_status.text = "Ruta vial automática disponible. También puedes importar un GPX o añadir puntos en el mapa."
	ui.flat.button_pressed = false
	ui.layer.button_pressed = true
	ui.map.set_satellite(true)
	ui.closed.button_pressed = false
	if definition.has("geo"):
		var geo: Dictionary = definition.geo
		_source_needs_terrain = bool(geo.get("is_flat_test", false)) or str(geo.get("elevation_status", "")) != "complete"
		_sample_spacing = float(geo.get("elevation_sample_spacing_m", 0.0))
		_elevation_source = str(geo.get("terrain_elevation_provider", ""))
		_terrain_grid_spacing = int(geo.get("terrain_grid_spacing_m", 0))
		for point: Dictionary in definition.get("points", []):
			var projected: Dictionary = GeoProjection.inverse(float(point.x), float(point.z), geo, point.y)
			if projected.get("ok", false):
				var existing_elevation: Variant = projected.ele
				if _source_needs_terrain:
					existing_elevation = null
				_points.append({"lat": projected.lat, "lon": projected.lon, "ele": existing_elevation,
					"elevation_source": "missing" if existing_elevation == null else "editor"})
		_original = definition.get("raw_route", []).duplicate(true)
		_original_closed = bool(geo.get("raw_closed", false))
		ui.flat.button_pressed = bool(geo.get("is_flat_test", false))
		ui.name.text = str(definition.get("name", "Mi ruta real"))
		ui.closed.button_pressed = bool(definition.get("closed", false))
	show()
	_refresh()
	if not _points.is_empty():
		ui.map.call_deferred("fit_route")
		if _source_needs_terrain:
			ui.plan_status.text = "Esta fuente es plana. Consultando automáticamente el relieve real de la carretera…"
			call_deferred("_lookup")
	else:
		ui.map.center_on(ui.lat.value, ui.lon.value)

func _import_text(text: String, filename: String) -> void:
	var parsed: Dictionary = RouteImporter.parse(text, filename.get_extension())
	if not parsed.get("ok", false):
		_message(str(parsed.get("error", "Archivo no válido.")))
		return
	_text = text
	_filename = filename
	ui.routes.clear()
	for route: Dictionary in parsed.get("routes", []):
		ui.routes.add_item("%s · %d puntos" % [str(route.name), int(route.point_count)])
	ui.routes.visible = ui.routes.item_count > 1
	_accept_import(parsed)

func _select_route(index: int) -> void:
	_accept_import(RouteImporter.parse(_text, _filename.get_extension(), index))

func _accept_import(parsed: Dictionary) -> void:
	if not parsed.get("ok", false):
		_message(str(parsed.get("error", "No se pudo importar esa ruta.")))
		return
	draft = parsed.definition
	_reset_elevation()
	_points = draft.get("control_route", draft.get("raw_route", [])).duplicate(true)
	_original = draft.get("raw_route", []).duplicate(true)
	_original_closed = bool(draft.geo.get("raw_closed", false))
	ui.name.text = str(draft.get("name", _filename.get_basename()))
	ui.closed.button_pressed = bool(draft.get("closed", false))
	ui.flat.button_pressed = false
	_refresh()
	ui.map.fit_route()
	_message("Importado: %s. %s" % [_filename, " ".join(parsed.get("warnings", []))])

func _clear_route() -> void:
	_points.clear()
	_original.clear()
	_original_closed = false
	_filename = ""
	_text = ""
	draft = {}
	_reset_elevation()
	ui.routes.clear()
	ui.routes.hide()
	ui.flat.button_pressed = false
	_refresh()
	_message("Ruta vacía. Dibuja nuevos puntos o importa un archivo.")

func _plan_route() -> void:
	if _loading:
		return
	_busy(true)
	ui.plan_status.text = "Buscando salida, llegada y carretera…"
	_planner.plan(ui.start.text, ui.finish.text)

func _planned_route(points: Array, start_label: String, finish_label: String) -> void:
	_points = points
	_original = points.duplicate(true)
	_original_closed = false
	_filename = ""
	ui.name.text = "%s → %s" % [start_label, finish_label]
	ui.closed.button_pressed = false
	ui.plan_status.text = "Ruta generada siguiendo carreteras. Ahora pulsa ADAPTAR AL TERRENO para obtener las cotas."
	_busy(false)
	_refresh()
	ui.map.fit_route()
	_message("Ruta lista · %d puntos viales. Puedes añadir o quitar puntos en el mapa." % points.size())

func _reset_elevation() -> void:
	_sample_spacing = 0.0
	_elevation_source = ""
	_terrain_grid_spacing = 0
	_pending_sample_spacing = 0.0
	_pending_grid_spacing = 0

func _add_point(lat: float, lon: float) -> void:
	if _elevation.busy:
		return
	if _points.size() >= 512:
		_message("Máximo de 512 puntos editables. Recorta la ruta para conservar el detalle.")
		return
	_points.append({"lat": lat, "lon": lon, "ele": null, "elevation_source": "missing"})
	_refresh()

func _undo() -> void:
	if not _points.is_empty() and not _elevation.busy:
		_points.pop_back()
		_refresh()

func _refresh() -> void:
	ui.map.coordinates = _points
	ui.map.closed = ui.closed.button_pressed
	ui.map.queue_redraw()
	var known: int = 0
	for point: Dictionary in _points:
		if point.get("ele") != null:
			known += 1
	ui.summary.text = "%d puntos · %d con cota\n%s" % [_points.size(), known, "Circuito cerrado" if ui.closed.button_pressed else "Ruta de salida a llegada"]
	ui.create.disabled = _points.size() < (4 if ui.closed.button_pressed else 2) or _loading
	ui.elevate.disabled = _points.size() < 2 or _loading

func _lookup() -> void:
	var parsed: Dictionary = RouteImporter.from_points(_points, ui.name.text, "map", ui.closed.button_pressed)
	if not parsed.get("ok", false):
		_message(str(parsed.get("error", "Ruta no válida.")))
		return
	var sampled: Dictionary = RouteImporter.elevation_samples(parsed.definition, 50.0)
	if not sampled.get("ok", false):
		_message(str(sampled.get("error", "No se pudo muestrear el recorrido.")))
		return
	if _original.is_empty():
		_original = _points.duplicate(true)
		_original_closed = ui.closed.button_pressed
	_pending_sample_spacing = float(sampled.get("max_interval_m", sampled.get("spacing_m", 50.0)))
	_pending_grid_spacing = 30 if ui.provider.selected == 0 else 90
	_busy(true)
	_elevation.lookup(sampled.points, ui.provider.selected, ui.replace.button_pressed)

func _elevated(points: Array, source: String) -> void:
	_points = points
	var has_dem: bool = points.any(func(point: Dictionary) -> bool: return str(point.get("elevation_source", "")) == source)
	_elevation_source = source if has_dem else ""
	_terrain_grid_spacing = _pending_grid_spacing if has_dem else 0
	_sample_spacing = _pending_sample_spacing
	ui.flat.button_pressed = false
	_busy(false)
	_message("Cotas listas · %s · separación entre muestras ≤ %.1f m. Revisa puentes y túneles." % [source if has_dem else "cotas existentes conservadas", _sample_spacing])

func _create() -> void:
	if _loading:
		return
	var points: Array = _points.duplicate(true)
	if ui.flat.button_pressed:
		for point: Dictionary in points:
			point["ele"] = 0.0
			point["elevation_source"] = "manual_flat"
	var parsed: Dictionary = RouteImporter.from_points(points, ui.name.text, "map" if _filename.is_empty() else _filename, ui.closed.button_pressed)
	if not parsed.get("ok", false):
		_message(str(parsed.get("error", "Ruta no válida.")))
		return
	draft = parsed.definition
	if draft.get("requires_elevation", false):
		_message("Faltan cotas. Pulsa Obtener cotas o selecciona explícitamente el plano de prueba.")
		return
	for point: Dictionary in draft.points:
		point["width"] = ui.width.value
	if not _original.is_empty():
		draft = RouteImporter.attach_original(draft, _original, _original_closed)
	draft.geo["is_flat_test"] = ui.flat.button_pressed
	draft.geo["elevation_sample_spacing_m"] = 0.0 if ui.flat.button_pressed else _sample_spacing
	if not _elevation_source.is_empty() and not ui.flat.button_pressed:
		draft.geo["terrain_elevation_provider"] = _elevation_source
		draft.geo["terrain_grid_spacing_m"] = _terrain_grid_spacing
	_close()
	created.emit(draft)

func _busy(value: bool) -> void:
	_loading = value
	ui.cancel.visible = value
	for key: String in ["import_button", "undo", "clear", "closed", "replace", "provider", "routes", "plan"]:
		ui[key].disabled = value
	ui.start.editable = not value
	ui.finish.editable = not value
	ui.map.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	_refresh()

func _message(text: String) -> void:
	ui.status.text = text

func _close() -> void:
	_elevation.cancel()
	_busy(false)
	ui.map.tiles.stop()
	hide()
