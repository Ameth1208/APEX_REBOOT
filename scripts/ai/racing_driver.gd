class_name ApexRacingDriver
extends RefCounted
## Every manoeuvre uses the player's pedals and steering, including recovery.

var vehicle: RigidBody3D
var track: Node3D
var planner = preload("res://scripts/ai/speed_planner.gd").new()
var distance: float = 0.0
var target_speed: float = 0.0
var lane: float = 0.0
var status_text: String = "Trazada"
var retired: bool = false
var retirement_reason: String = ""
var recovery_count: int:
	get:
		return _recovery.count
var _traffic = preload("res://scripts/ai/traffic_planner.gd").new()
var _recovery = preload("res://scripts/ai/physical_recovery.gd").new()
var _home_lane: float = 0.0
var _steer: float = 0.0
var _yaw_integral: float = 0.0
var _condition_time: float = 0.0
var _handling_scale: float = 1.0
var _pace: float = 0.84
var _plan_signature: Array = []

func configure(body: RigidBody3D, circuit: Node3D, wetness: float, pace: float, offset: float = 0.0) -> void:
	vehicle = body
	track = circuit
	_home_lane = offset
	_plan_signature.clear()
	replan(wetness, pace)
	_recovery.count = 0
	reset_recovery()

func replan(wetness: float, pace: float = -1.0) -> bool:
	if pace >= 0.0:
		_pace = pace
	var signature: Array = [wetness, _pace, vehicle.grip_factor, vehicle.aero_scale]
	if signature == _plan_signature:
		return false
	_plan_signature = signature
	var tuned: Dictionary = vehicle.profile.duplicate(true)
	tuned["tire_grip_scale"] = vehicle.grip_factor
	tuned["downforce_area_m2"] = float(tuned.get("downforce_area_m2", 0.0)) * vehicle.aero_scale
	planner.build(track, tuned, wetness, _pace)
	return true

func reset_recovery() -> void:
	distance = track.closest_distance(vehicle.global_position)
	_yaw_integral = 0.0
	_steer = 0.0
	retired = false
	retirement_reason = ""
	_recovery.reset()
	_traffic.configure(_home_lane)
	lane = _home_lane

func drive(delta: float, traffic: Array) -> void:
	distance = track.closest_distance(vehicle.global_position, distance)
	var line: Dictionary = track.sample_at(distance)
	var speed: float = vehicle.linear_velocity.length()
	_condition_time -= delta
	if _condition_time <= 0.0:
		_condition_time = 0.25
		var condition: Dictionary = vehicle.telemetry()
		_handling_scale = sqrt(clampf(float(condition.get("steering_health", 1.0)) * 0.65 + float(condition.get("aero_health", 1.0)) * 0.35, 0.3, 1.0))
	if not planner.closed and distance >= track.get_length() - ApexLapTracker.FINISH_TOLERANCE_M:
		target_speed = 0.0
		status_text = "Meta"
		vehicle.set_controls(0.0, 1.0, 0.0)
		return
	var lookahead: float = clampf(5.0 + speed * 0.60, 7.0, 36.0)
	var ahead: Dictionary = track.sample_at(distance + lookahead)
	target_speed = _planned_speed(speed, line, ahead)
	_traffic.update(vehicle, track, distance, target_speed, planner.braking_at(distance), delta, traffic)
	lane = float(_traffic.lane)
	target_speed = minf(target_speed, float(_traffic.speed_limit))
	status_text = str(_traffic.status)
	if absf(lane - _home_lane) > 0.3:
		# A close, slow bypass needs steering before the following envelope stops
		# the car. Aim using the commanded speed as well as the present speed.
		lookahead = minf(lookahead, 4.0 + minf(speed, target_speed) * 0.45)
		ahead = track.sample_at(distance + lookahead)
	var target: Vector3 = ahead.position + ahead.right * lane
	if not planner.closed:
		target += Vector3(ahead.forward) * maxf(0.0, distance + lookahead - track.get_length())
	var commands: Variant = _recovery.update(vehicle, line, target, target_speed, bool(_traffic.rear_clear), delta)
	retired = bool(_recovery.retired)
	retirement_reason = str(_recovery.reason)
	if commands is Vector3:
		status_text = "Abandono" if retired else str(_recovery.state)
		vehicle.set_controls(commands.x, commands.y, commands.z)
		return
	var local_target: Vector3 = vehicle.to_local(target)
	var horizontal_distance: float = maxf(2.0, Vector2(local_target.x, local_target.z).length())
	var curvature: float = 2.0 * local_target.x / (horizontal_distance * horizontal_distance)
	var angle: float = atan(float(vehicle.profile.get("wheelbase_m", 2.6)) * curvature)
	if not vehicle.is_motorcycle:
		var yaw_error: float = speed * curvature + vehicle.angular_velocity.dot(vehicle.global_basis.y)
		_yaw_integral = clampf(_yaw_integral + yaw_error * delta, -0.5, 0.5)
		angle += clampf(yaw_error * 0.08 + _yaw_integral * 0.04, -0.16, 0.16)
	var max_angle: float = deg_to_rad(float(vehicle.profile.get("max_steer_deg", 32.0)))
	_steer = move_toward(_steer, _steering_input(speed, angle, max_angle), delta * 4.0)
	var difference: float = target_speed - speed
	vehicle.set_controls(clampf(difference * 0.55, 0.0, 1.0), clampf(-difference * 0.32, 0.0, 1.0), _steer)

func _planned_speed(speed: float, line: Dictionary, ahead: Dictionary) -> float:
	var target: float = planner.target_at(distance + speed * 0.15) * _handling_scale
	if not planner.closed and track.get_length() - distance < 15.0:
		# Cross the timing line slowly instead of stopping short of the finish.
		target = maxf(target, 2.2)
	var aero_load: float = float(vehicle.downforce_n) / maxf(float(vehicle.downforce_multiplier), 0.4)
	var weight: float = float(vehicle.mass) * 9.81
	target *= sqrt((weight + aero_load * float(vehicle.downforce_multiplier)) / maxf(weight + aero_load, 1.0))
	var error: float = absf((vehicle.global_position - Vector3(line.position)).dot(Vector3(line.right)))
	var half_width: float = float(vehicle.profile.get("body_width_m", 1.8)) * 0.5
	var safe_half_width: float = maxf(1.0, float(line.width) * 0.5 - half_width - 0.5)
	if error > safe_half_width * 0.45:
		target *= lerpf(1.0, 0.35, clampf((error / safe_half_width - 0.45) / 0.7, 0.0, 1.0))
	var sideways_speed: float = absf(vehicle.linear_velocity.dot(vehicle.global_basis.x))
	if sideways_speed > 2.5:
		target *= clampf(2.5 / sideways_speed, 0.35, 1.0)
	if (-vehicle.global_basis.z).dot(Vector3(ahead.forward)) < 0.5:
		target = minf(target, 7.0)
	return target

func _steering_input(speed: float, angle: float, max_angle: float) -> float:
	if not vehicle.is_motorcycle:
		return clampf(angle * (1.0 + speed * 0.045) / max_angle, -1.0, 1.0)
	var lean_limit: float = deg_to_rad(float(vehicle.profile.get("max_lean_deg", 51.0)))
	var blend: float = smoothstep(4.0, 12.0, speed)
	var wheelbase: float = float(vehicle.profile.get("wheelbase_m", 1.40))
	var lower: float = -1.0
	var upper: float = 1.0
	for _iteration: int in 12:
		var candidate: float = (lower + upper) * 0.5
		var fast_angle: float = atan(9.81 * tan(candidate * lean_limit) * wheelbase / maxf(speed * speed, 1.0))
		var actual_angle: float = lerpf(candidate * max_angle, fast_angle, blend)
		if actual_angle < angle:
			lower = candidate
		else:
			upper = candidate
	return clampf((lower + upper) * 0.5, -1.0, 1.0)
