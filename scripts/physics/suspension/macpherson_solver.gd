class_name ApexMacPhersonSolver
extends ApexSuspensionSolver

## MacPherson strut suspension solver. Moderate camber gain with compression,
## typical on road sedans and hot hatches.

func _init(suspension_spec: ApexSuspensionSpec = null) -> void:
	super._init(suspension_spec)
	if spec.camber_gain_deg_per_m == 0.0:
		spec.camber_gain_deg_per_m = 8.0
