extends SceneTree
## Safety scenarios for planning; independent of a particular visual vehicle mesh.

const Traffic = preload("res://scripts/ai/traffic_planner.gd")
const Recovery = preload("res://scripts/ai/physical_recovery.gd")
const Speed = preload("res://scripts/ai/speed_planner.gd")
const Classification = preload("res://scripts/race/race_classification.gd")
const Driver = preload("res://scripts/ai/racing_driver.gd")
var _failures: Array[String] = []
var _checks: int = 0

class TestCar extends RigidBody3D:
	var profile: Dictionary = {"body_width_m": 1.8, "length_m": 4.5}
	var drivable: bool = true
	var grip_factor: float = 1.0
	var aero_scale: float = 1.0
	var downforce_n: float = 0.0
	var downforce_multiplier: float = 1.0
	func can_drive() -> bool:
		return drivable
	func telemetry() -> Dictionary:
		return {}
	func set_controls(_throttle: float, _brake: float, _steer: float) -> void:
		pass

class Straight extends Node3D:
	var closed: bool = false
	var width: float = 14.0
	var grade: float = 0.0
	func get_length() -> float:
		return 1000.0
	func sample_at(distance: float) -> Dictionary:
		var forward := Vector3(0.0, grade, -1.0).normalized()
		return {"position": forward * clampf(distance, 0.0, 1000.0), "forward": forward,
			"normal": Vector3.RIGHT.cross(forward), "right": Vector3.RIGHT,
			"width": width, "surface": "asphalt", "bank": 0.0}
	func closest_distance(point: Vector3, _hint: float = -1.0) -> float:
		return clampf(point.dot(Vector3(0.0, grade, -1.0).normalized()), 0.0, 1000.0)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var track := Straight.new()
	root.add_child(track)
	var host: TestCar = _car("Tú", Vector3(0, 0.65, -100), 20.0)
	var leader: TestCar = _car("Delante", Vector3(0, 0.65, -130), 0.0)
	var left: TestCar = _car("Izquierda", Vector3(-2.65, 0.65, -110), 0.0)
	var right: TestCar = _car("Derecha", Vector3(2.65, 0.65, -110), 0.0)
	var planner = Traffic.new()
	planner.configure(0.0)
	planner.update(host, track, 100.0, 35.0, 7.0, 1.0, [host, leader])
	_check(planner.lane < -0.5, "a clear adjacent corridor allows passing")
	_check(planner.speed_limit < 20.0, "stopped leader triggers braking before closing the gap")
	planner.configure(0.0)
	planner.update(host, track, 100.0, 35.0, 7.0, 1.0, [host, leader, left])
	_check(planner.lane > 0.5, "occupied left corridor selects the clear right corridor")
	planner.configure(0.0)
	planner.update(host, track, 100.0, 35.0, 7.0, 1.0, [host, leader, left, right])
	_check(is_zero_approx(planner.lane), "occupied adjacent lanes prevent an unsafe lane change")
	_check(planner.speed_limit < 20.0, "boxed-in follower slows instead of driving through the leader")
	track.width = 5.0
	planner.configure(0.0)
	planner.update(host, track, 100.0, 35.0, 7.0, 1.0, [host, leader])
	_check(is_zero_approx(planner.lane), "passing request cannot leave a narrow road")
	host.linear_velocity.z = -60.0
	leader.position.z = -350.0
	planner.configure(0.0)
	planner.update(host, track, 100.0, 65.0, 3.0, 1.0, [host, leader])
	_check(planner.speed_limit < 50.0 and is_zero_approx(planner.lane), "high-speed observation extends beyond 120 metres to respect weak brakes")
	host.linear_velocity.z = -20.0
	leader.position.z = -130.0
	track.width = 14.0
	leader.position.y = 6.0
	planner.configure(0.0)
	planner.update(host, track, 100.0, 35.0, 7.0, 1.0, [host, leader])
	_check(is_equal_approx(planner.speed_limit, 35.0), "vehicle on another bridge deck does not cause phantom braking")
	_check(is_zero_approx(planner.lane), "vehicle on another bridge deck does not cause a phantom pass")
	leader.position.y = 0.65
	left.position.z = -85.0
	left.linear_velocity = Vector3(0, 0, -36.0)
	planner.configure(0.0)
	planner.update(host, track, 100.0, 35.0, 7.0, 1.0, [host, leader, left])
	_check(planner.lane > 0.5, "faster approaching car reserves its passing corridor")
	planner.configure(0.0)
	planner.update(host, track, 100.0, 35.0, 7.0, 1.0, [host, leader])
	host.position = Vector3(-2.65, 0.65, -170.0)
	for _step: int in 20:
		planner.update(host, track, 170.0, 35.0, 7.0, 0.2, [host, leader])
	_check(absf(planner.lane) < 0.05, "completed pass returns to the nominal lane after rear clearance")
	_speed_checks(track)
	host.position = Vector3(0, 0.65, -100.0)
	host.linear_velocity = Vector3.ZERO
	_recovery_checks(host, track)
	_replan_checks(host, track)
	_classification_checks([host, leader, left])
	for node: Node in [host, leader, left, right, track]:
		node.queue_free()
	await process_frame
	print("AI_TRAFFIC_CHECKS ", "PASS" if _failures.is_empty() else str(_failures), " checks=", _checks)
	quit(0 if _failures.is_empty() else 1)

func _speed_checks(track: Straight) -> void:
	var profile: Dictionary = {"mass_kg": 1000.0, "brake_force_n": 10000.0, "tire_grip_scale": 1.0, "downforce_area_m2": 0.0}
	var normal = Speed.new()
	normal.build(track, profile, 0.0)
	var weak = Speed.new()
	profile["brake_force_n"] = 1000.0
	weak.build(track, profile, 0.0)
	_check(weak.target_at(930.0) < normal.target_at(930.0), "weaker brakes reduce the approach speed before the same finish")
	_check(weak.braking_at(500.0) < 1.0, "mechanical brake capability bounds the planner")
	profile["brake_force_n"] = 10000.0
	track.grade = -0.12
	var downhill = Speed.new()
	downhill.build(track, profile, 0.0)
	track.grade = 0.12
	var uphill = Speed.new()
	uphill.build(track, profile, 0.0)
	_check(downhill.braking_at(500.0) < normal.braking_at(500.0), "downhill gravity increases stopping distance")
	_check(uphill.braking_at(500.0) > normal.braking_at(500.0), "uphill gravity assists braking")
	track.grade = 0.0
	var wet = Speed.new()
	wet.build(track, profile, 1.0)
	_check(wet.target_at(930.0) < normal.target_at(930.0), "wet grip reduces approach speed")
	_check(is_zero_approx(normal.target_at(2000.0)), "open finish does not wrap to the beginning")

func _recovery_checks(host: TestCar, track: Straight) -> void:
	var recover = Recovery.new()
	var line: Dictionary = track.sample_at(100.0)
	var original: Transform3D = host.global_transform
	var command: Variant = null
	for _step: int in 8:
		command = recover.update(host, line, Vector3(0, 0, -120.0), 12.0, true, 0.5)
	_check(command is Vector3 and command.x < 0.0, "stuck recovery requests reverse through the normal accelerator")
	_check(host.global_transform.is_equal_approx(original), "recovery never teleports the vehicle")
	_check(host.linear_velocity == Vector3.ZERO, "recovery does not assign velocity")
	recover.reset()
	for _step: int in 24:
		command = recover.update(host, line, Vector3(0, 0, -120.0), 12.0, false, 0.5)
	_check(recover.retired, "vehicle without reverse clearance retires explicitly after waiting")
	_check(command is Vector3 and command.y == 1.0, "blocked recovery holds the brake")
	recover.reset()
	host.drivable = false
	command = recover.update(host, line, Vector3(0, 0, -120.0), 12.0, true, 0.1)
	_check(recover.retired and command.y == 1.0, "crashed or undriveable vehicle cannot resume AI racing")
	host.drivable = true
	recover.reset()
	_check(not recover.retired, "explicit player recovery clears the driver's retired state")

func _replan_checks(host: TestCar, track: Straight) -> void:
	var driver = Driver.new()
	driver.configure(host, track, 0.0, 0.8, 0.7)
	host.drivable = false
	driver.drive(0.1, [host])
	_check(driver.retired, "undriveable car enters the public retired state")
	var reason: String = driver.retirement_reason
	var old_speed: float = driver.planner.target_at(930.0)
	_check(driver.replan(1.0, 0.6), "changed live settings rebuild the envelope")
	_check(driver.planner.target_at(930.0) < old_speed, "live wetness and pace update the planned speed")
	_check(driver.retired and driver.retirement_reason == reason and is_equal_approx(driver.lane, 0.7), "replanning preserves retirement and lane state")
	_check(not driver.replan(1.0, 0.6), "unrelated settings do not rebuild the unchanged envelope")
	host.drivable = true

func _classification_checks(vehicles: Array) -> void:
	var trackers: Array[ApexLapTracker] = []
	for i: int in 3:
		var tracker := ApexLapTracker.new()
		tracker.setup(1000.0)
		tracker.finished = i < 2
		tracker.completed_laps = 1 if i < 2 else 0
		tracker.elapsed = 120.0 if i == 0 else 110.0
		tracker.progress = 1001.0 if i == 0 else 1000.0
		trackers.append(tracker)
	trackers[2].progress = 1400.0
	var rows: Array[Dictionary] = Classification.build(vehicles, trackers, [false, false, true], ["", "", "Motor dañado"])
	_check(int(rows[0].index) == 1, "circuit finish order follows arrival time rather than projection beyond the line")
	_check(int(rows[2].index) == 2 and bool(rows[2].retired), "DNF remains explicit and below active finishers")
	var career := ApexCareer.new()
	career.record(0, {"retired": true, "valid_laps": 1, "laps": 1})
	_check(career.credits == 0 and career.records.is_empty(), "retirement never grants championship rewards")

func _car(title: String, pose: Vector3, speed: float) -> TestCar:
	var body := TestCar.new()
	body.name = title
	body.freeze = true
	root.add_child(body)
	body.position = pose
	body.linear_velocity = Vector3(0, 0, -speed)
	return body

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
