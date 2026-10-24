extends Node3D
## Source-constrained placements; only nearby 160 m chunks get render resources.

const Osm = preload("res://scripts/world/osm_terrain.gd")
const Instances = preload("res://scripts/world/scenery_instances.gd")
const Broadleaf = preload("res://scripts/world/broadleaf_geometry.gd")
const Conifer = preload("res://scripts/world/tree_geometry.gd")
const CHUNK_M: float = 160.0
const CORRIDOR_M: float = 120.0
const VIEW_M: float = 460.0
const MAX_TREES: int = 1400
const MAX_CANDIDATES: int = 6000
var target: Node3D
var placements: Array[Dictionary] = []
var _plans: Dictionary = {}
var _loaded: Dictionary = {}
var _meshes: Dictionary = {}
var _roads: Dictionary = {}
var _areas: Dictionary = {}
var _blocked: Dictionary = {}
var _samples: Array[Dictionary] = []
var _surroundings: Dictionary = {}
var _field: Dictionary = {}
var _occupied: Dictionary = {}
var _fallback: Vector3
var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0

func configure(samples: Array[Dictionary], definition: Dictionary, surroundings: Dictionary, field: Dictionary) -> void:
	set_meta("render_category", "vegetation")
	set_meta("dynamic_stream_owner", true)
	_samples = samples
	_surroundings = surroundings
	_field = field
	_rng.seed = int(definition.get("seed", 8421)) + 777
	if samples.is_empty():
		return
	_fallback = samples[0].position
	for entry: Dictionary in surroundings.get("vegetation_exclusions", []):
		var polygon: Array = entry.polygon
		for point: Vector2 in polygon:
			var key := Vector2i(floori(point.x / CHUNK_M), floori(point.y / CHUNK_M))
			if not _blocked.has(key): _blocked[key] = []
			if not _blocked[key].has(entry): _blocked[key].append(entry)
	for area: Dictionary in surroundings.get("vegetation", []):
		var polygon: Array = area.polygon
		if polygon.is_empty(): continue
		var low: Vector2 = polygon[0]
		var high: Vector2 = polygon[0]
		for point: Vector2 in polygon:
			low = Vector2(minf(low.x, point.x), minf(low.y, point.y))
			high = Vector2(maxf(high.x, point.x), maxf(high.y, point.y))
		for z: int in range(floori(low.y / CHUNK_M), floori(high.y / CHUNK_M) + 1):
			for x: int in range(floori(low.x / CHUNK_M), floori(high.x / CHUNK_M) + 1):
				var key := Vector2i(x, z)
				if not _areas.has(key): _areas[key] = []
				_areas[key].append(area)
	# Spatial road index makes exclusion exact without scanning the entire route per tree.
	for i: int in range(samples.size() if definition.get("closed", true) else samples.size() - 1):
		var a: Vector3 = samples[i].position
		var b: Vector3 = samples[(i + 1) % samples.size()].position
		var low := Vector2(minf(a.x, b.x), minf(a.z, b.z)) - Vector2.ONE * CORRIDOR_M
		var high := Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) + Vector2.ONE * CORRIDOR_M
		for z: int in range(floori(low.y / CHUNK_M), floori(high.y / CHUNK_M) + 1):
			for x: int in range(floori(low.x / CHUNK_M), floori(high.x / CHUNK_M) + 1):
				var key := Vector2i(x, z)
				if not _roads.has(key): _roads[key] = []
				_roads[key].append({"a": Vector2(a.x, a.z), "b": Vector2(b.x, b.z), "clearance": maxf(float(samples[i].width), float(samples[(i + 1) % samples.size()].width)) * 0.5 + float(definition.get("runoff_width", 4)) + 4.0})
	# Explicit trees win deduplication over rows and estimated area populations.
	for entry: Dictionary in surroundings.get("trees", []):
		_offer(entry.position, entry)
	for row: Dictionary in surroundings.get("tree_rows", []):
		var points: Array = row.points
		for i: int in range(points.size() - 1):
			var count: int = maxi(1, ceili(points[i].distance_to(points[i + 1]) / 12.0))
			for j: int in count:
				_offer(points[i].lerp(points[i + 1], float(j) / count), row)
		if not points.is_empty(): _offer(points[-1], row)
	# Sample the route corridor, not the bounding box of enormous forest polygons.
	for key: Vector2i in _roads:
		for z: int in range(0, int(CHUNK_M), 18):
			for x: int in range(0, int(CHUNK_M), 18):
				var point := Vector2(key.x * CHUNK_M + x, key.y * CHUNK_M + z) + Vector2(_rng.randf_range(2, 15), _rng.randf_range(2, 15))
				for area: Dictionary in _areas.get(key, []):
					if Osm.point_in_polygon(point, area.polygon):
						if _rng.randf() <= float(area.get("coverage", 1.0)):
							_offer(point, area)
						break
	_limit_placements()
	set_meta("vegetation_source", str(surroundings.get("landcover_source", "OpenStreetMap")))
	set_meta("planned_trees", placements.size())
	set_meta("attribution", str(surroundings.get("vegetation_attribution", "© OpenStreetMap contributors")))

func _offer(point: Vector2, source: Dictionary) -> void:
	if placements.size() >= MAX_CANDIDATES:
		return
	var cell := Vector2i(floori(point.x / 4.0), floori(point.y / 4.0))
	if _occupied.has(cell): return
	var road_distance: float = INF
	for segment: Dictionary in _roads.get(Vector2i(floori(point.x / CHUNK_M), floori(point.y / CHUNK_M)), []):
		var ab: Vector2 = segment.b - segment.a
		var t: float = clampf((point - segment.a).dot(ab) / maxf(ab.length_squared(), 0.001), 0, 1)
		var distance: float = point.distance_to(segment.a + ab * t)
		if distance < float(segment.clearance): return
		road_distance = minf(road_distance, distance)
	if road_distance > CORRIDOR_M: return
	for entry: Dictionary in _blocked.get(Vector2i(floori(point.x / CHUNK_M), floori(point.y / CHUNK_M)), []):
		if Osm.point_in_polygon(point, entry.polygon): return
	for category: String in ["water", "buildings"]:
		for entry: Dictionary in _surroundings.get(category, []):
			if Osm.point_in_polygon(point, entry.get("polygon", [])): return
	var height: Variant = height_at(point)
	if height == null: return
	var hx: Variant = height_at(point + Vector2(2, 0))
	var hz: Variant = height_at(point + Vector2(0, 2))
	if hx == null or hz == null or Vector2(float(hx) - float(height), float(hz) - float(height)).length() > 1.6: return
	var tags: Dictionary = source.get("tags", {})
	# Do not randomly introduce conifers into tropical roads without leaf-type evidence.
	var variant: int = 2 if tags.get("leaf_type") == "needleleaved" else _rng.randi_range(0, 1)
	var scale: float = _rng.randf_range(0.8, 1.25)
	if tags.has("height") and str(tags.height).is_valid_float(): scale = clampf(float(tags.height) / 8.0, 0.4, 2.5)
	var pose := Transform3D(Basis(Vector3.UP, _rng.randf_range(0, TAU)).scaled(Vector3.ONE * scale), Vector3(point.x, float(height), point.y))
	var key := Vector2i(floori(point.x / CHUNK_M), floori(point.y / CHUNK_M))
	if not _plans.has(key): _plans[key] = []
	if _plans[key].size() >= 16 and source.get("source", "") != "osm_node": return
	_plans[key].append({"pose": pose, "variant": variant})
	placements.append({"position": pose.origin, "pose": pose, "source": source.get("source", "osm_area"), "estimated_position": source.get("source", "") != "osm_node", "variant": variant})
	_occupied[cell] = true

func _limit_placements() -> void:
	if placements.size() <= MAX_TREES: return
	var known: Array[Dictionary] = []
	var estimated: Array[Dictionary] = []
	for entry: Dictionary in placements:
		if entry.estimated_position: estimated.append(entry)
		else: known.append(entry)
	placements = known.slice(0, MAX_TREES)
	var budget: int = MAX_TREES - placements.size()
	for i: int in budget:
		placements.append(estimated[floori(float(i) * estimated.size() / budget)])
	_plans.clear()
	for entry: Dictionary in placements:
		var key := Vector2i(floori(entry.position.x / CHUNK_M), floori(entry.position.z / CHUNK_M))
		if not _plans.has(key): _plans[key] = []
		_plans[key].append({"pose": entry.pose, "variant": entry.variant})

func height_at(point: Vector2) -> Variant:
	var cell: Vector2 = (point - Vector2(_field.start)) / float(_field.step)
	var nx: int = int(_field.nx)
	var nz: int = int(_field.nz)
	if cell.x < 0 or cell.y < 0 or cell.x > nx - 1 or cell.y > nz - 1: return null
	var x: int = mini(floori(cell.x), nx - 2)
	var z: int = mini(floori(cell.y), nz - 2)
	var heights: PackedFloat32Array = _field.heights
	return lerpf(lerpf(heights[z * nx + x], heights[z * nx + x + 1], cell.x - x), lerpf(heights[(z + 1) * nx + x], heights[(z + 1) * nx + x + 1], cell.x - x), cell.y - z)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0: return
	_timer = 0.05
	var position: Vector3 = to_local(target.global_position) if is_instance_valid(target) else _fallback
	for key: Vector2i in _loaded.keys():
		if not visible or Vector2(position.x, position.z).distance_to((Vector2(key) + Vector2.ONE * 0.5) * CHUNK_M) > VIEW_M + CHUNK_M:
			_loaded[key].queue_free()
			_loaded.erase(key)
	if not visible: return
	var nearest: Vector2i
	var best: float = VIEW_M * VIEW_M
	var found: bool = false
	for key: Vector2i in _plans:
		if _loaded.has(key): continue
		var distance: float = Vector2(position.x, position.z).distance_squared_to((Vector2(key) + Vector2.ONE * 0.5) * CHUNK_M)
		if distance < best:
			nearest = key
			best = distance
			found = true
	if not found: return
	var chunk := Node3D.new()
	chunk.name = "VegetationChunk"
	add_child(chunk)
	for variant: int in 3:
		var poses: Array[Transform3D] = []
		for entry: Dictionary in _plans[nearest]:
			if entry.variant == variant: poses.append(entry.pose)
		if poses.is_empty(): continue
		if not _meshes.has(variant): _meshes[variant] = Broadleaf.create(71 + variant * 37) if variant < 2 else Conifer.create(51)
		Instances.build(chunk, "MappedTrees", _meshes[variant], null, poses, VIEW_M, false)
	_loaded[nearest] = chunk

func get_stream_stats() -> Dictionary:
	return {"planned_trees": placements.size(), "total": _plans.size(), "loaded": _loaded.size()}
