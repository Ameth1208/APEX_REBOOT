class_name ApexTransmissionSolver
extends RefCounted

## Transmission solver with gear ratios, manual / automatic shift logic,
## and clutch engagement during shifts.

var spec: ApexEngineSpec
var gear: int = 1 ## -1 reverse, 0 neutral, 1..N
var shift_cooldown: float = 0.0

func _init(engine_spec: ApexEngineSpec = null) -> void:
	if engine_spec != null:
		spec = engine_spec
	else:
		spec = ApexEngineSpec.new()

func get_ratio() -> float:
	if gear == 0:
		return 0.0
	if gear < 0:
		return -spec.reverse_ratio
	var idx: int = clampi(gear - 1, 0, spec.gear_ratios.size() - 1)
	return spec.gear_ratios[idx]

func shift_up() -> void:
	gear = mini(gear + 1, spec.gear_ratios.size())
	shift_cooldown = 0.22

func shift_down() -> void:
	gear = maxi(gear - 1, -1)
	shift_cooldown = 0.22

func step_auto(coupled_rpm: float, automatic: bool, dt: float) -> void:
	shift_cooldown = maxf(shift_cooldown - dt, 0.0)
	if automatic and gear > 0 and shift_cooldown <= 0.0:
		if coupled_rpm > spec.max_rpm * 0.92 and gear < spec.gear_ratios.size():
			shift_up()
		elif coupled_rpm < spec.max_rpm * 0.37 and gear > 1:
			shift_down()
