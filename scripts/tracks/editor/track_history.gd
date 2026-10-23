class_name TrackHistory
extends RefCounted
## Original geographic arrays are immutable; don't duplicate 20k GPS fixes per drag.

static func snapshot(definition: Dictionary) -> Dictionary:
	var copy: Dictionary = definition.duplicate(false)
	for key: String in definition:
		if key in ["raw_route", "control_route", "source_auxiliary_geojson_features", "source_properties", "conversion"]:
			continue
		if definition[key] is Dictionary or definition[key] is Array:
			copy[key] = definition[key].duplicate(true)
	return copy
