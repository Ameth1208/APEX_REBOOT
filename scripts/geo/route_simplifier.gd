class_name RouteSimplifier
extends RefCounted
## Bounded Ramer-Douglas-Peucker splitting with separate plan/height tolerances.
## Missing-height boundaries and vertical steps are mandatory; no forced decimation.

const Values = preload("res://scripts/geo/geo_value.gd")
const MAX_CONTROLS: int = 512
const PLAN_TOLERANCE_M: float = 1.0
const HEIGHT_TOLERANCE_M: float = 0.15

static func select(points: Array) -> Dictionary:
	var count: int = points.size()
	if count <= MAX_CONTROLS:
		return {"ok": true, "indices": range(count), "simplified": false}
	var required: Dictionary = {0: true, count - 1: true}
	for i: int in range(1, count):
		var previous: Dictionary = points[i - 1]
		var current: Dictionary = points[i]
		var missing_boundary: bool = (previous.get("y") == null) != (current.get("y") == null)
		var vertical: bool = _xz(previous).distance_to(_xz(current)) < 0.001 and previous.get("y") != current.get("y")
		if missing_boundary or vertical:
			required[i - 1] = true
			required[i] = true
	if required.size() > MAX_CONTROLS:
		return Values.fail("Los huecos de cota requieren más de 512 controles; selecciona un tramo menor.")
	var kept: Array = required.keys()
	kept.sort()
	var segments: Array[Dictionary] = []
	for i: int in range(kept.size() - 1):
		segments.append(_segment(points, int(kept[i]), int(kept[i + 1])))
	while true:
		var best: int = -1
		var error: float = 1.0
		for i: int in range(segments.size()):
			if float(segments[i]["error"]) > error:
				error = float(segments[i]["error"])
				best = i
		if best < 0:
			break
		if kept.size() >= MAX_CONTROLS:
			return Values.fail("La geometría necesita más de 512 controles para conservar giros y cotas (1 m / 0.15 m). Divide la ruta.")
		var segment: Dictionary = segments[best]
		var split: int = int(segment["split"])
		kept.append(split)
		segments[best] = _segment(points, int(segment["first"]), split)
		segments.append(_segment(points, split, int(segment["last"])))
	kept.sort()
	return {"ok": true, "indices": kept, "simplified": true,
		"plan_tolerance_m": PLAN_TOLERANCE_M, "height_tolerance_m": HEIGHT_TOLERANCE_M}

static func _segment(points: Array, first: int, last: int) -> Dictionary:
	var a: Dictionary = points[first]
	var b: Dictionary = points[last]
	var edge: Vector2 = _xz(b) - _xz(a)
	var edge_squared: float = edge.length_squared()
	var worst: float = 0.0
	var split: int = -1
	for i: int in range(first + 1, last):
		var p: Dictionary = points[i]
		var ratio: float = clampf((_xz(p) - _xz(a)).dot(edge) / edge_squared, 0.0, 1.0) if edge_squared > 0.000001 else float(i - first) / float(last - first)
		var error: float = _xz(p).distance_to(_xz(a) + edge * ratio) / PLAN_TOLERANCE_M
		if p.get("y") != null:
			if a.get("y") == null or b.get("y") == null:
				error = INF
			else:
				error = maxf(error, absf(float(p["y"]) - lerpf(float(a["y"]), float(b["y"]), ratio)) / HEIGHT_TOLERANCE_M)
		if error > worst:
			worst = error
			split = i
	return {"first": first, "last": last, "split": split, "error": worst}

static func _xz(point: Dictionary) -> Vector2:
	return Vector2(float(point["x"]), float(point["z"]))
