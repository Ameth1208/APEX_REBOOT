class_name ApexMotorcycleForkSolver
extends ApexSuspensionSolver

## Front telescopic fork for motorcycles, accounting for rake angle,
## anti-dive geometry, and progressive air spring cushion.

var rake_deg: float = 24.5

func _init(suspension_spec: ApexSuspensionSpec = null, rake: float = 24.5) -> void:
	super._init(suspension_spec)
	rake_deg = rake

func solve_fork(vertical_compression: float, vertical_rate: float) -> Dictionary:
	var rake_rad: float = deg_to_rad(rake_deg)
	var cos_rake: float = cos(rake_rad)
	var stroke: float = vertical_compression / maxf(cos_rake, 0.5)
	var stroke_rate: float = vertical_rate / maxf(cos_rake, 0.5)
	
	var res: Dictionary = solve_forces(stroke, stroke_rate)
	# Air chamber pressure builds exponentially near bottom-out
	var stroke_ratio: float = stroke / maxf(spec.travel_m, 0.05)
	if stroke_ratio > 0.70:
		var air_cushion: float = spec.spring_rate_n_m * pow(stroke_ratio - 0.70, 2.0) * 3.0
		res["bump_stop_force"] += air_cushion
		res["total_force"] += air_cushion
	return res
