class_name VehicleVisual
extends Node3D
## Display only. Physics and AI consume the same profile without touching meshes.

const Painter = preload("res://scripts/vehicles/paint_controller.gd")
const MaterialRepair = preload("res://scripts/vehicles/material_repair.gd")
const WheelSplitter = preload("res://scripts/vehicles/wheel_mesh_splitter.gd")
const MotorcycleRider = preload("res://scripts/vehicles/motorcycle_rider.gd")
const ModelLoader = preload("res://scripts/vehicles/vehicle_model_loader.gd")
const WheelSuspension = preload("res://scripts/vehicles/wheel_suspension_visual.gd")
const WheelGeometry = preload("res://scripts/vehicles/wheel_geometry.gd")
const WheelLayout = preload("res://scripts/physics/wheel_layout.gd")
const BodyBatcher = preload("res://scripts/vehicles/vehicle_body_batcher.gd")
var _profile: Dictionary = {}
var _lean: Node3D
var _normalized: Node3D
var _painter := Painter.new()
var _wheels: Array[Dictionary] = []
var _lights: Array[SpotLight3D] = []
var _rider: Node3D
var dimensions := Vector3.ZERO

func setup(profile: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_profile = profile
	_wheels.clear()
	_lights.clear()
	_rider = null
	_lean = Node3D.new()
	_lean.name = "Lean"
	add_child(_lean)
	_normalized = Node3D.new()
	_normalized.name = "NormalizedModel"
	_lean.add_child(_normalized)
	var path := str(profile.get("model_path", ""))
	var model := ModelLoader.instantiate(path)
	if model == null:
		return
	_normalized.add_child(model)
	_remove_scene_helpers(model)
	_normalized.rotation_degrees = Vector3(
		float(profile.get("model_pitch_deg", 0.0)),
		float(profile.get("model_yaw_deg", 0.0)),
		float(profile.get("model_roll_deg", 0.0))
	)
	var bounds := _bounds(_normalized, Transform3D.IDENTITY)
	var unit := float(profile.get("length_m", 4.5)) / maxf(bounds.size.z, 0.001)
	_normalized.scale = Vector3.ONE * unit
	var center := bounds.get_center()
	_normalized.position = Vector3(-center.x, -bounds.position.y, -center.z) * unit
	_normalized.position.z += float(profile.get("model_offset_z_m", 0.0))
	dimensions = bounds.size * unit
	MaterialRepair.apply(_normalized, profile.get("material_repairs", []))
	WheelSplitter.split(_normalized, profile.get("split_wheel_meshes", []))
	_align_body_to_axles()
	for group in profile.get("wheel_groups", []):
		_make_wheel(group)
	if bool(profile.get("batch_static_body", true)):
		BodyBatcher.apply(_normalized, str(profile.get("model_path", "")))
	_painter.configure(_lean, profile)
	if str(profile.get("kind", profile.get("category", ""))) == "motorcycle" and profile.get("show_rider", true):
		_rider = MotorcycleRider.new()
		_rider.name = "Rider"
		_lean.add_child(_rider)
		_rider.configure(profile)
		_rider.position.z += float(profile.get("model_offset_z_m", 0.0))
	_make_headlights()

func _wheel_bounds(group: Dictionary) -> AABB:
	var matches: Array[Node3D] = []
	_find_named(_normalized, group.get("names", []), matches)
	var result := AABB()
	var first := true
	for part: Node3D in matches:
		var parent_transform := _relative_transform(part) * part.transform.affine_inverse()
		var box := _bounds(part, parent_transform)
		result = box if first else result.merge(box)
		first = false
	return result

func _align_body_to_axles() -> void:
	if not bool(_profile.get("align_wheels_to_physics", false)):
		return
	var front_z: float = 0.0
	var rear_z: float = 0.0
	var front_count: int = 0
	var rear_count: int = 0
	for group: Dictionary in _profile.get("wheel_groups", []):
		var box := _wheel_bounds(group)
		if box.size.length_squared() < 0.000001:
			continue
		if bool(group.get("front", false)):
			front_z += box.get_center().z
			front_count += 1
		else:
			rear_z += box.get_center().z
			rear_count += 1
	if front_count == 0 or rear_count == 0:
		return
	front_z /= float(front_count)
	rear_z /= float(rear_count)
	var imported_wheelbase: float = rear_z - front_z
	if imported_wheelbase < 0.1:
		return
	var motorcycle: bool = str(_profile.get("kind", "")) == "motorcycle"
	var offsets: Array[Vector3] = WheelLayout.offsets(_profile, motorcycle)
	var target_front: float = offsets[0].z
	var target_rear: float = offsets[1 if motorcycle else 2].z
	var stretch: float = (target_rear - target_front) / imported_wheelbase
	# Calibrate the complete shell before detaching wheels, keeping arches over hubs.
	# A suspect import should be corrected explicitly, not stretched beyond recognition.
	if stretch < 0.8 or stretch > 1.2:
		push_warning("No se pudo alinear la carrocería: revisa la distancia entre ejes del modelo.")
		return
	_normalized.transform = Transform3D(Basis.from_scale(Vector3(1, 1, stretch)), Vector3(0, 0, target_front - front_z * stretch)) * _normalized.transform
	dimensions.z *= stretch

func set_paint(color: Color, original: bool = false) -> void:
	_painter.apply(color, original)

func set_livery(id: String) -> void:
	_painter.set_livery(id)

func set_headlights(enabled: bool) -> void:
	for lamp in _lights:
		lamp.visible = enabled

func set_cockpit_view(enabled: bool) -> void:
	if is_instance_valid(_rider):
		_rider.set_cockpit_view(enabled)

func sync_suspension(contacts: Array, delta: float) -> void:
	WheelSuspension.sync(_wheels, contacts, _profile, delta)

func animate(speed_mps: float, steering_rad: float, lean_rad: float, delta: float) -> void:
	if _lean == null:
		return
	_lean.rotation.z = -lean_rad
	var wheelbase: float = float(_profile.get("wheelbase_m", 2.65))
	for entry in _wheels:
		var pivot := entry["pivot"] as Node3D
		if not bool(entry.get("locked", false)):
			entry["spin"] = wrapf(float(entry["spin"]) - speed_mps * delta / float(entry["radius_m"]), -PI, PI)
		var angle: float = WheelLayout.steering(steering_rad, pivot.position.x, wheelbase) if entry["front"] else 0.0
		pivot.basis = Basis(Vector3.UP, -angle) * Basis(Vector3.RIGHT, float(entry["spin"]))
	if is_instance_valid(_rider):
		_rider.animate(speed_mps, steering_rad, lean_rad, delta)

func _remove_scene_helpers(node: Node) -> void:
	for child in node.get_children():
		if child is Light3D or child is Camera3D or child is WorldEnvironment:
			node.remove_child(child)
			child.queue_free()
		else:
			_remove_scene_helpers(child)
	if node is MeshInstance3D:
		node.lod_bias = 0.6
	if node is AnimationPlayer:
		node.stop()

func _bounds(node: Node, transform_from_parent: Transform3D) -> AABB:
	var transform_here := transform_from_parent
	if node is Node3D:
		transform_here *= node.transform
	var result := AABB()
	var found := false
	if node is MeshInstance3D and node.mesh:
		result = transform_here * node.mesh.get_aabb()
		found = true
	for child in node.get_children():
		var child_box := _bounds(child, transform_here)
		if child_box.size.length_squared() > 0.0000000001:
			result = result.merge(child_box) if found else child_box
			found = true
	return result

func _relative_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != _lean and parent is Node3D:
		result = parent.transform * result
		parent = parent.get_parent()
	return result

func _find_named(node: Node, names: Array, matches: Array[Node3D]) -> void:
	if node is Node3D and str(node.name) in names:
		if node is MeshInstance3D and node.skin:
			return # Keep skeleton-bound meshes attached to their original skeleton.
		matches.append(node)
		return
	for child in node.get_children():
		_find_named(child, names, matches)

func _make_wheel(group: Dictionary) -> void:
	var matches: Array[Node3D] = []
	_find_named(_normalized, group.get("names", []), matches)
	if matches.is_empty():
		return
	var box := AABB()
	var first := true
	for part in matches:
		var parent_transform := _relative_transform(part) * part.transform.affine_inverse()
		var part_box := _bounds(part, parent_transform)
		box = part_box if first else box.merge(part_box)
		first = false
	# Never rotate a baked axle containing both wheels as a single wheel.
	if box.size.x > maxf(dimensions.x * 0.7, 0.4):
		return
	var pivot := Node3D.new()
	pivot.name = str(group.get("id", "Wheel"))
	pivot.position = box.get_center()
	_lean.add_child(pivot)
	for part in matches:
		var previous := _relative_transform(part)
		_clear_owner(part)
		part.get_parent().remove_child(part)
		pivot.add_child(part)
		part.transform = pivot.transform.affine_inverse() * previous
	_wheels.append(WheelGeometry.prepare(pivot, box, bool(group.get("front", false)), _profile))

func _clear_owner(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owner(child)

func _make_headlights() -> void:
	if not _profile.get("headlights", false):
		return
	var offsets: Array = [0.0] if _profile.get("category") == "motorcycle" else [-0.3, 0.3]
	for x in offsets:
		var lamp := SpotLight3D.new()
		lamp.name = "Headlight"
		lamp.position = Vector3(float(x) * dimensions.x, dimensions.y * 0.55, -dimensions.z * 0.43)
		lamp.position.z += float(_profile.get("model_offset_z_m", 0.0))
		lamp.rotation.x = deg_to_rad(-4.0)
		lamp.light_color = Color(0.87, 0.93, 1.0)
		lamp.light_energy = 5.0
		lamp.spot_range = 85.0
		lamp.spot_angle = 32.0
		lamp.spot_attenuation = 0.6
		lamp.visible = false
		_lean.add_child(lamp)
		_lights.append(lamp)
