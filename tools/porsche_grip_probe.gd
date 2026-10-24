extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame

func _run() -> void:
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
	for variant: String in ["baseline", "full_inertia", "rear_com", "both"]:
		for steer: float in [0.15, 0.35]:
			var mode: String = "Sport"
			var throttle: float = 0.0
			var car := ApexVehicle.new()
			car.configure(profile)
			if variant in ["full_inertia", "both"]:
				car.inertia.y = car.mass * (pow(float(profile.length_m), 2.0) + pow(float(profile.body_width_m), 2.0)) / 12.0
			if variant in ["rear_com", "both"]:
				car.center_of_mass.z = float(profile.wheelbase_m) * (0.5 - float(profile.front_weight_fraction))
			car.set_assist_mode(mode)
			root.add_child(car)
			car.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, car.ride_height, 0)))
			await _frames(180)
			car.linear_velocity = Vector3(0, 0, -22.22)
			car.set_controls(throttle, 0, steer)
			var max_slip: float = 0.0
			var max_angle: float = 0.0
			var missing: int = 0
			for tick: int in 360:
				await physics_frame
				var forward: Vector3 = -car.global_basis.z
				var side: float = car.linear_velocity.dot(car.global_basis.x)
				var longitudinal: float = car.linear_velocity.dot(forward)
				max_angle = maxf(max_angle, absf(rad_to_deg(atan2(side, maxf(absf(longitudinal), 0.01)))))
				max_slip = maxf(max_slip, car.tire_slip)
				if car.grounded_wheels != 4:
					missing += 1
			print(JSON.stringify({"variant":variant,"mode":mode,"throttle":throttle,"steer":steer,"start_kph":80,"end_kph":car.speed_kph,"max_sideslip_deg":max_angle,"max_tyre_slip":max_slip,"missing_contact_ticks":missing,"yaw_deg":rad_to_deg(car.rotation.y),"aero_n":car.downforce_n,"yaw_inertia":car.inertia.y,"com_z":car.center_of_mass.z}))
			car.free()
			await _frames(2)
	floor_body.free()
	quit()
