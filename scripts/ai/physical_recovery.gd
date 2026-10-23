class_name ApexPhysicalRecovery
extends RefCounted
## Stuck cars manoeuvre with normal controls. No pose or velocity is assigned.

var state: String = "Conduciendo"
var attempts: int = 0
var count: int = 0
var retired: bool = false
var reason: String = ""
var _stuck: float = 0.0
var _time: float = 0.0
var _origin: Vector3 = Vector3.ZERO
var _reverse_steer: float = 0.0

func reset() -> void:
	state = "Conduciendo"
	attempts = 0
	retired = false
	reason = ""
	_stuck = 0.0
	_time = 0.0

func update(body: RigidBody3D, line: Dictionary, target: Vector3, desired_speed: float, rear_clear: bool, delta: float) -> Variant:
	if retired:
		return Vector3(0.0, 1.0, 0.0)
	if body.has_method("can_drive") and not body.can_drive():
		return _retire("Vehículo sin capacidad de continuar")
	if body.global_position.y < Vector3(line.position).y - 60.0:
		return _retire("Fuera del área de conducción")
	var speed: float = body.linear_velocity.length()
	var upright: float = body.global_basis.y.dot(Vector3(line.normal))
	var alignment: float = (-body.global_basis.z).dot(Vector3(line.forward))
	var forward_speed: float = body.linear_velocity.dot(-body.global_basis.z)
	if state == "Conduciendo":
		_stuck = _stuck + delta if speed < 1.1 and desired_speed > 4.0 else 0.0
		if upright < 0.3 and speed < 1.5:
			_stuck += delta
		if _stuck < 3.0:
			return null
		if upright < 0.3:
			return _retire("Vehículo volcado")
		_begin_reverse(body, target)
	_time += delta
	if state == "Frenando para maniobrar":
		if speed < 0.6 and rear_clear and _rear_free(body):
			state = "Marcha atrás"
			_time = 0.0
			_origin = body.global_position
		elif _time > 8.0:
			return _retire("Sin espacio para maniobrar")
		return Vector3(0.0, 1.0, 0.0)
	if state == "Marcha atrás":
		if _time > 2.5 or body.global_position.distance_to(_origin) > 3.5 or not rear_clear or not _rear_free(body):
			state = "Cambiando a avance"
			_time = 0.0
			return Vector3(0.0, 1.0, 0.0)
		var pedal: float = clampf((2.3 + forward_speed) * 0.45, 0.0, 0.48)
		return Vector3(-pedal, 0.0, _reverse_steer)
	if state == "Cambiando a avance":
		if speed < 0.6:
			state = "Reorientando"
			_time = 0.0
		return Vector3(0.0, 1.0, 0.0)
	if state == "Reorientando":
		if forward_speed > 2.5 and alignment > 0.65:
			reset()
			return null
		if _time > 5.0:
			if attempts >= 3:
				return _retire("No pudo recuperar la trayectoria")
			_begin_reverse(body, target)
			return Vector3(0.0, 1.0, 0.0)
		var local: Vector3 = body.to_local(target)
		var steer: float = clampf(atan2(local.x, maxf(1.0, -local.z)) * 1.8, -0.9, 0.9)
		return Vector3(clampf((4.0 - forward_speed) * 0.3, 0.0, 0.5), 0.0, steer)
	return null

func _begin_reverse(body: RigidBody3D, target: Vector3) -> void:
	attempts += 1
	count += 1
	_time = 0.0
	_stuck = 0.0
	state = "Frenando para maniobrar"
	var side: float = signf(body.to_local(target).x)
	_reverse_steer = -0.75 * (side if side != 0.0 else 1.0)

func _rear_free(body: RigidBody3D) -> bool:
	var half_width: float = float(body.profile.get("body_width_m", 1.8)) * 0.45
	var reach: float = float(body.profile.get("length_m", 4.5)) * 0.5 + 3.5
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	for side: float in [-half_width, 0.0, half_width]:
		var start: Vector3 = body.global_position + body.global_basis.x * side
		var query := PhysicsRayQueryParameters3D.create(start, start + body.global_basis.z * reach, 3, [body.get_rid()])
		if not space.intersect_ray(query).is_empty():
			return false
	return true

func _retire(message: String) -> Vector3:
	retired = true
	reason = message
	state = "Abandono"
	return Vector3(0.0, 1.0, 0.0)
