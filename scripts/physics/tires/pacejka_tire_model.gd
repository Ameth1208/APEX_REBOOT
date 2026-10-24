class_name ApexPacejkaTireModel
extends RefCounted

## Implementation of Hans Pacejka's Magic Formula for pure and combined slip.
## y(x) = D * sin(C * atan(B*x - E * (B*x - atan(B*x))))

static func magic_formula(x: float, B: float, C: float, D: float, E: float) -> float:
	var bx: float = B * x
	var atan_bx: float = atan(bx)
	return D * sin(C * atan(bx - E * (bx - atan_bx)))

## Evaluates pure lateral force Fy as a function of slip angle alpha (rad)
static func pure_lateral_force(alpha_rad: float, fz_n: float, mu: float, cornering_stiff: float) -> float:
	if fz_n <= 0.01:
		return 0.0
	var D: float = mu * fz_n
	var C: float = 1.30 # Lateral shape factor
	var B: float = cornering_stiff / maxf(C * D, 0.01) # Stiffness factor
	var E: float = -0.10 # Curvature factor
	return magic_formula(alpha_rad, B, C, D, E)

## Evaluates pure longitudinal force Fx as a function of slip ratio kappa
static func pure_longitudinal_force(kappa: float, fz_n: float, mu: float, longitudinal_stiff: float) -> float:
	if fz_n <= 0.01:
		return 0.0
	var D: float = mu * fz_n
	var C: float = 1.65 # Longitudinal shape factor
	var B: float = longitudinal_stiff / maxf(C * D, 0.01)
	var E: float = 0.15
	return magic_formula(kappa, B, C, D, E)
