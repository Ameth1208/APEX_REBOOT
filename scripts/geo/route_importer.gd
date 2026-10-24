class_name RouteImporter
extends RefCounted
## Pure import boundary. Successful parsing with unknown heights is preview-only.

const LocalProjection = preload("res://scripts/geo/geo_projection.gd")
const Values = preload("res://scripts/geo/geo_value.gd")
const Gpx = preload("res://scripts/geo/gpx_reader.gd")
const GeoJson = preload("res://scripts/geo/geojson_reader.gd")
const Simplifier = preload("res://scripts/geo/route_simplifier.gd")
const ElevationSampling = preload("res://scripts/geo/route_elevation_sampling.gd")
const Provenance = preload("res://scripts/geo/route_provenance.gd")
const Recon = preload("res://scripts/geo/route_recon.gd")
const MAX_RAW_POINTS: int = 20000
const MAX_CONTROL_POINTS: int = 512

static func parse(text: String, format: String, route_index: int = 0) -> Dictionary:
	var kind: String = format.strip_edges().to_lower().trim_prefix(".")
	if kind in ["", "auto"]:
		kind = "gpx" if text.strip_edges().begins_with("<") else "geojson"
	var parsed: Dictionary
	match kind:
		"gpx", "xml": parsed = Gpx.read(text)
		"geojson", "json": parsed = GeoJson.read(text)
		_: return Values.fail("Formato no admitido. Usa GPX o GeoJSON.")
	if not parsed["ok"]:
		return parsed
	var routes: Array[Dictionary] = []
	for route: Dictionary in parsed["routes"]:
		routes.append(_summary(route["points"], str(route["name"]), str(route["source"]), routes.size()))
	if route_index < 0 or route_index >= routes.size():
		var failure: Dictionary = Values.fail("Selecciona un índice de ruta válido.")
		failure["routes"] = routes
		return failure
	var selected: Dictionary = parsed["routes"][route_index]
	var result: Dictionary = from_points(selected["points"], str(selected["name"]), str(selected["source"]))
	result["routes"] = routes
	result["selected_route"] = route_index
	result["warnings"] = parsed["warnings"] + result.get("warnings", [])
	# Apply top-level GeoJSON properties (e.g. track_width_m).
	if parsed.has("properties") and result.get("ok", false):
		var props: Dictionary = parsed["properties"]
		if props.has("track_width_m") and result.get("definition") != null:
			var w: float = clampf(float(props["track_width_m"]), 6.0, 30.0)
			for p: Dictionary in result["definition"]["points"]:
				p["width"] = w
		if props.has("name") and result.get("definition") != null:
			result["definition"]["name"] = str(props["name"]).left(160)
	# Auto-detect road properties from OSM so the user doesn't need to configure.
	if result.get("ok", false) and result.get("definition") != null:
		var recon: Dictionary = Recon.analyse(result["definition"])
		if recon.get("ok", false):
			Recon.apply(result["definition"], recon)
			result["recon"] = recon
	return result

static func from_points(points: Array, name: String = "Mi ruta real", source: String = "map", closed: bool = false) -> Dictionary:
	if points.size() < 2 or points.size() > MAX_RAW_POINTS:
		return Values.fail("Se requieren de 2 a 20 000 puntos por ruta; no se truncan datos.")
	var raw: Array[Dictionary] = []
	var first_alt: Variant = null
	var first_alt_index: int = -1
	var elevation_count: int = 0
	var sources: Array[String] = []
	for i: int in range(points.size()):
		if not points[i] is Dictionary:
			return Values.fail("Punto " + str(i + 1) + " inválido; se requieren lat, lon y ele opcional.")
		var point: Dictionary = points[i].duplicate(true)
		if Values.number(point.get("lat")) == null or Values.number(point.get("lon")) == null:
			return Values.fail("Latitud/longitud no numérica en el punto " + str(i + 1) + ".")
		if point.get("ele") != null and (Values.number(point["ele"]) == null or absf(float(point["ele"])) > 1000000.0):
			return Values.fail("Cota no válida en el punto " + str(i + 1) + "; expresa metros finitos.")
		point["lat"] = float(point["lat"])
		point["lon"] = float(point["lon"])
		point["ele"] = Values.number(point.get("ele"))
		point["source_index"] = int(point.get("source_index", i)) if Values.number(point.get("source_index", i)) != null else i
		point["elevation_source"] = str(point.get("elevation_source", source)) if point["ele"] != null else "missing"
		if point["ele"] != null:
			elevation_count += 1
			if first_alt == null:
				first_alt = point["ele"]
				first_alt_index = i
			if not str(point["elevation_source"]) in sources:
				sources.append(str(point["elevation_source"]))
		raw.append(point)
	var geo: Dictionary = LocalProjection.make_origin(float(raw[0]["lat"]), float(raw[0]["lon"]), first_alt)
	geo.merge({"origin_alt_source_index": first_alt_index, "source": source,
		"elevation_status": "complete" if elevation_count == raw.size() else ("missing" if elevation_count == 0 else "partial"),
		"elevation_source": sources[0] if sources.size() == 1 else ("missing" if sources.is_empty() else "mixed"),
		"elevation_sources": sources, "elevation_datum": "unspecified", "raw_point_count": raw.size(), "raw_closed": closed})
	var projected: Array[Dictionary] = []
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	var horizontal: float = 0.0
	var vertical_steps: int = 0
	for i: int in range(raw.size()):
		var local: Dictionary = LocalProjection.project(float(raw[i]["lat"]), float(raw[i]["lon"]), raw[i]["ele"], geo)
		if not local["ok"]:
			return local
		var position: Vector2 = Vector2(float(local["x"]), float(local["z"]))
		minimum = minimum.min(position)
		maximum = maximum.max(position)
		if not projected.is_empty():
			var previous: Dictionary = projected[-1]
			var distance: float = position.distance_to(Vector2(float(previous["x"]), float(previous["z"])))
			horizontal += distance
			if distance < 0.001 and local["y"] != null and previous["y"] != null and absf(float(local["y"]) - float(previous["y"])) > 0.001:
				vertical_steps += 1
		projected.append({"x": local["x"], "y": local["y"], "z": local["z"],
			"width": 12.0, "bank": 0.0, "surface": "asphalt", "raw_index": i,
			"source_index": raw[i]["source_index"], "elevation_source": raw[i]["elevation_source"]})
	if minimum.distance_to(maximum) > LocalProjection.MAX_EXTENT_M:
		return Values.fail("La extensión total de la ruta supera 40 km; selecciona un tramo menor.")
	if horizontal < 0.1:
		return Values.fail("La ruta no tiene recorrido horizontal suficiente; revisa puntos repetidos o verticales.")
	var removed_closing_duplicate: bool = false
	if closed and _same_position(projected[0], projected[-1]):
		projected.pop_back()
		removed_closing_duplicate = true
	if closed and projected.size() < 4:
		return Values.fail("Un circuito cerrado requiere al menos cuatro controles distintos del duplicado de cierre.")
	var simplified: Dictionary = Simplifier.select(projected)
	if not simplified["ok"]:
		return simplified
	if closed and simplified["indices"].size() < 4:
		for candidate: int in range(projected.size()):
			if not candidate in simplified["indices"]:
				simplified["indices"].append(candidate)
			if simplified["indices"].size() >= 4:
				break
		simplified["indices"].sort()
	var controls: Array[Dictionary] = []
	var control_route: Array[Dictionary] = []
	for index: Variant in simplified["indices"]:
		controls.append(projected[int(index)])
		var geographic: Dictionary = raw[int(index)].duplicate(true)
		geographic["raw_index"] = int(index)
		control_route.append(geographic)
	geo["control_point_count"] = controls.size()
	geo["extent_m"] = minimum.distance_to(maximum)
	geo["simplification"] = simplified.duplicate(true)
	geo["simplification"].erase("indices")
	var warnings: Array[String] = []
	if removed_closing_duplicate:
		warnings.append("Se retiró el duplicado de cierre de los controles; el original se conserva íntegro.")
	if elevation_count < raw.size():
		warnings.append("Hay " + str(raw.size() - elevation_count) + " cotas desconocidas. Completa la elevación o elige plano explícitamente antes de construir.")
	if bool(simplified["simplified"]):
		warnings.append("Modelo reducido a " + str(controls.size()) + " controles; se conserva la ruta original y se declaran las tolerancias.")
	if vertical_steps > 0:
		warnings.append("Hay saltos verticales sin avance horizontal; revisa el trazado antes de conducir.")
	var definition: Dictionary = {"version": 2, "name": name.left(160), "description": "Trazado geográfico importado; verificar cotas y geometría.",
		"closed": closed, "interpolation": "catmull_rom", "points": controls, "raw_route": raw, "control_route": control_route,
		"geo": geo, "requires_elevation": elevation_count < raw.size(), "requires_geometry_review": vertical_steps > 0,
		"sample_spacing": 3.0, "thickness": 1.1, "runoff_width": 4.0, "runoff_surface": "gravel",
		"terrain_surface": "grass", "terrain_hills": 0.0, "barriers": true, "construction_mode": "faithful"}
	return {"ok": true, "error": "", "definition": definition, "warnings": warnings,
		"routes": [_summary(raw, name, source, 0)], "selected_route": 0}

static func elevation_samples(definition: Dictionary, spacing_m: float = 50.0) -> Dictionary:
	return ElevationSampling.sample(definition, spacing_m)

static func attach_original(definition: Dictionary, original: Array, original_closed: bool = false) -> Dictionary:
	return Provenance.attach_original(definition, original, original_closed)

static func _same_position(a: Dictionary, b: Dictionary) -> bool:
	return absf(float(a["x"]) - float(b["x"])) < 0.001 and absf(float(a["z"]) - float(b["z"])) < 0.001 and a.get("y") == b.get("y")

static func _summary(points: Array, name: String, source: String, index: int) -> Dictionary:
	var count: int = 0
	for point: Dictionary in points:
		if point.get("ele") != null:
			count += 1
	return {"index": index, "name": name, "source": source, "point_count": points.size(), "elevation_count": count}
