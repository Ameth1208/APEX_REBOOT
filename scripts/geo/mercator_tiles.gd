class_name MercatorTiles
extends RefCounted
## Coordinates for the visible map only; driving uses local metric coordinates.

static func pixel(lat: float, lon: float, level: int) -> Vector2:
	var scale: float = 256.0 * pow(2.0, level)
	var latitude: float = deg_to_rad(clampf(lat, -85.05112878, 85.05112878))
	return Vector2((lon + 180.0) / 360.0,
		(1.0 - log(tan(latitude) + 1.0 / cos(latitude)) / PI) * 0.5) * scale

static func coordinate(point: Vector2, level: int) -> Vector2:
	var scale: float = 256.0 * pow(2.0, level)
	return Vector2(rad_to_deg(atan(sinh(PI * (1.0 - 2.0 * point.y / scale)))),
		fposmod(point.x / scale * 360.0, 360.0) - 180.0)

static func tile_key(level: int, x: int, y: int) -> String:
	return "%d/%d/%d" % [level, posmod(x, 1 << level), y]
