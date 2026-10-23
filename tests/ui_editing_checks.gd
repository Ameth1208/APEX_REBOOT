extends SceneTree
## Real text input, immutable history and responsive garage/editor regressions.

var failures: Array[String] = []
var checks: int = 0
var screen: Control

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.theme = ApexUI.make_theme()
	root.add_child(screen)
	await _editing()
	_history()
	await _menus()
	screen.queue_free()
	await process_frame
	print("UI_EDITING_CHECKS ", "PASS" if failures.is_empty() else "FAIL", " ", checks, " ", failures)
	quit(0 if failures.is_empty() else 1)

func _editing() -> void:
	var editor := TrackEditor.new()
	screen.add_child(editor)
	var source: Dictionary = ApexCatalog.track(0)
	source["name"] = "Costa Clara"
	editor.open(source)
	editor._real_route.ui.map.tiles.enabled = false
	await process_frame
	var name_field: LineEdit = editor._fields._inputs.name
	name_field.grab_focus()
	name_field.caret_column = 6
	var initial_analysis: Dictionary = editor._profile.analysis
	for character: String in "Nueva ":
		_type(character)
		await process_frame
	_check(name_field.text == "Costa Nueva Clara", "Typing inside a name retains character order")
	_check(name_field.caret_column == 12, "Caret advances from insertion point, not from start")
	_check(name_field.has_focus(), "Text input retains focus after model updates")
	_check(editor._definition.name == name_field.text, "Model receives complete live text")
	_check(is_same(initial_analysis, editor._profile.analysis), "Renaming does not recompute elevation analysis")
	name_field.select(6, 11)
	editor._fields.show_point(editor._definition, editor._selected)
	_check(name_field.has_selection() and name_field.get_selected_text() == "Nueva", "Unchanged refresh preserves selection")
	name_field.deselect()
	editor._undo()
	_check(editor._definition.name == "Costa NuevaClara", "Undo restores the preceding text edit")
	editor._redo()
	_check(editor._definition.name == "Costa Nueva Clara", "Redo restores final name")
	var width: SpinBox = editor._fields._inputs.width
	width.get_line_edit().grab_focus()
	width.get_line_edit().text = "-"
	width.get_line_edit().caret_column = 1
	editor._fields.show_point(editor._definition, editor._selected)
	_check(width.get_line_edit().text == "-" and width.get_line_edit().caret_column == 1, "Numeric draft is not overwritten by a no-op refresh")
	for resolution: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _resize(resolution)
		_check(_inside(editor._map), "Editor map fits " + str(resolution))
		_check(_inside(editor._status), "Editor status fits " + str(resolution))
		if editor._profile._compact:
			editor._profile._toggle.button_pressed = true
			await process_frame
			await process_frame
			_check(_inside(editor._profile._chart) and _inside(editor._status), "Expanded compact profile fits alongside map")
			editor._profile._toggle.button_pressed = false
	editor.queue_free()
	await process_frame

func _history() -> void:
	var definition: Dictionary = ApexCatalog.track(0)
	definition["source_auxiliary_geojson_features"] = [{"type": "LineString", "coordinates": [[-74.0, 10.0], [-74.1, 10.1]]}]
	definition["source_properties"] = {"name": "source"}
	definition["conversion"] = {"source": "original"}
	var snapshot: Dictionary = TrackHistory.snapshot(definition)
	_check(is_same(snapshot.source_auxiliary_geojson_features, definition.source_auxiliary_geojson_features), "Immutable source layers are not cloned per keystroke")
	_check(is_same(snapshot.source_properties, definition.source_properties), "Source metadata is shared by history")
	snapshot.points[0].y = 321.0
	_check(float(definition.points[0].y) != 321.0, "Editable control points remain isolated between history entries")

func _menus() -> void:
	var settings := ApexSettings.new()
	var menu := ApexMainMenu.new()
	screen.add_child(menu)
	menu.build(settings.values, ApexCareer.new())
	menu.changed.connect(func(key: String, value: Variant): settings.values[key] = value; menu.update_vehicle(int(settings.values.vehicle)))
	await process_frame
	var mode: Control = menu.setup.get_child(0)
	mode.value_button.grab_focus()
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	Input.flush_buffered_events()
	await process_frame
	_check(settings.values.mode == "Carrera", "Focused selector responds to arrow keys")
	_check(menu.setup._rivals.visible, "Race settings expose rivals")
	mode.advance(2)
	_check(settings.values.mode == "Libre" and not menu.setup._rivals.visible and not menu.setup._laps.visible, "Free drive hides irrelevant grid and lap settings")
	var livery_items: int = menu.livery_select.item_count
	menu.update_vehicle(0)
	_check(menu.livery_select.item_count == livery_items, "Unchanged vehicle update preserves livery options")
	menu.changed.emit("vehicle", 3)
	for resolution: Vector2i in [Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		await _resize(resolution)
		_check(_inside(menu._ui.panel) and _inside(menu._ui.drive), "Garage session and drive action fit " + str(resolution))
		_check(_inside(menu._ui.strip) and _inside(menu.name_label), "Garage collection and title fit " + str(resolution))
		_check(not menu._ui.strip.get_global_rect().intersects(menu._ui.panel.get_global_rect()), "Collection does not overlap session panel " + str(resolution))
		if resolution.x == 960:
			_check(menu._ui.strip.get_global_rect().grow(1).encloses(menu.cards[3].get_global_rect()), "Selected fourth vehicle remains visible after resizing to 960")
	await _resize(Vector2i(960, 540))
	for index: int in [0, 3]:
		menu.changed.emit("vehicle", index)
		await process_frame
		await process_frame
		await process_frame
		_check(menu._ui.strip.get_global_rect().grow(1).encloses(menu.cards[index].get_global_rect()), "Changing vehicle reveals its complete card at 960: " + str(index))
	_check(mode.value_button.has_focus(), "Revealing a selected card preserves the user's current focus")
	menu._ui.strip.scroll_horizontal = 0
	menu.update_vehicle(3)
	await process_frame
	await process_frame
	_check(menu._ui.strip.scroll_horizontal == 0, "Unchanged vehicle updates allow manual collection scrolling")
	menu.queue_free()
	await process_frame
	var options := ApexOptionsPanel.new()
	screen.add_child(options)
	options.build(settings.values)
	for resolution: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720)]:
		await _resize(resolution)
		for i: int in options.tabs.get_tab_count():
			options.tabs.current_tab = i
			await process_frame
			_check(_inside(options.tabs), "Settings page fits " + str(resolution) + ": " + str(i))
	options.queue_free()
	await process_frame
	var modal := ApexModal.new()
	screen.add_child(modal)
	modal.build("EN PAUSA", "La siguiente curva puede esperar.", {"resume": "CONTINUAR", "restart": "Reiniciar sesión", "editor": "Editor de circuitos", "options": "Ajustes", "retire": "Retirarme · DNF", "garage": "Volver al garaje"})
	await _resize(Vector2i(960, 540))
	_check(_inside(modal.get_child(1).get_child(0)), "Complete pause menu fits minimum resolution")
	modal.queue_free()
	await process_frame

func _type(character: String) -> void:
	var event := InputEventKey.new()
	event.unicode = character.unicode_at(0)
	event.keycode = character.to_upper().unicode_at(0)
	event.physical_keycode = event.keycode
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var released := event.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	Input.flush_buffered_events()

func _resize(resolution: Vector2i) -> void:
	root.size = resolution
	root.content_scale_size = resolution
	await process_frame
	await process_frame
	await process_frame

func _inside(control: Control) -> bool:
	return control.get_viewport_rect().grow(1).encloses(control.get_global_rect())

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
