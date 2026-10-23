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
	var nodes: Dictionary = {}
	for el: Dictionary in data.get("elements", []):
		if el.get("type") == "node":
			nodes[el["id"]] = el
	var buildings: Array = []
	var surfaces: Array = []
	var water: Array = []
	var vegetation: Array = []
	for el: Dictionary in data.get("elements", []):
		if el.get("type") != "way":
			continue
		var tags: Dictionary = el.get("tags", {})
		var nds: Array = el.get("nodes", [])
		if nds.size() < 3:
			continue
		var pts: Array[Vector2] = []
		for nid in nds:
			var n: Dictionary = nodes.get(nid, {})
			if n.is_empty():
				continue
			var proj: Dictionary = GeoProjection.project(float(n.get("lat", 0.0)), float(n.get("lon", 0.0)), null, geo)
			if not proj.get("ok", false):
				continue
			pts.append(Vector2(float(proj["x"]), float(proj["z"])))
		if pts.size() < 3:
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
				if key in ["forest", "wood"]:
					vegetation.append({"polygon": pts, "tags": tags})
	return {"ok": true, "buildings": buildings, "surfaces": surfaces, "water": water, "vegetation": vegetation}

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
