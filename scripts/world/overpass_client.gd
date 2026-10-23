class_name OverpassClient
extends RefCounted

## Minimal synchronous Overpass API client for terrain generation.

const ENDPOINT: String = "https://overpass-api.de/api/interpreter"

static func fetch_bbox(south: float, west: float, north: float, east: float) -> Dictionary:
	var query: String = "[out:json][timeout:25];\n(\n  way[\"landuse\"](%f,%f,%f,%f);\n  way[\"natural\"](%f,%f,%f,%f);\n  way[\"building\"](%f,%f,%f,%f);\n  way[\"waterway\"](%f,%f,%f,%f);\n);\nout body;\n>;\nout skel qt;" % [south, west, north, east, south, west, north, east, south, west, north, east, south, west, north, east]
	var http: HTTPClient = HTTPClient.new()
	var err: int = http.connect_to_host("overpass-api.de", 443)
	if err != OK:
		return {"error": "connect_failed"}
	# Wait for connection
	var tries: int = 0
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		tries += 1
		if tries > 200:
			return {"error": "connect_timeout"}
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"error": "not_connected"}
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/x-www-form-urlencoded", "Accept: application/json"])
	var body: String = "data=" + query.uri_encode()
	err = http.request(HTTPClient.METHOD_POST, "/api/interpreter", headers, body)
	if err != OK:
		return {"error": "request_failed"}
	tries = 0
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		tries += 1
		if tries > 200:
			return {"error": "request_timeout"}
	# Read response
	var response_body: PackedByteArray = PackedByteArray()
	tries = 0
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk: PackedByteArray = http.read_response_body_chunk()
		if chunk.size() > 0:
			response_body.append_array(chunk)
		tries += 1
		if tries > 2000:
			return {"error": "body_timeout"}
	http.close()
	var text: String = response_body.get_string_from_utf8()
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(text)
	if parse_err != OK:
		return {"error": "parse_failed", "raw": text.substr(0, 200)}
	return json.data if (json.data is Dictionary) else {"error": "not_dict"}