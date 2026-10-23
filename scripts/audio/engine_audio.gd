extends Node
## Procedural engine pulses, road/tyres and collision transients. Profile-specific
## cylinder counts are used; these are synthesized sounds, not engine recordings.

var vehicle: RigidBody3D
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _smooth_rpm: float = 1000.0
var _random := RandomNumberGenerator.new()
var _impact_serial: int = 0
var _impact_envelope: float = 0.0
var _impact_phase: float = 0.0
var _squeal_phase: float = 0.0
var _rough_phase: float = 0.0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_player = AudioStreamPlayer.new()
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.20
	_player.stream = stream
	_player.volume_db = -15
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()
	_random.seed = 42

func _process(delta: float) -> void:
	if not is_instance_valid(vehicle) or _playback == null:
		return
	var data: Dictionary = vehicle.telemetry()
	_smooth_rpm = lerpf(_smooth_rpm, float(data.rpm), minf(delta * 10, 1))
	var cylinders: float = float(vehicle.profile.get("engine_cylinders", vehicle.profile.get("cylinders", 6)))
	var frequency: float = _smooth_rpm / 60.0 * cylinders * 0.5
	var load_level: float = 0.20 + float(data.throttle) * 0.24
	if not bool(data.get("can_drive", true)):
		load_level *= clampf(_smooth_rpm / 1800.0, 0.0, 1.0)
	var wind: float = clampf(float(data.speed_kph) / 400, 0, 0.20)
	var slip: float = clampf(float(data.tire_slip) - 0.25, 0, 0.65)
	var loose: bool = str(data.surface) in ["grass", "gravel", "dirt", "sand"]
	var rolling: float = clampf(float(data.speed_kph) / 180.0, 0.0, 0.12) if int(data.grounded_wheels) > 0 else 0.0
	var scrape: float = float(data.get("scrape_strength", 0.0))
	var damage: float = 1.0 - float(data.get("engine_health", 1.0))
	if _impact_serial != int(data.get("impact_serial", 0)):
		_impact_serial = int(data.get("impact_serial", 0))
		_impact_envelope = maxf(_impact_envelope, float(data.get("impact_strength", 0.0)))
		_impact_phase = 0.0
	var count: int = _playback.get_frames_available()
	for i in count:
		_phase = fposmod(_phase + frequency / 22050.0, 1.0)
		_squeal_phase = fposmod(_squeal_phase + (1650.0 + slip * 380.0) / 22050.0, 1.0)
		_rough_phase = fposmod(_rough_phase + 8.3 / 22050.0, 1.0)
		_impact_phase += 1.0 / 22050.0
		var engine: float = sin(_phase * TAU) * 0.55 + sin(_phase * TAU * 2) * 0.25 + sin(_phase * TAU * 3) * 0.12
		var noise: float = _random.randf_range(-1.0, 1.0)
		engine *= 1.0 - damage * maxf(sin(_rough_phase * TAU), 0.0) * 0.65
		var tyre: float = noise * rolling * (1.5 if loose else 0.4)
		if not loose and int(data.grounded_wheels) > 0:
			tyre += sin(_squeal_phase * TAU) * slip * 0.06 + noise * slip * 0.05
		var impact: float = (sin(_impact_phase * TAU * 57.0) * 0.7 + noise * 0.55) * _impact_envelope
		_impact_envelope *= 0.99955
		var sample: float = engine * load_level + noise * (wind + scrape * 0.18) + tyre + impact
		sample = clampf(sample, -0.98, 0.98)
		_playback.push_frame(Vector2(sample, sample))
