class_name ApexVehicle
extends RigidBody3D
## Shared physical body for player and AI. Local forward is -Z; steer > 0 is right.

const SuspensionSolver = preload("res://scripts/physics/suspension.gd")
const Forces = preload("res://scripts/physics/vehicle_forces.gd")
const Condition = preload("res://scripts/physics/vehicle_condition.gd")
const Feedback = preload("res://scripts/vehicles/vehicle_feedback.gd")
const Powertrain = preload("res://scripts/physics/powertrain.gd")
const Motorcycle = preload("res://scripts/physics/motorcycle_dynamics.gd")
const CollisionEnvelope = preload("res://scripts/physics/vehicle_collision_shape.gd")

var profile: Dictionary = {}
var speed_kph: float = 0.0
var rpm: float = 1000.0
var gear: int = 1
var steer_angle: float = 0.0
var lean_angle: float = 0.0
var total_lean_angle: float = 0.0
var grounded_wheels: int = 0
var downforce_n: float = 0.0
var surface_name: String = "asphalt"
var tire_slip: float = 0.0
var ride_height: float = 0.62
var grip_factor: float = 1.0
var aero_scale: float = 1.0
var draft_strength: float = 0.0
var drag_multiplier: float = 1.0
var downforce_multiplier: float = 1.0
var wetness: float = 0.0
var tyre_temp_c: float = 50.0
var ambient_temp_c: float = 25.0
var avg_tyre_temp_c: float = 50.0
var auto_transmission: bool = true
var abs_enabled: bool = true
var tcs_enabled: bool = true
var stability_enabled: bool = true
var abs_active: bool = false
var tcs_active: bool = false
var is_motorcycle: bool = false
var assist_mode: String = "Assisted"
var wheel_contacts: Array[Dictionary] = []
var crashed: bool:
	get: return _condition.crashed

var _condition = Condition.new()
var _suspension = SuspensionSolver.new()
var _engine = Powertrain.new()
var _motorcycle = Motorcycle.new()
var _collision: CollisionShape3D
var _input: Vector4 = Vector4.ZERO
var _throttle: float = 0.0
var _brake: float = 0.0
var _signed_speed: float = 0.0
var _reset_pending: bool = false
var _reset_pose: Transform3D = Transform3D.IDENTITY

func _ready() -> void:
	if profile.is_empty():
		configure({})
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 12
	linear_damp = 0.0
	angular_damp = 0.38
	if DisplayServer.get_name() != "headless":
		var feedback: Node3D = Feedback.new()
		feedback.name = "ContactFeedback"
		add_child(feedback)

func configure(data: Dictionary) -> void:
	profile = data.duplicate(true)
	var kind: String = str(profile.get("kind", profile.get("category", "car"))).to_lower()
	is_motorcycle = kind in ["motorcycle", "motorbike", "bike", "supersport", "moto"]
	mass = float(profile.get("mass_kg", profile.get("mass", 1450.0)))
	ride_height = float(profile.get("ride_height_m", profile.get("ride_height", 0.61 if is_motorcycle else 0.58)))
	grip_factor = float(profile.get("tire_grip_scale", profile.get("grip_factor", float(profile.get("grip", 1.22)) / 1.22)))
	_suspension.configure(profile, is_motorcycle, ride_height)
	_engine.configure(profile)
	_motorcycle.configure(profile)
	_condition.configure(profile, is_motorcycle)
	collision_layer = 2
	collision_mask = 3
	var width: float = float(profile.get("track_width_m", profile.get("track_width", 1.64)))
	var length: float = float(profile.get("wheelbase_m", profile.get("wheelbase", 2.65)))
	var body_width: float = 0.46 if is_motorcycle else width * 0.94
	if not is_instance_valid(_collision):
		_collision = CollisionShape3D.new()
		_collision.name = "ChassisCollision"
		add_child(_collision)
	_collision.shape = CollisionEnvelope.build(profile, is_motorcycle, ride_height)
	_collision.position = Vector3.ZERO
	# Keep the previous handling tune while improving only the collision envelope.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -ride_height + 0.38, 0.0)
	# Approximate chassis inertia prevents a thin visual mesh from defining handling.
	inertia = Vector3(mass * (length * length + 0.7) / 12.0, mass * (length * length + body_width * body_width) / 12.0, mass * (body_width * body_width + 0.7) / 12.0)
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.35
	material.bounce = 0.05
	physics_material_override = material
	rpm = _engine.rpm
	gear = 1

func can_drive() -> bool:
	return _condition.can_drive()

func set_controls(throttle: float, brake: float, steer: float, handbrake: float = 0.0) -> void:
	_input = Vector4(clampf(throttle, -1.0, 1.0), clampf(brake, 0.0, 1.0), clampf(steer, -1.0, 1.0), clampf(handbrake, 0.0, 1.0))

func set_assist_mode(mode: String) -> void:
	assist_mode = mode
	abs_enabled = mode != "Expert"
	tcs_enabled = mode == "Assisted"
	stability_enabled = mode == "Assisted"

func shift_up() -> void:
	if gear < 1 and absf(_signed_speed) > 2.0:
		return
	_engine.shift_up()
	gear = _engine.gear

func shift_down() -> void:
	if gear <= 1 and absf(_signed_speed) > 2.0:
		return
	_engine.shift_down()
	gear = _engine.gear

func reset_at(pose: Transform3D) -> void:
	_reset_pose = pose
	_reset_pending = true
	_condition.repair()
	global_transform = pose
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_input = Vector4.ZERO
	_throttle = 0.0
	_brake = 0.0
	steer_angle = 0.0
	lean_angle = 0.0
	total_lean_angle = 0.0
	draft_strength = 0.0
	drag_multiplier = 1.0
	downforce_multiplier = 1.0
	_motorcycle.configure(profile)
	_engine.gear = 1
	gear = 1
	_engine.rpm = _engine.idle_rpm
	sleeping = false
	reset_physics_interpolation()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_pending:
		state.transform = _reset_pose
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_reset_pending = false
	var dt: float = state.step
	var forward: Vector3 = -state.transform.basis.z.normalized()
	_signed_speed = state.linear_velocity.dot(forward)
	speed_kph = state.linear_velocity.length() * 3.6
	if _condition.sample(state, mass):
		_begin_fall(state, forward)
	if _input.x < -0.01 and absf(_signed_speed) < 1.5:
		_engine.gear = -1
	elif _input.x > 0.01 and _engine.gear < 0 and absf(_signed_speed) < 1.0:
		_engine.gear = 1
	_throttle = move_toward(_throttle, absf(_input.x), dt * 5.0)
	_brake = move_toward(_brake, _input.y, dt * 8.0)
	var max_steer: float = deg_to_rad(float(profile.get("max_steer_deg", 32.0)))
	var target_steer: float = _input.z * max_steer / (1.0 + absf(_signed_speed) * 0.045)
	if is_motorcycle:
		target_steer = _motorcycle.steering(_input.z, _signed_speed, max_steer, state.angular_velocity.dot(state.transform.basis.y), dt)
	else:
		# Cars: Ackermann-sensitive speed falloff. Sedans keep more angle at speed
		# than sports cars (less twitchy); trucks steer slower.
		var category: String = str(profile.get("category", "road_gt"))
		var speed_falloff: float = 0.045
		if category == "road_sedan": speed_falloff = 0.032
		elif category == "road_gt": speed_falloff = 0.040
		elif category == "track_weapon": speed_falloff = 0.055
		elif category == "pickup": speed_falloff = 0.028
		target_steer = _input.z * max_steer / (1.0 + absf(_signed_speed) * speed_falloff)
	target_steer = target_steer * _condition.steering_scale() + _condition.steering_bias
	steer_angle = move_toward(steer_angle, target_steer, dt * 1.8 * _condition.steering_scale())
	var drive_torque: float = _engine.drive_torque(_signed_speed, _throttle, auto_transmission, dt)
	drive_torque *= _condition.power_scale()
	rpm = _engine.rpm if can_drive() else 0.0
	gear = _engine.gear
	wheel_contacts = _suspension.sample(state, get_rid())
	grounded_wheels = wheel_contacts.size()
	tire_slip = 0.0
	abs_active = false
	tcs_active = false
	var ground_normal: Vector3 = Vector3.ZERO
	for contact: Dictionary in wheel_contacts:
		ground_normal += Vector3(contact["normal"])
		Forces.contact(self, state, contact, forward, drive_torque, dt)
	Forces.aero(self, state)
	# Advance tyre temperature from friction work.
	if grounded_wheels > 0:
		var slip_speed: float = 0.0
		for contact: Dictionary in wheel_contacts:
			slip_speed = maxf(slip_speed, absf(float(contact.get("slide_speed", 0.0))))
		var friction_power: float = float(wheel_contacts[0].get("load", 0.0)) * slip_speed
		tyre_temp_c = Forces.advance_tyre_temperature(tyre_temp_c, friction_power, ambient_temp_c, dt, absf(_signed_speed))
	avg_tyre_temp_c = tyre_temp_c
	if grounded_wheels > 0:
		ground_normal = ground_normal.normalized()
	else:
		ground_normal = Vector3.UP
	if is_motorcycle and _condition.observe_balance(state.transform.basis.y.dot(ground_normal), _signed_speed, tire_slip, total_lean_angle, grounded_wheels > 0, dt):
		_begin_fall(state, forward)
	if is_motorcycle and not crashed:
		_motorcycle.integrate(state, steer_angle, _signed_speed, ground_normal, mass, dt, grounded_wheels > 0)
		var chassis_roll: float = atan2(state.transform.basis.x.dot(ground_normal), state.transform.basis.y.dot(ground_normal))
		total_lean_angle = _motorcycle.lean_angle
		lean_angle = total_lean_angle + chassis_roll
	elif crashed:
		lean_angle = 0.0
		total_lean_angle = atan2(-state.transform.basis.x.dot(ground_normal), state.transform.basis.y.dot(ground_normal))
	elif stability_enabled and grounded_wheels >= 3:
		# Dampen excessive yaw only; this assist cannot supply lateral traction.
		var yaw_rate: float = state.angular_velocity.dot(ground_normal)
		var desired_yaw: float = -_signed_speed * tan(steer_angle) / float(profile.get("wheelbase_m", profile.get("wheelbase", 2.65)))
		var yaw_error: float = clampf(desired_yaw - yaw_rate, -0.8, 0.8)
		state.apply_torque(ground_normal * yaw_error * mass * 0.45)

func _begin_fall(state: PhysicsDirectBodyState3D, forward: Vector3) -> void:
	var direction: float = signf(total_lean_angle)
	if is_zero_approx(direction):
		direction = signf(_condition.steering_bias) if absf(_condition.steering_bias) > 0.001 else 1.0
	# A single roll impulse begins the fall; contact and gravity resolve the body.
	state.apply_torque_impulse(forward * direction * mass * 0.11)

func telemetry() -> Dictionary:
	var result: Dictionary = {
		"speed_kph": speed_kph, "signed_speed_mps": _signed_speed, "rpm": rpm, "gear": gear,
		"steer_angle": steer_angle, "lean_angle": total_lean_angle, "visual_lean_angle": lean_angle,
		"grounded_wheels": grounded_wheels, "downforce_n": downforce_n,
		"surface": surface_name, "surface_name": surface_name, "tire_slip": tire_slip,
		"abs_active": abs_active, "tcs_active": tcs_active, "assist_mode": assist_mode,
		"throttle": _throttle, "brake": _brake,
		"input_throttle": absf(_input.x), "input_brake": _input.y, "handbrake": _input.w,
		"is_motorcycle": is_motorcycle, "draft_strength": draft_strength,
		"drag_multiplier": drag_multiplier, "downforce_multiplier": downforce_multiplier,
		"tyre_temp_c": tyre_temp_c, "ambient_temp_c": ambient_temp_c,
	}
	result.merge(_condition.snapshot())
	return result
