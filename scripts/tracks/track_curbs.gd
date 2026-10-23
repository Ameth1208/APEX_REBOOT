extends RefCounted
## Low, bevelled concrete kerbs. Colour spacing follows the road in metres,
## rather than the arbitrary number/spacing of imported centreline samples.

const OFFSETS: Array[float] = [0.0, 0.12, 0.60, 0.75]
const HEIGHTS: Array[float] = [0.015, 0.065, 0.065, 0.005]

static func build(parent: Node3D, samples: Array[Dictionary], closed: bool, chunk_m: float) -> void:
	var buffer: TrackMeshBuffer = TrackMeshBuffer.new()
	for index: int in range(samples.size() if closed else samples.size() - 1):
		var a: Dictionary = samples[index]
		var b: Dictionary = samples[(index + 1) % samples.size()]
		if str(a["surface"]) not in ["asphalt", "concrete"]:
			continue
		var end_distance: float = float(a["distance"]) + Vector3(a["position"]).distance_to(b["position"])
		for side: float in [-1.0, 1.0]:
			for strip: int in range(3):
				var al: Vector3 = _position(a, side, strip)
				var ar: Vector3 = _position(a, side, strip + 1)
				var bl: Vector3 = _position(b, side, strip)
				var br: Vector3 = _position(b, side, strip + 1)
				var normal: Vector3 = (ar - al).cross(bl - al).normalized()
				if normal.dot(a["normal"]) < 0.0:
					normal = -normal
				buffer.quad(al, ar, br, bl, normal, PackedVector2Array([
					Vector2(OFFSETS[strip], a["distance"]), Vector2(OFFSETS[strip + 1], a["distance"]),
					Vector2(OFFSETS[strip + 1], end_distance), Vector2(OFFSETS[strip], end_distance)]))
	buffer.attach(parent, "Curbs", TrackMaterials.curbs(), "concrete", false, chunk_m)

static func _position(sample: Dictionary, side: float, strip: int) -> Vector3:
	return sample["position"] + sample["right"] * side * (float(sample["width"]) * 0.5 + OFFSETS[strip]) + sample["normal"] * HEIGHTS[strip]
