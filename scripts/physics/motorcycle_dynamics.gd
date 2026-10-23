extends RefCounted
## Two-contact motorcycle with front brake bias and a virtual rider.
## Each motorcycle type (sport, cruiser, dirt, touring) has distinct
## steering geometry, lean behaviour and suspension response.

enum BikeType { SPORT, CRUISER, DIRT, TOURING }

var bike_type: BikeType = BikeType.SPORT
var lean_angle: float = 0.0
var max_lean: float = deg_to_rad(51.0)
var wheelbase: float = 1.40
var steering_ratio: float = 1.0
var trail_m: float = 0.095
var rake_deg: float = 25.5
var _yaw_integral: float = 0.0
var _lean_demand: float = 0.0

const TYPE_DEFAULTS: Dictionary = {
	"sport": {"max_lean_deg": 51.0, "rake_deg": 24.5, "trail_m": 0.090, "steering_ratio": 1.0, "wheelbase": 1.40},
	"cruiser": {"max_lean_deg": 32.0, "rake_deg": 32.0, "trail_m": 0.140, "steering_ratio": 0.72, "wheelbase": 1.65},
	"dirt": {"max_lean_deg": 40.0, "rake_deg": 28.0, "trail_m": 0.115, "steering_ratio": 0.85, "wheelbase": 1.48},
	"touring": {"max_lean_deg": 37.0, "rake_deg": 30.0, "trail_m": 0.130, "steering_ratio": 0.78, "wheelbase": 1.60},
}

func configure(data: Dictionary) -> void:
	var type_str: String = str(data.get("motorcycle_type", data.get("bike_type", "sport"))).to_lower()
	bike_type = BikeType.CRUISER if type_str == "cruiser" else BikeType.DIRT if type_str == "dirt" else BikeType.TOURING if type_str == "touring" else BikeType.SPORT
	var defaults: Dictionary = TYPE_DEFAULTS.get(type_str, TYPE_DEFAULTS["sport"])
	max_lean = deg_to_rad(float(data.get("max_lean_deg", defaults["max_lean_deg"])))
	rake_deg = float(data.get("rake_deg", defaults["rake_deg"]))
	trail_m = float(data.get("trail_m", defaults["trail_m"]))
	steering_ratio = float(data.get("steering_ratio", defaults["steering_ratio"]))
	wheelbase = float(data.get("wheelbase_m", data.get("wheelbase", defaults["wheelbase"])))
	lean_angle = 0.0
	_yaw_integral = 0.0
	_lean_demand = 0.0

## Steering geometry: rake/trail affect how fast the bars self-centre.
## Cruisers with high rake need more rider input; sport bikes self-centre faster.
func steering(input: float, speed_mps: float, max_steer: float, yaw_rate: float, dt: float) -> float:
	var speed: float = absf(speed_mps)
	# Effective steering range scales by type (cruisers turn less).
	var effective_max: float = max_steer * steering_ratio
	var slow_steer: float = input * effective_max
	var requested_lean: float = input * max_lean
	# Self-centring torque ∝ trail / speed²; higher trail = more stable at speed.
	var self_center: float = trail_m * speed * speed * 0.004
	var fast_steer: float = atan(9.81 * tan(requested_lean) * wheelbase / maxf(speed * speed, 1.0))
	var blend: float = smoothstep(4.0, 12.0, speed)
	var geometric_angle: float = lerpf(slow_steer, fast_steer, blend)
	# Trail-induced self-centring damps the angle at speed.
	geometric_angle *= 1.0 / (1.0 + self_center * 0.1)
	_lean_demand = clampf(atan(speed * speed * tan(geometric_angle) / (wheelbase * 9.81)), -max_lean, max_lean)
	var desired_yaw_right: float = speed_mps * tan(geometric_angle) / wheelbase
	var error: float = desired_yaw_right + yaw_rate
	_yaw_integral = clampf(_yaw_integral * exp(-dt * 1.2) + error * dt, -0.35, 0.35)
	if speed < 4.0:
		_yaw_integral = 0.0
	var correction: float = (error * 0.16 + _yaw_integral * 0.035) * blend
	return clampf(geometric_angle + correction, -effective_max, effective_max)

func integrate(state: PhysicsDirectBodyState3D, steer_angle: float, speed_mps: float, ground_normal: Vector3, mass_kg: float, dt: float, touching: bool) -> void:
	var target_lean: float = _lean_demand
	if not touching:
		target_lean = 0.0
	# Cruisers lean slower, sport bikes quicker; dirt is intermediate.
	var lean_rate: float = 5.5
	match bike_type:
		BikeType.CRUISER: lean_rate = 3.8
		BikeType.TOURING: lean_rate = 4.2
		BikeType.DIRT: lean_rate = 5.0
		BikeType.SPORT: lean_rate = 6.5
	lean_angle = lerpf(lean_angle, target_lean, 1.0 - exp(-dt * lean_rate))
	if not touching:
		return
	var up: Vector3 = state.transform.basis.y.normalized()
	var forward: Vector3 = -state.transform.basis.z.normalized()
	var balance_error: float = up.cross(ground_normal).dot(forward)
	var roll_rate: float = state.angular_velocity.dot(forward)
	# Cruisers resist leaning less (lower balance gain); sport bikes snap upright.
	var balance_gain: float = 38.0
	var roll_damp: float = 8.0
	match bike_type:
		BikeType.CRUISER: balance_gain = 28.0; roll_damp = 10.0
		BikeType.TOURING: balance_gain = 32.0; roll_damp = 9.5
		BikeType.DIRT: balance_gain = 34.0; roll_damp = 7.0
		BikeType.SPORT: balance_gain = 42.0; roll_damp = 8.0
	state.apply_torque(forward * (balance_error * mass_kg * balance_gain - roll_rate * mass_kg * roll_damp))