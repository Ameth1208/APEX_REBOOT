class_name ApexPlayerInput
extends RefCounted

var steering: float = 0.0
var response: float = 1.0
var steering_curve: float = 1.2
var pedal_curve: float = 1.0
var steering_deadzone: float = 0.12
var pedal_deadzone: float = 0.03
var wheel_device: int = -1
var wheel_steering_axis: int = 0
var wheel_throttle_axis: int = 5
var wheel_brake_axis: int = 4
var wheel_invert_steering: bool = false
var wheel_steering_min: float = -1.0
var wheel_steering_center: float = 0.0
var wheel_steering_max: float = 1.0
var wheel_throttle_min: float = -1.0
var wheel_throttle_max: float = 1.0
var wheel_brake_min: float = -1.0
var wheel_brake_max: float = 1.0
var _resolved_wheel_device: int = -2
var _wheel_probe_timer: float = 0.0

func configure(values: Dictionary) -> void:
	response = clampf(float(values.get("steering_response", 1.0)), 0.4, 2.5)
	steering_curve = clampf(float(values.get("steering_curve", 1.2)), 0.6, 2.5)
	pedal_curve = clampf(float(values.get("pedal_curve", 1.0)), 0.5, 2.5)
	steering_deadzone = clampf(float(values.get("steering_deadzone", 0.12)), 0.0, 0.4)
	pedal_deadzone = clampf(float(values.get("pedal_deadzone", 0.03)), 0.0, 0.3)
	wheel_device = int(values.get("wheel_device", -1))
	wheel_steering_axis = clampi(int(values.get("wheel_steering_axis", 0)), 0, 15)
	wheel_throttle_axis = clampi(int(values.get("wheel_throttle_axis", 5)), 0, 15)
	wheel_brake_axis = clampi(int(values.get("wheel_brake_axis", 4)), 0, 15)
	wheel_invert_steering = bool(values.get("wheel_invert_steering", false))
	wheel_steering_min = float(values.get("wheel_steering_min", -1.0))
	wheel_steering_center = float(values.get("wheel_steering_center", 0.0))
	wheel_steering_max = float(values.get("wheel_steering_max", 1.0))
	wheel_throttle_min = float(values.get("wheel_throttle_min", -1.0))
	wheel_throttle_max = float(values.get("wheel_throttle_max", 1.0))
	wheel_brake_min = float(values.get("wheel_brake_min", -1.0))
	wheel_brake_max = float(values.get("wheel_brake_max", 1.0))
	if not is_finite(wheel_steering_min) or not is_finite(wheel_steering_center) or not is_finite(wheel_steering_max) or wheel_steering_max - wheel_steering_min < 0.01:
		wheel_steering_min = -1.0
		wheel_steering_center = 0.0
		wheel_steering_max = 1.0
	wheel_steering_center = clampf(wheel_steering_center, wheel_steering_min, wheel_steering_max)
	if not is_finite(wheel_throttle_min) or not is_finite(wheel_throttle_max) or wheel_throttle_max - wheel_throttle_min < 0.01:
		wheel_throttle_min = -1.0
		wheel_throttle_max = 1.0
	if not is_finite(wheel_brake_min) or not is_finite(wheel_brake_max) or wheel_brake_max - wheel_brake_min < 0.01:
		wheel_brake_min = -1.0
		wheel_brake_max = 1.0
	_resolved_wheel_device = -2

func apply(vehicle: RigidBody3D, delta: float) -> void:
	var wheel: Dictionary = _wheel_state(delta)
	var requested: float = float(wheel.get("steering", Input.get_axis("steer_left", "steer_right")))
	requested = signf(requested) * pow(absf(requested), steering_curve)
	steering = move_toward(steering, requested, delta * response * (4.0 if requested == 0 else 2.0))
	var throttle: float = pow(float(wheel.get("throttle", Input.get_action_strength("accelerate"))), pedal_curve)
	var braking: float = pow(float(wheel.get("brake", Input.get_action_strength("brake"))), pedal_curve)
	if Input.is_action_pressed("reverse"):
		throttle = -maxf(throttle, 0.65)
	vehicle.set_controls(throttle, braking, steering, Input.get_action_strength("handbrake"))
	if Input.is_action_just_pressed("shift_up"):
		vehicle.shift_up()
	if Input.is_action_just_pressed("shift_down"):
		vehicle.shift_down()

func _wheel_state(delta: float) -> Dictionary:
	_wheel_probe_timer -= delta
	if _resolved_wheel_device < 0 and _wheel_probe_timer <= 0.0:
		_resolved_wheel_device = -2
		_wheel_probe_timer = 1.0
	var device: int = _find_wheel_device()
	if device < 0:
		return {}
	var steer: float = _normalize_steering(Input.get_joy_axis(device, wheel_steering_axis))
	if wheel_invert_steering:
		steer = -steer
	var throttle: float = _pedal_axis(device, wheel_throttle_axis, wheel_throttle_min, wheel_throttle_max)
	var brake: float = _pedal_axis(device, wheel_brake_axis, wheel_brake_min, wheel_brake_max)
	return {"steering": _deadzone(steer, steering_deadzone), "throttle": throttle, "brake": brake}

func _find_wheel_device() -> int:
	if _resolved_wheel_device != -2:
		return _resolved_wheel_device
	var connected: PackedInt32Array = Input.get_connected_joypads()
	if wheel_device >= 0 and wheel_device in connected:
		_resolved_wheel_device = wheel_device
		return _resolved_wheel_device
	for id: int in connected:
		var name: String = Input.get_joy_name(id).to_lower()
		if name.contains("g923") or name.contains("logitech") or name.contains("wheel"):
			_resolved_wheel_device = id
			return id
	_resolved_wheel_device = -1
	return -1

func _pedal_axis(device: int, axis: int, minimum: float, maximum: float) -> float:
	var raw: float = Input.get_joy_axis(device, axis)
	var value: float = inverse_lerp(minimum, maximum, raw) if not is_equal_approx(minimum, maximum) else 0.0
	value = clampf(value, 0.0, 1.0)
	return 0.0 if value < pedal_deadzone else clampf((value - pedal_deadzone) / maxf(1.0 - pedal_deadzone, 0.001), 0.0, 1.0)

func _normalize_steering(raw: float) -> float:
	var value: float
	if raw >= wheel_steering_center:
		value = (raw - wheel_steering_center) / maxf(wheel_steering_max - wheel_steering_center, 0.001)
	else:
		value = (raw - wheel_steering_center) / maxf(wheel_steering_center - wheel_steering_min, 0.001)
	return clampf(value, -1.0, 1.0)

static func _deadzone(value: float, deadzone: float) -> float:
	var magnitude: float = absf(value)
	if magnitude <= deadzone:
		return 0.0
	return signf(value) * clampf((magnitude - deadzone) / maxf(1.0 - deadzone, 0.001), 0.0, 1.0)
