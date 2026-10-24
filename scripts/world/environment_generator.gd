class_name EnvironmentGenerator
extends RefCounted
## Fuses map vectors, DEM and land-cover data into an EnvironmentCell grid.
## Produces biome classification, material weights and object density rules.
## Runs offline at track creation time, never during a race.

const OsmTerrain = preload("res://scripts/world/osm_terrain.gd")

## Zone radii from road centreline (Section 53).
const ZONE_A: float = 100.0
const ZONE_B: float = 500.0
const CELL_SIZE: float = 64.0

## Biome palettes: asset selections per biome (Section 12).
const BIOME_PALETTES: Dictionary = {
	"tropical_dry": {
		"trees": ["palm", "tropical_broadleaf"], "grass": ["dry_grass"],
		"soil_color": Color(0.62, 0.48, 0.32), "grass_color": Color(0.45, 0.52, 0.22),
		"buildings": ["rural_house_concrete"]},
	"tropical_wet": {
		"trees": ["palm", "rainforest"], "grass": ["lush_grass"],
		"soil_color": Color(0.42, 0.35, 0.24), "grass_color": Color(0.28, 0.48, 0.18),
		"buildings": ["rural_house_wood"]},
	"agricultural": {
		"trees": ["broadleaf", "orchard"], "grass": ["field_grass"],
		"soil_color": Color(0.55, 0.44, 0.30), "grass_color": Color(0.40, 0.50, 0.20),
		"buildings": ["farm_house", "barn"]},
	"urban": {
		"trees": ["street_tree"], "grass": ["lawn"],
		"soil_color": Color(0.50, 0.48, 0.45), "grass_color": Color(0.32, 0.45, 0.20),
		"buildings": ["urban_low_rise", "commercial"]},
	"forest": {
		"trees": ["conifer", "broadleaf", "oak"], "grass": ["forest_floor"],
		"soil_color": Color(0.38, 0.32, 0.22), "grass_color": Color(0.25, 0.38, 0.15),
		"buildings": ["cabin"]},
	"coastal": {
		"trees": ["palm", "coastal_shrub"], "grass": ["beach_grass"],
		"soil_color": Color(0.78, 0.70, 0.55), "grass_color": Color(0.50, 0.55, 0.30),
		"buildings": ["coastal_house"]},
	"mountain": {
		"trees": ["conifer", "pine"], "grass": ["alpine_grass"],
		"soil_color": Color(0.48, 0.44, 0.40), "grass_color": Color(0.35, 0.42, 0.25),
		"buildings": ["mountain_cabin"]},
	"desert": {
		"trees": ["cactus", "dry_shrub"], "grass": ["sparse_grass"],
		"soil_color": Color(0.80, 0.70, 0.50), "grass_color": Color(0.55, 0.52, 0.30),
		"buildings": ["adobe_house"]},
}

## Environment cell grid.
var cells: Array[Dictionary] = []
var grid_origin: Vector2 = Vector2.ZERO
var grid_nx: int = 0
var grid_nz: int = 0
var biome: String = "agricultural"
var biome_confidence: float = 0.5
var surroundings: Dictionary = {}
var _total_length: float = 0.0

## Build from track samples and OSM surroundings.
func build(track_samples: Array[Dictionary], definition: Dictionary, osm_data: Dictionary = {}) -> void:
	surroundings = osm_data
	if track_samples.is_empty():
		return
	# Compute bounds.
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	for s: Dictionary in track_samples:
		var p: Vector3 = s["position"]
		min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.z))
		max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.z))
	_total_length = 0.0
	for i: int in range(1, track_samples.size()):
		var a: Vector3 = track_samples[i - 1]["position"]
		var b: Vector3 = track_samples[i]["position"]
		_total_length += Vector2(a.x - b.x, a.z - b.z).length()
	# Expand by zone B.
	min_p -= Vector2(ZONE_B, ZONE_B)
	max_p += Vector2(ZONE_B, ZONE_B)
	grid_origin = min_p
	grid_nx = ceili((max_p.x - min_p.x) / CELL_SIZE) + 1
	grid_nz = ceili((max_p.y - min_p.y) / CELL_SIZE) + 1
	# Cap grid size for performance.
	grid_nx = mini(grid_nx, 40)
	grid_nz = mini(grid_nz, 40)
	_classify_biome(definition)
	# Build cells.
	cells.resize(grid_nx * grid_nz)
	for iz: int in range(grid_nz):
		for ix: int in range(grid_nx):
			var center: Vector2 = grid_origin + Vector2(ix, iz) * CELL_SIZE + Vector2(CELL_SIZE, CELL_SIZE) * 0.5
			cells[iz * grid_nx + ix] = _build_cell(center, track_samples)

func _classify_biome(definition: Dictionary) -> void:
	# Use landcover data if available, else infer from OSM landuse.
	var landuse: Dictionary = {}
	for entry: Dictionary in surroundings.get("surfaces", []):
		var tags: Dictionary = entry.get("tags", {})
		if tags.has("landuse"):
			landuse[str(tags["landuse"])] = landuse.get(str(tags["landuse"]), 0) + 1
	# Classify.
	var urban_votes: int = int(landuse.get("residential", 0)) + int(landuse.get("commercial", 0)) + int(landuse.get("industrial", 0))
	var farm_votes: int = int(landuse.get("farmland", 0)) + int(landuse.get("orchard", 0)) + int(landuse.get("meadow", 0))
	var forest_votes: int = int(landuse.get("forest", 0)) + int(landuse.get("wood", 0))
	var total: int = urban_votes + farm_votes + forest_votes + 1
	if urban_votes > farm_votes and urban_votes > forest_votes:
		biome = "urban"
		biome_confidence = float(urban_votes) / float(total)
	elif forest_votes > farm_votes:
		biome = "forest"
		biome_confidence = float(forest_votes) / float(total)
	else:
		biome = "agricultural"
		biome_confidence = float(farm_votes) / float(total)
	# Override by elevation if available.
	var geo: Dictionary = definition.get("geo", {})
	if geo.has("origin_alt_m"):
		var alt: Variant = geo.get("origin_alt_m")
		if alt != null and float(alt) > 800.0:
			biome = "mountain"
			biome_confidence = 0.6

func _build_cell(center: Vector2, samples: Array[Dictionary]) -> Dictionary:
	# Road distance (Section 7).
	var min_road_dist: float = INF
	var nearest_width: float = 12.0
	for s: Dictionary in samples:
		var p: Vector3 = s["position"]
		var d: float = center.distance_to(Vector2(p.x, p.z))
		if d < min_road_dist:
			min_road_dist = d
			nearest_width = float(s.get("width", 12.0))
	# Road mask (Section 7).
	var half_w: float = nearest_width * 0.5
	var transition: float = 6.0
	var road_mask: float = 1.0 - smoothstep(half_w, half_w + transition, min_road_dist)
	# Land cover probabilities from OSM (Section 8).
	var probs: Dictionary = _landcover_at(center)
	# Material weights (Section 14): W = P * (1 - M_road).
	var weights: Dictionary = {}
	var w_sum: float = 0.0
	for key: String in ["grass", "bare", "crops", "trees", "built"]:
		var w: float = float(probs.get(key, 0.0)) * (1.0 - road_mask)
		weights[key] = w
		w_sum += w
	# Normalise.
	if w_sum > 0.001:
		for key: String in weights:
			weights[key] = float(weights[key]) / w_sum
	# Zone classification.
	var zone: int = 0
	if min_road_dist > ZONE_B:
		zone = 2
	elif min_road_dist > ZONE_A:
		zone = 1
	# Object density from biome + landcover.
	var palette: Dictionary = BIOME_PALETTES.get(biome, BIOME_PALETTES["agricultural"])
	var tree_density: float = float(probs.get("trees", 0.1)) * (1.0 - road_mask)
	var building_density: float = float(probs.get("built", 0.0)) * (1.0 - road_mask)
	return {
		"center": center,
		"road_distance": min_road_dist,
		"road_mask": road_mask,
		"zone": zone,
		"weights": weights,
		"probs": probs,
		"tree_density": tree_density,
		"building_density": building_density,
		"biome": biome,
		"palette": palette,
		"soil_color": palette.get("soil_color", Color(0.5, 0.4, 0.3)),
		"grass_color": palette.get("grass_color", Color(0.35, 0.45, 0.2)),
	}

func _landcover_at(point: Vector2) -> Dictionary:
	# Start with neutral.
	var probs: Dictionary = {"grass": 0.3, "bare": 0.1, "crops": 0.1, "trees": 0.2, "built": 0.05, "water": 0.0}
	# Override from OSM surfaces.
	for entry: Dictionary in surroundings.get("surfaces", []):
		var polygon: Array[Vector2] = entry["polygon"]
		if OsmTerrain.point_in_polygon(point, polygon):
			var surf: String = str(entry["surface"])
			var tags: Dictionary = entry.get("tags", {})
			var landuse: String = str(tags.get("landuse", tags.get("natural", "")))
			match landuse:
				"forest", "wood":
					probs = {"grass": 0.1, "bare": 0.1, "crops": 0.0, "trees": 0.75, "built": 0.0, "water": 0.0}
				"farmland", "orchard", "meadow", "vineyard":
					probs = {"grass": 0.2, "bare": 0.1, "crops": 0.6, "trees": 0.05, "built": 0.0, "water": 0.0}
				"residential", "commercial", "industrial", "retail":
					probs = {"grass": 0.1, "bare": 0.3, "crops": 0.0, "trees": 0.05, "built": 0.55, "water": 0.0}
				"grassland", "park", "village_green":
					probs = {"grass": 0.7, "bare": 0.1, "crops": 0.0, "trees": 0.15, "built": 0.0, "water": 0.0}
				"sand", "beach":
					probs = {"grass": 0.05, "bare": 0.85, "crops": 0.0, "trees": 0.02, "built": 0.0, "water": 0.0}
			break
	# Water override.
	for entry: Dictionary in surroundings.get("water", []):
		if OsmTerrain.point_in_polygon(point, entry["polygon"]):
			probs = {"grass": 0.0, "bare": 0.0, "crops": 0.0, "trees": 0.0, "built": 0.0, "water": 1.0}
			break
	return probs

## GeoBrush: query material/vegetation rules at a world position (Section 13).
func brush_at(world_pos: Vector2) -> Dictionary:
	var ix: int = clampi(floori((world_pos.x - grid_origin.x) / CELL_SIZE), 0, grid_nx - 1)
	var iz: int = clampi(floori((world_pos.y - grid_origin.y) / CELL_SIZE), 0, grid_nz - 1)
	if cells.is_empty():
		return {}
	return cells[iz * grid_nx + ix]

## Get cells in a zone (0=A, 1=B, 2=C).
func cells_in_zone(zone: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Dictionary in cells:
		if int(cell.get("zone", 0)) == zone:
			result.append(cell)
	return result

## Building generation rules per biome (Section 26-27).
func building_grammar() -> Dictionary:
	match biome:
		"urban":
			return {"floors_min": 1, "floors_max": 3, "roof": "flat", "wall": "concrete",
				"balcony_prob": 0.4, "commercial_prob": 0.3}
		"agricultural":
			return {"floors_min": 1, "floors_max": 1, "roof": "tile", "wall": "concrete",
				"balcony_prob": 0.0, "commercial_prob": 0.0}
		"forest":
			return {"floors_min": 1, "floors_max": 2, "roof": "gable", "wall": "wood",
				"balcony_prob": 0.1, "commercial_prob": 0.0}
		"coastal":
			return {"floors_min": 1, "floors_max": 2, "roof": "flat", "wall": "stucco",
				"balcony_prob": 0.3, "commercial_prob": 0.1}
		"mountain":
			return {"floors_min": 1, "floors_max": 2, "roof": "steep_gable", "wall": "stone",
				"balcony_prob": 0.0, "commercial_prob": 0.0}
		_:
			return {"floors_min": 1, "floors_max": 1, "roof": "gable", "wall": "concrete",
				"balcony_prob": 0.0, "commercial_prob": 0.0}

## Roadside rules per zone (Section 21).
func roadside_rules(distance_from_road: float) -> Dictionary:
	if distance_from_road < 1.5:
		return {"trees": false, "grass": true, "props": false, "buildings": false}
	elif distance_from_road < 4.0:
		return {"trees": false, "grass": true, "props": true, "buildings": false}
	elif distance_from_road < 10.0:
		return {"trees": true, "grass": true, "props": true, "buildings": distance_from_road > 6.0}
	else:
		return {"trees": true, "grass": true, "props": true, "buildings": true}

## Scene type for a position (Section 44).
func scene_type_at(distance_from_road: float) -> String:
	if distance_from_road > ZONE_B:
		return "background"
	elif distance_from_road > ZONE_A:
		match biome:
			"urban": return "urban_edge"
			"forest": return "forest_road"
			"agricultural": return "agricultural"
			_: return "rural"
	else:
		match biome:
			"urban": return "urban_road"
			"forest": return "forest_road"
			"mountain": return "mountain_road"
			"coastal": return "coastal_road"
			_: return "rural_road"

## Summary for UI (Section 65).
func summary() -> Dictionary:
	return {
		"biome": biome,
		"biome_label": biome.replace("_", " ").capitalize(),
		"confidence": biome_confidence,
		"length_km": _total_length / 1000.0,
		"cell_count": cells.size(),
		"zone_a_cells": cells_in_zone(0).size(),
		"zone_b_cells": cells_in_zone(1).size(),
		"zone_c_cells": cells_in_zone(2).size(),
	}