class_name GeoJsonReader
extends RefCounted
## RFC 7946 positions are [longitude, latitude, optional altitude in metres].

const Values = preload("res://scripts/geo/geo_value.gd")
const MAX_POINTS: int = 20000

static func read(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > 8 * 1024 * 1024:
		return Values.fail("El GeoJSON supera el límite de 8 MiB de texto.")
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return Values.fail("GeoJSON inválido en línea " + str(parser.get_error_line() + 1) + ": " + parser.get_error_message())
	var state: Dictionary = {"routes": [], "warnings": [], "count": 0, "error": ""}
	_visit(parser.data, "Ruta GeoJSON", state, 0)
	if not str(state["error"]).is_empty():
		return Values.fail(str(state["error"]))
	if state["routes"].is_empty():
		return Values.fail("No se encontraron geometrías LineString ni MultiLineString.")
	return {"ok": true, "error": "", "routes": state["routes"], "warnings": state["warnings"]}

static func _visit(value: Variant, name: String, state: Dictionary, depth: int) -> void:
	if not str(state["error"]).is_empty():
		return
	if not value is Dictionary or depth > 16:
		state["error"] = "Objeto GeoJSON inválido o excesivamente anidado."
		return
	var object: Dictionary = value
	if object.get("crs") != null:
		state["error"] = "Convierte el GeoJSON a RFC 7946/WGS84 sin crs alternativo antes de importarlo."
		return
	match str(object.get("type", "")):
		"Feature":
			var properties: Variant = object.get("properties", {})
			if properties is Dictionary:
				name = str(properties.get("name", properties.get("title", name))).left(160)
			if object.get("geometry") != null:
				_visit(object["geometry"], name, state, depth + 1)
			else:
				state["warnings"].append("Se omitió una Feature sin geometría.")
		"FeatureCollection", "GeometryCollection":
			var key: String = "features" if object["type"] == "FeatureCollection" else "geometries"
			var children: Variant = object.get(key)
			if not children is Array:
				state["error"] = "La colección GeoJSON no contiene una lista " + key + "."
				return
			for child: Variant in children:
				_visit(child, name, state, depth + 1)
		"LineString":
			_line(object.get("coordinates"), name, state)
		"MultiLineString":
			var lines: Variant = object.get("coordinates")
			if not lines is Array:
				state["error"] = "MultiLineString requiere una lista de líneas."
				return
			for i: int in range(lines.size()):
				_line(lines[i], name + " · segmento " + str(i + 1), state)
		"Point", "MultiPoint", "Polygon", "MultiPolygon":
			state["warnings"].append("Se omitió geometría " + str(object["type"]) + "; no es un trazado lineal.")
		_:
			state["error"] = "Tipo GeoJSON desconocido."

static func _line(value: Variant, name: String, state: Dictionary) -> void:
	if not str(state["error"]).is_empty():
		return
	if not value is Array or value.size() < 2:
		state["error"] = "Una LineString debe contener al menos dos posiciones."
		return
	var points: Array[Dictionary] = []
	for raw: Variant in value:
		if not raw is Array or raw.size() < 2:
			state["error"] = "Posición GeoJSON inválida; usa [lon, lat, ele opcional]."
			return
		var lon: Variant = Values.number(raw[0])
		var lat: Variant = Values.number(raw[1])
		var ele: Variant = Values.number(raw[2]) if raw.size() > 2 else null
		if lat == null or lon == null or absf(float(lat)) > 90.0 or absf(float(lon)) > 180.0:
			state["error"] = "Latitud/longitud GeoJSON inválida. El orden es [lon, lat]."
			return
		if raw.size() > 2 and raw[2] != null and ele == null:
			state["error"] = "Altitud GeoJSON inválida; usa metros finitos o null."
			return
		points.append({"lat": lat, "lon": lon, "ele": ele,
			"elevation_source": "geojson" if ele != null else "missing", "source_index": points.size()})
		state["count"] += 1
		if int(state["count"]) > MAX_POINTS:
			state["error"] = "El GeoJSON supera 20 000 puntos; importa un tramo menor sin truncarlo."
			return
	state["routes"].append({"name": name, "source": "geojson", "points": points})
	if state["routes"].size() > 256:
		state["error"] = "El GeoJSON contiene más de 256 rutas o segmentos."
