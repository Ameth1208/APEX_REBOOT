class_name ApexTrackLighting
extends RefCounted

const Obstacles = preload("res://scripts/physics/static_obstacle_collision.gd")

static func build(parent: Node3D, track: Node3D, glow: StandardMaterial3D, with_lights: bool = true) -> Array[SpotLight3D]:
	var lights: Array[SpotLight3D] = []
	var metal: StandardMaterial3D = ApexMesh.material(Color("41474b"), 0.68, 0.45)
	var poles: StaticBody3D = Obstacles.group(parent, "LampPostCollisions")
	var space: PhysicsDirectSpaceState3D = parent.get_world_3d().direct_space_state
	var spacing: float = maxf(90.0, float(track.get_length()) / 120.0)
	for index: int in range(ceili(float(track.get_length()) / spacing)):
		var sample: Dictionary = track.sample_at(float(index) * spacing)
		var origin: Vector3 = sample.position + sample.right * (float(sample.width) * 0.5 + 6.5)
		var ground: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 12, origin - Vector3.UP * 12, 1))
		var base: float = origin.y
		if not ground.is_empty() and absf(float(ground.position.y) - origin.y) < 5.0:
			base = ground.position.y
		var height: float = origin.y + 9.0 - base
		var center: Vector3 = Vector3(origin.x, base + height * 0.5, origin.z)
		var pole_mesh: MeshInstance3D = ApexMesh.cylinder(parent, center, 0.11, height, metal)
		pole_mesh.set_meta("render_category", "lamps")
		Obstacles.cylinder(poles, Transform3D(Basis.IDENTITY, center), 0.12, height)
		var arm: MeshInstance3D = ApexMesh.box(parent, origin + Vector3.UP * 8.9 - sample.right * 1.5, Vector3(3.2, 0.12, 0.18), metal)
		arm.set_meta("render_category", "lamps")
		arm.basis = Basis(sample.right, Vector3.UP, -sample.forward).orthonormalized()
		var lamp_position: Vector3 = origin + Vector3.UP * 8.8 - sample.right * 2.8
		var lamp_mesh: MeshInstance3D = ApexMesh.box(parent, lamp_position, Vector3(0.9, 0.08, 0.42), glow)
		lamp_mesh.set_meta("render_category", "lamps")
		if with_lights:
			lights.append(_add_light(parent, lamp_position))
	return lights

static func build_lights(parent: Node3D, track: Node3D) -> Array[SpotLight3D]:
	var lights: Array[SpotLight3D] = []
	var spacing: float = maxf(90.0, float(track.get_length()) / 120.0)
	for index: int in range(ceili(float(track.get_length()) / spacing)):
		var sample: Dictionary = track.sample_at(float(index) * spacing)
		var origin: Vector3 = sample.position + sample.right * (float(sample.width) * 0.5 + 6.5)
		var lamp_position: Vector3 = origin + Vector3.UP * 8.8 - sample.right * 2.8
		lights.append(_add_light(parent, lamp_position))
	return lights

static func _add_light(parent: Node3D, lamp_position: Vector3) -> SpotLight3D:
	var light: SpotLight3D = SpotLight3D.new()
	light.position = lamp_position - Vector3.UP * 0.12
	light.rotation_degrees.x = -90.0
	light.light_color = Color("ffe0b1")
	light.light_energy = 7.0
	light.spot_range = 34.0
	light.spot_angle = 65.0
	light.spot_attenuation = 0.7
	light.visible = false
	light.set_meta("render_category", "lamps")
	parent.add_child(light)
	return light
