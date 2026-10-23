class_name ApexPerformanceManager
extends RefCounted
## Opt-in diagnostics retain only recent local frame measurements and hardware.

const Governor = preload("res://scripts/app/quality_governor.gd")
const Quality = preload("res://scripts/app/render_quality.gd")
var governor = Governor.new()
var quality: String = "Automático"
var _viewport: Viewport
var _environment: Node3D
var _scenery: Node3D
var _frames: PackedFloat64Array = PackedFloat64Array()
var _cursor: int = 0
var _count: int = 0
var _gpu_ms: float = 0.0
var _render_cpu_ms: float = 0.0

func configure(viewport: Viewport, environment: Node3D, requested: String) -> void:
	_viewport = viewport
	_environment = environment
	quality = requested if requested in Quality.NAMES else "Equilibrado"
	governor.scale = 1.0
	governor.reset()
	_frames.resize(1200)
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	_apply()

func bind_scenery(scenery: Node3D) -> void:
	_scenery = scenery
	governor.reset()
	_count = 0
	_cursor = 0
	_apply()

func sample(delta: float, driving: bool) -> void:
	if _viewport == null or not driving or DisplayServer.get_name() == "headless" or delta <= 0.0:
		return
	var rid: RID = _viewport.get_viewport_rid()
	_gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(rid)
	_render_cpu_ms = RenderingServer.viewport_get_measured_render_time_cpu(rid)
	_frames[_cursor] = delta * 1000.0
	_cursor = (_cursor + 1) % _frames.size()
	_count = mini(_count + 1, _frames.size())
	if quality == "Automático" and governor.sample(delta, _gpu_ms):
		_apply()

func _apply() -> void:
	if _viewport == null:
		return
	Quality.apply_viewport(_viewport, quality, governor.scale)
	var resolved: String = Quality.tier(quality, governor.scale)
	if is_instance_valid(_environment):
		_environment.set_quality(resolved)
	if is_instance_valid(_scenery):
		Quality.apply_scenery(_scenery, resolved)

func report() -> Dictionary:
	var sorted: Array[float] = []
	var total: float = 0.0
	for i: int in range(_count):
		sorted.append(_frames[i])
		total += _frames[i]
	sorted.sort()
	return {"version": ProjectSettings.get_setting("application/config/version"),
		"engine": Engine.get_version_info().string, "operating_system": OS.get_name(),
		"cpu": OS.get_processor_name(), "graphics_adapter": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "quality": quality,
		"window_px": [int(_viewport.get_visible_rect().size.x), int(_viewport.get_visible_rect().size.y)],
		"render_scale_3d": _viewport.scaling_3d_scale, "physics_ticks_per_second": Engine.physics_ticks_per_second,
		"sampled_gameplay_frames": _count, "mean_fps": 1000.0 * _count / total if total > 0.0 else null,
		"frame_p95_ms": sorted[mini(_count - 1, floori(_count * 0.95))] if _count > 0 else null,
		"last_gpu_ms": _gpu_ms if _gpu_ms > 0.0 else null, "last_render_cpu_ms": _render_cpu_ms,
		"last_physics_process_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"rendered_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"scope": "Últimos 1200 fotogramas en pista. Medición local; no se envía información por red. GPU null significa temporización no disponible."}

func save_report() -> String:
	var text: String = JSON.stringify(report(), "  ")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), "APEX_rendimiento.json", "application/json")
		return "Descarga del informe de rendimiento solicitada."
	var path: String = "user://diagnostics/APEX_rendimiento.json"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "No se pudo guardar el informe de rendimiento."
	file.store_string(text + "\n")
	file.close()
	print("PERFORMANCE_REPORT ", ProjectSettings.globalize_path(path))
	return "Informe guardado en diagnostics/APEX_rendimiento.json"
