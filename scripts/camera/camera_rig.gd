class_name ApexCamera
extends Node3D
## Camera transform changes never modify the physical vehicle.

const NAMES := ["Persecución", "Capó / depósito", "Piloto", "Cinemática", "Orbital"]
const BikePose = preload("res://scripts/camera/motorcycle_camera_pose.gd")
var camera := Camera3D.new()
var target: Node3D
var mode: int = 0
var showroom: bool = true
var orbit: float = -0.65
var orbit_pitch: float = 0.25
var orbit_distance: float = 6.7
var photo_mode: bool = false
var _first: bool = true
var base_fov: float = 65.0
var bank_amount: float = 1.0
var motion_amount: float = 0.55
var _motion := ApexCameraMotion.new()

func configure(values: Dictionary) -> void:
	mode = clampi(int(values.get("camera", mode)), 0, NAMES.size() - 1)
	base_fov = clampf(float(values.get("camera_fov", 65.0)), 50.0, 95.0)
	bank_amount = clampf(float(values.get("camera_bank", 1.0)), 0.0, 1.0)
	motion_amount = clampf(float(values.get("camera_motion", 0.55)), 0.0, 1.0)

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.far = 3500.0
	camera.near = 0.05
	camera.fov = 56.0
	camera.current = true
	add_child(camera)

func follow(node: Node3D, garage: bool = false) -> void:
	target = node
	showroom = garage
	if garage: orbit_distance = float(node.get_meta("view_distance", 6.7))
	_first = true
	_motion.reset()

func cycle() -> void:
	if NAMES.is_empty():
		return
	mode = (mode + 1) % NAMES.size()
	_first = true

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var speed: float = 0.0 if showroom else maxf(0.0, float(target.get("speed_kph")))
	var bike: bool = false if showroom else bool(target.get("is_motorcycle"))
	var pose: Transform3D = target.get_global_transform_interpolated() if target is PhysicsBody3D and not showroom else target.global_transform
	if not pose.origin.is_finite() or not pose.basis.is_finite():
		return
	var origin: Vector3 = pose.origin
	var basis: Basis = pose.basis.orthonormalized()
	if not basis.is_finite():
		return
	var active_mode: int = 4 if showroom or photo_mode else mode
	var follow_lean: bool = bike and active_mode in [0, 1, 2]
	if follow_lean:
		var bike_frame: Transform3D = BikePose.frame(pose, float(target.ride_height), float(target.lean_angle))
		basis = bike_frame.basis
		origin = bike_frame.origin
		if bank_amount < 1.0:
			var level: Basis = BikePose.look_basis(Vector3.ZERO, -basis.z, Vector3.UP)
			basis = level.slerp(basis, bank_amount).orthonormalized()
	var camera_up: Vector3 = basis.y if follow_lean else Vector3.UP
	var aim: Vector3 = origin + camera_up * (0.55 if showroom else 0.5)
	var desired: Vector3
	if not showroom:
		var visual: Node3D = target.get_node_or_null("Visual")
		if visual != null and visual.has_method("set_cockpit_view"):
			visual.set_cockpit_view(active_mode == 2)
	match active_mode:
		0:
			desired = origin + basis.z * (6.5 + speed * 0.005) + camera_up * 2.5
			aim = origin - basis.z * 3.0 + camera_up * 0.6
		1:
			desired = origin + basis * Vector3(0, 0.55 if bike else 0.42, -0.55 if bike else -1.4)
			aim = desired - basis.z * 40 + basis.y * 0.4
		2:
			var profile: Dictionary = target.get("profile") if target.get("profile") is Dictionary else {}
			var raw_position: Variant = profile.get("cockpit_camera_ground", [0.0, 1.1, 0.1])
			var position_values: Array = raw_position if raw_position is Array else [0.0, 1.1, 0.1]
			if position_values.size() >= 3:
				var cockpit := Vector3(float(position_values[0]), float(position_values[1]) - float(target.get("ride_height")), float(position_values[2]))
				if cockpit.is_finite():
					desired = origin + basis * cockpit
					aim = desired - basis.z * 40 - basis.y * 0.4
				else:
					desired = origin + basis * Vector3(0, 0.42, -1.4)
					aim = desired - basis.z * 40 + basis.y * 0.4
			else:
				desired = origin + basis * Vector3(0, 0.42, -1.4)
				aim = desired - basis.z * 40 + basis.y * 0.4
		3:
			desired = origin + basis.z * 11 + Vector3.UP * 5 + basis.x * 6
			aim = origin - basis.z * 4
		_:
			if showroom and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				orbit += delta * 0.055
			desired = aim + Vector3(sin(orbit), sin(orbit_pitch), -cos(orbit)) * orbit_distance
	if not desired.is_finite() or not aim.is_finite():
		return
	var factor: float = 1.0 if _first or active_mode in [1, 2, 4] else 1.0 - exp(-delta * 7.0)
	if not showroom and active_mode in [0, 3]:
		var query := PhysicsRayQueryParameters3D.create(aim, desired, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			desired = hit.position + hit.normal * 0.45
	camera.global_position = camera.global_position.lerp(desired, factor)
	if camera.global_position.distance_squared_to(aim) > 0.01:
		if follow_lean:
			var orientation: Basis = BikePose.look_basis(camera.global_position, aim, camera_up)
			camera.global_basis = BikePose.smooth(camera.global_basis, orientation, delta, 12.0 if active_mode == 2 else 10.0, _first)
		else:
			camera.look_at(aim, Vector3.UP)
	if not showroom and not photo_mode and not get_tree().paused and target is RigidBody3D:
		camera.global_position += _motion.sample(target, basis, active_mode, delta, motion_amount)
	camera.fov = lerpf(camera.fov, 50.0 if showroom else clampf(base_fov + speed * 0.035, base_fov, minf(base_fov + 13.0, 105.0)), minf(delta * 3, 1))
	_first = false

func _unhandled_input(event: InputEvent) -> void:
	if not (showroom or mode == 4 or photo_mode):
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		orbit -= event.relative.x * 0.007
		orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.004, -0.05, 0.95)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = maxf(3.0, orbit_distance - 0.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = minf(25.0, orbit_distance + 0.7)
