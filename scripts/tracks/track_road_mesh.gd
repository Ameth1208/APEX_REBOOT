class_name TrackRoadMesh
extends RefCounted

const Curbs = preload("res://scripts/tracks/track_curbs.gd")
const CHUNK_M: float = 320.0

static func build(parent: Node3D, samples: Array[Dictionary], definition: Dictionary) -> void:
	var road: Dictionary = {}
	var underside: TrackMeshBuffer = TrackMeshBuffer.new()
	var runoff: TrackMeshBuffer = TrackMeshBuffer.new()
	var lines: TrackMeshBuffer = TrackMeshBuffer.new()
	var thickness: float = float(definition["thickness"])
	var runoff_width: float = float(definition["runoff_width"])
	var closed: bool = bool(definition.get("closed", true))
	for index: int in range(samples.size() if closed else samples.size() - 1):
		var a: Dictionary = samples[index]
		var b: Dictionary = samples[(index + 1) % samples.size()]
		var surface: String = str(a["surface"])
		if not road.has(surface):
			road[surface] = TrackMeshBuffer.new()
		var buffer: TrackMeshBuffer = road[surface]
		var an: Vector3 = a["normal"]
		var bn: Vector3 = b["normal"]
		var normal: Vector3 = (an + bn).normalized()
		var al: Vector3 = _edge(a, -1.0)
		var ar: Vector3 = _edge(a, 1.0)
		var bl: Vector3 = _edge(b, -1.0)
		var br: Vector3 = _edge(b, 1.0)
		var end_distance: float = float(a["distance"]) + Vector3(a["position"]).distance_to(b["position"])
		buffer.quad(al, ar, br, bl, normal, PackedVector2Array([
			Vector2(-float(a["width"]) * 0.5, a["distance"]), Vector2(float(a["width"]) * 0.5, a["distance"]),
			Vector2(float(b["width"]) * 0.5, end_distance), Vector2(-float(b["width"]) * 0.5, end_distance)]))
		buffer.quad(al - an * thickness, bl - bn * thickness, br - bn * thickness, ar - an * thickness, -normal)
		buffer.quad(al, bl, bl - bn * thickness, al - an * thickness, -a["right"])
		buffer.quad(ar, ar - an * thickness, br - bn * thickness, br, a["right"])
		var ao: Vector3 = a["right"] * 0.02
		var bo: Vector3 = b["right"] * 0.02
		underside.quad(al - an * 0.015 - ao, bl - bn * 0.015 - bo, bl - bn * thickness - bo, al - an * thickness - ao, -a["right"])
		underside.quad(ar - an * 0.015 + ao, ar - an * thickness + ao, br - bn * thickness + bo, br - bn * 0.015 + bo, a["right"])
		underside.quad(al - an * (thickness + 0.015), bl - bn * (thickness + 0.015), br - bn * (thickness + 0.015), ar - an * (thickness + 0.015), -normal)
		for side: float in [-1.0, 1.0]:
			var start: Vector3 = _edge(a, side)
			var end: Vector3 = _edge(b, side)
			var aa: Vector3 = a["right"] * side
			var ba: Vector3 = b["right"] * side
			runoff.quad(start - an * 0.06, start + aa * runoff_width - an * 0.12,
				end + ba * runoff_width - bn * 0.12, end - bn * 0.06, normal)
			lines.quad(start - aa * 0.28 + an * 0.025, start - aa * 0.10 + an * 0.025,
				end - ba * 0.10 + bn * 0.025, end - ba * 0.28 + bn * 0.025, normal)
	if not closed and samples.size() > 1:
		for index: int in [0, samples.size() - 1]:
			var sample: Dictionary = samples[index]
			var a: Vector3 = _edge(sample, -1.0)
			var b: Vector3 = _edge(sample, 1.0)
			var down: Vector3 = -Vector3(sample["normal"]) * thickness
			var normal: Vector3 = Vector3(sample["forward"]) * (-1.0 if index == 0 else 1.0)
			var cap: TrackMeshBuffer = road[str(samples[0 if index == 0 else index - 1]["surface"])]
			cap.quad(a, b, b + down, a + down, normal)
	for surface: String in road:
		var buffer: TrackMeshBuffer = road[surface]
		var material: ShaderMaterial = TrackMaterials.ground(surface, true)
		_apply_custom_texture(material, definition, surface)
		buffer.attach(parent, "Road_" + surface, material, surface, true, CHUNK_M)
	underside.attach(parent, "RoadStructure", TrackMaterials.flat(Color(0.30, 0.32, 0.33)), "", false, CHUNK_M)
	var runoff_material: ShaderMaterial = TrackMaterials.ground(str(definition["runoff_surface"]))
	_apply_custom_texture(runoff_material, definition, str(definition["runoff_surface"]))
	runoff.attach(parent, "Runoff", runoff_material, str(definition["runoff_surface"]), false, CHUNK_M)
	if not closed:
		_finish_apron(parent, samples[-1], runoff_material, str(definition["runoff_surface"]))
	if not definition.has("geo") or str(definition.get("construction_mode", "faithful")) != "faithful":
		Curbs.build(parent, samples, closed, CHUNK_M)
	lines.attach(parent, "WhiteEdgeLines", TrackMaterials.flat(Color("d0d1c9")), "", false, CHUNK_M)

static func _finish_apron(parent: Node3D, sample: Dictionary, material: Material, surface: String) -> void:
	# A braking apron is scenery/collision only; it never extends the timed route.
	var apron: TrackMeshBuffer = TrackMeshBuffer.new()
	var a: Vector3 = _edge(sample, -1.0) - Vector3(sample["normal"]) * 0.04
	var b: Vector3 = _edge(sample, 1.0) - Vector3(sample["normal"]) * 0.04
	var forward: Vector3 = Vector3(sample["forward"]) * 14.0
	apron.quad(a, b, b + forward, a + forward, sample["normal"])
	apron.attach(parent, "FinishBrakingApron", material, surface)

static func _edge(sample: Dictionary, side: float) -> Vector3:
	return sample["position"] + sample["right"] * float(sample["width"]) * 0.5 * side

static func _apply_custom_texture(material: ShaderMaterial, definition: Dictionary, surface: String) -> void:
	var textures: Dictionary = definition.get("surface_textures", {})
	var path: String = str(textures.get(surface, ""))
	if path.is_empty():
		return
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image: Image = Image.load_from_file(path)
		if image != null and not image.is_empty():
			image.generate_mipmaps()
			texture = ImageTexture.create_from_image(image)
	if texture != null:
		material.set_shader_parameter("custom_texture", texture)
		material.set_shader_parameter("use_custom_texture", true)
