extends SceneTree
## Stage timing must never wrap, accept a reset as a finish, or reward missing gates.

var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var valid: ApexLapTracker = _tracker()
	_advance(valid, 0, 1190)
	_check(not valid.finished, "stage does not finish before the end")
	valid.tick(0.1, 1199.4, 0.0, 12.0, 5)
	_check(not valid.finished, "finish tolerance is bounded to half a metre")
	valid.tick(0.1, 1199.6, 0.0, 12.0, 5)
	_check(valid.finished and valid.completed_laps == 1 and valid.valid_laps == 1, "one valid stage finishes even when options request five laps")
	_check(valid.lap == 1 and is_equal_approx(valid.progress, 1200.0), "stage progress never doubles the route length")
	var finish_time: float = valid.elapsed
	valid.tick(1.0, 0.0, 0.0, 12.0, 5)
	_check(is_equal_approx(valid.elapsed, finish_time) and valid.completed_laps == 1, "finished stage freezes timing")

	var reset: ApexLapTracker = _tracker()
	_advance(reset, 0, 1190)
	reset.notify_reset(1190.0)
	reset.tick(0.1, 1200.0, 0.0, 12.0, 1)
	_check(not reset.finished and reset.completed_laps == 0 and reset.best == 0.0, "reset before finish cannot collect a stage")
	_explicit_recovery_checks()

	var skipped: ApexLapTracker = _tracker()
	_advance(skipped, 0, 90)
	skipped.tick(0.1, 310.0, 0.0, 12.0, 1)
	_advance(skipped, 310, 1200)
	_check(not skipped.finished and skipped.best == 0.0, "teleport across gates cannot finish a stage")

	var cut: ApexLapTracker = _tracker()
	_advance(cut, 0, 300, 20.0)
	_advance(cut, 300, 1200)
	_check(cut.finished and cut.invalid_laps == 1 and cut.valid_laps == 0 and cut.best == 0.0, "off-road full stage records only an invalid result")

	var reverse: ApexLapTracker = _tracker()
	_advance(reverse, 0, 300)
	for d: int in range(290, -1, -10):
		reverse.tick(0.1, float(d), 0.0, 12.0, 1)
	_advance(reverse, 0, 1200)
	_check(reverse.finished and reverse.invalid_laps == 1 and reverse.best == 0.0, "reverse traversal cannot restore stage validity")

	var grid: ApexLapTracker = _tracker(120.0, 26.0)
	for d: int in range(30, 121, 10):
		grid.tick(0.1, float(d), 0.0, 12.0, 1)
	_check(grid.finished and grid.valid_laps == 1, "legitimate grid rows may begin beyond the first short-stage gate")
	var end_spawn: ApexLapTracker = _tracker(1200.0, 1190.0)
	end_spawn.tick(0.1, 1200.0, 0.0, 12.0, 1)
	_check(not end_spawn.finished, "initial position near finish does not pre-award all gates")
	var clamped: ApexLapTracker = _tracker()
	clamped.tick(0.1, -20.0, 0.0, 12.0, 1)
	_check(clamped.distance == 0.0 and clamped.progress == 0.0, "negative stage progress does not wrap")
	clamped.notify_reset(1400.0)
	_check(clamped.distance == 1200.0 and not clamped.finished, "end overflow clamps without finishing by reset")
	clamped.setup(1200.0)
	_check(clamped.closed and clamped.best == 0.0 and not clamped.finished, "default setup remains a fresh closed circuit")
	print("OPEN_ROUTE_RULES_CHECKS ", "PASS" if _failures == 0 else "FAIL: " + str(_failures))
	quit(0 if _failures == 0 else 1)

func _explicit_recovery_checks() -> void:
	var recovered: ApexLapTracker = _tracker()
	_advance(recovered, 0, 1190)
	recovered.notify_recovery(1200.0, "Etapa invalidada")
	_check(recovered.distance == 1190.0 and recovered.progress == 1190.0 and not recovered.valid, "explicit recovery cannot advance position or progress")
	recovered.tick(0.1, 1200.0, 0.0, 12.0, 1)
	_check(recovered.finished and recovered.invalid_laps == 1 and recovered.valid_laps == 0 and recovered.best == 0.0, "visited gates allow only an invalid stage finish after explicit recovery")
	var unvisited: ApexLapTracker = _tracker(1200.0, 1190.0)
	unvisited.notify_recovery(1200.0, "Etapa invalidada")
	unvisited.tick(0.1, 1200.0, 0.0, 12.0, 1)
	_check(not unvisited.finished and unvisited.completed_laps == 0, "explicit recovery never awards unvisited gates")
	var career := ApexCareer.new()
	career.record(0, {"position": 1, "best": recovered.best, "laps": 1, "valid_laps": recovered.valid_laps, "invalid_laps": recovered.invalid_laps})
	_check(career.credits == 0 and career.unlocked == 0 and career.records.is_empty(), "an invalid recovered stage grants no points, medals or unlocks")

func _tracker(length: float = 1200.0, initial: float = 0.0) -> ApexLapTracker:
	var result: ApexLapTracker = ApexLapTracker.new()
	result.setup(length, initial, false)
	return result

func _advance(tracker: ApexLapTracker, from_distance: int, to_distance: int, error: float = 0.0) -> void:
	for d: int in range(from_distance + 10, to_distance + 1, 10):
		tracker.tick(0.1, float(d), error, 12.0, 5)

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)
