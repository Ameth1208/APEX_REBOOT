extends RefCounted
## Correct runtime hub geometry without rewriting the imported model or materials.

const Layout = preload("res://scripts/physics/wheel_layout.gd")

static func prepare(pivot: Node3D, bounds: AABB, front: bool, profile: Dictionary) -> Dictionary:
	var motorcycle: bool = str(profile.get("kind", profile.get("category", ""))) == "motorcycle"
	var measured_radius: float = bounds.size.z * 0.5
	var radius: float = float(profile.get("wheel_visual_radius_m", measured_radius))
	radius = maxf(radius, 0.05)
	var radial_scale: Vector3 = Vector3(1.0, radius * 2.0 / maxf(bounds.size.y, 0.01), radius * 2.0 / maxf(bounds.size.z, 0.01))
	# A non-uniform import scale must not make the rotating tyre an ellipse.
	if absf(radial_scale.y - 1.0) > 0.002 or absf(radial_scale.z - 1.0) > 0.002:
		var correction: Transform3D = Transform3D(Basis.from_scale(radial_scale), Vector3.ZERO)
		for child: Node3D in pivot.get_children():
			child.transform = correction * child.transform
		pivot.position.y = bounds.position.y + radius
	var wheel_index: int = Layout.index(front, pivot.position.x >= 0.0, motorcycle)
	var imported_position: Vector3 = pivot.position
	if bool(profile.get("align_wheels_to_physics", false)):
		var contact: Vector3 = Layout.offsets(profile, motorcycle)[wheel_index]
		pivot.position.x = contact.x
		pivot.position.z = contact.z
	return {"pivot": pivot, "front": front, "index": wheel_index,
		"base_position": pivot.position, "imported_position": imported_position,
		"radius_m": radius, "spin": 0.0, "locked": false}
