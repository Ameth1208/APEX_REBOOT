class_name ApexEngineSolver
extends RefCounted

## Internal combustion / electric powertrain engine solver.
## Computes torque curve, redline limiter, throttle response, and engine braking.

var spec: ApexEngineSpec
var rpm: float = 1000.0

func _init(engine_spec: ApexEngineSpec = null) -> void:
	if engine_spec != null:
		spec = engine_spec
	else:
		spec = ApexEngineSpec.new()
	rpm = spec.idle_rpm

func torque_at(engine_rpm: float) -> float:
	var norm_rpm: float = engine_rpm / maxf(spec.max_rpm, 1.0)
	var peak_frac: float = clampf(spec.peak_torque_rpm / maxf(spec.max_rpm, 1.0), 0.25, 0.90)
	
	var factor: float = 0.0
	if norm_rpm < peak_frac:
		factor = lerpf(0.60, 1.0, clampf(norm_rpm / peak_frac, 0.0, 1.0))
	else:
		factor = lerpf(1.0, 0.78, clampf((norm_rpm - peak_frac) / (1.0 - peak_frac), 0.0, 1.0))
		
	var torque: float = spec.max_torque_nm * factor
	
	# Cap by maximum rated power if specified (P = tau * omega)
	if spec.max_power_kw > 0.0:
		var omega: float = engine_rpm * TAU / 60.0
		var max_power_w: float = spec.max_power_kw * 1000.0
		torque = minf(torque, max_power_w / maxf(omega, 1.0))
		
	return maxf(0.0, torque)

func step(target_rpm: float, dt: float) -> void:
	rpm = move_toward(rpm, clampf(target_rpm, spec.idle_rpm, spec.max_rpm * 1.03), dt * 6500.0)
