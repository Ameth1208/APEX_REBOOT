extends SceneTree
## Full dynamic laps: no path transforms, no speed assignment, no recovery allowed.
## Run with --headless --fixed-fps 120 --script tests/ai_lap_checks.gd

const Track = preload("res://scripts/tracks/circuit_track.gd")
const Vehicle = preload("res://scripts/vehicles/vehicle_body.gd")
const Driver = preload("res://scripts/ai/racing_driver.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 2:
		await _lap(args[0], args[1], float(args[2]) if args.size() > 2 else 0.84, args[3] if args.size() > 3 else "Sport", float(args[4]) if args.size() > 4 else 0.0)
	else:
		await _lap("porsche_992_gt3_rs_2024", "costa_clara", 0.84)
		await _lap("yamaha_yzf_2021", "costa_clara", 0.84)
	if _failures.is_empty():
		print("AI LAP CHECKS: PASS")
	else:
		print("AI LAP CHECKS: FAIL ", _failures)
	quit(0 if _failures.is_empty() else 1)

func _lap(vehicle_id: String, track_id: String, pace: float, assists: String = "Sport", wetness: float = 0.0) -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var circuit = Track.new()
	world.add_child(circuit)
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tracks/" + track_id + ".json"))
	circuit.build(definition)
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles/" + vehicle_id + ".json"))
	var body = Vehicle.new()
	body.configure(profile)
	body.set_assist_mode(assists)
	body.wetness = wetness
	world.add_child(body)
	body.reset_at(circuit.get_spawn_transform(20.0))
	for _frame: int in 240:
		await physics_frame
	var driver = Driver.new()
	driver.configure(body, circuit, wetness, pace)
	var last_distance: float = driver.distance
	var progress: float = 0.0
	var max_error: float = 0.0
	var max_corridor_ratio: float = 0.0
	var max_speed: float = 0.0
	var finished: bool = false
	for frame: int in 48000:
		driver.drive(1.0 / 120.0, [body])
		await physics_frame
		var delta: float = wrapf(driver.distance - last_distance, -circuit.length_m * 0.5, circuit.length_m * 0.5)
		progress += delta
		last_distance = driver.distance
		var line: Dictionary = circuit.sample_at(driver.distance)
		var error: float = absf((body.global_position - Vector3(line["position"])).dot(Vector3(line["right"])))
		max_error = maxf(max_error, error)
		var corridor: float = float(line["width"]) * 0.5 - float(profile.get("body_width_m", 1.8)) * 0.5
		max_corridor_ratio = maxf(max_corridor_ratio, error / maxf(corridor, 1.0))
		max_speed = maxf(max_speed, body.speed_kph)
		if frame % 2400 == 0:
			print(vehicle_id, " ", track_id, " t=", float(frame) / 120.0, " progress=", snappedf(progress, 0.1), " speed=", snappedf(body.speed_kph, 0.1), " error=", snappedf(error, 0.1), " recovery=", driver.recovery_count)
		if error > 80.0 or driver.recovery_count > 0 or driver.retired or body.position.y < -40.0:
			print("LAP FAILURE STATE position=", body.position, " rotation=", body.rotation, " wheels=", body.grounded_wheels, " speed=", body.speed_kph, " target=", driver.target_speed, " lean=", body.lean_angle, " telemetry=", body.telemetry())
			break
		if progress >= circuit.length_m:
			finished = true
			print("LAP DONE ", vehicle_id, " / ", track_id, " seconds=", float(frame) / 120.0, " max_error_m=", max_error, " max_kph=", max_speed, " recoveries=", driver.recovery_count)
			break
	if not finished:
		_failures.append(vehicle_id + " failed full lap on " + track_id + "; progress=" + str(progress) + "m; max_error=" + str(max_error) + "m")
	elif max_corridor_ratio > 1.0:
		_failures.append(vehicle_id + " left the usable road corridor on " + track_id + "; maximum ratio=" + str(max_corridor_ratio))
	world.queue_free()
	for _frame: int in 4:
		await physics_frame
