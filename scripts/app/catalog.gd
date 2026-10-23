class_name ApexCatalog
extends RefCounted

const PAINT_NAMES := ["Original", "Rojo", "Azul", "Amarillo", "Blanco", "Negro", "Verde", "Plata"]
const PAINT_COLORS := [Color.WHITE, Color("d42a35"), Color("166bc8"), Color("efc838"), Color("edeff2"), Color("15191e"), Color("238462"), Color("aab7c4")]

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("No se encuentra: " + path)
		return {}
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return result if result is Dictionary else {}

static func vehicle(index: int) -> Dictionary:
	var paths: Array = entries("vehicles")
	return read_json(str(paths[clampi(index, 0, paths.size() - 1)])) if not paths.is_empty() else {}

static func track(index: int) -> Dictionary:
	var paths: Array = entries("tracks")
	return read_json(str(paths[clampi(index, 0, paths.size() - 1)])) if not paths.is_empty() else {}

static func entries(kind: String) -> Array:
	var path: String = "res://data/%s/catalog.json" % kind
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []

static func paint_color(name: String) -> Color:
	var index: int = PAINT_NAMES.find(name)
	return PAINT_COLORS[maxi(index, 0)]
