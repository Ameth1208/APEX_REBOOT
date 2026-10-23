extends SceneTree
## Fixed camera captures: run before/after an environment change, not a FPS benchmark.

var _output: String = "user://world-probe"
var _world: Node3D
var _environment: ApexEnvironment
var _scenery: ApexScenery
var _vehicle: Node3D
var _camera: Camera3D
var _quality: String = "Equilibrado"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
		if argument.begins_with("--quality="):
			_quality = argument.trim_prefix("--quality=")
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_output)
	root.size = Vector2i(1440, 900)
	_world = Node3D.new()
	root.add_child(_world)
	_environment = ApexEnvironment.new()
	_world.add_child(_environment)
	_environment.set_quality(_quality)
	var track: CircuitTrack = CircuitTrack.new()
	_world.add_child(track)
	track.build(ApexCatalog.track(0))
	var s: Dictionary = track.sample_at(20.0)
	_vehicle = load("res://scripts/vehicles/vehicle_visual.gd").new()
	_world.add_child(_vehicle)
	_vehicle.setup(ApexCatalog.vehicle(1))
	_vehicle.transform = Transform3D(Basis(s.right, s.normal, -s.forward), s.position)
	_scenery = ApexScenery.new()
	_world.add_child(_scenery)
	_scenery.target = _vehicle
	await _scenery.build(track)
	_camera = Camera3D.new()
	_world.add_child(_camera)
	_camera.fov = 61.0
	_camera.position = s.position - s.forward * 8.0 + Vector3.UP * 3.5
	_camera.look_at(s.position + s.forward * 5.0 + Vector3.UP * 1.0)
	_camera.make_current()
	await _capture("day-dry")
	_environment.set_wetness(0.85)
	await _capture("day-wet")
	_environment.set_night(true)
	_scenery.night = true
	_vehicle.set_headlights(true)
	await _capture("night-wet")
	_world.remove_child(track)
	track.queue_free()
	_world.remove_child(_scenery)
	_scenery.queue_free()
	_world.remove_child(_vehicle)
	_vehicle.queue_free()
	_environment.set_showroom()
	var showroom: ApexShowroom = ApexShowroom.new()
	_world.add_child(showroom)
	showroom.show_vehicle(ApexCatalog.vehicle(1), "Original")
	_camera.position = Vector3(4.4, 2.15, 5.1)
	_camera.look_at(Vector3(0, 0.95, 0))
	await _capture("showroom")
	print("WORLD_VISUAL_PROBE PASS ", _output)
	quit()

func _capture(title: String) -> void:
	for frame: int in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(_output.path_join(title + ".png"))
	if error != OK:
		push_error("Could not save visual probe: " + str(error))
		quit(1)
	print("WORLD_CAPTURE ", title)
	print("WORLD_RENDER ", _quality, " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		" draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
