extends SceneTree
## Check the imported vertices, physical hubs and visible rolling of all four models.

const Layout = preload("res://scripts/physics/wheel_layout.gd")
var _failures: Array[String] = []
var _checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for id: String in ["senna_formula_1991", "porsche_992_gt3_rs_2024", "ferrari_312t_1976", "yamaha_yzf_2021", "volkswagen_golf_gti_2025", "cupra_formentor_2024", "kia_picanto_2024", "hyundai_elantra_2021"]:
		var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles/" + id + ".json"))
		var visual: VehicleVisual = VehicleVisual.new()
		root.add_child(visual)
		visual.setup(profile)
		if id == "porsche_992_gt3_rs_2024":
			_check_body_batching(visual, profile)
		var motorcycle: bool = profile.kind == "motorcycle"
		var offsets: Array[Vector3] = Layout.offsets(profile, motorcycle)
		_check(visual._wheels.size() == offsets.size(), id + " all independent wheels rigged")
		var max_runout: float = 0.0
		for wheel: Dictionary in visual._wheels:
			var pivot: Node3D = wheel.pivot
			var expected: Vector3 = offsets[int(wheel.index)]
			_check(absf(wheel.imported_position.z - expected.z) < 0.002, id + " shell axle stays over physical hub instead of snapping wheels away from arches")
			_check(Vector2(pivot.position.x, pivot.position.z).distance_to(Vector2(expected.x, expected.z)) < 0.002, id + " hub matches its physical contact")
			var vertices: PackedVector3Array = PackedVector3Array()
			for child: Node3D in pivot.get_children():
				_vertices(child, Transform3D.IDENTITY, vertices)
			_check(not vertices.is_empty(), id + " wheel contains real imported vertices")
			var lows: PackedFloat32Array = PackedFloat32Array()
			for step: int in 16:
				var rotated: Basis = Basis(Vector3.RIGHT, TAU * float(step) / 16.0)
				var low: float = INF
				for vertex: Vector3 in vertices:
					low = minf(low, (rotated * vertex).y)
				lows.append(low)
			lows.sort()
			var runout: float = lows[-1] - lows[0]
			max_runout = maxf(max_runout, runout)
			_check(runout < 0.018, id + " tyre does not bounce elliptically while rolling: " + str(runout))
		visual.animate(9.0, 0.0, 0.0, 0.03)
		_check(float(visual._wheels[0].spin) < 0.0, id + " forward motion rolls forward")
		visual.animate(-9.0, 0.0, 0.0, 0.03)
		_check(absf(float(visual._wheels[0].spin)) < 0.0001, id + " reverse motion unwinds the same distance")
		var contacts: Array[Dictionary] = []
		for i: int in offsets.size():
			contacts.append({"index": i, "compression": Layout.sag(profile, motorcycle), "locked": i == offsets.size() - 1})
		visual.sync_suspension(contacts, 0.1)
		var last_spin: float = visual._wheels[-1].spin
		visual.animate(15.0, 0.25, 0.0, 0.1)
		_check(visual._wheels[-1].spin == last_spin, id + " a locked tyre stops rotating")
		_check(absf(float(visual._wheels[0].spin)) > 0.01, id + " unlocked wheels keep rotating")
		if not motorcycle:
			var left: Basis = visual._wheels[0].pivot.basis
			var right: Basis = visual._wheels[1].pivot.basis
			_check(absf(atan2(right.x.z, right.x.x)) > absf(atan2(left.x.z, left.x.x)), id + " inside front wheel has a tighter steering angle")
		visual.sync_suspension([], 1.0)
		for wheel: Dictionary in visual._wheels:
			_check(absf(wheel.pivot.position.y - (wheel.base_position.y - Layout.sag(profile, motorcycle))) < 0.001, id + " unloaded hub reaches physical full extension")
		print("WHEEL_RIG ", id, " hubs=", offsets.size(), " radial_runout_m=", max_runout)
		visual.queue_free()
		await process_frame
	print("WHEEL_RIG_CHECKS ", "PASS" if _failures.is_empty() else "FAIL", " ", _checks, " ", _failures)
	quit(0 if _failures.is_empty() else 1)

func _check_body_batching(visual: VehicleVisual, profile: Dictionary) -> void:
	var original_profile: Dictionary = profile.duplicate(true)
	original_profile["batch_static_body"] = false
	var original := VehicleVisual.new()
	root.add_child(original)
	original.setup(original_profile)
	var before: AABB = original._bounds(original._lean, Transform3D.IDENTITY)
	var after: AABB = visual._bounds(visual._lean, Transform3D.IDENTITY)
	_check(before.position.distance_to(after.position) < 0.001 and before.size.distance_to(after.size) < 0.001, "batching preserves body geometry bounds and position")
	_check(visual._painter.surface_count() > 0 and original._painter.surface_count() > 0, "batched body still exposes real paint materials")
	var first_batch: MeshInstance3D
	for child: Node in visual._normalized.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("BodyBatch"):
			first_batch = child
			break
	_check(first_batch != null, "Porsche actually batches compatible body parts")
	var sibling := VehicleVisual.new()
	root.add_child(sibling)
	sibling.setup(profile)
	var shares_geometry: bool = false
	for child: Node in sibling._normalized.get_children():
		if child is MeshInstance3D and first_batch != null and child.mesh == first_batch.mesh:
			shares_geometry = true
	_check(shares_geometry, "rivals reuse prepared body geometry instead of regenerating LODs")
	visual.set_paint(Color.RED)
	_check(visual._painter._surfaces[0].mesh.get_surface_override_material(visual._painter._surfaces[0].surface) is ShaderMaterial, "painting still updates batched body immediately")
	_check(sibling._painter._surfaces[0].mesh.get_surface_override_material(sibling._painter._surfaces[0].surface) == sibling._painter._surfaces[0].override, "one vehicle's paint never changes a rival's shared geometry")
	visual.set_paint(Color.WHITE, true)
	_check(preload("res://scripts/vehicles/vehicle_model_loader.gd")._resources.size() <= 2, "model cache is bounded, not the whole catalogue")
	original.free()
	sibling.free()

func _vertices(node: Node3D, parent: Transform3D, target: PackedVector3Array) -> void:
	var transform_here: Transform3D = parent * node.transform
	if node is MeshInstance3D and node.mesh:
		for surface: int in node.mesh.get_surface_count():
			var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				target.append(transform_here * vertex)
	for child: Node in node.get_children():
		if child is Node3D:
			_vertices(child, transform_here, target)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		push_error(description)
