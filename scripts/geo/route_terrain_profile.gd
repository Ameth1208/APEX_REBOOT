extends RefCounted
## Offline DEM enrichment of an unchanged flat source. Raw observations are retained.

static func apply(source: Dictionary) -> Dictionary:
	var path: String = str(source.get("elevation_profile_path", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return source
	var geo: Dictionary = source.get("geo", {})
	if not bool(geo.get("is_flat_test", false)) or bool(geo.get("edited_after_import", false)):
		return source
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return source
	if str(parsed.get("source_file_sha256", "")) != str(geo.get("source_file_sha256", "")):
		return source
	var elevations: Array = parsed.get("elevation_m", [])
	var points: Array = source.get("points", [])
	if elevations.size() != points.size() or elevations.is_empty():
		return source
	for elevation: Variant in elevations:
		if not (elevation is float or elevation is int) or not is_finite(float(elevation)):
			return source
	var result: Dictionary = source.duplicate(true)
	var origin: float = float(elevations[0])
	for i: int in elevations.size():
		result.points[i]["y"] = float(elevations[i]) - origin
		result.points[i]["elevation_source"] = str(parsed.source)
		if i < result.get("control_route", []).size():
			result.control_route[i]["ele"] = float(elevations[i])
			result.control_route[i]["elevation_source"] = str(parsed.source)
	result.geo["origin_alt_m"] = origin
	result.geo["elevation_status"] = "complete"
	result.geo["elevation_source"] = str(parsed.source)
	result.geo["elevation_sources"] = [str(parsed.source)]
	result.geo["terrain_elevation_provider"] = str(parsed.source)
	result.geo["terrain_grid_spacing_m"] = int(parsed.resolution_m)
	result.geo["elevation_datum"] = "provider_dem"
	result.geo["is_flat_test"] = false
	result.geo["original_preserved"] = true
	result.geo["surface_status"] = "unverified"
	var grid_path: String = str(source.get("terrain_grid_path", ""))
	if not grid_path.is_empty() and FileAccess.file_exists(grid_path):
		var grid: Variant = JSON.parse_string(FileAccess.get_file_as_string(grid_path))
		if grid is Dictionary and str(grid.get("source_file_sha256", "")) == str(geo.get("source_file_sha256", "")):
			result["terrain_grid"] = grid
	result["requires_elevation"] = false
	result["name"] = str(result.get("name", "Ruta")).replace(" (plano)", "")
	result["description"] = "Carretera original conservada con relieve DEM aproximado de 90 m. Superficie aún sin verificar por tramos."
	return result
