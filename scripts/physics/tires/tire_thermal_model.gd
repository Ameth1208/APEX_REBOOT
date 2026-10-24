class_name ApexTireThermalModel
extends RefCounted

## Thermal dynamics for tires: friction heating, airspeed convection,
## road conduction, and thermal grip degradation.

static func grip_factor(temp_c: float, optimal_c: float = 85.0, window_c: float = 30.0) -> float:
	var delta: float = temp_c - optimal_c
	if absf(delta) <= window_c * 0.5:
		# In optimal temperature window: 100% grip
		return 1.0
	elif delta < 0.0:
		# Cold tire: gradual warmup ramp (down to 75% at cold ambient)
		var cold_amount: float = (-delta - window_c * 0.5) / 50.0
		return clampf(1.0 - cold_amount * 0.25, 0.75, 1.0)
	else:
		# Overheated tire: blistering / greasy loss
		var hot_amount: float = (delta - window_c * 0.5) / 45.0
		return clampf(1.0 - hot_amount * 0.32, 0.68, 1.0)

## Simulates heat exchange for one physics timestep dt
static func step_temperature(
	current_temp_c: float,
	friction_power_w: float,
	ambient_c: float,
	speed_mps: float,
	dt: float
) -> float:
	# Frictional heating: power input into tire carcass
	var heat_flux: float = friction_power_w * 0.00008
	
	# Cooling from convective airflow (continuous with vehicle speed)
	var air_cooling_rate: float = 0.04 + absf(speed_mps) * 0.0042
	var heat_loss: float = (current_temp_c - ambient_c) * air_cooling_rate
	
	var next_temp: float = current_temp_c + (heat_flux - heat_loss) * dt
	return clampf(next_temp, ambient_c, 220.0)
