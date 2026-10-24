class_name ApexWheelState
extends RefCounted

## State of a single wheel assembly including kinematics, suspension forces,
## tire contact, slip angles, and thermodynamic condition.

var index: int = 0
var is_front: bool = false
var is_left: bool = false
var is_driven: bool = false

# Kinematic offsets & locations
var mount_offset: Vector3 = Vector3.ZERO         ## Mount point relative to chassis origin
var contact_position: Vector3 = Vector3.ZERO     ## Contact position relative to vehicle origin
var global_contact: Vector3 = Vector3.ZERO       ## Global 3D contact point on road
var road_normal: Vector3 = Vector3.UP            ## Road surface normal n_road
var contact_velocity: Vector3 = Vector3.ZERO     ## Relative linear velocity at contact point
var forward_vector: Vector3 = Vector3.FORWARD    ## Wheel heading on surface plane
var lateral_vector: Vector3 = Vector3.RIGHT      ## Wheel lateral vector on surface plane

# Suspension states
var compression: float = 0.0                     ## xs: Suspension compression (m)
var compression_velocity: float = 0.0            ## \dot{xs}: Compression rate (m/s)
var spring_force_n: float = 0.0                  ## F_spring (N)
var damper_force_n: float = 0.0                  ## F_damper (N)
var bump_stop_force_n: float = 0.0               ## F_bump (N)
var arb_force_n: float = 0.0                     ## F_arb (N) from anti-roll bar
var normal_load_n: float = 0.0                   ## F_z: Total vertical load on tire (N)

# Tire dynamics
var steer_angle_rad: float = 0.0                 ## Steer angle around local upright
var camber_angle_rad: float = 0.0                ## \gamma: Camber angle relative to ground normal
var slip_ratio: float = 0.0                      ## \kappa: Longitudinal slip
var slip_angle_rad: float = 0.0                  ## \alpha: Lateral slip angle (rad)
var longitudinal_force_n: float = 0.0            ## F_x: Acceleration / braking force (N)
var lateral_force_n: float = 0.0                 ## F_y: Cornering force (N)
var camber_thrust_n: float = 0.0                 ## Camber thrust force component (N)
var rolling_resistance_n: float = 0.0            ## Rolling resistance (N)
var combined_force: Vector3 = Vector3.ZERO       ## Resulting 3D force applied to chassis

# Environmental & condition
var surface_name: String = "asphalt"
var friction_mu: float = 1.08
var effective_mu: float = 1.08
var temperature_c: float = 50.0                  ## T: Tire temperature (Celsius)
var pressure_bar: float = 2.2                    ## P: Tire inflation pressure (bar)
var wear: float = 0.0                            ## wear: [0.0 = fresh, 1.0 = bald]
var friction_power_w: float = 0.0                ## Heating power (W)
var slide_speed_mps: float = 0.0                 ## Tangential slide velocity (m/s)

# Control intervention flags
var is_grounded: bool = false
var is_locked: bool = false
var abs_active: bool = false
var tcs_active: bool = false

func reset(initial_temp: float = 50.0, initial_pressure: float = 2.2) -> void:
	compression = 0.0
	compression_velocity = 0.0
	spring_force_n = 0.0
	damper_force_n = 0.0
	bump_stop_force_n = 0.0
	arb_force_n = 0.0
	normal_load_n = 0.0
	steer_angle_rad = 0.0
	camber_angle_rad = 0.0
	slip_ratio = 0.0
	slip_angle_rad = 0.0
	longitudinal_force_n = 0.0
	lateral_force_n = 0.0
	camber_thrust_n = 0.0
	rolling_resistance_n = 0.0
	combined_force = Vector3.ZERO
	temperature_c = initial_temp
	pressure_bar = initial_pressure
	wear = 0.0
	friction_power_w = 0.0
	slide_speed_mps = 0.0
	is_grounded = false
	is_locked = false
	abs_active = false
	tcs_active = false

func to_dictionary() -> Dictionary:
	return {
		"index": index,
		"front": is_front,
		"left": is_left,
		"grounded": is_grounded,
		"fz": normal_load_n,
		"fx": longitudinal_force_n,
		"fy": lateral_force_n,
		"xs": compression,
		"xs_dot": compression_velocity,
		"spring_f": spring_force_n,
		"damper_f": damper_force_n,
		"bump_f": bump_stop_force_n,
		"arb_f": arb_force_n,
		"kappa": slip_ratio,
		"alpha": slip_angle_rad,
		"gamma": camber_angle_rad,
		"temp_c": temperature_c,
		"pressure_bar": pressure_bar,
		"wear": wear,
		"surface": surface_name,
		"mu_eff": effective_mu,
		"abs": abs_active,
		"tcs": tcs_active,
		"locked": is_locked
	}
