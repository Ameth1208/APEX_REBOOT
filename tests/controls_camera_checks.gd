extends SceneTree
## Exercise real InputMap/Input events, saved preferences and camera transforms.
var checks: int = 0
var failures: Array[String] = []

class InputVehicle:
	extends RigidBody3D
	var command: Vector4 = Vector4.ZERO
	var speed_kph: float = 0.0
	var is_motorcycle: bool = true
	var lean_angle: float = 0.0
	var ride_height: float = 0.61
	var profile: Dictionary = {"cockpit_camera_ground": [0.0, 1.3, 0.1]}
	func set_controls(t: float, b: float, s: float, h: float = 0.0) -> void:
		command = Vector4(t, b, s, h)
	func shift_up() -> void: pass
	func shift_down() -> void: pass
	func telemetry() -> Dictionary:
		return {"surface": "asphalt", "grounded_wheels": 2}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	ApexInput.install()
	var original_count: int = InputMap.action_get_events("accelerate").size()
	ApexInput.install()
	_check(InputMap.action_get_events("accelerate").size() == original_count, "Repeated setup does not duplicate events")
	_check(not ApexBindings.conflict("accelerate", KEY_S).is_empty(), "Reject a key used to brake")
	_check(not ApexBindings.conflict("accelerate", KEY_ESCAPE).is_empty(), "Protect pause shortcut")
	_check(not ApexBindings.conflict("accelerate", KEY_SHIFT).is_empty(), "Reject bare modifier")
	_check(ApexBindings.conflict("accelerate", KEY_I).is_empty(), "Accept unused physical key")
	var preferences := ApexSettings.new()
	preferences.values.key_bindings = {"accelerate": KEY_I, "reset_car": KEY_T}
	preferences.values.steering_deadzone = 0.22
	preferences.values.pedal_deadzone = 0.07
	preferences.values.camera_fov = 78.0
	preferences.values.camera_bank = 0.35
	preferences.values.pedal_curve = 2.0
	preferences.save_preferences("user://qa-controls.cfg")
	var restored := ApexSettings.new()
	restored.load_preferences("user://qa-controls.cfg")
	_check(restored.values == preferences.values, "Settings round-trip preserves bindings, curves and camera")
	ApexInput.apply_preferences(restored.values)
	_check(is_equal_approx(InputMap.action_get_deadzone("steer_right"), 0.22), "Steering deadzone reaches InputMap")
	_check(is_equal_approx(InputMap.action_get_deadzone("brake"), 0.07), "Pedal deadzone reaches InputMap")
	var axis_count: int = 0
	for event: InputEvent in InputMap.action_get_events("accelerate"):
		if event is InputEventJoypadMotion: axis_count += 1
	_check(axis_count == 1, "Remapping preserves the analog trigger exactly once")
	_key(KEY_W, true)
	_check(not Input.is_action_pressed("accelerate"), "Old key no longer accelerates")
	_key(KEY_W, false)
	_key(KEY_I, true)
	_check(Input.is_action_pressed("accelerate"), "New physical key activates throttle")
	_key(KEY_I, false)
	var body := InputVehicle.new()
	body.freeze = true
	root.add_child(body)
	var controls := ApexPlayerInput.new()
	controls.configure({"steering_response": 2.0, "steering_curve": 2.0, "pedal_curve": 2.0})
	Input.action_press("accelerate", 0.5)
	Input.action_press("brake", 0.25)
	Input.action_press("steer_right", 0.5)
	Input.action_press("handbrake", 0.7)
	controls.apply(body, 1.0)
	_check(absf(body.command.x - 0.25) < 0.001, "50% analog throttle produces 25% with squared curve")
	_check(absf(body.command.y - 0.0625) < 0.001, "Brake analog curve applied independently")
	_check(absf(body.command.z - 0.25) < 0.001, "Steering curve reaches vehicle command")
	_check(absf(body.command.w - 0.7) < 0.001, "Rear brake independent of main brake curve")
	for action: String in ["accelerate", "brake", "steer_right", "handbrake"]:
		Input.action_release(action)
	controls.steering = 0.0
	Input.action_press("steer_right", 1.0)
	controls.apply(body, 0.01)
	_check(absf(body.command.z - 0.04) < 0.001, "Steering response limits rate of actual command")
	Input.action_release("steer_right")
	var values: Dictionary = preferences.values.duplicate(true)
	values.vehicle = 0
	values.paint = ApexCatalog.PAINT_NAMES[2]
	values.livery = "Original"
	ApexVehiclePreferences.remember(values)
	values.vehicle = 1
	ApexVehiclePreferences.restore(values)
	_check(values.paint == "Original" and values.livery == "Original", "New vehicle begins with its original appearance")
	values.paint = ApexCatalog.PAINT_NAMES[4]
	ApexVehiclePreferences.remember(values)
	values.vehicle = 0
	ApexVehiclePreferences.restore(values)
	_check(values.paint == ApexCatalog.PAINT_NAMES[2], "Switching back restores the car's own paint")
	body.lean_angle = deg_to_rad(30.0)
	body.position.y = body.ride_height
	var camera := ApexCamera.new()
	root.add_child(camera)
	camera.set_process(false)
	camera.mode = 2
	camera.configure({"camera_bank": 0.0, "camera_fov": 80.0, "camera_motion": 0.0})
	camera.follow(body, false)
	var before: Transform3D = body.global_transform
	camera._process(1.0)
	_check(absf(_roll(camera.camera.global_basis)) < 0.01, "Zero bank preference holds horizon level")
	_check(absf(camera.camera.fov - 80.0) < 0.01, "Chosen base FOV reaches Camera3D")
	camera.configure({"camera_bank": 1.0, "camera_fov": 80.0, "camera_motion": 0.0})
	camera.follow(body, false)
	camera._process(1.0)
	_check(absf(_roll(camera.camera.global_basis) - 30.0) < 0.1, "Full bank follows the bike lean")
	_check(body.global_transform.is_equal_approx(before) and body.lean_angle == deg_to_rad(30.0), "Camera preferences leave physical body and lean untouched")
	var motion := ApexCameraMotion.new()
	_check(motion.sample(body, Basis.IDENTITY, 2, 0.016, 0.0) == Vector3.ZERO, "Motion intensity zero produces no offset")
	camera.queue_free()
	body.queue_free()
	DirAccess.remove_absolute("user://qa-controls.cfg")
	ApexInput.install()
	await process_frame
	print("CONTROLS_CAMERA_CHECKS ", "PASS" if failures.is_empty() else "FAIL", " ", checks, " ", failures)
	quit(0 if failures.is_empty() else 1)

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _roll(basis: Basis) -> float:
	return rad_to_deg(atan2(basis.y.x, basis.y.y))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
