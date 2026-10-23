class_name TrackEditor
extends Control

const LayoutValidation: Script = preload("res://scripts/tracks/track_validation.gd")

signal applied(definition: Dictionary)
signal closed

var _definition: Dictionary = {}
var _selected: int = 0
var _history: Array[Dictionary] = []
var _future: Array[Dictionary] = []
var _map: TrackMap
var _fields: TrackEditorFields
var _status: Label
var _storage: TrackEditorStorage = TrackEditorStorage.new()
var _profile: RouteProfilePanel
var _real_route: RealRouteDialog

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	hide()

func open(definition: Dictionary) -> void:
	_definition = TrackDefinition.clean(definition)
	_selected = 0
	_history.clear()
	_future.clear()
	show()
	_refresh()
	_map.call_deferred("fit")
	_status.text = "Edita la trayectoria en el mapa y ajusta altura, peralte y material de cada tramo."

func _build() -> void:
	var ui: Dictionary = TrackEditorLayout.build(self)
	_map = ui.map
	_fields = ui.fields
	_status = ui.status
	_profile = ui.profile
	var buttons: Dictionary = ui.buttons
	buttons.close.pressed.connect(_close)
	buttons.undo.pressed.connect(_undo)
	buttons.redo.pressed.connect(_redo)
	buttons.fit.pressed.connect(func() -> void: _map.fit())
	buttons.save.pressed.connect(func() -> void: _storage.save_local(_definition))
	buttons.load.pressed.connect(func() -> void: _storage.choose("load", _definition))
	buttons.import.pressed.connect(func() -> void: _storage.choose("import", _definition))
	buttons.export.pressed.connect(func() -> void: _storage.choose("export", _definition))
	buttons.apply.pressed.connect(_apply)
	_map.point_selected.connect(func(index: int) -> void: _select_point(index); _profile.select_control(index))
	_map.edit_started.connect(_snapshot)
	_map.point_moved.connect(_move_point)
	_map.point_added.connect(_add_point)
	_map.delete_requested.connect(_delete_point)
	_fields.changed.connect(_field_changed)
	_fields.delete_pressed.connect(func() -> void: _delete_point(_selected))
	_fields.texture_pressed.connect(func(surface: String) -> void: _storage.choose("texture", _definition, surface))
	_profile.control_selected.connect(_select_point)
	_storage.setup(self)
	_storage.loaded.connect(open)
	_storage.message.connect(func(text: String) -> void: _status.text = text)
	_storage.texture_chosen.connect(_texture_chosen)
	_real_route = RealRouteDialog.new()
	add_child(_real_route)
	buttons.real_route.pressed.connect(func() -> void: _real_route.open(_definition))
	_real_route.created.connect(func(definition: Dictionary) -> void:
		_snapshot()
		_definition = definition
		_selected = 0
		_refresh()
		_map.fit()
		_status.text = "Ruta geográfica importada. Revisa el perfil, anchura, peralte y puentes antes de conducir.")

func _select_point(index: int) -> void:
	_selected = clampi(index, 0, _definition["points"].size() - 1)
	_map.selected = _selected
	_map.queue_redraw()
	_fields.show_point(_definition, _selected)

func _snapshot() -> void:
	_history.append(TrackHistory.snapshot(_definition))
	if _history.size() > 64:
		_history.pop_front()
	_future.clear()

func _refresh() -> void:
	_selected = clampi(_selected, 0, _definition["points"].size() - 1)
	_map.set_definition(_definition, _selected)
	_fields.show_point(_definition, _selected)
	_profile.set_definition(_definition)

func _move_point(index: int, point: Vector2) -> void:
	_mark_edited()
	_definition["points"][index]["x"] = snappedf(point.x, 0.1)
	_definition["points"][index]["z"] = snappedf(point.y, 0.1)
	_refresh()

func _add_point(point: Vector2, after: int) -> void:
	var points: Array = _definition["points"]
	if points.size() >= 512:
		_status.text = "Máximo de 512 puntos editables por pista."
		return
	_snapshot()
	var new_point: Dictionary = points[after].duplicate(true)
	new_point["x"] = snappedf(point.x, 0.1)
	new_point["z"] = snappedf(point.y, 0.1)
	var following: int = (after + 1) % points.size() if _definition.get("closed", true) else mini(after + 1, points.size() - 1)
	new_point["y"] = (float(points[after]["y"]) + float(points[following]["y"])) * 0.5
	_mark_edited()
	points.insert(after + 1, new_point)
	_selected = after + 1
	_refresh()

func _delete_point(index: int) -> void:
	var minimum: int = 4 if _definition.get("closed", true) else 2
	if _definition["points"].size() <= minimum:
		_status.text = "Esta pista necesita al menos %d puntos." % minimum
		return
	_snapshot()
	_mark_edited()
	_definition["points"].remove_at(index)
	_refresh()

func _field_changed(key: String, value: Variant) -> void:
	if key == "closed" and bool(value) and _definition["points"].size() < 4:
		_status.text = "Añade al menos cuatro puntos para cerrar el circuito."
		_refresh()
		return
	_snapshot()
	if key == "name":
		# Reassigning a LineEdit on every keystroke resets its caret and IME.
		# A label edit also needs no geometry or elevation-profile rebuild.
		_definition[key] = value
		return
	_mark_edited()
	if key in ["x", "y", "z", "width", "bank", "surface"]:
		_definition["points"][_selected][key] = value
	else:
		_definition[key] = value
	if key in ["x", "y", "z", "bank", "closed", "interpolation"]:
		_refresh()
	else:
		_map.set_definition(_definition, _selected)
		_fields.show_point(_definition, _selected)

func _mark_edited() -> void:
	if _definition.has("geo"):
		_definition.geo["edited_after_import"] = true

func _texture_chosen(surface: String, path: String) -> void:
	_snapshot()
	if not _definition.has("surface_textures"):
		_definition["surface_textures"] = {}
	_definition["surface_textures"][surface] = path

func _undo() -> void:
	if _history.is_empty():
		return
	_future.append(TrackHistory.snapshot(_definition))
	_definition = _history.pop_back()
	_refresh()

func _redo() -> void:
	if _future.is_empty():
		return
	_history.append(TrackHistory.snapshot(_definition))
	_definition = _future.pop_back()
	_refresh()

func _apply() -> void:
	var source_error: String = LayoutValidation.source_error(_definition)
	if not source_error.is_empty():
		_status.text = source_error
		return
	var clean: Dictionary = TrackDefinition.clean(_definition)
	var check: TrackSampler = TrackSampler.new()
	check.rebuild(clean)
	var error: String = LayoutValidation.layout_error(check, float(clean["thickness"]))
	if not error.is_empty():
		_status.text = error
		return
	hide()
	applied.emit(clean)

func _close() -> void:
	hide()
	closed.emit()
