class_name ApexSuspensionSolver
extends RefCounted

## General real-force suspension solver implementing spring, asymmetric damper
## (bump cb vs rebound cr), and non-linear bump stop kb * max(0, x - xb)^n.

var spec: ApexSuspensionSpec

func _init(suspension_spec: ApexSuspensionSpec = null) -> void:
	if suspension_spec != null:
		spec = suspension_spec
	else:
		spec = ApexSuspensionSpec.new()

## Calculates normal suspension forces from wheel compression and compression rate.
## compression x (m): positive when spring is compressed past extension limit.
## compression_rate \dot{x} (m/s): positive when compressing, negative when extending.
func solve_forces(compression: float, compression_rate: float) -> Dictionary:
	if compression <= 0.0:
		return {
			"spring_force": 0.0,
			"damper_force": 0.0,
			"bump_stop_force": 0.0,
			"total_force": 0.0
		}
	
	var mr: float = spec.motion_ratio
	var x_spring: float = compression * mr
	var v_spring: float = compression_rate * mr
	
	# 1. Spring Force: F_spring = k * x
	var f_spring: float = spec.spring_rate_n_m * x_spring
	
	# 2. Damper Force: F_damper = c_b * \dot{x} if \dot{x} >= 0 else c_r * \dot{x}
	var f_damper: float = 0.0
	if v_spring >= 0.0:
		f_damper = spec.bump_damping_n_s_m * v_spring
	else:
		f_damper = spec.rebound_damping_n_s_m * v_spring
		
	# 3. Bump Stop Force: F_bump = k_b * max(0, x - x_b)^n
	var f_bump: float = 0.0
	var over_travel: float = maxf(0.0, compression - spec.bump_stop_travel_m)
	if over_travel > 0.0:
		f_bump = spec.bump_stop_stiffness * pow(over_travel, spec.bump_stop_exponent)
		
	# Total transmitted normal force
	var f_total: float = (f_spring + f_damper + f_bump) * mr
	f_total = maxf(0.0, f_total)
	
	return {
		"spring_force": f_spring * mr,
		"damper_force": f_damper * mr,
		"bump_stop_force": f_bump * mr,
		"total_force": f_total
	}

## Dynamic camber based on suspension geometry and deflection
func solve_camber_rad(compression: float, is_left_wheel: bool) -> float:
	var camber_deg: float = spec.static_camber_deg + spec.camber_gain_deg_per_m * (compression - spec.sag_m)
	var sign_side: float = 1.0 if is_left_wheel else -1.0
	return deg_to_rad(camber_deg * sign_side)
