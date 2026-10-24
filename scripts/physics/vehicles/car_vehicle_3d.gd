class_name ApexCarVehicle3D
extends ApexVehicle3D

## Specialized 4-wheel car physics implementation with Ackermann steering,
## dual anti-roll bars, and limited-slip differential.

func _ready() -> void:
	is_motorcycle = false
	super._ready()
