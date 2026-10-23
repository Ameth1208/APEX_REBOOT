extends SceneTree
## Native contacts at 120 Hz: barriers stop the visible body, vehicles exchange impulse.

var _failures: Array[String] = []
var _world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id: String in ["porsche_992_gt3_rs_2024", "yamaha_yzf_2021"]:
		await _barrier(id, 55.0)
	await _pair("porsche_992_gt3_rs_2024", "ferrari_312t_1976", 40.0)
	await _pair("yamaha_yzf_2021", "porsche_992_gt3_rs_2024", 40.0)
	await _pair("porsche_992_gt3_rs_2024", "yamaha_yzf_2021", 40.0)
	await _pair("yamaha_yzf_2021", "yamaha_yzf_2021", 40.0)
	await _props()
	print("COLLISION_CHECKS ", "PASS" if _failures.is_empty() else str(_failures))
	quit(0 if _failures.is_empty() else 1)

func _barrier(id: String, initial_speed: float) -> void:
	_new_world()
	var track: CircuitTrack = CircuitTrack.new()
	_world.add_child(track)
	track.build({"name": "Prueba de impacto", "closed": false, "interpolation": "linear", "terrain_hills": 0.0,
		"points": [{"x": 0.0, "y": 0.0, "z": 0.0, "width": 14.0}, {"x": 0.0, "y": 0.0, "z": -160.0, "width": 14.0}]})
	var body: ApexVehicle = _vehicle(id, Vector3(0, 1.0, -80), -PI * 0.5)
	await _frames(240)
	_check(body.grounded_wheels == (2 if body.is_motorcycle else 4), id + " suspension contacts the road")
	_check(body.continuous_cd and body.collision_layer == 2 and body.collision_mask == 3, id + " CCD/layers include road and vehicles")
	body.linear_velocity = Vector3(initial_speed, 0, 0)
	var first_contact_x: float = INF
	var speed_after_contact: float = initial_speed
	var contact_frame: int = -1
	var tunneled: bool = false
	for frame: int in range(180):
		await physics_frame
		for collider: Node in body.get_colliding_bodies():
			if str(collider.name).begins_with("Guardrails") and contact_frame < 0:
				first_contact_x = body.position.x
				contact_frame = frame
		if contact_frame >= 0 and frame >= contact_frame + 5:
			speed_after_contact = minf(speed_after_contact, absf(body.linear_velocity.x))
		if body.position.x > 12.4 and body.position.y < 0.75:
			tunneled = true
		if frame > contact_frame + 25 and contact_frame >= 0:
			break
	var visible_front: float = float(body.profile.length_m) * 0.5
	_check(contact_frame >= 0, id + " contacts a real guardrail at 198 km/h")
	_check(first_contact_x <= 11.7 - visible_front + 0.25, id + " bumper contacts before visible body penetrates the barrier")
	_check(speed_after_contact < initial_speed * 0.75, id + " barrier produces a substantial reaction impulse")
	_check(not tunneled, id + " does not tunnel through the guardrail near ground level")
	print("BARRIER ", id, " first_x=", first_contact_x, " after_mps=", speed_after_contact, " tunneled=", tunneled)
	await _clear()

func _pair(moving_id: String, target_id: String, initial_speed: float) -> void:
	_new_world()
	_floor()
	var mover: ApexVehicle = _vehicle(moving_id, Vector3(0, 1.0, 0))
	var target: ApexVehicle = _vehicle(target_id, Vector3(0, 1.0, -20))
	await _frames(240)
	mover.linear_velocity = Vector3(0, 0, -initial_speed)
	var contact_separation: float = -1.0
	var contact_frame: int = -1
	var target_speed: float = 0.0
	var mover_speed: float = initial_speed
	for frame: int in range(180):
		await physics_frame
		if mover.get_colliding_bodies().has(target) and contact_frame < 0:
			contact_separation = absf(target.position.z - mover.position.z)
			contact_frame = frame
		if contact_frame >= 0:
			target_speed = maxf(target_speed, -target.linear_velocity.z)
			mover_speed = minf(mover_speed, absf(mover.linear_velocity.z))
		if contact_frame >= 0 and frame > contact_frame + 18:
			break
	var expected_gap: float = (float(mover.profile.length_m) + float(target.profile.length_m)) * 0.5
	_check(contact_frame >= 0, moving_id + " collides with " + target_id)
	_check(contact_separation >= expected_gap - 0.35, moving_id + "/" + target_id + " contact follows visible front/rear extents")
	_check(target_speed > 3.0 and mover_speed < initial_speed * 0.9, moving_id + "/" + target_id + " exchanges a native physics impulse")
	print("PAIR ", moving_id, " -> ", target_id, " separation=", contact_separation, " target_mps=", target_speed, " mover_mps=", mover_speed)
	await _clear()

func _props() -> void:
	_new_world()
	var track: CircuitTrack = CircuitTrack.new()
	_world.add_child(track)
	track.build({"name": "Obstáculos sólidos", "closed": false, "interpolation": "linear", "terrain_hills": 0.0,
		"points": [{"x": 0.0, "y": 0.0, "z": 0.0}, {"x": 0.0, "y": 50.0, "z": -180.0}]})
	var scenery: ApexScenery = ApexScenery.new()
	_world.add_child(scenery)
	await scenery.build(track)
	await _frames(2)
	for obstacle: Node in [track.get_node("TimingGateCollisions"), track.get_node("ViaductPillarCollisions"), scenery.get_node("LampPostCollisions"), scenery.get_node("TreeTrunkCollisions")]:
		var body: StaticBody3D = obstacle as StaticBody3D
		_check(body.get_child_count() > 0, str(body.name) + " contains collision shapes")
		if body.get_child_count() == 0:
			continue
		var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
		var center: Vector3 = shape.global_position
		var exclude: Array[RID] = []
		for other: Node in _world.find_children("*", "CollisionObject3D", true, false):
			if other != body:
				exclude.append(other.get_rid())
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(center + Vector3.RIGHT * 3.0, center - Vector3.RIGHT * 3.0, 1, exclude)
		var hit: Dictionary = _world.get_world_3d().direct_space_state.intersect_ray(ray)
		_check(hit.get("collider") == body, str(body.name) + " is a registered solid obstacle")
	print("SOLID_PROPS gate/pier/lamp/tree checked")
	await _clear()

func _new_world() -> void:
	_world = Node3D.new()
	root.add_child(_world)

func _vehicle(id: String, position: Vector3, yaw: float = 0.0) -> ApexVehicle:
	var body: ApexVehicle = ApexVehicle.new()
	body.configure(JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles/" + id + ".json")))
	body.contact_monitor = true
	body.max_contacts_reported = 16
	_world.add_child(body)
	body.reset_at(Transform3D(Basis(Vector3.UP, yaw), position))
	return body

func _floor() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 2
	floor_body.set_meta("surface", "asphalt")
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200, 1, 300)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	_world.add_child(floor_body)

func _frames(count: int) -> void:
	for _frame: int in range(count):
		await physics_frame

func _clear() -> void:
	_world.queue_free()
	await _frames(4)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)
