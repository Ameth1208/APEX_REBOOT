class_name PaintController
extends RefCounted
## Paint and liveries affect only explicitly selected, instance-local surfaces.

const PaintShader = preload("res://scripts/vehicles/paint_shader.gd")
var _surfaces: Array[Dictionary] = []
var _shader: Shader
var _profile: Dictionary
var _root: Node3D
var _paint_color := Color.WHITE
var _original_paint := true
var _livery: Dictionary = {}

func configure(root: Node3D, profile: Dictionary) -> void:
	_surfaces.clear()
	_profile = profile
	_root = root
	_shader = PaintShader.create()
	_original_paint = true
	_paint_color = Color(str(profile.get("base_color", "#ffffff")))
	_livery = {}
	_collect(root, profile.get("paint_materials", []))

func apply(color: Color, original: bool = false) -> void:
	_paint_color = color
	_original_paint = original
	_refresh()

func set_livery(id: String) -> void:
	_livery = {}
	for preset in _profile.get("liveries", []):
		if str(preset.get("id", "")) == id and id != "Original":
			_livery = preset
			break
	_refresh()

func surface_count() -> int:
	return _surfaces.size()

func _collect(node: Node, names: Array) -> void:
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var source := node.get_active_material(surface) as BaseMaterial3D
			if source and source.resource_name in names:
				_surfaces.append({"mesh": node, "surface": surface, "source": source,
					"override": node.get_surface_override_material(surface),
					"transform": _relative_transform(node)})
	for child in node.get_children():
		_collect(child, names)

func _relative_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != _root and parent is Node3D:
		result = parent.transform * result
		parent = parent.get_parent()
	return result

func _refresh() -> void:
	for entry in _surfaces:
		var mesh := entry["mesh"] as MeshInstance3D
		if not is_instance_valid(mesh):
			continue
		if _original_paint and _livery.is_empty():
			mesh.set_surface_override_material(entry["surface"], entry["override"])
			continue
		mesh.set_surface_override_material(entry["surface"], _make_material(entry))

func _make_material(entry: Dictionary) -> ShaderMaterial:
	var source := entry["source"] as BaseMaterial3D
	var material := ShaderMaterial.new()
	material.shader = _shader
	var primary := Color(str(_livery.get("primary", "#ffffff"))) if _original_paint else _paint_color
	material.set_shader_parameter("paint_color", primary)
	material.set_shader_parameter("secondary_color", Color(str(_livery.get("secondary", "#ffffff"))))
	material.set_shader_parameter("accent_color", Color(str(_livery.get("accent", "#e52d42"))))
	material.set_shader_parameter("pattern", PaintShader.pattern_id(str(_livery.get("pattern", "original"))))
	material.set_shader_parameter("mesh_to_vehicle", entry["transform"])
	material.set_shader_parameter("vehicle_size", Vector3(
		float(_profile.get("body_width_m", 2.0)), float(_profile.get("body_height_m", 1.2)),
		float(_profile.get("length_m", 4.5))))
	material.set_shader_parameter("source_tint", source.albedo_color)
	material.set_shader_parameter("textured", source.albedo_texture != null)
	if source.albedo_texture:
		material.set_shader_parameter("source_texture", source.albedo_texture)
	material.set_shader_parameter("normal_mapped", source.normal_enabled and source.normal_texture != null)
	if source.normal_enabled and source.normal_texture:
		material.set_shader_parameter("source_normal", source.normal_texture)
		material.set_shader_parameter("normal_strength", source.normal_scale)
	material.set_shader_parameter("preserve_livery", _profile.get("paint_preserve_livery", true))
	material.set_shader_parameter("paint_metallic", source.metallic)
	material.set_shader_parameter("paint_roughness", maxf(source.roughness, 0.18))
	return material
