extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_valid_lap_and_finish()
	_sectors_cannot_be_skipped()
	_reset_cannot_complete_lap()
	_teleport_cannot_complete_lap()
	_reverse_cannot_complete_lap()
	_cut_lap_does_not_set_best()
	_invalid_then_clean_lap()
	_setup_resets_a_reused_tracker()
	print("RACE_RULES_CHECKS ", "PASS" if _failures == 0 else "FAIL: " + str(_failures))
	quit(0 if _failures == 0 else 1)

func _new() -> ApexLapTracker:
	var tracker: ApexLapTracker = ApexLapTracker.new()
	tracker.setup(1200.0)
	return tracker

func _advance(tracker: ApexLapTracker, from_distance: int, to_distance: int, road_error: float = 0.0, total: int = 2) -> void:
	for d: int in range(from_distance + 10, to_distance + 1, 10):
		tracker.tick(0.1, float(d % 1200), road_error, 12.0, total)

func _valid_lap_and_finish() -> void:
	var tracker: ApexLapTracker = _new()
	_advance(tracker, 0, 1200, 0.0, 1)
	_check(tracker.completed_laps == 1 and tracker.valid_laps == 1, "all ordered gates produce a valid completed lap")
	_check(tracker.invalid_laps == 0 and tracker.last_lap_valid, "clean lap validity accounting")
	_check(tracker.finished and tracker.best > 0.0, "clean race finishes and records a time")
	_check(is_equal_approx(tracker.progress, 1200.0), "finish progress updates in the crossing tick")
	var elapsed: float = tracker.elapsed
	tracker.tick(1.0, 30.0, 0.0, 12.0, 1)
	_check(is_equal_approx(tracker.elapsed, elapsed), "finished timing is frozen")

func _sectors_cannot_be_skipped() -> void:
	var tracker: ApexLapTracker = _new()
	_advance(tracker, 0, 90)
	tracker.tick(0.1, 310.0, 0.0, 12.0, 1)
	_advance(tracker, 310, 1200, 0.0, 1)
	_check(tracker.completed_laps == 0 and not tracker.finished, "cutting directly across sectors cannot complete a lap")
	_check(tracker.best == 0.0, "a skipped sector cannot set best time")

func _reset_cannot_complete_lap() -> void:
	var tracker: ApexLapTracker = _new()
	_advance(tracker, 0, 1190)
	tracker.notify_reset(1190.0)
	tracker.tick(0.1, 0.0, 0.0, 12.0, 1)
	_check(tracker.completed_laps == 0 and tracker.best == 0.0, "reset before the finish clears previously collected gates")
	_check(not tracker.finished, "reset is not a race finish")
	_advance(tracker, 0, 1200, 0.0, 1)
	_check(tracker.finished and tracker.valid_laps == 1, "a complete clean lap after reset remains possible")

func _teleport_cannot_complete_lap() -> void:
	var tracker: ApexLapTracker = _new()
	_advance(tracker, 0, 1100)
	tracker.tick(0.01, 5.0, 0.0, 12.0, 1)
	_check(tracker.completed_laps == 0 and not tracker.valid, "teleport across the finish cannot award a lap")
	_check(not tracker.finished, "teleport does not finish the race")

func _reverse_cannot_complete_lap() -> void:
	var tracker: ApexLapTracker = _new()
	for d: int in range(1190, -1, -10):
		tracker.tick(0.1, float(d), 0.0, 12.0, 1)
	_check(tracker.completed_laps == 0 and not tracker.finished, "one complete reverse circuit cannot count")
	_check(not tracker.valid, "reverse running invalidates timing")
	tracker.tick(0.1, 10.0, 0.0, 12.0, 1)
	_check(tracker.completed_laps == 0, "reverse then forward at the line cannot fabricate a lap")

func _cut_lap_does_not_set_best() -> void:
	var tracker: ApexLapTracker = _new()
	_advance(tracker, 0, 300, 18.0, 1)
	_advance(tracker, 300, 1200, 0.0, 1)
	_check(tracker.completed_laps == 1 and tracker.invalid_laps == 1, "full route with sustained off-road running is tracked as invalid")
	_check(tracker.valid_laps == 0 and tracker.best == 0.0, "invalid lap cannot create a valid result or best")
	_check(not tracker.last_lap_valid, "last-lap validity persists after starting the next timer")

func _invalid_then_clean_lap() -> void:
	var tracker: ApexLapTracker = _new()
	_advance(tracker, 0, 1200, 20.0, 2)
	_advance(tracker, 0, 1200, 0.0, 2)
	_check(tracker.completed_laps == tracker.valid_laps + tracker.invalid_laps, "completed lap accounting stays consistent")
	_check(tracker.valid_laps == 1 and tracker.invalid_laps == 1 and tracker.best > 0.0, "clean subsequent lap records its own best")
	_check(tracker.finished, "mixed validity race still exposes a result for policy handling")

func _setup_resets_a_reused_tracker() -> void:
	var tracker: ApexLapTracker = _new()
	_advance(tracker, 0, 1200, 0.0, 1)
	tracker.setup(1800.0, 12.0)
	_check(tracker.completed_laps == 0 and tracker.valid_laps == 0 and tracker.invalid_laps == 0, "setup resets lap counts")
	_check(tracker.elapsed == 0.0 and tracker.best == 0.0 and not tracker.finished, "setup resets timer and finish state")
	_check(is_equal_approx(tracker.distance, 12.0), "setup uses the new grid location")

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)
