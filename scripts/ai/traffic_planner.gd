class_name ApexTrafficPlanner
extends RefCounted
## Track-relative footprints, time headway and checked passing corridors.

var lane: float = 0.0
var speed_limit: float = INF
var status: String = "Trazada"
var rear_clear: bool = true
var gap_m: float = INF
var _home: float = 0.0
var _wanted: float = 0.0
var _timer: float = 0.0
var _passing_id: int = 0
var _clear_time: float = 0.0

func configure(offset: float) -> void:
	_home = offset
	lane = offset
	_wanted = offset
	_timer = 0.0
	_passing_id = 0
	_clear_time = 0.0

func update(body: RigidBody3D, track: Node3D, distance: float, cruise: float, braking: float, delta: float, traffic: Array) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.12
		_evaluate(body, track, distance, cruise, braking, traffic)
	# A continuous request avoids steering impulses when the chosen corridor changes.
	lane = move_toward(lane, _wanted, delta * 1.05)

func _evaluate(body: RigidBody3D, track: Node3D, distance: float, cruise: float, braking: float, traffic: Array) -> void:
	var here: Dictionary = track.sample_at(distance)
	var speed: float = maxf(0.0, body.linear_velocity.dot(Vector3(here.forward)))
	var host_lane: float = (body.global_position - Vector3(here.position)).dot(Vector3(here.right))
	var half_width: float = float(body.profile.get("body_width_m", 1.8)) * 0.5
	var half_length: float = float(body.profile.get("length_m", 4.5)) * 0.5
	var passing_horizon: float = maxf(35.0, speed * 4.5)
	var stopping_horizon: float = speed * speed / (2.0 * maxf(braking, 0.35)) + speed * 0.65 + half_length + 8.0
	var horizon: float = maxf(passing_horizon, stopping_horizon)
	var ahead: Dictionary = track.sample_at(distance + maxf(15.0, speed))
	var bound: float = maxf(0.0, minf(float(here.width), float(ahead.width)) * 0.5 - half_width - 0.65)
	var observations: Array[Dictionary] = _observe(body, track, distance, here, traffic, maxf(120.0, horizon))
	var leader: Dictionary = {}
	gap_m = INF
	rear_clear = true
	speed_limit = cruise
	status = "Trazada"
	for other: Dictionary in observations:
		var overlap: bool = absf(float(other.lane) - host_lane) < half_width + float(other.half_width) + 0.35
		if not overlap:
			continue
		var separation: float = float(other.distance)
		if separation < 0.0 and -separation < half_length + float(other.half_length) + 5.0:
			rear_clear = false
		# Allow the lane request and steering response to develop before braking
		# behind a stopped car makes further lateral movement impossible.
		if separation <= 0.0 or separation > horizon:
			continue
		var gap: float = separation - half_length - float(other.half_length)
		if gap < gap_m:
			gap_m = gap
			leader = other
	if _passing_id != 0:
		status = "Adelantando"
		var still_ahead: bool = false
		for other: Dictionary in observations:
			if int(other.id) == _passing_id and float(other.distance) > -half_length - float(other.half_length) - 5.0:
				still_ahead = true
		_clear_time = 0.0 if still_ahead else _clear_time + 0.12
		if _clear_time > 0.9:
			_passing_id = 0
		if not _lane_clear(_wanted, half_width, half_length, speed, observations):
			_wanted = clampf(host_lane, -bound, bound)
			_passing_id = 0
			status = "Cediendo paso"
			speed_limit = minf(speed_limit, maxf(0.0, speed - 1.5))
	if not leader.is_empty():
		var lead_speed: float = maxf(0.0, float(leader.speed))
		var buffer: float = 2.0 + speed * 0.55
		var safe_speed: float = sqrt(lead_speed * lead_speed + 2.0 * maxf(braking, 0.35) * maxf(0.0, gap_m - buffer))
		if gap_m < buffer:
			safe_speed = minf(safe_speed, lead_speed * clampf(gap_m / buffer, 0.0, 1.0))
		speed_limit = minf(cruise, safe_speed)
		status = "Siguiendo" if _passing_id == 0 else "Adelantando"
		if _passing_id == 0 and cruise > lead_speed + 1.5 and gap_m > 4.0 and float(leader.distance) <= passing_horizon:
			var clearance: float = half_width + float(leader.half_width) + 0.8
			var candidates: Array[float] = [float(leader.lane) - clearance, float(leader.lane) + clearance]
			if absf(candidates[1] - host_lane) < absf(candidates[0] - host_lane):
				candidates.reverse()
			for candidate: float in candidates:
				if absf(candidate) <= bound and _lane_clear(candidate, half_width, half_length, speed, observations):
					_wanted = candidate
					_passing_id = int(leader.id)
					_clear_time = 0.0
					status = "Adelantando"
					break
	if _passing_id == 0:
		var home: float = clampf(_home, -bound, bound)
		if _lane_clear(home, half_width, half_length, speed, observations):
			_wanted = home
		elif leader.is_empty():
			_wanted = clampf(host_lane, -bound, bound)
			status = "Manteniendo carril"
	_wanted = clampf(_wanted, -bound, bound)

func _observe(body: RigidBody3D, track: Node3D, distance: float, here: Dictionary, traffic: Array, horizon: float) -> Array[Dictionary]:
	var observed: Array[Dictionary] = []
	var host_height: float = (body.global_position - Vector3(here.position)).dot(Vector3(here.normal))
	for other: RigidBody3D in traffic:
		if other == body or not is_instance_valid(other) or body.global_position.distance_squared_to(other.global_position) > horizon * horizon:
			continue
		var station: float = track.closest_distance(other.global_position, distance)
		var sample: Dictionary = track.sample_at(station)
		var offset: Vector3 = other.global_position - Vector3(sample.position)
		# Cars on the other deck of a bridge must not become imaginary obstacles.
		if absf(offset.dot(Vector3(sample.normal)) - host_height) > 2.4:
			continue
		var separation: float = station - distance
		if bool(track.closed):
			separation = wrapf(separation, -track.get_length() * 0.5, track.get_length() * 0.5)
		if absf(separation) > horizon:
			continue
		observed.append({"id": other.get_instance_id(), "distance": separation,
			"lane": offset.dot(Vector3(sample.right)), "speed": other.linear_velocity.dot(Vector3(sample.forward)),
			"half_width": float(other.profile.get("body_width_m", 1.8)) * 0.5,
			"half_length": float(other.profile.get("length_m", 4.5)) * 0.5})
	return observed

func _lane_clear(candidate: float, half_width: float, half_length: float, speed: float, observations: Array[Dictionary]) -> bool:
	for other: Dictionary in observations:
		if absf(candidate - float(other.lane)) >= half_width + float(other.half_width) + 0.45:
			continue
		var separation: float = float(other.distance)
		var prediction: float = separation + (float(other.speed) - speed) * 1.2
		var front: float = half_length + float(other.half_length) + 5.0 + speed * 0.3
		var rear: float = half_length + float(other.half_length) + 4.0
		if minf(separation, prediction) < front and maxf(separation, prediction) > -rear:
			return false
	return true
