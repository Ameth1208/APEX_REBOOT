extends SceneTree
## Run python tests/fixtures/geo/local_http_server.py first. No public tiles.

const Proxy = preload("res://scripts/geo/network/geo_proxy.gd")
var failures: Array[String] = []
var checks: int = 0
var _done: bool = false
var _answer: Dictionary = {}
var _completions: int = 0
var _errors: int = 0
var _tile_codes: Array[int] = []
var _tile_missing: bool = false
var _picker_result: Dictionary = {}
var _created: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_config("/srtm")
	DirAccess.remove_absolute("user://elevations.json")
	_check(Proxy.parse("http://proxy.invalid:8080") == {"ok": true, "host": "proxy.invalid", "port": 8080}, "HTTP CONNECT proxy parsing")
	_check(not Proxy.parse("http://user:secret@proxy.invalid:8080").ok, "Unsupported credentials rejected without logging")
	_check(Proxy.bypass("http://127.0.0.1:8782/srtm", "") and Proxy.bypass("https://maps.example.test/x", ".example.test"), "Loopback and NO_PROXY domain bypass")
	var provider: ElevationProvider = _provider()
	var points: Array = [{"lat": 4.6, "lon": -74.08, "ele": 2650.0, "elevation_source": "gps"}, {"lat": 4.6001, "lon": -74.08, "ele": null}, {"lat": 4.6002, "lon": -74.08, "ele": null}]
	var original: Array = points.duplicate(true)
	var result: Dictionary = await _query(provider, points, false)
	_check(result.get("ok", false), "Missing-only lookup completes")
	if result.get("ok", false):
		_check(result.points[0].ele == 2650.0 and result.points[0].elevation_source == "gps" and provider._sent == 2, "Existing GPS height and provenance preserved")
		_check(result.points[1].ele != null and result.points[2].ele != null, "Only missing heights filled")
	_check(points == original, "Provider leaves caller data unchanged")
	result = await _query(provider, points, true)
	_check(result.get("ok", false) and result.points[0].ele != 2650.0 and provider._sent == 1, "Replace changes GPS height, reusing cached missing samples")
	provider.queue_free()
	await process_frame
	provider = _provider()
	result = await _query(provider, points, true)
	_check(result.get("ok", false) and provider._sent == 0, "Disk cache survives a fresh provider instance")
	_config("/slow")
	var before: int = _completions
	provider.lookup(points, 0, true)
	await create_timer(0.05).timeout
	provider.cancel()
	await create_timer(1.8).timeout
	_check(_completions == before and not provider.busy and points == original, "In-flight cancellation cannot commit delayed elevations")
	_config("/batch")
	var batch: Array = []
	for index: int in range(102):
		batch.append({"lat": 4.62 + float(index) * 0.00001, "lon": -74.05, "ele": null})
	provider.lookup(batch, 0, true)
	var deadline: int = Time.get_ticks_msec() + 5000
	while provider._sent == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(provider._sent == 100, "Provider sends at most 100 samples per request")
	provider.cancel()
	await create_timer(1.3).timeout
	_check(_completions == before and provider._pending.is_empty() and batch[0].ele == null, "Cancellation between batches stops timer continuation")
	_config("/missing")
	result = await _query(provider, points, true)
	_check(not result.get("ok", true) and points == original, "Missing DEM coverage fails without changing source route")
	_config("/bad-count")
	result = await _query(provider, points, true)
	_check(not result.get("ok", true), "Unexpected response count is rejected")
	_config("/srtm")
	result = await _query(provider, points, true)
	_check(result.get("ok", false), "A new lookup works after cancellation and failures")
	provider.queue_free()
	await _tiles()
	await _picker_and_provenance(points)
	if failures.is_empty():
		print("GEO_NETWORK_CHECKS PASS ", checks)
	else:
		for failure: String in failures:
			push_error(failure)
		print("GEO_NETWORK_CHECKS FAIL ", failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)

func _provider() -> ElevationProvider:
	var provider: ElevationProvider = ElevationProvider.new()
	root.add_child(provider)
	provider.completed.connect(func(points: Array, source: String) -> void:
		_answer = {"ok": true, "points": points.duplicate(true), "source": source}; _done = true; _completions += 1)
	provider.failed.connect(func(text: String) -> void:
		_answer = {"ok": false, "error": text}; _done = true; _errors += 1)
	return provider

func _query(provider: ElevationProvider, points: Array, replace_existing: bool) -> Dictionary:
	_done = false
	_answer = {}
	provider.lookup(points, 0, replace_existing)
	var deadline: int = Time.get_ticks_msec() + 5000
	while not _done and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _done:
		provider.cancel()
		return {"ok": false, "error": "Fixture timeout"}
	return _answer.duplicate(true)

func _tiles() -> void:
	var cache: MapTileCache = MapTileCache.new()
	root.add_child(cache)
	var key: String = "0/0/0"
	DirAccess.remove_absolute(cache._path(key))
	DirAccess.remove_absolute(cache._path(key) + ".json")
	cache._request.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		_tile_codes.append(code)
		if _tile_missing and code == 304:
			cache.stop()) # Bound the broken-cache regression instead of allowing a retry loop.
	cache.show_tiles([key])
	await _await_tile_codes(1)
	_check(_tile_codes == [200] and cache.textures.has(key), "One visible synthetic tile loads successfully")
	cache.show_tiles([key])
	await create_timer(0.1).timeout
	_check(_tile_codes.size() == 1, "Fresh tile cache avoids repeated HTTP requests")
	var meta: Dictionary = cache._metadata(key)
	_check(float(meta.get("expires", 0)) - Time.get_unix_time_from_system() > 604790.0, "Tile cache has minimum seven-day lifetime")
	meta["expires"] = 0
	var file: FileAccess = FileAccess.open(cache._path(key) + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(meta))
	file = null
	cache.show_tiles([key])
	await _await_tile_codes(2)
	_check(_tile_codes.size() >= 2 and _tile_codes[1] == 304 and cache.textures.has(key), "Expired cached texture revalidates with ETag")
	cache.stop()
	cache.textures.clear()
	DirAccess.remove_absolute(cache._path(key))
	_tile_missing = true
	cache.show_tiles([key])
	await _await_tile_codes(3)
	_check(_tile_codes.size() >= 3 and _tile_codes[2] == 200 and cache.textures.has(key), "Missing PNG with retained metadata must fetch a fresh body")
	cache.stop()
	cache.queue_free()
	await process_frame

func _await_tile_codes(count: int) -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while _tile_codes.size() < count and Time.get_ticks_msec() < deadline:
		await process_frame

func _picker_and_provenance(points: Array) -> void:
	var picker: RouteFilePicker = RouteFilePicker.new()
	root.add_child(picker)
	picker.loaded.connect(func(text: String, filename: String) -> void: _picker_result = {"text": text, "filename": filename})
	picker.failed.connect(func(error: String) -> void: _picker_result = {"error": error})
	picker._native_loaded("res://tests/fixtures/geo/synthetic_segments.gpx")
	_check(_picker_result.get("filename") == "synthetic_segments.gpx" and "<gpx" in str(_picker_result.get("text", "")), "Native file picker reads synthetic GPX text and filename")
	picker._native_loaded("user://does-not-exist.gpx")
	_check(_picker_result.has("error"), "Native file picker reports unreadable files")
	picker._web_loaded(["ok", "synthetic.geojson", "{}"])
	_check(_picker_result.get("filename") == "synthetic.geojson", "Web callback passes filename and file text")
	picker.queue_free()
	var dialog: RealRouteDialog = RealRouteDialog.new()
	root.add_child(dialog)
	dialog.ui.map.tiles.enabled = false
	dialog.created.connect(func(definition: Dictionary) -> void: _created = definition.duplicate(true))
	dialog.open()
	dialog._points = points.duplicate(true)
	dialog._original = points.duplicate(true)
	dialog._lookup()
	var deadline: int = Time.get_ticks_msec() + 5000
	while dialog._loading and Time.get_ticks_msec() < deadline:
		await process_frame
	dialog.ui.provider.select(1) # Merely choosing another provider must not relabel completed data.
	dialog._create()
	_check(not _created.is_empty() and _created.raw_route[0].ele == 2650.0 and _created.raw_route[1].ele == null, "UI attach_original retains original GPS and unknown heights after DEM fill")
	_check(not _created.get("requires_elevation", true) and _created.geo.get("terrain_grid_spacing_m") == 30, "UI constructed route uses complete elevations with provider provenance")
	var imported: String = '{"type":"LineString","coordinates":[[-74.08,4.6,2400],[-74.08,4.6001,2405],[-74.08,4.6002,2409]]}'
	dialog._import_text(imported, "another_complete.geojson")
	dialog._create()
	_check(not _created.geo.has("terrain_elevation_provider") and float(_created.geo.get("elevation_sample_spacing_m", 0)) == 0.0, "Importing a new file clears previous DEM provenance")
	dialog.ui.clear.pressed.emit()
	_check(dialog._filename.is_empty() and dialog._text.is_empty() and dialog._elevation_source.is_empty() and dialog._sample_spacing == 0.0, "Clear resets imported file and sampling provenance")
	dialog.queue_free()
	await process_frame

func _config(path: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("providers", "srtm_url", "http://127.0.0.1:8782" + path)
	config.set_value("providers", "copernicus_url", "http://127.0.0.1:8782/copernicus")
	config.set_value("providers", "map_url", "http://127.0.0.1:8782/tiles/{z}/{x}/{y}.png")
	config.save("user://geo_services.cfg")

func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)
