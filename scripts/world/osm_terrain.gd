class_name OsmTerrain
extends RefCounted

## Builds real-world surroundings (buildings) from OpenStreetMap via Overpass.

const Overpass = preload("res://scripts/world/overpass_client.gd")

static func add_buildings(parent: Node3D, samples: Array[Dictionary], definition: Dictionary) -> void:
	var geo: Dictionary = definition.get("geo", {})
	if geo.is_empty():
		return
	# Bounding box from samples projected to lat/lon.
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
	# Convert local bbox back to lat/lon using origin.
	var sw: Dictionary = GeoProjection.inverse(min_x, max_z, geo)
	var ne: Dictionary = GeoProjection.inverse(max_x, min_z, geo)
	if not sw.get("ok", false) or not ne.get("ok", false):
		return
	var data: Dictionary = Overpass.fetch_bbox(float(sw["lat"]), float(sw["lon"]), float(ne["lat"]), float(ne["lon"]))
	if data.has("error"):
		push_warning("OsmTerrain: " + str(data["error"]))
		return
	var nodes: Dictionary = {}
	for el: Dictionary in data.get("elements", []):
		if el.get("type") == "node":
			nodes[el["id"]] = el
	# Build buildings
	var origin_lat: float = float(geo["origin_lat"])
	var origin_lon: float = float(geo["origin_lon"])
	for el: Dictionary in data.get("elements", []):
		if el.get("type") != "way":
			continue
		var tags: Dictionary = el.get("tags", {})
		if not tags.has("building"):
			continue
		var nds: Array = el.get("nodes", [])
		if nds.size() < 3:
			continue
		# Collect local coords
		var pts: Array[Vector2] = []
		for nid in nds:
			var n: Dictionary = nodes.get(nid, {})
			if n.is_empty():
				continue
			var lat: float = float(n.get("lat", 0.0))
			var lon: float = float(n.get("lon", 0.0))
			var proj: Dictionary = GeoProjection.project(lat, lon, null, geo)
			if not proj.get("ok", false):
				continue
			pts.append(Vector2(float(proj["x"]), float(proj["z"])))
		if pts.size() < 3:
			continue
		# Bounding box of polygon
		var minp: Vector2 = pts[0]
		var maxp: Vector2 = pts[0]
		for pt: Vector2 in pts:
			minp.x = minf(minp.x, pt.x)
			minp.y = minf(minp.y, pt.y)
			maxp.x = maxf(maxp.x, pt.x)
			maxp.y = maxf(maxp.y, pt.y)
		var center: Vector3 = Vector3((minp.x + maxp.x) * 0.5, 0.0, (minp.y + maxp.y) * 0.5)
		var size_x: float = maxf(maxp.x - minp.x, 1.0)
		var size_z: float = maxf(maxp.y - minp.y, 1.0)
		var height: float = 6.0
		if tags.has("height"):
			height = float(str(tags["height"]).replace("m", "").strip())
		elif tags.has("building:levels"):
			height = float(tags["building:levels"]) * 3.0
		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(size_x, height, size_z)
		mesh_inst.mesh = box
		mesh_inst.position = center + Vector3(0, height * 0.5, 0)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.75, 0.72, 0.68)
		mat.roughness = 0.85
		mesh_inst.material_override = mat
		parent.add_child(mesh_inst)