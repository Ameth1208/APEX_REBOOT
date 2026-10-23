class_name RouteRecon
extends RefCounted
## Auto-detects road properties from OSM data so the builder doesn't need to ask.
## Fetches highway tags (surface, barrier, bridge, layer) and terrain context.

const Overpass = preload("res://scripts/world/overpass_client.gd")

## Query OSM for highway features near the route and auto-fill definition.
static func analyse(definition: Dictionary) -> Dictionary:
	var geo: Dictionary = definition.get("geo", {})
	if geo.is_empty():
		return {"ok": false, "error": "no_geo"}
	var points: Array = definition.get("points", [])
	if points.is_empty():
		return {"ok": false, "error": "no_points"}
	# Bounding box from control points.
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for p: Dictionary in points:
		min_x = minf(min_x, float(p["x"]))
		max_x = maxf(max_x, float(p["x"]))
		min_z = minf(min_z, float(p["z"]))
		max_z = maxf(max_z, float(p["z"]))
	var margin: float = 40.0
	var sw: Dictionary = GeoProjection.inverse(min_x - margin, max_z + margin, geo)
	var ne: Dictionary = GeoProjection.inverse(max_x + margin, min_z - margin, geo)
	if not sw.get("ok", false) or not ne.get("ok", false):
		return {"ok": false, "error": "projection"}
	# Query highways, barriers, bridges, terrain context.
	var query: String = "[out:json][timeout:20];\n(\n  way[\"highway\"](%f,%f,%f,%f);\n  way[\"barrier\"](%f,%f,%f,%f);\n  way[\"bridge\"](%f,%f,%f,%f);\n  way[\"landuse\"](%f,%f,%f,%f);\n  way[\"natural\"](%f,%f,%f,%f);\n);\nout tags;" % [
		float(sw["lat"]), float(sw["lon"]), float(ne["lat"]), float(ne["lon"]),
		float(sw["lat"]), float(sw["lon"]), float(ne["lat"]), float(ne["lon"]),
		float(sw["lat"]), float(sw["lon"]), float(ne["lat"]), float(ne["lon"]),
		float(sw["lat"]), float(sw["lon"]), float(ne["lat"]), float(ne["lon"]),
		float(sw["lat"]), float(sw["lon"]), float(ne["lat"]), float(ne["lon"])]
	var data: Dictionary = _fetch(query)
	if data.has("error"):
		return {"ok": false, "error": data["error"]}
	# Analyse tags.
	var result: Dictionary = {
		"ok": true,
		"surface": "",
		"barriers": false,
		"bridge": false,
		"terrain_type": "",
		"terrain_hills": 0.0,
		"runoff_width": 4.0,
		"runoff_surface": "gravel",
		"highway_type": "",
	}
	var surface_votes: Dictionary = {}
	var barrier_found: bool = false
	var bridge_found: bool = false
	var highway_types: Dictionary = {}
	var landuse_types: Dictionary = {}
	for el: Dictionary in data.get("elements", []):
		var tags: Dictionary = el.get("tags", {})
		if tags.has("highway"):
			var hw: String = str(tags["highway"])
			highway_types[hw] = highway_types.get(hw, 0) + 1
			if tags.has("surface"):
				var s: String = str(tags["surface"]).to_lower()
				if s in ["asphalt", "concrete", "gravel", "dirt", "grass", "sand", "compacted", "paving_stones", "sett", "cobblestone"]:
					surface_votes[s] = surface_votes.get(s, 0) + 1
				elif s in ["chipseal", "fine_gravel"]:
					surface_votes["asphalt"] = surface_votes.get("asphalt", 0) + 1
		if tags.has("barrier"):
			var b: String = str(tags["barrier"])
			if b in ["guardrail", "wall", "fence", "handrail", "cable_barrier"]:
				barrier_found = true
		if tags.has("bridge"):
			bridge_found = true
		if tags.has("landuse"):
			landuse_types[str(tags["landuse"])] = landuse_types.get(str(tags["landuse"]), 0) + 1
		if tags.has("natural"):
			landuse_types[str(tags["natural"])] = landuse_types.get(str(tags["natural"]), 0) + 1
	# Resolve surface.
	var best_surface: String = ""
	var best_votes: int = 0
	for s: String in surface_votes:
		if int(surface_votes[s]) > best_votes:
			best_surface = s
			best_votes = int(surface_votes[s])
	# Normalise surface to APEX types.
	result["surface"] = _normalise_surface(best_surface)
	# Resolve highway type.
	var best_hw: String = ""
	best_votes = 0
	for hw: String in highway_types:
		if int(highway_types[hw]) > best_votes:
			best_hw = hw
			best_votes = int(highway_types[hw])
	result["highway_type"] = best_hw
	# Barriers: only if guardrail/wall present, not just fence.
	result["barriers"] = barrier_found
	# Bridge detection.
	result["bridge"] = bridge_found
	# Terrain type and hills from landuse.
	result["terrain_type"] = _classify_terrain(landuse_types, best_hw)
	result["terrain_hills"] = _estimate_hills(result["terrain_type"], definition)
	# Runoff: wider on highways, narrower on rural roads.
	if best_hw in ["motorway", "trunk", "primary"]:
		result["runoff_width"] = 6.0
		result["runoff_surface"] = "gravel"
	elif best_hw in ["secondary", "tertiary"]:
		result["runoff_width"] = 4.5
		result["runoff_surface"] = "gravel"
	elif best_hw in ["residential", "unclassified", "service"]:
		result["runoff_width"] = 2.5
		result["runoff_surface"] = "dirt"
	else:
		result["runoff_width"] = 3.5
		result["runoff_surface"] = "gravel"
	return result

## Apply recon results to the track definition in-place.
static func apply(definition: Dictionary, recon: Dictionary) -> void:
	if not recon.get("ok", false):
		return
	if str(recon["surface"]) != "":
		definition["runoff_surface"] = str(recon["runoff_surface"])
		for p: Dictionary in definition.get("points", []):
			p["surface"] = str(recon["surface"])
	definition["barriers"] = bool(recon["barriers"])
	definition["terrain_hills"] = float(recon["terrain_hills"])
	definition["runoff_width"] = float(recon["runoff_width"])
	# Store recon info for debugging/UI.
	definition["recon"] = recon

static func _normalise_surface(s: String) -> String:
	match s:
		"asphalt", "concrete", "gravel", "dirt", "grass", "sand": return s
		"compacted", "paving_stones", "sett", "cobblestone": return "concrete"
		_: return ""

static func _classify_terrain(landuse: Dictionary, highway: String) -> String:
	# Priority: mountain > forest > urban > rural > coastal.
	if landuse.has("forest") or landuse.has("wood") or landuse.has("mountain"):
		return "forest"
	if landuse.has("residential") or landuse.has("commercial") or landuse.has("industrial") or landuse.has("retail"):
		return "urban"
	if landuse.has("farmland") or landuse.has("meadow") or landuse.has("grassland") or landuse.has("orchard"):
		return "rural"
	if highway in ["motorway", "trunk", "primary", "secondary"]:
		return "highway"
	return "rural"

static func _estimate_hills(terrain_type: String, definition: Dictionary) -> float:
	# Estimate terrain hill amplitude from the road's own elevation range.
	var points: Array = definition.get("points", [])
	var min_y: float = INF
	var max_y: float = -INF
	for p: Dictionary in points:
		if p.get("y") != null:
			min_y = minf(min_y, float(p["y"]))
			max_y = maxf(max_y, float(p["y"]))
	var elevation_range: float = max_y - min_y if min_y < INF else 0.0
	# If the road itself climbs, the terrain should have hills too.
	var base_hills: float = clampf(elevation_range * 0.35, 0.0, 40.0)
	match terrain_type:
		"forest": return maxf(base_hills, 8.0)
		"urban": return maxf(base_hills * 0.3, 1.0)
		"highway": return maxf(base_hills * 0.5, 2.0)
		"rural": return maxf(base_hills, 4.0)
		_: return maxf(base_hills, 3.0)

static func _fetch(query: String) -> Dictionary:
	var http: HTTPClient = HTTPClient.new()
	var err: int = http.connect_to_host("overpass-api.de", 443)
	if err != OK:
		return {"error": "connect"}
	var tries: int = 0
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		tries += 1
		if tries > 200:
			return {"error": "timeout"}
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"error": "not_connected"}
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	var body: String = "data=" + query.uri_encode()
	err = http.request(HTTPClient.METHOD_POST, "/api/interpreter", headers, body)
	if err != OK:
		return {"error": "request"}
	tries = 0
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		tries += 1
		if tries > 200:
			return {"error": "timeout"}
	var response: PackedByteArray = PackedByteArray()
	tries = 0
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk: PackedByteArray = http.read_response_body_chunk()
		if chunk.size() > 0:
			response.append_array(chunk)
		tries += 1
		if tries > 2000:
			return {"error": "body_timeout"}
	http.close()
	var json: JSON = JSON.new()
	if json.parse(response.get_string_from_utf8()) != OK:
		return {"error": "parse"}
	return json.data if (json.data is Dictionary) else {"error": "not_dict"}