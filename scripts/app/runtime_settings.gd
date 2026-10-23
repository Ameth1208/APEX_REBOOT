class_name ApexRuntimeSettings
extends RefCounted

static func apply(race: ApexRaceSession, values: Dictionary) -> void:
	for key: String in ["wetness", "aero", "grip", "assists", "automatic", "racing_line", "night", "ai_difficulty", "steering_response", "steering_curve", "pedal_curve"]:
		if values.has(key): race.settings[key] = values[key]
	race.configure_player_input(values)
	for body in race.vehicles:
		body.wetness = float(values.wetness)
		body.aero_scale = float(values.aero)
		body.grip_factor = float(body.profile.get("tire_grip_scale", 1.0)) * float(values.grip)
	race.player.set_assist_mode(str(values.assists))
	race.player.auto_transmission = bool(values.automatic)
	race.line.visible = bool(values.racing_line)
	race.set_lights(bool(values.night))
	race.configure_ai(values)
