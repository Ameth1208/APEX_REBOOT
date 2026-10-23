class_name RouteSimplifier
extends RefCounted
## Bounded Ramer-Douglas-Peucker splitting with plan/height tolerances and
## angle-based curve preservation. Adaptive: longer routes get coarser
## tolerances so the builder can focus detail where it matters.

const Values = preload("res://scripts/geo/geo_value.gd")
const MAX_CONTROLS: int = 512

static func select(points: Array) -> Dictionary:
	var count: int = points.size()
	if count <= MAX_CONTROLS:
		return {"ok": true, "indices": range(count), "simplified": false}
	# Compute total path length for adaptive tolerances.
	var total_length: float = 0.0
	for i: int in range(1, count):
		total_length += _xz(points[i]).distance_to(_xz(points[i - 1]))
	# Adaptive: short routes keep more detail, long routes simplify harder.
	var plan_tol: float = clampf(1.0 + total_length * 0.0008, 1.0, 4.0)
	var height_tol: float = clampf(0.15 + total_length * 0.00015, 0.15, 0.60)
	var angle_deg: float = clampf(8.0 + total_length * 0.001, 8.0, 22.0)
	var min_spacing: float = clampf(2.0 + total_length * 0.002, 2.0, 12.0)
	var required: Dictionary = {0: true, count - 1: true}
	for i: int in range(1, count):
		var previous: Dictionary = points[i - 1]
		var current: Dictionary = points[i]
		var missing_boundary: bool = (previous.get("y") == null) != (current.get("y") == null)
		var vertical: bool = _xz(previous).distance_to(_xz(current)) < 0.001 and previous.get("y") != current.get("y")
		if missing_boundary or vertical:
			required[i - 1] = true
			required[i] = true
	# Enforce minimum spacing: drop points too close to the previous required one.
	var last_kept_xz: Vector2 = _xz(points[0])
	var last_kept_idx: int = 0
	for i: int in range(1, count - 1):
		if required.has(i):
			last_kept_xz = _xz(points[i])
			last_kept_idx = i
			continue
		if _xz(points[i]).distance_to(last_kept_xz) >= min_spacing:
			# Only keep if it also has a meaningful direction change.
			if _has_curve(points, i, angle_deg):
				required[i] = true
				last_kept_xz = _xz(points[i])
				last_kept_idx = i
	if required.size() > MAX_CONTROLS:
		return Values.fail("Los huecos de cota requieren más de 512 controles; selecciona un tramo menor.")
	var kept: Array = required.keys()
	kept.sort()
	# RDP pass on the pre-filtered points with adaptive tolerances.
	var segments: Array[Dictionary] = []
	for i: int in range(kept.size() - 1):
		segments.append(_segment(points, int(kept[i]), int(kept[i + 1]), plan_tol, height_tol))
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
			return Values.fail("La geometría necesita más de 512 controles. Divide la ruta.")
		var segment: Dictionary = segments[best]
		var split: int = int(segment["split"])
		kept.append(split)
		segments[best] = _segment(points, int(segment["first"]), split, plan_tol, height_tol)
		segments.append(_segment(points, split, int(segment["last"]), plan_tol, height_tol))
	kept.sort()
	return {"ok": true, "indices": kept, "simplified": true,
		"plan_tolerance_m": plan_tol, "height_tolerance_m": height_tol,
		"angle_threshold_deg": angle_deg, "min_spacing_m": min_spacing}

## Check if point i has a meaningful direction change relative to neighbours.
static func _has_curve(points: Array, i: int, threshold_deg: float) -> bool:
	if i <= 0 or i >= points.size() - 1:
		return false
	var prev: Vector2 = _xz(points[i]) - _xz(points[i - 1])
	var next: Vector2 = _xz(points[i + 1]) - _xz(points[i])
	if prev.length_squared() < 0.001 or next.length_squared() < 0.001:
		return false
	var angle: float = rad_to_deg(prev.normalized().angle_to(next.normalized()))
	return absf(angle) >= threshold_deg

static func _segment(points: Array, first: int, last: int, plan_tol: float, height_tol: float) -> Dictionary:
	var a: Dictionary = points[first]
	var b: Dictionary = points[last]
	var edge: Vector2 = _xz(b) - _xz(a)
	var edge_squared: float = edge.length_squared()
	var worst: float = 0.0
	var split: int = -1
	for i: int in range(first + 1, last):
		var p: Dictionary = points[i]
		var ratio: float = clampf((_xz(p) - _xz(a)).dot(edge) / edge_squared, 0.0, 1.0) if edge_squared > 0.000001 else float(i - first) / float(last - first)
		var error: float = _xz(p).distance_to(_xz(a) + edge * ratio) / plan_tol
		if p.get("y") != null:
			if a.get("y") == null or b.get("y") == null:
				error = INF
			else:
				error = maxf(error, absf(float(p["y"]) - lerpf(float(a["y"]), float(b["y"]), ratio)) / height_tol)
		if error > worst:
			worst = error
			split = i
	return {"first": first, "last": last, "split": split, "error": worst}

static func _xz(point: Dictionary) -> Vector2:
	return Vector2(float(point["x"]), float(point["z"]))