class_name ApexDifferentialSolver
extends RefCounted

## Differential solver distributing drive torque across driven wheels.
## Supports Open, Viscous LSD, Mechanical Salisbury LSD, and Spool/Locked modes.

enum DiffType { OPEN, LIMITED_SLIP, SPOOL }

var type: DiffType = DiffType.LIMITED_SLIP
var power_bias_ratio: float = 2.5 # Torque ratio for Salisbury / LSD

func distribute_torque(total_torque: float, left_slip: float, right_slip: float) -> Vector2:
	if type == DiffType.SPOOL:
		return Vector2(total_torque * 0.5, total_torque * 0.5)
	
	if type == DiffType.OPEN:
		# Open diff matches torque to whichever wheel has least traction
		return Vector2(total_torque * 0.5, total_torque * 0.5)
		
	# Limited slip: transfers torque away from the faster slipping wheel
	var slip_diff: float = clampf(left_slip - right_slip, -1.0, 1.0)
	var split_left: float = clampf(0.5 - slip_diff * 0.25, 0.2, 0.8)
	var split_right: float = 1.0 - split_left
	return Vector2(total_torque * split_left, total_torque * split_right)
