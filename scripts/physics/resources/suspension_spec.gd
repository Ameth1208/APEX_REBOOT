class_name ApexSuspensionSpec
extends Resource

## Specification for suspension kinematics, spring rates, asymmetric dampers,
## bump stops, and anti-roll bars.

enum SuspensionType {
	MACPHERSON,
	DOUBLE_WISHBONE,
	MULTILINK,
	SOLID_AXLE,
	TELESCOPIC_FORK,
	SWINGARM
}

@export var type: SuspensionType = SuspensionType.MACPHERSON
@export var spring_rate_n_m: float = 45000.0
@export var bump_damping_n_s_m: float = 2800.0       ## Compression damping c_b
@export var rebound_damping_n_s_m: float = 4600.0    ## Rebound damping c_r
@export var travel_m: float = 0.24
@export var sag_m: float = 0.08
@export var bump_stop_travel_m: float = 0.18         ## Travel at which bump-stop engages
@export var bump_stop_stiffness: float = 180000.0    ## Stiff bump stop spring rate
@export var bump_stop_exponent: float = 2.0          ## Power n in kb * (x - xb)^n
@export var motion_ratio: float = 0.95               ## Ratio between wheel movement and spring movement
@export var anti_roll_bar_rate_n_m: float = 18000.0  ## Front or rear ARB torsional/linear rate
@export var static_camber_deg: float = -1.2
@export var camber_gain_deg_per_m: float = 12.0      ## Camber variation with compression
@export var static_caster_deg: float = 5.5
@export var static_toe_deg: float = 0.05
@export var unsprung_mass_kg: float = 42.0           ## Wheel + brake + hub mass (quarter-car)
@export var tire_vertical_stiffness_n_m: float = 250000.0 ## kt in quarter-car model

static func from_dictionary(data: Dictionary, is_front: bool, is_motorcycle: bool, corner_mass: float) -> ApexSuspensionSpec:
	var spec := ApexSuspensionSpec.new()
	var type_str: String = str(data.get("suspension_type", "macpherson")).to_lower()
	if is_motorcycle:
		spec.type = SuspensionType.TELESCOPIC_FORK if is_front else SuspensionType.SWINGARM
	else:
		match type_str:
			"double_wishbone": spec.type = SuspensionType.DOUBLE_WISHBONE
			"multilink": spec.type = SuspensionType.MULTILINK
			"leaf_spring", "solid_axle": spec.type = SuspensionType.SOLID_AXLE
			_: spec.type = SuspensionType.MACPHERSON

	spec.travel_m = float(data.get("suspension_travel_m", 0.24 if not is_motorcycle else 0.22))
	var damping_ratio: float = float(data.get("suspension_damping_ratio", 0.72))
	
	# Spring rate derived from corner mass and static sag, or explicit rate
	var default_sag: float = 0.09 if not is_motorcycle else 0.06
	spec.sag_m = float(data.get("suspension_sag_m", default_sag))
	spec.spring_rate_n_m = float(data.get("spring_rate_n_m", corner_mass * 9.81 / maxf(spec.sag_m, 0.01)))
	
	# Critical damping c_crit = 2 * sqrt(k * m)
	var c_crit: float = 2.0 * sqrt(spec.spring_rate_n_m * maxf(corner_mass, 1.0))
	var c_nominal: float = c_crit * damping_ratio
	
	# Asymmetric damping: bump c_b is softer for compliance (~0.75 nominal),
	# rebound c_r is stiffer (~1.35 nominal) to arrest body oscillation.
	spec.bump_damping_n_s_m = float(data.get("bump_damping_n_s_m", c_nominal * 0.78))
	spec.rebound_damping_n_s_m = float(data.get("rebound_damping_n_s_m", c_nominal * 1.38))
	
	spec.bump_stop_travel_m = float(data.get("bump_stop_travel_m", spec.travel_m * 0.78))
	spec.bump_stop_stiffness = float(data.get("bump_stop_stiffness", spec.spring_rate_n_m * 4.5))
	spec.bump_stop_exponent = float(data.get("bump_stop_exponent", 2.0))
	spec.motion_ratio = float(data.get("motion_ratio", 0.96 if spec.type == SuspensionType.DOUBLE_WISHBONE else 0.92))
	
	# Anti-roll bar rate (higher in front on road cars to promote stability)
	var arb_default: float = 22000.0 if is_front else 14000.0
	spec.anti_roll_bar_rate_n_m = 0.0 if is_motorcycle else float(data.get("anti_roll_bar_n_m", arb_default))
	
	spec.static_camber_deg = float(data.get("camber_deg", -0.8 if is_front else -0.5))
	spec.static_caster_deg = float(data.get("caster_deg", 5.5 if is_front else 0.0))
	spec.unsprung_mass_kg = float(data.get("unsprung_mass_kg", 38.0 if not is_motorcycle else 16.0))
	spec.tire_vertical_stiffness_n_m = float(data.get("tire_vertical_stiffness_n_m", 240000.0))
	return spec
