class_name ApexGroundCover
extends RefCounted
## Decorative blades have no collision; the existing terrain remains authoritative.

static func build(parent: Node3D, track: Node3D) -> void:
	if str(track.definition.get("terrain_surface", "grass")) not in ["grass", "dirt"]:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(track.definition.get("seed", 1291)) + 420
	var poses: Array[Transform3D] = []
	var space: PhysicsDirectSpaceState3D = parent.get_world_3d().direct_space_state
	var spacing: float = maxf(4.5, float(track.get_length()) / 650.0)
	for index: int in range(ceili(float(track.get_length()) / spacing)):
		var sample: Dictionary = track.sample_at(float(index) * spacing)
		for side: float in [-1.0, 1.0]:
			var offset: float = float(sample.width) * 0.5 + float(track.definition.runoff_width) + rng.randf_range(1.6, 12.0)
			var position: Vector3 = sample.position + sample.right * side * offset + sample.forward * rng.randf_range(-2.0, 2.0)
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(position + Vector3.UP * 30.0, position - Vector3.UP * 90.0, 1))
			if hit.is_empty() or hit.collider.get_meta("is_road", false) or hit.collider.get_meta("obstacle", false):
				continue
			if str(hit.collider.get_meta("surface", "")) not in ["grass", "dirt"]:
				continue
			var scale: float = rng.randf_range(0.65, 1.3)
			var basis: Basis = Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(scale, scale, scale))
			poses.append(Transform3D(basis, hit.position - Vector3.UP * 0.015))
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://shaders/foliage.gdshader")
	material.set_shader_parameter("wind_strength", 0.055)
	material.set_shader_parameter("root_height", 0.0)
	material.set_shader_parameter("bend_range", 0.8)
	ApexSceneryInstances.build(parent, "VergeGrass", _mesh(), material, poses, 210.0, false)

static func _mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 811
	for blade: int in range(9):
		var angle: float = rng.randf_range(0, TAU)
		var root: Vector3 = Vector3(rng.randf_range(-0.34, 0.34), 0.0, rng.randf_range(-0.34, 0.34))
		var right: Vector3 = Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.025, 0.05)
		var height: float = rng.randf_range(0.25, 0.58)
		var tip: Vector3 = root + Vector3.UP * height + right * 2.5
		var normal: Vector3 = Vector3(-right.z, 0.25, right.x).normalized()
		var color: Color = Color("505b2e").lerp(Color("7b7847"), rng.randf() * 0.5)
		ApexTreeGeometry._triangle(surface, root - right, root + right, tip, normal, color)
	return surface.commit()
