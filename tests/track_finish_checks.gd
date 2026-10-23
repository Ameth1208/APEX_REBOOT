extends SceneTree
## Spatial render budgets, winding at tight joins and physical kerb contacts.
## Optional first user argument: a native APEX track JSON to include in the check.

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_join_faces()
	var source: Dictionary = {"closed": true, "interpolation": "linear", "terrain_hills": 0.0,
		"points": [{"x": 0.0, "y": 0.0, "z": 0.0}, {"x": 5200.0, "y": 0.0, "z": 0.0},
			{"x": 5200.0, "y": 0.0, "z": 1800.0}, {"x": 0.0, "y": 0.0, "z": 1800.0}]}
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.is_empty():
		source = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	var original: Dictionary = source.duplicate(true)
	var track: CircuitTrack = CircuitTrack.new()
	root.add_child(track)
	var started: int = Time.get_ticks_msec()
	track.build(source)
	_check(track.build_error.is_empty(), "long route builds")
	if not track.build_error.is_empty():
		quit(1)
		return
	_check(source == original, "render finish preserves original data and editable geometry")
	var parts: Array[MeshInstance3D] = _group(track, "Road_asphalt")
	_check(parts.size() > 10, "long road is partitioned for frustum culling")
	var max_extent: float = 0.0
	var road_faces: int = 0
	var road_uv_coverage: bool = false
	for part: MeshInstance3D in parts:
		var bounds: AABB = part.mesh.get_aabb()
		max_extent = maxf(max_extent, maxf(bounds.size.x, bounds.size.z))
		var arrays: Array = part.mesh.surface_get_arrays(0)
		road_faces += PackedInt32Array(arrays[Mesh.ARRAY_INDEX]).size() / 3
		var strip: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		for value: Vector2 in strip:
			if value.y > 100.0:
				road_uv_coverage = true
				break
		_check(_bad_winding(part.mesh) == 0, "all triangles face their declared surface normal")
	_check(max_extent < 400.0, "no road render mesh retains the whole route AABB")
	_check(road_uv_coverage, "longitudinal UVs retain metre distance through chunking")
	var collider: StaticBody3D = track.get_node("Road_asphaltCollision")
	var shape: ConcavePolygonShape3D = collider.get_child(0).shape
	_check(shape.get_faces().size() == road_faces * 3, "collider and all rendered road chunks contain the same faces")
	_check(track.has_node("CurbsCollision"), "bevelled kerbs are physical concrete")
	_check(track.get_node("CurbsCollision").get_meta("surface") == "concrete", "kerbs use concrete friction")
	var a: ShaderMaterial = TrackMaterials.ground("asphalt", true)
	var b: ShaderMaterial = TrackMaterials.ground("grass")
	_check(a.get_shader_parameter("surface_detail") == b.get_shader_parameter("surface_detail"), "surface detail is shared rather than regenerated per chunk")
	TrackMaterials.set_wetness(0.7)
	var curb: MeshInstance3D = _group(track, "Curbs")[0]
	_check(is_equal_approx(float(curb.material_override.get_shader_parameter("wetness")), 0.7), "wetness reaches kerb and surface materials")
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = track.get_world_3d().direct_space_state
	var misses: int = 0
	var kerb_hits: int = 0
	for i: int in range(120):
		var s: Dictionary = track.sample_at(track.length_m * float(i) / 120.0)
		for side: float in [-1.0, 0.0, 1.0]:
			var p: Vector3 = s.position + s.right * side * float(s.width) * 0.35
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + s.normal * 1.0, p - s.normal * 0.3, 1)
			var contact: Dictionary = space.intersect_ray(query)
			if contact.is_empty():
				misses += 1
		var position: Vector3 = s.position + s.right * (float(s.width) * 0.5 + 0.35)
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(position + s.normal, position - s.normal * 0.3, 1)
		var hit: Dictionary = space.intersect_ray(ray)
		if not hit.is_empty() and str(hit.collider.name) == "CurbsCollision":
			kerb_hits += 1
	_check(misses == 0, "360 road contact rays remain continuous through chunk joins")
	_check(kerb_hits >= 110, "bevelled kerb collision follows the road edges")
	print("TRACK_FINISH ", JSON.stringify({"length_m": track.length_m, "road_chunks": parts.size(), "maximum_chunk_extent_m": max_extent,
		"road_triangles": road_faces, "road_contact_misses": misses, "kerb_hits": kerb_hits, "build_and_checks_ms": Time.get_ticks_msec() - started}))
	track.queue_free()
	await process_frame
	print("TRACK_FINISH_CHECKS ", "PASS" if failures == 0 else "FAIL: " + str(failures))
	quit(0 if failures == 0 else 1)

func _join_faces() -> void:
	var buffer: TrackMeshBuffer = TrackMeshBuffer.new()
	buffer.quad(Vector3(0, 0, 0), Vector3(8, 0, 0), Vector3(2, 0, -1), Vector3(0, 0, -8))
	buffer.quad(Vector3(0, 0, 0), Vector3(8, 0, 0), Vector3(0, 0, -2), Vector3(8, 0, -2))
	_check(_bad_winding(buffer.mesh()) == 0, "concave and folded joins do not inherit an inverted second triangle")

func _bad_winding(mesh: Mesh) -> int:
	var count: int = 0
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i: int in range(0, indices.size(), 3):
		var a: int = indices[i]
		var b: int = indices[i + 1]
		var c: int = indices[i + 2]
		if (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(normals[a]) >= 0.0:
			count += 1
	return count

func _group(parent: Node, name: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in parent.find_children("*", "MeshInstance3D", true, false):
		if node.get_meta("track_mesh_group", "") == name:
			result.append(node)
	return result

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
