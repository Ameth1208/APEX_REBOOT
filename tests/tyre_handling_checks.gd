extends SceneTree
## Tyre parameters must affect forces, and the stock Porsche must corner stably.

const Tyres = preload("res://scripts/physics/tyre_forces.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame

func _run() -> void:
	var contact := {"normal": Vector3.UP, "velocity": Vector3(0.1, 0, -25),
		"load": 4000.0, "corner_mass": 400.0, "surface": "asphalt", "reference_load_n": 4000.0,
		"cornering_stiffness": 8.0}
	var soft: Dictionary = Tyres.solve(contact, Vector3.FORWARD, 0, 0, 1.0, false, false, 1.0 / 120.0)
	contact.cornering_stiffness = 24.0
	var stiff: Dictionary = Tyres.solve(contact, Vector3.FORWARD, 0, 0, 1.0, false, false, 1.0 / 120.0)
	check(absf(stiff.force.x) > absf(soft.force.x) * 2.0, "Cornering stiffness must affect lateral force")
	contact.velocity = Vector3(10, 0, -25)
	var combined: Dictionary = Tyres.solve(contact, Vector3.FORWARD, 9000, 3000, 1.0, false, false, 1.0 / 120.0)
	check(Vector3(combined.force).length() <= 4000.01, "Acceleration and cornering must share one friction budget")
	var wet: Dictionary = Tyres.solve(contact, Vector3.FORWARD, 9000, 3000, 0.6, false, false, 1.0 / 120.0)
	check(Vector3(wet.force).length() < Vector3(combined.force).length(), "Lower surface friction must reduce tyre forces")
	contact.load = 0.0
	var airborne: Dictionary = Tyres.solve(contact, Vector3.FORWARD, 9000, 3000, 1.0, false, false, 1.0 / 120.0)
	check(Vector3(airborne.force).is_zero_approx(), "An unloaded tyre must generate no traction")
	var floor_body := StaticBody3D.new()
	floor_body.set_meta("surface", "asphalt")
	floor_body.set_meta("is_road", true)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4000, 1, 4000)
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	var profile: Dictionary = ApexCatalog.read_json("res://data/vehicles/porsche_992_gt3_rs_2024.json")
	for steer: float in [0.15, 0.35]:
		var car := ApexVehicle.new()
		car.configure(profile)
		car.set_assist_mode("Sport")
		root.add_child(car)
		car.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, car.ride_height, 0)))
		await _frames(180)
		car.linear_velocity = Vector3(0, 0, -22.22)
		car.set_controls(0, 0, steer)
		var max_slip: float = 0.0
		var missing: int = 0
		for tick: int in 360:
			await physics_frame
			var side: float = car.linear_velocity.dot(car.global_basis.x)
			var longitudinal: float = car.linear_velocity.dot(-car.global_basis.z)
			max_slip = maxf(max_slip, absf(rad_to_deg(atan2(side, maxf(absf(longitudinal), 0.01)))))
			if car.grounded_wheels != 4:
				missing += 1
		check(max_slip < 10.0, "Porsche at 80 km/h must not spin during a controlled coasting turn")
		check(missing == 0 and car.telemetry().damage == 0.0, "Porsche cornering must retain real contact without chassis impacts")
		car.tyre_temperatures_c[0] = 150.0
		await _frames(2)
		check(car.tyre_temperatures_c[0] > 140 and car.tyre_temperatures_c[1] < 60, "Tyre temperatures must remain independent")
		print("PORSCHE_TYRES steer=", steer, " max_sideslip_deg=", max_slip, " contacts_lost=", missing)
		car.free()
		await _frames(2)
	floor_body.free()
	print("TYRE_HANDLING_CHECKS ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
