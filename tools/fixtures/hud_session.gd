extends ApexRaceSession
## HUD-only fixture: real trackers and RigidBody3D nodes, synthetic telemetry.

class Track:
	extends Node3D
	var closed: bool = true
	var definition: Dictionary = {"name": "Prueba aislada de HUD"}
	func get_length() -> float:
		return 2000.0
	func sample_at(distance: float) -> Dictionary:
		var angle: float = distance / get_length() * TAU
		var point := Vector3(cos(angle) * 200.0, 0.0, sin(angle) * 135.0)
		if not closed:
			point = Vector3(distance * 0.20, 0.0, sin(angle * 0.7) * 100.0)
		return {"position": point}

class Vehicle:
	extends RigidBody3D
	var is_motorcycle: bool = false
	var profile: Dictionary = {"max_rpm": 9000.0}
	var data: Dictionary = {
		"speed_kph": 191.0, "rpm": 6700.0, "gear": 5,
		"throttle": 0.0, "brake": 0.0, "handbrake": 0.0,
		"damage": 0.0, "crashed": false, "surface": "asphalt",
		"grounded_wheels": 4, "downforce_n": 1300.0,
		"steer_angle": 0.04, "lean_angle": 0.12, "tire_slip": 0.08,
		"draft_strength": 0.0, "downforce_multiplier": 1.0,
		"engine_health": 1.0, "steering_health": 1.0, "aero_health": 1.0,
		"abs_active": false, "tcs_active": false,
	}
	func telemetry() -> Dictionary:
		return data

func setup_fixture(motorcycle: bool, mode: String, closed: bool) -> void:
	settings = {"mode": mode, "laps": 3, "closed": closed}
	countdown = 0.0
	active = false
	add_child(line)
	track = Track.new()
	track.closed = closed
	add_child(track)
	var count: int = 6 if mode == "Carrera" else 1
	for index: int in count:
		var body := Vehicle.new()
		body.name = "Tú" if index == 0 else "Piloto %02d" % index
		body.is_motorcycle = motorcycle
		body.profile.max_rpm = 14000.0 if motorcycle else 9000.0
		body.data.grounded_wheels = 2 if motorcycle else 4
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		add_child(body)
		var distance: float = 385.0 if index == 0 else 435.0 - index * 20.0
		body.position = track.sample_at(distance).position
		vehicles.append(body)
		var tracker := ApexLapTracker.new()
		tracker.setup(track.get_length(), distance, closed)
		tracker.elapsed = 12.345
		tracker.lap_time = 12.345
		tracker.best = 73.210
		laps.append(tracker)
		retired.append(false)
		_retirement_reasons.append("")
	player = vehicles[0]
	for row: Dictionary in classification():
		if bool(row.is_player):
			position_in_race = int(row.position)
