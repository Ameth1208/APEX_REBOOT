extends SceneTree

const LocalProjection = preload("res://scripts/geo/geo_projection.gd")
const Importer = preload("res://scripts/geo/route_importer.gd")
const Analyser = preload("res://scripts/geo/route_analyser.gd")

func _initialize() -> void:
	var origin: Dictionary = LocalProjection.make_origin(4.65, -74.1, 2500.0)
	var raw: Array[Dictionary] = []
	for i: int in range(20000):
		var point: Dictionary = LocalProjection.inverse(float(i) * 0.5, 0.0, origin, float(i) * 0.05)
		point["elevation_source"] = "synthetic"
		raw.append(point)
	var started: int = Time.get_ticks_msec()
	var imported: Dictionary = Importer.from_points(raw, "Límite sintético 20 000", "synthetic")
	if not imported["ok"]:
		push_error(str(imported["error"]))
		quit(1)
		return
	var analysed: Dictionary = Analyser.analyse(imported["definition"], 100.0)
	if not analysed["ok"] or not analysed["raw"]["ok"]:
		push_error("No se pudo analizar el límite de puntos admitido.")
		quit(1)
		return
	var passed: bool = imported["definition"]["raw_route"].size() == 20000 and analysed["raw_profile"].size() == 20000
	passed = passed and imported["definition"]["points"].size() <= 512
	passed = passed and absf(float(analysed["raw"]["max_uphill_pct"]) - 10.0) < 0.0001
	print("GEO_LIMITS_CHECKS ", "PASS" if passed else "FAIL", ": raw=", analysed["raw_profile"].size(),
		" controls=", imported["definition"]["points"].size(), " grade=", analysed["raw"]["max_uphill_pct"],
		" duration_ms=", Time.get_ticks_msec() - started)
	quit(0 if passed else 1)
