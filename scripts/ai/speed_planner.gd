class_name ApexSpeedPlanner
extends RefCounted
## Speed envelope uses the same surface/wet tyre coefficients as the vehicle.
## Banking is signed; crests and braking distance constrain the target speed.

const Tyres = preload("res://scripts/physics/tyre_forces.gd")
var velocities: PackedFloat32Array = PackedFloat32Array()
var braking_limits: PackedFloat32Array = PackedFloat32Array()
var spacing: float = 5.0
var length_m: float = 1.0
var closed: bool = true

func build(track: Node3D, profile: Dictionary, wetness: float, pace: float = 0.9) -> void:
	length_m = track.get_length()
	closed = bool(track.closed)
	var segments: int = maxi(32, ceili(length_m / 5.0))
	spacing = length_m / float(segments)
	var count: int = segments if closed else segments + 1
	velocities.resize(count)
	braking_limits.resize(count)
	var tyre_scale: float = float(profile.get("tire_grip_scale", profile.get("grip_factor", float(profile.get("grip", 1.22)) / 1.22)))
	var mass_kg: float = float(profile.get("mass_kg", 1000.0))
	var brake_spec: ApexEngineSpec = ApexEngineSpec.from_dictionary(profile, str(profile.get("kind", "")) == "motorcycle", mass_kg)
	var mechanical_braking: float = brake_spec.brake_force_total_n / maxf(mass_kg, 1.0)
	var aero: float = float(profile.get("downforce_area_m2", 0.5))
	var max_speed: float = float(profile.get("top_speed_kph", 280.0)) / 3.6
	var motorcycle: bool = str(profile.get("kind", profile.get("category", "car"))) == "motorcycle"
	var rider_margin: float = 0.72 if motorcycle else 1.0
	for i: int in count:
		var distance: float = float(i) * spacing
		var before: Dictionary = track.sample_at(distance - 5.0)
		var here: Dictionary = track.sample_at(distance)
		var after: Dictionary = track.sample_at(distance + 5.0)
		var f0: Vector3 = before["forward"]
		var f1: Vector3 = after["forward"]
		var horizontal0: Vector3 = Vector3(f0.x, 0.0, f0.z).normalized()
		var horizontal1: Vector3 = Vector3(f1.x, 0.0, f1.z).normalized()
		var turn_right: float = -signf(horizontal0.cross(horizontal1).y)
		var span: float = 10.0 if closed else maxf(0.1, minf(distance + 5.0, length_m) - maxf(distance - 5.0, 0.0))
		var curvature: float = horizontal0.distance_to(horizontal1) / span
		var mu: float = Tyres.friction(str(here.get("surface", "asphalt")), wetness, tyre_scale)
		var bank: float = deg_to_rad(float(here.get("bank", 0.0)))
		var lateral_accel: float = 9.81 * maxf(0.18, mu * cos(bank) + turn_right * sin(bank))
		var denominator: float = maxf(0.001, curvature - 0.5 * 1.225 * aero * mu / mass_kg)
		var corner_speed: float = sqrt(lateral_accel / denominator)
		if motorcycle:
			var max_lean: float = deg_to_rad(float(profile.get("max_lean_deg", 51.0)))
			corner_speed = minf(corner_speed, sqrt(9.81 * tan(max_lean) / maxf(curvature, 0.001)))
		var crest: float = maxf(0.0, (f0.y - f1.y) / span)
		if crest > 0.001:
			corner_speed = minf(corner_speed, sqrt(6.5 / crest))
		# Retain a combined-slip margin for braking, path correction and model error.
		velocities[i] = minf(max_speed, corner_speed * 0.88) * clampf(pace, 0.45, 1.0) * rider_margin
		# Brakes, tyre load on the slope and gravity all constrain stopping distance.
		var normal_fraction: float = maxf(0.15, Vector3(here["normal"]).dot(Vector3.UP))
		var tyre_braking: float = mu * 9.81 * normal_fraction
		braking_limits[i] = maxf(0.35, minf(tyre_braking, mechanical_braking) * 0.62 + Vector3(here["forward"]).y * 9.81)
	if not closed:
		velocities[count - 1] = 0.0
	for _pass: int in (3 if closed else 1):
		for i: int in range(count - 1 if closed else count - 2, -1, -1):
			var next: float = velocities[(i + 1) % count]
			velocities[i] = minf(velocities[i], sqrt(next * next + 2.0 * braking_limits[i] * spacing))

func braking_at(distance: float) -> float:
	if braking_limits.is_empty():
		return 4.0
	var station: float = fposmod(distance, length_m) if closed else clampf(distance, 0.0, length_m)
	return braking_limits[mini(floori(station / spacing), braking_limits.size() - 1)]

func target_at(distance: float) -> float:
	if velocities.is_empty():
		return 12.0
	var normalized: float = (fposmod(distance, length_m) if closed else clampf(distance, 0.0, length_m)) / spacing
	var index: int = mini(floori(normalized), velocities.size() - 1)
	var next: int = (index + 1) % velocities.size() if closed else mini(index + 1, velocities.size() - 1)
	return lerpf(velocities[index], velocities[next], normalized - floorf(normalized))
