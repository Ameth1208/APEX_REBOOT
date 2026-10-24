extends RefCounted
## Batch only rigid, opaque body parts after animated wheels have been detached.
## Material identity is retained so paint/liveries stay instance-local and editable.

static var _cache: Dictionary = {}
static var _cached_model_path: String = ""

static func apply(root: Node3D, model_path: String) -> void:
	if _cached_model_path != model_path:
		_cache.clear()
		_cached_model_path = model_path
	var groups: Dictionary = {}
	for child: Node in root.get_children():
		if child is Node3D:
			_collect(child, Transform3D.IDENTITY, groups)
	for key: String in groups:
		var entries: Array = groups[key]
		if entries.size() < 2:
			continue
		var cache_key: String = model_path + ":" + key
		var geometry: ArrayMesh = _cache.get(cache_key)
		if geometry == null:
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			for entry: Dictionary in entries:
				builder.append_from(entry.node.mesh, 0, entry.transform)
			builder.set_material(entries[0].material)
			geometry = builder.commit()
			var lod_mesh := ImporterMesh.new()
			lod_mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES, geometry.surface_get_arrays(0), [], {}, entries[0].material, "", geometry.surface_get_format(0))
			lod_mesh.generate_lods(60.0, 25.0, [])
			geometry = lod_mesh.get_mesh()
			_cache[cache_key] = geometry
		var batch := MeshInstance3D.new()
		batch.name = "BodyBatch"
		batch.mesh = geometry
		batch.lod_bias = 0.6
		batch.cast_shadow = entries[0].node.cast_shadow
		batch.layers = entries[0].node.layers
		# Dense panels retain their imported LODs; small merged parts get new LODs once.
		root.add_child(batch)
		for entry: Dictionary in entries:
			entry.node.mesh = null

static func _collect(node: Node3D, parent: Transform3D, groups: Dictionary) -> void:
	if not node.visible:
		return
	var pose: Transform3D = parent * node.transform
	if node is MeshInstance3D and node.mesh is ArrayMesh and node.skin == null:
		var mesh: ArrayMesh = node.mesh
		# Dense imported meshes already have useful LODs; batching would discard them.
		if mesh.get_surface_count() == 1 and mesh.get_blend_shape_count() == 0 and pose.basis.determinant() > 0.0 and mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES:
			var material := node.get_active_material(0) as BaseMaterial3D
			var arrays: Array = mesh.surface_get_arrays(0)
			var count: int = arrays[Mesh.ARRAY_VERTEX].size()
			if material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and count < 3000:
				var key: String = str(material.get_instance_id()) + ":" + str(mesh.surface_get_format(0)) + ":" + str(node.cast_shadow) + ":" + str(node.layers)
				if not groups.has(key):
					groups[key] = []
				groups[key].append({"node": node, "transform": pose, "material": material})
	for child: Node in node.get_children():
		if child is Node3D:
			_collect(child, pose, groups)
