extends Node3D
## Contact-driven effects use the same telemetry for the player and every rival.

const Trails = preload("res://scripts/vehicles/tyre_trails.gd")
const Particles = preload("res://scripts/vehicles/vehicle_particles.gd")
var _vehicle
var _trails
var _tyres: Array[CPUParticles3D] = []
var _sparks: CPUParticles3D
var _engine_smoke: CPUParticles3D
var _impact_serial: int = 0
var _repair_serial: int = -1
var _engine_offset: Vector3 = Vector3(0, 0.2, 0.3)

func _ready() -> void:
	_vehicle = get_parent()
	top_level = true
	global_transform = Transform3D.IDENTITY
	_trails = Trails.new()
	_trails.name = "TyreMarks"
	add_child(_trails)
	for i: int in (2 if _vehicle.is_motorcycle else 4):
		_tyres.append(Particles.puff(self, "ContactPuff%d" % i))
	_sparks = Particles.sparks(self)
	_engine_smoke = Particles.puff(self, "EngineSmoke", 32)
	_engine_smoke.color = Color(0.20, 0.22, 0.24, 0.8)
	_engine_smoke.lifetime = 1.8
	var offset: Array = _vehicle.profile.get("engine_smoke_offset_m", [0, 0.2, 0.3])
	if offset.size() == 3:
		_engine_offset = Vector3(float(offset[0]), float(offset[1]), float(offset[2]))

func _process(delta: float) -> void:
	if not is_instance_valid(_vehicle):
		return
	var condition = _vehicle._condition
	if _repair_serial != condition.repair_serial:
		_repair_serial = condition.repair_serial
		_trails.clear_connections()
		for emitter in _tyres:
			emitter.emitting = false
	_trails.update_contacts(_vehicle.wheel_contacts, _vehicle.global_position, _vehicle.is_motorcycle, delta)
	_update_tyres()
	if _impact_serial != condition.impact_serial:
		_impact_serial = condition.impact_serial
		_sparks.global_position = condition.impact_position
		_sparks.direction = condition.impact_normal
		_sparks.restart()
		_sparks.emitting = true
	_engine_smoke.global_position = _vehicle.global_position + _vehicle.global_basis * _engine_offset
	_engine_smoke.emitting = condition.engine_health < 0.62

func _update_tyres() -> void:
	for emitter in _tyres:
		emitter.emitting = false
	for wheel: Dictionary in _vehicle.wheel_contacts:
		var index: int = int(wheel["index"])
		if index < 0 or index >= _tyres.size() or float(wheel["load"]) < 80.0:
			continue
		var loose: bool = str(wheel["surface"]) in ["gravel", "dirt", "grass", "sand"]
		var moving: bool = Vector3(wheel["velocity"]).length() > 3.0
		var smoke: bool = float(wheel.get("slide_speed", 0.0)) > 3.0
		var spray: bool = not loose and _vehicle.wetness > 0.25 and _vehicle.speed_kph > 30.0
		var emitter: CPUParticles3D = _tyres[index]
		emitter.global_position = _vehicle.global_position + Vector3(wheel["position"]) + Vector3(wheel["normal"]) * 0.06
		emitter.color = Color(0.53, 0.43, 0.30, 0.8) if loose else Color(0.74, 0.81, 0.85, 0.55 if spray else 0.8)
		emitter.emitting = (loose and moving) or smoke or spray
