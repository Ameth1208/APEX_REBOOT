extends SceneTree
## Native audio integration: capture the mixed bus before/after a real wall hit.

const Vehicle = preload("res://scripts/vehicles/vehicle_body.gd")
const EngineAudio = preload("res://scripts/audio/engine_audio.gd")
var _capture: AudioEffectCapture
var _phase: String = "idle"
var _peaks: Dictionary = {"idle": 0.0, "impact": 0.0}
var _samples: Dictionary = {"idle": 0, "impact": 0}
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use a native display (or Xvfb); headless intentionally disables audio.")
		quit(2)
		return
	root.size = Vector2i(640, 360)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(0, _capture)
	var world: Node3D = Node3D.new()
	root.add_child(world)
	_box(world, Vector3(60, 1, 100), Vector3(0, -0.5, -20))
	_box(world, Vector3(30, 3, 0.4), Vector3(0, 1.5, -12))
	var body = Vehicle.new()
	body.configure(JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles/yamaha_yzf_2021.json")))
	world.add_child(body)
	body.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, body.ride_height, 0)))
	var audio = EngineAudio.new()
	audio.vehicle = body
	world.add_child(audio)
	await _frames(150)
	_check(int(_samples.idle) > 4000 and float(_peaks.idle) > 0.005, "running engine produces non-silent mixed PCM")
	_phase = "impact"
	body.linear_velocity = Vector3(0, 0, -24)
	for _i: int in 240:
		await physics_frame
		if body.crashed:
			break
	await _frames(120)
	_check(body.crashed and not body.can_drive(), "actual contact cuts the motorcycle engine")
	_check(audio._impact_serial == int(body.telemetry().impact_serial) and audio._impact_serial > 0, "audio consumes the physical collision event")
	_check(int(_samples.impact) > 4000 and float(_peaks.impact) > float(_peaks.idle) * 1.5, "impact transient reaches the mixed bus")
	_check(float(_peaks.impact) < 0.99, "mixed audio stays below clipping")
	var report: Dictionary = {"samples": _samples, "peaks": _peaks, "failures": _failures}
	var file: FileAccess = FileAccess.open("user://audio_contact_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print("AUDIO_CONTACT_PROBE ", "PASS " if _failures.is_empty() else "FAIL ", report)
	audio._player.stop()
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	_capture = null
	world.queue_free()
	# Let the audio mixing thread finish releasing the stopped playback.
	await create_timer(0.25).timeout
	quit(0 if _failures.is_empty() else 1)

func _process(_delta: float) -> bool:
	if _capture == null:
		return false
	var frames: PackedVector2Array = _capture.get_buffer(_capture.get_frames_available())
	_samples[_phase] = int(_samples[_phase]) + frames.size()
	for frame: Vector2 in frames:
		_peaks[_phase] = maxf(float(_peaks[_phase]), maxf(absf(frame.x), absf(frame.y)))
	return false

func _box(parent: Node3D, size: Vector3, location: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("surface", "asphalt")
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = location
	parent.add_child(body)

func _frames(count: int) -> void:
	for _i: int in count:
		await physics_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)
