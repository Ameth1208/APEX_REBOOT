class_name TrackTerrain
extends RefCounted

static func build(parent: Node3D, samples: Array[Dictionary], definition: Dictionary) -> void:
	if samples.is_empty():
		return
	var bounds: AABB = AABB(samples[0]["position"], Vector3.ZERO)
	for sample: Dictionary in samples:
		bounds = bounds.expand(sample["position"])
	var margin: float = 180.0
	# Keep long imported routes bounded; short circuits retain the original grid.
	var step: float = maxf(24.0, maxf(bounds.size.x, bounds.size.z) / 128.0)
	var start: Vector2 = Vector2(bounds.position.x - margin, bounds.position.z - margin)
	var nx: int = ceili((bounds.size.x + margin * 2.0) / step) + 1
	var nz: int = ceili((bounds.size.z + margin * 2.0) / step) + 1
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(definition.get("seed", 8421))
	noise.frequency = 0.008
	noise.fractal_octaves = 3
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(nx * nz)
	var road_floors: PackedFloat32Array = _road_floor_caps(samples, definition, start, step, nx, nz)
	for iz: int in range(nz):
		for ix: int in range(nx):
			var xz: Vector2 = start + Vector2(ix, iz) * step
			var height: float = bounds.position.y - 2.0 + (noise.get_noise_2d(xz.x, xz.y) + 0.6) * float(definition["terrain_hills"])
			heights[iz * nx + ix] = minf(height, road_floors[iz * nx + ix])
	var buffer: TrackMeshBuffer = TrackMeshBuffer.new()
	for iz: int in range(nz - 1):
		for ix: int in range(nx - 1):
			var a: Vector3 = Vector3(start.x + ix * step, heights[iz * nx + ix], start.y + iz * step)
			var b: Vector3 = Vector3(a.x + step, heights[iz * nx + ix + 1], a.z)
			var c: Vector3 = Vector3(b.x, heights[(iz + 1) * nx + ix + 1], a.z + step)
			var d: Vector3 = Vector3(a.x, heights[(iz + 1) * nx + ix], c.z)
			var normal: Vector3 = (d - a).cross(b - a).normalized()
			buffer.quad(a, b, c, d, normal)
	var material: ShaderMaterial = TrackMaterials.ground(str(definition["terrain_surface"]))
	TrackRoadMesh._apply_custom_texture(material, definition, str(definition["terrain_surface"]))
	buffer.attach(parent, "Terrain", material, str(definition["terrain_surface"]), false, 320.0)
	_verges(parent, samples, definition, bounds.position.y, start, step, nx, nz, heights, material)

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
