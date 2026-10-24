class_name ApexRuntimeSettings
extends RefCounted

static func apply(race: ApexRaceSession, values: Dictionary) -> void:
	for key: String in ["wetness", "aero", "grip", "assists", "automatic", "racing_line", "night", "ai_difficulty", "steering_response", "steering_curve", "pedal_curve", "wheel_device", "wheel_steering_axis", "wheel_throttle_axis", "wheel_brake_axis", "wheel_invert_steering", "wheel_steering_min", "wheel_steering_center", "wheel_steering_max", "wheel_throttle_min", "wheel_throttle_max", "wheel_brake_min", "wheel_brake_max"]:
		if values.has(key): race.settings[key] = values[key]
	race.configure_player_input(values)
	for body in race.vehicles:
		body.wetness = float(values.wetness)
		body.aero_scale = float(values.aero)
		body.grip_factor = float(body.profile.get("tire_grip_scale", 1.0)) * float(values.grip)
	race.player.set_assist_mode(str(values.assists))
	race.player.auto_transmission = bool(values.automatic)
	race.line.visible = bool(values.racing_line)
	var app := race.get_parent()
	if app != null and app.has_method("set_racing_line_visible"):
		app.set_racing_line_visible(bool(values.racing_line))
	race.set_lights(bool(values.night))
	race.configure_ai(values)
