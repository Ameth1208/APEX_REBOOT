class_name RouteElevationSampling
extends RefCounted
## Sample the plan route before asking for terrain elevation; new heights stay null.

const LocalProjection = preload("res://scripts/geo/geo_projection.gd")
const Values = preload("res://scripts/geo/geo_value.gd")
const Provenance = preload("res://scripts/geo/route_provenance.gd")
const MAX_POINTS: int = 512

static func sample(definition: Dictionary, spacing_m: float = 50.0) -> Dictionary:
	var controls: Variant = Provenance.current_controls(definition)
	if not controls is Array or controls.size() < 2 or controls.size() > MAX_POINTS:
		return Values.fail("El muestreo requiere entre 2 y 512 controles geográficos.")
	if not is_finite(spacing_m) or spacing_m <= 0.0:
		return Values.fail("La separación del muestreo debe ser positiva y finita.")
	var geo: Dictionary = definition.get("geo", {})
	var local: Array[Vector2] = []
	for raw: Variant in controls:
		if not raw is Dictionary or Values.number(raw.get("lat")) == null or Values.number(raw.get("lon")) == null:
			return Values.fail("Control geográfico inválido para el muestreo.")
		var projected: Dictionary = LocalProjection.project(float(raw["lat"]), float(raw["lon"]), null, geo)
		if not projected["ok"]:
			return projected
		local.append(Vector2(float(projected["x"]), float(projected["z"])))
	var closes: bool = bool(definition.get("closed", false)) and local[0].distance_to(local[-1]) > 0.001
	var edges: Array[float] = []
	for i: int in range(controls.size() - 1 + int(closes)):
		edges.append(local[i].distance_to(local[(i + 1) % local.size()]))
	var actual: float = spacing_m
	var warnings: Array[String] = []
	if _count(edges, controls.size(), actual) > MAX_POINTS:
		var low: float = spacing_m
		var high: float = maxf(spacing_m, float(edges.max()))
		for iteration: int in range(48):
			var middle: float = (low + high) * 0.5
			if _count(edges, controls.size(), middle) > MAX_POINTS:
				low = middle
			else:
				high = middle
		actual = high * 1.00000001
		warnings.append("Separación aumentada a " + str(snappedf(actual, 0.1)) + " m para conservar vértices dentro de 512 muestras.")
	var points: Array[Dictionary] = []
	var max_interval: float = 0.0
	for i: int in range(controls.size()):
		var original: Dictionary = controls[i].duplicate(true)
		original["original_raw_index"] = original.get("original_raw_index", original.get("raw_index", -1))
		points.append(original)
		if i >= edges.size():
			continue
		var sections: int = maxi(1, ceili(edges[i] / actual))
		max_interval = maxf(max_interval, edges[i] / float(sections))
		var next: Dictionary = controls[(i + 1) % controls.size()]
		for j: int in range(1, sections):
			var ratio: float = float(j) / float(sections)
			points.append({"lat": lerpf(float(original["lat"]), float(next["lat"]), ratio),
				"lon": lerpf(float(original["lon"]), float(next["lon"]), ratio), "ele": null,
				"elevation_source": "missing", "source_index": -1, "raw_index": -1,
				"original_raw_index": -1, "interpolated": true, "source_segment": i})
	return {"ok": true, "error": "", "points": points, "spacing_m": actual,
		"requested_spacing_m": spacing_m, "max_interval_m": max_interval, "warnings": warnings}

static func _count(edges: Array[float], originals: int, spacing: float) -> int:
	var count: int = originals
	for distance: float in edges:
		count += maxi(0, ceili(distance / spacing) - 1)
	return count
