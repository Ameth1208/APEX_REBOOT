class_name ApexTireSpec
extends Resource

## Specification for tire physics, load sensitivity, thermal & wear properties.

@export var name: String = "Default Tire"
@export var width_mm: float = 245.0
@export var aspect_ratio: float = 40.0
@export var rim_diameter_in: float = 18.0
@export var radius_m: float = 0.33
@export var cornering_stiffness_n_per_rad: float = 120000.0
@export var longitudinal_stiffness_n: float = 140000.0
@export var camber_stiffness_n_per_rad: float = 12000.0
@export var reference_load_n: float = 4000.0
@export var load_sensitivity: float = 0.00008
@export var friction_scale: float = 1.0
@export var optimal_temp_c: float = 85.0
@export var temp_window_c: float = 30.0
@export var thermal_mass: float = 1200.0 # J/K
@export var rolling_resistance_coeff: float = 0.015
@export var nominal_pressure_bar: float = 2.2

static func from_dictionary(data: Dictionary, default_radius: float = 0.34, default_stiff: float = 14.0) -> ApexTireSpec:
	var spec := ApexTireSpec.new()
	spec.width_mm = float(data.get("width_mm", 245.0))
	spec.radius_m = float(data.get("radius_m", data.get("wheel_radius_m", default_radius)))
	spec.reference_load_n = float(data.get("reference_load_n", 4000.0))
	spec.load_sensitivity = float(data.get("load_sensitivity", 0.00008))
	spec.friction_scale = float(data.get("grip_scale", data.get("tire_grip_scale", 1.0)))
	
	if data.has("cornering_stiffness_n_per_rad"):
		spec.cornering_stiffness_n_per_rad = float(data["cornering_stiffness_n_per_rad"])
	else:
		var mult: float = float(data.get("cornering_stiffness", default_stiff))
		spec.cornering_stiffness_n_per_rad = mult * spec.reference_load_n
		if data.has("width_mm"):
			var ref_w: float = float(data.get("reference_width_mm", 275.0))
			spec.cornering_stiffness_n_per_rad *= sqrt(maxf(spec.width_mm, 1.0) / maxf(ref_w, 1.0))
			
	spec.longitudinal_stiffness_n = spec.cornering_stiffness_n_per_rad * 1.25
	spec.camber_stiffness_n_per_rad = spec.cornering_stiffness_n_per_rad * 0.12
	spec.optimal_temp_c = float(data.get("optimal_temp_c", 85.0))
	spec.rolling_resistance_coeff = float(data.get("rolling_resistance", 0.015))
	spec.nominal_pressure_bar = float(data.get("pressure_bar", 2.2))
	return spec
