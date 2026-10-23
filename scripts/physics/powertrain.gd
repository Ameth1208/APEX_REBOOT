extends RefCounted
## Torque based drivetrain. Values are SI except engine speed (rpm).

var gear: int = 1 # -1 reverse, 0 neutral, 1..N forward.
var rpm: float = 1000.0
var idle_rpm: float = 1000.0
var max_rpm: float = 8500.0
var peak_torque: float = 465.0
var peak_rpm: float = 5500.0
var max_power_w: float = 0.0
var peak_power_rpm: float = 0.0
var final_drive: float = 3.9
var wheel_radius: float = 0.34
var efficiency: float = 0.88
var ratios: Array[float] = [3.75, 2.38, 1.72, 1.34, 1.08, 0.90]
var shift_cooldown: float = 0.0

func configure(data: Dictionary) -> void:
	peak_torque = float(data.get("engine_torque_nm", data.get("torque_nm", 465.0)))
	idle_rpm = float(data.get("idle_rpm", 1000.0))
	max_rpm = float(data.get("max_rpm", data.get("redline_rpm", 8500.0)))
	peak_rpm = float(data.get("peak_torque_rpm", max_rpm * 0.55))
	max_power_w = float(data.get("engine_power_kw", 0.0)) * 1000.0
	peak_power_rpm = float(data.get("peak_power_rpm", 0.0))
	final_drive = float(data.get("final_drive", 3.9))
	wheel_radius = float(data.get("wheel_radius_m", data.get("wheel_radius", 0.34)))
	efficiency = float(data.get("drivetrain_efficiency", 0.88))
	var supplied: Array = data.get("gear_ratios", [])
	if not supplied.is_empty():
		ratios.clear()
		for ratio: Variant in supplied:
			ratios.append(maxf(float(ratio), 0.1))
	gear = 1
	rpm = idle_rpm
	shift_cooldown = 0.0

func ratio_for_gear() -> float:
	if gear == 0:
		return 0.0
	if gear < 0:
		return -ratios[0] * 0.82
	return ratios[clampi(gear - 1, 0, ratios.size() - 1)]

func shift_up() -> void:
	gear = mini(gear + 1, ratios.size())
	shift_cooldown = 0.22

func shift_down() -> void:
	gear = maxi(gear - 1, -1)
	shift_cooldown = 0.22

func drive_torque(speed_mps: float, throttle: float, automatic: bool, dt: float) -> float:
	shift_cooldown = maxf(shift_cooldown - dt, 0.0)
	var wheel_rpm: float = absf(speed_mps) / maxf(wheel_radius, 0.1) * 60.0 / TAU
	var coupled_rpm: float = wheel_rpm * absf(ratio_for_gear()) * final_drive
	if automatic and gear > 0 and shift_cooldown <= 0.0:
		if coupled_rpm > max_rpm * 0.92 and gear < ratios.size():
			shift_up()
		elif coupled_rpm < max_rpm * 0.37 and gear > 1:
			shift_down()
		coupled_rpm = wheel_rpm * absf(ratio_for_gear()) * final_drive
	var launch_rpm: float = idle_rpm + throttle * max_rpm * 0.26
	var target_rpm: float = maxf(coupled_rpm, launch_rpm)
	if gear == 0:
		target_rpm = lerpf(idle_rpm, max_rpm, throttle)
	rpm = move_toward(rpm, clampf(target_rpm, idle_rpm, max_rpm * 1.03), dt * 6500.0)
	if gear == 0:
		return 0.0
	var available_torque: float = torque_at(rpm)
	var torque: float = throttle * available_torque
	if coupled_rpm > max_rpm:
		torque *= clampf((max_rpm * 1.035 - coupled_rpm) / (max_rpm * 0.035), 0.0, 1.0)
	if shift_cooldown > 0.12:
		torque *= 0.2
	var wheel_torque: float = torque * ratio_for_gear() * final_drive * efficiency
	if absf(speed_mps) > 1.0 and throttle < 0.04:
		wheel_torque -= signf(speed_mps) * peak_torque * 0.11 * absf(ratio_for_gear()) * final_drive
	return wheel_torque

func torque_at(engine_rpm: float) -> float:
	var available: float = peak_torque * torque_factor(engine_rpm / max_rpm, clampf(peak_rpm / max_rpm, 0.25, 0.90))
	# A nominal power point must be attainable, not merely an unreachable ceiling.
	# The segments between nominal points remain a simulation approximation.
	if max_power_w > 0.0 and peak_power_rpm > peak_rpm and engine_rpm > peak_rpm:
		var power_torque: float = max_power_w / (peak_power_rpm * TAU / 60.0)
		if engine_rpm <= peak_power_rpm:
			available = lerpf(peak_torque, power_torque, (engine_rpm - peak_rpm) / (peak_power_rpm - peak_rpm))
		else:
			var falloff: float = lerpf(1.0, 0.94, clampf((engine_rpm - peak_power_rpm) / maxf(1.0, max_rpm - peak_power_rpm), 0.0, 1.0))
			available = max_power_w * falloff / maxf(engine_rpm * TAU / 60.0, 1.0)
	if max_power_w > 0.0:
		available = minf(available, max_power_w / maxf(engine_rpm * TAU / 60.0, 1.0))
	return maxf(available, 0.0)

static func torque_factor(normalized_rpm: float, peak_fraction: float = 0.55) -> float:
	# Broad torque plateau, then a power-limited falloff near redline.
	if normalized_rpm < peak_fraction:
		return lerpf(0.60, 1.0, clampf(normalized_rpm / peak_fraction, 0.0, 1.0))
	return lerpf(1.0, 0.78, clampf((normalized_rpm - peak_fraction) / (1.0 - peak_fraction), 0.0, 1.0))
