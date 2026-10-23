class_name GpxReader
extends RefCounted
## GPX trkseg and rte are separate selectable routes; never bridge a recording gap.

const Values = preload("res://scripts/geo/geo_value.gd")
const MAX_POINTS: int = 20000
const MAX_ROUTES: int = 256

static func read(text: String) -> Dictionary:
	var bytes: PackedByteArray = text.to_utf8_buffer()
	if bytes.size() > 8 * 1024 * 1024:
		return Values.fail("El GPX supera el límite de 8 MiB de texto.")
	if "<!DOCTYPE" in text.to_upper() or "<!ENTITY" in text.to_upper():
		return Values.fail("No se admiten DTD ni entidades externas en GPX.")
	var parser: XMLParser = XMLParser.new()
	if parser.open_buffer(bytes) != OK:
		return Values.fail("No se pudo leer el documento XML GPX.")
	var state: Dictionary = {"routes": [], "warnings": [], "stack": [], "texts": [],
		"route": {}, "point": {}, "track_name": "", "track": 0, "segment": 0,
		"count": 0, "root_seen": false, "error": ""}
	while true:
		var status: Error = parser.read()
		if status == ERR_FILE_EOF:
			break
		if status != OK:
			return Values.fail("XML GPX incompleto o inválido, línea " + str(parser.get_current_line() + 1) + ".")
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag: String = _local(parser.get_node_name())
				_start(tag, parser, state)
				state["stack"].append(tag)
				state["texts"].append("")
				if parser.is_empty():
					_end(tag, state)
			XMLParser.NODE_ELEMENT_END:
				_end(_local(parser.get_node_name()), state)
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				var data: String = parser.get_node_data() if parser.get_node_type() == XMLParser.NODE_TEXT else parser.get_node_name()
				if not state["texts"].is_empty():
					state["texts"][-1] += data
				elif not data.strip_edges().is_empty():
					state["error"] = "Texto fuera del elemento raíz GPX."
		if not str(state["error"]).is_empty():
			return Values.fail(str(state["error"]))
	if not state["root_seen"] or not state["stack"].is_empty():
		return Values.fail("XML GPX incompleto: faltan el elemento gpx o sus cierres.")
	if state["routes"].is_empty():
		return Values.fail("El GPX no contiene segmentos trkseg ni rutas rte con puntos.")
	return {"ok": true, "error": "", "routes": state["routes"], "warnings": state["warnings"]}

static func _start(tag: String, parser: XMLParser, state: Dictionary) -> void:
	var stack: Array = state["stack"]
	var parent: String = str(stack[-1]) if not stack.is_empty() else ""
	if stack.size() > 48:
		state["error"] = "El GPX tiene demasiados niveles XML."
	if parent.is_empty():
		if tag != "gpx" or state["root_seen"]:
			state["error"] = "Se esperaba un único elemento raíz gpx."
		state["root_seen"] = true
	if tag == "trk" and parent == "gpx":
		state["track"] += 1
		state["segment"] = 0
		state["track_name"] = "Track " + str(state["track"])
	elif tag == "trkseg" and _path(stack, ["gpx", "trk"]):
		state["segment"] += 1
		state["route"] = {"name": str(state["track_name"]) + " · segmento " + str(state["segment"]),
			"source": "gpx", "segment_index": state["segment"] - 1, "points": []}
	elif tag == "rte" and parent == "gpx":
		state["route"] = {"name": "Ruta GPX " + str(state["routes"].size() + 1), "source": "gpx", "points": []}
	elif (tag == "trkpt" and _path(stack, ["gpx", "trk", "trkseg"])) or (tag == "rtept" and _path(stack, ["gpx", "rte"])):
		var lat: Variant = Values.text_number(parser.get_named_attribute_value_safe("lat"))
		var lon: Variant = Values.text_number(parser.get_named_attribute_value_safe("lon"))
		if lat == null or lon == null or absf(float(lat)) > 90.0 or absf(float(lon)) > 180.0:
			state["error"] = "Coordenada GPX inválida en el punto " + str(state["count"] + 1) + "."
		state["point"] = {"lat": lat, "lon": lon, "ele": null,
			"elevation_source": "missing", "source_index": state["route"].get("points", []).size()}

static func _end(tag: String, state: Dictionary) -> void:
	var stack: Array = state["stack"]
	if stack.is_empty() or str(stack[-1]) != tag:
		state["error"] = "XML GPX con etiquetas sin correspondencia."
		return
	var value: String = str(state["texts"].pop_back()).strip_edges()
	stack.pop_back()
	if tag == "name" and _path(stack, ["gpx", "trk"]) and not value.is_empty():
		state["track_name"] = value.left(160)
	elif tag == "name" and _path(stack, ["gpx", "rte"]) and not value.is_empty():
		state["route"]["name"] = value.left(160)
	elif tag == "ele" and (_path(stack, ["gpx", "trk", "trkseg", "trkpt"]) or _path(stack, ["gpx", "rte", "rtept"])):
		var ele: Variant = Values.text_number(value)
		if ele == null:
			state["error"] = "Cota GPX inválida; una cota ausente debe omitir ele."
		else:
			state["point"]["ele"] = ele
			state["point"]["elevation_source"] = "gpx"
	elif (tag == "trkpt" and _path(stack, ["gpx", "trk", "trkseg"])) or (tag == "rtept" and _path(stack, ["gpx", "rte"])):
		state["count"] += 1
		if int(state["count"]) > MAX_POINTS:
			state["error"] = "El GPX supera 20 000 puntos; divide el archivo sin truncarlo."
			return
		state["route"]["points"].append(state["point"])
		state["point"] = {}
	elif (tag == "trkseg" and _path(stack, ["gpx", "trk"])) or (tag == "rte" and _path(stack, ["gpx"])):
		var route: Dictionary = state["route"]
		if not route.get("points", []).is_empty():
			state["routes"].append(route)
		else:
			state["warnings"].append("Se omitió un segmento GPX vacío.")
		if state["routes"].size() > MAX_ROUTES:
			state["error"] = "El archivo contiene más de 256 rutas o segmentos."
		state["route"] = {}

static func _path(stack: Array, path: Array) -> bool:
	return stack == path

static func _local(tag: String) -> String:
	return tag.get_slice(":", tag.get_slice_count(":") - 1)
