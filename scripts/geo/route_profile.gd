class_name RouteProfile
extends RefCounted
## Accumulate a 3D polyline without treating unknown heights as zero.

const Values = preload("res://scripts/geo/geo_value.gd")
const EPSILON_M: float = 0.000001

static func build(input: Array, geo: Dictionary, closed: bool, kind: String) -> Dictionary:
	if input.size() < 2 or input.size() > 20000:
		return Values.fail("El perfil requiere entre 2 y 20 000 puntos.")
	var points: Array = input.duplicate(true)
	for raw: Variant in points:
		if not raw is Dictionary or Values.number(raw.get("x")) == null or Values.number(raw.get("z")) == null:
			return Values.fail("El perfil contiene una posición horizontal inválida.")
		if raw.get("y") != null and Values.number(raw.get("y")) == null:
			return Values.fail("El perfil contiene una altura inválida.")
	if closed and not _same(points[0], points[-1]):
		var closing: Dictionary = points[0].duplicate(true)
		closing["closing_sample"] = true
		points.append(closing)
	var altitude: Variant = Values.number(geo.get("origin_alt_m"))
	var profile: Array[Dictionary] = []
	var distances: PackedFloat64Array = []
	var heights: Array = []
	var bad_prefix: PackedInt32Array = []
	var vertical_distances: PackedFloat64Array = []
	var horizontal: float = 0.0
	var known_horizontal: float = 0.0
	var known_3d: float = 0.0
	var gain: float = 0.0
	var loss: float = 0.0
	var minimum: float = INF
	var maximum: float = -INF
	var complete: bool = true
	var known_count: int = 0
	var bad_count: int = 0
	var duplicates: int = 0
	for i: int in range(points.size()):
		var p: Dictionary = points[i]
		var height: Variant = Values.number(p.get("y"))
		if height == null:
			complete = false
		else:
			known_count += 1
			minimum = minf(minimum, float(height))
			maximum = maxf(maximum, float(height))
		var segment_valid: bool = height != null
		if i > 0:
			var previous: Dictionary = points[i - 1]
			var dx: float = float(p["x"]) - float(previous["x"])
			var dz: float = float(p["z"]) - float(previous["z"])
			var distance: float = sqrt(dx * dx + dz * dz)
			if not is_finite(distance):
				return Values.fail("Distancia horizontal fuera de rango numérico.")
			horizontal += distance
			segment_valid = height != null and previous.get("y") != null
			if segment_valid:
				var dy: float = float(height) - float(previous["y"])
				known_3d += sqrt(distance * distance + dy * dy)
				known_horizontal += distance
				gain += maxf(0.0, dy)
				loss += maxf(0.0, -dy)
				if distance < EPSILON_M and absf(dy) > EPSILON_M:
					vertical_distances.append(horizontal)
					segment_valid = false
				elif distance < EPSILON_M:
					duplicates += 1
			if not segment_valid:
				bad_count += 1
		distances.append(horizontal)
		heights.append(height)
		bad_prefix.append(bad_count)
		profile.append({"distance_m": horizontal, "horizontal_distance_m": horizontal,
			"distance_3d_m": known_3d if complete else null, "height_m": height,
			"elevation_m": float(altitude) + float(height) if altitude != null and height != null else null,
			"control_index": int(p.get("control_index", i)) if kind == "constructed" and not p.get("closing_sample", false) else (0 if kind == "constructed" else -1),
			"raw_index": int(p.get("raw_index", i)), "source_index": int(p.get("source_index", i)),
			"elevation_source": str(p.get("elevation_source", "model" if height != null else "missing")),
			"segment_valid": segment_valid, "closing_sample": bool(p.get("closing_sample", false))})
	var warnings: Array[String] = []
	if not complete:
		warnings.append("Cotas incompletas: distancia 3D y desnivel totales desconocidos; known_* solo suma tramos con ambos extremos conocidos.")
	if not vertical_distances.is_empty():
		warnings.append("Hay saltos verticales: su pendiente es indefinida y las ventanas que los tocan se invalidan.")
	if horizontal < EPSILON_M:
		warnings.append("No se calcula pendiente sin recorrido horizontal.")
	return {"ok": true, "error": "", "warnings": warnings, "closed": closed, "profile": profile,
		"horizontal_distance_m": horizontal, "distance_3d_m": known_3d if complete else null,
		"known_distance_3d_m": known_3d, "elevation_gain_m": gain if complete else null,
		"elevation_loss_m": loss if complete else null, "known_elevation_gain_m": gain,
		"known_elevation_loss_m": loss, "min_height_m": minimum if known_count > 0 else null,
		"max_height_m": maximum if known_count > 0 else null,
		"min_elevation_m": float(altitude) + minimum if altitude != null and known_count > 0 else null,
		"max_elevation_m": float(altitude) + maximum if altitude != null and known_count > 0 else null,
		"elevation_complete": complete, "elevation_reference": "absolute" if altitude != null else "local",
		"elevation_coverage": known_horizontal / horizontal if horizontal > EPSILON_M else float(known_count) / float(points.size()),
		"point_elevation_coverage": float(known_count) / float(points.size()),
		"vertical_steps": vertical_distances.size(), "duplicate_points": duplicates,
		"_distances": distances, "_heights": heights, "_bad_prefix": bad_prefix, "_vertical_distances": vertical_distances}

static func _same(a: Dictionary, b: Dictionary) -> bool:
	if absf(float(a["x"]) - float(b["x"])) > EPSILON_M or absf(float(a["z"]) - float(b["z"])) > EPSILON_M:
		return false
	if a.get("y") == null or b.get("y") == null:
		return a.get("y") == b.get("y")
	return absf(float(a["y"]) - float(b["y"])) < EPSILON_M
