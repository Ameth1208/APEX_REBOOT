class_name GeoProjection
extends RefCounted
## Local WGS84 differential projection: east +X, south +Z, height +Y, metres.
## This is a bounded local approximation, not a survey/UTM coordinate operation.

const Values = preload("res://scripts/geo/geo_value.gd")
const SEMI_MAJOR_M: float = 6378137.0
const INVERSE_FLATTENING: float = 298.257223563
const MAX_EXTENT_M: float = 40000.0
const MAX_LATITUDE_DEG: float = 85.0

static func make_origin(lat: float, lon: float, alt: Variant = null) -> Dictionary:
	return {"origin_lat": lat, "origin_lon": lon, "origin_alt_m": alt,
		"projection": "wgs84_local", "horizontal_datum": "WGS84",
		"axes": "x east, y up, z south", "max_extent_m": MAX_EXTENT_M}

static func project(lat: float, lon: float, ele: Variant, geo: Dictionary) -> Dictionary:
	var valid: Dictionary = validate_origin(geo)
	if not valid["ok"]:
		return valid
	if not _valid_coordinate(lat, lon):
		return Values.fail("Latitud o longitud inválida; se requieren grados WGS84 finitos.")
	if absf(lat) >= MAX_LATITUDE_DEG:
		return Values.fail("La proyección local no admite latitudes polares (|lat| >= 85°).")
	var lat0: float = float(geo["origin_lat"])
	var lon_delta: float = lon - float(geo["origin_lon"])
	if absf(lon_delta) > 180.0:
		return Values.fail("La ruta cruza el antimeridiano; divide el trazado antes de importarlo.")
	var radii: Vector2 = _radii(lat0)
	var x: float = deg_to_rad(lon_delta) * radii.x * cos(deg_to_rad(lat0))
	var z: float = -deg_to_rad(lat - lat0) * radii.y
	if Vector2(x, z).length() > MAX_EXTENT_M:
		return Values.fail("El trazado supera el alcance local de 40 km; importa un tramo menor.")
	if ele != null and Values.number(ele) == null:
		return Values.fail("Cota inválida; usa metros finitos o null para una cota desconocida.")
	var y: Variant = null
	if ele != null and geo.get("origin_alt_m") != null:
		y = float(ele) - float(geo["origin_alt_m"])
	return {"ok": true, "error": "", "x": x, "y": y, "z": z}

static func inverse(x: float, z: float, geo: Dictionary, y: Variant = null) -> Dictionary:
	var valid: Dictionary = validate_origin(geo)
	if not valid["ok"]:
		return valid
	if not is_finite(x) or not is_finite(z) or Vector2(x, z).length() > MAX_EXTENT_M:
		return Values.fail("Posición local inválida o fuera del alcance de 40 km.")
	if y != null and Values.number(y) == null:
		return Values.fail("Altura local inválida.")
	var lat0: float = float(geo["origin_lat"])
	var radii: Vector2 = _radii(lat0)
	var lat: float = lat0 - rad_to_deg(z / radii.y)
	var lon: float = float(geo["origin_lon"]) + rad_to_deg(x / (radii.x * cos(deg_to_rad(lat0))))
	if not _valid_coordinate(lat, lon) or absf(lat) >= MAX_LATITUDE_DEG:
		return Values.fail("La conversión cruzaría el antimeridiano o una zona polar.")
	var ele: Variant = null
	if y != null and geo.get("origin_alt_m") != null:
		ele = float(geo["origin_alt_m"]) + float(y)
	return {"ok": true, "error": "", "lat": lat, "lon": lon, "ele": ele}

static func validate_origin(geo: Dictionary) -> Dictionary:
	if Values.number(geo.get("origin_lat")) == null or Values.number(geo.get("origin_lon")) == null:
		return Values.fail("Falta un origen geográfico WGS84 válido.")
	var lat: float = float(geo["origin_lat"])
	var lon: float = float(geo["origin_lon"])
	if not _valid_coordinate(lat, lon) or absf(lat) >= MAX_LATITUDE_DEG:
		return Values.fail("Origen fuera de WGS84 local; no se admiten latitudes polares.")
	if geo.get("origin_alt_m") != null and Values.number(geo["origin_alt_m"]) == null:
		return Values.fail("Cota del origen inválida.")
	return {"ok": true, "error": ""}

static func _valid_coordinate(lat: float, lon: float) -> bool:
	return is_finite(lat) and is_finite(lon) and absf(lat) <= 90.0 and absf(lon) <= 180.0

static func _radii(lat_deg: float) -> Vector2:
	var flattening: float = 1.0 / INVERSE_FLATTENING
	var e2: float = flattening * (2.0 - flattening)
	var denominator: float = 1.0 - e2 * pow(sin(deg_to_rad(lat_deg)), 2.0)
	return Vector2(SEMI_MAJOR_M / sqrt(denominator),
		SEMI_MAJOR_M * (1.0 - e2) / pow(denominator, 1.5))
