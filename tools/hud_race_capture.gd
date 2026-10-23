extends SceneTree
## Native visual QA of the real race HUD. Captures are not a GPU benchmark.

var session: ApexRaceSession
var hud: ApexHUD
var camera: ApexCamera
var world: Node3D
var environment: ApexEnvironment
var scenery: ApexScenery
var output: String = "user://qa/hud-race"
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_physics_steps_per_frame = 128
	ApexInput.install()
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600, 900)
	await _create_race(3, 2)
	await _drive_and_capture("formula")
	await _release_world()
	await _create_race(1, 0)
	await _drive_and_capture("moto")
	environment.set_night(true)
	scenery.night = true
	session.set_lights(true)
	await _capture("moto-noche")
	hud.show_telemetry = true
	await _capture("telemetria-opcional")
	await _release_world()
	var report := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures": failures, "physics_hz": Engine.physics_ticks_per_second,
		"software_renderer": true, "viewport": [1600, 900], "harness_max_steps": 128}, "\t"))
	report.close()
	print("HUD_RACE_CAPTURE ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	quit(0 if failures.is_empty() else 1)

func _create_race(vehicle_index: int, camera_index: int) -> void:
	world = Node3D.new()
	root.add_child(world)
	environment = ApexEnvironment.new()
	world.add_child(environment)
	environment.set_quality("Equilibrado")
	var options: Dictionary = ApexSettings.new().values.duplicate(true)
	options.vehicle = vehicle_index
	options.mode = "Carrera"
	options.opponents = 5
	options.laps = 3
	options.fullscreen = false
	options.night = false
	options.racing_line = false
	session = ApexRaceSession.new()
	world.add_child(session)
	session.start(ApexCatalog.vehicle(vehicle_index), ApexCatalog.track(0), options)
	session.active = false
	for body: RigidBody3D in session.vehicles:
		body.freeze = true
	camera = ApexCamera.new()
	# Let the follow camera settle while the QA snapshot pauses physics.
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	world.add_child(camera)
	camera.mode = camera_index
	camera.configure(options)
	camera.follow(session.player)
	scenery = ApexScenery.new()
	world.add_child(scenery)
	scenery.target = session.player
	await scenery.build(session.track)
	var canvas := CanvasLayer.new()
	world.add_child(canvas)
	hud = ApexHUD.new()
	canvas.add_child(hud)
	hud.build(session)
	session.notice.connect(hud.notify)
	await process_frame
	print("HUD_RACE_READY ", vehicle_index)

func _drive_and_capture(name: String) -> void:
	for body: RigidBody3D in session.vehicles:
		body.freeze = false
	session.countdown = 0.0
	session.active = true
	Input.action_press("accelerate", 0.65)
	var deadline: int = Time.get_ticks_msec() + 90000
	while session.laps[0].elapsed < 2.7 and Time.get_ticks_msec() < deadline:
		await process_frame
	session.active = false
	# Pause the simulation without freezing bodies: freeze clears velocity on the
	# next physics tick, which would make the captured speedometer read zero.
	paused = true
	Input.action_release("accelerate")
	if session.player.speed_kph < 5.0:
		failures.append(name + ": actual input did not move the vehicle")
	print("HUD_CAPTURE_DRIVE ", name, " speed=", session.player.speed_kph,
		" throttle=", session.player.telemetry().throttle, " time=", session.laps[0].elapsed)
	await _capture(name)

func _process(delta: float) -> bool:
	if is_instance_valid(hud) and is_instance_valid(session):
		hud.update_session(session, ApexCamera.NAMES[camera.mode], delta)
	return false

func _capture(name: String) -> void:
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	if int(hud.speed.text) < 5:
		failures.append(name + ": speedometer lost actual moving state during capture")
	var error: Error = root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	if error != OK:
		failures.append("Capture failed: " + name)
	print("HUD_RACE_SHOT ", ProjectSettings.globalize_path(output.path_join(name + ".png")))

func _release_world() -> void:
	world.queue_free()
	await process_frame
	await process_frame
	hud = null
	session = null
	paused = false
