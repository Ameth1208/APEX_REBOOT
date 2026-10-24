class_name OsmTerrain
extends RefCounted

## Builds real-world surroundings from OpenStreetMap via Overpass:
## buildings, landuse-based surface classification, water and vegetation.

const Overpass = preload("res://scripts/world/overpass_client.gd")

## OSM landuse / natural values mapped to APEX surface types.
const LANDUSE_MAP: Dictionary = {
	"forest": "grass", "wood": "grass", "grassland": "grass",
	"meadow": "grass", "village_green": "grass", "park": "grass",
	"farmland": "grass", "orchard": "grass", "vineyard": "grass",
	"residential": "concrete", "commercial": "concrete", "industrial": "concrete",
	"retail": "concrete", "cemetery": "grass", "recreation_ground": "grass",
	"sand": "sand", "beach": "sand", "dune": "sand",
	"quarry": "dirt", "construction": "dirt", "brownfield": "dirt",
	"landfill": "dirt", "allotments": "dirt",
	"water": "grass", "reservoir": "grass", "basin": "grass",
	"wetland": "grass", "mud": "dirt",
}

## Returns a Dictionary with:
##  - buildings: Array of {center: Vector3, size_x, size_z, height, tags}
##  - surfaces:  Array of {polygon: Array[Vector2], surface: String, tags}
##  - water:     Array of {polygon: Array[Vector2]}
##  - vegetation:Array of {polygon: Array[Vector2]}
static func fetch_surroundings(samples: Array[Dictionary], definition: Dictionary, margin_m: float = 220.0) -> Dictionary:
	var geo: Dictionary = definition.get("geo", {})
	if geo.is_empty():
		return {"ok": false, "error": "no_geo"}
	var saved_path: String = str(definition.get("surroundings_path", ""))
	if not saved_path.is_empty() and FileAccess.file_exists(saved_path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(saved_path))
		if saved is Dictionary and str(saved.get("source_file_sha256", "")) == str(geo.get("source_file_sha256", "")):
			return parse_elements(saved, geo)
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for s: Dictionary in samples:
		var p: Vector3 = s["position"]
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
	min_x -= margin_m
	max_x += margin_m
	min_z -= margin_m
	max_z += margin_m
	var sw: Dictionary = GeoProjection.inverse(min_x, max_z, geo)
	var ne: Dictionary = GeoProjection.inverse(max_x, min_z, geo)
	if not sw.get("ok", false) or not ne.get("ok", false):
		return {"ok": false, "error": "projection_failed"}
	var data: Dictionary = Overpass.fetch_bbox(float(sw["lat"]), float(sw["lon"]), float(ne["lat"]), float(ne["lon"]))
	if data.has("error"):
		return {"ok": false, "error": data["error"]}
	return parse_elements(data, geo)

static func parse_elements(data: Dictionary, geo: Dictionary) -> Dictionary:
	var nodes: Dictionary = {}
	for el: Dictionary in data.get("elements", []):
		if el.get("type") == "node":
			nodes[el["id"]] = el
	var buildings: Array = []
	var surfaces: Array = []
	var water: Array = []
	var vegetation: Array = []
	var trees: Array = []
	var rows: Array = []
	for el: Dictionary in data.get("elements", []):
		var tags: Dictionary = el.get("tags", {})
		if el.get("type") == "node" and tags.get("natural") == "tree":
			var projected: Dictionary = GeoProjection.project(float(el.lat), float(el.lon), null, geo)
			if projected.get("ok", false):
				trees.append({"position": Vector2(projected.x, projected.z), "tags": tags, "source": "osm_node", "id": el.id})
		if el.get("type") != "way":
			continue
		var nds: Array = el.get("nodes", [])
		if nds.size() < 2 and el.get("geometry", []).size() < 2:
			continue
		var pts: Array[Vector2] = []
		var geometry: Array = el.get("geometry", [])
		for index: int in range(maxi(nds.size(), geometry.size())):
			var n: Dictionary = geometry[index] if index < geometry.size() else nodes.get(nds[index], {})
			if n.is_empty():
				continue
			var proj: Dictionary = GeoProjection.project(float(n.get("lat", 0.0)), float(n.get("lon", 0.0)), null, geo)
			if not proj.get("ok", false):
				continue
			pts.append(Vector2(float(proj["x"]), float(proj["z"])))
		if tags.get("natural") == "tree_row" and pts.size() >= 2:
			rows.append({"points": pts, "tags": tags, "source": "osm_row", "id": el.id})
			continue
		if pts.size() < 3 or (pts[0].distance_to(pts[-1]) > 0.1):
			continue
		if tags.has("building"):
			var h: float = 6.0
			if tags.has("height"):
				h = float(str(tags["height"]).replace("m", "").strip_edges())
			elif tags.has("building:levels"):
				h = float(tags["building:levels"]) * 3.0
			var minp: Vector2 = pts[0]
			var maxp: Vector2 = pts[0]
			for pt: Vector2 in pts:
				minp = Vector2(minf(minp.x, pt.x), minf(minp.y, pt.y))
				maxp = Vector2(maxf(maxp.x, pt.x), maxf(maxp.y, pt.y))
			buildings.append({
				"polygon": pts,
				"center": Vector3((minp.x + maxp.x) * 0.5, 0.0, (minp.y + maxp.y) * 0.5),
				"size_x": maxf(maxp.x - minp.x, 1.0),
				"size_z": maxf(maxp.y - minp.y, 1.0),
				"height": clampf(h, 3.0, 120.0),
				"tags": tags,
			})
		elif tags.has("waterway") or tags.get("natural") == "water":
			water.append({"polygon": pts, "tags": tags})
		elif tags.has("landuse") or tags.has("natural"):
			var key: String = str(tags.get("landuse", tags.get("natural", "")))
			var surf: String = LANDUSE_MAP.get(key, "")
			if not surf.is_empty():
				surfaces.append({"polygon": pts, "surface": surf, "tags": tags})
				if key in ["forest", "wood", "orchard"]:
					vegetation.append({"polygon": pts, "tags": tags, "source": "osm_area", "id": el.id})
	return {"ok": true, "buildings": buildings, "surfaces": surfaces, "water": water, "vegetation": vegetation, "trees": trees, "tree_rows": rows}

static func add_landcover(surroundings: Dictionary, definition: Dictionary) -> void:
	var path: String = str(definition.get("landcover_path", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var grid: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var geo: Dictionary = definition.get("geo", {})
	if not grid is Dictionary or str(grid.get("source_file_sha256", "")) != str(geo.get("source_file_sha256", "")):
		return
	var nx: int = int(grid.get("nx", 0))
	var nz: int = int(grid.get("nz", 0))
	var cover: Array = grid.get("tree_cover", [])
	var built: Array = grid.get("built_cover", [])
	var water: Array = grid.get("water_cover", [])
	if nx <= 0 or nz <= 0 or nx * nz > 100000 or cover.size() != nx * nz or built.size() != nx * nz or water.size() != nx * nz:
		return
	if not surroundings.has("vegetation"):
		surroundings["vegetation"] = []
	surroundings["vegetation_exclusions"] = []
	for z: int in nz:
		for x: int in nx:
			var fraction: float = float(cover[z * nx + x]) / 100.0
			var excluded: bool = float(built[z * nx + x]) >= 25 or float(water[z * nx + x]) >= 25
			if fraction < 0.25 and not excluded:
				continue
			var polygon: Array[Vector2] = []
			for corner: Vector2i in [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x + 1, z + 1), Vector2i(x, z + 1)]:
				var point: Dictionary = GeoProjection.project(float(grid.north) - corner.y * float(grid.cell_lat_deg), float(grid.west) + corner.x * float(grid.cell_lon_deg), null, geo)
				if point.get("ok", false):
					polygon.append(Vector2(point.x, point.z))
			if polygon.size() == 4:
				if excluded:
					surroundings.vegetation_exclusions.append({"polygon": polygon})
				else:
					surroundings.vegetation.append({"polygon": polygon, "tags": {}, "coverage": fraction, "source": str(grid.source), "estimated_positions": true})
	surroundings["landcover_source"] = grid.source
	surroundings["vegetation_attribution"] = grid.attribution

## Point-in-polygon test (even-odd rule).
static func point_in_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	var inside: bool = false
	var j: int = polygon.size() - 1
	for i: int in range(polygon.size()):
		var pi: Vector2 = polygon[i]
		var pj: Vector2 = polygon[j]
		if (pi.y > point.y) != (pj.y > point.y) and point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x:
			inside = not inside
		j = i
	return inside

## Classify a local XZ position to the most specific surface from OSM data.
static func surface_at(xz: Vector2, surroundings: Dictionary, default_surface: String) -> String:
	for entry: Dictionary in surroundings.get("water", []):
		if point_in_polygon(xz, entry["polygon"]):
			return "sand"
	for entry: Dictionary in surroundings.get("surfaces", []):
		if point_in_polygon(xz, entry["polygon"]):
			return str(entry["surface"])
	return default_surface
