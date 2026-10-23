class_name TrackMeshBuffer
extends RefCounted

var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var uvs: PackedVector2Array = PackedVector2Array()
var road_uvs: PackedVector2Array = PackedVector2Array()
var indices: PackedInt32Array = PackedInt32Array()

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3 = Vector3.UP,
		strip_uvs: PackedVector2Array = PackedVector2Array()) -> void:
	var offset: int = vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c, d]))
	normals.append_array(PackedVector3Array([normal, normal, normal, normal]))
	uvs.append_array(PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), Vector2(d.x, d.z)]))
	road_uvs.append_array(strip_uvs if strip_uvs.size() == 4 else PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
	# A concave road join can require the other diagonal. Each face must still
	# face its own supplied normal; inheriting the first face's winding left holes.
	var ac: float = (b - a).cross(c - a).dot(normal) * (c - a).cross(d - a).dot(normal)
	var bd: float = (b - a).cross(d - a).dot(normal) * (c - b).cross(d - b).dot(normal)
	if ac < 0.0 and bd > 0.0:
		_triangle(offset, offset + 1, offset + 3, normal)
		_triangle(offset + 1, offset + 2, offset + 3, normal)
	else:
		_triangle(offset, offset + 1, offset + 2, normal)
		_triangle(offset, offset + 2, offset + 3, normal)

func _triangle(a: int, b: int, c: int, normal: Vector3) -> void:
	var signed_area: float = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(normal)
	if absf(signed_area) > 0.00000001:
		indices.append_array(PackedInt32Array([a, c, b] if signed_area > 0.0 else [a, b, c]))

func mesh() -> ArrayMesh:
	var result: ArrayMesh = ArrayMesh.new()
	if vertices.is_empty():
		return result
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = road_uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func attach(parent: Node3D, title: String, material: Material, surface: String = "", road: bool = false,
		chunk_m: float = 0.0) -> MeshInstance3D:
	var chunks: Array[TrackMeshBuffer] = [self]
	if chunk_m > 0.0:
		chunks = _chunks(chunk_m)
	var instance: MeshInstance3D
	for i: int in range(chunks.size()):
		var part: MeshInstance3D = _attach_mesh(parent, title if i == 0 else title + "Part" + str(i), material, chunks[i].mesh())
		part.set_meta("track_mesh_group", title)
		if i == 0:
			instance = part
	if not surface.is_empty() and not indices.is_empty():
		var body: StaticBody3D = StaticBody3D.new()
		body.name = title + "Collision"
		body.collision_layer = 1
		body.collision_mask = 2
		body.set_meta("surface", surface)
		body.set_meta("is_road", road)
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		var faces: PackedVector3Array = PackedVector3Array()
		faces.resize(indices.size())
		for i: int in range(indices.size()):
			faces[i] = vertices[indices[i]]
		shape.set_faces(faces)
		shape.backface_collision = true
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)
	return instance

func _attach_mesh(parent: Node3D, title: String, material: Material, geometry: Mesh) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = title
	instance.mesh = geometry
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _chunks(size_m: float) -> Array[TrackMeshBuffer]:
	if vertices.size() < 64:
		return [self]
	var groups: Dictionary = {}
	for i: int in range(0, vertices.size(), 4):
		var center: Vector3 = (vertices[i] + vertices[i + 1] + vertices[i + 2] + vertices[i + 3]) * 0.25
		var key: Vector2i = Vector2i(floori(center.x / size_m), floori(center.z / size_m))
		if not groups.has(key):
			groups[key] = TrackMeshBuffer.new()
		var part: TrackMeshBuffer = groups[key]
		part.quad(vertices[i], vertices[i + 1], vertices[i + 2], vertices[i + 3], normals[i], road_uvs.slice(i, i + 4))
	var result: Array[TrackMeshBuffer] = []
	for key: Vector2i in groups:
		result.append(groups[key])
	return result
