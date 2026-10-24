class_name ApexDoubleWishboneSolver
extends ApexSuspensionSolver

## Double-wishbone suspension solver. High camber compensation during roll,
## progressive motion ratio, common on GT race cars and supercars.

func _init(suspension_spec: ApexSuspensionSpec = null) -> void:
	super._init(suspension_spec)
	if spec.camber_gain_deg_per_m == 0.0:
		spec.camber_gain_deg_per_m = 16.0

## Progressive spring curve as suspension approaches deep travel
func solve_forces(compression: float, compression_rate: float) -> Dictionary:
	var res: Dictionary = super.solve_forces(compression, compression_rate)
	var travel_ratio: float = clampf(compression / maxf(spec.travel_m, 0.01), 0.0, 1.0)
	if travel_ratio > 0.5:
		var progressive_factor: float = 1.0 + (travel_ratio - 0.5) * 0.4
		res["total_force"] *= progressive_factor
	return res
