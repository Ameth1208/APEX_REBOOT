class_name CircuitTrack
extends Node3D

const OsmTerrain = preload("res://scripts/world/osm_terrain.gd")

var definition: Dictionary = {}
var samples: Array[Dictionary] = []
var length_m: float = 0.0
var closed: bool = true
var build_error: String = ""
var _sampler: TrackSampler = TrackSampler.new()

func build(source: Dictionary) -> void:
	build_error = TrackValidation.source_error(source)
	if not build_error.is_empty():
		push_warning(build_error)
		return
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	definition = TrackDefinition.clean(source)
	closed = bool(definition["closed"])
	_sampler.rebuild(definition)
	samples = _sampler.samples
	length_m = _sampler.length_m
	TrackRoadMesh.build(self, samples, definition)
	TrackTerrain.build(self, samples, definition)
	TrackProps.build(self, _sampler, definition)
	if definition.get("geo", null) != null:
		OsmTerrain.add_buildings(self, samples, definition)

func get_length() -> float:
	return length_m

func sample_at(distance: float) -> Dictionary:
	return _sampler.sample_at(distance)

func closest_distance(point: Vector3, hint_distance: float = -1.0) -> float:
	return _sampler.closest_distance(to_local(point), hint_distance)

func get_spawn_transform(distance: float = 0.0, lateral: float = 0.0) -> Transform3D:
	var s: Dictionary = sample_at(distance)
	var basis: Basis = Basis(s["right"], s["normal"], -s["forward"]).orthonormalized()
	var origin: Vector3 = s["position"] + s["right"] * lateral + s["normal"] * 1.2
	return global_transform * Transform3D(basis, origin)

func get_grid_transform(slot: int = 0) -> Transform3D:
	var distance: float = 8.0 + float(slot / 2) * 9.0
	if not closed:
		distance = clampf(distance, 4.0, maxf(4.0, length_m - 8.0))
	var sample: Dictionary = sample_at(distance)
	var lateral: float = minf(1.8, float(sample["width"]) * 0.25)
	return get_spawn_transform(distance, lateral * (-1.0 if slot % 2 == 0 else 1.0))

func get_elevation_range() -> Vector2:
	var bounds: Vector2 = Vector2(INF, -INF)
	for sample: Dictionary in samples:
		var position: Vector3 = sample["position"]
		bounds.x = minf(bounds.x, position.y)
		bounds.y = maxf(bounds.y, position.y)
	return bounds
