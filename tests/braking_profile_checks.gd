extends SceneTree
## Actual flat-road braking, plus catalogue/axle capacity contracts.
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var capacities: Dictionary = {}
	for path: String in ApexCatalog.entries("vehicles"):
		var profile := ApexCatalog.read_json(path)
		var spec := ApexVehicleSpec.from_dictionary(profile)
		check(is_equal_approx(spec.powertrain.brake_force_total_n, float(profile.brake_force_n)), str(profile.id) + " uses its own brake capacity")
		capacities[spec.powertrain.brake_force_total_n] = true
	check(capacities.size() == 8, "The eight vehicle profiles have distinct brake capacities")
	var axle_spec := ApexEngineSpec.from_dictionary({"front_brake_force_n": 9000.0, "rear_brake_force_n": 3000.0}, false, 1000)
	check(axle_spec.brake_force_total_n == 12000 and axle_spec.front_brake_bias == 0.75, "Explicit axle capacities preserve total force and distribution")
	var floor_body := StaticBody3D.new()
	floor_body.set_meta("surface", "asphalt")
	floor_body.set_meta("is_road", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2000, 1, 2000)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var profile := ApexCatalog.read_json("res://data/vehicles/kia_picanto_2024.json")
	var strong: float = await _stop(profile, 14000.0)
	var weak: float = await _stop(profile, 1800.0)
	check(weak > strong * 1.5, "Physical stopping distance changes with brake hardware, not just metadata")
	print("BRAKING_PROFILE_CHECKS ", "PASS" if failures.is_empty() else "FAIL", " strong_stop_m=", strong, " weak_distance_m=", weak, " ", failures)
	quit(0 if failures.is_empty() else 1)

func _stop(source: Dictionary, capacity: float) -> float:
	var profile: Dictionary = source.duplicate(true)
	profile["brake_force_n"] = capacity
	var vehicle := ApexVehicle.new()
	vehicle.configure(profile)
	vehicle.set_assist_mode("Sport")
	root.add_child(vehicle)
	vehicle.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)))
	for i: int in 240: await physics_frame
	vehicle.linear_velocity = Vector3(0, 0, -80.0 / 3.6)
	vehicle.set_controls(0, 1, 0)
	var start: Vector3 = vehicle.position
	for i: int in 1800:
		await physics_frame
		if vehicle.speed_kph < 1.0: break
	var distance: float = Vector2(vehicle.position.x - start.x, vehicle.position.z - start.z).length()
	check(vehicle.grounded_wheels == 4, "Brake comparison stays on the road")
	vehicle.free()
	await physics_frame
	return distance
