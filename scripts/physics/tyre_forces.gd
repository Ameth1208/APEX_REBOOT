extends RefCounted
## Combined-slip friction circle tire solver with load sensitivity.
## Surface coefficients are calibration values; no force may exceed mu_eff * normal load.
## Strictly zero force when normal load is zero.
## Continuous across all speeds from 0 to 300+ km/h without artificial speed gates.

const SurfaceDef = preload("res://scripts/physics/surfaces/surface_definition.gd")
const TireSolver = preload("res://scripts/physics/tires/tire_solver.gd")
const ThermalModel = preload("res://scripts/physics/tires/tire_thermal_model.gd")

const SURFACES: Dictionary = {
	"asphalt": {"mu": 1.08, "rolling": 0.015, "wet_loss": 0.36},
	"concrete": {"mu": 0.98, "rolling": 0.018, "wet_loss": 0.35},
	"gravel": {"mu": 0.58, "rolling": 0.055, "wet_loss": 0.16},
	"grass": {"mu": 0.42, "rolling": 0.075, "wet_loss": 0.45},
	"sand": {"mu": 0.38, "rolling": 0.12, "wet_loss": 0.10},
	"dirt": {"mu": 0.56, "rolling": 0.048, "wet_loss": 0.34}
}

static func surface_data(name: String) -> Dictionary:
	return SURFACES.get(name, SURFACES["asphalt"])

static func friction(name: String, wetness: float, scale: float) -> float:
	return SurfaceDef.get_friction(name, wetness, scale)

## Smooth, continuous speed-dependent grip across all velocities
static func speed_grip_factor(speed_mps: float) -> float:
	var v: float = absf(speed_mps)
	if v < 30.0:
		return 1.0
	# Smooth continuous reduction above 30 m/s without discrete step
	return 1.0 - clampf((v - 30.0) / 50.0, 0.0, 1.0) * 0.08

## Tyre temperature grip response window
static func temperature_grip_factor(temp_c: float) -> float:
	if temp_c < 40.0:
		return 0.75 + clampf((temp_c - 5.0) / 35.0, 0.0, 1.0) * 0.25
	elif temp_c <= 95.0:
		return 1.0
	elif temp_c <= 130.0:
		return 1.0 - (temp_c - 95.0) / 35.0 * 0.18
	else:
		return 0.82 - clampf((temp_c - 130.0) / 50.0, 0.0, 1.0) * 0.15

## Thermodynamic temperature stepping
static func advance_temperature(temp_c: float, friction_power: float, ambient_c: float, dt: float, speed_mps: float = 0.0) -> float:
	var heating: float = friction_power * 0.00008
	var convection: float = (0.04 + absf(speed_mps) * 0.004)
	var cooling: float = (temp_c - ambient_c) * convection
	var next: float = temp_c + heating * dt - cooling * dt
	return clampf(next, ambient_c, 200.0)

## WGS84 normal gravity (m/s²) from latitude (°) and altitude (m).
static func gravity_at(lat_deg: float, altitude_m: float) -> float:
	var lat: float = deg_to_rad(clampf(lat_deg, -90.0, 90.0))
	var sin_lat: float = sin(lat)
	var g_e: float = 9.7803267715
	var c1: float = 0.00193185265241
	var c2: float = -0.0000030860510484
	var m: float = 0.00344978650684
	var gamma: float = g_e * (1.0 + c1 * sin_lat * sin_lat + c2 * sin_lat * sin_lat * sin_lat * sin_lat) / sqrt(1.0 - m * sin_lat * sin_lat)
	return gamma - 3.086e-6 * altitude_m

static func solve(contact: Dictionary, forward: Vector3, drive_n: float, brake_n: float, friction_mu: float, abs_active: bool, tcs_active: bool, dt: float) -> Dictionary:
	return TireSolver.solve(contact, forward, drive_n, brake_n, friction_mu, abs_active, tcs_active, dt)

static func driven_slip(drive_n: float, limit_n: float) -> float:
	return maxf(absf(drive_n) / maxf(limit_n, 1.0) - 1.0, 0.0)
