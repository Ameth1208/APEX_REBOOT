class_name TrackSampler
extends RefCounted

var samples: Array[Dictionary] = []
var length_m: float = 0.0
var closed: bool = true
var interpolation: String = "catmull_rom"
var _query_index = preload("res://scripts/tracks/track_query_index.gd").new()

func rebuild(definition: Dictionary) -> void:
	samples.clear()
	_query_index.clear()
	length_m = 0.0
	closed = bool(definition.get("closed", true))
	interpolation = str(definition.get("interpolation", "catmull_rom"))
	var points: Array = definition["points"]
	if points.size() < 2:
		return
	var spacing: float = float(definition.get("sample_spacing", 4.0))
	var smooth_height: bool = bool(definition.get("smooth_vertical_profile", str(definition.get("geo", {}).get("elevation_datum", "")) == "provider_dem"))
	var segment_count: int = points.size() if closed else points.size() - 1
	for index: int in range(segment_count):
		var p0: Dictionary = points[_point_index(index - 1, points.size())]
		var p1: Dictionary = points[index]
		var p2: Dictionary = points[_point_index(index + 1, points.size())]
		var p3: Dictionary = points[_point_index(index + 2, points.size())]
		var a: Vector3 = TrackDefinition.position(p1)
		var b: Vector3 = TrackDefinition.position(p2)
		var divisions: int = maxi(1, ceili(a.distance_to(b) / spacing)) if interpolation == "linear" else maxi(12, ceili(a.distance_to(b) / spacing * 1.15))
		for step: int in range(divisions):
			var t: float = float(step) / float(divisions)
			var point: Vector3 = a.lerp(b, t) if interpolation == "linear" else catmull(TrackDefinition.position(p0), a, b, TrackDefinition.position(p3), t)
			if smooth_height and interpolation == "linear":
				point.y = preload("res://scripts/tracks/vertical_profile.gd").height(TrackDefinition.position(p0), a, b, TrackDefinition.position(p3), t)
			_append(point, p1, p2, t, index)
	if not closed:
		_append(TrackDefinition.position(points[-1]), points[-1], points[-1], 0.0, points.size() - 1)
	elif samples.size() > 1:
		length_m += samples[-1]["position"].distance_to(samples[0]["position"])
	if smooth_height and str(definition.get("geo", {}).get("elevation_datum", "")) == "provider_dem":
		preload("res://scripts/tracks/vertical_profile.gd").filter_dem(samples, closed, length_m)
		length_m = 0.0
		for i: int in samples.size():
			if i > 0: length_m += Vector3(samples[i - 1].position).distance_to(samples[i].position)
			samples[i].distance = length_m
		if closed and samples.size() > 1: length_m += Vector3(samples[-1].position).distance_to(samples[0].position)
	_update_frames()
	_query_index.rebuild(samples, length_m, closed)

func _append(point: Vector3, a: Dictionary, b: Dictionary, t: float, index: int) -> void:
	if not samples.is_empty():
		length_m += point.distance_to(samples[-1]["position"])
	samples.append({"position": point, "distance": length_m,
		"width": lerpf(float(a["width"]), float(b["width"]), smoothstep(0.0, 1.0, t)),
		"bank": lerpf(float(a["bank"]), float(b["bank"]), smoothstep(0.0, 1.0, t)),
		"surface": str(a["surface"]), "control_index": index, "raw_index": int(a.get("raw_index", index))})

func _update_frames() -> void:
	for index: int in range(samples.size()):
		var previous: Vector3 = samples[_point_index(index - 1, samples.size())]["position"]
		var following: Vector3 = samples[_point_index(index + 1, samples.size())]["position"]
		var forward: Vector3 = (following - previous).normalized()
		if forward.length_squared() < 0.1:
			forward = Vector3.FORWARD
		var right: Vector3 = forward.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.1:
			right = Vector3.RIGHT
		var normal: Vector3 = right.cross(forward).normalized()
		normal = normal.rotated(forward, deg_to_rad(float(samples[index]["bank"])))
		samples[index]["forward"] = forward
		samples[index]["normal"] = normal
		samples[index]["right"] = forward.cross(normal).normalized()

func _point_index(index: int, count: int) -> int:
	return posmod(index, count) if closed else clampi(index, 0, count - 1)

func normalize_distance(distance: float) -> float:
	return fposmod(distance, maxf(length_m, 0.001)) if closed else clampf(distance, 0.0, length_m)

func sample_at(distance: float) -> Dictionary:
	if samples.is_empty() or length_m <= 0.01:
		return {"position": Vector3.ZERO, "forward": Vector3.FORWARD, "normal": Vector3.UP, "right": Vector3.RIGHT, "width": 12.0, "bank": 0.0, "surface": "asphalt", "distance": 0.0}
	var normalized: float = normalize_distance(distance)
	var low: int = 0
	var high: int = samples.size() - 1
	while low < high:
		var mid: int = (low + high + 1) / 2
		if float(samples[mid]["distance"]) <= normalized:
			low = mid
		else:
			high = mid - 1
	var a: Dictionary = samples[low]
	var b: Dictionary = samples[_point_index(low + 1, samples.size())]
	var end: float = length_m if low == samples.size() - 1 else float(b["distance"])
	var ratio: float = clampf((normalized - float(a["distance"])) / maxf(0.001, end - float(a["distance"])), 0.0, 1.0)
	var forward: Vector3 = a["forward"].lerp(b["forward"], ratio).normalized()
	var normal_hint: Vector3 = a["normal"].lerp(b["normal"], ratio).normalized()
	var right: Vector3 = forward.cross(normal_hint).normalized()
	return {"position": a["position"].lerp(b["position"], ratio), "forward": forward,
		"normal": right.cross(forward).normalized(), "right": right,
		"width": lerpf(float(a["width"]), float(b["width"]), ratio),
		"bank": lerpf(float(a["bank"]), float(b["bank"]), ratio),
		"surface": str(a["surface"]), "distance": normalized}

func closest_distance(point: Vector3, hint: float = -1.0) -> float:
	return _query_index.closest(point, hint)

static func catmull(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)
