extends RefCounted
## Analytic two-bone IK preserves the supplied human's limb lengths.
## Targets use the normalized motorcycle's ground coordinates, metres.

var _rig: Skeleton3D
var _to_rig: Transform3D
var _from_rig: Transform3D
var _rest: Dictionary = {}
var _ids: Dictionary = {}
var _profile: Dictionary
var _tuck := 0.0
var _shift := 0.0
var _targets: Dictionary = {}

func configure(skeleton: Skeleton3D, rider: Node3D, profile: Dictionary) -> void:
	_rig = skeleton
	_profile = profile
	_to_rig = _rig.global_transform.affine_inverse() * rider.global_transform
	_from_rig = _to_rig.affine_inverse()
	_rig.reset_bone_poses()
	for i in _rig.get_bone_count():
		var name := _rig.get_bone_name(i)
		_ids[name] = i
		_rest[name] = _from_rig * _rig.get_bone_global_rest(i)
	_curl_fingers()

func update(speed: float, steering: float, lean: float, delta: float) -> void:
	var blend := 1.0 - exp(-8.0 * maxf(delta, 0.0))
	_tuck = lerpf(_tuck, clampf(absf(speed) / 45.0, 0.0, 1.0), blend)
	_shift = lerpf(_shift, clampf(lean, -0.8, 0.8) * 0.065, blend)
	var pelvis := _point("rider_seat", Vector3(0, 0.945, 0.405))
	pelvis.x += _shift
	var pitch := deg_to_rad(-49.0 - 8.0 * _tuck)
	var pelvis_basis := Basis(Vector3.RIGHT, pitch) * (_rest["pelvis"] as Transform3D).basis
	_write_pose("pelvis", Transform3D(pelvis_basis, pelvis))
	# Keep the gaze up the road while the spine bends forward from the seat.
	_rotate("neck_01", (_rest["neck_01"] as Transform3D).basis)
	_rotate("Head", Basis(Vector3.UP, -steering * 0.4) * (_rest["Head"] as Transform3D).basis)
	for side in [-1.0, 1.0]:
		var suffix := "_l" if side < 0.0 else "_r"
		var grip := _point("rider_grip", Vector3(0.285, 1.005, -0.345))
		grip.x *= side
		var hand_axis := Vector3(0, -0.15, -1).normalized()
		var wrist := grip - hand_axis * 0.092
		var elbow_pole := Vector3(side * 0.50, 1.13, 0.13)
		_solve("upperarm" + suffix, "lowerarm" + suffix, "hand" + suffix, wrist, elbow_pole)
		var normal: Vector3 = Vector3.UP * float(side)
		var across: Vector3 = normal.cross(hand_axis).normalized()
		_rotate("hand" + suffix, Basis(hand_axis.cross(across), hand_axis, across))
		var ankle := _point("rider_ankle", Vector3(0.245, 0.41, 0.405))
		ankle.x *= side
		_solve("thigh" + suffix, "calf" + suffix, "foot" + suffix, ankle, Vector3(side * 0.29, 0.64, -0.22))
		_rotate("foot" + suffix, (_rest["foot" + suffix] as Transform3D).basis)
		_targets["hand" + suffix] = wrist
		_targets["foot" + suffix] = ankle

func _solve(upper: String, lower: String, end: String, goal: Vector3, pole: Vector3) -> void:
	var a := _bone_pose(upper).origin
	var first := (_rest[upper] as Transform3D).origin.distance_to((_rest[lower] as Transform3D).origin)
	var second := (_rest[lower] as Transform3D).origin.distance_to((_rest[end] as Transform3D).origin)
	var axis := (goal - a).normalized()
	var distance := clampf(a.distance_to(goal), absf(first - second) + 0.001, first + second - 0.001)
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var normal := pole - a
	normal = (normal - axis * normal.dot(axis)).normalized()
	var elbow := a + axis * along + normal * sqrt(maxf(first * first - along * along, 0.0))
	_aim(upper, lower, elbow)
	_aim(lower, end, a + axis * distance)

func _aim(bone: String, child: String, goal: Vector3) -> void:
	var original: Transform3D = _rest[bone]
	var rest_axis := ((_rest[child] as Transform3D).origin - original.origin).normalized()
	var direction := (goal - _bone_pose(bone).origin).normalized()
	_rotate(bone, Basis(Quaternion(rest_axis, direction)) * original.basis)

func _rotate(bone: String, basis: Basis) -> void:
	_write_pose(bone, Transform3D(basis, _bone_pose(bone).origin))

func _write_pose(bone: String, pose: Transform3D) -> void:
	var index: int = _ids[bone]
	var desired := _to_rig * pose
	var parent := _rig.get_bone_parent(index)
	if parent >= 0:
		desired = _rig.get_bone_global_pose(parent).affine_inverse() * desired
	_rig.set_bone_pose_position(index, desired.origin)
	_rig.set_bone_pose_rotation(index, desired.basis.orthonormalized().get_rotation_quaternion())

func _bone_pose(bone: String) -> Transform3D:
	return _from_rig * _rig.get_bone_global_pose(int(_ids[bone]))

func _point(key: String, fallback: Vector3) -> Vector3:
	var point: Array = _profile.get(key, [fallback.x, fallback.y, fallback.z])
	return Vector3(float(point[0]), float(point[1]), float(point[2]))

func _curl_fingers() -> void:
	for side in ["l", "r"]:
		for finger in ["index", "middle", "ring", "pinky", "thumb"]:
			for segment in range(1, 4):
				var id := _rig.find_bone("%s_%02d_%s" % [finger, segment, side])
				if id < 0:
					continue
				var angle := 0.88 if segment > 1 else 0.60
				if finger == "thumb":
					angle *= 0.55
				var basis := _rig.get_bone_rest(id).basis * Basis(Vector3.RIGHT, angle)
				_rig.set_bone_pose_rotation(id, basis.orthonormalized().get_rotation_quaternion())

func helmet_transform() -> Transform3D:
	var pose := _bone_pose("Head")
	pose.origin += pose.basis.orthonormalized() * Vector3(0, 0.085, 0.0)
	pose.basis = pose.basis.orthonormalized() * Basis(Vector3.UP, PI)
	return pose

func ankle_position(side: String) -> Vector3:
	return _bone_pose("foot_" + side).origin

func calf_direction(side: String) -> Vector3:
	return _bone_pose("calf_" + side).origin - ankle_position(side)

func contact_report() -> Dictionary:
	var result := {"bone_count": _rig.get_bone_count(), "tuck": _tuck, "shift_m": _shift}
	for bone in _targets:
		result[bone] = {"error_m": _bone_pose(bone).origin.distance_to(_targets[bone]), "position": _bone_pose(bone).origin, "target": _targets[bone]}
	result["head"] = _bone_pose("Head").origin
	return result
