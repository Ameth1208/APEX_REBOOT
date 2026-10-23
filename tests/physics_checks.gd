extends SceneTree
## Run: godot --headless --path . --fixed-fps 120 --script tests/physics_checks.gd

const Vehicle = preload("res://scripts/vehicles/vehicle_body.gd")
const Tyres = preload("res://scripts/physics/tyre_forces.gd")
const Drivetrain = preload("res://scripts/physics/powertrain.gd")
const Suspension = preload("res://scripts/physics/suspension.gd")

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
	_check_tyre_limits()
	_check_drivetrain()
	_world = Node3D.new()
	root.add_child(_world)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.set_meta("surface", "asphalt")
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2000.0, 1.0, 2000.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	_world.add_child(floor_body)
	await _check_car()
	await _check_motorcycle()
	await _check_slope()
	if _failures.is_empty():
		print("PHYSICS CHECKS: PASS (tyres, drivetrain, suspension, braking, steering, motorcycle)")
	else:
		print("PHYSICS CHECKS: FAIL ", _failures)
	quit(0 if _failures.is_empty() else 1)

func _check_tyre_limits() -> void:
	var dry: float = Tyres.friction("asphalt", 0.0, 1.0)
	var wet: float = Tyres.friction("asphalt", 1.0, 1.0)
	check(wet < dry, "Wet asphalt must reduce traction")
	check(Tyres.friction("grass", 0.0, 1.0) < dry, "Grass must have less traction than asphalt")
	var contact: Dictionary = {"normal": Vector3.UP, "velocity": Vector3(5.0, 0.0, -20.0), "load": 3000.0, "corner_mass": 350.0, "surface": "asphalt"}
	var result: Dictionary = Tyres.solve(contact, Vector3.FORWARD, 9000.0, 0.0, dry, false, false, 1.0 / 120.0)
	check(Vector3(result["force"]).length() <= dry * 3000.0 + 0.01, "Combined tyre force exceeded friction circle")
	check(Vector3(result["force"]).x < 0.0, "Lateral tyre force must oppose lateral slip")
	var abs_result: Dictionary = Tyres.solve(contact, Vector3.FORWARD, 0.0, 15000.0, dry, true, false, 1.0 / 120.0)
	check(bool(abs_result["abs"]), "ABS must detect an excessive brake request")
	var tcs_result: Dictionary = Tyres.solve(contact, Vector3.FORWARD, 20000.0, 0.0, dry, false, true, 1.0 / 120.0)
	check(bool(tcs_result["tcs"]), "TCS must detect excessive drive demand")

func _check_drivetrain() -> void:
	var power = Drivetrain.new()
	power.configure({"engine_torque_nm": 465.0})
	check(power.drive_torque(0.0, 1.0, false, 0.1) > 0.0, "First gear must drive forward")
	power.gear = -1
	check(power.drive_torque(0.0, 1.0, false, 0.1) < 0.0, "Reverse must produce negative torque")
	power.gear = 0
	check(is_zero_approx(power.drive_torque(0.0, 1.0, false, 0.1)), "Neutral must disconnect drive torque")
	power.gear = 1
	power.drive_torque(45.0, 1.0, true, 0.3)
	check(power.gear > 1, "Automatic transmission must upshift before redline")
	var springs = Suspension.new()
	springs.configure({}, false, 0.58)
	check(springs.offsets.size() == 4, "Car requires four independent contacts")
	springs.configure({}, true, 0.61)
	check(springs.offsets.size() == 2, "Motorcycle requires exactly two contacts")

func _check_car() -> void:
	var car = Vehicle.new()
	car.configure({"mass_kg": 1450.0, "engine_torque_nm": 465.0, "wheelbase_m": 2.65, "ride_height_m": 0.58})
	_world.add_child(car)
	car.reset_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.58, 0.0)))
	await _frames(360)
	print("CAR idle: height=", car.position.y, " speed=", car.speed_kph, " wheels=", car.grounded_wheels)
	check(absf(car.position.y - car.ride_height) < 0.045, "Car suspension must settle at configured ride height")
	check(car.linear_velocity.length() < 0.2 and car.grounded_wheels == 4, "Car must remain stable on flat ground")
	car.set_controls(1.0, 0.0, 0.0)
	await _frames(600)
	print("CAR throttle: speed=", car.speed_kph, " position=", car.position, " up=", car.basis.y)
	check(car.speed_kph > 60.0, "Car must accelerate from engine torque")
	check(car.basis.y.dot(Vector3.UP) > 0.90, "Car must remain upright under acceleration")
	car.set_controls(0.0, 1.0, 0.0)
	await _frames(420)
	print("CAR braking: speed=", car.speed_kph)
	check(car.speed_kph < 3.0, "Braking must stop the car without reversing it")
	car.reset_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.58, 0.0)))
	car.set_controls(1.0, 0.0, 0.0)
	await _frames(240)
	car.set_controls(0.5, 0.0, 0.25)
	await _frames(180)
	print("CAR right turn: x=", car.position.x, " yaw=", car.rotation.y)
	check(car.position.x > 0.8 and car.rotation.y < -0.05, "Positive steer must turn the car to its right")
	car.queue_free()
	await _frames(2)

func _check_motorcycle() -> void:
	var bike = Vehicle.new()
	bike.configure({"kind": "motorcycle", "mass_kg": 280.0, "engine_torque_nm": 113.0, "max_rpm": 14000.0, "wheelbase_m": 1.405, "ride_height_m": 0.61, "wheel_radius_m": 0.30, "final_drive": 5.5})
	_world.add_child(bike)
	bike.reset_at(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.61, 0.0)))
	await _frames(360)
	print("BIKE idle: height=", bike.position.y, " speed=", bike.speed_kph, " wheels=", bike.grounded_wheels)
	check(bike.grounded_wheels == 2 and bike.linear_velocity.length() < 0.2, "Motorcycle virtual rider must balance at rest")
	bike.set_controls(1.0, 0.0, 0.0)
	await _frames(480)
	print("BIKE throttle: speed=", bike.speed_kph, " up=", bike.basis.y)
	check(bike.speed_kph > 60.0 and bike.basis.y.dot(Vector3.UP) > 0.85, "Motorcycle must accelerate with stable pitch")
	bike.set_controls(0.35, 0.0, 0.45)
	await _frames(240)
	print("BIKE turn: x=", bike.position.x, " lean=", bike.lean_angle, " yaw=", bike.rotation.y, " speed=", bike.speed_kph, " steer=", bike.steer_angle)
	check(bike.position.x > 0.7 and bike.lean_angle > 0.10, "Motorcycle must turn and bank into a right bend")
	check(bike.grounded_wheels > 0 and bike.basis.y.dot(Vector3.UP) > 0.8, "Motorcycle balance must remain stable through a turn")
	bike.queue_free()
	await _frames(2)

func _check_slope() -> void:
	var surface: StaticBody3D = StaticBody3D.new()
	surface.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(10.0))), Vector3(0.0, 20.0, 0.0))
	surface.set_meta("surface", "concrete")
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60.0, 0.5, 180.0)
	collision.shape = box
	surface.add_child(collision)
	_world.add_child(surface)
	var car = Vehicle.new()
	car.configure({"mass_kg": 1450.0, "ride_height_m": 0.58})
	_world.add_child(car)
	car.reset_at(surface.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.83, 0.0)))
	car.set_controls(0.0, 1.0, 0.0)
	await _frames(360)
	print("SLOPE: wheels=", car.grounded_wheels, " alignment=", car.basis.y.dot(surface.basis.y), " speed=", car.speed_kph)
	check(car.grounded_wheels == 4, "All four suspension contacts must follow a sloped/banked road")
	check(car.basis.y.dot(surface.basis.y) > 0.97, "Chassis must follow the bank instead of global horizontal")
	check(car.linear_velocity.length() < 0.30, "Brakes must hold the car on an 8-degree grade")
	check(car.surface_name == "concrete", "Tyres must read the terrain surface metadata")
	car.queue_free()
	surface.queue_free()
	await _frames(2)
