extends Node3D
## Original procedural rider. No third-party character mesh or bitmap is used.
## Dimensions fit the supplied R7-like motorcycle; profile offsets allow tuning.

var _upper_body: Node3D
var _upper_arms: Node3D
var _helmet: Node3D
var _suit: StandardMaterial3D
var _armour: StandardMaterial3D
var _accent: StandardMaterial3D

func configure(profile: Dictionary) -> void:
	_suit = _material(Color("#202631"), 0.0, 0.83)
	_armour = _material(Color("#353e4b"), 0.15, 0.43)
	_accent = _material(Color("#82c9dd"), 0.10, 0.48)
	var multiplier := float(profile.get("rider_scale", 1.0))
	scale = Vector3.ONE * multiplier
	var offset: Array = profile.get("rider_offset", [0.0, 0.0, 0.0])
	position = Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
	_upper_body = Node3D.new()
	_upper_body.name = "Torso"
	add_child(_upper_body)
	_upper_arms = Node3D.new()
	_upper_arms.name = "UpperArms"
	add_child(_upper_arms)
	_link(_upper_body, Vector3(0, 1.035, 0.31), Vector3(0, 1.27, -0.10), 0.14, _suit)
	_link(_upper_body, Vector3(-0.145, 1.245, -0.08), Vector3(0.145, 1.245, -0.08), 0.075, _suit)
	_link(_upper_body, Vector3(0, 1.25, -0.11), Vector3(0, 1.36, -0.19), 0.060, _suit)
	_link(self, Vector3(-0.105, 1.02, 0.32), Vector3(0.105, 1.02, 0.32), 0.10, _suit)
	for side in [-1.0, 1.0]:
		_limb(side)
	_make_helmet()

func set_cockpit_view(enabled: bool) -> void:
	_upper_body.visible = not enabled
	_upper_arms.visible = not enabled
	_helmet.visible = not enabled

func _limb(side: float) -> void:
	var shoulder := Vector3(side * 0.17, 1.25, -0.10)
	var elbow := Vector3(side * 0.30, 1.12, 0.015)
	var wrist := Vector3(side * 0.28, 1.005, -0.345)
	_link(_upper_arms, shoulder, elbow, 0.052, _suit)
	_link(self, elbow, wrist, 0.041, _suit)
	_ellipsoid(self, elbow, Vector3(0.063, 0.073, 0.065), _armour)
	_ellipsoid(self, wrist, Vector3(0.048, 0.041, 0.063), _suit)
	_ellipsoid(_upper_body, shoulder, Vector3(0.078, 0.045, 0.079), _accent)
	var hip := Vector3(side * 0.10, 1.015, 0.32)
	var knee := Vector3(side * 0.235, 0.70, -0.025)
	var ankle := Vector3(side * 0.245, 0.41, 0.39)
	_link(self, hip, knee, 0.075, _suit)
	_link(self, knee, ankle, 0.059, _suit)
	_ellipsoid(self, knee, Vector3(0.084, 0.089, 0.080), _armour)
	_link(self, ankle, Vector3(side * 0.23, 0.36, 0.21), 0.053, _armour)

func _make_helmet() -> void:
	_helmet = Node3D.new()
	_helmet.name = "Helmet"
	_helmet.position = Vector3(0, 1.43, -0.23)
	add_child(_helmet)
	var shell := _material(Color("#cfd7de"), 0.30, 0.22)
	_ellipsoid(_helmet, Vector3.ZERO, Vector3(0.164, 0.180, 0.178), shell)
	_ellipsoid(_helmet, Vector3(0, -0.105, -0.105), Vector3(0.13, 0.070, 0.107), shell)
	var visor := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in 9:
		var latitude := lerpf(-0.18, 0.39, float(row) / 8.0)
		for column in 25:
			var longitude := lerpf(-1.18, 1.18, float(column) / 24.0)
			var normal := Vector3(sin(longitude) * cos(latitude), sin(latitude), -cos(longitude) * cos(latitude))
			vertices.append(normal * Vector3(0.168, 0.184, 0.184))
			normals.append(normal)
	for row in 8:
		for column in 24:
			var i := row * 25 + column
			indices.append_array(PackedInt32Array([i, i + 25, i + 1, i + 1, i + 25, i + 26]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	visor.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var glass := _material(Color("#102131"), 0.48, 0.11)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.mesh = visor
	instance.material_override = glass
	_helmet.add_child(instance)

func _link(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = a.distance_to(b) + radius * 2.0
	capsule.radial_segments = 16
	capsule.rings = 6
	var instance := MeshInstance3D.new()
	instance.mesh = capsule
	instance.material_override = material
	instance.position = (a + b) * 0.5
	instance.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	parent.add_child(instance)

func _ellipsoid(parent: Node3D, center: Vector3, radii: Vector3, material: Material) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 28
	sphere.rings = 14
	var instance := MeshInstance3D.new()
	instance.mesh = sphere
	instance.material_override = material
	instance.position = center
	instance.scale = radii
	parent.add_child(instance)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
