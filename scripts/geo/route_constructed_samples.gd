class_name RouteConstructedSamples
extends RefCounted
## Reuse the road's pure sampler so spline overshoot is measured, not guessed.

const Values = preload("res://scripts/geo/geo_value.gd")
const Sampler = preload("res://scripts/tracks/track_sampler.gd")

static func collect(definition: Dictionary) -> Dictionary:
	var input: Variant = definition.get("points", [])
	if not input is Array or input.size() < 2:
		return Values.fail("No hay suficientes controles para analizar la pista.")
	var prepared: Dictionary = definition.duplicate(true)
	var interpolation: String = str(definition.get("interpolation", "catmull_rom"))
	var complete: bool = true
	for point: Variant in prepared["points"]:
		if not point is Dictionary or Values.number(point.get("x")) == null or Values.number(point.get("z")) == null:
			return Values.fail("La pista contiene un control horizontal inválido.")
		if point.get("y") != null and Values.number(point["y"]) == null:
			return Values.fail("La pista contiene una altura inválida.")
		complete = complete and point.get("y") != null
		point["width"] = point.get("width", 12.0)
		point["bank"] = point.get("bank", 0.0)
		point["surface"] = point.get("surface", "asphalt")
	if interpolation == "linear" or not complete:
		return {"ok": true, "points": prepared["points"], "geometry_exact": interpolation == "linear" and complete,
			"profile_source": "constructed_linear" if complete else "unbuilt_control_polyline"}
	var spacing: Variant = Values.number(prepared.get("sample_spacing", 4.0))
	if spacing == null or float(spacing) <= 0.0:
		return Values.fail("La separación de muestras de la pista es inválida.")
	prepared["sample_spacing"] = clampf(float(spacing), 2.0, 12.0)
	var count: int = input.size() if bool(definition.get("closed", true)) else input.size() - 1
	var estimate: int = 0
	for i: int in range(count):
		var a: Dictionary = input[i]
		var b: Dictionary = input[(i + 1) % input.size()]
		var length: float = Vector3(float(a["x"]), float(a["y"]), float(a["z"])).distance_to(Vector3(float(b["x"]), float(b["y"]), float(b["z"])))
		estimate += maxi(12, ceili(length / float(prepared["sample_spacing"]) * 1.15))
	if estimate > 20000:
		return Values.fail("El perfil de la malla supera 20 000 muestras; aumenta sample_spacing o divide la pista.")
	var sampler: RefCounted = Sampler.new()
	sampler.rebuild(prepared)
	var points: Array[Dictionary] = []
	for sample: Dictionary in sampler.samples:
		var position: Vector3 = sample["position"]
		var index: int = int(sample["control_index"])
		var control: Dictionary = input[index]
		points.append({"x": float(position.x), "y": float(position.y), "z": float(position.z),
			"control_index": index, "raw_index": int(control.get("raw_index", -1)),
			"source_index": int(control.get("source_index", index)), "elevation_source": "interpolated_model"})
	return {"ok": true, "points": points, "geometry_exact": true, "profile_source": "constructed_track_samples"}
