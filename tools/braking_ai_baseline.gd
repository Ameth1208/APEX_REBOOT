extends SceneTree
## Read-only comparison: original brake ramp vs configurable ramp at its default.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var baseline := GDScript.new()
	baseline.source_code = FileAccess.get_file_as_string("res://scripts/physics/core/apex_vehicle_3d.gd").replace("class_name ApexVehicle3D", "").replace("dt / spec.powertrain.brake_response_time_s", "dt * 8.0")
	if baseline.reload() != OK:
		quit(1)
		return
	for old_ramp: bool in [true, false]:
		var world := Node3D.new()
		root.add_child(world)
		var track := CircuitTrack.new()
		world.add_child(track)
		track.build(ApexCatalog.read_json("res://data/tracks/costa_clara.json"))
		var body: RigidBody3D = baseline.new() if old_ramp else ApexVehicle.new()
		body.configure(ApexCatalog.read_json("res://data/vehicles/porsche_992_gt3_rs_2024.json"))
		body.set_assist_mode("Sport")
		world.add_child(body)
		body.reset_at(track.get_spawn_transform(20))
		for i: int in 240: await physics_frame
		var driver := ApexRacingDriver.new()
		driver.configure(body, track, 0.0, 0.84)
		for i: int in 7200:
			driver.drive(1.0 / 120.0, [body])
			await physics_frame
			if driver.retired or driver.recovery_count > 0: break
		print("BRAKING_AI_BASELINE old_ramp=", old_ramp, " station=", driver.distance, " position=", body.position, " can_drive=", body.can_drive())
		world.queue_free()
		for i: int in 4: await physics_frame
	quit()
