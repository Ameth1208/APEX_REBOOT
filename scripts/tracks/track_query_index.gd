class_name TrackQueryIndex
extends RefCounted
## Cached 3D segments and binary station ranges for the previous-position window.
## Exact segment projection still chooses the deck at bridges and crossing roads.

const HINT_RADIUS_M: float = 180.0
const RECOVERY_DISTANCE_SQUARED: float = 2500.0
var _starts: PackedVector3Array = PackedVector3Array()
var _edges: PackedVector3Array = PackedVector3Array()
var _squared: PackedFloat64Array = PackedFloat64Array()
var _lengths: PackedFloat64Array = PackedFloat64Array()
var _stations: PackedFloat64Array = PackedFloat64Array()
var _length: float = 0.0
var _closed: bool = true
var last_candidate_count: int = 0

func clear() -> void:
	_starts.clear()
	_edges.clear()
	_squared.clear()
	_lengths.clear()
	_stations.clear()
	_length = 0.0

func rebuild(samples: Array[Dictionary], length_m: float, closed: bool) -> void:
	clear()
	_length = length_m
	_closed = closed
	var count: int = samples.size() if closed else maxi(0, samples.size() - 1)
	for index: int in range(count):
		var a: Dictionary = samples[index]
		var b: Dictionary = samples[(index + 1) % samples.size()]
		var edge: Vector3 = Vector3(b.position) - Vector3(a.position)
		_starts.append(a.position)
		_edges.append(edge)
		_squared.append(edge.length_squared())
		_lengths.append(edge.length())
		_stations.append(float(a.distance))

func closest(point: Vector3, hint: float = -1.0) -> float:
	last_candidate_count = 0
	var best: Array[float] = [INF, 0.0]
	if hint >= 0.0 and is_finite(hint) and _length > 0.0:
		_window(point, hint, best)
	if best[0] >= RECOVERY_DISTANCE_SQUARED:
		_scan(point, 0, _starts.size(), best)
	return fposmod(best[1], maxf(_length, 0.001)) if _closed else clampf(best[1], 0.0, _length)

func _window(point: Vector3, hint: float, best: Array[float]) -> void:
	if _closed and _length <= HINT_RADIUS_M * 2.0:
		_scan(point, 0, _starts.size(), best)
		return
	var station: float = fposmod(hint, _length) if _closed else hint
	var low: float = station - HINT_RADIUS_M
	var high: float = station + HINT_RADIUS_M
	if _closed and low < 0.0:
		_scan(point, 0, _upper_bound(high), best)
		_scan(point, _lower_bound(low + _length), _starts.size(), best)
	elif _closed and high >= _length:
		_scan(point, 0, _upper_bound(high - _length), best)
		_scan(point, _lower_bound(low), _starts.size(), best)
	else:
		_scan(point, _lower_bound(low), _upper_bound(high), best)

func _scan(point: Vector3, first: int, end: int, best: Array[float]) -> void:
	last_candidate_count += end - first
	for index: int in range(first, end):
		var offset: Vector3 = point - _starts[index]
		var fraction: float = clampf(offset.dot(_edges[index]) / _squared[index], 0.0, 1.0) if _squared[index] > 0.0 else 0.0
		var error: float = point.distance_squared_to(_starts[index] + _edges[index] * fraction)
		if error < best[0]:
			best[0] = error
			best[1] = _stations[index] + _lengths[index] * fraction

func _lower_bound(value: float) -> int:
	var low: int = 0
	var high: int = _stations.size()
	while low < high:
		var middle: int = (low + high) / 2
		if _stations[middle] < value:
			low = middle + 1
		else:
			high = middle
	return low

func _upper_bound(value: float) -> int:
	var low: int = 0
	var high: int = _stations.size()
	while low < high:
		var middle: int = (low + high) / 2
		if _stations[middle] <= value:
			low = middle + 1
		else:
			high = middle
	return low
