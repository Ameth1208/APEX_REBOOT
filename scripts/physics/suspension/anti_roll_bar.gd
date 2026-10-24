class_name ApexAntiRollBar
extends RefCounted

## Anti-roll bar (ARB / sway bar) calculating elastic load transfer
## between left and right wheels on a single axle.
## F_arb = k_arb * (x_left - x_right)

var stiffness_n_m: float = 18000.0

func _init(stiffness: float = 18000.0) -> void:
	stiffness_n_m = stiffness

func calculate_transfer(compression_left: float, compression_right: float) -> float:
	# Positive transfer means left is compressed more than right,
	# so left pushes upward more (increasing normal load) and right pushes less.
	return stiffness_n_m * (compression_left - compression_right)
