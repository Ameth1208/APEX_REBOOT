class_name ApexVehicle3D
extends RigidBody3D

## Universal Real-Force Vehicle Architecture for APEX.
## Valid for both 4-wheel cars and 2-wheel motorcycles.
## Computes per-wheel loads (Fz, Fx, Fy, xs, \dot{xs}, kappa, alpha, gamma, T, P, wear, n_road).
## Natural load transfer emerges from chassis inertia and suspension reaction forces;
## no artificial speed thresholds or duplicate load transfer equations.

const WheelLayout = preload("res://scripts/physics/wheel_layout.gd")
const Condition = preload("res://scripts/physics/vehicle_condition.gd")
const Feedback = preload("res://scripts/vehicles/vehicle_feedback.gd")
const CollisionEnvelope = preload("res://scripts/physics/vehicle_collision_shape.gd")
const MotorcycleDynamics = preload("res://scripts/physics/motorcycle_dynamics.gd")

const SurfaceSampler = preload("res://scripts/physics/surfaces/surface_sampler.gd")
const SurfaceDef = preload("res://scripts/physics/surfaces/surface_definition.gd")
const TireSolver = preload("res://scripts/physics/tires/tire_solver.gd")
const AeroSolver = preload("res://scripts/physics/aero/aero_solver.gd")
const EngineSolver = preload("res://scripts/physics/powertrain/engine_solver.gd")
const TransmissionSolver = preload("res://scripts/physics/powertrain/transmission_solver.gd")
const DifferentialSolver = preload("res://scripts/physics/powertrain/differential_solver.gd")
const AntiRollBar = preload("res://scripts/physics/suspension/anti_roll_bar.gd")
const SuspensionSolver = preload("res://scripts/physics/suspension/suspension_solver.gd")
const MacPhersonSolver = preload("res://scripts/physics/suspension/macpherson_solver.gd")
const DoubleWishboneSolver = preload("res://scripts/physics/suspension/double_wishbone_solver.gd")
const MotoForkSolver = preload("res://scripts/physics/suspension/motorcycle_fork_solver.gd")

# Vehicle specifications & profile
var spec: ApexVehicleSpec
var profile: Dictionary = {}

# Dynamic telemetry variables
var speed_kph: float = 0.0
var _signed_speed: float = 0.0
var rpm: float = 1000.0
var gear: int = 1
var steer_angle: float = 0.0
var lean_angle: float = 0.0
var total_lean_angle: float = 0.0
var grounded_wheels: int = 0
var downforce_n: float = 0.0
var surface_name: String = "asphalt"
var tire_slip: float = 0.0
var ride_height: float = 0.58
var grip_factor: float = 1.0
var aero_scale: float = 1.0
var draft_strength: float = 0.0
var drag_multiplier: float = 1.0
var downforce_multiplier: float = 1.0
var wetness: float = 0.0
var tyre_temp_c: float = 50.0
var ambient_temp_c: float = 25.0
var avg_tyre_temp_c: float = 50.0
var tyre_temperatures_c: PackedFloat32Array = PackedFloat32Array()

# Driver assists
var auto_transmission: bool = true
var abs_enabled: bool = true
var tcs_enabled: bool = true
var stability_enabled: bool = true
var abs_active: bool = false
var tcs_active: bool = false
var is_motorcycle: bool = false
var assist_mode: String = "Assisted"

# Wheel states & contacts
var wheel_states: Array[ApexWheelState] = []
var wheel_contacts: Array[Dictionary] = []
var crashed: bool:
	get: return _condition.crashed

const LegacySuspension = preload("res://scripts/physics/suspension.gd")
const LegacyPowertrain = preload("res://scripts/physics/powertrain.gd")

# Internal subsystems
var _condition = Condition.new()
var _suspension = LegacySuspension.new()
var _engine = LegacyPowertrain.new()
var _motorcycle = MotorcycleDynamics.new()
var _engine_solver: EngineSolver
var _trans_solver: TransmissionSolver
var _diff_solver: DifferentialSolver
var _aero_solver: AeroSolver
var _front_susp_solver: SuspensionSolver
var _rear_susp_solver: SuspensionSolver
var _front_arb: AntiRollBar
var _rear_arb: AntiRollBar

var _wheel_offsets: Array[Vector3] = []
var _corner_masses: PackedFloat32Array = PackedFloat32Array()
var _ray_queries: Array[PhysicsRayQueryParameters3D] = []
var _collision: CollisionShape3D

var _input: Vector4 = Vector4.ZERO
var _throttle: float = 0.0
var _brake: float = 0.0
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
	spec = ApexVehicleSpec.from_dictionary(profile)
	is_motorcycle = spec.is_motorcycle
	mass = spec.mass_kg
	ride_height = spec.ride_height_m
	grip_factor = spec.front_tire.friction_scale
	
	_engine_solver = EngineSolver.new(spec.powertrain)
	_trans_solver = TransmissionSolver.new(spec.powertrain)
	_diff_solver = DifferentialSolver.new()
	_aero_solver = AeroSolver.new(spec.aero)
	
	# Instantiate suspension solvers
	if is_motorcycle:
		_front_susp_solver = MotoForkSolver.new(spec.front_suspension, 24.5)
		_rear_susp_solver = SuspensionSolver.new(spec.rear_suspension)
	elif spec.front_suspension.type == ApexSuspensionSpec.SuspensionType.DOUBLE_WISHBONE:
		_front_susp_solver = DoubleWishboneSolver.new(spec.front_suspension)
		_rear_susp_solver = DoubleWishboneSolver.new(spec.rear_suspension)
	else:
		_front_susp_solver = MacPhersonSolver.new(spec.front_suspension)
		_rear_susp_solver = SuspensionSolver.new(spec.rear_suspension)
		
	_front_arb = AntiRollBar.new(spec.front_suspension.anti_roll_bar_rate_n_m)
	_rear_arb = AntiRollBar.new(spec.rear_suspension.anti_roll_bar_rate_n_m)
	
	_wheel_offsets = WheelLayout.offsets(profile, is_motorcycle)
	var wheel_count: int = _wheel_offsets.size()
	
	wheel_states.clear()
	_corner_masses.clear()
	_ray_queries.clear()
	tyre_temperatures_c.resize(wheel_count)
	tyre_temperatures_c.fill(50.0)
	
	for i: int in wheel_count:
		var ws := ApexWheelState.new()
		ws.index = i
		ws.mount_offset = _wheel_offsets[i]
		ws.is_front = _wheel_offsets[i].z < 0.0
		ws.is_left = _wheel_offsets[i].x < 0.0
		
		# Drive configuration
		if is_motorcycle:
			ws.is_driven = not ws.is_front
		else:
			match spec.powertrain.layout:
				ApexEngineSpec.DrivetrainLayout.FWD: ws.is_driven = ws.is_front
				ApexEngineSpec.DrivetrainLayout.AWD: ws.is_driven = true
				_: ws.is_driven = not ws.is_front
				
		var share: float = spec.front_weight_fraction if ws.is_front else (1.0 - spec.front_weight_fraction)
		var corner_m: float = mass * share / (1.0 if is_motorcycle else 2.0)
		_corner_masses.append(corner_m)
		
		ws.reset(50.0, 2.2)
		wheel_states.append(ws)
		_ray_queries.append(PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1))
		
	_motorcycle.configure(profile)
	_condition.configure(profile, is_motorcycle)
	_suspension.configure(profile, is_motorcycle, ride_height)
	_engine.configure(profile)
	
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
	
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -ride_height + 0.38, 0.0)
	
	inertia = Vector3(
		mass * (length * length + 0.7) / 12.0,
		mass * (length * length + body_width * body_width) / 12.0,
		mass * (body_width * body_width + 0.7) / 12.0
	)
	if not is_motorcycle:
		var chassis_length: float = maxf(float(profile.get("length_m", length)), length)
		var chassis_width: float = maxf(float(profile.get("body_width_m", body_width)), body_width)
		inertia.y = mass * (chassis_length * chassis_length + chassis_width * chassis_width) / 12.0
		
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.35
	material.bounce = 0.05
	physics_material_override = material
	
	rpm = _engine_solver.rpm
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
	_trans_solver.shift_up()
	gear = _trans_solver.gear

func shift_down() -> void:
	if gear <= 1 and absf(_signed_speed) > 2.0:
		return
	_trans_solver.shift_down()
	gear = _trans_solver.gear

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
	if _trans_solver:
		_trans_solver.gear = 1
		gear = 1
	if _engine_solver:
		_engine_solver.rpm = _engine_solver.spec.idle_rpm
		rpm = _engine_solver.rpm
	tyre_temperatures_c.fill(50.0)
	tyre_temp_c = 50.0
	avg_tyre_temp_c = 50.0
	for ws in wheel_states:
		ws.reset(50.0, 2.2)
	sleeping = false
	reset_physics_interpolation()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_pending:
		state.transform = _reset_pose
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_reset_pending = false
		
	var dt: float = state.step
	var body_forward: Vector3 = -state.transform.basis.z.normalized()
	var body_up: Vector3 = state.transform.basis.y.normalized()
	var body_right: Vector3 = state.transform.basis.x.normalized()
	
	_signed_speed = state.linear_velocity.dot(body_forward)
	speed_kph = state.linear_velocity.length() * 3.6
	
	if _condition.sample(state, mass):
		_begin_fall(state, body_forward)
		
	# Gear selection from driver input
	if _input.x < -0.01 and absf(_signed_speed) < 1.5:
		_trans_solver.gear = -1
		gear = -1
	elif _input.x > 0.01 and _trans_solver.gear < 0 and absf(_signed_speed) < 1.0:
		_trans_solver.gear = 1
		gear = 1
		
	_throttle = move_toward(_throttle, absf(_input.x), dt * 5.0)
	_brake = move_toward(_brake, _input.y, dt / spec.powertrain.brake_response_time_s)
	
	# Continuous steering without artificial speed thresholds
	var max_steer: float = deg_to_rad(spec.max_steer_deg)
	var target_steer: float = 0.0
	if is_motorcycle:
		target_steer = _motorcycle.steering(_input.z, _signed_speed, max_steer, state.angular_velocity.dot(body_up), dt)
	else:
		# Smooth continuous speed falloff based on speed, eliminating abrupt thresholds
		var cat: String = str(profile.get("category", "road_gt"))
		var speed_falloff: float = 0.060
		if cat == "road_sedan": speed_falloff = 0.050
		elif cat == "track_weapon": speed_falloff = 0.085
		elif cat == "pickup": speed_falloff = 0.045
		target_steer = _input.z * max_steer / (1.0 + absf(_signed_speed) * speed_falloff)
		
	var steer_rate: float = 1.8 * _condition.steering_scale() / (1.0 + absf(_signed_speed) * 0.025)
	target_steer = target_steer * _condition.steering_scale() + _condition.steering_bias
	steer_angle = move_toward(steer_angle, target_steer, dt * steer_rate)
	
	# Drivetrain torque calculation
	var wheel_r: float = spec.front_tire.radius_m
	var wheel_rpm: float = absf(_signed_speed) / maxf(wheel_r, 0.1) * 60.0 / TAU
	var coupled_rpm: float = wheel_rpm * absf(_trans_solver.get_ratio()) * spec.powertrain.final_drive
	
	_trans_solver.step_auto(coupled_rpm, auto_transmission, dt)
	gear = _trans_solver.gear
	
	var launch_rpm: float = spec.powertrain.idle_rpm + _throttle * spec.powertrain.max_rpm * 0.26
	var target_rpm: float = maxf(coupled_rpm, launch_rpm)
	if gear == 0:
		target_rpm = lerpf(spec.powertrain.idle_rpm, spec.powertrain.max_rpm, _throttle)
	_engine_solver.step(target_rpm, dt)
	rpm = _engine_solver.rpm if can_drive() else 0.0
	
	var engine_torque: float = _throttle * _engine_solver.torque_at(rpm) * _condition.power_scale()
	if coupled_rpm > spec.powertrain.max_rpm:
		engine_torque *= clampf((spec.powertrain.max_rpm * 1.035 - coupled_rpm) / (spec.powertrain.max_rpm * 0.035), 0.0, 1.0)
	if _trans_solver.shift_cooldown > 0.12:
		engine_torque *= 0.2
		
	var total_drive_torque: float = 0.0
	if gear != 0:
		total_drive_torque = engine_torque * _trans_solver.get_ratio() * spec.powertrain.final_drive * spec.powertrain.drivetrain_efficiency
		if absf(_signed_speed) > 1.0 and _throttle < 0.04:
			total_drive_torque -= signf(_signed_speed) * spec.powertrain.max_torque_nm * 0.11 * absf(_trans_solver.get_ratio()) * spec.powertrain.final_drive
			
	# --- PHASE 1: WHEEL RAY SAMPLES & SUSPENSION RESOLUTION ---
	var space: PhysicsDirectSpaceState3D = state.get_space_state()
	var sag: float = spec.front_suspension.sag_m
	var ray_dist: float = ride_height + sag
	
	grounded_wheels = 0
	wheel_contacts.clear()
	var ground_normal_sum: Vector3 = Vector3.ZERO
	
	for i: int in wheel_states.size():
		var ws: ApexWheelState = wheel_states[i]
		var origin: Vector3 = state.transform * ws.mount_offset
		var query: PhysicsRayQueryParameters3D = _ray_queries[i]
		query.from = origin
		query.to = origin - body_up * ray_dist
		if query.exclude.is_empty():
			query.exclude = [get_rid()]
			
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			ws.is_grounded = false
			ws.normal_load_n = 0.0
			ws.compression = 0.0
			ws.compression_velocity = 0.0
			continue
			
		var hit_norm: Vector3 = hit["normal"]
		if hit_norm.dot(body_up) < 0.25:
			ws.is_grounded = false
			ws.normal_load_n = 0.0
			continue
			
		ws.is_grounded = true
		grounded_wheels += 1
		ground_normal_sum += hit_norm
		ws.road_normal = hit_norm
		ws.global_contact = hit["position"]
		ws.contact_position = ws.global_contact - state.transform.origin
		ws.contact_velocity = state.get_velocity_at_local_position(ws.contact_position)
		
		# Compression x_s = ride_height + sag - distance
		var dist: float = origin.distance_to(ws.global_contact)
		ws.compression = maxf(0.0, ray_dist - dist)
		
		# Compression velocity \dot{x}_s: relative speed projected onto body normal
		var damp_v: float = ws.contact_velocity.dot(hit_norm)
		ws.compression_velocity = -damp_v
		
		var collider: Object = hit["collider"]
		ws.surface_name = SurfaceSampler.sample_surface(Vector2(ws.global_contact.x, ws.global_contact.z), collider)
		
		# Suspension solver call (spring + asymmetric damper + bump stop)
		var susp_solver: SuspensionSolver = _front_susp_solver if ws.is_front else _rear_susp_solver
		var susp_res: Dictionary = susp_solver.solve_forces(ws.compression, ws.compression_velocity)
		ws.spring_force_n = float(susp_res["spring_force"])
		ws.damper_force_n = float(susp_res["damper_force"])
		ws.bump_stop_force_n = float(susp_res["bump_stop_force"])
		ws.normal_load_n = float(susp_res["total_force"])
		
	# --- PHASE 2: ANTI-ROLL BARS (ELASTIC LOAD TRANSFER) ---
	if not is_motorcycle and wheel_states.size() == 4:
		# Front ARB: Wheel 0 (FL) vs Wheel 1 (FR)
		if wheel_states[0].is_grounded and wheel_states[1].is_grounded:
			var arb_f: float = _front_arb.calculate_transfer(wheel_states[0].compression, wheel_states[1].compression)
			wheel_states[0].arb_force_n = arb_f
			wheel_states[1].arb_force_n = -arb_f
			wheel_states[0].normal_load_n = maxf(0.0, wheel_states[0].normal_load_n + arb_f)
			wheel_states[1].normal_load_n = maxf(0.0, wheel_states[1].normal_load_n - arb_f)
			
		# Rear ARB: Wheel 2 (RL) vs Wheel 3 (RR)
		if wheel_states[2].is_grounded and wheel_states[3].is_grounded:
			var arb_r: float = _rear_arb.calculate_transfer(wheel_states[2].compression, wheel_states[3].compression)
			wheel_states[2].arb_force_n = arb_r
			wheel_states[3].arb_force_n = -arb_r
			wheel_states[2].normal_load_n = maxf(0.0, wheel_states[2].normal_load_n + arb_r)
			wheel_states[3].normal_load_n = maxf(0.0, wheel_states[3].normal_load_n - arb_r)
			
	# --- PHASE 3: APPLY SUSPENSION REACTION FORCES ---
	for ws in wheel_states:
		if ws.is_grounded and ws.normal_load_n > 0.0:
			state.apply_force(ws.road_normal * ws.normal_load_n, ws.contact_position)
			
	# --- PHASE 4: TIRE FORCES & FRICTION ELLIPSE ---
	tire_slip = 0.0
	abs_active = false
	tcs_active = false
	
	var driven_wheels_count: float = 0.0
	for ws in wheel_states:
		if ws.is_driven and ws.is_grounded:
			driven_wheels_count += 1.0
	driven_wheels_count = maxf(1.0, driven_wheels_count)
	
	var brake_total: float = spec.powertrain.brake_force_total_n
	var f_bias: float = spec.powertrain.front_brake_bias
	
	for i: int in wheel_states.size():
		var ws: ApexWheelState = wheel_states[i]
		if not ws.is_grounded or ws.normal_load_n <= 0.0:
			continue
			
		# Ackermann steer angle
		var w_steer: float = steer_angle
		if ws.is_front and not is_motorcycle:
			w_steer = WheelLayout.steering(steer_angle, ws.mount_offset.x, spec.wheelbase_m)
		ws.steer_angle_rad = w_steer if ws.is_front else 0.0
		
		# Wheel heading
		var w_heading: Vector3 = body_forward.rotated(ws.road_normal, -ws.steer_angle_rad) if ws.is_front else body_forward
		ws.forward_vector = w_heading.slide(ws.road_normal).normalized()
		ws.lateral_vector = ws.forward_vector.cross(ws.road_normal).normalized()
		
		# Drive force for this wheel
		var wheel_drive_n: float = (total_drive_torque / maxf(wheel_r, 0.1) / driven_wheels_count) if ws.is_driven else 0.0
		
		# Brake force for this wheel
		var wheel_brake_share: float = (f_bias if ws.is_front else (1.0 - f_bias)) / (1.0 if is_motorcycle else 2.0)
		var wheel_brake_n: float = _brake * brake_total * wheel_brake_share
		if not ws.is_front:
			wheel_brake_n += _input.w * mass * 12.0 / (1.0 if is_motorcycle else 2.0)
			
		surface_name = ws.surface_name
		var base_mu: float = SurfaceDef.get_friction(ws.surface_name, wetness, grip_factor)
		var tyre_dict: Dictionary = profile.get("front_tyre" if ws.is_front else "rear_tyre", {})
		base_mu *= maxf(float(tyre_dict.get("grip_scale", 1.0)), 0.0)
		var cornering_stiff: float = float(tyre_dict.get("cornering_stiffness", 18.0 if is_motorcycle else 14.0))
		if tyre_dict.has("width_mm"):
			var reference_width: float = float(tyre_dict.get("reference_width_mm", 275.0))
			cornering_stiff *= sqrt(maxf(float(tyre_dict.width_mm), 1.0) / maxf(reference_width, 1.0))
		
		# Sync externally modified tyre temperature (e.g. from tests or pit strategy)
		ws.temperature_c = tyre_temperatures_c[i]
		
		var contact_dict: Dictionary = {
			"requested_brake_n": wheel_brake_n,
			"index": ws.index,
			"position": ws.contact_position,
			"normal": ws.road_normal,
			"velocity": ws.contact_velocity,
			"load": ws.normal_load_n,
			"corner_mass": _corner_masses[i],
			"front": ws.is_front,
			"surface": ws.surface_name,
			"compression": ws.compression,
			"cornering_stiffness": cornering_stiff,
			"reference_load_n": _corner_masses[i] * 9.81,
			"load_sensitivity": float(tyre_dict.get("load_sensitivity", 0.00008)),
			"temperature_c": ws.temperature_c,
			"wear": ws.wear,
			"slide_speed": ws.slide_speed_mps
		}
		for key: String in ["cornering_stiffness_n_per_rad", "reference_load_n", "load_sensitivity"]:
			if tyre_dict.has(key):
				contact_dict[key] = tyre_dict[key]
		
		# Traction control cut on lateral slide or spinning
		if ws.is_driven and tcs_enabled:
			var lat_slide: float = absf(ws.slide_speed_mps)
			if lat_slide > 3.0:
				wheel_drive_n *= clampf(1.0 - (lat_slide - 3.0) / 8.0, 0.2, 1.0)
		if ws.is_driven and stability_enabled and not is_motorcycle:
			var yaw_r: float = state.angular_velocity.dot(ws.road_normal)
			var des_yaw: float = -_signed_speed * tan(steer_angle) / spec.wheelbase_m
			var yaw_diff: float = absf(yaw_r - des_yaw)
			if yaw_diff > 0.5:
				wheel_drive_n *= clampf(1.0 - (yaw_diff - 0.5) * 0.6, 0.1, 1.0)
				
		var solve_res: Dictionary = TireSolver.solve(
			contact_dict,
			ws.forward_vector,
			wheel_drive_n,
			wheel_brake_n,
			base_mu,
			abs_enabled and _input.w < 0.1,
			tcs_enabled,
			dt
		)
		
		var force_vec: Vector3 = Vector3(solve_res["force"])
		state.apply_force(force_vec, ws.contact_position)
		
		ws.combined_force = force_vec
		ws.slip_ratio = float(solve_res["slip"])
		ws.slide_speed_mps = float(solve_res["slide_speed"])
		ws.friction_power_w = float(solve_res["friction_power_w"])
		ws.is_locked = bool(solve_res["locked"])
		ws.abs_active = bool(solve_res["abs"])
		ws.tcs_active = bool(solve_res["tcs"])
		ws.longitudinal_force_n = float(solve_res["fx"])
		ws.lateral_force_n = float(solve_res["fy"])
		
		tire_slip = maxf(tire_slip, ws.slip_ratio)
		abs_active = abs_active or ws.abs_active
		tcs_active = tcs_active or ws.tcs_active
		
		# Thermal update per tire
		ws.temperature_c = TireSolver.ThermalModel.step_temperature(
			ws.temperature_c,
			ws.friction_power_w,
			ambient_temp_c,
			_signed_speed,
			dt
		)
		tyre_temperatures_c[i] = ws.temperature_c
		
		contact_dict["friction_power_w"] = ws.friction_power_w
		contact_dict["slip"] = ws.slip_ratio
		wheel_contacts.append(contact_dict)
		
	# Average tyre temperature
	var total_t: float = 0.0
	for t in tyre_temperatures_c:
		total_t += t
	avg_tyre_temp_c = total_t / maxf(1.0, float(tyre_temperatures_c.size()))
	tyre_temp_c = avg_tyre_temp_c
	
	# --- PHASE 5: AERODYNAMICS (DRAG & BALANCED DOWNFORCE) ---
	var aero_res: Dictionary = _aero_solver.solve(
		state.linear_velocity,
		state.transform.basis,
		aero_scale,
		drag_multiplier,
		downforce_multiplier,
		_condition.aero_health
	)
	var drag_f: Vector3 = Vector3(aero_res["drag_force"])
	downforce_n = float(aero_res["total_downforce_n"])
	var downforce_vec: Vector3 = Vector3(aero_res["downforce_force"])
	
	if drag_f.length_squared() > 0.001:
		state.apply_central_force(drag_f)
	if downforce_vec.length_squared() > 0.001:
		state.apply_central_force(downforce_vec)
		
	# Ground normal vector
	var ground_normal: Vector3 = (ground_normal_sum / maxf(1.0, float(grounded_wheels))).normalized() if grounded_wheels > 0 else Vector3.UP
	
	# --- PHASE 6: MOTORCYCLE BALANCE OR CAR STABILITY CONTROL ---
	if is_motorcycle and _condition.observe_balance(state.transform.basis.y.dot(ground_normal), _signed_speed, tire_slip, total_lean_angle, grounded_wheels > 0, dt):
		_begin_fall(state, body_forward)
		
	if is_motorcycle and not crashed:
		_motorcycle.integrate(state, steer_angle, _signed_speed, ground_normal, mass, dt, grounded_wheels > 0)
		var chassis_roll: float = atan2(body_right.dot(ground_normal), body_up.dot(ground_normal))
		total_lean_angle = _motorcycle.lean_angle
		lean_angle = total_lean_angle + chassis_roll
	elif crashed:
		lean_angle = 0.0
		total_lean_angle = atan2(-body_right.dot(ground_normal), body_up.dot(ground_normal))
	elif stability_enabled and grounded_wheels >= 3:
		# Electronic stability control for cars
		var yaw_rate: float = state.angular_velocity.dot(ground_normal)
		var desired_yaw: float = -_signed_speed * tan(steer_angle) / spec.wheelbase_m
		var yaw_error: float = clampf(desired_yaw - yaw_rate, -1.5, 1.5)
		var gain: float = 0.45 + absf(yaw_error) * 1.2
		state.apply_torque(ground_normal * yaw_error * mass * gain)
		var excess_yaw: float = yaw_rate - desired_yaw
		if absf(excess_yaw) > 0.3:
			state.apply_torque(-ground_normal * signf(excess_yaw) * mass * minf(absf(excess_yaw), 1.0) * 0.3)

func _begin_fall(state: PhysicsDirectBodyState3D, forward: Vector3) -> void:
	var direction: float = signf(total_lean_angle)
	if is_zero_approx(direction):
		direction = signf(_condition.steering_bias) if absf(_condition.steering_bias) > 0.001 else 1.0
	state.apply_torque_impulse(forward * direction * mass * 0.11)

func telemetry() -> Dictionary:
	var wheel_dict_array: Array = []
	for ws in wheel_states:
		wheel_dict_array.append(ws.to_dictionary())
		
	var result: Dictionary = {
		"brake_capacity_n": spec.powertrain.brake_force_total_n,
		"front_brake_capacity_n": spec.powertrain.brake_force_total_n * spec.powertrain.front_brake_bias,
		"rear_brake_capacity_n": spec.powertrain.brake_force_total_n * (1.0 - spec.powertrain.front_brake_bias),
		"requested_brake_n": _brake * spec.powertrain.brake_force_total_n,
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
		"tyre_temperatures_c": tyre_temperatures_c.duplicate(),
		"wheels": wheel_dict_array
	}
	result.merge(_condition.snapshot())
	return result
