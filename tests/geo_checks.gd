extends SceneTree

const LocalProjection = preload("res://scripts/geo/geo_projection.gd")
const Importer = preload("res://scripts/geo/route_importer.gd")
const Analyser = preload("res://scripts/geo/route_analyser.gd")
var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_projection_checks()
	_parser_checks()
	_import_checks()
	_sampling_checks()
	_analysis_checks()
	_provenance_checks()
	_spline_checks()
	print("GEO_CHECKS ", "PASS" if _failures == 0 else "FAIL", " ", _checks, " assertions, ", _failures, " failures")
	quit(0 if _failures == 0 else 1)

func _projection_checks() -> void:
	var geo: Dictionary = LocalProjection.make_origin(0.0, 0.0, 2500.0)
	var east: Dictionary = LocalProjection.project(0.0, 0.001, 2510.0, geo)
	_close(float(east["x"]), 111.31949, 0.002, "WGS84 equatorial east metres")
	_close(float(east["y"]), 10.0, 0.0001, "relative height uses absolute origin")
	var north: Dictionary = LocalProjection.project(0.001, 0.0, null, geo)
	_check(float(north["z"]) < 0.0 and north["y"] == null, "north is negative Z and unknown height stays null")
	var local: Dictionary = LocalProjection.make_origin(4.65, -74.1, 2500.0)
	var inverse: Dictionary = LocalProjection.inverse(1234.5, -678.9, local, 25.0)
	var roundtrip: Dictionary = LocalProjection.project(float(inverse["lat"]), float(inverse["lon"]), inverse["ele"], local)
	_close(float(roundtrip["x"]), 1234.5, 0.001, "projection inverse east roundtrip")
	_close(float(roundtrip["z"]), -678.9, 0.001, "projection inverse north roundtrip")
	_close(float(inverse["ele"]), 2525.0, 0.001, "inverse recovers absolute height")
	_check(not LocalProjection.project(85.0, 0.0, null, geo)["ok"], "polar coordinate rejected")
	_check(not LocalProjection.project(0.0, -179.99, null, LocalProjection.make_origin(0.0, 179.99))["ok"], "antimeridian crossing rejected")
	_check(not LocalProjection.project(0.0, 1.0, null, geo)["ok"], "extent beyond 40 km rejected")
	_check(not LocalProjection.project(NAN, 0.0, null, geo)["ok"], "nonfinite latitude rejected")
	_check(not LocalProjection.inverse(1.0, 2.0, {"origin_lat":true,"origin_lon":0})["ok"], "boolean is not a coordinate")
	var span: Array = _geographic([Vector3.ZERO, Vector3(30000, 0, 0), Vector3(-30000, 0, 0)])
	_check(not Importer.from_points(span)["ok"], "40 km guard covers complete bounding extent, not only origin radius")

func _parser_checks() -> void:
	var gpx_text: String = FileAccess.get_file_as_string("res://tests/fixtures/geo/synthetic_segments.gpx")
	var geojson_text: String = FileAccess.get_file_as_string("res://tests/fixtures/geo/synthetic_multiline.geojson")
	for format: String in ["gpx", "geojson"]:
		var text: String = gpx_text if format == "gpx" else geojson_text
		var parsed: Dictionary = Importer.parse(text, format, 0)
		_check(bool(parsed["ok"]), format + " synthetic fixture parses")
		if not parsed["ok"]:
			continue
		_check(parsed["routes"].size() == 3, format + " keeps three routes separate")
		_check(parsed["definition"]["raw_route"].size() == 2, format + " does not connect segments")
		_check(not parsed["definition"]["closed"], format + " never invents a closing segment")
		var second: Dictionary = Importer.parse(text, format, 1)
		_check(second["definition"]["requires_elevation"], format + " missing height blocks construction")
		_check(second["definition"]["points"][0]["y"] == null, format + " missing first height remains null")
		_check(second["definition"]["geo"]["origin_alt_source_index"] == 1, format + " first available altitude is explicitly identified")
		var third: Dictionary = Importer.parse(text, format, 2)
		_close(float(third["definition"]["raw_route"][0]["ele"]), 0.0, 0.0001, format + " zero altitude is valid")
		_close(float(third["definition"]["raw_route"][1]["ele"]), -5.0, 0.0001, format + " negative altitude is valid")
		_check(not Importer.parse(text, format, 8)["ok"], format + " invalid selection rejected")
	var namespaced: String = '<g:gpx xmlns:g="http://www.topografix.com/GPX/1/1"><g:rte><g:rtept lat="0" lon="0"><g:ele>1</g:ele></g:rtept><g:rtept lat="0" lon="0.001"><g:ele>2</g:ele></g:rtept></g:rte></g:gpx>'
	_check(Importer.parse(namespaced, "gpx")["ok"], "namespace-prefixed GPX accepted")
	_check(not Importer.parse('<gpx><trk><trkseg>', "gpx")["ok"], "truncated XML rejected")
	_check(not Importer.parse('<gpx><rte></gpx>', "gpx")["ok"], "mismatched XML rejected")
	_check(not Importer.parse('<!DOCTYPE gpx [<!ENTITY x SYSTEM "file:///x">]><gpx/>', "gpx")["ok"], "DTD and external entities rejected")
	_check(not Importer.parse('{"type":"LineString","coordinates":[[0,0],[true,0]]}', "geojson")["ok"], "boolean GeoJSON coordinate rejected")
	_check(not Importer.parse('{"type":"LineString","coordinates":[[0,0],[1,0,"bad"]]}', "geojson")["ok"], "invalid altitude is not flattened")
	_check(not Importer.parse('{"type":"LineString","crs":{"name":"EPSG:3857"},"coordinates":[[0,0],[1,0]]}', "geojson")["ok"], "alternate CRS rejected explicitly")
	var line: Dictionary = Importer.parse('{"type":"LineString","coordinates":[[-74.1,4.65],[-74.099,4.65]]}', "geojson")
	_check(line["ok"] and float(line["definition"]["points"][1]["x"]) > 100.0, "GeoJSON longitude precedes latitude")

func _import_checks() -> void:
	var raw: Array = _geographic([Vector3.ZERO, Vector3(100, 10, 0), Vector3(200, 0, 0)])
	var imported: Dictionary = Importer.from_points(raw, "Sintético", "synthetic")
	_check(imported["ok"], "manual geographic route accepted")
	var definition: Dictionary = imported["definition"]
	_check(definition["interpolation"] == "catmull_rom" and definition["points"][0]["width"] == 12.0, "smooth route defaults")
	_check(definition["points"][1]["raw_index"] == 1 and definition["control_route"][1]["raw_index"] == 1, "control and raw indices map explicitly")
	definition["raw_route"][0]["ele"] = 123.0
	_check(raw[0]["ele"] == 2500.0, "import does not mutate caller points")
	var missing: Array = [{"lat":0.0,"lon":0.0},{"lat":0.0,"lon":0.001}]
	var incomplete: Dictionary = Importer.from_points(missing)["definition"]
	_check(incomplete["requires_elevation"] and incomplete["geo"]["origin_alt_m"] == null, "all-missing elevation keeps null origin")
	_check(incomplete["points"][0]["y"] == null and incomplete["points"][1]["y"] == null, "no implicit flat terrain")
	var too_many: Array = []
	too_many.resize(20001)
	_check(not Importer.from_points(too_many)["ok"], "raw point cap rejects instead of truncating")
	var many: Array[Vector3] = []
	for i: int in range(600):
		many.append(Vector3(float(i) * 2.0, 30.0 if i == 287 else 0.0, 0.0))
	var reduced: Dictionary = Importer.from_points(_geographic(many))
	_check(reduced["ok"], "600-point route conservatively simplified")
	_check(reduced["definition"]["raw_route"].size() == 600 and reduced["definition"]["points"].size() <= 512, "raw points retained while controls are bounded")
	var peak: bool = false
	for p: Dictionary in reduced["definition"]["points"]:
		peak = peak or int(p["raw_index"]) == 287
	_check(peak, "simplification preserves a sharp elevation peak")
	var zigzag: Array[Vector3] = []
	for i: int in range(700):
		zigzag.append(Vector3(float(i) * 2.0, 0.0, 10.0 if i % 2 == 0 else -10.0))
	_check(not Importer.from_points(_geographic(zigzag))["ok"], "overcomplex geometry is not silently forced into 512 points")

func _sampling_checks() -> void:
	var definition: Dictionary = Importer.from_points(_geographic([Vector3.ZERO, Vector3(1000, 100, 0)]))["definition"]
	var sampled: Dictionary = Importer.elevation_samples(definition, 50.0)
	_check(sampled["ok"] and sampled["points"].size() >= 21, "lookup samples reveal terrain between distant vertices")
	_check(sampled["points"][0]["ele"] == 2500.0 and sampled["points"][-1]["ele"] == 2600.0, "original elevations retained for lookup")
	_check(sampled["points"][1]["ele"] == null and sampled["points"][1]["interpolated"], "intermediate heights never interpolated before lookup")
	var long_route: Dictionary = Importer.from_points(_geographic([Vector3.ZERO, Vector3(39000, 0, 0)]))["definition"]
	var capped: Dictionary = Importer.elevation_samples(long_route, 10.0)
	_check(capped["ok"] and capped["points"].size() <= 512, "elevation API samples bounded to 512")
	_check(float(capped["spacing_m"]) > 10.0 and not capped["warnings"].is_empty(), "sampling adjustment disclosed")
	_check(capped["points"][0]["lat"] == long_route["control_route"][0]["lat"] and capped["points"][-1]["lon"] == long_route["control_route"][-1]["lon"], "sampling preserves exact endpoints")
	var closed: Dictionary = Importer.from_points(_geographic([Vector3.ZERO, Vector3(100,0,0), Vector3(100,0,100), Vector3(0,0,100)]), "closed", "synthetic", true)["definition"]
	var loop: Dictionary = Importer.elevation_samples(closed, 50.0)
	_check(loop["points"].size() > 5 and float(loop["max_interval_m"]) <= 50.001, "closed route sampling includes the closing leg")

func _analysis_checks() -> void:
	var line: Dictionary = _definition([Vector3.ZERO, Vector3(100,10,0), Vector3(200,20,0)])
	var analysis: Dictionary = Analyser.analyse(line, 100.0)
	_close(float(analysis["horizontal_distance_m"]), 200.0, 0.0001, "horizontal arc length")
	_close(float(analysis["distance_3d_m"]), sqrt(40400.0), 0.0001, "3D length uses elevation")
	_close(float(analysis["max_uphill_pct"]), 10.0, 0.0001, "10 percent means rise over horizontal distance")
	_close(float(analysis["elevation_gain_m"]), 20.0, 0.0001, "ascent accumulated")
	_close(float(analysis["min_elevation_m"]), 2500.0, 0.0001, "absolute minimum elevation")
	for row: Dictionary in analysis["profile"]:
		_close(float(row["grade_pct"]), 10.0, 0.0001, "constant slope on full horizontal window")
		_close(float(row["window_m"]), 100.0, 0.0001, "real window recorded")
	var turning: Dictionary = Analyser.analyse(_definition([Vector3.ZERO, Vector3(100,10,0), Vector3(100,20,100)]), 200.0)
	_close(float(turning["max_uphill_pct"]), 10.0, 0.0001, "grade uses horizontal arc around turns, not endpoint chord")
	var sharp: Dictionary = Analyser.analyse(_definition([Vector3.ZERO, Vector3(20,0,0), Vector3(70,50,0), Vector3(170,50,0), Vector3(210,0,0)]), 50.0)
	_close(float(sharp["max_uphill_pct"]), 100.0, 0.0001, "window extrema evaluated between profile vertex centres")
	_close(float(sharp["max_downhill_pct"]), -100.0, 0.0001, "signed descent is negative")
	var short: Dictionary = Analyser.analyse(_definition([Vector3.ZERO, Vector3(10,1,0)]), 100.0)
	_close(float(short["window_m"]), 10.0, 0.0001, "short route declares actual window")
	_close(float(short["max_uphill_pct"]), 10.0, 0.0001, "short route grade remains correct")
	var repeated: Dictionary = Analyser.analyse(_definition([Vector3.ZERO, Vector3.ZERO, Vector3(100,10,0)]))
	_check(repeated["duplicate_points"] == 1, "repeated points counted safely")
	_close(float(repeated["max_uphill_pct"]), 10.0, 0.0001, "repeats do not change grade")
	var vertical: Dictionary = Analyser.analyse(_definition([Vector3.ZERO, Vector3(50,5,0), Vector3(50,15,0), Vector3(100,20,0)]))
	_check(vertical["vertical_steps"] == 1 and vertical["max_uphill_pct"] == null, "vertical jumps have undefined slope, never infinity")
	var missing: Dictionary = _definition([Vector3.ZERO, Vector3(50,0,0), Vector3(100,10,0), Vector3(200,20,0)])
	missing["points"][1]["y"] = null
	var gaps: Dictionary = Analyser.analyse(missing)
	_check(gaps["distance_3d_m"] == null and gaps["elevation_gain_m"] == null, "missing heights invalidate total 3D distance and total gain")
	_close(float(gaps["known_elevation_gain_m"]), 10.0, 0.0001, "partial gain only counts adjacent known heights")
	_check(gaps["profile"][0]["grade_pct"] == null, "grade windows cannot bridge missing heights")
	_close(float(gaps["profile"][-1]["grade_pct"]), 10.0, 0.0001, "independent fully known span retains valid slope")
	_close(float(gaps["elevation_coverage"]), 0.5, 0.0001, "height coverage reports known horizontal spans")
	var closed: Dictionary = _definition([Vector3.ZERO, Vector3(100,10,0), Vector3(100,0,100)])
	closed["closed"] = true
	var loop: Dictionary = Analyser.analyse(closed)
	_close(float(loop["horizontal_distance_m"]), 200.0 + sqrt(20000.0), 0.0001, "closed analysis includes closing distance")
	_check(loop["profile"].size() == 4 and loop["profile"][-1]["closing_sample"], "closed analysis adds one explicit closing sample")
	_check(loop["profile"][-1]["control_index"] == 0, "closing sample maps to first control")
	closed["points"].append(closed["points"][0].duplicate(true))
	_check(Analyser.analyse(closed)["profile"].size() == 4, "already-closed input is not closed twice")
	var imported: Dictionary = Importer.from_points(_geographic([Vector3.ZERO, Vector3(100,10,0), Vector3(200,0,0)]))["definition"]
	imported["points"][1]["y"] = 20.0
	var comparison: Dictionary = Analyser.analyse(imported)
	_close(float(comparison["raw"]["elevation_gain_m"]), 10.0, 0.001, "original profile remains unchanged by model edits")
	_close(float(comparison["constructed"]["elevation_gain_m"]), 20.0, 0.001, "constructed profile measures edited heights")
	# With catmull_rom, find the sample at control 1 instead of assuming index 1.
	var control1_found: bool = false
	var raw_control_neg: bool = false
	for row: Dictionary in comparison["profile"]:
		if int(row["control_index"]) == 1:
			control1_found = true
	for row: Dictionary in comparison["raw_profile"]:
		if int(row["control_index"]) == -1:
			raw_control_neg = true
	_check(control1_found and raw_control_neg, "profile mappings distinguish raw from model controls")
	var local_only: Dictionary = _definition([Vector3.ZERO, Vector3(100,10,0)])
	local_only.erase("geo")
	_check(Analyser.analyse(local_only)["min_elevation_m"] == null, "local height is not presented as absolute elevation")
	var bad: Dictionary = _definition([Vector3.ZERO, Vector3(100,10,0)])
	bad["points"][1]["y"] = "bad"
	_check(not Analyser.analyse(bad)["ok"], "invalid height rejected without coercing to zero")
	_check(not Analyser.analyse(line, 0.0)["ok"], "zero analysis window rejected")

func _provenance_checks() -> void:
	var original: Array = _geographic([Vector3.ZERO, Vector3(1000,100,0)])
	var initial: Dictionary = Importer.from_points(original)["definition"]
	var lookup: Dictionary = Importer.elevation_samples(initial, 50.0)
	for p: Dictionary in lookup["points"]:
		if p["ele"] == null:
			p["ele"] = 2510.0
			p["elevation_source"] = "synthetic_dem"
	var rebuilt: Dictionary = Importer.from_points(lookup["points"])["definition"]
	var attached: Dictionary = Importer.attach_original(rebuilt, original)
	_check(attached["raw_route"].size() == 2, "original observations retained after DEM sampling")
	_check(attached["points"][0]["raw_index"] == 0 and attached["points"][-1]["raw_index"] == 1, "source vertices remap to exact original IDs")
	_check(attached["points"][1]["raw_index"] == -1, "DEM intermediate never claims an original observation")
	_check(rebuilt["raw_route"].size() > 2, "attach_original does not mutate supplied definition")
	var analysis: Dictionary = Analyser.analyse(attached)
	_check(analysis["raw_profile"].size() == 2 and analysis["profile"].size() > 2, "original and DEM model retain distinct sampling")
	initial["points"][1]["x"] = 2000.0
	initial["points"][1]["y"] = 200.0
	var current: Dictionary = Importer.elevation_samples(initial, 100.0)
	_close(float(current["points"][-1]["ele"]), 2700.0, 0.001, "lookup uses currently edited model altitude")
	var endpoint: Dictionary = LocalProjection.project(float(current["points"][-1]["lat"]), float(current["points"][-1]["lon"]), current["points"][-1]["ele"], initial["geo"])
	_close(float(endpoint["x"]), 2000.0, 0.001, "lookup uses currently edited coordinates, not stale control_route")
	var remapped: Dictionary = Importer.attach_original(initial, original)
	_check(remapped["points"][1]["raw_index"] == -1, "moved control loses stale original source ID")
	var loop_points: Array = _geographic([Vector3.ZERO, Vector3(100,0,0), Vector3(100,0,100), Vector3(0,0,100), Vector3.ZERO])
	var closed: Dictionary = Importer.from_points(loop_points, "closed", "synthetic", true)
	_check(closed["ok"] and closed["definition"]["points"].size() == 4, "closed duplicate removed only from model controls")
	_check(closed["definition"]["raw_route"].size() == 5, "closing source observation retained")
	_check(not Importer.from_points(_geographic([Vector3.ZERO,Vector3(100,0,0),Vector3(0,0,100)]),"closed","synthetic",true)["ok"], "closed importer enforces four controls")

func _spline_checks() -> void:
	var source: Dictionary = _definition([Vector3.ZERO, Vector3(100,0,0), Vector3(200,100,0), Vector3(300,100,0)])
	source["interpolation"] = "catmull_rom"
	var analysis: Dictionary = Analyser.analyse(source)
	_check(analysis["ok"] and analysis["geometry_exact"], "spline analysis uses the road sampler")
	_check(float(analysis["min_height_m"]) < -7.0 and float(analysis["max_height_m"]) > 107.0, "spline undershoot and overshoot measured from actual model")
	_check(analysis["profile"].size() > 50 and analysis["profile"][-1]["control_index"] == 3, "sampled model profiles map to real control indices")
	var sampler: TrackSampler = TrackSampler.new()
	for p: Dictionary in source["points"]:
		p.merge({"width":12.0,"bank":0.0,"surface":"asphalt"})
	sampler.rebuild(source)
	_close(float(analysis["distance_3d_m"]), sampler.length_m, 0.01, "spline 3D analysis matches constructed road length")
	var legacy: Dictionary = _definition([Vector3.ZERO, Vector3(100,0,0), Vector3(100,0,100), Vector3(0,0,100)])
	legacy.erase("closed")
	legacy.erase("interpolation")
	var v1: Dictionary = Analyser.analyse(legacy)
	_check(v1["closed"] and v1["interpolation"] == "catmull_rom" and v1["profile"].size() > 4, "legacy defaults use closed Catmull geometry")

func _definition(local: Array) -> Dictionary:
	var points: Array[Dictionary] = []
	for position: Vector3 in local:
		points.append({"x":float(position.x),"y":float(position.y),"z":float(position.z)})
	return {"points":points,"closed":false,"interpolation":"linear","geo":LocalProjection.make_origin(4.65,-74.1,2500.0)}

func _geographic(local: Array) -> Array:
	var points: Array[Dictionary] = []
	var origin: Dictionary = LocalProjection.make_origin(4.65, -74.1, 2500.0)
	for position: Vector3 in local:
		var result: Dictionary = LocalProjection.inverse(float(position.x), float(position.z), origin, float(position.y))
		points.append({"lat":result["lat"],"lon":result["lon"],"ele":result["ele"],"elevation_source":"synthetic"})
	return points

func _close(actual: float, expected: float, tolerance: float, label: String) -> void:
	_check(absf(actual - expected) <= tolerance, label + ": " + str(actual) + " vs " + str(expected))

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("GEO FAIL: " + description)
