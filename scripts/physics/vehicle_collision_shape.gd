extends RefCounted
## A small convex envelope follows the configured body dimensions, including overhangs.

static func build(profile: Dictionary, motorcycle: bool, ride_height: float) -> ConvexPolygonShape3D:
	var length: float = maxf(0.8, float(profile.get("length_m", float(profile.get("wheelbase_m", 2.65)) + 0.8)))
	var width: float = maxf(0.2, float(profile.get("body_width_m", 0.70 if motorcycle else 1.85)))
	var height: float = maxf(0.45, float(profile.get("body_height_m", 1.16 if motorcycle else 1.3)))
	var vertices: PackedVector3Array = PackedVector3Array()
	var half: float = width * 0.5
	if motorcycle:
		_ring(vertices, half * 0.24, 0.18, -length * 0.5, ride_height)
		_ring(vertices, half * 0.24, height * 0.52, -length * 0.5, ride_height)
		_ring(vertices, half * 0.30, 0.18, length * 0.5, ride_height)
		_ring(vertices, half * 0.30, height * 0.70, length * 0.5, ride_height)
		_ring(vertices, half, height * 0.92, -length * 0.12, ride_height)
		_ring(vertices, half * 0.68, 0.30, 0.0, ride_height)
		_ring(vertices, half * 0.65, height * 0.94, length * 0.20, ride_height)
	else:
		_ring(vertices, half * 0.90, 0.17, -length * 0.5, ride_height)
		_ring(vertices, half * 0.90, height * 0.52, -length * 0.5, ride_height)
		_ring(vertices, half * 0.90, 0.17, length * 0.5, ride_height)
		_ring(vertices, half * 0.90, height * 0.60, length * 0.5, ride_height)
		_ring(vertices, half, height * 0.65, -length * 0.28, ride_height)
		_ring(vertices, half, height * 0.65, length * 0.28, ride_height)
		_ring(vertices, half * 0.76, height * 0.96, -length * 0.14, ride_height)
		_ring(vertices, half * 0.80, height * 0.96, length * 0.15, ride_height)
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	# The visual bounding-box centre need not coincide with the mass/axle origin.
	for i: int in vertices.size():
		vertices[i].z += float(profile.get("model_offset_z_m", 0.0))
	shape.points = vertices
	return shape

static func _ring(points: PackedVector3Array, half_width: float, height: float, z: float, ride_height: float) -> void:
	points.append(Vector3(-half_width, height - ride_height, z))
	points.append(Vector3(half_width, height - ride_height, z))
