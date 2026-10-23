class_name ApexCameraMotion
extends RefCounted
## Small, bounded visual response to actual acceleration and discrete impacts.

var _last_velocity: Vector3 = Vector3.ZERO
var _sway: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _kick: float = 0.0
var _impact: int = 0
var _initialized: bool = false

func reset() -> void:
	_initialized = false
	_sway = Vector3.ZERO
	_kick = 0.0
	_impact = 0

func sample(vehicle: Node3D, basis: Basis, mode: int, delta: float, amount: float) -> Vector3:
	if delta <= 0.0 or amount <= 0.0:
		return Vector3.ZERO
	var velocity: Vector3 = vehicle.linear_velocity
	if not _initialized:
		_last_velocity = velocity
		_initialized = true
	var acceleration: Vector3 = (velocity - _last_velocity) / maxf(delta, 0.001)
	_last_velocity = velocity
	_time += delta
	var data: Dictionary = vehicle.telemetry()
	var serial: int = int(data.get("impact_serial", 0))
	if serial != _impact:
		_impact = serial
		_kick = maxf(_kick, clampf(float(data.get("impact_strength", 0.0)), 0.0, 1.0) * 0.075)
	_kick *= exp(-delta * 7.0)
	var desired := Vector3(clampf(-basis.x.dot(acceleration) * 0.0035, -0.055, 0.055), 0.0, clampf(-basis.z.dot(acceleration) * 0.004, -0.065, 0.065))
	_sway = _sway.lerp(desired, 1.0 - exp(-delta * 6.0))
	var rough: float = 0.0 if str(data.get("surface", "asphalt")) in ["asphalt", "concrete"] else 0.003
	var speed: float = clampf(velocity.length() / 35.0, 0.0, 1.0)
	var bounce: float = sin(_time * 34.0) * _kick
	if int(data.get("grounded_wheels", 0)) > 0:
		bounce += sin(_time * 19.0) * rough * speed
	var offset: Vector3 = _sway if mode in [1, 2] else Vector3.ZERO
	offset.y += bounce
	offset.x += cos(_time * 28.0) * _kick * 0.35
	return basis * offset * clampf(amount, 0.0, 1.0)
