class_name ApexTireWearModel
extends RefCounted

## Simulates tire tread wear and inflation pressure effects.

static func grip_from_wear(wear_amount: float) -> float:
	# Fresh tire has full tread; as wear approaches 1.0 (slick/worn down),
	# dry grip peaks slightly on dry asphalt then drops significantly on wet/rough.
	return clampf(1.0 - wear_amount * 0.18, 0.70, 1.02)

static func grip_from_pressure(current_bar: float, nominal_bar: float = 2.2) -> float:
	var ratio: float = current_bar / maxf(nominal_bar, 0.5)
	if absf(ratio - 1.0) < 0.05:
		return 1.0
	# Under-inflation or severe over-inflation reduces contact patch uniformity
	var deviation: float = absf(ratio - 1.0)
	return clampf(1.0 - deviation * 0.25, 0.75, 1.0)

static func step_wear(current_wear: float, friction_work_joules: float, dt: float) -> float:
	var wear_rate: float = friction_work_joules * 1.5e-9
	return clampf(current_wear + wear_rate * dt, 0.0, 1.0)
