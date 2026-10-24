extends SceneTree

func _initialize() -> void:
	var route: Dictionary = preload("res://scripts/geo/route_terrain_profile.gd").apply(ApexCatalog.read_json("res://data/tracks/polonuevo_baranoa.json"))
	for enabled: bool in [false, true]:
		route["smooth_vertical_profile"] = enabled
		var sampler := TrackSampler.new()
		sampler.rebuild(TrackDefinition.clean(route))
		var last: float = 0.0
		var maximum: float = 0.0
		var sum: float = 0.0
		for i: int in range(sampler.samples.size() - 1):
			var a: Vector3 = sampler.samples[i].position
			var b: Vector3 = sampler.samples[i + 1].position
			var grade: float = atan2(b.y - a.y, Vector2(b.x - a.x, b.z - a.z).length())
			if i > 0:
				maximum = maxf(maximum, absf(grade - last))
				sum += absf(grade - last)
			last = grade
		print("ROAD_PROFILE smoothing=", enabled, " samples=", sampler.samples.size(), " length_m=", sampler.length_m, " max_grade_change_deg=", rad_to_deg(maximum), " total_grade_variation_deg=", rad_to_deg(sum))
	quit()
