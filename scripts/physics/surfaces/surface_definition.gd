class_name ApexSurfaceDefinition
extends RefCounted

## Material parameters for terrain and road surfaces.

var name: String = "asphalt"
var mu: float = 1.08
var rolling_resistance: float = 0.015
var wet_grip_loss: float = 0.36
var bump_amplitude: float = 0.0

const SURFACES: Dictionary = {
	"asphalt": {"mu": 1.08, "rolling": 0.015, "wet_loss": 0.36, "bump": 0.0},
	"concrete": {"mu": 0.98, "rolling": 0.018, "wet_loss": 0.35, "bump": 0.002},
	"gravel": {"mu": 0.58, "rolling": 0.055, "wet_loss": 0.16, "bump": 0.015},
	"grass": {"mu": 0.42, "rolling": 0.075, "wet_loss": 0.45, "bump": 0.025},
	"sand": {"mu": 0.38, "rolling": 0.120, "wet_loss": 0.10, "bump": 0.035},
	"dirt": {"mu": 0.56, "rolling": 0.048, "wet_loss": 0.34, "bump": 0.020}
}

static func get_properties(surface_name: String) -> Dictionary:
	return SURFACES.get(surface_name, SURFACES["asphalt"])

static func get_friction(surface_name: String, wetness: float, grip_scale: float) -> float:
	var props: Dictionary = get_properties(surface_name)
	var base_mu: float = float(props["mu"])
	var wet_loss: float = float(props["wet_loss"])
	return base_mu * (1.0 - clampf(wetness, 0.0, 1.0) * wet_loss) * maxf(grip_scale, 0.1)

static func get_rolling_resistance(surface_name: String) -> float:
	var props: Dictionary = get_properties(surface_name)
	return float(props["rolling"])
