extends RefCounted
## Correct explicitly audited export defects without changing source assets.

static func apply(root: Node, rules: Array) -> void:
	if rules.is_empty():
		return
	var replacements: Dictionary = {}
	_visit(root, rules, replacements)

static func _visit(node: Node, rules: Array, replacements: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var source := node.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			for rule: Dictionary in rules:
				if source.resource_name not in rule.get("names", []):
					continue
				var key := source.get_instance_id()
				if not replacements.has(key):
					replacements[key] = _repair(source, rule)
				node.set_surface_override_material(surface, replacements[key])
				break
	for child in node.get_children():
		_visit(child, rules, replacements)

static func _repair(source: BaseMaterial3D, rule: Dictionary) -> BaseMaterial3D:
	var result := source.duplicate() as BaseMaterial3D
	result.albedo_color = Color(str(rule.get("color", "#ffffff")))
	if rule.get("discard_white_albedo_map", true):
		result.albedo_texture = null
	result.metallic = float(rule.get("metallic", 0.0))
	result.roughness = float(rule.get("roughness", 0.5))
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if result.albedo_color.a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	return result
