extends Node3D
## Composition root. Rendering, screens and simulation remain separate modules.

var settings := ApexSettings.new()
var career := ApexCareer.new()
var environment := ApexEnvironment.new()
var showroom := ApexShowroom.new()
var camera := ApexCamera.new()
var screens := ApexScreens.new()
var race: ApexRaceSession
var scenery: ApexScenery
var custom_track: Dictionary = {}
var _building: bool = false
var _headlights: bool = false
var _photo: bool = false
var _track_intel: TrackIntelligence
var _racing_line: RacingLineVisualizer
var _racing_line_visible: bool = false
var performance = preload("res://scripts/app/performance_manager.gd").new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings.load_preferences()
	ApexInput.apply_preferences(settings.values)
	camera.configure(settings.values)
	career.load_progress()
	settings.apply_display()
	add_child(environment)
	environment.set_quality(str(settings.values.quality))
	environment.set_render_features(settings.values)
	performance.configure(get_viewport(), environment, str(settings.values.quality))
	add_child(showroom)
	add_child(camera)
	add_child(screens)
	screens.start_requested.connect(start_race)
	screens.changed.connect(change_setting)
	screens.action_requested.connect(handle_action)
	screens.track_applied.connect(apply_track)
	show_garage()
	if OS.get_cmdline_user_args().has("--qa"):
		var probe: Node = load("res://tools/runtime_probe.gd").new()
		add_child(probe)
		probe.run(self)
	elif OS.get_cmdline_user_args().has("--qa-distribution"):
		var probe: Node = load("res://scripts/qa/native_distribution_smoke.gd").new()
		add_child(probe)
		probe.run(self)

func show_garage() -> void:
	get_tree().paused = false
	if is_instance_valid(_racing_line):
		_racing_line.queue_free()
		_racing_line = null
	_track_intel = null
	_photo = false
	camera.photo_mode = false
	if is_instance_valid(race):
		remove_child(race)
		race.queue_free()
		race = null
	if is_instance_valid(scenery):
		remove_child(scenery)
		scenery.queue_free()
	showroom.visible = true
	showroom.show_vehicle(ApexCatalog.vehicle(int(settings.values.vehicle)), str(settings.values.paint), str(settings.values.livery))
	camera.follow(showroom.target, true)
	environment.set_night(bool(settings.values.night))
	environment.set_showroom()
	screens.show_menu(settings.values, career)

func start_race() -> void:
	if _building:
		return
	_building = true
	get_tree().paused = false
	_photo = false
	camera.photo_mode = false
	screens.show_loading("Preparando vehículos, geometría y trazada…")
	await get_tree().process_frame
	await get_tree().process_frame
	var options: Dictionary = settings.values.duplicate(true)
	if options.mode == "Campeonato":
		var event: Dictionary = ApexCareer.EVENTS[clampi(int(options.get("career_event", 0)), 0, career.unlocked)]
		for key in event:
			if key in ["vehicle", "track", "laps", "night", "opponents"]:
				options[key] = event[key]
	if is_instance_valid(race):
		remove_child(race)
		race.queue_free()
	if is_instance_valid(scenery):
		remove_child(scenery)
		scenery.queue_free()
	showroom.visible = false
	race = ApexRaceSession.new()
	race.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(race)
	var definition: Dictionary = custom_track if not custom_track.is_empty() and options.mode != "Campeonato" else ApexCatalog.track(int(options.track))
	race.start(ApexCatalog.vehicle(int(options.vehicle)), definition, options)
	ApexRuntimeSettings.apply(race, options)
	race.finished.connect(_race_finished)
	race.notice.connect(func(text: String):
		if is_instance_valid(screens.hud): screens.hud.notify(text))
	camera.mode = int(settings.values.camera)
	camera.follow(race.player)
	scenery = ApexScenery.new()
	add_child(scenery)
	scenery.target = race.player
	scenery.night = bool(options.night)
	await scenery.build(race.track)
	ApexRenderQuality.apply_features(scenery, options)
	ApexRenderQuality.apply_features(race.track, options)
	environment.set_render_features(options)
	performance.bind_scenery(scenery)
	environment.set_night(bool(options.night))
	environment.set_wetness(float(options.wetness))
	_headlights = bool(options.night)
	# Build track intelligence and racing line.
	_build_racing_line()
	screens.show_hud(race)
	screens.hud.apply_preferences(settings.values)
	get_viewport().gui_release_focus()
	_building = false
	settings.save_preferences()

func change_setting(key: String, value: Variant) -> void:
	if key == "vehicle":
		ApexVehiclePreferences.remember(settings.values)
	settings.values[key] = value
	if key.begins_with("hud_") and is_instance_valid(screens.hud):
		screens.hud.apply_preferences(settings.values)
	if key == "vehicle":
		ApexVehiclePreferences.restore(settings.values)
	if key in ["paint", "livery"]:
		ApexVehiclePreferences.remember(settings.values)
	settings.save_preferences()
	if key in ["key_bindings", "steering_deadzone", "pedal_deadzone"]:
		ApexInput.apply_preferences(settings.values)
	if key.begins_with("camera_"):
		camera.configure(settings.values)
	if key in ["fullscreen", "quality", "volume"]:
		settings.apply_display(false)
		if key == "quality": performance.configure(get_viewport(), environment, str(value))
	if key in ["night", "wetness"]:
		if key == "night": _headlights = bool(value)
		environment.set_night(bool(settings.values.night))
		environment.set_wetness(float(settings.values.wetness))
		if is_instance_valid(scenery): scenery.night = bool(settings.values.night)
	if key.begins_with("render_"):
		environment.set_render_features(settings.values)
		if is_instance_valid(scenery): ApexRenderQuality.apply_features(scenery, settings.values)
		if is_instance_valid(race) and is_instance_valid(race.track): ApexRenderQuality.apply_features(race.track, settings.values)
	if key == "track": custom_track.clear()
	if is_instance_valid(screens.menu) and showroom.visible:
		environment.set_showroom()
		screens.menu.update_vehicle(int(settings.values.vehicle))
		if key == "vehicle":
			showroom.show_vehicle(ApexCatalog.vehicle(int(value)), str(settings.values.paint), str(settings.values.livery))
			camera.follow(showroom.target, true)
		if key == "paint": showroom.vehicle.set_paint(ApexCatalog.paint_color(str(value)), str(value) == "Original")
		if key == "livery": showroom.vehicle.set_livery(str(value))
	if is_instance_valid(race) and not _building and (key in ["wetness", "aero", "grip", "assists", "automatic", "racing_line", "night", "ai_difficulty", "steering_response", "steering_curve", "pedal_curve"] or key.begins_with("wheel_")):
		ApexRuntimeSettings.apply(race, settings.values)

func handle_action(action: String) -> void:
	match action:
		"pause":
			get_tree().paused = true
			screens.show_modal("PAUSA", "Tu sesión está detenida.", {"resume": "CONTINUAR", "confirm_restart": "REINICIAR", "pause_camera": "CAMBIAR CÁMARA", "pause_photo": "MODO FOTO", "pause_controls": "CONTROLES", "options": "AJUSTES", "editor": "EDITAR PISTA", "confirm_garage": "VOLVER AL GARAJE"})
		"confirm_restart":
			screens.show_modal("¿REINICIAR?", "Comenzarás de nuevo esta sesión.", {"restart": "REINICIAR SESIÓN", "pause": "SEGUIR EN PAUSA"})
		"confirm_garage":
			screens.show_modal("¿VOLVER AL GARAJE?", "Se perderá el progreso de esta sesión.", {"garage": "VOLVER AL GARAJE", "pause": "SEGUIR EN PAUSA"})
		"pause_camera":
			camera.cycle()
			settings.values.camera = camera.mode
			handle_action("resume")
		"pause_photo":
			screens.clear_overlay()
			_photo = true
			camera.photo_mode = true
			screens.hud.visible = false
		"pause_controls":
			screens.show_options(settings.values)
			screens.options._select_category(0)
		"resume", "close_overlay":
			if action == "close_overlay" and is_instance_valid(screens.options) and is_instance_valid(race) and get_tree().paused:
				handle_action("pause")
				return
			screens.clear_overlay()
			get_tree().paused = false
			_photo = false
			camera.photo_mode = false
		"garage": show_garage()
		"restart": start_race()
		"retire":
			if is_instance_valid(race): race.retire_player()
		"editor":
			get_tree().paused = true
			# From main menu: simplified creation flow. From pause: full editor.
			if is_instance_valid(race):
				var definition: Dictionary = race.track.definition
				screens.show_editor(definition)
			else:
				# Start the map editor from the currently selected catalog route.
				var track_index: int = clampi(int(settings.values.track), 0, maxi(0, ApexCatalog.entries("tracks").size() - 1))
				screens.show_editor(ApexCatalog.track(track_index))
		"load_track":
			screens.show_creation_flow()
		"route_planner":
			var route_index: int = clampi(int(settings.values.track), 0, maxi(0, ApexCatalog.entries("tracks").size() - 1))
			screens.show_route_planner(ApexCatalog.track(route_index))
		"options":
			get_tree().paused = is_instance_valid(race)
			screens.show_options(settings.values)
		"credits":
			screens.show_modal("CRÉDITOS", "APEX REBOOT — Simulador de conducción para academia.\nFísica: Pacejka, Box3D concepts, suspensión progresiva.\nEntorno: OpenStreetMap, terrain blending, biomas.", {"close": "Volver"})

func apply_track(definition: Dictionary) -> void:
	custom_track = definition.duplicate(true)
	if settings.values.mode == "Campeonato":
		settings.values.mode = "Libre"
	screens.clear_overlay()
	get_tree().paused = false
	start_race()

func _build_racing_line() -> void:
	# Clean up previous.
	if is_instance_valid(_racing_line):
		_racing_line.queue_free()
	if is_instance_valid(_track_intel):
		_track_intel = null
	if not is_instance_valid(race) or not is_instance_valid(race.track):
		return
	# Use one driving-line renderer, not both the legacy strip and dynamic overlay.
	if is_instance_valid(race.line):
		race.line.visible = false
	var track: Node3D = race.track
	if not ("samples" in track) or track.samples.is_empty():
		return
	# This visualizer is CPU-heavy and is disabled by default.
	_racing_line_visible = bool(settings.values.get("racing_line", false))
	if not _racing_line_visible:
		return
	_track_intel = TrackIntelligence.new()
	var vehicle: Dictionary = race.player.profile if is_instance_valid(race.player) else {}
	_track_intel.build(track.samples, vehicle, float(settings.values.get("wetness", 0.0)))
	_racing_line = RacingLineVisualizer.new()
	add_child(_racing_line)
	_racing_line.set_intelligence(_track_intel)
	_racing_line.set_line_visible(_racing_line_visible)

func set_racing_line_visible(value: bool) -> void:
	_racing_line_visible = value
	settings.values["racing_line"] = value
	if _building:
		return # start_race builds intelligence once, after scenery is ready.
	if is_instance_valid(race) and is_instance_valid(race.line):
		race.line.visible = false
	if value and not is_instance_valid(_racing_line) and is_instance_valid(race):
		_build_racing_line()
		return
	if is_instance_valid(_racing_line):
		_racing_line.set_line_visible(value)

func _update_racing_line() -> void:
	if not _racing_line_visible or not is_instance_valid(_racing_line) or not is_instance_valid(race) or not is_instance_valid(race.player):
		return
	if _track_intel == null:
		return
	var player: RigidBody3D = race.player
	var pos: Vector3 = player.global_position
	var idx: int = _track_intel.sample_at_position(pos)
	var speed: float = player.linear_velocity.length()
	var braking: bool = false
	if "_brake" in player:
		braking = float(player.get("_brake")) > 0.1
	_racing_line.set_player_state(idx, speed, braking)

func _process(delta: float) -> void:
	performance.sample(delta, is_instance_valid(race) and not _building and not get_tree().paused)
	if is_instance_valid(race) and is_instance_valid(screens.hud) and not _building:
		screens.hud.update_session(race, ApexCamera.NAMES[camera.mode], delta)
	_update_racing_line()

func _unhandled_input(event: InputEvent) -> void:
	if _building or event.is_echo():
		return
	if event.is_action_pressed("performance_report"):
		var message: String = performance.save_report()
		if is_instance_valid(screens.hud): screens.hud.notify(message)
	elif event.is_action_pressed("pause_game"):
		handle_action("resume" if get_tree().paused else ("pause" if is_instance_valid(race) else "close_overlay"))
	elif event.is_action_pressed("editor"):
		handle_action("editor")
	elif event.is_action_pressed("toggle_night"):
		change_setting("night", not bool(settings.values.night))
	elif event.is_action_pressed("racing_line"):
		set_racing_line_visible(not _racing_line_visible)
		if is_instance_valid(screens.hud): screens.hud.notify("Línea de carrera: " + ("VISIBLE" if _racing_line_visible else "oculta"))
	elif event.is_action_pressed("screenshot"):
		ApexPhoto.capture(get_viewport(), screens.hud)
	elif is_instance_valid(race) and not get_tree().paused:
		if event.is_action_pressed("camera_next"):
			camera.cycle()
			settings.values.camera = camera.mode
		elif event.is_action_pressed("reset_car"):
			race.reset_player()
			screens.hud.reset_session_history()
		elif event.is_action_pressed("telemetry"): screens.hud.show_telemetry = not screens.hud.show_telemetry
		elif event.is_action_pressed("physics_debug"):
			if is_instance_valid(screens.hud) and screens.hud.physics_overlay != null:
				screens.hud.physics_overlay.toggle()
				screens.hud.notify("Modo Física: " + ("ACTIVO" if screens.hud.physics_overlay.is_enabled() else "oculto"))
		elif event.is_action_pressed("autopilot"):
			race.autopilot = not race.autopilot
			screens.hud.notify("Piloto automático " + ("activado" if race.autopilot else "desactivado"))
		elif event.is_action_pressed("toggle_lights"):
			_headlights = not _headlights
			race.set_lights(_headlights)
	if event.is_action_pressed("photo") and is_instance_valid(race):
		_photo = not _photo
		get_tree().paused = _photo
		camera.photo_mode = _photo
		screens.hud.visible = not _photo

func _race_finished(result: Dictionary) -> void:
	get_tree().paused = true
	var progression: String = ""
	if result.mode == "Campeonato":
		progression = "Retirada · no concede progreso de campeonato." if result.get("retired", false) else career.record(int(settings.values.get("career_event", 0)), result)
	screens.show_results(result, progression)
