extends SceneTree
## Build the real saved road, exercise nearby vegetation and save a desktop view.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var track := CircuitTrack.new()
	world.add_child(track)
	var source: Dictionary = preload("res://scripts/geo/route_terrain_profile.gd").apply(ApexCatalog.read_json("res://data/tracks/polonuevo_baranoa.json"))
	var started := Time.get_ticks_msec()
	track.build(source)
	var vegetation: Node3D = track.get_node_or_null("MappedVegetation")
	if vegetation == null or vegetation.placements.is_empty():
		push_error("La cobertura real no produjo vegetación: revisar datos y exclusiones.")
		quit(1)
		return
	var focus: Vector3 = vegetation.placements[0].position
	var target := Node3D.new()
	world.add_child(target)
	target.position = focus
	vegetation.target = target
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = focus + Vector3(50, 32, 55)
	camera.look_at(focus)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-50, -25, 0)
	world.add_child(sunlight)
	for frame: int in 40:
		vegetation._process(0.06)
		await process_frame
	print("REAL_VEGETATION_PREVIEW ", vegetation.get_stream_stats(), " build_ms=", Time.get_ticks_msec() - started, " source=", track.get_meta("vegetation_source"))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://qa")
		root.get_texture().get_image().save_png("user://qa/polonuevo-vegetation.png")
	quit()
