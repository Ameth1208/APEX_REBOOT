class_name TrackTerrain
extends RefCounted

const OsmTerrain = preload("res://scripts/world/osm_terrain.gd")
const ApexBroadleafGeometry = preload("res://scripts/world/broadleaf_geometry.gd")
const ApexTreeGeometry = preload("res://scripts/world/tree_geometry.gd")
const ApexSceneryInstances = preload("res://scripts/world/scenery_instances.gd")

## Surface blend weights per cell vertex: smooth transitions instead of hard cuts.
## Each vertex carries a colour where R=sand, G=grass, B=dirt, A=concrete.

static func build(parent: Node3D, samples: Array[Dictionary], definition: Dictionary) -> void:
	if samples.is_empty():
		return
	var bounds: AABB = AABB(samples[0]["position"], Vector3.ZERO)
	for sample: Dictionary in samples:
		bounds = bounds.expand(sample["position"])
	var margin: float = 180.0
	var step: float = maxf(18.0, maxf(bounds.size.x, bounds.size.z) / 160.0)
	var start: Vector2 = Vector2(bounds.position.x - margin, bounds.position.z - margin)
	var nx: int = ceili((bounds.size.x + margin * 2.0) / step) + 1
	var nz: int = ceili((bounds.size.z + margin * 2.0) / step) + 1
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(definition.get("seed", 8421))
	noise.frequency = 0.008
	noise.fractal_octaves = 4
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(nx * nz)
	var road_floors: PackedFloat32Array = _road_floor_caps(samples, definition, start, step, nx, nz)
	for iz: int in range(nz):
		for ix: int in range(nx):
			var xz: Vector2 = start + Vector2(ix, iz) * step
			var height: float = bounds.position.y - 2.0 + (noise.get_noise_2d(xz.x, xz.y) + 0.6) * float(definition["terrain_hills"])
			heights[iz * nx + ix] = minf(height, road_floors[iz * nx + ix])
	# Fetch OSM surroundings for real surface classification.
	var surroundings: Dictionary = {}
	if definition.get("geo", null) != null:
		surroundings = OsmTerrain.fetch_surroundings(samples, definition, margin)
	# Build ONE blended mesh with vertex-colour surface weights.
	var buffer: TrackMeshBuffer = TrackMeshBuffer.new()
	var blend_radius: float = 18.0
	for iz: int in range(nz - 1):
		for ix: int in range(nx - 1):
			var a: Vector3 = Vector3(start.x + ix * step, heights[iz * nx + ix], start.y + iz * step)
			var b: Vector3 = Vector3(a.x + step, heights[iz * nx + ix + 1], a.z)
			var c: Vector3 = Vector3(b.x, heights[(iz + 1) * nx + ix + 1], a.z + step)
			var d: Vector3 = Vector3(a.x, heights[(iz + 1) * nx + ix], c.z)
			var normal: Vector3 = (d - a).cross(b - a).normalized()
			var ca: Color = _vertex_blend(Vector2(a.x, a.z), surroundings, definition, blend_radius)
			var cb: Color = _vertex_blend(Vector2(b.x, b.z), surroundings, definition, blend_radius)
			var cc: Color = _vertex_blend(Vector2(c.x, c.z), surroundings, definition, blend_radius)
			var cd: Color = _vertex_blend(Vector2(d.x, d.z), surroundings, definition, blend_radius)
			buffer.quad_colored(a, b, c, d, normal, ca, cb, cc, cd)
	var material: ShaderMaterial = TrackMaterials.ground_blended()
	buffer.attach(parent, "Terrain", material, str(definition["terrain_surface"]), false, 320.0)
	_verges(parent, samples, definition, bounds.position.y, start, step, nx, nz, heights, TrackMaterials.ground(str(definition["terrain_surface"])))
	if not surroundings.is_empty():
		_spawn_buildings(parent, surroundings.get("buildings", []))
		_spawn_water(parent, surroundings.get("water", []))
		_spawn_vegetation(parent, surroundings.get("vegetation", []), definition, start, step, nx, nz, heights)

## Per-vertex blend: R=sand, G=grass, B=dirt, A=concrete. Smooth by distance.
static func _vertex_blend(xz: Vector2, surroundings: Dictionary, definition: Dictionary, radius: float) -> Color:
	var default_surface: String = str(definition["terrain_surface"])
	if surroundings.is_empty():
		return _surface_to_color(default_surface)
	# Find nearest surface polygon and compute smooth weight.
	var best_surf: String = default_surface
	var best_dist: float = INF
	for entry: Dictionary in surroundings.get("surfaces", []):
		var polygon: Array[Vector2] = entry["polygon"]
		if OsmTerrain.point_in_polygon(xz, polygon):
			best_surf = str(entry["surface"])
			best_dist = 0.0
			break
		# Distance to polygon edge for blending.
		var d: float = _poly_distance(xz, polygon)
		if d < best_dist:
			best_dist = d
			best_surf = str(entry["surface"])
	# Water zones force sand near shore.
	for entry: Dictionary in surroundings.get("water", []):
		if OsmTerrain.point_in_polygon(xz, entry["polygon"]):
			return _surface_to_color("sand")
	var base: Color = _surface_to_color(best_surf)
	# Within blend radius, mix with default surface for smooth edges.
	if best_dist > 0.0 and best_dist < radius:
		var t: float = smoothstep(0.0, radius, best_dist)
		var fallback: Color = _surface_to_color(default_surface)
		base = fallback.lerp(base, 1.0 - t)
	return base

static func _surface_to_color(surface: String) -> Color:
	# R=sand, G=grass, B=dirt, A=concrete
	match surface:
		"sand": return Color(1, 0, 0, 0)
		"grass": return Color(0, 1, 0, 0)
		"dirt": return Color(0, 0, 1, 0)
		"concrete": return Color(0, 0, 0, 1)
		_: return Color(0, 1, 0, 0)

static func _poly_distance(point: Vector2, polygon: Array[Vector2]) -> float:
	var min_d: float = INF
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		var ab: Vector2 = b - a
		var t: float = clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		min_d = minf(min_d, point.distance_to(a + ab * t))
	return min_d

static func _road_floor_caps(samples: Array[Dictionary], definition: Dictionary, start: Vector2, step: float, nx: int, nz: int) -> PackedFloat32Array:
	var caps: PackedFloat32Array = PackedFloat32Array()
	caps.resize(nx * nz)
	caps.fill(INF)
	for index: int in range(samples.size()):
		if index % 2 == 1 and index != samples.size() - 1:
			continue
		var sample: Dictionary = samples[index]
		var p: Vector3 = sample["position"]
		var xz: Vector2 = Vector2(p.x, p.z)
		var cell: Vector2 = (xz - start) / step
		var safe_width: float = float(sample["width"]) * 0.5 + float(definition["runoff_width"]) + step * 1.5
		var radius: int = ceili(safe_width / step)
		var banking_drop: float = absf(sin(deg_to_rad(float(sample["bank"])))) * safe_width
		var floor_y: float = p.y - float(definition["thickness"]) - banking_drop - 0.4
		for z: int in range(maxi(0, floori(cell.y) - radius), mini(nz, ceili(cell.y) + radius + 1)):
			for x: int in range(maxi(0, floori(cell.x) - radius), mini(nx, ceili(cell.x) + radius + 1)):
				if (start + Vector2(x, z) * step).distance_to(xz) < safe_width:
					caps[z * nx + x] = minf(caps[z * nx + x], floor_y)
	return caps

static func _verges(parent: Node3D, samples: Array[Dictionary], definition: Dictionary, minimum_y: float,
		start: Vector2, step: float, nx: int, nz: int, heights: PackedFloat32Array, material: Material) -> void:
	var berm: TrackMeshBuffer = TrackMeshBuffer.new()
	var ground_limit: float = minimum_y + float(definition["terrain_hills"]) * 0.8 + 8.0
	for index: int in range(samples.size() if bool(definition.get("closed", true)) else samples.size() - 1):
		var a: Dictionary = samples[index]
		var b: Dictionary = samples[(index + 1) % samples.size()]
		var ap: Vector3 = a["position"]
		var bp: Vector3 = b["position"]
		if ap.y > ground_limit or bp.y > ground_limit:
			continue
		for side: float in [-1.0, 1.0]:
			var ar: Vector3 = a["right"]
			var br: Vector3 = b["right"]
			var inner_a: Vector3 = ap + ar * side * (float(a["width"]) * 0.5 + float(definition["runoff_width"])) - a["normal"] * 0.12
			var inner_b: Vector3 = bp + br * side * (float(b["width"]) * 0.5 + float(definition["runoff_width"])) - b["normal"] * 0.12
			var outer_a: Vector3 = inner_a + ar * side * 24.0
			var outer_b: Vector3 = inner_b + br * side * 24.0
			outer_a.y = _grid_height(outer_a, start, step, nx, nz, heights) + 0.025
			outer_b.y = _grid_height(outer_b, start, step, nx, nz, heights) + 0.025
			var normal: Vector3 = (outer_a - inner_a).cross(inner_b - inner_a).normalized()
			if normal.y < 0.0:
				normal = -normal
			berm.quad(inner_a, outer_a, outer_b, inner_b, normal)
	berm.attach(parent, "GrassVerges", material, str(definition["terrain_surface"]), false, 320.0)

static func _grid_height(point: Vector3, start: Vector2, step: float, nx: int, nz: int, heights: PackedFloat32Array) -> float:
	var cell: Vector2 = (Vector2(point.x, point.z) - start) / step
	var x: int = clampi(floori(cell.x), 0, nx - 2)
	var z: int = clampi(floori(cell.y), 0, nz - 2)
	var u: float = clampf(cell.x - float(x), 0.0, 1.0)
	var v: float = clampf(cell.y - float(z), 0.0, 1.0)
	return lerpf(lerpf(heights[z * nx + x], heights[z * nx + x + 1], u),
		lerpf(heights[(z + 1) * nx + x], heights[(z + 1) * nx + x + 1], u), v)

static func _spawn_buildings(parent: Node3D, buildings: Array) -> void:
	for entry: Dictionary in buildings:
		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		var height: float = float(entry["height"])
		box.size = Vector3(float(entry["size_x"]), height, float(entry["size_z"]))
		mesh_inst.mesh = box
		mesh_inst.position = entry["center"] + Vector3(0, height * 0.5, 0)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		var tags: Dictionary = entry.get("tags", {})
		if tags.has("building:colour"):
			mat.albedo_color = Color(str(tags["building:colour"]))
		else:
			var shade: float = 0.6 + hash(entry["center"]) % 40 / 100.0
			mat.albedo_color = Color(shade, shade * 0.96, shade * 0.9)
		mat.roughness = 0.85
		mesh_inst.material_override = mat
		mesh_inst.set_meta("surface", "concrete")
		parent.add_child(mesh_inst)

static func _spawn_water(parent: Node3D, water: Array) -> void:
	for entry: Dictionary in water:
		var buffer: TrackMeshBuffer = TrackMeshBuffer.new()
		var polygon: Array[Vector2] = entry["polygon"]
		if polygon.size() < 3:
			continue
		for i: int in range(1, polygon.size() - 1):
			buffer.tri(Vector3(polygon[0].x, 0.05, polygon[0].y),
				Vector3(polygon[i].x, 0.05, polygon[i].y),
				Vector3(polygon[i + 1].x, 0.05, polygon[i + 1].y),
				Vector3.UP)
		var water_mat: StandardMaterial3D = StandardMaterial3D.new()
		water_mat.albedo_color = Color(0.1, 0.22, 0.35, 0.75)
		water_mat.roughness = 0.1
		water_mat.metallic = 0.3
		water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		buffer.attach(parent, "Water", water_mat, "", false, 0.0)

static func _spawn_vegetation(parent: Node3D, vegetation: Array, definition: Dictionary,
		start: Vector2, step: float, nx: int, nz: int, heights: PackedFloat32Array) -> void:
	if vegetation.is_empty():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(definition.get("seed", 8421)) + 777
	var groups: Array = [[], [], [], []]
	for entry: Dictionary in vegetation:
		var polygon: Array[Vector2] = entry["polygon"]
		if polygon.size() < 3:
			continue
		var minp: Vector2 = polygon[0]
		var maxp: Vector2 = polygon[0]
		for pt: Vector2 in polygon:
			minp = Vector2(minf(minp.x, pt.x), minf(minp.y, pt.y))
			maxp = Vector2(maxf(maxp.x, pt.x), maxf(maxp.y, pt.y))
		var area_x: float = maxp.x - minp.x
		var area_z: float = maxp.y - minp.y
		var count: int = clampi(int(area_x * area_z / 40.0), 1, 200)
		for _i: int in range(count):
			var xz: Vector2 = Vector2(rng.randf_range(minp.x, maxp.x), rng.randf_range(minp.y, maxp.y))
			if not OsmTerrain.point_in_polygon(xz, polygon):
				continue
			var y: float = _grid_height(Vector3(xz.x, 0, xz.y), start, step, nx, nz, heights)
			var scale: float = rng.randf_range(0.7, 1.4)
			var basis: Basis = Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(scale, scale * rng.randf_range(0.9, 1.1), scale))
			var pose: Transform3D = Transform3D(basis, Vector3(xz.x, y, xz.y))
			var variant: int = rng.randi_range(0, 3)
			groups[variant].append(pose)
	for variant: int in range(4):
		if groups[variant].is_empty():
			continue
		var transforms: Array[Transform3D] = []
		transforms.assign(groups[variant])
		var mesh: ArrayMesh = ApexBroadleafGeometry.create(71 + variant * 37) if variant < 2 else ApexTreeGeometry.create(13 + variant * 19)
		ApexSceneryInstances.build(parent, "OSM_BroadleafTrees" if variant < 2 else "OSM_ConiferTrees", mesh, null, transforms, 460.0)