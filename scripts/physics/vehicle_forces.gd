extends RefCounted
## Suspension contact and aero forces shared by player and every rival.

const Tyres = preload("res://scripts/physics/tyre_forces.gd")
const Layout = preload("res://scripts/physics/wheel_layout.gd")

static func contact(body, state: PhysicsDirectBodyState3D, wheel: Dictionary, forward: Vector3, torque: float, dt: float) -> void:
	var front: bool = bool(wheel["front"])
	var normal: Vector3 = wheel["normal"]
	var position: Vector3 = wheel["position"]
	state.apply_force(normal * float(wheel["load"]), position)
	var steer: float = body.steer_angle
	if front and not body.is_motorcycle:
		steer = Layout.steering(steer, body._suspension.offsets[int(wheel["index"])].x,
			float(body.profile.get("wheelbase_m", body.profile.get("wheelbase", 2.65))))
	wheel["steer_angle"] = steer if front else 0.0
	var direction: Vector3 = forward.rotated(normal, -steer) if front else forward
	var drive: String = str(body.profile.get("drive", body.profile.get("drivetrain", "RWD"))).to_upper()
	var driven: bool = (not front) if body.is_motorcycle else drive == "AWD" or (front and drive == "FWD") or (not front and drive == "RWD")
	var driven_count: float = 1.0 if body.is_motorcycle else (4.0 if drive == "AWD" else 2.0)
	var drive_n: float = torque / maxf(body._engine.wheel_radius, 0.1) / driven_count if driven else 0.0
	var bias: float = float(body.profile.get("front_brake_bias", 0.72 if body.is_motorcycle else 0.63))
	var brake_total: float = float(body.profile.get("brake_force_n", body.mass * 16.0))
	var brake_n: float = body._brake * brake_total * (bias if front else 1.0 - bias) / (1.0 if body.is_motorcycle else 2.0)
	if not front:
		brake_n += body._input.w * body.mass * 12.0 / (1.0 if body.is_motorcycle else 2.0)
	body.surface_name = str(wheel["surface"])
	wheel["cornering_stiffness"] = float(body.profile.get("cornering_stiffness", 18.0 if body.is_motorcycle else 14.0))
	var mu: float = Tyres.friction(body.surface_name, body.wetness, body.grip_factor)
	var result: Dictionary = Tyres.solve(wheel, direction, drive_n, brake_n, mu, body.abs_enabled and body._input.w < 0.1, body.tcs_enabled, dt)
	state.apply_force(Vector3(result["force"]), position)
	wheel["slip"] = result["slip"]
	wheel["slide_speed"] = result["slide_speed"]
	wheel["locked"] = result["locked"]
	wheel["driven"] = driven
	body.tire_slip = maxf(body.tire_slip, float(result["slip"]))
	body.abs_active = body.abs_active or bool(result["abs"])
	body.tcs_active = body.tcs_active or bool(result["tcs"])

static func aero(body, state: PhysicsDirectBodyState3D) -> void:
	var velocity: Vector3 = state.linear_velocity
	var pressure: float = 0.5 * 1.225 * velocity.length_squared()
	var drag_area: float = float(body.profile.get("drag_area_m2", 0.62 if body.is_motorcycle else 0.72))
	var aero_area: float = float(body.profile.get("downforce_area_m2", 0.0 if body.is_motorcycle else 0.8))
	var health: float = body._condition.aero_health
	body.downforce_n = 0.5 * 1.225 * body._signed_speed * body._signed_speed * aero_area * maxf(body.aero_scale, 0.0) * clampf(body.downforce_multiplier, 0.4, 1.0) * health
	if velocity.length_squared() > 0.01:
		state.apply_central_force(-velocity.normalized() * pressure * drag_area * clampf(body.drag_multiplier, 0.55, 1.0) * (1.0 + (1.0 - health) * 0.25))
	state.apply_central_force(-state.transform.basis.y.normalized() * body.downforce_n)
