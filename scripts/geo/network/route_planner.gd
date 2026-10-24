class_name RoutePlanner
extends Node
## Geocodes two places and builds a drivable route through OpenStreetMap roads.

signal route_ready(points: Array, start_label: String, finish_label: String)
signal failed(message: String)

const NOMINATIM_URL := "https://nominatim.openstreetmap.org/search"
const OSRM_URL := "https://router.project-osrm.org/route/v1/driving/"

var _request: HTTPRequest
var _stage: String = ""
var _start_text: String = ""
var _finish_text: String = ""
var _start: Dictionary = {}
var _finish: Dictionary = {}

func _ready() -> void:
	_request = HTTPRequest.new()
	_request.timeout = 20.0
	add_child(_request)
	_request.request_completed.connect(_completed)

func plan(start_text: String, finish_text: String) -> void:
	if _request == null or _request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		failed.emit("Ya hay una ruta en preparación.")
		return
	_start_text = start_text.strip_edges()
	_finish_text = finish_text.strip_edges()
	if _start_text.is_empty() or _finish_text.is_empty():
		failed.emit("Escribe un punto de salida y uno de llegada.")
		return
	_stage = "start"
	_start = {}
	_finish = {}
	_request_place(_start_text)

func cancel() -> void:
	if _request != null:
		_request.cancel_request()
	_stage = ""

func _request_place(query: String) -> void:
	var url := NOMINATIM_URL + "?format=jsonv2&limit=1&countrycodes=co&q=" + query.uri_encode()
	if not GeoServices.configure_request(_request, url):
		failed.emit("No se pudo configurar la conexión de mapas.")
		return
	var error := _request.request(url, GeoServices.headers())
	if error != OK:
		failed.emit("No se pudo consultar el lugar: " + str(error))

func _request_route() -> void:
	var coordinates := "%s,%s;%s,%s" % [_start.lon, _start.lat, _finish.lon, _finish.lat]
	var url := OSRM_URL + coordinates + "?overview=full&geometries=geojson&steps=false"
	if not GeoServices.configure_request(_request, url):
		failed.emit("No se pudo configurar el planificador de rutas.")
		return
	var error := _request.request(url, GeoServices.headers())
	if error != OK:
		failed.emit("No se pudo calcular la ruta: " + str(error))

func _completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		failed.emit("El servicio de mapas no respondió. Puedes importar GPX o marcar la ruta en el mapa.")
		_stage = ""
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Array and not parsed is Dictionary:
		failed.emit("Respuesta de mapas inválida.")
		_stage = ""
		return
	if _stage in ["start", "finish"]:
		var places: Array = parsed as Array
		if places.is_empty():
			failed.emit("No encontré «%s». Prueba con municipio y departamento." % (_start_text if _stage == "start" else _finish_text))
			_stage = ""
			return
		var place: Dictionary = places[0]
		var resolved := {"lat": float(place.get("lat", 0.0)), "lon": float(place.get("lon", 0.0)), "label": str(place.get("display_name", "Lugar"))}
		if _stage == "start":
			_start = resolved
			_stage = "finish"
			_request_place(_finish_text)
		else:
			_finish = resolved
			_stage = "route"
			_request_route()
		return
	var data: Dictionary = parsed as Dictionary
	var routes: Array = data.get("routes", [])
	if data.get("code", "") != "Ok" or routes.is_empty():
		failed.emit("No hay una ruta vial disponible entre esos puntos.")
		_stage = ""
		return
	var geometry: Dictionary = routes[0].get("geometry", {})
	var coordinates: Array = geometry.get("coordinates", [])
	var points: Array = []
	for coordinate: Array in coordinates:
		if coordinate.size() >= 2:
			points.append({"lat": float(coordinate[1]), "lon": float(coordinate[0]), "ele": null, "elevation_source": "missing"})
	_stage = ""
	if points.size() < 2:
		failed.emit("La ruta calculada no contiene suficientes puntos.")
		return
	route_ready.emit(points, _start_text, _finish_text)
