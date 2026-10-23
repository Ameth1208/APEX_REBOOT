extends SceneTree
## Import/editor integration: no external services required.

var failures: Array[String] = []
var editor: TrackEditor
var received: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for coordinate: Vector2 in [Vector2(4.651, -74.092), Vector2(-33.86, 151.21), Vector2(51.5, -0.12)]:
		var roundtrip: Vector2 = MercatorTiles.coordinate(MercatorTiles.pixel(coordinate.x, coordinate.y, 14), 14)
		# Godot's Vector2 stores float32 pixels; allow less than half a pixel at z14.
		_check(coordinate.distance_to(roundtrip) < 0.00003, "Map projection preserves hemisphere and location: " + str(roundtrip))
	var screen: Control = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.theme = ApexUI.make_theme()
	root.add_child(screen)
	editor = TrackEditor.new()
	screen.add_child(editor)
	editor._real_route.ui.map.tiles.enabled = false
	editor.open(TrackDefinition.clean({}))
	await process_frame
	_check(editor._profile.analysis.get("ok", false), "Native track analysis initializes")
	_check(not editor._profile._chart.profile.is_empty() and editor._profile._chart.profile[0].elevation_m != null, "Local heights remain visible without geographic metadata")
	var dialog: RealRouteDialog = editor._real_route
	dialog.open()
	var text: String = '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"name":"Prueba sintética A"},"geometry":{"type":"LineString","coordinates":[[-74.09,4.65,2600],[-74.09,4.652,2620],[-74.091,4.654,2645],[-74.092,4.656,2630]]}},{"type":"Feature","properties":{"name":"Prueba sintética B"},"geometry":{"type":"LineString","coordinates":[[-74.092,4.65],[-74.092,4.656]]}}]}'
	dialog._import_text(text, "synthetic_routes.geojson")
	_check(dialog.ui.routes.item_count == 2, "Separate tracks offered in selector")
	_check(dialog._points.size() == 4, "First feature selected without joining routes")
	dialog._create()
	_check(editor._definition.has("geo") and not editor._definition.closed, "Create geographic open track in editor")
	_check(editor._definition.raw_route.size() == 4, "Original route retained")
	_check(editor._profile.analysis.constructed.geometry_exact, "Profile uses current constructed geometry")
	var original_height: float = float(editor._definition.raw_route[1].ele)
	editor._select_point(1)
	editor._field_changed("y", 123.0)
	_check(float(editor._definition.raw_route[1].ele) == original_height, "Editing road leaves original elevation immutable")
	editor._undo()
	_check(absf(float(editor._definition.points[1].y) - 20.0) < 0.01, "Undo restores imported control height")
	dialog.open()
	dialog._import_text(text, "synthetic_routes.geojson")
	dialog._select_route(1)
	dialog._create()
	_check(dialog.visible and "Faltan cotas" in dialog.ui.status.text, "Unknown elevations cannot silently create flat road")
	dialog.ui.flat.button_pressed = true
	dialog._create()
	_check(not dialog.visible and editor._definition.geo.is_flat_test, "Explicit flat test is labelled and accepted")
	_check(not editor._definition.requires_elevation, "Flat opt-in produces buildable numeric controls")
	editor.applied.connect(func(definition: Dictionary) -> void: received = definition)
	editor._apply()
	_check(not received.is_empty() and not received.closed, "Open route survives validation and apply")
	var path: String = "user://geo_ui_roundtrip.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(received))
	file.close()
	editor._storage._read(path)
	_check(editor.visible and not editor._definition.closed, "Native JSON import retains open route")
	screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("GEO_UI_CHECKS PASS")
	else:
		for failure: String in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, text: String) -> void:
	if not condition:
		failures.append(text)
