class_name ApexCareer
extends RefCounted

const EVENTS := [
	{"name": "01 · Escuela GT", "subtitle": "Costa Clara · Porsche · 2 vueltas", "vehicle": 0, "track": 0, "laps": 2, "night": false, "opponents": 2},
	{"name": "02 · Equilibrio", "subtitle": "Laguna Técnica · Yamaha · 2 vueltas", "vehicle": 1, "track": 2, "laps": 2, "night": false, "opponents": 2},
	{"name": "03 · Herencia", "subtitle": "Sierra Alta · Ferrari · 3 vueltas", "vehicle": 2, "track": 1, "laps": 3, "night": false, "opponents": 3},
	{"name": "04 · La última luz", "subtitle": "Costa Clara · Fórmula 1991 · 3 vueltas", "vehicle": 3, "track": 0, "laps": 3, "night": true, "opponents": 4}
]
var unlocked: int = 0
var credits: int = 0
var records: Dictionary = {}

func load_progress() -> void:
	if not FileAccess.file_exists("user://career.json"):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://career.json"))
	if data is Dictionary:
		unlocked = clampi(int(data.get("unlocked", 0)), 0, EVENTS.size() - 1)
		credits = int(data.get("credits", 0))
		records = data.get("records", {})

func record(event_index: int, result: Dictionary) -> String:
	if bool(result.get("retired", false)):
		return "Retirada · sin progreso de campeonato"
	if bool(result.get("autopilot", false)):
		return "Exhibición de IA · sin progreso de campeonato"
	if int(result.get("invalid_laps", 0)) > 0 or int(result.get("valid_laps", 0)) < int(result.get("laps", 1)):
		return "Completa todas las vueltas dentro de pista para avanzar."
	var place: int = int(result.position)
	var medal: String = "Oro" if place == 1 else ("Plata" if place == 2 else "Bronce")
	var reward: int = maxi(100, 500 - (place - 1) * 100)
	credits += reward
	unlocked = maxi(unlocked, mini(EVENTS.size() - 1, event_index + 1))
	records[str(event_index)] = {"medal": medal, "position": place, "best": result.best}
	var file := FileAccess.open("user://career.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"unlocked": unlocked, "credits": credits, "records": records}, "\t"))
	return "%s · +%d puntos · progreso guardado" % [medal, reward]
