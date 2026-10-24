class_name ApexInput
extends RefCounted

static func install(bindings: Dictionary = {}) -> void:
	var keys: Dictionary = {
		"accelerate": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT], "steer_right": [KEY_D, KEY_RIGHT],
		"handbrake": [KEY_SPACE], "reverse": [KEY_V], "shift_up": [KEY_E],
		"shift_down": [KEY_Q], "reset_car": [KEY_R], "camera_next": [KEY_C],
		"pause_game": [KEY_ESCAPE], "toggle_lights": [KEY_L], "toggle_night": [KEY_N],
		"editor": [KEY_F2], "telemetry": [KEY_F3], "autopilot": [KEY_F4],
		"racing_line": [KEY_F5], "physics_debug": [KEY_F7],
		"photo": [KEY_F6], "performance_report": [KEY_F8], "screenshot": [KEY_F12]
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.12)
		InputMap.action_erase_events(action)
		var codes: Array = [int(bindings[action])] if bindings.has(action) else keys[action]
		for key in codes:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	_axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("steer_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("accelerate", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	var buttons: Dictionary = {"handbrake": JOY_BUTTON_A, "camera_next": JOY_BUTTON_Y,
		"shift_down": JOY_BUTTON_X, "shift_up": JOY_BUTTON_B, "pause_game": JOY_BUTTON_START,
		"reset_car": JOY_BUTTON_BACK, "reverse": JOY_BUTTON_LEFT_SHOULDER}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		InputMap.action_add_event(action, event)
	ApexBindings.invalidate()

static func apply_preferences(values: Dictionary) -> void:
	install(values.get("key_bindings", {}))
	for action: String in ["steer_left", "steer_right"]:
		InputMap.action_set_deadzone(action, clampf(float(values.get("steering_deadzone", 0.12)), 0.0, 0.4))
	for action: String in ["accelerate", "brake"]:
		InputMap.action_set_deadzone(action, clampf(float(values.get("pedal_deadzone", 0.03)), 0.0, 0.3))

static func _axis(action: String, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)
