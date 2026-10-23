class_name ApexRaceSession
extends Node3D

signal finished(result: Dictionary)
signal notice(message: String)

var track: Node3D
var player: RigidBody3D
var vehicles: Array = []
var drivers: Array[ApexRacingDriver] = []
var laps: Array[ApexLapTracker] = []
var retired: Array[bool] = []
var settings: Dictionary
var line := ApexRacingLine.new()
var countdown: float = 3.8
var active: bool = false
var autopilot: bool = false
var autopilot_used: bool = false
var position_in_race: int = 1
var player_driver: ApexRacingDriver
var _input := ApexPlayerInput.new()
var _wake = preload("res://scripts/physics/aero_wake.gd").new()
var _finished: bool = false
var _recoveries: Array[int] = []
var _retirement_reasons: Array[String] = []
var _player_recovery_notice: bool = false
const Classification = preload("res://scripts/race/race_classification.gd")
const AI_PACE: Dictionary = {"Easy": 0.68, "Normal": 0.80, "Expert": 0.92}

func start(profile: Dictionary, definition: Dictionary, options: Dictionary) -> void:
	settings = options.duplicate(true)
	_input.configure(settings)
	track = load("res://scripts/tracks/circuit_track.gd").new()
	add_child(track)
	track.build(definition)
	settings["closed"] = track.closed
	if not track.closed:
		settings["laps"] = 1
	player = ApexVehicleFactory.create(self, profile, settings, track.get_grid_transform(0), str(settings.get("paint", "Original")), "Tú")
	vehicles.append(player)
	var count: int = int(settings.get("opponents", 3)) if settings.get("mode", "") in ["Carrera", "Campeonato"] else 0
	for i in count:
		var ai_options: Dictionary = settings.duplicate(true)
		ai_options["assists"] = "Assisted"
		ai_options["automatic"] = true
		var offset: float = 1.8 if i % 2 == 0 else -1.8
		var body: RigidBody3D = ApexVehicleFactory.create(self, profile, ai_options, track.get_grid_transform(i + 1), ApexCatalog.PAINT_NAMES[(i + 1) % 7 + 1], "Piloto %02d" % (i + 1))
		vehicles.append(body)
		var driver := ApexRacingDriver.new()
		driver.configure(body, track, float(settings.get("wetness", 0.0)), _pace_for(i, count), offset * 0.4)
		drivers.append(driver)
	for body in vehicles:
		var tracker := ApexLapTracker.new()
		tracker.setup(track.get_length(), track.closest_distance(body.global_position), track.closed)
		laps.append(tracker)
		retired.append(false)
		_recoveries.append(0)
		_retirement_reasons.append("")
	player_driver = ApexRacingDriver.new()
	player_driver.configure(player, track, float(settings.get("wetness", 0.0)), 0.84)
	line.build(track, player_driver.planner)
	line.visible = bool(settings.get("racing_line", true))
	add_child(line)
	var audio: Node = load("res://scripts/audio/engine_audio.gd").new()
	audio.vehicle = player
	add_child(audio)
	active = true

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(player):
		return
	_wake.update(vehicles, delta)
	for body in vehicles:
		var visual: Node3D = body.get_node("Visual")
		var signed_speed: float = body.linear_velocity.dot(-body.global_basis.z.normalized())
		visual.animate(signed_speed, float(body.steer_angle), float(body.lean_angle), delta)
		visual.sync_suspension(body.wheel_contacts, delta)
	if countdown > 0.0:
		countdown -= delta
		for body in vehicles:
			body.set_controls(0, 1, 0)
		return
	if _finished:
		for body in vehicles:
			body.set_controls(0, 1, 0)
		return
	if autopilot:
		autopilot_used = true
		_drive_ai(0, player_driver, delta)
	else:
		_input.apply(player, delta)
	if player.has_method("can_drive") and not player.can_drive() and not _player_recovery_notice:
		_player_recovery_notice = true
		notice.emit("Vehículo inmovilizado · pulsa %s para recuperar y reparar" % ApexBindings.label_for("reset_car"))
	for i in drivers.size():
		_drive_ai(i + 1, drivers[i], delta)
	_update_timing(delta)

func _drive_ai(index: int, driver: ApexRacingDriver, delta: float) -> void:
	if laps[index].finished or retired[index]:
		vehicles[index].set_controls(0.0, 1.0, 0.0)
		return
	driver.drive(delta, vehicles)
	if driver.recovery_count > _recoveries[index]:
		_recoveries[index] = driver.recovery_count
		laps[index].invalidate("Maniobra de recuperación · intento no válido")
	if driver.retired:
		if index > 0:
			_retire(index, driver.retirement_reason)
		elif not _player_recovery_notice:
			_player_recovery_notice = true
			notice.emit(driver.retirement_reason + " · pulsa %s para recuperar" % ApexBindings.label_for("reset_car"))

func _retire(index: int, reason: String) -> void:
	retired[index] = true
	_retirement_reasons[index] = reason
	laps[index].invalidate("Abandono · " + reason)
	vehicles[index].set_controls(0.0, 1.0, 0.0)
	if index > 0:
		notice.emit(str(vehicles[index].name) + " abandona · " + reason)

func _update_timing(delta: float) -> void:
	var total: int = int(settings.get("laps", 3))
	if settings.get("mode", "") == "Libre" and track.closed:
		total = 999999
	for i in vehicles.size():
		if retired[i]:
			continue
		var body: RigidBody3D = vehicles[i]
		var tracker: ApexLapTracker = laps[i]
		var distance: float = track.closest_distance(body.global_position, tracker.distance)
		var sample: Dictionary = track.sample_at(distance)
		var error: float = absf((body.global_position - Vector3(sample.position)).dot(Vector3(sample.right)))
		if tracker.tick(delta, distance, error, float(sample.width), total) and i == 0:
			notice.emit(tracker.last_message)
	for row: Dictionary in classification():
		if bool(row.is_player):
			position_in_race = int(row.position)
	if laps[0].finished and not _finished:
		_finish(total)

func classification() -> Array[Dictionary]:
	return Classification.build(vehicles, laps, retired, _retirement_reasons)

func retire_player() -> void:
	if _finished or not active:
		return
	_retire(0, "Retirada del jugador")
	_finish(int(settings.get("laps", 3)))

func _finish(total: int) -> void:
	_finished = true
	var rows: Array[Dictionary] = classification()
	for row: Dictionary in rows:
		if bool(row.is_player):
			position_in_race = int(row.position)
	finished.emit({"position": position_in_race, "racers": vehicles.size(), "best": laps[0].best,
		"total": laps[0].elapsed, "laps": total, "autopilot": autopilot_used, "mode": settings.get("mode", ""),
		"closed": track.closed, "stage_completed": not track.closed and laps[0].completed_laps == 1,
		"completed_laps": laps[0].completed_laps, "valid_laps": laps[0].valid_laps,
		"invalid_laps": laps[0].invalid_laps, "retired": retired[0], "classification": rows})

func reset_player() -> void:
	var distance: float = track.closest_distance(player.global_position, laps[0].distance)
	if not track.closed:
		distance = minf(distance, laps[0].distance)
	player.reset_at(track.get_spawn_transform(distance, 0.0))
	player_driver.reset_recovery()
	_player_recovery_notice = false
	if track.closed:
		laps[0].notify_reset(distance, "Vehículo recolocado · vuelta no válida")
	else:
		laps[0].notify_recovery(distance, "Etapa invalidada; puedes llegar a meta o reiniciar para registrar tiempo")
	notice.emit(laps[0].last_message)

func configure_player_input(values: Dictionary) -> void:
	_input.configure(values)

func configure_ai(values: Dictionary) -> void:
	settings["ai_difficulty"] = str(values.get("ai_difficulty", settings.get("ai_difficulty", "Normal")))
	for i: int in drivers.size():
		drivers[i].replan(float(vehicles[i + 1].wetness), _pace_for(i, drivers.size()))
	if player_driver.replan(float(player.wetness), 0.84):
		line.build(track, player_driver.planner)

func _pace_for(index: int, count: int) -> float:
	var base: float = float(AI_PACE.get(str(settings.get("ai_difficulty", "Normal")), 0.80))
	return clampf(base + (index - (count - 1) * 0.5) * 0.012, 0.45, 1.0)

func set_lights(enabled: bool) -> void:
	for body in vehicles:
		body.get_node("Visual").set_headlights(enabled)
