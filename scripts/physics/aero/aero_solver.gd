class_name ApexAeroSolver
extends RefCounted

## Master aerodynamics solver calculating:
## 1. Drag force F_D = 0.5 * rho * C_D * A * v^2
## 2. Downforce F_DF = 0.5 * rho * C_L * A * v^2
## 3. Front/Rear axle downforce distribution (aero balance)
## 4. Yaw degradation (loss of downforce & induced drag when sliding)
## 5. Slipstream / draft wake attenuation

var spec: ApexAeroSpec

func _init(aero_spec: ApexAeroSpec = null) -> void:
	if aero_spec != null:
		spec = aero_spec
	else:
		spec = ApexAeroSpec.new()

func solve(
	linear_velocity: Vector3,
	body_basis: Basis,
	aero_scale: float = 1.0,
	drag_mult: float = 1.0,
	downforce_mult: float = 1.0,
	aero_health: float = 1.0
) -> Dictionary:
	var speed: float = linear_velocity.length()
	if speed < 0.05:
		return {
			"drag_force": Vector3.ZERO,
			"total_downforce_n": 0.0,
			"front_downforce_n": 0.0,
			"rear_downforce_n": 0.0,
			"downforce_force": Vector3.ZERO
		}
	
	var rho: float = spec.air_density
	var dynamic_pressure: float = 0.5 * rho * speed * speed
	var forward: Vector3 = -body_basis.z.normalized()
	var up: Vector3 = body_basis.y.normalized()
	var vel_dir: Vector3 = linear_velocity.normalized()
	
	# Yaw alignment: dot product between velocity and vehicle heading
	var alignment: float = clampf(vel_dir.dot(forward), -1.0, 1.0)
	var yaw_factor: float = clampf(absf(alignment), 0.35, 1.0)
	
	# Effective areas under yaw
	var eff_drag_area: float = spec.drag_area_cd_a * lerpf(spec.yaw_drag_factor, 1.0, yaw_factor)
	var eff_downforce_area: float = spec.downforce_area_cl_a * yaw_factor * maxf(0.0, alignment)
	
	# Compute total drag and downforce magnitudes
	var drag_magnitude: float = dynamic_pressure * eff_drag_area * clampf(drag_mult, 0.5, 1.2) * (1.0 + (1.0 - aero_health) * 0.25)
	var downforce_total: float = dynamic_pressure * eff_downforce_area * maxf(0.0, aero_scale) * clampf(downforce_mult, 0.4, 1.0) * aero_health
	
	var drag_vector: Vector3 = -vel_dir * drag_magnitude
	var downforce_vector: Vector3 = -up * downforce_total
	
	var f_front: float = downforce_total * spec.aero_balance_front
	var f_rear: float = downforce_total * (1.0 - spec.aero_balance_front)
	
	return {
		"drag_force": drag_vector,
		"total_downforce_n": downforce_total,
		"front_downforce_n": f_front,
		"rear_downforce_n": f_rear,
		"downforce_force": downforce_vector
	}
