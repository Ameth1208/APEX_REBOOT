class_name GeoProxy
extends RefCounted
## HTTP CONNECT proxies are opt-in through environment/user configuration.
## Never print proxy URLs: they may contain credentials in other environments.

static func parse(value: String) -> Dictionary:
	var authority: String = value.strip_edges().trim_suffix("/")
	if authority.is_empty():
		return {"ok": true, "host": "", "port": -1}
	if "://" in authority:
		if not authority.begins_with("http://"):
			return {"ok": false}
		authority = authority.trim_prefix("http://")
	if "@" in authority or "/" in authority or " " in authority or "\n" in authority:
		return {"ok": false}
	var host: String
	var port_text: String = "80"
	if authority.begins_with("["):
		var closing: int = authority.find("]")
		if closing < 0:
			return {"ok": false}
		host = authority.substr(1, closing - 1)
		var tail: String = authority.substr(closing + 1)
		if not tail.is_empty():
			if not tail.begins_with(":"):
				return {"ok": false}
			port_text = tail.trim_prefix(":")
	else:
		if authority.get_slice_count(":") > 2:
			return {"ok": false}
		host = authority.get_slice(":", 0)
		if ":" in authority:
			port_text = authority.get_slice(":", 1)
	if host.is_empty() or not port_text.is_valid_int() or int(port_text) < 1 or int(port_text) > 65535:
		return {"ok": false}
	return {"ok": true, "host": host, "port": int(port_text)}

static func bypass(url: String, no_proxy: String) -> bool:
	var authority: String = url.get_slice("://", 1).get_slice("/", 0).to_lower()
	var host: String = authority.get_slice(":", 0)
	if authority.begins_with("["):
		host = authority.substr(1, authority.find("]") - 1)
	if host in ["localhost", "127.0.0.1", "::1"]:
		return true
	for raw: String in no_proxy.split(",", false):
		var domain: String = raw.strip_edges().to_lower().trim_prefix(".")
		if domain == "*":
			return true
		if domain.begins_with("["):
			domain = domain.substr(1, domain.find("]") - 1)
		else:
			domain = domain.get_slice(":", 0)
		if not domain.is_empty() and (host == domain or host.ends_with("." + domain)):
			return true
	return false
