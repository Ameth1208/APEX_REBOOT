extends SceneTree
## Isolated real HUD QA. Fixture captures are not screenshots of gameplay.

const Fixture = preload("res://tools/fixtures/hud_session.gd")
const SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(2560, 1080)]
var session: ApexRaceSession
var hud: ApexHUD
var checks: int = 0
var failures: Array[String] = []
var views: Array[Dictionary] = []
var capture: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capture = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute("user://qa")
	for scenario: Dictionary in [
		{"name": "moto-carrera", "bike": true, "mode": "Carrera", "closed": true},
		{"name": "coche-contrarreloj", "bike": false, "mode": "Contrarreloj", "closed": true},
		{"name": "moto-libre", "bike": true, "mode": "Libre", "closed": true},
		{"name": "coche-etapa", "bike": false, "mode": "Carrera", "closed": false}]:
		session = Fixture.new()
		root.add_child(session)
		session.call("setup_fixture", bool(scenario.bike), str(scenario.mode), bool(scenario.closed))
		hud = ApexHUD.new()
		root.add_child(hud)
		hud.build(session)
		await _tick()
		await _inputs(bool(scenario.bike))
		await _mode(scenario)
		await _viewports(str(scenario.name))
		hud.queue_free()
		session.queue_free()
		await process_frame
	var report := {"checks": checks, "failures": failures, "viewports": views, "capture": capture, "scope": "Real HUD; synthetic telemetry; no physics or FPS benchmark"}
	var output := FileAccess.open("user://qa/hud-layout-report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("HUD_LAYOUT_PROBE ", "PASS" if failures.is_empty() else "FAIL", " ", checks, " ", failures)
	quit(0 if failures.is_empty() else 1)

func _inputs(bike: bool) -> void:
	for values: Vector3 in [Vector3.ZERO, Vector3(0.65, 0.30, 0.40), Vector3.ONE, Vector3.ZERO]:
		await _tick({"throttle": values.x, "brake": values.y, "handbrake": values.z})
		var inputs: Array = [hud.throttle_input, hud.brake_input, hud.handbrake_input]
		for index: int in 3:
			_check(is_equal_approx(inputs[index].amount, values[index]), "Applied pedal reaches HUD: " + str(values) + "/" + str(index))
			_check(inputs[index].value_label.text == "%d %%" % roundi(values[index] * 100.0), "Pedal percentage agrees with applied command")
	_check(hud.handbrake_input.caption.text == ("TRASERO" if bike else "MANO"), "Third pedal is vehicle-specific")
	await _tick({"gear": -1, "rpm": 0.0, "speed_kph": 0.0})
	_check(hud.gear.text == "R" and hud.speed.text == "0" and hud.rpm.value == 0.0, "Reverse, stopped speed and zero RPM")
	await _tick({"gear": 0, "rpm": float(session.player.profile.max_rpm) * 2.0})
	_check(hud.gear.text == "N" and hud.rpm.value == 100.0, "Neutral and RPM strip stops at its limit")
	await _tick({"gear": 5, "rpm": 6700.0, "speed_kph": 191.0, "throttle": 0.65, "brake": 0.30, "handbrake": 0.40})
	_check(not hud.telemetry_box.visible and not hud.condition.visible, "Diagnostics and healthy status are hidden by default")
	var normal: String = _visible_text(hud).to_upper()
	for forbidden: String in ["SIN DAÑOS", "AIRE LIMPIO", "CONTROLES APLICADOS", "PERSECUCIÓN", "PAUSA", "F2", "F3", "CÁMARA"]:
		_check(not normal.contains(forbidden), "No permanent HUD clutter: " + forbidden)
	hud.show_telemetry = true
	await _tick()
	_check(hud.telemetry_box.visible and hud.telemetry_box.details.text.contains("Cámara"), "Optional telemetry reveals detailed data")
	hud.show_telemetry = false
	hud.notify("Aviso de prueba")
	await _tick()
	_check(hud._ui.notice_box.visible and hud.message.text == "Aviso de prueba", "Context notice is displayed")
	hud.update_session(session, "Persecución", 6.0)
	_check(not hud._ui.notice_box.visible and hud.message.text.is_empty(), "Context notice expires")
	await _tick({"damage": 0.25, "crashed": true})
	_check(hud.condition.visible and _visible_text(hud.condition).contains("CAÍDA" if bike else "INMOVILIZADO"), "Vehicle warning appears only with its state")
	await _tick({"damage": 0.0, "crashed": false})
	_check(not hud.condition.visible, "Vehicle warning disappears after recovery")

func _mode(scenario: Dictionary) -> void:
	_check(hud.tower.title_label.text == str(scenario.mode).to_upper(), "Mode displayed correctly: " + str(scenario.name))
	_check(hud.timing_panel.current_label.text == "0:12.345", "Current timer comes from tracker")
	_check(hud.tower.row_controls.size() == (6 if scenario.mode == "Carrera" else 0), "Only actual rival sessions have classification rows")
	var lap: ApexLapTracker = session.laps[0]
	if bool(scenario.closed):
		_check(hud.timing_panel.best_caption.text == "MEJOR" and hud.timing_panel.best_label.text == "1:13.210", "Circuit best lap is displayed")
		_check(hud.tower.lap_label.text == ("VUELTA 1" if scenario.mode == "Libre" else "VUELTA 1 / 3"), "Free laps and limited laps are distinct")
		lap.best = 0.0
		await _tick()
		_check(hud.timing_panel.best_label.text == "—:——.———", "No best time is invented")
		lap.best = 73.210
	else:
		_check(hud.tower.lap_label.text == "ETAPA" and hud.timing_panel.best_caption.text == "FALTAN", "Open route shows a stage and remaining distance")
		_check(hud.timing_panel.best_label.text.contains("km"), "Long remaining distance includes its unit")
		lap.finished = true
		lap.last_lap_valid = true
		lap.previous = 123.456
		await _tick()
		_check(hud.timing_panel.best_caption.text == "META" and hud.timing_panel.best_label.text == "COMPLETADA" and hud.timing_panel.current_label.text == "2:03.456", "Stage finish uses recorded time and arrival state")
		lap.finished = false
	lap.valid = false
	await _tick()
	_check(hud.timing_panel.validity_label.text == "NO VÁLIDA", "Invalid attempt is clearly distinguished")
	lap.valid = true
	await _tick()

func _viewports(scenario: String) -> void:
	for resolution: Vector2i in SIZES:
		root.size = resolution
		hud.show_telemetry = false
		await _tick({"damage": 0.0, "crashed": false})
		_bounds(scenario + " normal " + str(resolution))
		if capture:
			await _shot("hud-" + scenario + "-" + str(resolution.x) + "x" + str(resolution.y))
		hud.show_telemetry = true
		await _tick({"damage": 0.25})
		_bounds(scenario + " diagnostics " + str(resolution))
		views.append({"scenario": scenario, "window": [root.size.x, root.size.y], "hud": [hud.size.x, hud.size.y]})
	hud.show_telemetry = false
	await _tick({"damage": 0.0})

func _bounds(context: String) -> void:
	var panels: Array[Control] = [hud.tower, hud.timing_panel, hud.cluster, hud.map, hud.condition, hud.telemetry_box]
	var area := Rect2(Vector2.ZERO, hud.size).grow(0.5)
	for index: int in panels.size():
		if not panels[index].is_visible_in_tree(): continue
		var rect: Rect2 = panels[index].get_global_transform() * Rect2(Vector2.ZERO, panels[index].size)
		if not area.encloses(rect):
			_geometry(panels[index], context + " outside")
		_check(area.encloses(rect), context + " panel inside viewport: " + str(index))
		for other: int in range(index + 1, panels.size()):
			if not panels[other].is_visible_in_tree(): continue
			var second: Rect2 = panels[other].get_global_transform() * Rect2(Vector2.ZERO, panels[other].size)
			if rect.grow(-0.5).intersects(second.grow(-0.5)):
				_geometry(panels[index], context + " intersection first")
				_geometry(panels[other], context + " intersection second")
			_check(not rect.grow(-0.5).intersects(second.grow(-0.5)), context + " panels do not overlap: %d/%d" % [index, other])
	var cluster_rect: Rect2 = hud.cluster.get_global_transform() * Rect2(Vector2.ZERO, hud.cluster.size)
	_check(absf(cluster_rect.get_center().x - hud.size.x * 0.5) < 1.0, context + " instruments remain centred")
	_check(hud.tower.position.x < hud.size.x * 0.5 and hud.timing_panel.position.x > hud.size.x * 0.5 and hud.map.position.y > hud.size.y * 0.5, context + " reference corner distribution")

func _geometry(control: Control, context: String) -> void:
	var parent: Node = control.get_parent()
	print("HUD_GEOMETRY ", context, " path=", control.get_path(), " script=", control.get_script().resource_path)
	print(" local_size=", control.size, " position=", control.position, " scale=", control.scale,
		" global_rect=", control.get_global_rect(), " transformed_rect=", control.get_global_transform() * Rect2(Vector2.ZERO, control.size))
	print(" viewport=", control.get_viewport_rect(), " root_visible=", root.get_visible_rect(), " window=", root.size, " hud=", hud.size)
	if parent is Control:
		print(" parent=", parent.get_path(), " rect=", parent.get_global_rect(), " scale=", parent.scale, " transform=", parent.get_global_transform())

func _tick(data: Dictionary = {}) -> void:
	session.player.data.merge(data, true)
	hud.update_session(session, "Persecución", 0.25)
	await process_frame
	hud.update_session(session, "Persecución", 0.0)
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func _visible_text(node: Node) -> String:
	if node is Control and not node.is_visible_in_tree(): return ""
	var text: String = node.text + "\n" if node is Label else ""
	for child: Node in node.get_children():
		text += _visible_text(child)
	return text

func _shot(name: String) -> void:
	var path: String = "user://qa/" + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("HUD_FIXTURE_SHOT ", ProjectSettings.globalize_path(path))

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)
