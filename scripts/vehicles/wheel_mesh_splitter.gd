extends RefCounted
## Split axle-wide static tyre/rim meshes without losing UVs, normals or materials.
## This changes the runtime scene only; original source GLB stays byte-identical.

static func split(root: Node, names: Array) -> void:
	if names.is_empty():
		return
	var sources: Array[MeshInstance3D] = []
	_collect(root, names, sources)
	for source in sources:
		var space := _relative_transform(source, root)
		var center: float = (space * source.mesh.get_aabb().get_center()).x
		for side in [-1, 1]:
			var mesh := ArrayMesh.new()
			for surface in source.mesh.get_surface_count():
				var arrays: Array = source.mesh.surface_get_arrays(surface)
				var compact: Array = _half(arrays, space, center, side)
				if compact.is_empty():
					continue
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, compact)
				mesh.surface_set_material(mesh.get_surface_count() - 1, source.get_active_material(surface))
			if mesh.get_surface_count() == 0:
				continue
			var part := MeshInstance3D.new()
			part.name = str(source.name) + ("_Left" if side < 0 else "_Right")
			part.mesh = mesh
			part.transform = source.transform
			part.cast_shadow = source.cast_shadow
			source.get_parent().add_child(part)
		source.get_parent().remove_child(source)
		source.queue_free()

static func _collect(root: Node, names: Array, result: Array[MeshInstance3D]) -> void:
	if root is MeshInstance3D and root.mesh and not root.skin and str(root.name) in names:
		result.append(root)
	for child in root.get_children():
		_collect(child, names, result)

static func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != root and parent is Node3D:
		result = parent.transform * result
		parent = parent.get_parent()
	return result

static func _half(arrays: Array, space: Transform3D, center: float, side: int) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():
			indices.append(i)
	var remap: Dictionary = {}
	var selected: Array[int] = []
	var new_indices := PackedInt32Array()
	for triangle in range(0, indices.size() - 2, 3):
		var a: int = indices[triangle]
		var b: int = indices[triangle + 1]
		var c: int = indices[triangle + 2]
		var x: float = (space * ((vertices[a] + vertices[b] + vertices[c]) / 3.0)).x
		if (x - center) * side < 0.0:
			continue
		for old_index in [a, b, c]:
			if not remap.has(old_index):
				remap[old_index] = selected.size()
				selected.append(old_index)
			new_indices.append(remap[old_index])
	if new_indices.is_empty():
		return []
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	for slot in Mesh.ARRAY_MAX:
		if slot == Mesh.ARRAY_INDEX or arrays[slot] == null:
			continue
		var original: Variant = arrays[slot]
		if original.size() == 0:
			continue
		var stride: int = original.size() / vertices.size()
		if stride < 1:
			continue
		var values: Variant = original.duplicate()
		values.clear()
		for old_index in selected:
			for component in stride:
				values.append(original[old_index * stride + component])
		result[slot] = values
	result[Mesh.ARRAY_INDEX] = new_indices
	return result
