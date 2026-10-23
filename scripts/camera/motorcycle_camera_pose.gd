class_name MotorcycleCameraPose
extends RefCounted
## Match the motorcycle's visual frame: physical bank + residual visual lean.
## The residual already compensates chassis roll; adding total_lean again doubles it.

static func frame(body_pose: Transform3D, ride_height: float, residual_lean: float) -> Transform3D:
	var body_basis: Basis = body_pose.basis.orthonormalized()
	var visual_basis: Basis = (body_basis * Basis(Vector3.FORWARD, residual_lean)).orthonormalized()
	# VehicleVisual leans around its ground-level child, below the rigid-body root.
	var ground_pivot: Vector3 = body_pose.origin - body_basis.y * ride_height
	return Transform3D(visual_basis, ground_pivot + visual_basis.y * ride_height)

static func look_basis(position: Vector3, aim: Vector3, up_hint: Vector3) -> Basis:
	var forward: Vector3 = (aim - position).normalized()
	var up: Vector3 = up_hint.normalized()
	if forward.cross(up).length_squared() < 0.0001:
		up = Vector3.UP if absf(forward.y) < 0.95 else Vector3.RIGHT
	return Basis.looking_at(forward, up).orthonormalized()

static func smooth(current: Basis, desired: Basis, delta: float, response: float, snap: bool = false) -> Basis:
	if snap:
		return desired
	var factor: float = 1.0 - exp(-maxf(0.0, delta) * response)
	return current.orthonormalized().slerp(desired, factor).orthonormalized()
