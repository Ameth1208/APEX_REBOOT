class_name ApexScenery
extends Node3D

var lights: Array[SpotLight3D] = []
var target: Node3D
var _track: Node3D
var night: bool = false
var _timer: float = 0.0
var _glow: StandardMaterial3D
var _stream_timer: float = 0.0
var _stream_roots: Array[Node] = []
var _stream_nodes: Array[Node] = []
var _stream_visible: int = 0
var _stream_loaded: int = 0
var _faithful_road: bool = false

const STREAM_UPDATE_INTERVAL: float = 0.20
const STREAM_EXTRA_MARGIN: float = 80.0

func build(track: Node3D) -> void:
	await get_tree().physics_frame
	_track = track
	_faithful_road = track.definition.has("geo") and str(track.definition.get("construction_mode", "faithful")) == "faithful"
	_stream_roots = [self, track]
	if _faithful_road:
		var vegetation: Node = track.get_node_or_null("MappedVegetation")
		if vegetation != null:
			vegetation.target = target
		# Geographic surroundings were built by TrackTerrain from mapped features.
		# Procedural circuit lamps, forests and signs have no source on this road.
		_collect_stream_nodes()
		return
	_glow = ApexMesh.material(Color("e8e3d9"))
	_glow.emission_enabled = true
	_glow.emission = Color("ffd9a1")
	_glow.emission_energy_multiplier = 0.10
	# Daytime races keep lamp geometry but skip every SpotLight3D until night is used.
	lights = ApexTrackLighting.build(self, track, _glow, night)
	ApexForest.build(self, track)
	ApexGroundCover.build(self, track)
	ApexCircuitSigns.build(self, track)
	_collect_stream_nodes()
	if str(track.definition.get("name", "")).contains("Costa"):
		var material: StandardMaterial3D = ApexMesh.material(Color("264759"), 0.0, 0.19)
		var water: MeshInstance3D = ApexMesh.box(self, Vector3(0, -11, 0), Vector3(6500, 0.5, 6500), material)
		water.set_meta("render_category", "water")
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	_timer -= delta
	_stream_timer -= delta
	if _stream_timer <= 0.0:
		_stream_timer = STREAM_UPDATE_INTERVAL
		_update_stream_chunks()
	if _timer > 0.0:
		return
	_timer = 0.2
	if _glow != null:
		_glow.emission_energy_multiplier = 1.8 if night else 0.10
	if night and not _faithful_road and lights.is_empty() and is_instance_valid(_track):
		lights = ApexTrackLighting.build_lights(self, _track)
	for light: SpotLight3D in lights:
		light.visible = bool(light.get_meta("render_feature_enabled", true)) and night and is_instance_valid(target) and light.global_position.distance_squared_to(target.global_position) < 10000.0

func _update_stream_chunks() -> void:
	if not is_instance_valid(target):
		return
	var target_position: Vector3 = target.global_position
	_stream_visible = 0
	_stream_loaded = 0
	for chunk: Node in _stream_nodes:
		if not is_instance_valid(chunk):
			continue
		var range_m: float = float(chunk.get_meta("stream_range", 460.0)) + STREAM_EXTRA_MARGIN
		var in_range: bool = chunk.global_position.distance_squared_to(target_position) <= range_m * range_m
		if in_range:
			_restore_stream_resource(chunk)
		else:
			_release_stream_resource(chunk)
		if chunk.visible != in_range:
			chunk.visible = in_range
		if in_range:
			_stream_visible += 1
		if _stream_resource_is_loaded(chunk):
			_stream_loaded += 1

func _collect_stream_nodes() -> void:
	_stream_nodes.clear()
	var pending: Array[Node] = []
	for root: Node in _stream_roots:
		if is_instance_valid(root):
			pending.append(root)
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node.get_meta("dynamic_stream_owner", false):
			continue # This subtree creates and releases its own chunks over time.
		for child: Node in node.get_children():
			pending.append(child)
			if child.get_meta("stream_chunk", false):
				_stream_nodes.append(child)
				if not child.has_meta("stream_gpu_unload"):
					child.set_meta("stream_gpu_unload", false)

func get_stream_stats() -> Dictionary:
	var vegetation_stats: Dictionary = {}
	if is_instance_valid(_track):
		var vegetation: Node = _track.get_node_or_null("MappedVegetation")
		if vegetation != null: vegetation_stats = vegetation.get_stream_stats()
	return {"total": _stream_nodes.size() + int(vegetation_stats.get("total", 0)), "visible": _stream_visible + int(vegetation_stats.get("loaded", 0)), "gpu_loaded": _stream_loaded + int(vegetation_stats.get("loaded", 0)), "planned_trees": int(vegetation_stats.get("planned_trees", 0))}

func _release_stream_resource(chunk: Node) -> void:
	if not bool(chunk.get_meta("stream_gpu_unload", false)) or not _stream_resource_is_loaded(chunk):
		return
	if chunk is MultiMeshInstance3D:
		(chunk as MultiMeshInstance3D).multimesh = null
	elif chunk is MeshInstance3D:
		(chunk as MeshInstance3D).mesh = null

func _restore_stream_resource(chunk: Node) -> void:
	if not bool(chunk.get_meta("stream_gpu_unload", false)) or _stream_resource_is_loaded(chunk):
		return
	var resource: Variant = chunk.get_meta("stream_resource", null)
	if resource == null:
		return
	if chunk is MultiMeshInstance3D and resource is MultiMesh:
		(chunk as MultiMeshInstance3D).multimesh = resource
	elif chunk is MeshInstance3D and resource is Mesh:
		(chunk as MeshInstance3D).mesh = resource

func _stream_resource_is_loaded(chunk: Node) -> bool:
	if chunk is MultiMeshInstance3D:
		return (chunk as MultiMeshInstance3D).multimesh != null
	if chunk is MeshInstance3D:
		return (chunk as MeshInstance3D).mesh != null
	return true
