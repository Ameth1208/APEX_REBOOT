class_name ApexPlayerInput
extends RefCounted

var steering: float = 0.0
var response: float = 1.0
var steering_curve: float = 1.2
var pedal_curve: float = 1.0

func configure(values: Dictionary) -> void:
	response = clampf(float(values.get("steering_response", 1.0)), 0.4, 2.5)
	steering_curve = clampf(float(values.get("steering_curve", 1.2)), 0.6, 2.5)
	pedal_curve = clampf(float(values.get("pedal_curve", 1.0)), 0.5, 2.5)

func apply(vehicle: RigidBody3D, delta: float) -> void:
	var requested: float = Input.get_axis("steer_left", "steer_right")
	requested = signf(requested) * pow(absf(requested), steering_curve)
	steering = move_toward(steering, requested, delta * response * (4.0 if requested == 0 else 2.0))
	var throttle: float = pow(Input.get_action_strength("accelerate"), pedal_curve)
	var braking: float = pow(Input.get_action_strength("brake"), pedal_curve)
	if Input.is_action_pressed("reverse"):
		throttle = -maxf(throttle, 0.65)
	vehicle.set_controls(throttle, braking, steering, Input.get_action_strength("handbrake"))
	if Input.is_action_just_pressed("shift_up"):
		vehicle.shift_up()
	if Input.is_action_just_pressed("shift_down"):
		vehicle.shift_down()
