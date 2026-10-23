extends SceneTree
## Geometry contract for imported point-to-point routes, including exact linear heights.

var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw: Dictionary = _definition()
	var definition: Dictionary = TrackDefinition.clean(raw)
	_check(definition.version == 2 and not definition.closed and definition.interpolation == "linear", "v2 open interpolation flags survive normalization")
	_check(definition.geo.origin_lat == 4.6 and definition.raw_route[0].ele == 2600.0, "geographic source metadata remains available")
	_check(definition.points[1].raw_index == 20 and definition.points[0].y == 2600.0, "source indices and high relative elevations survive normalization")
	var sampler: TrackSampler = TrackSampler.new()
	sampler.rebuild(definition)
	var first: Vector3 = TrackDefinition.position(definition.points[0])
	var last: Vector3 = TrackDefinition.position(definition.points[-1])
	var expected: float = 0.0
	for i: int in range(definition.points.size() - 1):
		expected += TrackDefinition.position(definition.points[i]).distance_to(TrackDefinition.position(definition.points[i + 1]))
	_check(absf(sampler.length_m - expected) < 0.01, "open length contains only source segments")
	_check(Vector3(sampler.sample_at(-20.0).position).distance_to(first) < 0.001, "sample before start clamps to start")
	_check(Vector3(sampler.sample_at(expected + 20.0).position).distance_to(last) < 0.001, "sample after finish clamps to finish")
	_check(absf(sampler.closest_distance(last + Vector3(sampler.sample_at(expected).normal), expected) - expected) < 0.1, "finish projection does not wrap to zero")
	_check(sampler.samples.size() < 100, "linear sampling avoids twelve subdivisions per tiny source edge")
	for sample: Dictionary in sampler.samples:
		var index: int = mini(int(sample.control_index), definition.points.size() - 2)
		var a: Vector3 = TrackDefinition.position(definition.points[index])
		var b: Vector3 = TrackDefinition.position(definition.points[index + 1])
		var v: Vector3 = b - a
		var ratio: float = clampf((Vector3(sample.position) - a).dot(v) / v.length_squared(), 0.0, 1.0)
		_check(Vector3(sample.position).distance_to(a.lerp(b, ratio)) < 0.001, "linear route preserves each supplied 3D segment")
		_check(Vector3(sample.forward).is_finite() and absf(Vector3(sample.normal).length() - 1.0) < 0.001, "open frames remain finite and normalized")
	var curved: Dictionary = definition.duplicate(true)
	curved.interpolation = "catmull_rom"
	sampler.rebuild(curved)
	_check(Vector3(sampler.sample_at(0).position).distance_to(first) < 0.001 and Vector3(sampler.sample_at(sampler.length_m).position).distance_to(last) < 0.001, "open Catmull–Rom keeps exact endpoints")
	var two: Dictionary = definition.duplicate(true)
	two.points = [definition.points[0], definition.points[1]]
	_check(TrackDefinition.clean(two).points.size() == 2 and TrackValidation.source_error(two).is_empty(), "two-point open source is supported")
	var missing: Dictionary = definition.duplicate(true)
	missing.points[1].y = null
	_check(not TrackValidation.source_error(missing).is_empty(), "unknown elevation is rejected before cleaning")
	missing = definition.duplicate(true)
	missing.requires_elevation = true
	_check(not TrackValidation.source_error(missing).is_empty(), "incomplete geographic elevation cannot silently become a flat route")
	missing = definition.duplicate(true)
	missing.requires_geometry_review = true
	_check(TrackValidation.source_error(missing).is_empty(), "review metadata does not permanently block corrected current geometry")
	missing = definition.duplicate(true)
	missing.points[1].x = missing.points[0].x
	missing.points[1].z = missing.points[0].z
	_check(not TrackValidation.source_error(missing).is_empty(), "vertical segments are blocked even without an importer flag")

	var track: CircuitTrack = CircuitTrack.new()
	root.add_child(track)
	track.build(definition)
	_check(track.build_error.is_empty() and not track.closed, "physical open track builds")
	_check(_maximum_edge(track, "Road_asphalt") < 25.0, "all road chunks have no invented closing chord")
	_check(_maximum_edge(track, "GrassVerges") < 55.0, "all terrain verge chunks do not close the route")
	_check(track.has_node("FinishBrakingApron"), "finish has a separate safe braking apron")
	var names: Array[String] = []
	for child: Node in track.get_children():
		if child is Label3D:
			names.append(child.text)
	_check(names.has("APEX  /  SALIDA") and names.has("APEX  /  META"), "separate start and finish gates are visible")
	for i: int in range(6):
		var transform: Transform3D = track.get_grid_transform(i)
		var distance: float = track.closest_distance(transform.origin)
		_check(distance >= 4.0 and distance < track.length_m - 8.0, "grid slot remains within open road")
	track.queue_free()
	await process_frame
	await _large_route_budget()
	var closed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tracks/costa_clara.json"))
	sampler.rebuild(TrackDefinition.clean(closed))
	_check(sampler.closed and sampler.length_m > 3000.0, "existing preset stays a closed circuit")
	_check(Vector3(sampler.sample_at(-10.0).position).distance_to(sampler.sample_at(sampler.length_m - 10.0).position) < 0.001, "closed negative distances still wrap")
	_check(Vector3(sampler.sample_at(sampler.length_m).position).distance_to(sampler.sample_at(0.0).position) < 0.001, "closed finish still wraps to start")
	print("OPEN_ROUTE_CHECKS ", "PASS" if _failures == 0 else "FAIL: " + str(_failures))
	quit(0 if _failures == 0 else 1)

func _large_route_budget() -> void:
	var definition: Dictionary = TrackDefinition.clean({"closed": false, "interpolation": "linear", "sample_spacing": 12.0, "terrain_hills": 0.0,
		"points": [{"x": 0.0, "y": 0.0, "z": 0.0}, {"x": 28000.0, "y": 20.0, "z": -28000.0}]})
	var limit: Dictionary = TrackDefinition.clean({"closed": false, "points": [{"x": 0.0, "y": 0.0, "z": 0.0}, {"x": 39000.0, "y": 0.0, "z": 0.0}]})
	_check(limit.points[1].x == 39000.0, "valid geographic extents are not clipped to 25 km")
	var sampler: TrackSampler = TrackSampler.new()
	sampler.rebuild(definition)
	var holder: Node3D = Node3D.new()
	root.add_child(holder)
	TrackTerrain.build(holder, sampler.samples, definition)
	var count: int = 0
	for instance: MeshInstance3D in _mesh_group(holder, "Terrain"):
		for surface: int in range(instance.mesh.get_surface_count()):
			count += PackedVector3Array(instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]).size()
	_check(count > 1000 and count < 100000, "all long-route terrain chunks together keep a bounded grid")
	holder.queue_free()
	await process_frame

func _maximum_edge(parent: Node, group: String) -> float:
	var longest: float = 0.0
	for instance: MeshInstance3D in _mesh_group(parent, group):
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i: int in range(0, indices.size(), 3):
				for j: int in range(3):
					longest = maxf(longest, vertices[indices[i + j]].distance_to(vertices[indices[i + (j + 1) % 3]]))
	return longest

func _mesh_group(parent: Node, group: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in parent.find_children("*", "MeshInstance3D", true, false):
		if node.get_meta("track_mesh_group", "") == group:
			result.append(node)
	return result

func _definition() -> Dictionary:
	return {"name": "Prueba geográfica", "closed": false, "interpolation": "linear", "terrain_hills": 0.0,
		"geo": {"origin_lat": 4.6, "origin_lon": -74.1, "origin_alt_m": 2600.0, "projection": "wgs84_local"},
		"raw_route": [{"lat": 4.6, "lon": -74.1, "ele": 2600.0}],
		"points": [{"x": 0.0, "y": 2600.0, "z": 0.0, "raw_index": 0},
			{"x": 0.0, "y": 2610.0, "z": -100.0, "raw_index": 20},
			{"x": 60.0, "y": 2620.0, "z": -160.0, "raw_index": 40},
			{"x": 120.0, "y": 2610.0, "z": -160.0, "raw_index": 60}]}

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)
