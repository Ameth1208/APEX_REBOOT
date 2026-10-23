extends SceneTree
## Small real-time/progress fixtures; no models, physics worlds or speed estimates.

const Intervals = preload("res://scripts/ui/hud/intervals.gd")
var checks: int = 0
var failures: Array[String] = []

class TrackFixture extends Node3D:
	var closed: bool = true
	func get_length() -> float:
		return 500.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := ApexRaceSession.new()
	# start() normally parents this constructor-created MeshInstance3D. This
	# fixture skips start(), so it must give the node the same lifetime owner.
	session.add_child(session.line)
	session.track = TrackFixture.new()
	session.add_child(session.track)
	session.countdown = 0.0
	for index: int in 2:
		session.laps.append(ApexLapTracker.new())
		session.retired.append(false)
	var gaps := Intervals.new()
	_ahead(gaps, session)
	_check(gaps.text_for(session, 1) == "-1.000", "Ahead gap comes from the other driver's recorded crossing")
	_check(gaps.text_for(session, 0) == "—", "Player row does not invent a self interval")
	gaps.clear()
	_sample(gaps, session, 1.0, [20.0, 10.0])
	_sample(gaps, session, 2.0, [30.0, 20.0])
	_sample(gaps, session, 3.0, [40.0, 30.0])
	_check(gaps.text_for(session, 1) == "+1.000", "Behind gap uses the player's earlier crossing")
	gaps.clear()
	_sample(gaps, session, 1.0, [10.0, 20.0])
	_check(gaps.text_for(session, 1) == "—", "One sample cannot fabricate a crossing time")
	_sample(gaps, session, 2.0, [15.0, 30.0])
	_check(gaps.text_for(session, 1) == "—", "Outside recorded distance coverage remains unavailable")
	gaps.clear()
	_sample(gaps, session, 1.0, [10.0, 15.0])
	_sample(gaps, session, 2.0, [20.0, 30.0])
	_check(gaps.text_for(session, 1) == "-0.667", "Crossing between samples is linearly interpolated")
	_check(gaps.text_for(session, -1) == "—" and gaps.text_for(session, 5) == "—", "Out-of-range drivers remain unavailable")
	_ahead(gaps, session)
	gaps.clear()
	_check(gaps.text_for(session, 1) == "—", "Explicit reset drops all old crossing data immediately")
	_sample(gaps, session, 4.0, [40.0, 50.0])
	_check(gaps.text_for(session, 1) == "—", "First point after reset is not a time interval")
	_ahead(gaps, session)
	session.laps[0].valid = false
	_sample(gaps, session, 4.0, [40.0, 50.0])
	_check(gaps.text_for(session, 1) == "—", "An invalidation removes comparisons across the invalidating event")
	_sample(gaps, session, 5.0, [50.0, 60.0])
	_sample(gaps, session, 6.0, [60.0, 70.0])
	_check(gaps.text_for(session, 1) == "-1.000", "An already invalid attempt can accumulate new real crossings")
	session.laps[0].valid = true
	_ahead(gaps, session)
	_sample(gaps, session, 3.1, [31.0, 400.0])
	_check(gaps.text_for(session, 1) == "—", "A nonphysical forward jump cannot reuse a previous interval")
	_ahead(gaps, session)
	_sample(gaps, session, 3.1, [28.0, 41.0])
	_check(gaps.text_for(session, 1) == "—", "Reversing discards the non-monotonic crossing history")
	_ahead(gaps, session)
	session.retired[1] = true
	_check(gaps.text_for(session, 1) == "DNF", "Retirement is a race status, not a numeric interval")
	session.retired[1] = false
	session.laps[0].finished = true
	session.laps[1].finished = true
	session.laps[0].elapsed = 90.75
	session.laps[1].elapsed = 92.0
	gaps.clear()
	_check(gaps.text_for(session, 1) == "+1.250", "Both finished uses actual total finishing times even without history")
	session.laps[1].elapsed = 89.5
	_check(gaps.text_for(session, 1) == "-1.250", "Earlier finisher stays ahead relative to the player")
	session.laps[0].finished = false
	session.laps[1].finished = false
	gaps.clear()
	_sample(gaps, session, 1.0, [0.0, 10.0])
	_sample(gaps, session, 2.0, [10.0, 20.0])
	_sample(gaps, session, 3.0, [20.0, 20.0])
	_sample(gaps, session, 15.0, [20.0, 20.0])
	_check(gaps.text_for(session, 1) == "0.000", "Cars stopped alongside do not acquire a false growing gap")
	gaps.clear()
	_sample(gaps, session, 1.0, [20.0, 20.0])
	_sample(gaps, session, 30.0, [20.0, 20.0])
	_check(gaps.text_for(session, 1) == "—", "Stationary from the start is unknown without crossing samples")
	gaps.clear()
	for sample_index: int in 1200:
		var progress: float = float(sample_index + 1)
		_sample(gaps, session, progress * 0.1, [progress, progress + 5.0])
	_check(gaps._history[0].size() <= Intervals.MAX_SAMPLES and gaps._history[1].size() <= Intervals.MAX_SAMPLES, "Sample history remains bounded")
	_check(session.laps[0].elapsed - float(gaps._history[0].front().y) < 90.3, "Old crossing history is pruned by elapsed time")
	session.countdown = 2.0
	_check(gaps.text_for(session, 1) == "—", "Starting grid does not display running intervals")
	session.free()
	print("HUD_INTERVALS_CHECKS ", "PASS" if failures.is_empty() else "FAIL", " ", checks, " ", failures)
	quit(0 if failures.is_empty() else 1)

func _ahead(gaps: RefCounted, session: ApexRaceSession) -> void:
	gaps.clear()
	_sample(gaps, session, 1.0, [10.0, 20.0])
	_sample(gaps, session, 2.0, [20.0, 30.0])
	_sample(gaps, session, 3.0, [30.0, 40.0])

func _sample(gaps: RefCounted, session: ApexRaceSession, time: float, progress: Array[float]) -> void:
	for index: int in progress.size():
		session.laps[index].elapsed = time
		session.laps[index].progress = progress[index]
	gaps.update_session(session, 0.1)

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)
