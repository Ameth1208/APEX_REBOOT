extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var source: Dictionary = ApexCatalog.read_json("res://data/tracks/polonuevo_baranoa.json")
	var route: Dictionary = preload("res://scripts/geo/route_terrain_profile.gd").apply(source)
	check(route.points.size() == 214, "Every original control must be retained")
	check(route.raw_route == source.raw_route, "Raw source observations must remain untouched")
	check(not bool(route.geo.is_flat_test), "Catalog route must use DEM rather than the flat test")
	var highest: float = 0.0
	for i: int in route.points.size():
		check(route.points[i].x == source.points[i].x and route.points[i].z == source.points[i].z, "DEM must not change the plan route")
		highest = maxf(highest, float(route.points[i].y))
	check(highest > 40.0, "Retrieved terrain must produce the expected elevation range")
	check(route.get("terrain_grid", {}).get("elevation_m", []).size() == 532, "Real surroundings must use their own elevation samples")
	var grid: Dictionary = route.get("terrain_grid", {})
	var grid_origin := Vector2(float(grid.start_x), float(grid.start_z))
	var terrain_y: Variant = TrackTerrain.grid_elevation(grid, grid_origin, float(route.geo.origin_alt_m))
	check(terrain_y != null and is_equal_approx(float(terrain_y), float(grid.elevation_m[0]) - float(route.geo.origin_alt_m)), "Terrain and road must share their vertical origin")
	check(TrackTerrain.grid_elevation(grid, grid_origin - Vector2.ONE, float(route.geo.origin_alt_m)) == null, "Outside DEM coverage must not silently return a measured height")
	var props := Node3D.new()
	var faithful_sampler := TrackSampler.new()
	faithful_sampler.rebuild(TrackDefinition.clean(route))
	TrackProps.build(props, faithful_sampler, route)
	check(props.get_child_count() == 0, "Faithful road must not invent viaduct supports or timing gantries")
	props.free()
	var sampler := TrackSampler.new()
	sampler.rebuild(TrackDefinition.clean(route))
	check(sampler.length_m > 14000.0, "Route must retain its full driving length")
	var crossing := {"closed": false, "construction_mode": "faithful", "points": [
		{"x": -100.0, "y": 0.0, "z": -100.0}, {"x": 100.0, "y": 0.0, "z": 100.0},
		{"x": -100.0, "y": 0.1, "z": 100.0}, {"x": 100.0, "y": 0.1, "z": -100.0}]}
	var repaired: Dictionary = TrackValidation.auto_repair_crossings(TrackDefinition.clean(crossing), 1.1)
	check(float(repaired.points[0].y) == 0.0 and float(repaired.points[2].y) == 0.1, "Faithful crossing repair must never invent a bridge")
	var collider := StaticBody3D.new()
	collider.set_meta("surface", "gravel")
	collider.set_meta("is_road", true)
	check(preload("res://scripts/physics/suspension.gd").surface_at_point(Vector2.ZERO, collider) == "gravel", "Road material must have priority over landuse polygons")
	collider.free()
	var buffer := TrackMeshBuffer.new()
	for i: int in range(20):
		var x: float = float(i) * 40.0
		buffer.quad_colored(Vector3(x, 0, 0), Vector3(x + 30, 0, 0), Vector3(x + 30, 0, 30), Vector3(x, 0, 30), Vector3.UP, Color.GREEN, Color.GREEN, Color.GREEN, Color.GREEN)
	for chunk: TrackMeshBuffer in buffer._chunks(320.0):
		check(chunk.colors.size() == chunk.vertices.size(), "Streaming terrain chunks must preserve the detected surface blend weights")
	print("ROAD FIDELITY: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
