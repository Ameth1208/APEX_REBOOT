class_name ApexAeroSpec
extends Resource

## Aerodynamics specification: Drag, downforce, distribution, and wake draft.

@export var drag_area_cd_a: float = 0.72       ## Cd * A (m^2)
@export var downforce_area_cl_a: float = 0.85  ## Cl * A (m^2)
@export var aero_balance_front: float = 0.42   ## Front axle fraction of downforce
@export var air_density: float = 1.225         ## kg / m^3
@export var yaw_drag_factor: float = 1.35      ## Drag increase when car is sliding yawed
@export var yaw_lift_factor: float = 0.5       ## Downforce loss when car is sliding yawed

static func from_dictionary(data: Dictionary, is_motorcycle: bool) -> ApexAeroSpec:
	var spec := ApexAeroSpec.new()
	var default_drag: float = 0.42 if is_motorcycle else 0.72
	var default_downforce: float = 0.0 if is_motorcycle else 0.80
	spec.drag_area_cd_a = float(data.get("drag_area_m2", default_drag))
	spec.downforce_area_cl_a = float(data.get("downforce_area_m2", default_downforce))
	spec.aero_balance_front = float(data.get("aero_balance_front", 0.42))
	
	if is_motorcycle:
		var bike_type: String = str(data.get("motorcycle_type", data.get("bike_type", "sport"))).to_lower()
		match bike_type:
			"sport": spec.drag_area_cd_a *= 0.88
			"cruiser": spec.drag_area_cd_a *= 1.18
			"dirt": spec.drag_area_cd_a *= 1.25
			"touring": spec.drag_area_cd_a *= 1.05
	else:
		var cat: String = str(data.get("category", "road_gt")).to_lower()
		match cat:
			"road_gt": spec.drag_area_cd_a *= 0.94
			"track_weapon": spec.drag_area_cd_a *= 0.85
			"pickup": spec.drag_area_cd_a *= 1.30
	return spec
