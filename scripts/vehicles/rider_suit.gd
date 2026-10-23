extends RefCounted
## Runtime clothing/visibility masks use bind-pose vertices, independent of skinning.
## The artist's source buffers/textures are never rewritten.

const SUIT_SHADER = preload("res://scripts/vehicles/rider_suit.gdshader")
var _material: ShaderMaterial
var _face_parts: Array[MeshInstance3D] = []

func configure(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		mesh_node.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 4, 3))
		if str(node.name) != "SuperHero_Male":
			_face_parts.append(mesh_node)
			continue
		var source := mesh_node.mesh
		var original := source.surface_get_material(0) as StandardMaterial3D
		_material = ShaderMaterial.new()
		_material.shader = SUIT_SHADER
		_material.set_shader_parameter("skin_texture", original.albedo_texture)
		_material.set_shader_parameter("skin_normal", original.normal_texture)
		var clothed := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var anatomy := PackedVector2Array()
			for point in points:
				anatomy.append(Vector2(point.x, point.y))
			arrays[Mesh.ARRAY_TEX_UV2] = anatomy
			clothed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh_node.mesh = clothed
		mesh_node.material_override = _material

func set_cockpit_view(enabled: bool) -> void:
	if _material:
		_material.set_shader_parameter("cockpit", enabled)
	for part in _face_parts:
		part.visible = not enabled
