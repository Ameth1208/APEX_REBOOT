class_name ApexTreeGeometry
extends RefCounted
## Seeded conifer geometry: a tapered trunk, visible branches and irregular crowns.
## Materials are embedded per surface; leave the MultiMesh material override empty.

const Foliage = preload("res://scripts/world/foliage_cluster.gd")

static func create(seed_value: int = 1291) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var wood: SurfaceTool = SurfaceTool.new()
	var leaves: SurfaceTool = SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height: float = rng.randf_range(8.6, 10.2)
	var lean: Vector3 = Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
	var bark: Color = Color("67523f")
	for section: int in range(5):
		var t0: float = float(section) / 5.0
		var t1: float = float(section + 1) / 5.0
		var a: Vector3 = Vector3.UP * height * t0 + lean * t0 * t0
		var b: Vector3 = Vector3.UP * height * t1 + lean * t1 * t1
		_tube(wood, a, b, lerpf(0.27, 0.025, t0), lerpf(0.27, 0.025, t1), bark * rng.randf_range(0.85, 1.08), 7)
	for level: int in range(7):
		var ratio: float = float(level) / 7.0
		var y: float = lerpf(2.1, height - 0.4, ratio) + rng.randf_range(-0.15, 0.15)
		var trunk: Vector3 = Vector3.UP * y + lean * pow(y / height, 2.0)
		var branch_count: int = 6 if level < 5 else 5
		for branch: int in range(branch_count):
			var angle: float = float(branch) / float(branch_count) * TAU + float(level) * 2.39996 + rng.randf_range(-0.19, 0.19)
			var direction: Vector3 = Vector3(cos(angle), 0, sin(angle))
			var length: float = lerpf(2.9, 0.5, ratio) * rng.randf_range(0.78, 1.13)
			var elbow: Vector3 = trunk + direction * length * 0.48 + Vector3.UP * 0.10
			var tip: Vector3 = trunk + direction * length - Vector3.UP * length * rng.randf_range(0.07, 0.18)
			_tube(wood, trunk, elbow, 0.055 * (1.0 - ratio * 0.6), 0.029, bark * 0.83, 4)
			_tube(wood, elbow, tip, 0.029, 0.008, bark * 0.78, 4)
			for bunch: int in range(3):
				var fraction: float = 0.30 + float(bunch) * 0.32
				var center: Vector3 = trunk.lerp(tip, fraction)
				center += Vector3(-direction.z, 0, direction.x) * rng.randf_range(-0.23, 0.23)
				var radius: float = lerpf(0.84, 0.25, ratio) * rng.randf_range(0.77, 1.15)
				var green: Color = Color("58774c").lerp(Color("82935b"), rng.randf_range(0.0, 0.28))
				_clump(leaves, center, radius, radius * rng.randf_range(0.95, 1.30), angle, green, rng)
	_clump(leaves, Vector3.UP * (height - 0.32) + lean, 0.4, 0.85, 0.0, Color("6d8855"), rng)
	var mesh: ArrayMesh = wood.commit()
	leaves.commit(mesh)
	mesh.surface_set_material(0, _material())
	mesh.surface_set_material(1, Foliage.material())
	return mesh

static func _tube(surface: SurfaceTool, a: Vector3, b: Vector3, bottom: float, top: float, color: Color, sides: int) -> void:
	var axis: Vector3 = (b - a).normalized()
	var right: Vector3 = axis.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.1:
		right = Vector3.RIGHT
	var forward: Vector3 = axis.cross(right).normalized()
	for index: int in range(sides):
		var angle0: float = float(index) / float(sides) * TAU
		var angle1: float = float(index + 1) / float(sides) * TAU
		var radial0: Vector3 = right * cos(angle0) + forward * sin(angle0)
		var radial1: Vector3 = right * cos(angle1) + forward * sin(angle1)
		var normal: Vector3 = (radial0 + radial1).normalized()
		var p0: Vector3 = a + radial0 * bottom
		var p1: Vector3 = a + radial1 * bottom
		var p2: Vector3 = b + radial1 * top
		var p3: Vector3 = b + radial0 * top
		_triangle(surface, p0, p1, p2, normal, color)
		_triangle(surface, p0, p2, p3, normal, color)

static func _clump(surface: SurfaceTool, center: Vector3, radius: float, height: float, _rotation: float, color: Color, rng: RandomNumberGenerator) -> void:
	Foliage.add(surface, center, Vector3(radius, height, radius), color, rng, true)

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3,
		color: Color, center: Vector3 = Vector3.ZERO, smooth: bool = false) -> void:
	var vertices: PackedVector3Array = PackedVector3Array([a, c, b]) if (b - a).cross(c - a).dot(normal) > 0.0 else PackedVector3Array([a, b, c])
	for vertex: Vector3 in vertices:
		surface.set_color(color.srgb_to_linear())
		surface.set_normal(((vertex - center) * Vector3(1, 2, 1)).normalized() if smooth else normal)
		surface.add_vertex(vertex)

static func _material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
