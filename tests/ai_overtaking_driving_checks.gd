extends SceneTree
## The same physical cars must pass a stopped vehicle without contact or resets.

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
	track.build({"name": "Adelantamiento físico", "closed": false, "interpolation": "linear",
		"terrain_hills": 0.0, "runoff_width": 1.0, "barriers": true, "points": [
			{"x": 0.0, "y": 0.0, "z": 0.0, "width": 16.0, "bank": 0.0, "surface": "asphalt"},
			{"x": 0.0, "y": 0.0, "z": -400.0, "width": 16.0, "bank": 0.0, "surface": "asphalt"}]})
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles/porsche_992_gt3_rs_2024.json"))
	var host = _car(world, profile, track.get_spawn_transform(80.0))
	var leader = _car(world, profile, track.get_spawn_transform(140.0))
	for _frame: int in 240:
		await physics_frame
	var driver = Driver.new()
	driver.configure(host, track, 0.0, 0.84)
	var saw_pass: bool = false
	var contact: bool = false
	var largest_error: float = 0.0
	var returned: bool = false
	var elapsed: float = 0.0
	for frame: int in 7200:
		elapsed = frame / 120.0
		driver.drive(1.0 / 120.0, [host, leader])
		leader.set_controls(0.0, 1.0, 0.0)
		await physics_frame
		var line: Dictionary = track.sample_at(driver.distance)
		var error: float = absf((host.position - Vector3(line.position)).dot(Vector3(line.right)))
		largest_error = maxf(largest_error, error)
		saw_pass = saw_pass or driver.status_text == "Adelantando"
		contact = contact or host.get_colliding_bodies().has(leader)
		if frame % 1200 == 0:
			print("OVERTAKE t=", frame / 120.0, " state=", driver.status_text, " station=", driver.distance, " lane=", driver.lane, " error=", error)
		if driver.retired or contact:
			break
		if driver.distance > 165.0 and error < 0.8 and absf(driver.lane) < 0.1:
			returned = true
			break
		if driver.distance > 320.0:
			break
	_check(saw_pass and largest_error > 1.5, "the car uses a passing corridor")
	_check(not contact, "the pass causes no contact with the stopped vehicle")
	_check(returned, "the car passes and returns to its nominal line after rear clearance")
	_check(largest_error < 6.0, "the entire physical body remains within the useful road width")
	_check(driver.recovery_count == 0 and not driver.retired, "the pass requires no recovery or retirement")
	print("AI_OVERTAKING_DRIVING_CHECKS ", "PASS" if _failures.is_empty() else str(_failures), " max_error_m=", largest_error, " recovery_count=", driver.recovery_count, " elapsed=", elapsed, " station=", driver.distance, " lane=", driver.lane)
	world.queue_free()
	for _frame: int in 4:
		await physics_frame
	quit(0 if _failures.is_empty() else 1)

func _car(parent: Node3D, profile: Dictionary, pose: Transform3D) -> RigidBody3D:
	var body = Vehicle.new()
	body.configure(profile)
	body.set_assist_mode("Assisted")
	parent.add_child(body)
	body.reset_at(pose)
	body.set_controls(0.0, 1.0, 0.0)
	return body

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
