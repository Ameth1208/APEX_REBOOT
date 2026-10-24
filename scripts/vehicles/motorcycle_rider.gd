extends Node3D
## Quaternius CC0 human, posed over the motorcycle without changing bike physics.
## Original source topology, skin and face textures remain in assets/rider/.

const Fallback = preload("res://scripts/vehicles/procedural_rider.gd")
const RidingPose = preload("res://scripts/vehicles/rider_pose.gd")
const RidingSuit = preload("res://scripts/vehicles/rider_suit.gd")
const Helmet = preload("res://scripts/vehicles/rider_helmet.gd")
const Boot = preload("res://scripts/vehicles/rider_boot.gd")
const DEFAULT_MODEL := "res://assets/rider/quaternius/Superhero_Male_FullBody.gltf"
var _pose: RefCounted
var _suit: RefCounted
var _helmet: Node3D
var _fallback: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _boots: Array[Node3D] = []

func configure(profile: Dictionary) -> void:
	var path := str(profile.get("rider_model_path", DEFAULT_MODEL))
	if profile.get("rider_procedural", false) or not ResourceLoader.exists(path):
		_use_fallback(profile)
		return
	var source := load(path) as PackedScene
	if source == null:
		_use_fallback(profile)
		return
	_model = source.instantiate() as Node3D
	add_child(_model)
	_skeleton = _find_skeleton(_model)
	if _skeleton == null or _skeleton.find_bone("pelvis") < 0:
		_model.queue_free()
		_use_fallback(profile)
		return
	scale = Vector3.ONE * float(profile.get("rider_scale", 1.0))
	var offset: Array = profile.get("rider_offset", [0.0, 0.0, 0.0])
	position = Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
	_model.rotation.y = PI # Source face points +Z; motorcycle front is -Z.
	_model.scale = Vector3.ONE * 0.98
	_suit = RidingSuit.new()
	_suit.configure(_model)
	_pose = RidingPose.new()
	_pose.configure(_skeleton, self, profile)
	_helmet = Helmet.new()
	_helmet.name = "Helmet"
	add_child(_helmet)
	_helmet.build()
	for side in ["l", "r"]:
		var boot := Boot.new()
		boot.name = "Boot_" + side
		add_child(boot)
		boot.build()
		_boots.append(boot)
	animate(0.0, 0.0, 0.0, 1.0)

func set_cockpit_view(enabled: bool) -> void:
	if is_instance_valid(_fallback):
		_fallback.set_cockpit_view(enabled)
		return
	if _suit:
		_suit.set_cockpit_view(enabled)
	if is_instance_valid(_helmet):
		_helmet.visible = not enabled

func animate(speed_mps: float, steering: float, lean: float, delta: float) -> void:
	if _pose == null:
		return
	_pose.update(speed_mps, steering, lean, delta)
	if is_instance_valid(_helmet):
		_helmet.transform = _pose.helmet_transform()
	if _boots.size() >= 2 and is_instance_valid(_boots[0]) and is_instance_valid(_boots[1]):
		_boots[0].position = _pose.ankle_position("l")
		_boots[1].position = _pose.ankle_position("r")
		_boots[0].follow_leg(_pose.calf_direction("l"))
		_boots[1].follow_leg(_pose.calf_direction("r"))

func contact_report() -> Dictionary:
	return _pose.contact_report() if _pose else {"fallback": true}

func _use_fallback(profile: Dictionary) -> void:
	_fallback = Fallback.new()
	_fallback.name = "ProceduralFallback"
	add_child(_fallback)
	_fallback.configure(profile)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	if node is AnimationPlayer:
		node.stop()
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null
