extends SceneTree
## Nominal power, contact reach, and Formula suspension under real aero loading.

const Layout = preload("res://scripts/physics/wheel_layout.gd")
const Powertrain = preload("res://scripts/physics/powertrain.gd")
var _failures: Array[String] = []
var _checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles/senna_formula_1991.json"))
	var drive = Powertrain.new()
	drive.configure(profile)
	var power_kw: float = drive.torque_at(13500.0) * 13500.0 * TAU / 60.0 / 1000.0
	_check(absf(power_kw - float(profile.engine_power_kw)) < 0.1, "Honda nominal 13500 rpm power point is attainable")
	for rpm: int in range(3500, 14500, 100):
		_check(drive.torque_at(rpm) * rpm * TAU / 60.0 <= float(profile.engine_power_kw) * 1000.0 + 0.1, "Engine respects the nominal power ceiling")
	var offsets: Array[Vector3] = Layout.offsets(profile, false)
	_check(absf(offsets[1].x - offsets[0].x - 1.824) < 0.0001, "Honda front track is 1.824 m")
	_check(absf(offsets[3].x - offsets[2].x - 1.669) < 0.0001, "Honda rear track is 1.669 m")
	for direction: float in [-0.35, 0.35]:
		var a: float = Layout.steering(direction, offsets[0].x, float(profile.wheelbase_m))
		var b: float = Layout.steering(direction, offsets[1].x, float(profile.wheelbase_m))
		var radius_a: float = float(profile.wheelbase_m) / tan(a) + offsets[0].x
		var radius_b: float = float(profile.wheelbase_m) / tan(b) + offsets[1].x
		_check(absf(radius_a - radius_b) < 0.001, "Both steered tyres share one instantaneous turn centre")
	var floor_body: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(200, 1, 4000)
	collision.shape = shape
	floor_body.position = Vector3(0, -0.5, -1500)
	floor_body.add_child(collision)
	root.add_child(floor_body)
	var body: ApexVehicle = ApexVehicle.new()
	body.configure(profile)
	body.set_assist_mode("Expert")
	root.add_child(body)
	body.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, body.ride_height, 0)))
	await _frames(240)
	_check(body.grounded_wheels == 4 and absf(body.position.y - body.ride_height) < 0.02, "Formula settles on four tyres at its configured ride height")
	body.linear_velocity = Vector3(0, 0, -85)
	body.set_controls(1, 0, 0)
	var minimum_height: float = body.position.y
	var maximum_compression: float = 0.0
	var missing_contact_ticks: int = 0
	for i: int in 360:
		await physics_frame
		minimum_height = minf(minimum_height, body.position.y)
		if body.grounded_wheels != 4:
			missing_contact_ticks += 1
		for contact: Dictionary in body.wheel_contacts:
			maximum_compression = maxf(maximum_compression, float(contact.compression))
	_check(minimum_height > body.ride_height - 0.11, "Aero load does not force the chassis onto the road at 306 km/h")
	_check(maximum_compression < float(profile.suspension_travel_m), "High-speed spring compression stays within available travel")
	_check(missing_contact_ticks == 0, "All four tyres remain in contact during the high-speed check")
	_check(float(body.telemetry().damage) == 0.0, "No phantom impact damage during smooth high-speed driving")
	print("FORMULA_HIGH_SPEED min_height_m=", minimum_height, " max_compression_m=", maximum_compression, " final_kph=", body.speed_kph, " power_at_13500_kw=", power_kw)
	body.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, body.ride_height + Layout.sag(profile, false) + 0.025, 0)))
	await _frames(3)
	_check(body.grounded_wheels == 0, "Suspension does not report ground below the fully extended tyres")
	body.free()
	floor_body.free()
	print("FORMULA_HANDLING_CHECKS ", "PASS" if _failures.is_empty() else "FAIL", " ", _checks, " ", _failures)
	quit(0 if _failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		push_error(description)
