class_name RouteAnalyser
extends RefCounted
## Model and original route are independent profiles with explicit provenance.

const Values = preload("res://scripts/geo/geo_value.gd")
const LocalProjection = preload("res://scripts/geo/geo_projection.gd")
const Profile = preload("res://scripts/geo/route_profile.gd")
const Grades = preload("res://scripts/geo/grade_window.gd")
const Constructed = preload("res://scripts/geo/route_constructed_samples.gd")

static func analyse(definition: Dictionary, window_m: float = 100.0) -> Dictionary:
	if not is_finite(window_m) or window_m <= 0.0:
		return Values.fail("La ventana de pendiente debe ser positiva y finita.")
	var points: Variant = definition.get("points", [])
	if not points is Array:
		return Values.fail("La definición no contiene una lista de puntos.")
	var geo: Dictionary = definition.get("geo", {})
	var closed: bool = bool(definition.get("closed", true))
	var sampled: Dictionary = Constructed.collect(definition)
	if not sampled["ok"]:
		return sampled
	var constructed: Dictionary = Profile.build(sampled["points"], geo, closed, "constructed")
	if not constructed["ok"]:
		return constructed
	Grades.apply(constructed, window_m)
	constructed["profile_source"] = sampled["profile_source"]
	constructed["geometry_exact"] = sampled["geometry_exact"]
	constructed["interpolation"] = str(definition.get("interpolation", "catmull_rom"))
	if not sampled["geometry_exact"]:
		constructed["warnings"].append("Faltan cotas: todavía no existe una geometría completa construible; se muestra la polilínea de controles con huecos.")
	var result: Dictionary = constructed.duplicate(true)
	result["constructed"] = constructed
	result["raw"] = {}
	result["raw_profile"] = []
	var original: Variant = definition.get("raw_route", [])
	if original is Array and not original.is_empty():
		var raw: Dictionary = _raw_profile(original, geo, bool(geo.get("raw_closed", false)), window_m)
		result["raw"] = raw
		if raw["ok"]:
			result["raw_profile"] = raw["profile"]
			result["comparison"] = {"horizontal_distance_delta_m": float(constructed["horizontal_distance_m"]) - float(raw["horizontal_distance_m"]),
				"elevation_gain_delta_m": float(constructed["elevation_gain_m"]) - float(raw["elevation_gain_m"]) if constructed["elevation_gain_m"] != null and raw["elevation_gain_m"] != null else null}
		else:
			result["warnings"].append("No se pudo analizar el original: " + str(raw["error"]))
	return result

static func _raw_profile(raw: Array, geo: Dictionary, closed: bool, window_m: float) -> Dictionary:
	if raw.size() > 20000:
		return Values.fail("El perfil original supera 20 000 puntos.")
	var local: Array[Dictionary] = []
	for i: int in range(raw.size()):
		if not raw[i] is Dictionary:
			return Values.fail("Punto original inválido.")
		var point: Dictionary = raw[i]
		if Values.number(point.get("lat")) == null or Values.number(point.get("lon")) == null:
			return Values.fail("Coordenada original inválida.")
		var projected: Dictionary = LocalProjection.project(float(point["lat"]), float(point["lon"]), point.get("ele"), geo)
		if not projected["ok"]:
			return projected
		local.append({"x": projected["x"], "y": projected["y"], "z": projected["z"],
			"raw_index": i, "source_index": int(point.get("source_index", i)),
			"elevation_source": str(point.get("elevation_source", "missing"))})
	var summary: Dictionary = Profile.build(local, geo, closed, "raw")
	if summary["ok"]:
		Grades.apply(summary, window_m)
		summary["profile_source"] = "original_geographic_route"
	return summary
