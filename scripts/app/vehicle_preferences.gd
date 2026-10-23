class_name ApexVehiclePreferences
extends RefCounted
## Remember each vehicle's own paint and livery without changing source materials.

static func remember(values: Dictionary) -> void:
	var looks: Dictionary = values.get("vehicle_looks", {})
	looks[str(values.vehicle)] = {"paint": str(values.paint), "livery": str(values.livery)}
	values.vehicle_looks = looks

static func restore(values: Dictionary) -> void:
	var saved: Dictionary = values.get("vehicle_looks", {}).get(str(values.vehicle), {})
	values.paint = str(saved.get("paint", "Original"))
	values.livery = str(saved.get("livery", "Original"))
	var found: bool = values.livery == "Original"
	for item: Dictionary in ApexCatalog.vehicle(int(values.vehicle)).get("liveries", []):
		found = found or str(item.id) == values.livery
	if not found:
		values.livery = "Original"
	if not str(values.paint) in ApexCatalog.PAINT_NAMES:
		values.paint = "Original"
