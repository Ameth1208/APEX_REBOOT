extends RefCounted
## Tyre model based on Pacejka Magic Formula with load sensitivity,
## temperature window, combined slip friction ellipse, and proper slip ratio.

const SURFACES: Dictionary = {
	"asphalt": {"mu": 1.35, "rolling": 0.013, "wet_loss": 0.32, "k_c": 0.0, "k_phi": 0.0, "n": 0.0},
	"concrete": {"mu": 1.20, "rolling": 0.016, "wet_loss": 0.30, "k_c": 0.0, "k_phi": 0.0, "n": 0.0},
	"gravel": {"mu": 0.72, "rolling": 0.050, "wet_loss": 0.14, "k_c": 5.0, "k_phi": 90.0, "n": 1.1},
	"grass": {"mu": 0.52, "rolling": 0.070, "wet_loss": 0.42, "k_c": 3.0, "k_phi": 60.0, "n": 1.2},
	"sand": {"mu": 0.48, "rolling": 0.11, "wet_loss": 0.08, "k_c": 1.5, "k_phi": 40.0, "n": 1.3},
	"dirt": {"mu": 0.68, "rolling": 0.045, "wet_loss": 0.30, "k_c": 4.0, "k_phi": 75.0, "n": 1.15}
}

## Pacejka coefficients per surface: B=stiffness, C=shape, E=curvature.
const PACEJKA_LAT: Dictionary = {
	"asphalt": {"B": 11.0, "C": 1.45, "E": 0.97},
	"concrete": {"B": 10.0, "C": 1.40, "E": 0.97},
	"gravel": {"B": 6.0, "C": 1.35, "E": 0.90},
	"grass": {"B": 4.5, "C": 1.30, "E": 0.85},
	"sand": {"B": 3.5, "C": 1.25, "E": 0.80},
	"dirt": {"B": 5.5, "C": 1.32, "E": 0.88}
}
const PACEJKA_LONG: Dictionary = {
	"asphalt": {"B": 14.0, "C": 1.55, "E": 0.96},
	"concrete": {"B": 13.0, "C": 1.50, "E": 0.96},
	"gravel": {"B": 7.0, "C": 1.40, "E": 0.90},
	"grass": {"B": 5.0, "C": 1.35, "E": 0.85},
	"sand": {"B": 4.0, "C": 1.28, "E": 0.80},
	"dirt": {"B": 6.5, "C": 1.38, "E": 0.88}
}

## Load sensitivity: mu falls as Fz grows beyond nominal.
const LOAD_SENSITIVITY: float = 0.07
const NOMINAL_LOAD_N: float = 3500.0

static func surface_data(name: String) -> Dictionary:
	return SURFACES.get(name, SURFACES["asphalt"])

static func pacejka_lat(name: String) -> Dictionary:
	return PACEJKA_LAT.get(name, PACEJKA_LAT["asphalt"])

static func pacejka_long(name: String) -> Dictionary:
	return PACEJKA_LONG.get(name, PACEJKA_LONG["asphalt"])

## Pacejka Magic Formula: Y = D * sin(C * atan(B*x - E*(B*x - atan(B*x))))
## D = peak force, B = stiffness, C = shape, E = curvature.
static func magic_formula(x: float, b: float, c: float, e: float) -> float:
	var bx: float = b * x
	return sin(c * atan(bx - e * (bx - atan(bx))))

## mu_eff = mu0 * f_load * f_temp * f_water
static func effective_mu(surface_name: String, base_mu: float, load_n: float, temp_c: float, wetness: float) -> float:
	var mu: float = base_mu
	# Load sensitivity (Section 19): only reduces above nominal.
	var load_excess: float = maxf(load_n - NOMINAL_LOAD_N, 0.0)
	var f_load: float = clampf(1.0 - LOAD_SENSITIVITY * load_excess / NOMINAL_LOAD_N, 0.60, 1.0)
	mu *= f_load
	# Temperature window (Section 23): Gaussian around optimal.
	var f_temp: float = temperature_factor(temp_c)
	mu *= f_temp
	# Water (Section 29).
	var surface: Dictionary = surface_data(surface_name)
	mu *= (1.0 - clampf(wetness, 0.0, 1.0) * float(surface["wet_loss"]))
	return maxf(mu, 0.1)

## Temperature window: full grip 40-100 °C, reduced outside.
## Cold loses ~15%, hot loses ~15%, overheated loses more.
static func temperature_factor(temp_c: float) -> float:
	if temp_c < 40.0:
		return 0.82 + clampf((temp_c - 5.0) / 35.0, 0.0, 1.0) * 0.18
	elif temp_c <= 100.0:
		return 1.0
	elif temp_c <= 140.0:
		return 1.0 - (temp_c - 100.0) / 40.0 * 0.15
	else:
		return 0.85 - clampf((temp_c - 140.0) / 40.0, 0.0, 1.0) * 0.20

## Advance tyre temperature. Friction heats, airflow cools.
## Tuned so equilibrium under normal driving sits in the 70-95 °C window.
static func advance_temperature(temp_c: float, friction_power: float, ambient_c: float, dt: float, speed_mps: float = 0.0) -> float:
	var heating: float = friction_power * 0.00040
	heating = minf(heating, 6.0)
	var convection: float = 0.010 + absf(speed_mps) * 0.0004
	if temp_c > 120.0:
		convection += (temp_c - 120.0) * 0.001
	var cooling: float = (temp_c - ambient_c) * convection
	return clampf(temp_c + heating * dt - cooling * dt, ambient_c, 180.0)

static func gravity_at(lat_deg: float, altitude_m: float) -> float:
	var lat: float = deg_to_rad(clampf(lat_deg, -90.0, 90.0))
	var sin_lat: float = sin(lat)
	var g_e: float = 9.7803267715
	var c1: float = 0.00193185265241
	var c2: float = -0.0000030860510484
	var m: float = 0.00344978650684
	var gamma: float = g_e * (1.0 + c1 * sin_lat * sin_lat + c2 * sin_lat * sin_lat * sin_lat * sin_lat) / sqrt(1.0 - m * sin_lat * sin_lat)
	return gamma - 3.086e-6 * altitude_m

static func friction(name: String, wetness: float, scale: float) -> float:
	var surface: Dictionary = surface_data(name)
	return float(surface["mu"]) * (1.0 - clampf(wetness, 0.0, 1.0) * float(surface["wet_loss"])) * maxf(scale, 0.1)

static func speed_grip_factor(speed_mps: float) -> float:
	var v: float = absf(speed_mps)
	if v < 40.0:
		return 1.0
	return 1.0 - clampf((v - 40.0) / 60.0, 0.0, 1.0) * 0.05

static func temperature_grip_factor(temp_c: float) -> float:
	return temperature_factor(temp_c)

## Full tyre force solver with Pacejka combined slip.
static func solve(contact: Dictionary, forward: Vector3, drive_n: float, brake_n: float, friction_mu: float, abs_active: bool, tcs_active: bool, dt: float) -> Dictionary:
	var normal: Vector3 = contact["normal"]
	var wheel_forward: Vector3 = forward.slide(normal).normalized()
	if wheel_forward.length_squared() < 0.1:
		return {"force": Vector3.ZERO, "slip": 0.0, "slide_speed": 0.0, "locked": false, "abs": false, "tcs": false}
	var right: Vector3 = wheel_forward.cross(normal).normalized()
	var velocity: Vector3 = contact["velocity"]
	var longitudinal_speed: float = velocity.dot(wheel_forward)
	var lateral_speed: float = velocity.dot(right)
	var load_n: float = float(contact["load"])
	var corner_mass: float = float(contact["corner_mass"])
	var surface_name: String = str(contact["surface"])
	var surface: Dictionary = surface_data(surface_name)
	# Effective mu with load sensitivity (Section 19): only reduces above nominal.
	var load_excess: float = maxf(load_n - NOMINAL_LOAD_N, 0.0)
	var mu_eff: float = friction_mu * clampf(1.0 - LOAD_SENSITIVITY * load_excess / NOMINAL_LOAD_N, 0.60, 1.0)
	var limit_n: float = mu_eff * load_n
	# --- Slip angle (Section 16): atan2(Vy, |Vx|+eps) ---
	var slip_angle: float = atan2(lateral_speed, absf(longitudinal_speed) + 0.5)
	# --- Longitudinal demand ---
	var requested_drive: float = drive_n
	var tcs_intervening: bool = tcs_active and absf(drive_n) > limit_n * 0.92
	if tcs_intervening:
		drive_n = clampf(drive_n, -limit_n * 0.92, limit_n * 0.92)
	var stop_force: float = absf(longitudinal_speed) * corner_mass / maxf(dt, 0.001)
	var actual_brake: float = minf(brake_n, stop_force)
	var locked: bool = actual_brake > limit_n and absf(longitudinal_speed) > 1.0
	if abs_active:
		actual_brake = minf(actual_brake, limit_n * 0.90)
	var long_demand: float = drive_n - signf(longitudinal_speed) * actual_brake
	# Normalised longitudinal slip: how much demand exceeds available grip.
	var kappa: float = long_demand / maxf(mu_eff * load_n, 1.0)
	# --- Pacejka lateral force (Section 18) ---
	# Magic formula returns positive for positive x. Force must OPPOSE slip:
	# positive slip_angle (sliding right) → force to the left (negative).
	var pl: Dictionary = pacejka_lat(surface_name)
	var D_lat: float = limit_n
	var Fy_raw: float = -magic_formula(slip_angle, float(pl["B"]), float(pl["C"]), float(pl["E"])) * D_lat
	# --- Pacejka longitudinal force ---
	var po: Dictionary = pacejka_long(surface_name)
	var D_long: float = limit_n
	var Fx_raw: float = magic_formula(kappa, float(po["B"]), float(po["C"]), float(po["E"])) * D_long
	# Preserve direction of longitudinal demand.
	if absf(kappa) > 0.001:
		Fx_raw = signf(kappa) * absf(Fx_raw)
	else:
		Fx_raw = long_demand
	# Locked wheel: lateral authority drops.
	if locked and not abs_active:
		Fy_raw *= 0.30
	# Rolling resistance is part of the longitudinal budget.
	var rolling: float = float(surface["rolling"]) * load_n * clampf(longitudinal_speed / 0.8, -1.0, 1.0)
	Fx_raw -= rolling
	# --- Combined slip friction ellipse (Section 20) ---
	var p_ellipse: float = 2.0
	var nx: float = Fx_raw / maxf(limit_n, 1.0)
	var ny: float = Fy_raw / maxf(limit_n, 1.0)
	var ellipse: float = pow(absf(nx), p_ellipse) + pow(absf(ny), p_ellipse)
	if ellipse > 1.0 and ellipse > 0.001:
		var scale: float = pow(ellipse, -1.0 / p_ellipse)
		Fx_raw *= scale
		Fy_raw *= scale
	# Final clamp.
	var combined: Vector2 = Vector2(Fx_raw, Fy_raw)
	if combined.length() > limit_n and limit_n > 0.0:
		combined = combined.limit_length(limit_n)
	# Telemetry.
	var slip: float = maxf(absf(slip_angle) / 0.15, maxf(absf(kappa) - 0.1, 0.0))
	if locked and not abs_active:
		slip = maxf(slip, minf(absf(longitudinal_speed) / 10.0, 1.5))
	var slide_speed: float = absf(lateral_speed)
	if locked and not abs_active:
		slide_speed = maxf(slide_speed, absf(longitudinal_speed))
	return {"force": wheel_forward * combined.x + right * combined.y, "slip": minf(slip, 3.0),
		"slide_speed": minf(slide_speed, 60.0), "locked": locked and not abs_active,
		"abs": locked and abs_active, "tcs": tcs_intervening}

static func driven_slip(drive_n: float, limit_n: float) -> float:
	return maxf(absf(drive_n) / maxf(limit_n, 1.0) - 1.0, 0.0)