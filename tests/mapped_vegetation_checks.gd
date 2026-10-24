extends SceneTree
## Desktop fixtures verify map semantics, exclusions, terrain and lazy rendering.
const Vegetation = preload("res://scripts/world/mapped_vegetation.gd")
const Osm = preload("res://scripts/world/osm_terrain.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var geo := GeoProjection.make_origin(10.78, -74.86, 0)
	var parsed: Dictionary = Osm.parse_elements({"elements": [
		{"type": "node", "id": 1, "lat": 10.78, "lon": -74.86, "tags": {"natural": "tree"}},
		{"type": "way", "id": 2, "tags": {"natural": "tree_row"}, "geometry": [{"lat": 10.78, "lon": -74.86}, {"lat": 10.781, "lon": -74.86}]},
		{"type": "way", "id": 3, "tags": {"natural": "wood"}, "geometry": [{"lat": 10.78, "lon": -74.86}, {"lat": 10.781, "lon": -74.86}, {"lat": 10.781, "lon": -74.861}, {"lat": 10.78, "lon": -74.86}]},
		{"type": "way", "id": 4, "tags": {"waterway": "stream"}, "geometry": [{"lat": 10.78, "lon": -74.86}, {"lat": 10.781, "lon": -74.86}, {"lat": 10.781, "lon": -74.861}]}
	]}, geo)
	check(parsed.trees.size() == 1, "OSM individual tree nodes are retained")
	check(parsed.tree_rows.size() == 1 and parsed.vegetation.size() == 1, "Rows remain lines and woodland remains an area")
	check(parsed.water.is_empty(), "Open streams never become filled polygon lakes")
	var samples: Array[Dictionary] = [
		{"position": Vector3(0, 0, -300), "width": 12.0},
		{"position": Vector3(0, 0, 300), "width": 12.0}]
	var data: Dictionary = {"trees": [
		{"position": Vector2(25, 0), "source": "osm_node", "tags": {}},
		{"position": Vector2(0, 0), "source": "osm_node", "tags": {}},
		{"position": Vector2(40, 0), "source": "osm_node", "tags": {}},
		{"position": Vector2(60, 0), "source": "osm_node", "tags": {}},
		{"position": Vector2(800, 0), "source": "osm_node", "tags": {}}],
		"vegetation": [], "tree_rows": [],
		"water": [{"polygon": _box(40)}], "buildings": [{"polygon": _box(60)}]}
	var vegetation := Vegetation.new()
	root.add_child(vegetation)
	vegetation.configure(samples, {"closed": false}, data, {"start": Vector2(-1000, -1000), "step": 2000.0, "nx": 2, "nz": 2, "heights": PackedFloat32Array([7, 7, 7, 7])})
	check(vegetation.placements.size() == 1, "Road, water, building and distant placements are excluded")
	check(vegetation.placements[0].position.is_equal_approx(Vector3(25, 7, 0)), "Known tree keeps its horizontal position and follows actual terrain")
	check(not vegetation.placements[0].estimated_position, "Known tree is not mislabeled as an estimated position")
	check(vegetation.get_child_count() == 0, "Planning does not instantiate all tree chunks")
	vegetation._process(0.1)
	check(vegetation._loaded.size() == 1, "Nearby chunk is generated on demand")
	var target := Node3D.new()
	root.add_child(target)
	vegetation.target = target
	target.position = Vector3(9000, 0, 0)
	vegetation._process(0.1)
	await process_frame
	check(vegetation._loaded.is_empty() and vegetation.get_child_count() == 0, "Far render chunks are freed, not merely hidden")
	check(vegetation.placements.size() == 1, "Unloading preserves the deterministic editable placement data")
	target.position = Vector3.ZERO
	vegetation._process(0.1)
	check(vegetation._loaded.size() == 1, "Returning rebuilds the same chunk")
	vegetation.visible = false
	vegetation._process(0.1)
	check(vegetation._loaded.is_empty(), "Disabling vegetation releases active chunks")
	vegetation.free()
	target.free()
	print("MAPPED_VEGETATION_CHECKS ", "PASS" if failures.is_empty() else "FAIL", " ", checks, " ", failures)
	quit(0 if failures.is_empty() else 1)

func _box(x: float) -> Array[Vector2]:
	return [Vector2(x - 4, -4), Vector2(x + 4, -4), Vector2(x + 4, 4), Vector2(x - 4, 4)]
