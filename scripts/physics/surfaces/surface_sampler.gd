class_name ApexSurfaceSampler
extends RefCounted

## Queries surface type and properties using collider metadata and OSM zones.

const OsmTerrain = preload("res://scripts/world/osm_terrain.gd")

static var _osm_zones: Dictionary = {}

static func set_osm_zones(zones: Dictionary) -> void:
	_osm_zones = zones

static func get_osm_zones() -> Dictionary:
	return _osm_zones

static func sample_surface(xz: Vector2, collider: Object) -> String:
	# A mapped field/residential polygon must not replace the road's own material.
	if is_instance_valid(collider) and bool(collider.get_meta("is_road", false)):
		return str(collider.get_meta("surface", "asphalt"))
	if not _osm_zones.is_empty():
		var osm: String = OsmTerrain.surface_at(xz, _osm_zones, "")
		if not osm.is_empty():
			return osm
	if is_instance_valid(collider):
		return str(collider.get_meta("surface", "asphalt"))
	return "asphalt"
