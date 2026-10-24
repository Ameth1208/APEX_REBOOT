class_name ApexVehicleSpec
extends Resource

## Master vehicle specification combining geometry, mass, tires, suspension,
## powertrain, and aerodynamics.

@export var name: String = "Apex Vehicle"
@export var is_motorcycle: bool = false
@export var mass_kg: float = 1450.0
@export var curb_mass_kg: float = 1375.0
@export var rider_mass_kg: float = 75.0
@export var wheelbase_m: float = 2.65
@export var track_width_front_m: float = 1.58
@export var track_width_rear_m: float = 1.56
@export var cg_height_m: float = 0.52
@export var front_weight_fraction: float = 0.55
@export var ride_height_m: float = 0.58
@export var max_steer_deg: float = 32.0

@export var front_tire: ApexTireSpec
@export var rear_tire: ApexTireSpec
@export var front_suspension: ApexSuspensionSpec
@export var rear_suspension: ApexSuspensionSpec
@export var powertrain: ApexEngineSpec
@export var aero: ApexAeroSpec

static func from_dictionary(data: Dictionary) -> ApexVehicleSpec:
	var spec := ApexVehicleSpec.new()
	var kind: String = str(data.get("kind", data.get("category", "car"))).to_lower()
	spec.is_motorcycle = kind in ["motorcycle", "motorbike", "bike", "supersport", "moto"]
	spec.name = str(data.get("display_name", data.get("short_name", "Vehicle")))
	spec.mass_kg = float(data.get("mass_kg", data.get("mass", 280.0 if spec.is_motorcycle else 1450.0)))
	spec.curb_mass_kg = float(data.get("curb_mass_kg", spec.mass_kg - 75.0))
	spec.rider_mass_kg = float(data.get("rider_mass_kg", 75.0))
	spec.wheelbase_m = float(data.get("wheelbase_m", data.get("wheelbase", 1.42 if spec.is_motorcycle else 2.65)))
	
	var tw: float = float(data.get("track_width_m", data.get("track_width", 0.15 if spec.is_motorcycle else 1.58)))
	spec.track_width_front_m = float(data.get("track_width_front_m", tw))
	spec.track_width_rear_m = float(data.get("track_width_rear_m", tw))
	
	spec.cg_height_m = float(data.get("cg_height_m", 0.62 if spec.is_motorcycle else 0.52))
	spec.front_weight_fraction = float(data.get("front_weight_fraction", 0.48 if spec.is_motorcycle else 0.54))
	spec.ride_height_m = float(data.get("ride_height_m", data.get("ride_height", 0.62 if spec.is_motorcycle else 0.58)))
	spec.max_steer_deg = float(data.get("max_steer_deg", 29.0 if spec.is_motorcycle else 32.0))
	
	var wheel_radius: float = float(data.get("wheel_radius_m", data.get("wheel_radius", 0.31 if spec.is_motorcycle else 0.34)))
	
	# Load sub-specs
	var f_tyre_dict: Dictionary = data.get("front_tyre", {})
	var r_tyre_dict: Dictionary = data.get("rear_tyre", {})
	spec.front_tire = ApexTireSpec.from_dictionary(f_tyre_dict, wheel_radius, 14.0)
	spec.rear_tire = ApexTireSpec.from_dictionary(r_tyre_dict, wheel_radius, 14.0)
	
	var front_corner_mass: float = spec.mass_kg * spec.front_weight_fraction / (1.0 if spec.is_motorcycle else 2.0)
	var rear_corner_mass: float = spec.mass_kg * (1.0 - spec.front_weight_fraction) / (1.0 if spec.is_motorcycle else 2.0)
	
	spec.front_suspension = ApexSuspensionSpec.from_dictionary(data, true, spec.is_motorcycle, front_corner_mass)
	spec.rear_suspension = ApexSuspensionSpec.from_dictionary(data, false, spec.is_motorcycle, rear_corner_mass)
	spec.powertrain = ApexEngineSpec.from_dictionary(data, spec.is_motorcycle, spec.mass_kg)
	spec.aero = ApexAeroSpec.from_dictionary(data, spec.is_motorcycle)
	return spec
