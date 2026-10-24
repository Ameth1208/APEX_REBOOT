class_name ApexSettings
extends RefCounted
## All user preferences are stored outside the installation directory.

var values: Dictionary = {
	"vehicle": 0, "track": 0, "mode": "Contrarreloj", "opponents": 3,
	"laps": 3, "assists": "Sport", "automatic": true, "night": false,
	"wetness": 0.0, "racing_line": false, "volume": 0.55,
	"aero": 1.0, "grip": 1.0, "camera": 0, "quality": "Automático",
	"paint": "Original", "livery": "Original", "fullscreen": false,
	"render_vegetation": true, "render_buildings": true, "render_water": true,
	"render_lamps": true, "render_props": true, "render_shadows": true, "render_fog": true,
	"ai_difficulty": "Normal", "camera_fov": 65.0, "camera_bank": 1.0,
	"camera_motion": 0.55, "steering_response": 1.0, "steering_curve": 1.2,
	"pedal_curve": 1.0, "steering_deadzone": 0.12, "pedal_deadzone": 0.03,
	"wheel_device": -1, "wheel_steering_axis": 0, "wheel_throttle_axis": 5,
	"wheel_brake_axis": 4, "wheel_invert_steering": false,
	"wheel_steering_min": -1.0, "wheel_steering_center": 0.0, "wheel_steering_max": 1.0,
	"wheel_throttle_min": -1.0, "wheel_throttle_max": 1.0,
	"wheel_brake_min": -1.0, "wheel_brake_max": 1.0,
	"key_bindings": {}, "vehicle_looks": {},
	"hud_minimap": true, "hud_standings": true, "hud_timing": true, "hud_cluster_scale": 1.0
}

func load_preferences(path: String = "user://settings.cfg") -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for key in values:
		values[key] = config.get_value("preferences", key, values[key])
	values["vehicle"] = clampi(int(values["vehicle"]), 0, maxi(0, ApexCatalog.entries("vehicles").size() - 1))
	values["track"] = clampi(int(values["track"]), 0, maxi(0, ApexCatalog.entries("tracks").size() - 1))
	values["opponents"] = clampi(int(values["opponents"]), 0, 5)
	values["laps"] = clampi(int(values["laps"]), 1, 10)
	if str(values["quality"]) not in ["Automático", "Rendimiento", "Equilibrado", "Alto"]:
		values["quality"] = "Automático"
	for key: String in ["camera_fov", "camera_bank", "camera_motion", "steering_response", "steering_curve", "pedal_curve", "steering_deadzone", "pedal_deadzone"]:
		if not is_finite(float(values[key])):
			values[key] = 65.0 if key == "camera_fov" else 1.0
	for key: String in ["wheel_steering_min", "wheel_steering_center", "wheel_steering_max", "wheel_throttle_min", "wheel_throttle_max", "wheel_brake_min", "wheel_brake_max"]:
		if not is_finite(float(values[key])):
			values[key] = 0.0 if key == "wheel_steering_center" else (-1.0 if key.ends_with("_min") else 1.0)
	for prefix: String in ["wheel_steering", "wheel_throttle", "wheel_brake"]:
		var minimum: float = float(values[prefix + "_min"])
		var maximum: float = float(values[prefix + "_max"])
		if maximum - minimum < 0.01:
			values[prefix + "_min"] = -1.0
			values[prefix + "_max"] = 1.0
	if values["wheel_steering_center"] < values["wheel_steering_min"] or values["wheel_steering_center"] > values["wheel_steering_max"]:
		values["wheel_steering_center"] = 0.0
	if not values.key_bindings is Dictionary:
		values.key_bindings = {}
	if not values.vehicle_looks is Dictionary:
		values.vehicle_looks = {}

func save_preferences(path: String = "user://settings.cfg") -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value("preferences", key, values[key])
	config.save(path)

func apply_display(update_quality: bool = true) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	var viewport := Engine.get_main_loop().root as Window
	if update_quality:
		preload("res://scripts/app/render_quality.gd").apply_viewport(viewport, str(values["quality"]))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, float(values["volume"]))))
