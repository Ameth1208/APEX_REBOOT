extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_mesh_winding_checks()
	var mountain: Dictionary = {}
	for filename: String in ["costa_clara", "sierra_alta", "tecnica_laguna"]:
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tracks/" + filename + ".json"))
		_check(source is Dictionary, filename + " parses")
		if not source is Dictionary:
			continue
		var track: CircuitTrack = CircuitTrack.new()
		root.add_child(track)
		var started: int = Time.get_ticks_msec()
		track.build(source)
		var elapsed: int = Time.get_ticks_msec() - started
		_check(track.length_m > 1500.0, filename + " substantial circuit length")
		_check(track.samples.size() > 300, filename + " sufficiently sampled")
		var first: Dictionary = track.sample_at(0.0)
		var last: Dictionary = track.sample_at(track.length_m)
		_check(first["position"].distance_to(last["position"]) < 0.001, filename + " position closes")
		_check(first["forward"].dot(last["forward"]) > 0.999, filename + " tangent closes")
		_check(track.sample_at(-4.0)["position"].distance_to(track.sample_at(track.length_m - 4.0)["position"]) < 0.001, "negative distances wrap")
		for step: int in range(64):
			var distance: float = float(step) / 64.0 * track.length_m
			var sample: Dictionary = track.sample_at(distance)
			var position: Vector3 = sample["position"]
			var normal: Vector3 = sample["normal"]
			var forward: Vector3 = sample["forward"]
			_check(position.is_finite() and normal.is_finite(), "finite 3D coordinates")
			_check(absf(normal.length() - 1.0) < 0.001, "unit normal")
			_check(absf(normal.dot(forward)) < 0.001, "normal orthogonal to tangent")
			var nearest: float = track.closest_distance(position + normal * 1.0, distance)
			var delta: float = absf(fposmod(nearest - distance + track.length_m * 0.5, track.length_m) - track.length_m * 0.5)
			_check(delta < 2.0, "3D nearest projection preserves progress")
		var range_y: Vector2 = track.get_elevation_range()
		var road_bounds: AABB = _mesh_group_bounds(track, "Road_asphalt")
		_check(road_bounds.position.y < range_y.x - 0.25, "all road chunks include underside below driving surface")
		var collider: StaticBody3D = track.get_node("Road_asphaltCollision") as StaticBody3D
		_check(collider.get_meta("surface") == "asphalt" and collider.collision_layer == 1, "surface collision contract")
		var spawn: Transform3D = track.get_spawn_transform(0.0)
		_check((-spawn.basis.z).dot(first["forward"]) > 0.999, "spawn forward is -Z")
		_check(absf(spawn.origin.distance_to(first["position"]) - 1.2) < 0.001, "spawn clearance")
		_check_crossings(track)
		print("TRACK ", filename, ": ", snappedf(track.length_m, 0.1), " m; elevation ", range_y, "; samples ", track.samples.size(), "; build ", elapsed, " ms")
		if filename == "sierra_alta":
			mountain = source
			_check(range_y.y - range_y.x > 60.0, "mountain retains physical elevation")
		track.queue_free()
		await process_frame
	await _editor_checks(mountain)
	print("TRACK_CHECKS ", "PASS" if _failures == 0 else "FAIL: " + str(_failures))
	quit(0 if _failures == 0 else 1)

func _editor_checks(source: Dictionary) -> void:
	var editor: TrackEditor = TrackEditor.new()
	root.add_child(editor)
	editor.open(source)
	await process_frame

	var original_height: float = float(source["points"][0]["y"])
	editor._field_changed("y", 88.0)
	_check(float(editor._definition["points"][0]["y"]) == 88.0, "editor updates elevation")
	_check(float(source["points"][0]["y"]) == original_height, "editor isolates source")
	editor._undo()
	_check(float(editor._definition["points"][0]["y"]) == original_height, "editor undo")
	editor._redo()
	_check(float(editor._definition["points"][0]["y"]) == 88.0, "editor redo")
	var count: int = editor._definition["points"].size()
	editor._add_point(Vector2(55.0, 66.0), 0)
	_check(editor._definition["points"].size() == count + 1, "editor adds point")
	editor._delete_point(1)
	_check(editor._definition["points"].size() == count, "editor deletes point")
	var captured: Dictionary = {}
	editor.applied.connect(func(definition: Dictionary) -> void: captured.merge(definition))
	editor._apply()
	_check(captured.has("points") and not editor.visible, "editor applies through signal")
	editor.queue_free()
	await process_frame

func _check_crossings(track: CircuitTrack) -> void:
	var samples: Array[Dictionary] = track.samples
	var stride: int = 4
	for i: int in range(0, samples.size() - stride, stride):
		var a: Vector3 = samples[i]["position"]
		var b: Vector3 = samples[i + stride]["position"]
		for j: int in range(i + stride * 2, samples.size() - stride, stride):
			var c: Vector3 = samples[j]["position"]
			var d: Vector3 = samples[j + stride]["position"]
			var crossing: Variant = Geometry2D.segment_intersects_segment(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), Vector2(d.x, d.z))
			if crossing == null:
				continue
			var p: Vector2 = crossing
			var t1: float = Vector2(a.x, a.z).distance_to(p) / maxf(0.001, Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)))
			var t2: float = Vector2(c.x, c.z).distance_to(p) / maxf(0.001, Vector2(c.x, c.z).distance_to(Vector2(d.x, d.z)))
			var clearance: float = absf(lerpf(a.y, b.y, t1) - lerpf(c.y, d.y, t2))
			_check(clearance > float(track.definition["thickness"]) + 6.0, "crossing roads have safe vertical clearance")
			for branch: Vector3 in [a.lerp(b, t1), c.lerp(d, t2)]:
				var located: Dictionary = track.sample_at(track.closest_distance(branch))
				_check(located["position"].distance_to(branch) < 1.0, "3D projection selects the correct crossing level without a hint")

func _mesh_winding_checks() -> void:
	var buffer: TrackMeshBuffer = TrackMeshBuffer.new()
	buffer.quad(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, -1), Vector3(0, 0, -1), Vector3.UP)
	buffer.quad(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1), Vector3.UP)
	for i: int in range(0, buffer.indices.size(), 3):
		var a: Vector3 = buffer.vertices[buffer.indices[i]]
		var b: Vector3 = buffer.vertices[buffer.indices[i + 1]]
		var c: Vector3 = buffer.vertices[buffer.indices[i + 2]]
		_check((b - a).cross(c - a).dot(Vector3.UP) < 0.0, "clockwise winding matches Godot's visible upward face regardless of caller order")

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)

func _mesh_group_bounds(parent: Node, group: String) -> AABB:
	var bounds: AABB = AABB()
	var first: bool = true
	for node: Node in parent.find_children("*", "MeshInstance3D", true, false):
		if node.get_meta("track_mesh_group", "") == group:
			var part: AABB = node.transform * node.mesh.get_aabb()
			bounds = part if first else bounds.merge(part)
			first = false
	return bounds
