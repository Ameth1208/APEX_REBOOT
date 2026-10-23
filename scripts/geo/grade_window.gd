class_name GradeWindow
extends RefCounted
## Signed rise / horizontal arc distance. Invalid spans never bridge elevation gaps.

const EPSILON_M: float = 0.000001

static func apply(summary: Dictionary, requested_m: float) -> void:
	var total: float = float(summary["horizontal_distance_m"])
	var window: float = minf(requested_m, total)
	var closed: bool = bool(summary["closed"])
	var profile: Array = summary["profile"]
	for row: Dictionary in profile:
		var center: float = float(row["distance_m"])
		var start: float = fposmod(center - window * 0.5, total) if closed and total > EPSILON_M else clampf(center - window * 0.5, 0.0, maxf(0.0, total - window))
		row["grade_pct"] = _grade(summary, start, window)
		row["window_m"] = window
		row["grade_start_m"] = start
		row["grade_end_m"] = fposmod(start + window, total) if closed and total > EPSILON_M else start + window
	var uphill: Variant = null
	var downhill: Variant = null
	# For a piecewise-linear height profile, extrema occur when either end of the
	# moving window reaches a vertex. Evaluate both event families, not just centres.
	var candidates: Dictionary = {0.0: true}
	var distances: PackedFloat64Array = summary["_distances"]
	for distance: float in distances:
		for event: float in [distance, distance - window]:
			var start: float = fposmod(event, total) if closed and total > EPSILON_M else clampf(event, 0.0, maxf(0.0, total - window))
			candidates[start] = true
	for start: Variant in candidates:
		var grade: Variant = _grade(summary, float(start), window)
		if grade != null:
			uphill = maxf(float(grade), float(uphill) if uphill != null else 0.0)
			downhill = minf(float(grade), float(downhill) if downhill != null else 0.0)
	summary["window_m"] = window
	summary["requested_window_m"] = requested_m
	summary["max_uphill_pct"] = uphill
	summary["max_downhill_pct"] = downhill
	for key: String in ["_distances", "_heights", "_bad_prefix", "_vertical_distances"]:
		summary.erase(key)

static func _grade(summary: Dictionary, start: float, window: float) -> Variant:
	if window < EPSILON_M:
		return null
	var total: float = float(summary["horizontal_distance_m"])
	var end: float = start + window
	var rise: Variant
	if end <= total + EPSILON_M:
		rise = _rise(summary, start, minf(end, total))
	else:
		var before: Variant = _rise(summary, start, total)
		var after: Variant = _rise(summary, 0.0, end - total)
		if before == null or after == null:
			return null
		rise = float(before) + float(after)
	return float(rise) * 100.0 / window if rise != null else null

static func _rise(summary: Dictionary, start: float, end: float) -> Variant:
	var distances: PackedFloat64Array = summary["_distances"]
	var bad: PackedInt32Array = summary["_bad_prefix"]
	var verticals: PackedFloat64Array = summary["_vertical_distances"]
	var first: int = clampi(_upper_bound(distances, start) - 1, 0, distances.size() - 1)
	var last: int = clampi(_lower_bound(distances, end), 0, distances.size() - 1)
	if bad[last] - bad[first] > 0:
		return null
	var vertical_index: int = _lower_bound(verticals, start - EPSILON_M)
	if vertical_index < verticals.size() and verticals[vertical_index] <= end + EPSILON_M:
		return null
	var a: Variant = _height(summary, start)
	var b: Variant = _height(summary, end)
	return float(b) - float(a) if a != null and b != null else null

static func _height(summary: Dictionary, distance: float) -> Variant:
	var distances: PackedFloat64Array = summary["_distances"]
	var heights: Array = summary["_heights"]
	var index: int = clampi(_upper_bound(distances, distance) - 1, 0, distances.size() - 1)
	if absf(distance - distances[index]) < EPSILON_M or index == distances.size() - 1:
		return heights[index]
	if heights[index] == null or heights[index + 1] == null:
		return null
	var span: float = distances[index + 1] - distances[index]
	if span < EPSILON_M:
		return null
	return lerpf(float(heights[index]), float(heights[index + 1]), (distance - distances[index]) / span)

static func _lower_bound(values: PackedFloat64Array, value: float) -> int:
	var low: int = 0
	var high: int = values.size()
	while low < high:
		var middle: int = (low + high) >> 1
		if values[middle] < value:
			low = middle + 1
		else:
			high = middle
	return low

static func _upper_bound(values: PackedFloat64Array, value: float) -> int:
	var low: int = 0
	var high: int = values.size()
	while low < high:
		var middle: int = (low + high) >> 1
		if values[middle] <= value:
			low = middle + 1
		else:
			high = middle
	return low
