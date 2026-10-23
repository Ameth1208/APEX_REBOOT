extends SceneTree
## Opt-in live smoke: exactly two public coordinates per elevation service, no tiles.

const Provider = preload("res://scripts/geo/network/elevation_provider.gd")
var _finished: bool = false
var _result: Dictionary = {}
var _failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var provider: Node = Provider.new()
	root.add_child(provider)
	provider._request.timeout = 25.0
	provider._request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		print("GEO_HTTP result=", result, " code=", code))
	provider.completed.connect(func(points: Array, source: String) -> void:
		_result = {"ok":true,"points":points.duplicate(true),"source":source}; _finished = true)
	provider.failed.connect(func(message: String) -> void:
		_result = {"ok":false,"error":message}; _finished = true)
	var input: Array = [{"lat":4.5981,"lon":-74.0758,"ele":null}, {"lat":4.6056,"lon":-74.0556,"ele":null}]
	var report: Dictionary = {"coordinates":"Dos coordenadas públicas de Bogotá; consulta de DEM, no medición GPS.","providers":[]}
	for index: int in [0, 1]:
		var started: int = Time.get_ticks_msec()
		var response: Dictionary = await _query(provider, input, index)
		response["provider_index"] = index
		response["duration_ms"] = Time.get_ticks_msec() - started
		if response["ok"]:
			var from_cache: Dictionary = await _query(provider, input, index)
			response["cache_hit"] = from_cache.get("ok", false) and provider._sent == 0 and from_cache.get("points", []) == response["points"]
			response["input_unchanged"] = input[0]["ele"] == null and input[1]["ele"] == null
			response["cache_persisted"] = FileAccess.file_exists("user://elevations.json")
			if not response["cache_hit"] or not response["input_unchanged"] or not response["cache_persisted"]:
				_failed += 1
		else:
			_failed += 1
		report["providers"].append(response)
		print("GEO_LIVE ", JSON.stringify(response))
	var file: FileAccess = FileAccess.open("/workspace/scratch/c2ca777a7497/tooling/geo_network_live_report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	provider.queue_free()
	await process_frame
	print("GEO_NETWORK_LIVE_CHECKS ", "PASS" if _failed == 0 else "FAIL")
	quit(0 if _failed == 0 else 1)

func _query(provider: Node, points: Array, index: int) -> Dictionary:
	_finished = false
	_result = {}
	provider.lookup(points, index, true)
	var deadline: int = Time.get_ticks_msec() + 35000
	while not _finished and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _finished:
		provider.cancel()
		return {"ok":false,"error":"Watchdog: consulta sin finalizar en 35 s."}
	return _result.duplicate(true)
