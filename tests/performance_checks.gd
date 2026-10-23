extends SceneTree
## Behavioural contracts for indexed route projection and adaptive 3D quality.

const Governor = preload("res://scripts/app/quality_governor.gd")
const Quality = preload("res://scripts/app/render_quality.gd")
const Manager = preload("res://scripts/app/performance_manager.gd")
var failures: Array[String] = []
var projection_queries: int = 0

class EnvironmentStub extends Node3D:
	var applied: String = ""
	func set_quality(value: String) -> void:
		applied = value

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_projection_checks()
	_governor_checks()
	await _presentation_checks()
	print("PERFORMANCE_CHECKS ", JSON.stringify({"status": "PASS" if failures.is_empty() else "FAIL", "projection_queries": projection_queries, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _projection_checks() -> void:
	var open: TrackSampler = _sampler([Vector3.ZERO, Vector3(900, 0, 0), Vector3(1600, 25, -400), Vector3(2300, 25, -600)], false)
	var closed: TrackSampler = _sampler([Vector3.ZERO, Vector3(700, 0, 0), Vector3(700, 15, 600), Vector3(0, 0, 600)], true)
	for sampler: TrackSampler in [open, closed]:
		for distance: float in [0.0, 0.7, 3.95, 80.3, 179.5, sampler.length_m * 0.4, sampler.length_m * 0.73, sampler.length_m - 0.5, sampler.length_m]:
			var sample: Dictionary = sampler.sample_at(distance)
			var point: Vector3 = sample.position + sample.right * 2.7 + sample.normal * 0.35
			_compare(sampler, point, -1.0, "global projection agrees with native 3D geometry")
			_compare(sampler, point, maxf(0.0, distance - 6.0), "nearby hint agrees with global reference")
		var far_point: Vector3 = sampler.sample_at(sampler.length_m * 0.52).position
		_compare(sampler, far_point, 0.0, "stale distant hint falls back to full route")
		_check(sampler._query_index.last_candidate_count >= sampler.samples.size() - 1, "recovery actually examines the full route")
		_compare(sampler, far_point, INF, "nonfinite hint falls back safely")
		_compare(sampler, far_point, NAN, "NaN hint falls back safely")
		_compare(sampler, far_point, sampler.length_m * 30.0, "out-of-range hint remains recoverable")
		var near: Dictionary = sampler.sample_at(sampler.length_m * 0.3)
		sampler.closest_distance(near.position, near.distance)
		_check(sampler._query_index.last_candidate_count < sampler.samples.size() * 0.3, "valid hint only scans a bounded station window")
	_compare(closed, closed.sample_at(closed.length_m - 3.0).position, 0.2, "hint window wraps backwards over finish")
	_compare(closed, closed.sample_at(2.0).position, closed.length_m - 0.2, "hint window wraps forwards over finish")
	_compare(open, Vector3(-10, 0, 0), 0.0, "open projection clamps before start")
	_compare(open, open.samples[-1].position + open.samples[-1].forward * 30.0, open.length_m, "open projection clamps after finish")
	var bridge: TrackSampler = _sampler([Vector3(-300, 0, 0), Vector3(300, 0, 0), Vector3(300, 10, -300), Vector3(0, 10, -300), Vector3(0, 10, 300)], false)
	var lower: float = _reference(bridge, Vector3.ZERO)
	var upper: float = _reference(bridge, Vector3(0, 10, 0))
	_check(absf(upper - lower) > 1000.0, "bridge fixture has distinct path stations at the same horizontal position")
	_compare(bridge, Vector3(0, 0.2, 0), -1.0, "bridge query chooses lower deck in 3D")
	_compare(bridge, Vector3(0, 10.2, 0), -1.0, "bridge query chooses upper deck in 3D")
	_compare(bridge, Vector3(0, 10.2, 0), upper - 4.0, "hint preserves correct bridge deck")
	var tiny: TrackSampler = _sampler([Vector3.ZERO, Vector3(120, 0, 0), Vector3(120, 0, 0.02)], false)
	var finish: float = tiny.closest_distance(Vector3(120, 0, 0.02))
	_check(absf(finish - tiny.length_m) < 0.0001, "a 2cm final segment still reaches the exact finish")
	var repeated: TrackSampler = _sampler([Vector3.ZERO, Vector3(120, 0, 0), Vector3(120, 0, 0), Vector3(240, 0, 0)], false)
	_compare(repeated, Vector3(120, 0.5, 0), 120.0, "zero-length duplicate segments keep projection finite")
	open.rebuild({"closed": false, "points": []})
	_check(open.closest_distance(Vector3(1000, 3, 4), 12.0) == 0.0, "clearing a route discards cached segments")
	var short: TrackSampler = _sampler([Vector3.ZERO, Vector3(60, 0, 0), Vector3(60, 0, 60), Vector3(0, 0, 60)], true)
	_compare(short, Vector3(2, 0.2, 60), 1.0, "short closed routes search the entire loop")

func _sampler(positions: Array[Vector3], closed: bool) -> TrackSampler:
	var points: Array[Dictionary] = []
	for p: Vector3 in positions:
		points.append({"x": p.x, "y": p.y, "z": p.z})
	var sampler: TrackSampler = TrackSampler.new()
	sampler.rebuild(TrackDefinition.clean({"closed": closed, "interpolation": "linear", "sample_spacing": 4.0, "points": points}))
	return sampler

func _reference(sampler: TrackSampler, point: Vector3) -> float:
	# Godot's geometric primitive is an independent oracle, with no hint/index.
	var best_error: float = INF
	var distance: float = 0.0
	for i: int in range(sampler.samples.size() if sampler.closed else sampler.samples.size() - 1):
		var a: Vector3 = sampler.samples[i].position
		var b: Vector3 = sampler.samples[(i + 1) % sampler.samples.size()].position
		var projected: Vector3 = Geometry3D.get_closest_point_to_segment(point, a, b)
		var error: float = point.distance_squared_to(projected)
		if error < best_error:
			best_error = error
			distance = float(sampler.samples[i].distance) + a.distance_to(projected)
	return sampler.normalize_distance(distance)

func _compare(sampler: TrackSampler, point: Vector3, hint: float, label: String) -> void:
	projection_queries += 1
	var actual: float = sampler.closest_distance(point, hint)
	var expected: float = _reference(sampler, point)
	var error: float = absf(actual - expected)
	if sampler.closed:
		error = minf(error, sampler.length_m - error)
	_check(error < 0.005, label + " (error %.6f m)" % error)

func _governor_checks() -> void:
	var governor = Governor.new()
	_feed(governor, 1.8, 1.0 / 30.0, 30.0)
	_check(is_equal_approx(governor.scale, 1.0), "warm-up does not lower quality")
	var before: float = governor.average_frame_ms
	var pause_changed: bool = false
	for i: int in range(100):
		pause_changed = governor.sample(0.1, 80.0, false) or pause_changed
	_check(not pause_changed, "paused samples do not trigger adaptation")
	_check(governor.average_frame_ms == before and governor.scale == 1.0, "pauses do not pollute timing averages")
	_check(not governor.sample(0.0) and not governor.sample(-0.1) and not governor.sample(NAN), "invalid timing is ignored")
	governor.reset()
	_feed(governor, 3.0, 1.0 / 60.0, 8.0)
	governor.sample(0.25, 8.0)
	_feed(governor, 4.0, 1.0 / 60.0, 8.0)
	_check(is_equal_approx(governor.scale, 1.0), "a single 250ms hitch does not lower sustained render quality")
	governor.scale = 1.0
	governor.reset()
	var first_change: float = -1.0
	var last_change: float = -100.0
	var bounded: bool = true
	for i: int in range(500):
		if governor.sample(0.04, 30.0):
			var time: float = i * 0.04
			if first_change < 0.0:
				first_change = time
			_check(time - last_change >= 3.95, "quality changes obey a cooldown")
			last_change = time
		bounded = bounded and governor.scale >= Governor.MIN_SCALE and governor.scale <= 1.0
	_check(bounded, "adaptive scale stays within supported bounds")
	_check(first_change > 3.0 and first_change < 6.0, "sustained load lowers quality after warm-up and hysteresis")
	_check(is_equal_approx(governor.scale, Governor.MIN_SCALE), "long overload reaches the supported minimum")
	_feed(governor, 6.0, 1.0 / 60.0, 6.0)
	_check(is_equal_approx(governor.scale, Governor.MIN_SCALE), "brief recovery does not immediately increase quality")
	_feed(governor, 10.0, 1.0 / 60.0, 6.0)
	_check(governor.scale > Governor.MIN_SCALE and governor.scale <= Governor.MIN_SCALE + 0.051, "sustained headroom restores one cautious quality step")
	_feed(governor, 100.0, 1.0 / 60.0, 6.0)
	_check(is_equal_approx(governor.scale, 1.0), "recovery stops at native resolution")

func _feed(governor: RefCounted, seconds: float, delta: float, gpu: float) -> void:
	for i: int in range(ceili(seconds / delta)):
		governor.sample(delta, gpu)

func _presentation_checks() -> void:
	var window_size: Vector2i = root.size
	var ui_rect: Rect2 = root.get_visible_rect()
	var canvas_scale: Vector2i = root.content_scale_size
	var panel: Control = Control.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var panel_rect: Rect2 = panel.get_global_rect()
	for quality: String in Quality.NAMES:
		Quality.apply_viewport(root, quality, 0.72)
		await process_frame
		_check(root.size == window_size and root.get_visible_rect() == ui_rect and root.content_scale_size == canvas_scale, "3D quality preserves window and UI resolution")
		_check(panel.get_global_rect() == panel_rect, "3D quality preserves control geometry")
		_check(Engine.physics_ticks_per_second == 120 and ProjectSettings.get_setting("physics/common/physics_ticks_per_second") == 120, "quality never reduces simulation frequency")
		if RenderingServer.get_current_rendering_method() == "gl_compatibility":
			_check(root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "Compatibility quality does not request unsupported screen-space AA")
	Quality.apply_viewport(root, "Automático", 0.1)
	_check(is_equal_approx(root.scaling_3d_scale, 0.70), "automatic resolution clamps low values")
	Quality.apply_viewport(root, "Automático", 1.5)
	_check(is_equal_approx(root.scaling_3d_scale, 1.0), "automatic resolution clamps high values")
	_check(Quality.tier("unknown", 0.7) == "Equilibrado", "unknown quality has a safe fallback")
	var environment: EnvironmentStub = EnvironmentStub.new()
	var scenery: Node3D = Node3D.new()
	root.add_child(environment)
	root.add_child(scenery)
	var managed: MeshInstance3D = MeshInstance3D.new()
	managed.set_meta("quality_visibility_range", 1000.0)
	scenery.add_child(managed)
	var unmanaged: MeshInstance3D = MeshInstance3D.new()
	unmanaged.visibility_range_end = 700.0
	scenery.add_child(unmanaged)
	var manager = Manager.new()
	manager.configure(root, environment, "Rendimiento")
	manager.bind_scenery(scenery)
	manager.bind_scenery(scenery)
	_check(environment.applied == "Rendimiento", "manager applies requested environment quality")
	_check(is_equal_approx(managed.visibility_range_end, 700.0), "repeated quality changes use the original distance without compounding")
	_check(is_equal_approx(unmanaged.visibility_range_end, 700.0), "quality leaves untagged track geometry distances alone")
	var report: Dictionary = manager.report()
	_check(report.mean_fps == null and report.sampled_gameplay_frames == 0, "unmeasured gameplay is reported as unknown rather than a claimed FPS")
	_check(report.physics_ticks_per_second == 120, "diagnostics report the unchanged physics rate")
	panel.queue_free()
	environment.queue_free()
	scenery.queue_free()
	await process_frame

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error(label)
