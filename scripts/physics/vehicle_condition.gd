extends RefCounted
## Gameplay damage uses actual contact impulse per unit mass. It is not a crash
## reconstruction model. Repair is explicit through vehicle.reset_at().

var engine_health: float = 1.0
var steering_health: float = 1.0
var aero_health: float = 1.0
var steering_bias: float = 0.0
var crashed: bool = false
var impact_strength: float = 0.0
var impact_serial: int = 0
var impact_position: Vector3 = Vector3.ZERO
var impact_normal: Vector3 = Vector3.UP
var impact_delta_v: float = 0.0
var scrape_strength: float = 0.0
var repair_serial: int = 0
var _grace: float = 0.0
var _cooldown: float = 0.0
var _loss_time: float = 0.0
var _motorcycle: bool = false
var _sensitivity: float = 1.0

func configure(profile: Dictionary, motorcycle: bool) -> void:
	_motorcycle = motorcycle
	_sensitivity = clampf(float(profile.get("damage_sensitivity", 1.0)), 0.1, 3.0)
	repair()

func repair() -> void:
	engine_health = 1.0
	steering_health = 1.0
	aero_health = 1.0
	steering_bias = 0.0
	crashed = false
	impact_strength = 0.0
	impact_delta_v = 0.0
	scrape_strength = 0.0
	_grace = 0.75
	_cooldown = 0.0
	_loss_time = 0.0
	repair_serial += 1

func sample(state: PhysicsDirectBodyState3D, mass_kg: float) -> bool:
	var dt: float = state.step
	_grace = maxf(_grace - dt, 0.0)
	_cooldown = maxf(_cooldown - dt, 0.0)
	impact_strength = move_toward(impact_strength, 0.0, dt * 2.2)
	scrape_strength = move_toward(scrape_strength, 0.0, dt * 3.0)
	var impulse_sum: float = 0.0
	var strongest: float = 0.0
	var position: Vector3 = state.transform.origin
	var normal: Vector3 = Vector3.UP
	for i: int in state.get_contact_count():
		var impulse: float = state.get_contact_impulse(i).length()
		impulse_sum += impulse
		if impulse > strongest:
			strongest = impulse
			position = state.get_contact_collider_position(i)
			normal = state.get_contact_impulse(i).normalized()
		var relative: Vector3 = state.get_contact_local_velocity_at_position(i) - state.get_contact_collider_velocity_at_position(i)
		if impulse > mass_kg * 0.018:
			scrape_strength = maxf(scrape_strength, clampf(relative.length() / 35.0, 0.0, 1.0))
	if _grace > 0.0 or _cooldown > 0.0:
		return false
	var delta_v: float = impulse_sum / maxf(mass_kg, 1.0)
	if delta_v < 1.6:
		return false
	impact_delta_v = delta_v
	impact_strength = clampf(delta_v / 20.0, 0.08, 1.0)
	impact_position = position
	impact_normal = normal if normal.length_squared() > 0.1 else Vector3.UP
	impact_serial += 1
	_cooldown = 0.16
	var local_hit: Vector3 = state.transform.affine_inverse() * position
	var severity: float = clampf(pow(maxf(delta_v - 3.0, 0.0) / 24.0, 1.5) * _sensitivity, 0.0, 1.0)
	_apply_damage(severity, local_hit)
	if _motorcycle and delta_v >= 8.5 and not crashed:
		crashed = true
		return true
	return false

func _apply_damage(severity: float, local_hit: Vector3) -> void:
	var front_hit: float = 1.0 if local_hit.z < -0.15 else 0.55
	engine_health = clampf(engine_health - severity, 0.0, 1.0)
	steering_health = clampf(steering_health - severity * front_hit, 0.0, 1.0)
	aero_health = clampf(aero_health - severity * (0.7 + front_hit * 0.3), 0.0, 1.0)
	steering_bias = clampf(steering_bias + signf(local_hit.x) * severity * front_hit * 0.045, -0.06, 0.06)

func observe_balance(alignment: float, speed_mps: float, slip: float, lean: float, touching: bool, dt: float) -> bool:
	if not _motorcycle or crashed or _grace > 0.0:
		return false
	var overturned: bool = alignment < 0.35
	var lost_grip: bool = touching and absf(speed_mps) > 15.0 and absf(lean) > deg_to_rad(37.0) and slip > 0.85
	_loss_time = _loss_time + dt if overturned or lost_grip else maxf(_loss_time - dt * 2.0, 0.0)
	if _loss_time < (0.25 if overturned else 0.9):
		return false
	crashed = true
	return true

func can_drive() -> bool:
	return not crashed and engine_health > 0.10

func power_scale() -> float:
	return lerpf(0.22, 1.0, engine_health) if can_drive() else 0.0

func steering_scale() -> float:
	return lerpf(0.38, 1.0, steering_health)

func snapshot() -> Dictionary:
	return {"damage": 1.0 - minf(engine_health, minf(steering_health, aero_health)),
		"engine_health": engine_health, "steering_health": steering_health, "aero_health": aero_health,
		"crashed": crashed, "can_drive": can_drive(), "impact_strength": impact_strength,
		"impact_serial": impact_serial, "impact_delta_v": impact_delta_v,
		"impact_position": impact_position, "scrape_strength": scrape_strength, "repair_serial": repair_serial}
