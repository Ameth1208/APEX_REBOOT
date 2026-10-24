class_name ApexEngineSpec
extends Resource

## Engine, transmission, and drivetrain specs.

enum DrivetrainLayout { FWD, RWD, AWD }

@export var max_torque_nm: float = 450.0
@export var max_power_kw: float = 300.0
@export var idle_rpm: float = 950.0
@export var max_rpm: float = 7500.0
@export var peak_torque_rpm: float = 4800.0
@export var gear_ratios: Array[float] = [3.8, 2.4, 1.7, 1.3, 1.05, 0.85]
@export var reverse_ratio: float = 3.6
@export var final_drive: float = 3.9
@export var drivetrain_efficiency: float = 0.88
@export var layout: DrivetrainLayout = DrivetrainLayout.RWD
@export var brake_force_total_n: float = 22000.0
@export var front_brake_bias: float = 0.65
@export var brake_response_time_s: float = 0.125

static func from_dictionary(data: Dictionary, is_motorcycle: bool, mass: float) -> ApexEngineSpec:
	var spec := ApexEngineSpec.new()
	spec.max_torque_nm = float(data.get("engine_torque_nm", data.get("torque_nm", 350.0)))
	spec.max_power_kw = float(data.get("engine_power_kw", data.get("power_kw", 220.0)))
	spec.idle_rpm = float(data.get("idle_rpm", 1300.0 if is_motorcycle else 950.0))
	spec.max_rpm = float(data.get("max_rpm", 12000.0 if is_motorcycle else 7500.0))
	spec.peak_torque_rpm = float(data.get("peak_torque_rpm", 7000.0 if is_motorcycle else 4800.0))
	
	var ratios: Array = data.get("gear_ratios", [])
	if not ratios.is_empty():
		spec.gear_ratios.clear()
		for r in ratios:
			spec.gear_ratios.append(float(r))
			
	spec.final_drive = float(data.get("final_drive", 5.0 if is_motorcycle else 3.9))
	spec.drivetrain_efficiency = float(data.get("drivetrain_efficiency", 0.88))
	
	var drive_str: String = str(data.get("drive", data.get("drivetrain", "RWD"))).to_upper()
	if is_motorcycle or drive_str == "RWD":
		spec.layout = DrivetrainLayout.RWD
	elif drive_str == "FWD":
		spec.layout = DrivetrainLayout.FWD
	elif drive_str == "AWD":
		spec.layout = DrivetrainLayout.AWD
		
	var default_brake: float = mass * 16.0
	spec.brake_force_total_n = maxf(float(data.get("brake_force_n", default_brake)), 0.0)
	spec.front_brake_bias = clampf(float(data.get("front_brake_bias", 0.74 if is_motorcycle else 0.63)), 0.0, 1.0)
	# Optional measured axle capacities override the legacy total/bias pair together.
	if data.has("front_brake_force_n") and data.has("rear_brake_force_n"):
		var front: float = maxf(float(data.front_brake_force_n), 0.0)
		var rear: float = maxf(float(data.rear_brake_force_n), 0.0)
		spec.brake_force_total_n = front + rear
		spec.front_brake_bias = front / (front + rear) if front + rear > 0.0 else 0.5
	spec.brake_response_time_s = clampf(float(data.get("brake_response_time_s", 0.125)), 0.01, 1.0)
	return spec
