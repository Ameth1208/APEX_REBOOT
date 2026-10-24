class_name TrackIntelligence
extends RefCounted
## Dynamic Feasible Speed Envelope.
## For each metre of track: the maximum speed this vehicle can carry and
## still correctly complete what comes next.
## Computed BACKWARD from corners, with speed-dependent braking (downforce).
## Same brain for player line, AI targets and brake points.

const Tyres = preload("res://scripts/physics/tyre_forces.gd")

## Sampling resolution along the track (metres).
var sample_spacing: float = 2.0
## Lookahead time for the player line (seconds).
var lookahead_s: float = 3.5

var samples: Array[Dictionary] = []
var distances: PackedFloat32Array = PackedFloat32Array()
var curvatures: PackedFloat32Array = PackedFloat32Array()
var line_offsets: PackedFloat32Array = PackedFloat32Array()
## Base speed envelope (m/s): max speed at each point to still complete the track.
var base_speeds: PackedFloat32Array = PackedFloat32Array()
## Dynamic envelope adjusted for current conditions.
var dynamic_speeds: PackedFloat32Array = PackedFloat32Array()
## Brake limit curve: max speed from which you can still brake to target (m/s).
## Computed during backward pass; used for player colouring.
var brake_limits: PackedFloat32Array = PackedFloat32Array()

var _total_length: float = 0.0
var _vehicle_profile: Dictionary = {}
var _wetness: float = 0.0

func build(track_samples: Array[Dictionary], vehicle: Dictionary, wetness: float = 0.0) -> void:
	samples = track_samples
	_wetness = wetness
	_vehicle_profile = vehicle.duplicate(true)
	var brake_spec: ApexEngineSpec = ApexEngineSpec.from_dictionary(vehicle, str(vehicle.get("kind", "")) == "motorcycle", float(vehicle.get("mass_kg", 1000.0)))
	_vehicle_profile["brake_force_n"] = brake_spec.brake_force_total_n
	if samples.size() < 2:
		return
	_compute_distances()
	_compute_curvatures()
	_generate_racing_line()
	_compute_speed_envelope()

func _compute_distances() -> void:
	distances.resize(samples.size())
	distances[0] = 0.0
	for i: int in range(1, samples.size()):
		var p0: Vector3 = samples[i - 1]["position"]
		var p1: Vector3 = samples[i]["position"]
		distances[i] = distances[i - 1] + Vector2(p1.x - p0.x, p1.z - p0.z).length()
	_total_length = distances[samples.size() - 1]

func _compute_curvatures() -> void:
	curvatures.resize(samples.size())
	var n: int = samples.size()
	if n < 3:
		curvatures.fill(0.0)
		return
	for i: int in range(n):
		var prev: int = maxi(i - 1, 0)
		var next: int = mini(i + 1, n - 1)
		var p0: Vector2 = Vector2(samples[prev]["position"].x, samples[prev]["position"].z)
		var p1: Vector2 = Vector2(samples[i]["position"].x, samples[i]["position"].z)
		var p2: Vector2 = Vector2(samples[next]["position"].x, samples[next]["position"].z)
		var d1: Vector2 = p1 - p0
		var d2: Vector2 = p2 - p1
		var l1: float = d1.length()
		var l2: float = d2.length()
		if l1 < 0.001 or l2 < 0.001:
			curvatures[i] = 0.0
			continue
		var cross: float = d1.x * d2.y - d1.y * d2.x
		var avg_len: float = (l1 + l2) * 0.5
		curvatures[i] = cross / (avg_len * avg_len)

func _generate_racing_line() -> void:
	var n: int = samples.size()
	line_offsets.resize(n)
	line_offsets.fill(0.0)
	if n < 3:
		return
	var max_offset_factor: float = 0.42
	for i: int in range(n):
		var half_width: float = float(samples[i].get("width", 12.0)) * 0.5
		var margin: float = 1.5
		var available: float = maxf(half_width - margin, 0.5)
		var kappa: float = curvatures[i]
		if absf(kappa) < 0.001:
			line_offsets[i] = 0.0
		else:
			var direction: float = -signf(kappa)
			line_offsets[i] = direction * available * max_offset_factor
	var smoothed: PackedFloat32Array = line_offsets.duplicate()
	for _pass: int in range(8):
		for i: int in range(1, n - 1):
			smoothed[i] = (line_offsets[i - 1] + line_offsets[i] * 2.0 + line_offsets[i + 1]) * 0.25
		line_offsets = smoothed.duplicate()

## Dynamic Feasible Speed Envelope (Section: converge multi-pass).
## 1. Track speed limits (max corner speed)
## 2. Backward braking pass (speed-dependent a_brake)
## 3. Forward acceleration pass
## 4. Repeat 2-3 until converged
func _compute_speed_envelope() -> void:
	var n: int = samples.size()
	base_speeds.resize(n)
	dynamic_speeds.resize(n)
	brake_limits.resize(n)
	if n < 2:
		return
	# Pass 1: track speed limits from corner physics.
	for i: int in range(n):
		base_speeds[i] = _max_corner_speed(i)
	# Converge: alternate backward/forward passes.
	for iteration: int in range(3):
		_backward_braking_pass(n)
		_forward_acceleration_pass(n)
	dynamic_speeds = base_speeds.duplicate()

## Backward braking pass with speed-dependent deceleration.
## For each point, find max speed from which you can brake to the next
## point's speed. a_brake = f(v) because downforce ∝ v².
func _backward_braking_pass(n: int) -> void:
	for i: int in range(n - 2, -1, -1):
		var ds: float = maxf(distances[i + 1] - distances[i], 0.1)
		var v_next: float = base_speeds[i + 1]
		# Integrate backward in small steps: v decreases as we brake.
		# Start from candidate speed, integrate forward through segment,
		# check we can reach v_next. Binary search on candidate.
		var lo: float = v_next
		var hi: float = _vehicle_top_speed() * 1.1
		for _b: int in range(18):
			var mid: float = (lo + hi) * 0.5
			if _can_brake_to(mid, v_next, ds):
				lo = mid
			else:
				hi = mid
		base_speeds[i] = minf(base_speeds[i], lo)
		brake_limits[i] = lo

## Can we brake from v0 to vt across distance ds with a_brake(v)?
## Integrates in 2m substeps because a_brake depends on speed.
func _can_brake_to(v0: float, vt: float, ds: float) -> bool:
	var step: float = 2.0
	var v: float = v0
	var travelled: float = 0.0
	while travelled < ds and v > vt:
		var a: float = _available_braking(v)
		var dv_sq: float = 2.0 * a * step
		v = sqrt(maxf(v * v - dv_sq, vt * vt))
		travelled += step
	return v <= vt + 0.1

## Forward acceleration pass.
func _forward_acceleration_pass(n: int) -> void:
	for i: int in range(n - 1):
		var ds: float = maxf(distances[i + 1] - distances[i], 0.1)
		var a_accel: float = _available_acceleration(base_speeds[i])
		var v_curr: float = base_speeds[i]
		var v_max_next: float = sqrt(v_curr * v_curr + 2.0 * a_accel * ds)
		base_speeds[i + 1] = minf(base_speeds[i + 1], v_max_next)

## Max safe cornering speed at sample i.
func _max_corner_speed(i: int) -> float:
	var kappa: float = absf(curvatures[i])
	if kappa < 0.0005:
		return _vehicle_top_speed()
	var mass: float = float(_vehicle_profile.get("mass_kg", 1400.0))
	var bank: float = deg_to_rad(float(samples[i].get("bank", 0.0)))
	var grade: float = deg_to_rad(float(samples[i].get("grade", 0.0)))
	var mu: float = _available_grip()
	var g: float = 9.81
	var a_y_max: float = mu * g * (cos(bank) + sin(bank) / maxf(mu, 0.1))
	a_y_max *= cos(grade) * 0.95 + 0.05
	# Downforce increases grip with speed: iterate to converge.
	var v: float = sqrt(a_y_max / kappa)
	for _iter: int in range(6):
		var df: float = _downforce_at_speed(v)
		var extra_grip: float = df / (mass * g)
		var a_y_total: float = (mu * (1.0 + extra_grip)) * g * (cos(bank) + sin(bank) / maxf(mu, 0.1))
		var v_new: float = sqrt(a_y_total / kappa)
		v = lerpf(v, v_new, 0.5)
	return clampf(v, 5.0, _vehicle_top_speed())

## Available braking deceleration at a given speed (a_brake = f(v)).
func _available_braking(speed: float) -> float:
	var mu: float = _available_grip()
	var g: float = 9.81
	var mass: float = float(_vehicle_profile.get("mass_kg", 1400.0))
	var base: float = mu * g
	# Aero braking: downforce increases grip at speed.
	var df: float = _downforce_at_speed(speed)
	var extra: float = df / (mass * g)
	# Brake system limit (may be damaged).
	var brake_force: float = float(_vehicle_profile.get("brake_force_n", mass * 16.0))
	var brake_decel: float = brake_force / mass
	# Gravity component: downhill helps braking, uphill hurts.
	var brake_health: float = clampf(float(_vehicle_profile.get("brake_health", 1.0)), 0.4, 1.0)
	return minf(base * (1.0 + extra), brake_decel) * brake_health

## Available acceleration at a given speed.
func _available_acceleration(speed: float) -> float:
	var mass: float = float(_vehicle_profile.get("mass_kg", 1400.0))
	var power_kw: float = float(_vehicle_profile.get("engine_power_kw", 200.0))
	var power_w: float = power_kw * 1000.0
	var mu: float = _available_grip()
	var traction_limit: float = mu * 9.81
	var power_limit: float = power_w / maxf(mass * maxf(speed, 5.0), 1.0)
	var drag: float = _drag_decel(speed)
	return maxf(minf(traction_limit, power_limit) - drag, 0.5)

func _vehicle_top_speed() -> float:
	var power_kw: float = float(_vehicle_profile.get("engine_power_kw", 200.0))
	var drag_area: float = float(_vehicle_profile.get("drag_area_m2", 0.7))
	var rho: float = 1.225
	var v_max: float = pow(2.0 * power_kw * 1000.0 / (rho * drag_area), 1.0 / 3.0)
	return clampf(v_max, 30.0, 160.0)

func _available_grip() -> float:
	var surface: String = str(_vehicle_profile.get("surface", "asphalt"))
	var base_mu: float = float(Tyres.surface_data(surface).get("mu", 1.2))
	var tyre_temp: float = float(_vehicle_profile.get("tyre_temp_c", 80.0))
	var wear: float = clampf(float(_vehicle_profile.get("tyre_wear", 0.0)), 0.0, 1.0)
	var temp_factor: float = Tyres.temperature_grip_factor(tyre_temp)
	var wet_factor: float = 1.0 - _wetness * float(Tyres.surface_data(surface).get("wet_loss", 0.3))
	var wear_factor: float = 1.0 - wear * 0.25
	return base_mu * temp_factor * wet_factor * wear_factor

func _downforce_at_speed(speed: float) -> float:
	var area: float = float(_vehicle_profile.get("downforce_area_m2", 0.8))
	var rho: float = 1.225
	return 0.5 * rho * speed * speed * area

func _drag_decel(speed: float) -> float:
	var area: float = float(_vehicle_profile.get("drag_area_m2", 0.7))
	var mass: float = float(_vehicle_profile.get("mass_kg", 1400.0))
	var rho: float = 1.225
	return 0.5 * rho * area * speed * speed / mass

func sample_at_position(pos: Vector3) -> int:
	var best: int = 0
	var best_dist: float = INF
	for i: int in range(samples.size()):
		var p: Vector3 = samples[i]["position"]
		var d: float = Vector2(p.x - pos.x, p.z - pos.z).length_squared()
		if d < best_dist:
			best_dist = d
			best = i
	return best

## Dynamic colour for the player at a given point.
## Uses R_v = v_current / v_brakeLimit(s) and BrakeMargin.
## The key question: "If I start braking here, can I reach the corner right?"
func brake_risk(player_index: int, current_speed: float, is_braking: bool, dt: float) -> Dictionary:
	if base_speeds.is_empty() or player_index < 0 or player_index >= base_speeds.size():
		return {"risk": 0.0, "color": Color.GREEN, "braking_needed": false}
	var n: int = samples.size()
	# Lookahead: find the binding constraint (lowest brake limit ahead).
	var lookahead_dist: float = current_speed * lookahead_s
	var binding_speed: float = base_speeds[player_index]
	var binding_index: int = player_index
	var acc: float = 0.0
	for i: int in range(player_index, n):
		acc = distances[i] - distances[player_index]
		if acc > lookahead_dist:
			break
		if base_speeds[i] < binding_speed:
			binding_speed = base_speeds[i]
			binding_index = i
	# Distance to the binding point.
	var dist_to_target: float = maxf(distances[binding_index] - distances[player_index], 1.0)
	# v_brakeLimit: max speed from which we can still brake to binding_speed.
	var v_brake_limit: float = _brake_limit_from(current_speed, binding_speed, dist_to_target)
	# R_v = v_current / v_brakeLimit (Section: colour thresholds).
	var r_v: float = current_speed / maxf(v_brake_limit, 1.0)
	# BrakeMargin = distance available - distance required.
	var d_required: float = 0.0
	if current_speed > binding_speed:
		d_required = (current_speed * current_speed - binding_speed * binding_speed) / (2.0 * maxf(_available_braking(current_speed), 0.5))
	var brake_margin: float = dist_to_target - d_required
	# Combined risk.
	var risk: float = 0.0
	if r_v >= 1.0:
		# Over the limit: scale how badly.
		risk = 1.0 + (r_v - 1.0) * 2.0
	elif r_v >= 0.99:
		risk = 0.75 + (r_v - 0.99) / 0.01 * 0.25
	elif r_v >= 0.93:
		risk = 0.35 + (r_v - 0.93) / 0.06 * 0.40
	else:
		risk = r_v / 0.93 * 0.35
	# BrakeMargin refines it.
	if brake_margin < -10.0:
		risk = maxf(risk, 1.05)
	elif brake_margin < 20.0:
		risk = maxf(risk, 0.99)
	elif brake_margin < 80.0:
		risk = maxf(risk, 0.75)
	var color: Color = _risk_color(risk)
	return {"risk": risk, "color": color, "braking_needed": r_v > 0.93,
		"r_v": r_v, "brake_margin": brake_margin,
		"v_brake_limit": v_brake_limit, "target_speed": binding_speed,
		"dist_to_target": dist_to_target}

## Compute max speed from which braking reaches vt across dist.
func _brake_limit_from(v_current: float, vt: float, dist: float) -> float:
	# Binary search on v0.
	var lo: float = vt
	var hi: float = maxf(v_current, vt) * 1.3 + 10.0
	for _b: int in range(14):
		var mid: float = (lo + hi) * 0.5
		if _can_brake_to(mid, vt, dist):
			lo = mid
		else:
			hi = mid
	return lo

## Continuous colour from risk score.
static func _risk_color(risk: float) -> Color:
	var r: float = clampf(risk, 0.0, 1.5)
	if r < 0.35:
		var t: float = r / 0.35
		return Color(0.2, 0.9, 0.2).lerp(Color(0.7, 0.9, 0.1), t)
	elif r < 0.75:
		var t: float = (r - 0.35) / 0.40
		return Color(0.7, 0.9, 0.1).lerp(Color(1.0, 0.55, 0.0), t)
	elif r < 1.0:
		var t: float = (r - 0.75) / 0.25
		return Color(1.0, 0.55, 0.0).lerp(Color(1.0, 0.1, 0.1), t)
	else:
		return Color(1.0, 0.0, 0.0)

func target_speed(index: int) -> float:
	if index >= 0 and index < dynamic_speeds.size():
		return dynamic_speeds[index]
	return 0.0

func target_position(index: int) -> Vector3:
	if index < 0 or index >= samples.size():
		return Vector3.ZERO
	var p: Vector3 = samples[index]["position"]
	var right: Vector3 = samples[index].get("right", Vector3.RIGHT)
	return p + right * line_offsets[index]

## AI brake command: BrakeInput = a_required / a_available, clamped 0..1.
func ai_brake_input(index: int, current_speed: float) -> float:
	if index < 0 or index >= dynamic_speeds.size():
		return 0.0
	var target: float = dynamic_speeds[index]
	if current_speed <= target:
		return 0.0
	# Look ahead for the target point.
	var n: int = samples.size()
	var lookahead: float = current_speed * 2.5
	var binding_speed: float = target
	var binding_index: int = index
	var acc: float = 0.0
	for i: int in range(index, n):
		acc = distances[i] - distances[index]
		if acc > lookahead:
			break
		if dynamic_speeds[i] < binding_speed:
			binding_speed = dynamic_speeds[i]
			binding_index = i
	var dist: float = maxf(distances[binding_index] - distances[index], 1.0)
	if current_speed <= binding_speed:
		return 0.0
	var a_required: float = (current_speed * current_speed - binding_speed * binding_speed) / (2.0 * dist)
	var a_available: float = _available_braking(current_speed)
	return clampf(a_required / maxf(a_available, 0.5), 0.0, 1.0)

## Update dynamic profile for current conditions (5-10 Hz).
func update_dynamic(vehicle_state: Dictionary) -> void:
	_vehicle_profile.merge(vehicle_state, true)
	_wetness = float(vehicle_state.get("wetness", _wetness))
	if samples.size() >= 2:
		_compute_speed_envelope()

func total_length() -> float:
	return _total_length

func sample_count() -> int:
	return samples.size()
