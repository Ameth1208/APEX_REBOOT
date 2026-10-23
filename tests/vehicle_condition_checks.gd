extends SceneTree
## Native wall impacts must change driving state; repair restores a real launch.

const Vehicle = preload("res://scripts/vehicles/vehicle_body.gd")
var _failures: Array[String] = []
var _world: Node3D
var _checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _scenario("porsche_992_gt3_rs_2024", 13.0, false)
	await _scenario("yamaha_yzf_2021", 24.0, true)
	var report: FileAccess = FileAccess.open("user://vehicle_condition_result.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": _checks, "failures": _failures}))
	report.close()
	print("VEHICLE_CONDITION_CHECKS ", "PASS" if _failures.is_empty() else str(_failures))
	quit(0 if _failures.is_empty() else 1)

func _scenario(id: String, speed: float, expect_fall: bool) -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_box("Floor", Vector3(100, 1, 180), Vector3(0, -0.5, -50))
	_box("Wall", Vector3(30, 3, 0.4), Vector3(0, 1.5, -12))
	var body = Vehicle.new()
	body.configure(JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles/" + id + ".json")))
	_world.add_child(body)
	body.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, body.ride_height, 0)))
	await _frames(180)
	var initial: Dictionary = body.telemetry()
	_check(is_zero_approx(float(initial.damage)), id + " settled without phantom damage")
	_check(body.can_drive() and not body.crashed, id + " can drive before impact")
	body.linear_velocity = Vector3(0, 0, -speed)
	var touched: bool = false
	for frame: int in 360:
		await physics_frame
		if int(body.telemetry().impact_serial) > 0:
			touched = true
			break
	var damaged: Dictionary = body.telemetry()
	_check(touched, id + " reports a native contact impulse")
	_check(float(damaged.damage) > 0.04, id + " impact changes damage state")
	_check(float(damaged.engine_health) < 0.97 and float(damaged.aero_health) < 0.97, id + " impact affects engine and aero")
	if expect_fall:
		_check(body.crashed and not body.can_drive(), id + " heavy impact disables rider balance and drive")
		body.set_controls(1, 0, 1)
		await _frames(180)
		_check(body.crashed and not body.can_drive(), id + " controls do not silently recover a fallen motorcycle")
		_check(absf(body.basis.y.dot(Vector3.UP)) < 0.8, id + " chassis actually falls instead of only setting a flag")
	else:
		_check(body.can_drive(), id + " moderate car impact remains driveable")
		_check(float(damaged.steering_health) < 0.97, id + " frontal impact damages steering")
	print("IMPACT ", id, " delta_v=", damaged.impact_delta_v, " damage=", damaged.damage, " crashed=", damaged.crashed)
	var last_impact: int = int(damaged.impact_serial)
	var reset_pose: Transform3D = Transform3D(Basis.IDENTITY, Vector3(20, body.ride_height, 0))
	body.reset_at(reset_pose)
	body.set_controls(1, 0, 0)
	await _frames(360)
	var repaired: Dictionary = body.telemetry()
	_check(is_zero_approx(float(repaired.damage)) and body.can_drive() and not body.crashed, id + " explicit reset repairs and restores balance")
	_check(body.speed_kph > 25.0, id + " repaired engine accelerates again")
	_check(int(repaired.impact_serial) == last_impact, id + " repair does not create a fake collision")
	print("REPAIRED ", id, " speed_kph=", body.speed_kph, " damage=", repaired.damage)
	_world.queue_free()
	await _frames(3)

func _box(label: String, size: Vector3, position: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("surface", "asphalt")
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = position
	_world.add_child(body)

func _frames(count: int) -> void:
	for _frame: int in count:
		await physics_frame

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)
