class_name ApexMotorcycleVehicle3D
extends ApexVehicle3D

## Specialized 2-wheel motorcycle physics implementation with telescopic fork,
## dynamic lean angle equilibrium, rider mass shift, and natural wheelie/stoppie limits.

func _ready() -> void:
	is_motorcycle = true
	super._ready()
