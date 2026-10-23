class_name ApexRaceClassification
extends RefCounted
## Finish order uses elapsed time on circuits and stages; DNF is explicit.

static func build(vehicles: Array, laps: Array, retired: Array[bool], reasons: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i: int in vehicles.size():
		var tracker: ApexLapTracker = laps[i]
		var abandoned: bool = i < retired.size() and retired[i]
		rows.append({"position": 0, "name": str(vehicles[i].name), "is_player": i == 0,
			"status": "Abandono" if abandoned else ("Finalizó" if tracker.finished else "En pista"),
			"retired": abandoned, "reason": reasons[i] if i < reasons.size() else "",
			"total": tracker.elapsed, "best": tracker.best, "completed_laps": tracker.completed_laps,
			"valid_laps": tracker.valid_laps, "progress": tracker.progress,
			"finished": tracker.finished, "index": i})
	rows.sort_custom(_ahead)
	for place: int in rows.size():
		rows[place]["position"] = place + 1
	return rows

static func _ahead(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.retired) != bool(b.retired):
		return not bool(a.retired)
	if bool(a.finished) and bool(b.finished):
		if not is_equal_approx(float(a.total), float(b.total)):
			return float(a.total) < float(b.total)
	elif bool(a.finished) != bool(b.finished):
		return bool(a.finished)
	elif not is_equal_approx(float(a.progress), float(b.progress)):
		return float(a.progress) > float(b.progress)
	return int(a.index) < int(b.index)
