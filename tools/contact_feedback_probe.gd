extends SceneTree
## Native visual QA: actual rear-wheel lock, wall contact, physical fall and repair.

var _world: Node3D
var _body: ApexVehicle
var _camera: Camera3D
var _directory: String = "user://qa_contacts"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	_world = Node3D.new()
	root.add_child(_world)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.20, 0.26)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.72, 0.78, 0.86)
	environment.environment.ambient_light_energy = 0.65
	_world.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -25, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	_world.add_child(sun)
	_box("Floor", Vector3(100, 1, 180), Vector3(0, -0.5, -50), Color(0.29, 0.31, 0.33))
	_box("Wall", Vector3(25, 2.0, 0.4), Vector3(0, 1.0, -12), Color(0.43, 0.45, 0.47))
	_camera = Camera3D.new()
	_world.add_child(_camera)
	_camera.current = true
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles/yamaha_yzf_2021.json"))
	_body = ApexVehicleFactory.create(_world, profile, {"assists": "Expert"}, Transform3D(Basis.IDENTITY, Vector3(20, 0.64, 0)), "Original", "Moto QA")
	_camera.position = Vector3(25, 4, 2)
	_camera.look_at(Vector3(20, 0.6, -10))
	await _frames(100)
	_body.linear_velocity = Vector3(0, 0, -20)
	_body.set_controls(0, 0, 0, 1)
	await _frames(75)
	await _capture("rear_lock")
	print("TRAIL_INSTANCES ", _body.get_node("ContactFeedback/TyreMarks").multimesh.visible_instance_count)
	_body.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.64, 0)))
	_camera.position = Vector3(5, 3, -4)
	_camera.look_at(Vector3(0, 0.8, -10))
	await _frames(100)
	_body.linear_velocity = Vector3(0, 0, -24)
	for _i: int in 240:
		await physics_frame
		if _body.crashed:
			break
	await _frames(5)
	await _capture("impact")
	await _frames(115)
	await _capture("fallen")
	print("CONTACT_VISUAL_PROBE damage=", _body.telemetry().damage, " crashed=", _body.crashed, " alignment=", _body.basis.y.dot(Vector3.UP))
	quit()

func _physics_process(delta: float) -> bool:
	if is_instance_valid(_body):
		var visual = _body.get_node("Visual")
		visual.animate(_body.speed_kph / 3.6, _body.steer_angle, _body.lean_angle, delta)
		visual.sync_suspension(_body.wheel_contacts, delta)
	return false

func _box(label: String, size: Vector3, location: Vector3, color: Color) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("surface", "asphalt")
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = location
	_world.add_child(body)

func _frames(count: int) -> void:
	for _i: int in count:
		await physics_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory))
	root.get_texture().get_image().save_png(_directory.path_join(label + ".png"))
