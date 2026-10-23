extends SceneTree
## Drive complete open routes using real controls, then stop at the independent finish.

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var profiles: PackedStringArray = OS.get_cmdline_user_args()
	if profiles.is_empty():
		profiles = PackedStringArray(["porsche_992_gt3_rs_2024", "yamaha_yzf_2021", "ferrari_312t_1976", "senna_formula_1991"])
	for vehicle_id: String in profiles:
		await _stage(vehicle_id)
	print("OPEN_ROUTE_AI_CHECKS ", "PASS" if _failures.is_empty() else str(_failures))
	quit(0 if _failures.is_empty() else 1)

func _stage(vehicle_id: String) -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var track: CircuitTrack = CircuitTrack.new()
	world.add_child(track)
	track.build(_definition())
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles/" + vehicle_id + ".json"))
	var body: ApexVehicle = ApexVehicle.new()
	body.configure(profile)
	body.set_assist_mode("Sport")
	world.add_child(body)
	body.reset_at(track.get_spawn_transform(8.0))
	for _frame: int in range(240):
		await physics_frame
	var driver: ApexRacingDriver = ApexRacingDriver.new()
	driver.configure(body, track, 0.0, 0.84)
	var tracker: ApexLapTracker = ApexLapTracker.new()
	tracker.setup(track.length_m, driver.distance, false)
	_check(driver.planner.target_at(track.length_m + 100.0) == 0.0, "planner clamps to a stationary finish")
	_check(driver.planner.target_at(track.length_m - 60.0) > driver.planner.target_at(track.length_m - 5.0), "planner brakes before the end")
	var max_error: float = 0.0
	for frame: int in range(24000):
		driver.drive(1.0 / 120.0, [body])
		await physics_frame
		var distance: float = track.closest_distance(body.global_position, tracker.distance)
		var sample: Dictionary = track.sample_at(distance)
		var error: float = absf((body.global_position - Vector3(sample.position)).dot(Vector3(sample.right)))
		max_error = maxf(max_error, error)
		tracker.tick(1.0 / 120.0, distance, error, float(sample.width), 3)
		if tracker.finished or driver.recovery_count > 0:
			break
		if frame % 2400 == 0:
			print(vehicle_id, " stage t=", float(frame) / 120.0, " distance=", snappedf(distance, 0.1), " speed=", snappedf(body.speed_kph, 0.1))
	_check(tracker.finished and tracker.valid_laps == 1, vehicle_id + " completes one valid physical stage")
	_check(driver.recovery_count == 0, vehicle_id + " requires no recovery manoeuvre")
	_check(not driver.retired, vehicle_id + " remains driveable through the stage")
	_check(max_error < 5.0, vehicle_id + " remains in the usable road corridor")
	for _frame: int in range(480):
		driver.drive(1.0 / 120.0, [body])
		await physics_frame
	_check(body.linear_velocity.length() < 0.6, vehicle_id + " stops after the finish")
	_check(body.position.distance_to(Vector3(track.sample_at(track.length_m).position)) < 10.0, vehicle_id + " remains at the finish instead of restarting the route")
	print("OPEN_STAGE_DONE ", vehicle_id, " seconds=", tracker.elapsed, " max_error=", max_error, " final_speed=", body.linear_velocity.length(), " recoveries=", driver.recovery_count)
	world.queue_free()
	for _frame: int in range(4):
		await physics_frame

func _definition() -> Dictionary:
	var points: Array[Dictionary] = []
	for position: Vector3 in [Vector3(0, 2, 0), Vector3(0, 3, -140), Vector3(10, 6, -260), Vector3(35, 10, -380), Vector3(80, 12, -500), Vector3(140, 13, -620), Vector3(210, 12, -730)]:
		points.append({"x": position.x, "y": position.y, "z": position.z, "width": 14.0, "bank": 0.0, "surface": "asphalt"})
	return {"name": "Ruta abierta de comprobación", "closed": false, "interpolation": "linear", "points": points, "terrain_hills": 0.0, "barriers": false}

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)
