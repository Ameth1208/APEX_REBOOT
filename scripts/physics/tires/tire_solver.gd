class_name ApexTireSolver
extends RefCounted

## Master real-force tire solver implementing:
## 1. Load-dependent friction (mu drops with increasing Fz)
## 2. Combined slip friction ellipse: (Fx / (mu_x * Fz))^2 + (Fy / (mu_y * Fz))^2 <= 1
## 3. Strict zero-traction guarantee when Fz == 0
## 4. Continuous, smooth physics from 0 to 300+ km/h without artificial speed thresholds.

const BrushModel = preload("res://scripts/physics/tires/brush_tire_model.gd")
const ThermalModel = preload("res://scripts/physics/tires/tire_thermal_model.gd")
const WearModel = preload("res://scripts/physics/tires/tire_wear_model.gd")

static func solve(
	wheel: Dictionary,
	wheel_forward: Vector3,
	drive_n: float,
	brake_n: float,
	friction_mu: float,
	abs_enabled: bool,
	tcs_enabled: bool,
	dt: float
) -> Dictionary:
	var normal: Vector3 = wheel.get("normal", Vector3.UP)
	var forward: Vector3 = wheel_forward.slide(normal).normalized()
	if forward.length_squared() < 0.1:
		return {
			"force": Vector3.ZERO, "slip": 0.0, "slide_speed": 0.0,
			"friction_power_w": 0.0, "locked": false, "abs": false, "tcs": false,
			"fx": 0.0, "fy": 0.0, "effective_mu": 0.0
		}
	
	var right: Vector3 = forward.cross(normal).normalized()
	var velocity: Vector3 = wheel.get("velocity", Vector3.ZERO)
	var vx: float = velocity.dot(forward)
	var vy: float = velocity.dot(right)
	
	var load_n: float = maxf(0.0, float(wheel.get("load", 0.0)))
	
	# Strict zero-load check: airborne or unweighted tires generate exactly 0 force
	if load_n <= 0.01:
		return {
			"force": Vector3.ZERO, "slip": 0.0, "slide_speed": 0.0,
			"friction_power_w": 0.0, "locked": false, "abs": false, "tcs": false,
			"fx": 0.0, "fy": 0.0, "effective_mu": 0.0
		}
	
	# 1. Load sensitivity calculation: mu decreases as normal load increases
	var reference_load: float = maxf(float(wheel.get("reference_load_n", 4000.0)), 1.0)
	var sensitivity: float = maxf(float(wheel.get("load_sensitivity", 0.00008)), 0.0)
	var load_factor: float = clampf(1.0 - sensitivity * (load_n - reference_load), 0.55, 1.25)
	var effective_mu: float = maxf(friction_mu, 0.0) * load_factor
	
	# Thermal and wear influence
	var temp_c: float = float(wheel.get("temperature_c", 50.0))
	effective_mu *= ThermalModel.grip_factor(temp_c)
	var wear_val: float = float(wheel.get("wear", 0.0))
	effective_mu *= WearModel.grip_from_wear(wear_val)
	
	var limit_n: float = effective_mu * load_n
	var corner_mass: float = maxf(float(wheel.get("corner_mass", 350.0)), 1.0)
	
	# 2. Longitudinal demand & Traction Control
	var requested_drive: float = drive_n
	var tcs_intervening: bool = tcs_enabled and absf(drive_n) > limit_n * 0.92
	if tcs_intervening:
		drive_n = clampf(drive_n, -limit_n * 0.92, limit_n * 0.92)
		
	var stop_force: float = absf(vx) * corner_mass / maxf(dt, 0.001)
	var actual_brake: float = minf(brake_n, stop_force)
	var locked: bool = actual_brake > limit_n and absf(vx) > 1.0
	var abs_active: bool = false
	if abs_enabled and locked:
		actual_brake = minf(actual_brake, limit_n * 0.90)
		abs_active = true
		locked = false
		
	var fx: float = drive_n - signf(vx) * actual_brake
	
	# 3. Lateral demand via Brush Formulation (Continuous at all speeds)
	# Continuous speed regularization: avoids singularity at 0 m/s and
	# operates smoothly at 5, 40, 80, 120, 200, 300+ km/h without artificial speed thresholds.
	var v_ref: float = maxf(absf(vx), 3.0)
	var slip_ratio_lat: float = vy / v_ref
	
	# Real tire cornering stiffness scales naturally with normal load Fz
	var stiffness_mult: float = float(wheel.get("cornering_stiffness", 14.0))
	if wheel.has("cornering_stiffness_n_per_rad"):
		var ref_l: float = maxf(float(wheel.get("reference_load_n", 4000.0)), 1.0)
		stiffness_mult = float(wheel["cornering_stiffness_n_per_rad"]) / ref_l
	var stiffness: float = maxf(stiffness_mult * load_n, 0.0)
	
	var peak_slip: float = maxf(3.0 * limit_n / maxf(stiffness, 1.0), 0.001)
	var normalised_lat: float = absf(slip_ratio_lat) / peak_slip
	var brush_deflection: float = minf(normalised_lat, 1.0)
	var lateral_curve: float = 1.0 - pow(1.0 - brush_deflection, 3.0)
	var fy: float = -signf(slip_ratio_lat) * lateral_curve * limit_n
	
	# Lateral deceleration limit in one tick (prevents oscillation)
	var lateral_stop_force: float = absf(vy) * corner_mass / maxf(dt, 0.001)
	fy = clampf(fy, -lateral_stop_force, lateral_stop_force)
	
	if locked:
		fy *= 0.35
		
	# 4. Combined-Slip Friction Ellipse: (Fx / limit)^2 + (Fy / limit)^2 <= 1
	var demand_len: float = sqrt(fx * fx + fy * fy)
	if demand_len > limit_n and demand_len > 0.0001:
		var scale: float = limit_n / demand_len
		fx *= scale
		fy *= scale
		
	# 5. Rolling Resistance
	var roll_coeff: float = float(wheel.get("rolling_resistance", 0.015))
	var rolling_f: float = roll_coeff * load_n * clampf(vx / 0.8, -1.0, 1.0)
	fx -= rolling_f
	
	# Re-clamp combined vector strictly within friction circle
	var final_demand: float = sqrt(fx * fx + fy * fy)
	if final_demand > limit_n and limit_n > 0.0:
		var scale2: float = limit_n / final_demand
		fx *= scale2
		fy *= scale2
		
	var slip: float = maxf(absf(slip_ratio_lat) / peak_slip, maxf(absf(requested_drive) / maxf(limit_n, 1.0) - 1.0, 0.0))
	if locked:
		slip = maxf(slip, minf(absf(vx) / 10.0, 1.5))
		
	var slide_speed: float = absf(vy)
	if locked:
		slide_speed = maxf(slide_speed, absf(vx))
	elif not tcs_enabled and absf(requested_drive) > limit_n:
		slide_speed = maxf(slide_speed, (absf(requested_drive) / limit_n - 1.0) * maxf(absf(vx), 2.0))
		
	var friction_power: float = absf(fy * vy) + absf(fx) * maxf(slide_speed - absf(vy), 0.0)
	
	return {
		"force": forward * fx + right * fy,
		"slip": minf(slip, 3.0),
		"friction_power_w": friction_power,
		"slide_speed": minf(slide_speed, 60.0),
		"locked": locked,
		"abs": abs_active,
		"tcs": tcs_intervening,
		"effective_mu": effective_mu,
		"fx": fx,
		"fy": fy
	}
