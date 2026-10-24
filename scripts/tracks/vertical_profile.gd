extends RefCounted
## Shape-preserving vertical easements. Does not change the horizontal route,
## control elevations, bridges, surface materials or the overall relief.

static func height(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> float:
	var h0: float = Vector2(b.x - a.x, b.z - a.z).length()
	var h1: float = Vector2(c.x - b.x, c.z - b.z).length()
	var h2: float = Vector2(d.x - c.x, d.z - c.z).length()
	if h1 < 0.001: return lerpf(b.y, c.y, t)
	var slope: float = (c.y - b.y) / h1
	var left: float = _tangent((b.y - a.y) / maxf(h0, 0.001), slope, h0, h1) if h0 > 0.001 else slope
	var right: float = _tangent(slope, (d.y - c.y) / maxf(h2, 0.001), h1, h2) if h2 > 0.001 else slope
	var t2: float = t * t
	var t3: float = t2 * t
	return (2 * t3 - 3 * t2 + 1) * b.y + (t3 - 2 * t2 + t) * h1 * left + (-2 * t3 + 3 * t2) * c.y + (t3 - t2) * h1 * right

static func _tangent(before: float, after: float, h0: float, h1: float) -> float:
	if before * after <= 0.0: return 0.0
	var w0: float = 2.0 * h1 + h0
	var w1: float = h1 + 2.0 * h0
	return (w0 + w1) / (w0 / before + w1 / after)

static func filter_dem(samples: Array[Dictionary], closed: bool, length_m: float, radius_m: float = 35.0) -> void:
	# DEM pixels are terrain estimates, not a surveyed asphalt profile. Smooth their
	# short-wavelength noise along route station (never across neighbouring roads).
	var heights := PackedFloat32Array()
	heights.resize(samples.size())
	for i: int in samples.size():
		var base: float = Vector3(samples[i].position).y
		var sum: float = base
		var weight_sum: float = 1.0
		var station: float = float(samples[i].distance)
		for direction: int in [-1, 1]:
			for offset: int in range(1, samples.size()):
				var index: int = i + direction * offset
				if not closed and (index < 0 or index >= samples.size()): break
				index = posmod(index, samples.size())
				var distance: float = (float(samples[index].distance) - station) * direction
				if closed and distance < 0: distance += length_m
				if distance > radius_m: break
				var weight: float = exp(-0.5 * pow(distance / (radius_m * 0.4), 2))
				sum += Vector3(samples[index].position).y * weight
				weight_sum += weight
		var taper: float = 1.0 if closed else clampf(minf(station, length_m - station) / radius_m, 0, 1)
		heights[i] = base + clampf(sum / weight_sum - base, -3.0, 3.0) * taper
	for i: int in samples.size():
		var point: Vector3 = samples[i].position
		point.y = heights[i]
		samples[i].position = point
