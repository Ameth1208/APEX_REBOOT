extends RefCounted
## Shared contact geometry; visual hubs and tyre forces use the same axle layout.

static func offsets(data: Dictionary, motorcycle: bool) -> Array[Vector3]:
	var length: float = float(data.get("wheelbase_m", data.get("wheelbase", 2.65)))
	var share: float = float(data.get("front_weight_fraction", 0.48 if motorcycle else 0.46))
	var front: float = -length * (1.0 - share)
	var rear: float = length * share
	if motorcycle:
		return [Vector3(0, 0, front), Vector3(0, 0, rear)]
	var width: float = float(data.get("track_width_m", data.get("track_width", 1.64)))
	var front_width: float = float(data.get("front_track_width_m", width))
	var rear_width: float = float(data.get("rear_track_width_m", width))
	return [Vector3(-front_width * 0.5, 0, front), Vector3(front_width * 0.5, 0, front),
		Vector3(-rear_width * 0.5, 0, rear), Vector3(rear_width * 0.5, 0, rear)]

static func index(front: bool, right: bool, motorcycle: bool) -> int:
	return (0 if front else 1) if motorcycle else (0 if front else 2) + (1 if right else 0)

static func steering(central_angle: float, lateral: float, wheelbase: float) -> float:
	if absf(central_angle) < 0.0001:
		return 0.0
	var radius: float = wheelbase / tan(absf(central_angle))
	return signf(central_angle) * atan2(wheelbase, maxf(0.1, radius - lateral * signf(central_angle)))

static func sag(data: Dictionary, motorcycle: bool) -> float:
	return clampf(float(data.get("suspension_sag_m", 0.115 if motorcycle else 0.10)), 0.015,
		maxf(0.015, float(data.get("suspension_travel_m", 0.27)) * 0.75))
