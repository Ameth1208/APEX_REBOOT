class_name GeoServices
extends RefCounted
## Providers can be replaced without changing source. See REAL_ROUTES.md.

const USER_AGENT: String = "APEX-Reboot/0.2 (Godot geographic track editor)"
const MAP_URL: String = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
# ArcGIS REST tile order is level / row (y) / column (x).
const SATELLITE_URL: String = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}.jpg"
const SRTM_URL: String = "https://api.opentopodata.org/v1/srtm30m"
const COPERNICUS_URL: String = "https://api.open-meteo.com/v1/elevation"
const Proxy = preload("res://scripts/geo/network/geo_proxy.gd")

static func configure_request(request: HTTPRequest, url: String = "") -> bool:
	if OS.has_feature("web"):
		return true # Browser networking owns its proxy and TLS configuration.
	if Proxy.bypass(url, setting("no_proxy", _environment("NO_PROXY"))):
		request.set_http_proxy("", -1)
		request.set_https_proxy("", -1)
		return true
	var http: Dictionary = Proxy.parse(setting("http_proxy", _environment("HTTP_PROXY")))
	var https: Dictionary = Proxy.parse(setting("https_proxy", _environment("HTTPS_PROXY")))
	if not http["ok"] or not https["ok"]:
		return false
	request.set_http_proxy(str(http["host"]), int(http["port"]))
	request.set_https_proxy(str(https["host"]), int(https["port"]))
	return true

static func _environment(name: String) -> String:
	var value: String = OS.get_environment(name)
	return value if not value.is_empty() else OS.get_environment(name.to_lower())

static func setting(key: String, fallback: String) -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://geo_services.cfg") == OK:
		return str(config.get_value("providers", key, fallback))
	return fallback

static func headers() -> PackedStringArray:
	return PackedStringArray() if OS.has_feature("web") else PackedStringArray(["User-Agent: " + USER_AGENT])

static func source(provider: int) -> String:
	return "SRTM ~30 m · Open Topo Data" if provider == 0 else "Copernicus GLO-90 · Open-Meteo"
