extends SceneTree
## Validates 3D wake geometry, bounded shared coefficients and a physical coast test.

const Vehicle = preload("res://scripts/vehicles/vehicle_body.gd")
const Wake = preload("res://scripts/physics/aero_wake.gd")
var _failures: Array[String] = []
var _world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _body(profile: Dictionary, position: Vector3, frozen: bool = true) -> RigidBody3D:
	var body = Vehicle.new()
	body.configure(profile)
	body.freeze = frozen
	_world.add_child(body)
	body.position = position
	body.linear_velocity = Vector3.FORWARD * 30.0
	return body

func _run() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_check_geometry()
	await _physical_coast()
	print("AERO WAKE CHECKS: ", "PASS" if _failures.is_empty() else "FAIL " + str(_failures))
	_world.queue_free()
	await physics_frame
	quit(0 if _failures.is_empty() else 1)

func _check_geometry() -> void:
	var leader: RigidBody3D = _body({"body_width_m": 1.85}, Vector3(0.0, 0.58, -20.0))
	var follower: RigidBody3D = _body({"downforce_area_m2": 2.65}, Vector3(0.0, 0.58, 0.0))
	var centered: float = Wake.strength_between(follower, leader)
	check(centered > 0.6, "A same-direction leader 20m ahead must create a wake")
	follower.wetness = 1.0
	check(is_equal_approx(centered, Wake.strength_between(follower, leader)), "Surface wetness must not invent or remove an aerodynamic wake")
	follower.position.x = 8.0
	check(is_zero_approx(Wake.strength_between(follower, leader)), "A car outside the wake cone must not draft")
	follower.position = Vector3(0.0, 9.0, 0.0)
	check(is_zero_approx(Wake.strength_between(follower, leader)), "A vehicle on an overpass must not draft the road below")
	follower.position = Vector3(0.0, 0.58, -35.0)
	check(is_zero_approx(Wake.strength_between(follower, leader)), "A vehicle ahead cannot draft the vehicle behind")
	follower.position = Vector3(0.0, 0.58, 0.0)
	follower.rotation.y = PI
	check(is_zero_approx(Wake.strength_between(follower, leader)), "Opposite body directions must not produce a wake")
	follower.rotation.y = 0.0
	follower.linear_velocity = Vector3.BACK * 30.0
	check(is_zero_approx(Wake.strength_between(follower, leader)), "A reversing vehicle cannot receive a forward wake")
	follower.linear_velocity = Vector3.FORWARD * 30.0
	var wake = Wake.new()
	wake.update([follower, leader], 1.0)
	var one_leader: float = follower.drag_multiplier
	check(one_leader < 1.0 and follower.downforce_multiplier < 1.0, "Wake must reduce drag and model-specific downforce")
	follower.draft_strength = 0.0
	wake.update([follower, leader, leader], 1.0)
	check(is_equal_approx(one_leader, follower.drag_multiplier), "Multiple wakes must not stack unbounded aerodynamic gains")
	var bike: RigidBody3D = _body({"kind": "motorcycle", "downforce_area_m2": 0.0}, follower.position)
	wake.update([bike, leader], 1.0)
	check(bike.drag_multiplier < 1.0, "Motorcycles must receive the same physical drafting mechanism")
	check(is_equal_approx(bike.downforce_multiplier, 1.0), "A motorcycle without aero downforce must not lose fictional downforce")
	print("WAKE coefficients: strength=", centered, " drag=", follower.drag_multiplier, " downforce=", follower.downforce_multiplier, " bike_drag=", bike.drag_multiplier)
	leader.queue_free()
	follower.queue_free()
	bike.queue_free()

func _physical_coast() -> void:
	await physics_frame
	var floor_body: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(500.0, 1.0, 1000.0)
	collision.shape = box
	collision.position.y = -0.5
	floor_body.add_child(collision)
	_world.add_child(floor_body)
	var profile: Dictionary = {"mass_kg": 1450.0, "engine_torque_nm": 0.0, "downforce_area_m2": 0.0, "ride_height_m": 0.58, "body_width_m": 1.85}
	var leader: RigidBody3D = _body(profile, Vector3(0.0, 0.58, -22.0), false)
	var follower: RigidBody3D = _body(profile, Vector3(0.0, 0.58, 0.0), false)
	var reference: RigidBody3D = _body(profile, Vector3(40.0, 0.58, 0.0), false)
	var vehicles: Array = [leader, follower, reference]
	for body: RigidBody3D in vehicles:
		body.linear_velocity = Vector3.ZERO
	for _frame: int in 240:
		await physics_frame
	for body: RigidBody3D in vehicles:
		body.linear_velocity = Vector3.FORWARD * 35.0
		body.set_controls(0.0, 0.0, 0.0)
	var wake = Wake.new()
	for _frame: int in 600:
		wake.update(vehicles, 1.0 / 120.0)
		await physics_frame
	var advantage_kph: float = float(follower.speed_kph) - float(reference.speed_kph)
	print("WAKE physical coast5s: follower=", follower.speed_kph, " isolated=", reference.speed_kph, " advantage_kph=", advantage_kph)
	check(advantage_kph > 0.3, "Reduced aero drag must change physical coast speed with identical pedal inputs")
	check(is_equal_approx(reference.drag_multiplier, 1.0), "The isolated reference vehicle must receive no wake gain")
