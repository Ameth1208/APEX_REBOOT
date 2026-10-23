class_name MapTileCache
extends Node
## Only the current viewport is queued. Disk cache >= 7 days; no prefetch.

signal changed
signal message(text: String)

var textures: Dictionary = {}
var enabled: bool = true
var _wanted: Array[String] = []
var _failed: Dictionary = {}
var _request: HTTPRequest
var _active: String = ""
var _folder: String = ""
var _url: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_url = GeoServices.setting("map_url", GeoServices.MAP_URL)
	_folder = "user://maps/" + _url.sha256_text().substr(0, 16)
	DirAccess.make_dir_recursive_absolute(_folder)
	_request = HTTPRequest.new()
	_request.timeout = 15.0
	_request.body_size_limit = 2 * 1024 * 1024
	add_child(_request)
	GeoServices.configure_request(_request)
	_request.request_completed.connect(_completed)

func show_tiles(keys: Array[String]) -> void:
	_wanted = keys
	for key: String in keys:
		if not textures.has(key) and FileAccess.file_exists(_path(key)):
			var picture: Image = Image.load_from_file(_path(key))
			if picture != null and not picture.is_empty():
				textures[key] = ImageTexture.create_from_image(picture)
	if textures.size() > 128:
		for key: String in textures.keys():
			if key not in keys:
				textures.erase(key)
	_next()

func stop() -> void:
	_wanted.clear()
	if is_instance_valid(_request):
		_request.cancel_request()
	_active = ""

func _next() -> void:
	if not enabled or not _active.is_empty() or not is_instance_valid(_request):
		return
	var now: float = Time.get_unix_time_from_system()
	for key: String in _wanted:
		if float(_failed.get(key, 0.0)) > now:
			continue
		var meta: Dictionary = _metadata(key)
		if textures.has(key) and float(meta.get("expires", 0.0)) > now:
			continue
		_active = key
		var headers: PackedStringArray = GeoServices.headers()
		if not OS.has_feature("web") and textures.has(key):
			# A 304 is useful only while an actual cached image is available.
			if meta.has("etag"):
				headers.append("If-None-Match: " + str(meta.etag))
			if meta.has("modified"):
				headers.append("If-Modified-Since: " + str(meta.modified))
		var parts: PackedStringArray = key.split("/")
		var url: String = _url.replace("{z}", parts[0]).replace("{x}", parts[1]).replace("{y}", parts[2])
		if not GeoServices.configure_request(_request, url):
			_fail("El proxy del mapa necesita HTTP CONNECT sin credenciales en la URL.")
			return
		if _request.request(url, headers) != OK:
			_fail("No se pudo conectar con el mapa. Puedes importar un GPX sin cartografía.")
		return

func _completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _active.is_empty():
		return
	if result != HTTPRequest.RESULT_SUCCESS or code not in [200, 304]:
		_fail("Mapa no disponible (HTTP %d). El trazado y la importación siguen disponibles." % code)
		return
	if code == 304 and not textures.has(_active):
		_fail("El servidor revalidó una imagen que ya no está en caché.")
		return
	if code == 200:
		var picture: Image = Image.new()
		if picture.load_png_from_buffer(body) != OK:
			_fail("La respuesta del mapa no es una imagen PNG válida.")
			return
		textures[_active] = ImageTexture.create_from_image(picture)
		picture.save_png(_path(_active))
	var meta: Dictionary = _metadata(_active)
	var ttl: float = 604800.0
	for header: String in headers:
		var value: String = header.get_slice(":", 1).strip_edges()
		if header.to_lower().begins_with("etag:"):
			meta["etag"] = value
		elif header.to_lower().begins_with("last-modified:"):
			meta["modified"] = header.substr(header.find(":") + 1).strip_edges()
		elif header.to_lower().begins_with("cache-control:"):
			for directive: String in value.split(","):
				if directive.strip_edges().begins_with("max-age="):
					ttl = maxf(ttl, float(directive.get_slice("=", 1)))
	meta["expires"] = Time.get_unix_time_from_system() + ttl
	var file: FileAccess = FileAccess.open(_path(_active) + ".json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(meta))
		file.close() # _next reads the cache immediately; commit before advancing.
	_active = ""
	changed.emit()
	_next()

func _fail(text: String) -> void:
	_failed[_active] = Time.get_unix_time_from_system() + 60.0
	_active = ""
	message.emit(text)
	_next.call_deferred()

func _path(key: String) -> String:
	return _folder.path_join(key.replace("/", "_") + ".png")

func _metadata(key: String) -> Dictionary:
	if not FileAccess.file_exists(_path(key) + ".json"):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path(key) + ".json"))
	return parsed if parsed is Dictionary else {}
