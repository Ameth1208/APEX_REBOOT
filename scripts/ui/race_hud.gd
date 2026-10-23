class_name ApexHUD
extends Control

signal pause_requested
var tower: ApexRaceTower
var timing_panel: ApexTimingPanel
var cluster: ApexInstrumentCluster
var speed: Label
var gear: Label
var rpm: ApexRPMStrip
var throttle_input: ApexCompactPedal
var brake_input: ApexCompactPedal
var handbrake_input: ApexCompactPedal
var countdown: Label
var message: Label
var map: ApexMinimap
var condition: ApexVehicleStatus
var telemetry_box: ApexHudTelemetry
var physics_overlay: PhysicsDebugOverlay
var show_telemetry: bool = false
var _ui: Dictionary = {}
var _notice_time: float = 0.0
var _map_refresh: float = 0.0

func build(session: ApexRaceSession) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui = ApexHudLayout.build(self, session)
	for key: String in ["tower", "timing_panel", "cluster", "countdown", "message", "map", "condition", "telemetry_box"]:
		set(key, _ui[key])
	# Physics debug overlay (F8).
	physics_overlay = PhysicsDebugOverlay.new()
	add_child(physics_overlay)
	physics_overlay.set_vehicle(session.player)
	speed = cluster.speed
	gear = cluster.gear
	rpm = cluster.rpm
	throttle_input = cluster.throttle_input
	brake_input = cluster.brake_input
	handbrake_input = cluster.handbrake_input
	resized.connect(_arrange)
	for key: String in ["tower", "timing_panel", "cluster", "condition"]:
		_ui[key].resized.connect(_arrange, CONNECT_DEFERRED)
	_ui.condition.minimum_size_changed.connect(_arrange, CONNECT_DEFERRED)
	_arrange.call_deferred()

func update_session(session: ApexRaceSession, camera_mode: String, delta: float) -> void:
	var data: Dictionary = session.player.telemetry()
	cluster.update_state(data, float(session.player.profile.get("max_rpm", 8000)))
	tower.update_session(session, delta)
	timing_panel.update_session(session, delta)
	condition.update_state(data)
	_ui.auto_badge.visible = session.autopilot
	countdown.text = str(ceili(session.countdown - 0.8)) if session.countdown > 0.8 else ("SALIDA" if session.countdown > 0 else "")
	telemetry_box.visible = show_telemetry
	if show_telemetry:
		telemetry_box.update_state(data, camera_mode)
	_map_refresh -= delta
	if _map_refresh <= 0.0:
		map.queue_redraw()
		_map_refresh = 1.0 / 30.0
	_notice_time = maxf(0.0, _notice_time - delta)
	_ui.notice_box.visible = _notice_time > 0.0 and not message.text.is_empty()
	_ui.notice_box.modulate.a = minf(1.0, _notice_time / 0.35)
	if _notice_time <= 0.0:
		message.text = ""

func reset_session_history() -> void:
	tower.reset_intervals()

func notify(text: String) -> void:
	message.text = text
	_notice_time = 5.0

func _arrange() -> void:
	ApexHudLayout.arrange(self, _ui)
