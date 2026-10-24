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
	mu *= Tyres.speed_grip_factor(state.linear_velocity.length())
	mu *= Tyres.temperature_grip_factor(body.tyre_temp_c)
	# Power cut on detected lateral slide of driven wheel (power-oversteer fix).
	# If this wheel is sliding sideways while being driven, cut torque.
	if driven and body.tcs_enabled:
		var lateral_slide: float = absf(float(wheel.get("slide_speed", 0.0)))
		if lateral_slide > 3.0:
			var cut: float = clampf(1.0 - (lateral_slide - 3.0) / 8.0, 0.2, 1.0)
			drive_n *= cut
	# Also cut if body yaw rate exceeds steering demand (spin detection).
	if driven and body.stability_enabled:
		var ground_up: Vector3 = wheel["normal"]
		var yaw_rate: float = state.angular_velocity.dot(ground_up)
		var desired_yaw: float = -body._signed_speed * tan(body.steer_angle) / float(body.profile.get("wheelbase_m", 2.65))
		var yaw_slip: float = absf(yaw_rate - desired_yaw)
		if yaw_slip > 0.5:
			drive_n *= clampf(1.0 - (yaw_slip - 0.5) * 0.6, 0.1, 1.0)
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
	var speed: float = velocity.length()
	var pressure: float = 0.5 * 1.225 * speed * speed
	# Drag and downforce areas from profile, adjusted by vehicle type.
	var drag_area: float = float(body.profile.get("drag_area_m2", 0.62 if body.is_motorcycle else 0.72))
	var aero_area: float = float(body.profile.get("downforce_area_m2", 0.0 if body.is_motorcycle else 0.8))
	if body.is_motorcycle:
		# Sport bikes with fairings cut drag; cruisers/dirt are upright (more drag).
		var bike_type: String = str(body.profile.get("motorcycle_type", body.profile.get("bike_type", "sport"))).to_lower()
		match bike_type:
			"sport": drag_area *= 0.88
			"cruiser": drag_area *= 1.18
			"dirt": drag_area *= 1.25
			"touring": drag_area *= 1.05
	else:
		# Car categories: sedans moderate, GTs low drag, pickups high drag.
		var category: String = str(body.profile.get("category", "road_gt")).to_lower()
		match category:
			"road_sedan": drag_area *= 1.0
			"road_gt": drag_area *= 0.92
			"track_weapon": drag_area *= 0.85
			"pickup": drag_area *= 1.30
			_: drag_area *= 1.0
	# Yaw sensitivity: aero less effective when the car is sideways.
	var forward: Vector3 = -state.transform.basis.z.normalized()
	var yaw_factor: float = 1.0
	if speed > 1.0:
		var aligned: float = velocity.normalized().dot(forward)
		yaw_factor = clampf(aligned, 0.35, 1.0)
		drag_area *= lerpf(1.15, 1.0, yaw_factor)
		aero_area *= yaw_factor
	var health: float = body._condition.aero_health
	body.downforce_n = 0.5 * 1.225 * speed * speed * aero_area * maxf(body.aero_scale, 0.0) * clampf(body.downforce_multiplier, 0.4, 1.0) * health
	if speed > 0.01:
		state.apply_central_force(-velocity.normalized() * pressure * drag_area * clampf(body.drag_multiplier, 0.55, 1.0) * (1.0 + (1.0 - health) * 0.25))
	state.apply_central_force(-state.transform.basis.y.normalized() * body.downforce_n)

static func advance_tyre_temperature(temp_c: float, friction_power: float, ambient_c: float, dt: float, speed_mps: float = 0.0) -> float:
	return Tyres.advance_temperature(temp_c, friction_power, ambient_c, dt, speed_mps)
