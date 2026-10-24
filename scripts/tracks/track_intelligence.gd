class_name TrackIntelligence
extends RefCounted
## Physical racing line + dynamic speed profile + braking risk.
## Same brain for player and AI. Everything is computed from vehicle physics,
## never from hardcoded "this corner is red".

const Tyres = preload("res://scripts/physics/tyre_forces.gd")

## Sampling resolution along the track (metres).
var sample_spacing: float = 2.0
## Lookahead time for the player line (seconds).
var lookahead_s: float = 3.5

## Track geometry per sample.
var samples: Array[Dictionary] = []
## Cumulative distance along the track.
var distances: PackedFloat32Array = PackedFloat32Array()
## Curvature per sample (1/m).
var curvatures: PackedFloat32Array = PackedFloat32Array()
## Racing line lateral offset per sample (metres from centre).
var line_offsets: PackedFloat32Array = PackedFloat32Array()
## Base speed profile from vehicle physics (m/s).
var base_speeds: PackedFloat32Array = PackedFloat32Array()
## Dynamic speed profile adjusted for current conditions.
var dynamic_speeds: PackedFloat32Array = PackedFloat32Array()

var _total_length: float = 0.0
var _vehicle_profile: Dictionary = {}
var _wetness: float = 0.0

## Build from track definition and vehicle profile.
func build(track_samples: Array[Dictionary], vehicle: Dictionary, wetness: float = 0.0) -> void:
	samples = track_samples
	_wetness = wetness
	_vehicle_profile = vehicle
	if samples.size() < 2:
		return
	_compute_distances()
	_compute_curvatures()
	_generate_racing_line()
	_compute_speed_profile()

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

## Generate racing line: minimise curvature subject to track limits.
## First pass: move toward inside of corners. Second pass: smooth.
func _generate_racing_line() -> void:
	var n: int = samples.size()
	line_offsets.resize(n)
	line_offsets.fill(0.0)
	if n < 3:
		return
	# Pass 1: shift toward inside of each corner.
	var max_offset_factor: float = 0.42
	for i: int in range(n):
		var half_width: float = float(samples[i].get("width", 12.0)) * 0.5
		var margin: float = 1.5
		var available: float = maxf(half_width - margin, 0.5)
		var kappa: float = curvatures[i]
		if absf(kappa) < 0.001:
			line_offsets[i] = 0.0
		else:
			# Shift toward inside (negative curvature = left turn = shift right).
			var direction: float = -signf(kappa)
			line_offsets[i] = direction * available * max_offset_factor
	# Pass 2: smooth the line (minimise curvature of the racing line itself).
	var smoothed: PackedFloat32Array = line_offsets.duplicate()
	for _pass: int in range(8):
		for i: int in range(1, n - 1):
			smoothed[i] = (line_offsets[i - 1] + line_offsets[i] * 2.0 + line_offsets[i + 1]) * 0.25
		line_offsets = smoothed.duplicate()

## Compute base speed profile using vehicle physics.
## Three passes: max corner speed, backward braking, forward acceleration.
func _compute_speed_profile() -> void:
	var n: int = samples.size()
	base_speeds.resize(n)
	dynamic_speeds.resize(n)
	if n < 2:
		return
	# Pass 1: maximum cornering speed per sample.
	for i: int in range(n):
		base_speeds[i] = _max_corner_speed(i)
	# Pass 2: backward braking pass (from end to start).
	for i: int in range(n - 2, -1, -1):
		var ds: float = maxf(distances[i + 1] - distances[i], 0.1)
		var a_brake: float = _available_braking(base_speeds[i + 1])
		var v_next: float = base_speeds[i + 1]
		var v_max_prev: float = sqrt(v_next * v_next + 2.0 * a_brake * ds)
		base_speeds[i] = minf(base_speeds[i], v_max_prev)
	# Pass 3: forward acceleration pass.
	for i: int in range(n - 1):
		var ds: float = maxf(distances[i + 1] - distances[i], 0.1)
		var a_accel: float = _available_acceleration(base_speeds[i])
		var v_curr: float = base_speeds[i]
		var v_max_next: float = sqrt(v_curr * v_curr + 2.0 * a_accel * ds)
		base_speeds[i + 1] = minf(base_speeds[i + 1], v_max_next)
	dynamic_speeds = base_speeds.duplicate()

## Maximum safe cornering speed at sample i, considering grip, banking, grade.
func _max_corner_speed(i: int) -> float:
	var kappa: float = absf(curvatures[i])
	if kappa < 0.0005:
		# Nearly straight: limited by top speed.
		return _vehicle_top_speed()
	var mass: float = float(_vehicle_profile.get("mass_kg", 1400.0))
	var bank: float = deg_to_rad(float(samples[i].get("bank", 0.0)))
	var grade: float = deg_to_rad(float(samples[i].get("grade", 0.0)))
	# Available lateral grip (simplified: mu * g adjusted by banking).
	var mu: float = _available_grip()
	var g: float = 9.81
	# Banking helps: effective gravity component into the corner.
	var a_y_max: float = mu * g * (cos(bank) + sin(bank) / maxf(mu, 0.1))
	# Grade reduces available grip for uphill, increases for downhill.
	a_y_max *= cos(grade) * 0.95 + 0.05
	# Downforce increases grip with speed (iterate to converge).
	var v: float = sqrt(a_y_max / kappa)
	for _iter: int in range(6):
		var df: float = _downforce_at_speed(v)
		var extra_grip: float = df / (mass * g)
		var a_y_total: float = (mu * (1.0 + extra_grip)) * g * (cos(bank) + sin(bank) / maxf(mu, 0.1))
		var v_new: float = sqrt(a_y_total / kappa)
		v = lerpf(v, v_new, 0.5)
	return clampf(v, 5.0, _vehicle_top_speed())

## Available braking deceleration at a given speed.
func _available_braking(speed: float) -> float:
	var mu: float = _available_grip()
	var g: float = 9.81
	var mass: float = float(_vehicle_profile.get("mass_kg", 1400.0))
	var base: float = mu * g
	# Aero braking: downforce increases grip at speed.
	var df: float = _downforce_at_speed(speed)
	var extra: float = df / (mass * g)
	# Brake system limit.
	var brake_force: float = float(_vehicle_profile.get("brake_force_n", mass * 16.0))
	var brake_decel: float = brake_force / mass
	return minf(base * (1.0 + extra), brake_decel)

## Available acceleration at a given speed.
func _available_acceleration(speed: float) -> float:
	var mass: float = float(_vehicle_profile.get("mass_kg", 1400.0))
	var power_kw: float = float(_vehicle_profile.get("engine_power_kw", 200.0))
	var power_w: float = power_kw * 1000.0
	# Traction limit.
	var mu: float = _available_grip()
	var traction_limit: float = mu * 9.81
	# Power limit: a = P / (m * v).
	var power_limit: float = power_w / maxf(mass * maxf(speed, 5.0), 1.0)
	# Drag limit.
	var drag: float = _drag_decel(speed)
	return maxf(minf(traction_limit, power_limit) - drag, 0.5)

## Top speed of the vehicle.
func _vehicle_top_speed() -> float:
	var power_kw: float = float(_vehicle_profile.get("engine_power_kw", 200.0))
	var drag_area: float = float(_vehicle_profile.get("drag_area_m2", 0.7))
	var mass: float = float(_vehicle_profile.get("mass_kg", 1400.0))
	# v_max where power = drag force * v: P = 0.5 * rho * CdA * v^3
	var rho: float = 1.225
	var v_max: float = pow(2.0 * power_kw * 1000.0 / (rho * drag_area), 1.0 / 3.0)
	return clampf(v_max, 30.0, 150.0)

## Effective grip coefficient considering surface, temperature, wear, wetness.
func _available_grip() -> float:
	var surface: String = str(_vehicle_profile.get("surface", "asphalt"))
	var base_mu: float = float(Tyres.surface_data(surface).get("mu", 1.2))
	var tyre_temp: float = float(_vehicle_profile.get("tyre_temp_c", 80.0))
	var wear: float = clampf(float(_vehicle_profile.get("tyre_wear", 0.0)), 0.0, 1.0)
	var temp_factor: float = Tyres.temperature_grip_factor(tyre_temp)
	var wet_factor: float = 1.0 - _wetness * float(Tyres.surface_data(surface).get("wet_loss", 0.3))
	var wear_factor: float = 1.0 - wear * 0.25
	return base_mu * temp_factor * wet_factor * wear_factor

## Downforce at a given speed (Newtons).
func _downforce_at_speed(speed: float) -> float:
	var area: float = float(_vehicle_profile.get("downforce_area_m2", 0.8))
	var rho: float = 1.225
	return 0.5 * rho * speed * speed * area

## Drag deceleration at a given speed (m/s²).
func _drag_decel(speed: float) -> float:
	var area: float = float(_vehicle_profile.get("drag_area_m2", 0.7))
	var mass: float = float(_vehicle_profile.get("mass_kg", 1400.0))
	var rho: float = 1.225
	return 0.5 * rho * area * speed * speed / mass

## Find the sample index nearest to a world position.
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

## Compute brake risk for the player at current state.
## Returns {risk: float, color: Color, braking_needed: bool}
func brake_risk(player_index: int, current_speed: float, is_braking: bool, dt: float) -> Dictionary:
	if base_speeds.is_empty() or player_index < 0 or player_index >= base_speeds.size():
		return {"risk": 0.0, "color": Color.GREEN, "braking_needed": false}
	var n: int = samples.size()
	# Lookahead distance based on speed.
	var lookahead_dist: float = current_speed * lookahead_s
	# Find the point ahead that has the lowest target speed.
	var target_speed: float = base_speeds[player_index]
	var target_index: int = player_index
	var acc: float = 0.0
	for i: int in range(player_index, n):
		acc = distances[i] - distances[player_index]
		if acc > lookahead_dist:
			break
		if base_speeds[i] < target_speed:
			target_speed = base_speeds[i]
			target_index = i
	# Distance to the target point.
	var dist_to_target: float = maxf(distances[target_index] - distances[player_index], 1.0)
	# Required deceleration: a = (v0² - vt²) / (2d).
	var v0: float = current_speed
	var vt: float = target_speed
	var a_required: float = 0.0
	if v0 > vt:
		a_required = (v0 * v0 - vt * vt) / (2.0 * dist_to_target)
	# Available braking at current speed.
	var a_available: float = _available_braking(v0)
	# BrakeRisk = required / available.
	var risk: float = 0.0
	if a_available > 0.1:
		risk = a_required / a_available
	# SpeedRatio: how much faster than target.
	var speed_ratio: float = v0 / maxf(vt, 1.0)
	# Combined risk: max of braking risk and speed excess.
	var speed_risk: float = clampf((speed_ratio - 1.0) * 5.0, 0.0, 2.0)
	var combined: float = maxf(risk, speed_risk)
	# Colour: continuous interpolation green → yellow → red.
	var color: Color = _risk_color(combined)
	return {"risk": combined, "color": color, "braking_needed": a_required > 0.5,
		"a_required": a_required, "a_available": a_available,
		"target_speed": target_speed, "dist_to_target": dist_to_target}

## Continuous colour from risk score.
static func _risk_color(risk: float) -> Color:
	var r: float = clampf(risk, 0.0, 1.5)
	if r < 0.35:
		# Green → yellow-green.
		var t: float = r / 0.35
		return Color(0.2, 0.9, 0.2).lerp(Color(0.7, 0.9, 0.1), t)
	elif r < 0.75:
		# Yellow → orange.
		var t: float = (r - 0.35) / 0.40
		return Color(0.7, 0.9, 0.1).lerp(Color(1.0, 0.55, 0.0), t)
	elif r < 1.0:
		# Orange → red.
		var t: float = (r - 0.75) / 0.25
		return Color(1.0, 0.55, 0.0).lerp(Color(1.0, 0.1, 0.1), t)
	else:
		# Intense red (impossible braking).
		return Color(1.0, 0.0, 0.0)

## Get target speed at a given index (for AI).
func target_speed(index: int) -> float:
	if index >= 0 and index < dynamic_speeds.size():
		return dynamic_speeds[index]
	return 0.0

## Get target position (racing line) at a given index.
func target_position(index: int) -> Vector3:
	if index < 0 or index >= samples.size():
		return Vector3.ZERO
	var p: Vector3 = samples[index]["position"]
	var right: Vector3 = samples[index].get("right", Vector3.RIGHT)
	return p + right * line_offsets[index]

## Update dynamic profile for current conditions (call at 5-10 Hz).
func update_dynamic(vehicle_state: Dictionary) -> void:
	_vehicle_profile.merge(vehicle_state, true)
	_wetness = float(vehicle_state.get("wetness", _wetness))
	if samples.size() >= 2:
		_compute_speed_profile()

func total_length() -> float:
	return _total_length

func sample_count() -> int:
	return samples.size()