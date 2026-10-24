extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	var source := TrackDefinition.clean({"closed": false, "interpolation": "linear", "smooth_vertical_profile": true, "sample_spacing": 2.0, "points": [
		{"x": 0, "y": 0, "z": 0}, {"x": 100, "y": 10, "z": 0},
		{"x": 200, "y": 10, "z": 0}, {"x": 300, "y": 0, "z": 0}]})
	var original: Array = source.points.duplicate(true)
	var sampler := TrackSampler.new()
	sampler.rebuild(source)
	for sample: Dictionary in sampler.samples:
		var p: Vector3 = sample.position
		check(p.y >= -0.001 and p.y <= 10.001, "Smoothing never overshoots source heights")
		check(absf(p.z) < 0.00001, "Horizontal route is unchanged")
	check(source.points == original, "Source control elevations remain untouched")
	check(sampler.samples[0].position.is_equal_approx(Vector3.ZERO) and sampler.samples[-1].position.is_equal_approx(Vector3(300, 0, 0)), "Open-route endpoints are preserved")
	var left: float = preload("res://scripts/tracks/vertical_profile.gd").height(Vector3(0, 0, 0), Vector3(0, 0, 0), Vector3(100, 10, 0), Vector3(200, 10, 0), 0.999)
	check(absf(10.0 - left) / 0.1 < 0.001, "Grade eases into the plateau instead of making an abrupt pitch step")
	var real_source: Dictionary = preload("res://scripts/geo/route_terrain_profile.gd").apply(ApexCatalog.read_json("res://data/tracks/polonuevo_baranoa.json"))
	var baseline := TrackSampler.new()
	real_source["smooth_vertical_profile"] = false
	baseline.rebuild(TrackDefinition.clean(real_source))
	var smooth := TrackSampler.new()
	real_source["smooth_vertical_profile"] = true
	smooth.rebuild(TrackDefinition.clean(real_source))
	check(_max_grade_change(smooth.samples) < _max_grade_change(baseline.samples) * 0.5, "Real DEM road reduces worst short-wavelength grade changes")
	check(smooth.samples.size() == baseline.samples.size(), "Filtering does not increase road mesh/collision sample count")
	for i: int in smooth.samples.size():
		var a: Vector3 = smooth.samples[i].position
		var b: Vector3 = baseline.samples[i].position
		check(a.x == b.x and a.z == b.z, "DEM filtering preserves horizontal geometry exactly")
		check(absf(a.y - b.y) < 4.0, "DEM road filtering remains bounded rather than flattening relief")
	print("VERTICAL_PROFILE_CHECKS ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _max_grade_change(samples: Array[Dictionary]) -> float:
	var maximum: float = 0.0
	var previous: float = 0.0
	for i: int in range(samples.size() - 1):
		var a: Vector3 = samples[i].position
		var b: Vector3 = samples[i + 1].position
		var grade: float = atan2(b.y - a.y, Vector2(b.x - a.x, b.z - a.z).length())
		if i > 0: maximum = maxf(maximum, absf(grade - previous))
		previous = grade
	return maximum
