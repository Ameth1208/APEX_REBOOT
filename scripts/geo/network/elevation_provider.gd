class_name ElevationProvider
extends Node
## Explicit terrain lookup. Existing GPS elevations are preserved by default.

signal completed(points: Array, source: String)
signal message(text: String)
signal failed(text: String)

var busy: bool = false
var _points: Array = []
var _pending: Array[int] = []
var _batch: Array[int] = []
var _provider: int = 0
var _request: HTTPRequest
var _generation: int = 0
var _cache: Dictionary = {}
var _sent: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_request = HTTPRequest.new()
	_request.timeout = 30.0
	_request.body_size_limit = 1024 * 1024
	add_child(_request)
	GeoServices.configure_request(_request)
	_request.request_completed.connect(_received)
	if FileAccess.file_exists("user://elevations.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://elevations.json"))
		if parsed is Dictionary:
			_cache = parsed

func lookup(points: Array, provider: int, replace_existing: bool = false) -> void:
	cancel()
	if points.size() < 2 or points.size() > 512:
		failed.emit("La consulta necesita entre 2 y 512 puntos de muestreo.")
		return
	_provider = provider
	_points = points.duplicate(true)
	_sent = 0
	for index: int in range(_points.size()):
		var point: Dictionary = _points[index]
		if point.get("ele") != null and not replace_existing:
			continue
		var cached: Variant = _cache.get(_key(point))
		if cached is Dictionary and Time.get_unix_time_from_system() - float(cached.get("at", 0)) < 2592000.0:
			point["ele"] = cached.elevation
			point["elevation_source"] = GeoServices.source(provider)
		else:
			_pending.append(index)
	busy = true
	_send(_generation)

func cancel() -> void:
	_generation += 1
	busy = false
	_pending.clear()
	_batch.clear()
	if is_instance_valid(_request):
		_request.cancel_request()

func _send(generation: int) -> void:
	if generation != _generation or not busy:
		return
	if _pending.is_empty():
		busy = false
		var file: FileAccess = FileAccess.open("user://elevations.json", FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_cache))
			file.close() # Consumers may read persisted results inside completed.
		completed.emit(_points, GeoServices.source(_provider))
		return
	_batch.clear()
	for index: int in range(mini(100, _pending.size())):
		_batch.append(_pending.pop_front())
	var locations: PackedStringArray = PackedStringArray()
	var latitudes: PackedStringArray = PackedStringArray()
	var longitudes: PackedStringArray = PackedStringArray()
	for index: int in _batch:
		var point: Dictionary = _points[index]
		locations.append("%.7f,%.7f" % [float(point.lat), float(point.lon)])
		latitudes.append("%.7f" % float(point.lat))
		longitudes.append("%.7f" % float(point.lon))
	var url: String
	if _provider == 0:
		url = GeoServices.setting("srtm_url", GeoServices.SRTM_URL) + "?locations=" + "|".join(locations).uri_encode() + "&interpolation=bilinear"
	else:
		url = GeoServices.setting("copernicus_url", GeoServices.COPERNICUS_URL) + "?latitude=" + ",".join(latitudes) + "&longitude=" + ",".join(longitudes)
	message.emit("Consultando cotas del terreno… %d / %d puntos." % [_sent, _sent + _pending.size() + _batch.size()])
	if not GeoServices.configure_request(_request, url):
		_error("El proxy configurado no es compatible: se requiere un proxy HTTP CONNECT sin credenciales en la URL.")
		return
	if _request.request(url, GeoServices.headers()) != OK:
		_error("No se pudo iniciar la consulta de elevación.")

func _received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not busy:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		var hint: String = " En web usa Copernicus GLO-90 o un proveedor SRTM con CORS." if OS.has_feature("web") else ""
		_error("No se pudieron obtener las cotas (HTTP %d). Conservamos tu trazado.%s" % [code, hint])
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_error("La respuesta de elevación no contiene JSON válido.")
		return
	var values: Variant = parsed.get("results", []) if _provider == 0 else parsed.get("elevation", [])
	if not values is Array or values.size() != _batch.size():
		_error("El proveedor devolvió un número de cotas inesperado.")
		return
	for offset: int in range(_batch.size()):
		var elevation: Variant = values[offset].get("elevation") if _provider == 0 and values[offset] is Dictionary else values[offset]
		if not (elevation is int or elevation is float) or not is_finite(float(elevation)):
			_error("El modelo no tiene cobertura para toda la ruta. Importa cotas completas o elige otro proveedor.")
			return
		var point: Dictionary = _points[_batch[offset]]
		point["ele"] = float(elevation)
		point["elevation_source"] = GeoServices.source(_provider)
		_cache[_key(point)] = {"elevation": float(elevation), "at": Time.get_unix_time_from_system()}
	_sent += _batch.size()
	var generation: int = _generation
	await get_tree().create_timer(1.1, true).timeout
	_send(generation)

func _key(point: Dictionary) -> String:
	var endpoint: String = GeoServices.setting("srtm_url", GeoServices.SRTM_URL) if _provider == 0 else GeoServices.setting("copernicus_url", GeoServices.COPERNICUS_URL)
	return "%s|%.7f|%.7f" % [endpoint, float(point.lat), float(point.lon)]

func _error(text: String) -> void:
	busy = false
	_pending.clear()
	_batch.clear()
	failed.emit(text)
