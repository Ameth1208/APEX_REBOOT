class_name ApexBrushTireModel
extends RefCounted

## Analytical Brush Tire Model for combined longitudinal and lateral slip.
## Computes continuous, smooth tire shear deformation and saturation.

static func calculate_forces(
	slip_ratio: float,
	slip_angle_rad: float,
	camber_rad: float,
	normal_load_n: float,
	effective_mu: float,
	cornering_stiff_n_rad: float,
	longitudinal_stiff_n: float,
	camber_stiff_n_rad: float
) -> Dictionary:
	if normal_load_n <= 0.01 or effective_mu <= 0.001:
		return {
			"fx": 0.0,
			"fy": 0.0,
			"camber_thrust": 0.0,
			"adhesion_state": 1.0
		}
	
	var fz: float = normal_load_n
	var limit: float = effective_mu * fz
	
	# Camber thrust component
	var f_camber: float = camber_stiff_n_rad * sin(camber_rad) * (fz / maxf(cornering_stiff_n_rad / 25.0, 1.0))
	
	# Equivalent combined slip
	var tan_alpha: float = tan(slip_angle_rad)
	var ks: float = longitudinal_stiff_n
	var ky: float = cornering_stiff_n_rad
	
	# Normalized slip components
	var gamma_x: float = ks * slip_ratio / maxf(limit, 1.0)
	var gamma_y: float = ky * tan_alpha / maxf(limit, 1.0)
	var gamma_total: float = sqrt(gamma_x * gamma_x + gamma_y * gamma_y)
	
	var fx: float = 0.0
	var fy: float = 0.0
	var adhesion: float = 1.0
	
	if gamma_total <= 3.0:
		# Partial adhesion region
		var term: float = gamma_total / 3.0
		var factor: float = term * (1.0 - term + (term * term) / 3.0)
		fx = (gamma_x / maxf(gamma_total, 0.0001)) * limit * factor * 3.0
		fy = (gamma_y / maxf(gamma_total, 0.0001)) * limit * factor * 3.0
		adhesion = 1.0 - term
	else:
		# Complete sliding region
		fx = (gamma_x / maxf(gamma_total, 0.0001)) * limit
		fy = (gamma_y / maxf(gamma_total, 0.0001)) * limit
		adhesion = 0.0
		
	fy += f_camber * adhesion
	
	return {
		"fx": fx,
		"fy": fy,
		"camber_thrust": f_camber,
		"adhesion_state": adhesion
	}
