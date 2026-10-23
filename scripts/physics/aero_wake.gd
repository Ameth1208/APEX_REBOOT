class_name ApexAeroWake
extends RefCounted
## Shared 3D wake model for every player/AI vehicle. It modifies aerodynamic
## coefficients only: no velocity impulse, extra engine power or artificial grip.

func update(vehicles: Array, delta: float) -> void:
	for follower: RigidBody3D in vehicles:
		if not is_instance_valid(follower):
			continue
		var strongest: float = 0.0
		for leader: RigidBody3D in vehicles:
			if leader != follower and is_instance_valid(leader):
				strongest = maxf(strongest, strength_between(follower, leader))
		var blend: float = 1.0 - exp(-maxf(delta, 0.0) * 4.0)
		follower.draft_strength = lerpf(follower.draft_strength, strongest, blend)
		var bike: bool = bool(follower.is_motorcycle)
		var aero_area: float = float(follower.profile.get("downforce_area_m2", 0.0))
		var drag_loss: float = clampf(float(follower.profile.get("wake_drag_reduction", 0.28 if bike else 0.22)), 0.0, 0.45)
		var default_loss: float = 0.32 if aero_area >= 2.0 else (0.16 if aero_area > 0.0 else 0.0)
		var downforce_loss: float = clampf(float(follower.profile.get("wake_downforce_loss", default_loss)), 0.0, 0.60)
		follower.drag_multiplier = 1.0 - drag_loss * follower.draft_strength
		follower.downforce_multiplier = 1.0 - downforce_loss * follower.draft_strength

static func strength_between(follower: RigidBody3D, leader: RigidBody3D) -> float:
	var forward: Vector3 = -leader.global_basis.z.normalized()
	var leader_speed: float = leader.linear_velocity.dot(forward)
	var follower_speed: float = follower.linear_velocity.dot(-follower.global_basis.z.normalized())
	if leader_speed < 8.0 or follower_speed < 5.0:
		return 0.0
	if forward.dot(-follower.global_basis.z.normalized()) < 0.80:
		return 0.0
	if leader.linear_velocity.normalized().dot(follower.linear_velocity.normalized()) < 0.70:
		return 0.0
	var offset: Vector3 = follower.global_position - leader.global_position
	var behind: float = -offset.dot(forward)
	var range_m: float = maxf(5.0, float(leader.profile.get("wake_range_m", 48.0 if leader.is_motorcycle else 75.0)))
	if behind < 1.0 or behind >= range_m:
		return 0.0
	var width: float = float(leader.profile.get("body_width_m", 0.75 if leader.is_motorcycle else 1.85))
	var half_width: float = width * 0.60 + behind * 0.055
	var side: float = absf(offset.dot(leader.global_basis.x.normalized()))
	var height: float = absf(offset.dot(leader.global_basis.y.normalized()))
	var height_limit: float = 1.25 + behind * 0.018
	if side >= half_width or height >= height_limit:
		return 0.0
	var lateral_shape: float = 1.0 - pow(side / half_width, 2.0)
	var height_shape: float = 1.0 - height / height_limit
	var distance_shape: float = 1.0 - behind / range_m
	var speed_shape: float = clampf((leader_speed - 8.0) / 22.0, 0.0, 1.0)
	var size_factor: float = clampf(width / 1.85, 0.45, 1.0)
	return clampf(lateral_shape * height_shape * distance_shape * speed_shape * size_factor, 0.0, 1.0)
