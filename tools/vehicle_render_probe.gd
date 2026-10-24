extends SceneTree
## Desktop diagnostic; never reads or writes player preferences.

var _frames: Array[float] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world := Node3D.new()
	root.add_child(world)
	var showroom := ApexShowroom.new()
	world.add_child(showroom)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(5.2, 2.5, -5.7)
	camera.look_at(Vector3(0, 0.65, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	world.add_child(light)
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if not args.is_empty() else "porsche_992_gt3_rs_2024"
	var profile := ApexCatalog.read_json("res://data/vehicles/" + id + ".json")
	profile["batch_static_body"] = not args.has("--unbatched")
	var started := Time.get_ticks_msec()
	showroom.show_vehicle(profile, "Original")
	print("MODEL_SETUP_MS ", Time.get_ticks_msec() - started)
	if args.has("--repeat"):
		started = Time.get_ticks_msec()
		showroom.show_vehicle(profile, "Original")
		print("REPEATED_MODEL_SETUP_MS ", Time.get_ticks_msec() - started)
	for frame: int in 180:
		await process_frame
		if frame >= 60:
			_frames.append(root.get_process_delta_time() * 1000.0)
	_frames.sort()
	print("VEHICLE_RENDER ", id, " median_frame_ms=", _frames[_frames.size() / 2], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://qa/alignment")
		root.get_texture().get_image().save_png("user://qa/alignment/" + id + ".png")
	quit()
