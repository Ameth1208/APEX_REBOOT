extends SceneTree
## Real native UI flow, physical key events, responsive layouts and actual race state.
var app: Node3D
var checks: int = 0
var failures: Array[String] = []
var throttle_peak: float = 0.0
var brake_peak: float = 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# The software renderer can miss the normal eight-tick frame budget. Keep
	# the same 120 Hz physics while allowing this QA harness to catch up.
	Engine.max_physics_steps_per_frame = 128
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	app.settings.values.vehicle = 1
	app.settings.values.mode = "Carrera"
	app.settings.values.opponents = 5
	app.settings.values.laps = 1
	app.settings.values.fullscreen = false
	root.add_child(app)
	await process_frame
	await process_frame
	app.camera.orbit = -0.85
	await _shot("v03-garaje")
	app.handle_action("options")
	await process_frame
	var options: ApexOptionsPanel = app.screens.options
	_check(options.tabs.get_tab_count() == 4, "Four usable settings pages exist")
	for index: int in 4:
		options.tabs.current_tab = index
		await process_frame
		_check(_inside(options.tabs), "Settings tab fits: " + options.tabs.get_tab_title(index))
	options.tabs.current_tab = 2
	await process_frame
	var controls: ApexControlsPanel = options.tabs.get_child(2).get_child(0).get_child(0)
	controls._buttons.accelerate.pressed.emit()
	_key(KEY_S, true)
	_key(KEY_S, false)
	_check(controls._waiting == "accelerate", "UI rejects a key already used by another action")
	_key(KEY_I, true)
	_key(KEY_I, false)
	_check(controls._waiting.is_empty() and int(app.settings.values.key_bindings.accelerate) == KEY_I, "UI saves new physical throttle key")
	_check(controls._buttons.accelerate.text == "I", "Binding button displays actual new key")
	await _shot("v03-controles")
	for resolution: Vector2i in [Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		await _resize(resolution)
		_check(_inside(options.tabs) and _inside(options.get_child(1)), "Settings fit " + str(resolution))
	await _resize(Vector2i(1440, 900))
	options.tabs.current_tab = 1
	await _shot("v03-camara-ajustes")
	app.handle_action("close_overlay")
	app.change_setting("camera_fov", 73.0)
	app.change_setting("camera_motion", 0.35)
	await _resize(Vector2i(960, 540))
	await app.start_race()
	_check(app.race.vehicles.size() == 6, "Race actually contains player and five physical rivals")
	var deadline: int = Time.get_ticks_msec() + 45000
	while app.race.countdown > 0.0 and Time.get_ticks_msec() < deadline:
		await process_frame
	print("V03_COUNTDOWN ", app.race.countdown, " physics_hz=", Engine.physics_ticks_per_second, " max_steps=", Engine.max_physics_steps_per_frame)
	_check(app.race.countdown <= 0.0, "Countdown completes before player input")
	_key(KEY_I, true)
	var start: Vector3 = app.race.player.global_position
	deadline = Time.get_ticks_msec() + 45000
	while (throttle_peak < 0.96 or app.race.player.global_position.distance_to(start) <= 1.0) and Time.get_ticks_msec() < deadline:
		await _visible_frame()
		throttle_peak = maxf(throttle_peak, app.screens.hud.throttle_input.amount)
	_key(KEY_I, false)
	_check(app.race.player.global_position.distance_to(start) > 1.0, "Remapped key physically drives the motorcycle")
	_check(throttle_peak > 0.95, "Red throttle HUD reaches actual full applied input")
	_check(not _has_driving_hints(app.screens.hud), "Race HUD does not display a permanent key guide")
	_key(KEY_S, true)
	deadline = Time.get_ticks_msec() + 45000
	while brake_peak < 0.96 and Time.get_ticks_msec() < deadline:
		await _visible_frame()
		brake_peak = maxf(brake_peak, app.screens.hud.brake_input.amount)
	_key(KEY_S, false)
	_check(brake_peak > 0.9, "Red brake HUD reports applied braking independently")
	app.race.active = false
	app.race.player.set_controls(0.65, 0.30, 0.0, 0.40)
	await create_timer(0.6, true, true).timeout
	app.race.player.freeze = true
	for body: RigidBody3D in app.race.vehicles:
		body.freeze = true
	app.screens.hud.show_telemetry = true
	await process_frame
	_check(app.screens.hud.tower.rows.size() == 6, "Live standings include real race participants")
	for resolution: Vector2i in [Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		await _resize(resolution)
		_check(_inside(app.screens.hud.cluster) and _inside(app.screens.hud.throttle_input) and _inside(app.screens.hud.map) and _inside(app.screens.hud.telemetry_box), "HUD fits " + str(resolution))
	await _resize(Vector2i(1440, 900))
	await _shot("v03-carrera")
	app.screens.hud.show_telemetry = false
	app.camera.mode = 3
	app.race.player.get_node("Visual").set_cockpit_view(false)
	await create_timer(0.1, true).timeout
	await _shot("v03-piloto")
	app.handle_action("pause")
	_check(paused, "Pause stops simulation")
	app.handle_action("options")
	app.change_setting("steering_response", 1.6)
	app.change_setting("ai_difficulty", "Expert")
	_check(is_equal_approx(app.race._input.response, 1.6), "In-race options reach actual player controller")
	_check(app.race.settings.ai_difficulty == "Expert", "In-race difficulty reaches AI planners")
	app.handle_action("resume")
	app.race.active = true
	app.handle_action("retire")
	await process_frame
	_check(paused and app.screens.modal is ApexRaceResults and app.race.retired[0], "Retire creates DNF result and pauses session")
	for resolution: Vector2i in [Vector2i(960, 540), Vector2i(1024, 768), Vector2i(2560, 1080)]:
		await _resize(resolution)
		_check(_inside(app.screens.modal.get_child(1).get_child(0)), "Six-driver results fit " + str(resolution))
	await _resize(Vector2i(1440, 900))
	await _shot("v03-resultados")
	app.handle_action("garage")
	await process_frame
	_check(not paused and app.race == null and is_instance_valid(app.screens.menu), "Result returns to functioning garage")
	var persisted := ApexSettings.new()
	persisted.load_preferences()
	_check(int(persisted.values.key_bindings.accelerate) == KEY_I and is_equal_approx(float(persisted.values.camera_fov), 73.0), "Changed controls and camera survive reload")
	DirAccess.make_dir_recursive_absolute("user://qa")
	var file := FileAccess.open("user://qa/v03-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "throttle_peak": throttle_peak, "brake_peak": brake_peak}, "\t"))
	file.close()
	print("V03_FEATURE_PROBE ", "PASS" if failures.is_empty() else "FAIL", " ", checks, " ", failures)
	quit(0 if failures.is_empty() else 1)

func _resize(size: Vector2i) -> void:
	root.size = size
	await process_frame
	await process_frame

func _visible_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await process_frame
		await process_frame
	else:
		await RenderingServer.frame_post_draw

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _inside(control: Control) -> bool:
	return control.get_viewport_rect().grow(1).encloses(control.get_global_rect())

func _has_driving_hints(node: Node) -> bool:
	if node is Label and node.visible and ("Acelerar / frenar" in node.text or "CONTROLES APLICADOS" in node.text):
		return true
	for child: Node in node.get_children():
		if _has_driving_hints(child): return true
	return false

func _shot(caption: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://qa")
	var path: String = "user://qa/" + caption + ".png"
	root.get_texture().get_image().save_png(path)
	print("V03_SHOT ", ProjectSettings.globalize_path(path))

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)
