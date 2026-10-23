extends RefCounted
## Combined-slip friction circle. Surface coefficients are game calibration,
## not manufacturer tyre measurements; no force may exceed mu * normal load.

const SURFACES: Dictionary = {
	"asphalt": {"mu": 1.22, "rolling": 0.015, "wet_loss": 0.36},
	"concrete": {"mu": 1.10, "rolling": 0.018, "wet_loss": 0.35},
	"gravel": {"mu": 0.64, "rolling": 0.055, "wet_loss": 0.16},
	"grass": {"mu": 0.46, "rolling": 0.075, "wet_loss": 0.45},
	"sand": {"mu": 0.42, "rolling": 0.12, "wet_loss": 0.10},
	"dirt": {"mu": 0.63, "rolling": 0.048, "wet_loss": 0.34}
}

static func surface_data(name: String) -> Dictionary:
	return SURFACES.get(name, SURFACES["asphalt"])

static func friction(name: String, wetness: float, scale: float) -> float:
	var surface: Dictionary = surface_data(name)
	return float(surface["mu"]) * (1.0 - clampf(wetness, 0.0, 1.0) * float(surface["wet_loss"])) * maxf(scale, 0.1)

## Speed-dependent grip: slightly less grip at very high speeds (aero heating).
static func speed_grip_factor(speed_mps: float) -> float:
	var v: float = absf(speed_mps)
	if v < 30.0:
		return 1.0
	# Lose up to 8% grip above 30 m/s, linear ramp to 80 m/s.
	return 1.0 - clampf((v - 30.0) / 50.0, 0.0, 1.0) * 0.08

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
	# Load sensitivity: grip per newton falls as load grows (Box3D concept).
	var mu_effective: float = friction_mu * maxf(0.55, 1.0 - 0.00008 * (load_n - 2000.0))
	var limit_n: float = mu_effective * load_n
	var corner_mass: float = float(contact["corner_mass"])
	var requested_drive: float = drive_n
	var tcs_intervening: bool = tcs_active and absf(drive_n) > limit_n * 0.92
	if tcs_intervening:
		drive_n = clampf(drive_n, -limit_n * 0.92, limit_n * 0.92)
	# This cap prevents the brake from reversing a nearly stopped wheel.
	var stop_force: float = absf(longitudinal_speed) * corner_mass / maxf(dt, 0.001)
	var actual_brake: float = minf(brake_n, stop_force)
	var locked: bool = actual_brake > limit_n and absf(longitudinal_speed) > 1.0
	if abs_active:
		actual_brake = minf(actual_brake, limit_n * 0.90)
	var long_force: float = drive_n - signf(longitudinal_speed) * actual_brake
	var slip_angle: float = atan2(lateral_speed, maxf(absf(longitudinal_speed), 2.5))
	var stiffness: float = float(contact.get("cornering_stiffness", 14.0))
	var lateral_force: float = -slip_angle * load_n * stiffness
	# A locked tyre has much less directional authority. ABS preserves it.
	if locked and not abs_active:
		lateral_force *= 0.24
	var stop_lateral: float = absf(lateral_speed) * corner_mass / maxf(dt, 0.001)
	lateral_force = clampf(lateral_force, -stop_lateral, stop_lateral)
	var combined: Vector2 = Vector2(long_force, lateral_force)
	var demand: float = combined.length()
	if demand > limit_n and demand > 0.001:
		combined *= limit_n / demand
	var surface: Dictionary = surface_data(str(contact["surface"]))
	# Rolling resistance is included in the same friction budget.
	var rolling: float = float(surface["rolling"]) * load_n * clampf(longitudinal_speed / 0.8, -1.0, 1.0)
	combined.x -= rolling
	if combined.length() > limit_n and limit_n > 0.0:
		combined = combined.limit_length(limit_n)
	var slip: float = maxf(absf(slip_angle), maxf(absf(requested_drive) / maxf(limit_n, 1.0) - 1.0, 0.0))
	if locked and not abs_active:
		slip = maxf(slip, minf(absf(longitudinal_speed) / 10.0, 1.5))
	var slide_speed: float = absf(lateral_speed)
	if locked and not abs_active:
		slide_speed = maxf(slide_speed, absf(longitudinal_speed))
	elif not tcs_active and driven_slip(requested_drive, limit_n) > 0.0:
		slide_speed = maxf(slide_speed, driven_slip(requested_drive, limit_n) * maxf(absf(longitudinal_speed), 2.0))
	return {"force": wheel_forward * combined.x + right * combined.y, "slip": minf(slip, 3.0),
		"slide_speed": minf(slide_speed, 60.0), "locked": locked and not abs_active, "abs": locked and abs_active, "tcs": tcs_intervening}

static func driven_slip(drive_n: float, limit_n: float) -> float:
	return maxf(absf(drive_n) / maxf(limit_n, 1.0) - 1.0, 0.0)
