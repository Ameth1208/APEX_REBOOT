class_name TrackDefinition
extends RefCounted

const SURFACES: Array[String] = ["asphalt", "concrete", "gravel", "dirt", "grass", "sand"]

static func clean(source: Dictionary) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	result["version"] = 2
	result["name"] = str(source.get("name", "Mi circuito"))
	result["description"] = str(source.get("description", "Circuito personalizado"))
	result["closed"] = bool(source.get("closed", true))
	result["interpolation"] = "linear" if source.get("interpolation", "catmull_rom") == "linear" else "catmull_rom"
	result["thickness"] = clampf(float(source.get("thickness", 1.1)), 0.25, 8.0)
	result["runoff_width"] = clampf(float(source.get("runoff_width", 4.0)), 1.0, 12.0)
	result["runoff_surface"] = valid_surface(str(source.get("runoff_surface", "gravel")))
	result["terrain_surface"] = valid_surface(str(source.get("terrain_surface", "grass")))
	result["terrain_type"] = str(source.get("terrain_type", "auto"))
	result["terrain_surface_auto"] = bool(source.get("terrain_surface_auto", false))
	result["terrain_hills"] = clampf(float(source.get("terrain_hills", 8.0)), 0.0, 60.0)
	result["sample_spacing"] = clampf(float(source.get("sample_spacing", 4.0)), 2.0, 12.0)
	result["barriers"] = bool(source.get("barriers", true))
	var construction_mode: String = str(source.get("construction_mode", "faithful"))
	result["construction_mode"] = construction_mode if construction_mode in ["faithful", "race_design"] else "faithful"
	var points: Array[Dictionary] = []
	var source_points: Variant = source.get("points", [])
	if source_points is Array:
		for raw: Variant in source_points:
			if not raw is Dictionary:
				continue
			var p: Dictionary = raw
			var point: Dictionary = {"x": _number(p.get("x", 0.0), -40000.0, 40000.0),
				"y": _number(p.get("y", 0.0), -10000.0, 10000.0),
				"z": _number(p.get("z", 0.0), -40000.0, 40000.0),
				"width": _number(p.get("width", 12.0), 6.0, 30.0),
				"bank": _number(p.get("bank", 0.0), -22.0, 22.0),
				"surface": valid_surface(str(p.get("surface", "asphalt")))}
			if p.has("raw_index"):
				point["raw_index"] = int(p["raw_index"])
			points.append(point)
	if points.size() < (4 if bool(result["closed"]) else 2):
		points = [{"x": 0.0, "y": 2.0, "z": 180.0, "width": 12.0, "bank": 0.0, "surface": "asphalt"},
			{"x": 0.0, "y": 2.0, "z": -180.0, "width": 12.0, "bank": 0.0, "surface": "asphalt"},
			{"x": 300.0, "y": 8.0, "z": -180.0, "width": 12.0, "bank": 3.0, "surface": "asphalt"},
			{"x": 300.0, "y": 8.0, "z": 180.0, "width": 12.0, "bank": 3.0, "surface": "asphalt"}]
	result["points"] = points
	return result

static func position(point: Dictionary) -> Vector3:
	return Vector3(float(point["x"]), float(point["y"]), float(point["z"]))

static func valid_surface(value: String) -> String:
	return value if value in SURFACES else "asphalt"

static func _number(value: Variant, minimum: float, maximum: float) -> float:
	var number: float = float(value)
	return clampf(number, minimum, maximum) if is_finite(number) else minimum
