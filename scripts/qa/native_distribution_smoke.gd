extends Node
## Run the exported application with -- --qa-distribution (isolated test preferences).
## Software-rendered integration check; frame timing is not a target-GPU benchmark.

var app: Node
var failures: Array[String] = []

func run(root_app: Node) -> void:
	app = root_app
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Window = get_tree().root
	if DisplayServer.get_name() == "headless":
		push_error("This integration check requires a native display.")
		get_tree().quit(2)
		return
	Engine.max_physics_steps_per_frame = 128
	root.size = Vector2i(1280, 720)
	await get_tree().process_frame
	app.change_setting("vehicle", 3)
	app.change_setting("quality", "Automático")
	app.settings.values.mode = "Libre"
	app.settings.values.opponents = 0
	app.settings.values.track = 3
	app.settings.values.racing_line = false
	app.settings.values.volume = 0.0
	print("NATIVE_DISTRIBUTION_STARTING_POLONUEVO")
	await app.start_race()
	print("NATIVE_DISTRIBUTION_DRIVING")
	app.race.countdown = 0.0
	Input.action_press("accelerate", 0.65)
	for frame: int in range(18):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var telemetry: Dictionary = app.race.player.telemetry()
	_check(app.race.player.speed_kph > 1.0, "actual throttle moved the exported vehicle")
	var pedal_curve: float = float(app.settings.values.get("pedal_curve", 1.0))
	var expected_throttle: float = pow(0.65, pedal_curve)
	_check(absf(float(telemetry.throttle) - expected_throttle) < 0.01, "throttle remains analog after configured pedal curve")
	_check(app.race.track.definition.name == "Polonuevo - Baranoa (plano)", "built-in real-route track loaded")
	DirAccess.make_dir_recursive_absolute("user://qa")
	var shot_path: String = "user://qa/distribution-polonuevo.png"
	_check(root.get_texture().get_image().save_png(shot_path) == OK, "native screenshot saved")
	Input.action_release("accelerate")
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_F8
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	var path: String = "user://diagnostics/APEX_rendimiento.json"
	_check(FileAccess.file_exists(path), "F8 saved the local performance report")
	var report: Dictionary = ApexCatalog.read_json(path)
	_check(report.get("version", "") == "0.3.2", "exported version matches release")
	_check(int(report.get("sampled_gameplay_frames", 0)) > 0, "diagnostics contain measured gameplay frames")
	_check(int(report.get("physics_ticks_per_second", 0)) == 120, "physics stays at 120 Hz")
	_check(root.size == Vector2i(1280, 720), "automatic quality preserves window size")
	print("NATIVE_DISTRIBUTION_SMOKE ", JSON.stringify({"status": "PASS" if failures.is_empty() else "FAIL", "failures": failures,
		"track": app.race.track.definition.name, "speed_kph": app.race.player.speed_kph, "screenshot": ProjectSettings.globalize_path(shot_path),
		"diagnostic": ProjectSettings.globalize_path(path), "render_scale_3d": report.get("render_scale_3d"), "software_renderer": true}))
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error(label)
