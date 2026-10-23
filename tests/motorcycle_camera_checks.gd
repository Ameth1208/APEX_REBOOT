extends SceneTree

const CameraRig = preload("res://scripts/camera/camera_rig.gd")
const BikePose = preload("res://scripts/camera/motorcycle_camera_pose.gd")
var _failures: int = 0
var _checks: int = 0

class TestVehicle:
	extends Node3D
	var speed_kph: float = 0.0
	var is_motorcycle: bool = true
	var lean_angle: float = 0.0
	var total_lean_angle: float = 0.0
	var ride_height: float = 0.61
	var profile: Dictionary = {"cockpit_camera_ground": [0.0, 1.3, 0.1]}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var target: TestVehicle = TestVehicle.new()
	root.add_child(target)
	target.position.y = target.ride_height
	var rig: Node3D = CameraRig.new()
	root.add_child(rig)
	rig.set_process(false)
	for mode: int in [0, 1, 2]:
		rig.mode = mode
		for angle: float in [-35.0, 35.0]:
			target.lean_angle = deg_to_rad(angle)
			target.total_lean_angle = target.lean_angle
			rig.follow(target, false)
			rig._process(1.0 / 60.0)
			_close(_roll(rig.camera.global_basis), angle, 0.05, "camera mode " + str(mode) + " follows signed lean")
	# Physical body: 15 degrees of road bank + 10 degrees of chassis roll.
	# Residual visual lean: 30-degree target lean minus the 10-degree chassis roll.
	target.basis = Basis(Vector3.FORWARD, deg_to_rad(25.0))
	target.lean_angle = deg_to_rad(20.0)
	target.total_lean_angle = deg_to_rad(30.0)
	rig.mode = 2
	rig.follow(target, false)
	rig._process(1.0 / 60.0)
	_close(_roll(rig.camera.global_basis), 45.0, 0.05, "road bank and visual lean included exactly once")
	var expected: Transform3D = BikePose.frame(target.global_transform, target.ride_height, target.lean_angle)
	var expected_head: Vector3 = expected.origin + expected.basis * Vector3(0.0, 1.3 - target.ride_height, 0.1)
	_check(rig.camera.global_position.distance_to(expected_head) < 0.0001, "pilot camera moves with rider head around ground pivot")
	_check(target.total_lean_angle == deg_to_rad(30.0), "camera does not alter physical lean telemetry")
	target.basis = Basis.IDENTITY
	target.lean_angle = 0.0
	rig.follow(target, false)
	rig._process(1.0 / 60.0)
	target.lean_angle = deg_to_rad(40.0)
	rig._process(1.0 / 60.0)
	var first_step: float = _roll(rig.camera.global_basis)
	_check(first_step > 0.0 and first_step < 40.0, "lean transition is smoothed without forcing an upright horizon")
	for step: int in range(60):
		rig._process(1.0 / 60.0)
	_close(_roll(rig.camera.global_basis), 40.0, 0.05, "smoothing converges to full requested lean")
	var rotation_30: Basis = Basis.IDENTITY
	var rotation_120: Basis = Basis.IDENTITY
	var desired: Basis = Basis(Vector3.FORWARD, deg_to_rad(-35.0))
	for step: int in range(30):
		rotation_30 = BikePose.smooth(rotation_30, desired, 1.0 / 30.0, 10.0)
	for step: int in range(120):
		rotation_120 = BikePose.smooth(rotation_120, desired, 1.0 / 120.0, 10.0)
	_check(rotation_30.get_rotation_quaternion().angle_to(rotation_120.get_rotation_quaternion()) < 0.001, "rotation smoothing is independent of frame rate")
	rig.mode = 0
	target.lean_angle = deg_to_rad(25.0)
	target.speed_kph = 0.0
	rig.follow(target, false)
	rig._process(1.0)
	var low_position: Vector3 = rig.camera.global_position
	var low_fov: float = rig.camera.fov
	target.speed_kph = 200.0
	rig.follow(target, false)
	rig._process(1.0)
	_close(rig.camera.global_position.z - low_position.z, 1.0, 0.0001, "chase distance responds to speed")
	_check(rig.camera.fov > low_fov and rig.camera.fov <= 78.0, "speed FOV remains active")
	_close(_roll(rig.camera.global_basis), 25.0, 0.05, "speed changes preserve the motorcycle lean angle")
	target.is_motorcycle = false
	target.basis = Basis(Vector3.FORWARD, deg_to_rad(30.0))
	for mode: int in [0, 1, 2]:
		rig.mode = mode
		rig.follow(target, false)
		rig._process(1.0 / 60.0)
		_close(_roll(rig.camera.global_basis), 0.0, 0.1, "car camera behavior preserved in mode " + str(mode))
	rig.queue_free()
	target.queue_free()
	await process_frame
	print("MOTORCYCLE_CAMERA_CHECKS ", "PASS" if _failures == 0 else "FAIL", ": ", _checks, " assertions, ", _failures, " failures")
	quit(0 if _failures == 0 else 1)

func _roll(basis: Basis) -> float:
	return rad_to_deg(atan2(basis.y.x, basis.y.y))

func _close(actual: float, expected: float, tolerance: float, description: String) -> void:
	_check(absf(actual - expected) < tolerance, description + ": " + str(actual) + " vs " + str(expected))

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("CAMERA FAIL: " + description)
