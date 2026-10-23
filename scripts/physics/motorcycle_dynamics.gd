extends RefCounted
## Two-contact motorcycle with front brake bias and a virtual rider.
## A rider balances the chassis while the model banks into the turn.
## Lean demand follows tan(lean) = lateral acceleration / gravity.

var lean_angle: float = 0.0
var max_lean: float = deg_to_rad(51.0)
var wheelbase: float = 1.40
var _yaw_integral: float = 0.0
var _lean_demand: float = 0.0

func configure(data: Dictionary) -> void:
	max_lean = deg_to_rad(float(data.get("max_lean_deg", 51.0)))
	wheelbase = float(data.get("wheelbase_m", data.get("wheelbase", 1.40)))
	lean_angle = 0.0
	_yaw_integral = 0.0
	_lean_demand = 0.0

func steering(input: float, speed_mps: float, max_steer: float, yaw_rate: float, dt: float) -> float:
	var speed: float = absf(speed_mps)
	var slow_steer: float = input * max_steer
	var requested_lean: float = input * max_lean
	var fast_steer: float = atan(9.81 * tan(requested_lean) * wheelbase / maxf(speed * speed, 1.0))
	var blend: float = smoothstep(4.0, 12.0, speed)
	var geometric_angle: float = lerpf(slow_steer, fast_steer, blend)
	_lean_demand = clampf(atan(speed * speed * tan(geometric_angle) / (wheelbase * 9.81)), -max_lean, max_lean)
	# The rider corrects tyre slip through the handlebars, never by yaw teleport.
	var desired_yaw_right: float = speed_mps * tan(geometric_angle) / wheelbase
	var error: float = desired_yaw_right + yaw_rate
	_yaw_integral = clampf(_yaw_integral * exp(-dt * 1.2) + error * dt, -0.35, 0.35)
	if speed < 4.0:
		_yaw_integral = 0.0
	var correction: float = (error * 0.16 + _yaw_integral * 0.035) * blend
	return clampf(geometric_angle + correction, -max_steer, max_steer)

func integrate(state: PhysicsDirectBodyState3D, steer_angle: float, speed_mps: float, ground_normal: Vector3, mass_kg: float, dt: float, touching: bool) -> void:
	var target_lean: float = _lean_demand
	if not touching:
		target_lean = 0.0
	lean_angle = lerpf(lean_angle, target_lean, 1.0 - exp(-dt * 5.5))
	if not touching:
		return
	var up: Vector3 = state.transform.basis.y.normalized()
	var forward: Vector3 = -state.transform.basis.z.normalized()
	# Pitch remains suspension driven; balance adds roll torque only.
	var balance_error: float = up.cross(ground_normal).dot(forward)
	var roll_rate: float = state.angular_velocity.dot(forward)
	state.apply_torque(forward * (balance_error * mass_kg * 38.0 - roll_rate * mass_kg * 8.0))
