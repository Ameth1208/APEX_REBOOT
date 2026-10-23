class_name ApexHudIntervals
extends RefCounted
## Relative gaps use recorded times at the same race distance, never speed estimates.

const SAMPLE_PERIOD: float = 0.10
const HISTORY_SECONDS: float = 90.0
const MAX_SAMPLES: int = 920
var _history: Array = []
var _valid: Array[bool] = []
var _until_sample: float = 0.0

func update_session(session: ApexRaceSession, delta: float) -> void:
	if _history.size() != session.laps.size():
		clear(session.laps.size())
	if session.countdown > 0.0:
		return
	_until_sample -= delta
	if _until_sample > 0.0:
		return
	_until_sample = SAMPLE_PERIOD
	var invalidated: bool = false
	for index: int in session.laps.size():
		invalidated = invalidated or (not session.laps[index].valid and _valid[index])
	if invalidated:
		for points: Array in _history:
			points.clear()
	for index: int in session.laps.size():
		var lap: ApexLapTracker = session.laps[index]
		var points: Array = _history[index]
		_valid[index] = lap.valid
		var sample := Vector2(lap.progress, lap.elapsed)
		if not points.is_empty():
			var previous: Vector2 = points.back()
			var elapsed: float = sample.y - previous.y
			var travelled: float = sample.x - previous.x
			if elapsed < 0.0 or travelled < -0.25 or travelled > maxf(6.0, elapsed * 180.0 + 4.0):
				points.clear()
			elif travelled < 0.01:
				continue
		points.append(sample)
		while points.size() > MAX_SAMPLES or (points.size() > 2 and float(points[1].y) < lap.elapsed - HISTORY_SECONDS):
			points.pop_front()

func clear(count: int = 0) -> void:
	_history.clear()
	_valid.clear()
	_until_sample = 0.0
	for index: int in count:
		_history.append([])
		_valid.append(true)

func text_for(session: ApexRaceSession, index: int) -> String:
	if index < 0 or index >= session.laps.size():
		return "—"
	if session.retired[index]:
		return "DNF"
	if index == 0:
		return "—"
	var player: ApexLapTracker = session.laps[0]
	var other: ApexLapTracker = session.laps[index]
	if session.countdown > 0.0 or player.elapsed <= 0.0:
		return "—"
	if player.finished and other.finished:
		return "%+.3f" % (other.elapsed - player.elapsed)
	var difference: float = other.progress - player.progress
	var length: float = session.track.get_length()
	if session.track.closed and absf(difference) >= length:
		return "%s%d V" % ["−" if difference > 0.0 else "+", floori(absf(difference) / length)]
	if index >= _history.size() or _history[0].size() < 2 or _history[index].size() < 2:
		return "—"
	# At equal progress both drivers are alongside now. An old arrival sample
	# while stopped must not create a growing, fictitious negative time gap.
	if absf(difference) < 0.05:
		return "0.000"
	var crossing: float = _time_at(index if difference >= 0.0 else 0, player.progress if difference >= 0.0 else other.progress)
	if not is_finite(crossing):
		return "—"
	var gap: float = crossing - player.elapsed if difference >= 0.0 else other.elapsed - crossing
	return "%+.3f" % gap

func _time_at(index: int, distance: float) -> float:
	var points: Array = _history[index]
	if points.size() < 2 or distance < float(points.front().x) or distance > float(points.back().x):
		return NAN
	var left: int = 0
	var right: int = points.size() - 1
	while right - left > 1:
		var middle: int = (left + right) / 2
		if float(points[middle].x) <= distance:
			left = middle
		else:
			right = middle
	var a: Vector2 = points[left]
	var b: Vector2 = points[right]
	return lerpf(a.y, b.y, clampf((distance - a.x) / maxf(0.001, b.x - a.x), 0.0, 1.0))
