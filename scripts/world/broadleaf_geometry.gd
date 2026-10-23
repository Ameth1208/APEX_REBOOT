class_name ApexBroadleafGeometry
extends RefCounted
## Dense, irregular broadleaf canopy, sharing one mesh per seeded variant.

const Foliage = preload("res://scripts/world/foliage_cluster.gd")

static func create(seed_value: int = 71) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var wood: SurfaceTool = SurfaceTool.new()
	var foliage: SurfaceTool = SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	foliage.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height: float = rng.randf_range(6.2, 8.5)
	var bend: Vector3 = Vector3(rng.randf_range(-0.5, 0.5), height * 0.65, rng.randf_range(-0.4, 0.4))
	ApexTreeGeometry._tube(wood, Vector3.ZERO, bend, 0.28, 0.12, Color("4d4235"), 7)
	for branch: int in range(11):
		var angle: float = float(branch) * 2.39996 + rng.randf_range(-0.2, 0.2)
		var level: float = rng.randf_range(0.50, 0.90)
		var reach: float = rng.randf_range(1.3, 2.8) * (1.3 - level * 0.45)
		var start: Vector3 = bend * rng.randf_range(0.55, 0.95)
		var center: Vector3 = Vector3(cos(angle) * reach, height * level, sin(angle) * reach)
		ApexTreeGeometry._tube(wood, start, center, 0.11, 0.025, Color("504635"), 5)
		for lobe: int in range(5):
			var spread: float = float(lobe) * 2.39996 + angle
			var offset: Vector3 = Vector3(cos(spread), rng.randf_range(-0.5, 0.5), sin(spread)) * rng.randf_range(0.6, 1.2)
			_canopy(foliage, center + offset, Vector3(rng.randf_range(0.72, 1.05), rng.randf_range(0.65, 1.0), rng.randf_range(0.72, 1.05)), rng)
	_canopy(foliage, Vector3(0.1, height, -0.1), Vector3(1.25, 1.15, 1.25), rng)
	var mesh: ArrayMesh = wood.commit()
	foliage.commit(mesh)
	mesh.surface_set_material(0, ApexTreeGeometry._material())
	mesh.surface_set_material(1, Foliage.material())
	return mesh

static func _canopy(surface: SurfaceTool, center: Vector3, scale: Vector3, rng: RandomNumberGenerator) -> void:
	var green: Color = Color("6f8849").lerp(Color("91a560"), rng.randf_range(0.0, 0.40))
	Foliage.add(surface, center, scale, green, rng)
