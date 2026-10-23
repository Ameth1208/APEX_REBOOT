class_name GeoValue
extends RefCounted
## Strict numbers keep missing/invalid coordinates distinct from a legitimate zero.

static func number(value: Variant) -> Variant:
	if not (value is int or value is float):
		return null
	var result: float = float(value)
	return result if is_finite(result) else null

static func text_number(value: String) -> Variant:
	var clean: String = value.strip_edges()
	return number(clean.to_float()) if clean.is_valid_float() else null

static func fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "warnings": []}
