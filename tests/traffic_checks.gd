extends SceneTree
## Runs the real race session: imported models, countdown, player autopilot,
## three opponents, shared collisions, lap tracking and finish signal.

const Session = preload("res://scripts/race/race_session.gd")
var _finished: bool = false
var _result: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = Session.new()
	root.add_child(session)
	session.finished.connect(func(result: Dictionary) -> void:
		_finished = true
		_result = result)
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles/porsche_992_gt3_rs_2024.json"))
	var track: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tracks/costa_clara.json"))
	var options: Dictionary = {"mode": "Carrera", "opponents": 3, "laps": 1, "assists": "Sport", "automatic": true, "wetness": 0.0, "aero": 1.0, "grip": 1.0, "paint": "Original", "racing_line": false}
	session.start(profile, track, options)
	session.autopilot = true
	var max_errors: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for frame: int in 48000:
		await physics_frame
		for i: int in session.vehicles.size():
			var vehicle: RigidBody3D = session.vehicles[i]
			var line: Dictionary = session.track.sample_at(session.track.closest_distance(vehicle.position))
			var error: float = absf((vehicle.position - Vector3(line["position"])).dot(Vector3(line["right"])))
			max_errors[i] = maxf(max_errors[i], error)
		if frame % 2400 == 0:
			print("TRAFFIC t=", float(frame) / 120.0, " player_progress=", session.laps[0].progress, " max_errors=", max_errors)
		if _finished:
			break
	var recoveries: int = session.player_driver.recovery_count
	for driver in session.drivers:
		recoveries += driver.recovery_count
	var passed: bool = _finished and recoveries == 0 and float(_result.get("best", 0.0)) > 0.0
	print("TRAFFIC CHECK: ", "PASS" if passed else "FAIL", " result=", _result, " total_recoveries=", recoveries, " max_errors_m=", max_errors)
	session.queue_free()
	for _frame: int in 4:
		await physics_frame
	quit(0 if passed else 1)
