class_name ApexForest
extends RefCounted

const Obstacles = preload("res://scripts/physics/static_obstacle_collision.gd")

static func build(parent: Node3D, track: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(track.definition.get("seed", 1291))
	var groups: Array = [[], [], [], []]
	var trunks: StaticBody3D = Obstacles.group(parent, "TreeTrunkCollisions", "dirt")
	var space: PhysicsDirectSpaceState3D = parent.get_world_3d().direct_space_state
	var spacing: float = maxf(28.0, float(track.get_length()) / 170.0)
	for index: int in range(ceili(float(track.get_length()) / spacing)):
		var sample: Dictionary = track.sample_at(float(index) * spacing)
		var clear_edge: float = float(sample.width) * 0.5 + float(track.definition.runoff_width) + 8.0
		for side: float in [-1.0, 1.0]:
			var distance: float = clear_edge + pow(rng.randf(), 1.45) * 110.0
			var position: Vector3 = sample.position + sample.right * side * distance
			position += sample.forward * rng.randf_range(-11.0, 11.0)
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(position + Vector3.UP * 300.0, position - Vector3.UP * 500.0, 1))
			if hit.is_empty() or hit.collider.get_meta("is_road", false) or hit.collider.get_meta("obstacle", false):
				continue
			if float(hit.normal.y) < 0.70:
				continue
			var scale: float = rng.randf_range(0.78, 1.45)
			var basis: Basis = Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(scale, scale * rng.randf_range(0.91, 1.13), scale))
			var pose: Transform3D = Transform3D(basis, hit.position - Vector3.UP * 0.04)
			var variant: int = rng.randi_range(0, 3)
			groups[variant].append(pose)
			Obstacles.cylinder(trunks, pose.translated_local(Vector3(0, 3.8, 0)), 0.28, 7.6)
	for variant: int in range(4):
		var transforms: Array[Transform3D] = []
		transforms.assign(groups[variant])
		var mesh: ArrayMesh = ApexBroadleafGeometry.create(71 + variant * 37) if variant < 2 else ApexTreeGeometry.create(13 + variant * 19)
		ApexSceneryInstances.build(parent, "BroadleafTrees" if variant < 2 else "ConiferTrees", mesh, null, transforms, 460.0)
