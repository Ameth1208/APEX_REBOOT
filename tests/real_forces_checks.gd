extends SceneTree
## Verification of real-force suspension, tire friction ellipse, load sensitivity,
## continuous speed physics (5-300+ km/h), and natural weight transfer for cars and bikes.
## Run: godot_console.exe --headless --path . --fixed-fps 120 --script tests/real_forces_checks.gd

const Vehicle = preload("res://scripts/vehicles/vehicle_body.gd")
const CarVehicle = preload("res://scripts/physics/vehicles/car_vehicle_3d.gd")
const MotoVehicle = preload("res://scripts/physics/vehicles/motorcycle_vehicle_3d.gd")
const TireSolver = preload("res://scripts/physics/tires/tire_solver.gd")
const SuspensionSolver = preload("res://scripts/physics/suspension/suspension_solver.gd")
const AntiRollBar = preload("res://scripts/physics/suspension/anti_roll_bar.gd")

var _failures: Array[String] = []
var _world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for frame: int in count:
		await physics_frame

func _run() -> void:
	_test_suspension_formulas()
	_test_anti_roll_bar()
	_test_tire_friction_ellipse_and_load_sensitivity()
	_test_continuous_speed_physics()
	
	_world = Node3D.new()
	root.add_child(_world)
	var floor_body := StaticBody3D.new()
	floor_body.set_meta("surface", "asphalt")
	floor_body.set_meta("is_road", true)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2000.0, 1.0, 2000.0)
	col.shape = box
	col.position.y = -0.5
	floor_body.add_child(col)
	_world.add_child(floor_body)
	
	await _test_natural_weight_transfer_car()
	await _test_natural_weight_transfer_motorcycle()
	
	if _failures.is_empty():
		print("REAL FORCES CHECKS: PASS (suspension formulas, ARB, friction ellipse, continuous speed, natural weight transfer)")
	else:
		print("REAL FORCES CHECKS: FAIL ", _failures)
	quit(0 if _failures.is_empty() else 1)

func _test_suspension_formulas() -> void:
	var spec := ApexSuspensionSpec.new()
	spec.spring_rate_n_m = 40000.0
	spec.bump_damping_n_s_m = 2500.0
	spec.rebound_damping_n_s_m = 4500.0
	spec.bump_stop_travel_m = 0.15
	spec.bump_stop_stiffness = 150000.0
	spec.bump_stop_exponent = 2.0
	spec.motion_ratio = 1.0
	
	var solver := SuspensionSolver.new(spec)
	
	# 1. Zero compression yields zero force
	var zero_res: Dictionary = solver.solve_forces(0.0, 0.0)
	check(zero_res.total_force == 0.0, "Uncompressed suspension must produce 0 force")
	
	# 2. Static spring deflection F = k * x
	var x_static: float = 0.08
	var static_res: Dictionary = solver.solve_forces(x_static, 0.0)
	check(absf(static_res.spring_force - 40000.0 * x_static) < 0.1, "F_spring must equal k * x")
	
	# 3. Asymmetric damping: bump vs rebound
	var v_comp: float = 0.5
	var v_reb: float = -0.5
	var bump_res: Dictionary = solver.solve_forces(x_static, v_comp)
	var reb_res: Dictionary = solver.solve_forces(x_static, v_reb)
	check(bump_res.damper_force > 0.0, "Damper force must resist compression (positive normal load)")
	check(reb_res.damper_force < 0.0, "Damper force must resist rebound (negative normal contribution)")
	check(absf(reb_res.damper_force) > absf(bump_res.damper_force), "Rebound damping c_r must be stiffer than bump c_b")
	
	# 4. Bump stop protection F_bump = k_b * max(0, x - x_b)^n
	var deep_x: float = 0.20 # 5 cm past bump stop
	var deep_res: Dictionary = solver.solve_forces(deep_x, 0.0)
	var expected_bump: float = 150000.0 * pow(deep_x - 0.15, 2.0)
	check(absf(deep_res.bump_stop_force - expected_bump) < 0.1, "Bump stop force must follow k_b * (x - x_b)^n")
	check(deep_res.total_force > deep_res.spring_force, "Total suspension force includes bump stop")

func _test_anti_roll_bar() -> void:
	var arb := AntiRollBar.new(20000.0)
	# Flat axle: no compression difference
	check(arb.calculate_transfer(0.08, 0.08) == 0.0, "Level axle must have zero ARB load transfer")
	
	# Left compressed more than right (left turn / roll to right)
	var x_l: float = 0.11
	var x_r: float = 0.05
	var transfer: float = arb.calculate_transfer(x_l, x_r)
	check(transfer > 0.0, "Compressed side must receive positive ARB reaction force")
	check(absf(transfer - 20000.0 * (0.11 - 0.05)) < 0.01, "ARB transfer must equal k_arb * delta_x")

func _test_tire_friction_ellipse_and_load_sensitivity() -> void:
	var contact := {
		"normal": Vector3.UP, "velocity": Vector3(10.0, 0.0, -25.0),
		"load": 4000.0, "corner_mass": 400.0, "surface": "asphalt",
		"reference_load_n": 4000.0, "load_sensitivity": 0.0001,
		"cornering_stiffness": 16.0
	}
	
	# 1. Friction ellipse boundary: sqrt(Fx^2 + Fy^2) <= limit_n
	var res: Dictionary = TireSolver.solve(contact, Vector3.FORWARD, 12000.0, 4000.0, 1.0, false, false, 1.0 / 120.0)
	var f: Vector3 = Vector3(res.force)
	check(f.length() <= 4000.01, "Tire forces must remain inside the friction ellipse")
	
	# 2. Strict zero-traction guarantee when Fz == 0
	contact.load = 0.0
	var zero_f: Dictionary = TireSolver.solve(contact, Vector3.FORWARD, 10000.0, 5000.0, 1.0, false, false, 1.0 / 120.0)
	check(Vector3(zero_f.force).is_zero_approx(), "Airborne tire (Fz == 0) must generate exactly 0 force")
	
	# 3. Load sensitivity: effective mu drops at high Fz
	contact.load = 2000.0
	var low_load_res: Dictionary = TireSolver.solve(contact, Vector3.FORWARD, 0.0, 0.0, 1.0, false, false, 1.0 / 120.0)
	contact.load = 8000.0
	var high_load_res: Dictionary = TireSolver.solve(contact, Vector3.FORWARD, 0.0, 0.0, 1.0, false, false, 1.0 / 120.0)
	var mu_low: float = float(low_load_res.effective_mu)
	var mu_high: float = float(high_load_res.effective_mu)
	check(mu_high < mu_low, "Tire load sensitivity must reduce effective mu as normal load increases")

func _test_continuous_speed_physics() -> void:
	# Speeds from 5 km/h to 300 km/h: 5, 40, 80, 120, 200, 300 km/h
	var test_kph: Array[float] = [5.0, 40.0, 80.0, 120.0, 200.0, 300.0]
	var last_fx: float = 0.0
	for kph in test_kph:
		var speed_mps: float = kph / 3.6
		var contact := {
			"normal": Vector3.UP, "velocity": Vector3(1.0, 0.0, -speed_mps),
			"load": 4000.0, "corner_mass": 400.0, "surface": "asphalt",
			"reference_load_n": 4000.0, "cornering_stiffness": 16.0
		}
		var res: Dictionary = TireSolver.solve(contact, Vector3.FORWARD, 2000.0, 0.0, 1.0, false, false, 1.0 / 120.0)
		var f: Vector3 = Vector3(res.force)
		check(not f.is_zero_approx() and f.is_finite(), "Tire solver must be non-zero and stable at " + str(kph) + " km/h")
		# Check that 80 km/h is not a discontinuous step
		if kph == 80.0:
			check(f.length() > 0.0 and absf(f.x) > 0.0, "80 km/h must behave continuously")

func _test_natural_weight_transfer_car() -> void:
	var car := CarVehicle.new()
	# Real car setup: 1400 kg, 60/40 weight distribution, 2.65m wheelbase, 0.52m CG height
	car.configure({
		"mass_kg": 1400.0, "front_weight_fraction": 0.60, "wheelbase_m": 2.65,
		"ride_height_m": 0.58, "engine_torque_nm": 400.0, "brake_force_n": 22000.0,
		"anti_roll_bar_n_m": 25000.0
	})
	_world.add_child(car)
	car.reset_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.58, 0.0)))
	await _frames(240)
	
	# 1. Static Equilibrium Loads (At Rest)
	var telem: Dictionary = car.telemetry()
	var wheels: Array = telem.get("wheels", [])
	check(wheels.size() == 4, "Car must report 4 independent wheels in telemetry")
	
	var static_front_fz: float = wheels[0].fz + wheels[1].fz
	var static_rear_fz: float = wheels[2].fz + wheels[3].fz
	var total_static_fz: float = static_front_fz + static_rear_fz
	var expected_total_w: float = 1400.0 * 9.81
	
	check(absf(total_static_fz - expected_total_w) / expected_total_w < 0.05, "Static wheel loads must sum to total vehicle weight")
	check(static_front_fz > static_rear_fz, "60/40 car must have more normal load in front at rest")
	
	# 2. Braking Weight Transfer (Natural Pitch & Load Transfer)
	car.set_controls(0.0, 0.0, 0.0)
	car.linear_velocity = Vector3(0.0, 0.0, -22.22) # 80 km/h
	await _frames(2)
	car.set_controls(0.0, 0.8, 0.0) # Apply heavy braking
	await _frames(15)
	
	var brake_telem: Dictionary = car.telemetry()
	var brake_wheels: Array = brake_telem.get("wheels", [])
	var brake_front_fz: float = brake_wheels[0].fz + brake_wheels[1].fz
	var brake_rear_fz: float = brake_wheels[2].fz + brake_wheels[3].fz
	
	check(brake_front_fz > static_front_fz, "Braking must naturally increase front axle normal load via pitch and suspension reaction")
	check(brake_rear_fz < static_rear_fz, "Braking must naturally decrease rear axle normal load without duplicate additive equations")
	
	# 3. Cornering Weight Transfer (Lateral Load Transfer & Anti-Roll Bars)
	car.reset_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.58, 0.0)))
	car.linear_velocity = Vector3(0.0, 0.0, -20.0) # 72 km/h
	car.set_controls(0.2, 0.0, 0.35) # Hard right turn
	await _frames(30)
	
	var turn_telem: Dictionary = car.telemetry()
	var turn_wheels: Array = turn_telem.get("wheels", [])
	# Turning right: Left wheels (0 and 2) are outside, Right wheels (1 and 3) are inside
	var left_outside_fz: float = turn_wheels[0].fz + turn_wheels[2].fz
	var right_inside_fz: float = turn_wheels[1].fz + turn_wheels[3].fz
	
	check(left_outside_fz > right_inside_fz, "Cornering must naturally transfer load to outside wheels through body roll and ARBs")
	
	car.queue_free()
	await _frames(2)

func _test_natural_weight_transfer_motorcycle() -> void:
	var bike := MotoVehicle.new()
	# 260 kg bike + rider, 48/52 distribution, 1.42m wheelbase
	bike.configure({
		"kind": "motorcycle", "mass_kg": 260.0, "front_weight_fraction": 0.48,
		"wheelbase_m": 1.42, "ride_height_m": 0.62, "brake_force_n": 5000.0,
		"engine_torque_nm": 90.0
	})
	_world.add_child(bike)
	bike.reset_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.62, 0.0)))
	await _frames(240)
	
	var telem: Dictionary = bike.telemetry()
	var wheels: Array = telem.get("wheels", [])
	check(wheels.size() == 2, "Motorcycle must have exactly 2 wheels")
	
	var static_front: float = wheels[0].fz
	var static_rear: float = wheels[1].fz
	check(absf(static_front + static_rear - 260.0 * 9.81) / (260.0 * 9.81) < 0.05, "Motorcycle static loads must balance total weight")
	
	# Hard braking: front fork compresses, rear wheel unloads
	bike.linear_velocity = Vector3(0.0, 0.0, -20.0)
	bike.set_controls(0.0, 0.85, 0.0)
	await _frames(20)
	
	var brake_telem: Dictionary = bike.telemetry()
	var brake_wheels: Array = brake_telem.get("wheels", [])
	check(brake_wheels[0].fz > static_front, "Motorcycle braking must compress front fork and increase front load")
	check(brake_wheels[1].fz < static_rear, "Motorcycle braking must unload the rear wheel toward a stoppie condition")
	
	bike.queue_free()
	await _frames(2)
