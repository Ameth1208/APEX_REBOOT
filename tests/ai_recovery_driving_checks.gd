extends SceneTree
## A car touching a wall must reverse and steer out using the real drivetrain.

const Track = preload("res://scripts/tracks/circuit_track.gd")
const Vehicle = preload("res://scripts/vehicles/vehicle_body.gd")
const Driver = preload("res://scripts/ai/racing_driver.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var track = Track.new()
	world.add_child(track)
	track.build({"name": "Recuperación física", "closed": false, "interpolation": "linear",
		"terrain_hills": 0.0, "runoff_width": 1.0, "barriers": true, "points": [
			{"x": 0.0, "y": 0.0, "z": 0.0, "width": 18.0, "bank": 0.0, "surface": "asphalt"},
			{"x": 0.0, "y": 0.0, "z": -400.0, "width": 18.0, "bank": 0.0, "surface": "asphalt"}]})
	var body = Vehicle.new()
	body.configure(JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles/porsche_992_gt3_rs_2024.json")))
	body.set_assist_mode("Assisted")
	world.add_child(body)
	var pose: Transform3D = track.get_spawn_transform(100.0, -8.28)
	pose.basis = pose.basis.rotated(Vector3.UP, PI * 0.5)
	body.reset_at(pose)
	for _frame: int in 240:
		await physics_frame
	var driver = Driver.new()
	driver.configure(body, track, 0.0, 0.80)
	var saw_reverse: bool = false
	var recovered: bool = false
	var largest_step: float = 0.0
	var last_position: Vector3 = body.global_position
	for frame: int in 7200:
		driver.drive(1.0 / 120.0, [body])
		await physics_frame
		var step: float = body.global_position.distance_to(last_position)
		largest_step = maxf(largest_step, step)
		last_position = body.global_position
		saw_reverse = saw_reverse or float(body.telemetry().signed_speed_mps) < -0.4
		if frame % 1200 == 0:
			print("RECOVERY_DRIVE t=", frame / 120.0, " state=", driver.status_text, " pos=", body.position, " speed=", body.speed_kph, " count=", driver.recovery_count)
		if driver.retired:
			break
		if driver.distance > 135.0 and body.speed_kph > 15.0:
			recovered = true
			break
	_check(recovered, "wall recovery returns to the road and advances by normal driving")
	_check(saw_reverse, "the drivetrain actually entered reverse")
	_check(driver.recovery_count > 0, "the blocked car performed a recovery manoeuvre")
	_check(largest_step < 1.5, "no instantaneous reposition occurred")
	_check(not driver.retired, "recoverable wall contact does not retire the driver")
	print("AI_RECOVERY_DRIVING_CHECKS ", "PASS" if _failures.is_empty() else str(_failures), " max_step_m=", largest_step, " attempts=", driver.recovery_count)
	world.queue_free()
	for _frame: int in 4:
		await physics_frame
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
