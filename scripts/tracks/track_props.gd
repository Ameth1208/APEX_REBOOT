class_name TrackProps
extends RefCounted

const Obstacles = preload("res://scripts/physics/static_obstacle_collision.gd")

static func build(parent: Node3D, sampler: TrackSampler, definition: Dictionary) -> void:
	if sampler.samples.is_empty():
		return
	# Imported roads need mapped structures, not decorations inferred from altitude.
	if definition.has("geo") and str(definition.get("construction_mode", "faithful")) == "faithful":
		return
	if bool(definition.get("barriers", true)):
		_barriers(parent, sampler, definition)
	_start_grid(parent, sampler)
	if not sampler.closed:
		_gate(parent, sampler, sampler.length_m, true)
	_supports(parent, sampler, definition)

static func _barriers(parent: Node3D, sampler: TrackSampler, definition: Dictionary) -> void:
	var rails: TrackMeshBuffer = TrackMeshBuffer.new()
	var solid: StaticBody3D = Obstacles.group(parent, "GuardrailsCollision")
	var posts: Array[Transform3D] = []
	var spacing: float = 8.0
	var count: int = ceili(sampler.length_m / spacing)
	for index: int in range(count):
		var a: Dictionary = sampler.sample_at(float(index) * spacing)
		var b: Dictionary = sampler.sample_at(minf(float(index + 1) * spacing, sampler.length_m))
		for side: float in [-1.0, 1.0]:
			var an: Vector3 = a["normal"]
			var bn: Vector3 = b["normal"]
			var offset: float = float(a["width"]) * 0.5 + float(definition["runoff_width"]) + 0.7
			var next_offset: float = float(b["width"]) * 0.5 + float(definition["runoff_width"]) + 0.7
			var start: Vector3 = a["position"] + a["right"] * side * offset
			var end: Vector3 = b["position"] + b["right"] * side * next_offset
			for level: float in [0.28, 0.77]:
				rails.quad(start + an * level, start + an * (level + 0.27), end + bn * (level + 0.27), end + bn * level, a["right"] * -side)
			var forward: Vector3 = (end - start).normalized()
			var right: Vector3 = forward.cross((an + bn).normalized()).normalized()
			var up: Vector3 = right.cross(forward).normalized()
			Obstacles.box(solid, Transform3D(Basis(right, up, -forward), (start + end) * 0.5 + up * 0.575), Vector3(0.20, 1.15, start.distance_to(end) + 0.12))
			var basis: Basis = Basis(a["right"], an, -a["forward"])
			posts.append(Transform3D(basis, start + an * 0.575))
	rails.attach(parent, "Guardrails", TrackMaterials.flat(Color(0.48, 0.53, 0.57), 0.35, 0.72), "", false, 320.0)
	var post_mesh: BoxMesh = BoxMesh.new()
	post_mesh.size = Vector3(0.16, 1.15, 0.16)
	_multimesh(parent, "GuardrailPosts", post_mesh, TrackMaterials.flat(Color(0.23, 0.26, 0.28), 0.6, 0.5), posts)

static func _start_grid(parent: Node3D, sampler: TrackSampler) -> void:
	_gate(parent, sampler, 0.0, false)
	for index: int in range(8):
		var distance: float = -12.0 - index * 11.0 if sampler.closed else 5.5 + float(index / 2) * 9.0
		var s: Dictionary = sampler.sample_at(distance)
		var lateral: float = minf(1.8, float(s["width"]) * 0.25) * (-1.0 if index % 2 == 0 else 1.0)
		var transform: Transform3D = Transform3D(Basis(s["right"], s["normal"], -s["forward"]), s["position"] + s["right"] * lateral + s["normal"] * 0.04)
		_box(parent, "GridSlot", Vector3(2.2, 0.025, 0.18), transform, Color(0.88, 0.88, 0.82))

static func _gate(parent: Node3D, sampler: TrackSampler, distance: float, is_finish: bool) -> void:
	var white: TrackMeshBuffer = TrackMeshBuffer.new()
	var black: TrackMeshBuffer = TrackMeshBuffer.new()
	var sample: Dictionary = sampler.sample_at(distance)
	var half_width: float = float(sample["width"]) * 0.5
	var tile_size: float = 0.8
	var columns: int = ceili(half_width * 2.0 / tile_size)
	for row: int in range(2):
		for column: int in range(columns):
			var lateral: float = -half_width + float(column) * tile_size
			var a: Vector3 = sample["position"] + sample["right"] * lateral + sample["forward"] * (float(row) - (2.0 if is_finish else 0.0)) * tile_size + sample["normal"] * 0.035
			var right: Vector3 = sample["right"] * minf(tile_size, half_width - lateral)
			var forward: Vector3 = sample["forward"] * tile_size
			var buffer: TrackMeshBuffer = white if (row + column) % 2 == 0 else black
			buffer.quad(a, a + right, a + right + forward, a + forward, sample["normal"])
	white.attach(parent, "FinishWhite" if is_finish else "StartWhite", TrackMaterials.flat(Color(0.93, 0.93, 0.88)))
	black.attach(parent, "FinishBlack" if is_finish else "StartBlack", TrackMaterials.flat(Color(0.035, 0.04, 0.045)))
	var start_basis: Basis = Basis(sample["right"], sample["normal"], -sample["forward"])
	for side: float in [-1.0, 1.0]:
		var position: Vector3 = sample["position"] + sample["right"] * side * (half_width + 6.0) + sample["normal"] * 3.8
		_box(parent, "StartPillar", Vector3(0.6, 7.6, 0.65), Transform3D(start_basis, position), Color(0.11, 0.14, 0.16), true)
	_box(parent, "StartGantry", Vector3(half_width * 2.0 + 12.6, 1.5, 0.8), Transform3D(start_basis, sample["position"] + sample["normal"] * 7.4), Color(0.045, 0.09, 0.10), true)
	var label: Label3D = Label3D.new()
	label.text = "APEX  /  META" if is_finish else "APEX  /  SALIDA"
	label.font_size = 100
	label.pixel_size = 0.015
	label.modulate = Color("f14b55")
	label.transform = Transform3D(start_basis, sample["position"] + sample["normal"] * 7.4 - sample["forward"] * 0.43)
	parent.add_child(label)

static func _supports(parent: Node3D, sampler: TrackSampler, definition: Dictionary) -> void:
	var transforms: Array[Transform3D] = []
	var minimum: float = INF
	for sample: Dictionary in sampler.samples:
		var point: Vector3 = sample["position"]
		minimum = minf(minimum, point.y)
	for index: int in range(ceili(sampler.length_m / 65.0)):
		var sample: Dictionary = sampler.sample_at(index * 65.0)
		var point: Vector3 = sample["position"]
		var floor_y: float = minimum - 12.0
		var height: float = point.y - floor_y - float(definition["thickness"])
		if height < 20.0:
			continue
		var crosses_lower_road: bool = false
		for below: Dictionary in sampler.samples:
			var below_point: Vector3 = below["position"]
			if below_point.y < point.y - 7.0 and Vector2(below_point.x, below_point.z).distance_to(Vector2(point.x, point.z)) < float(below["width"]) * 0.5 + 8.0:
				crosses_lower_road = true
				break
		if crosses_lower_road:
			continue
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(1.0, height, 1.0))
		transforms.append(Transform3D(basis, Vector3(point.x, floor_y + height * 0.5, point.z)))
	var column: CylinderMesh = CylinderMesh.new()
	column.top_radius = 1.25
	column.bottom_radius = 1.65
	column.height = 1.0
	column.radial_segments = 8
	_multimesh(parent, "ViaductPillars", column, TrackMaterials.flat(Color(0.46, 0.47, 0.45)), transforms)
	var solid: StaticBody3D = Obstacles.group(parent, "ViaductPillarCollisions")
	for pose: Transform3D in transforms:
		Obstacles.cylinder(solid, pose, 1.65, 1.0)

static func _box(parent: Node3D, title: String, size: Vector3, transform: Transform3D, color: Color, solid: bool = false) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = title
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = TrackMaterials.flat(color)
	instance.transform = transform
	parent.add_child(instance)
	if solid:
		Obstacles.box(Obstacles.group(parent, "TimingGateCollisions"), transform, size)

static func _multimesh(parent: Node3D, title: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	# Los props lejanos no aportan detalle jugable; mantenerlos fuera del presupuesto GPU.
	ApexSceneryInstances.build(parent, title, mesh, material, transforms, 720.0, false)
