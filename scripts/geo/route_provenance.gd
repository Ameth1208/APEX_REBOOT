class_name RouteProvenance
extends RefCounted
## Reattach immutable source observations after a DEM/model edit without false IDs.

const LocalProjection = preload("res://scripts/geo/geo_projection.gd")
const Values = preload("res://scripts/geo/geo_value.gd")

static func current_controls(definition: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var points: Variant = definition.get("points", [])
	var snapshots: Variant = definition.get("control_route", [])
	var geo: Variant = definition.get("geo", {})
	if not points is Array or not snapshots is Array or not geo is Dictionary:
		return []
	for i: int in range(points.size()):
		if not points[i] is Dictionary:
			return []
		var point: Dictionary = points[i]
		if Values.number(point.get("x")) == null or Values.number(point.get("z")) == null:
			return []
		var position: Dictionary = LocalProjection.inverse(float(point["x"]), float(point["z"]), geo, point.get("y"))
		if not position["ok"]:
			return []
		var raw: Dictionary = snapshots[i].duplicate(true) if i < snapshots.size() and snapshots[i] is Dictionary else {}
		var edited: bool = not raw.is_empty() and (not _same_coordinate(raw, position) or raw.get("ele") != position.get("ele"))
		raw.merge({"lat": position["lat"], "lon": position["lon"], "ele": position["ele"],
			"raw_index": int(point.get("raw_index", raw.get("raw_index", -1))),
			"elevation_source": "edited_model" if edited else str(raw.get("elevation_source", point.get("elevation_source", "model"))),
			"source_index": int(point.get("source_index", raw.get("source_index", i)))}, true)
		if position["ele"] == null:
			raw["elevation_source"] = "missing"
		result.append(raw)
	return result

static func attach_original(definition: Dictionary, original: Array, original_closed: bool = false) -> Dictionary:
	var result: Dictionary = definition.duplicate(true)
	var original_copy: Array = original.duplicate(true)
	var lookup: Dictionary = {}
	for i: int in range(original_copy.size()):
		if not original_copy[i] is Dictionary:
			continue
		var point: Dictionary = original_copy[i]
		if Values.number(point.get("lat")) != null and Values.number(point.get("lon")) != null:
			var key: String = _key(point)
			if not lookup.has(key):
				lookup[key] = []
			lookup[key].append(i)
	var controls: Array[Dictionary] = current_controls(definition)
	for point: Dictionary in result.get("points", []):
		point["raw_index"] = -1
	for i: int in range(controls.size()):
		var point: Dictionary = controls[i]
		var candidate: int = int(point.get("original_raw_index", -1))
		var index: int = -1
		if candidate >= 0 and candidate < original_copy.size() and original_copy[candidate] is Dictionary and _same_coordinate(point, original_copy[candidate]):
			index = candidate
		else:
			var matches: Array = lookup.get(_key(point), [])
			# Coincident crossing/bridge points need a retained source ID, not a guess.
			for possible: Variant in matches if matches.size() == 1 else []:
				if _same_coordinate(point, original_copy[int(possible)]):
					index = int(possible)
					break
		point["raw_index"] = index
		point["original_raw_index"] = index
		result["points"][i]["raw_index"] = index
	result["control_route"] = controls
	result["raw_route"] = original_copy
	if not result.has("geo"):
		result["geo"] = {}
	result["geo"]["raw_closed"] = original_closed
	result["geo"]["raw_point_count"] = original_copy.size()
	result["geo"]["original_preserved"] = true
	return result

static func _same_coordinate(a: Dictionary, b: Dictionary) -> bool:
	if Values.number(a.get("lat")) == null or Values.number(a.get("lon")) == null or Values.number(b.get("lat")) == null or Values.number(b.get("lon")) == null:
		return false
	return absf(float(a["lat"]) - float(b["lat"])) < 0.00000001 and absf(float(a["lon"]) - float(b["lon"])) < 0.00000001

static func _key(point: Dictionary) -> String:
	return "%.8f,%.8f" % [float(point["lat"]), float(point["lon"])]
