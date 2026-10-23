class_name ApexLapTracker
extends RefCounted
## Ordered gates count complete circuits; timing validity is tracked separately.

const GATES: int = 12
const FINISH_TOLERANCE_M: float = 0.5
var closed: bool = true
var lap: int = 1
var completed_laps: int = 0
var valid_laps: int = 0
var invalid_laps: int = 0
var last_lap_valid: bool = false
var best: float = 0.0
var previous: float = 0.0
var elapsed: float = 0.0
var lap_time: float = 0.0
var valid: bool = true
var finished: bool = false
var distance: float = 0.0
var progress: float = 0.0
var last_message: String = ""
var _next_gate: int = 1
var _last_distance: float = 0.0
var _off_time: float = 0.0
var _reverse_distance: float = 0.0
var _length: float = 1.0

func setup(length_m: float, initial_distance: float = 0.0, is_closed: bool = true) -> void:
	_length = maxf(1.0, length_m)
	closed = is_closed
	lap = 1
	completed_laps = 0
	valid_laps = 0
	invalid_laps = 0
	last_lap_valid = false
	best = 0.0
	previous = 0.0
	elapsed = 0.0
	lap_time = 0.0
	valid = true
	finished = false
	distance = _normalize(initial_distance)
	progress = distance
	_last_distance = distance
	_next_gate = 1
	# Grid rows on a short stage can already lie beyond its first checkpoint.
	if not closed and distance <= minf(50.0, _length * 0.25):
		_next_gate = mini(GATES - 1, floori(distance / _length * GATES) + 1)
	_off_time = 0.0
	_reverse_distance = 0.0
	last_message = ""

func tick(delta: float, new_distance: float, road_error: float, road_width: float, total_laps: int) -> bool:
	if finished or delta <= 0.0 or not is_finite(new_distance):
		return false
	elapsed += delta
	lap_time += delta
	distance = _normalize(new_distance)
	_off_time = _off_time + delta if road_error > road_width * 0.5 + 1.5 else 0.0
	if _off_time > 1.0:
		invalidate("Fuera de pista · " + ("vuelta" if closed else "etapa") + " no válida")
	var step: float = distance - _last_distance
	if closed and step > _length * 0.5:
		step -= _length
	elif closed and step < -_length * 0.5:
		step += _length
	# 160 m/s exceeds vehicle capability; 4 m tolerance covers projection noise.
	if absf(step) > maxf(6.0, delta * 160.0 + 4.0):
		notify_reset(distance, "Reposición o salto de sectores · vuelta no válida")
		return false
	_reverse_distance = _reverse_distance - step if step < 0.0 else 0.0
	if _reverse_distance > 5.0:
		invalidate("Sentido contrario · " + ("vuelta" if closed else "etapa") + " no válida")
	if step > 0.0:
		_accept_gates(_last_distance, _last_distance + step)
	var crossed: bool = step > 0.0 and _last_distance + step >= _length
	if not closed:
		crossed = step > 0.0 and _last_distance < _length - FINISH_TOLERANCE_M and distance >= _length - FINISH_TOLERANCE_M
	_last_distance = distance
	if crossed:
		if closed:
			_finish_lap(total_laps)
		else:
			_finish_stage()
	progress = completed_laps * _length + distance if closed else (_length if finished else distance)
	return crossed

func _accept_gates(start: float, end: float) -> void:
	while _next_gate < GATES:
		var gate_distance: float = _length * float(_next_gate) / float(GATES)
		if gate_distance <= start or gate_distance > end:
			break
		_next_gate += 1

func _finish_lap(total_laps: int) -> void:
	if _next_gate >= GATES:
		_record_completion()
		lap += 1
		finished = completed_laps >= maxi(1, total_laps)
		last_message = "Vuelta %.3f s%s" % [previous, "" if valid else " · no válida"]
	else:
		last_lap_valid = false
		last_message = "Faltan sectores · vuelve a completar el circuito"
	_next_gate = 1
	lap_time = 0.0
	valid = true
	_off_time = 0.0
	_reverse_distance = 0.0

func _finish_stage() -> void:
	if _next_gate < GATES:
		last_message = "Faltan sectores · reinicia para completar la etapa"
		return
	_record_completion()
	finished = true
	last_message = "Etapa %.3f s%s" % [previous, "" if valid else " · no válida"]

func _record_completion() -> void:
	previous = lap_time
	last_lap_valid = valid
	if valid:
		valid_laps += 1
		if best == 0.0 or lap_time < best:
			best = lap_time
	else:
		invalid_laps += 1
	completed_laps += 1

func _normalize(value: float) -> float:
	return fposmod(value, _length) if closed else clampf(value, 0.0, _length)

func notify_reset(new_distance: float, reason: String = "Vehículo recolocado · vuelta no válida") -> void:
	invalidate(reason)
	distance = _normalize(new_distance)
	_last_distance = distance
	_next_gate = 1
	_off_time = 0.0
	_reverse_distance = 0.0
	progress = completed_laps * _length + distance if closed else distance

func notify_recovery(new_distance: float, reason: String) -> void:
	if closed:
		notify_reset(new_distance, reason)
		return
	# An explicit stage recovery can keep gates already traversed, never add
	# gates or advance the car's progress. Generic jumps still use notify_reset.
	var visited: int = _next_gate
	notify_reset(minf(distance, new_distance), reason)
	_next_gate = visited

func invalidate(reason: String) -> void:
	valid = false
	last_message = reason

static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "—:——.———"
	var milliseconds: int = roundi(seconds * 1000)
	return "%d:%02d.%03d" % [milliseconds / 60000, (milliseconds / 1000) % 60, milliseconds % 1000]
