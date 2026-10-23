extends SceneTree
## CPU microbenchmark; elapsed query time is not gameplay FPS.

func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var input: String = arguments[0] if not arguments.is_empty() else "res://data/tracks/costa_clara.json"
	var definition: Dictionary = TrackDefinition.clean(JSON.parse_string(FileAccess.get_file_as_string(input)))
	var sampler: TrackSampler = TrackSampler.new()
	sampler.rebuild(definition)
	var positions: Array[Vector3] = []
	var hints: Array[float] = []
	for i: int in range(1200):
		var distance: float = float(i) / 1200.0 * sampler.length_m
		var sample: Dictionary = sampler.sample_at(distance)
		positions.append(sample.position + sample.right * sin(float(i)) * 4.0 + sample.normal * 0.6)
		hints.append(sampler.normalize_distance(distance - 12.0))
	var checksum: float = 0.0
	for i: int in range(60):
		checksum += sampler.closest_distance(positions[i], hints[i])
	var rounds: Array[float] = []
	for _round: int in range(5):
		var started: int = Time.get_ticks_usec()
		for i: int in range(positions.size()):
			checksum += sampler.closest_distance(positions[i], hints[i])
		rounds.append(float(Time.get_ticks_usec() - started) / 1000.0)
	rounds.sort()
	print("ROUTE_QUERY_BENCHMARK ", JSON.stringify({"engine": Engine.get_version_info().string,
		"track": definition.name, "samples": sampler.samples.size(), "length_m": sampler.length_m,
		"queries_per_round": positions.size(), "rounds": rounds, "median_ms": rounds[2],
		"median_us_per_query": rounds[2] * 1000.0 / float(positions.size()), "checksum": checksum,
		"scope": "Single-threaded nearest-route CPU queries with a previous-position hint; no rendering or game FPS."}))
	quit()
