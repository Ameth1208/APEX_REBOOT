extends SceneTree
## Regression for stale session position during countdown and between row updates.

const Fixture = preload("res://tools/fixtures/hud_session.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session: ApexRaceSession = Fixture.new()
	root.add_child(session)
	session.call("setup_fixture", true, "Carrera", true)
	session.countdown = 3.0
	session.position_in_race = 1
	for index: int in session.laps.size():
		session.laps[index].progress = index * 20.0
	var tower := ApexRaceTower.new()
	root.add_child(tower)
	tower.build(session)
	_check(tower.position_label.text == "6 / 6", "Countdown header uses grid classification, not initial session position")
	_check(tower.rows[5].is_player and tower.place_labels[5].text == "6", "Player row agrees with countdown header")
	session.countdown = 0.0
	session.laps[0].progress = 200.0
	tower.update_session(session, 0.25)
	_check(tower.position_label.text == "1 / 6" and tower.rows[0].is_player, "Header and rows update together after overtaking")
	session.laps[0].progress = 0.0
	session.position_in_race = 6
	tower.update_session(session, 0.05)
	_check(tower.position_label.text == "1 / 6" and tower.rows[0].is_player, "Header preserves the displayed row snapshot between refreshes")
	tower.update_session(session, 0.25)
	_check(tower.position_label.text == "6 / 6" and tower.rows[5].is_player, "Next refresh applies the changed order to both")
	tower.queue_free()
	session.queue_free()
	await process_frame
	await process_frame
	print("HUD_POSITION_CHECKS ", "PASS" if failures.is_empty() else "FAIL", " ", checks, " ", failures)
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)
