class_name ApexRacingLine
extends MeshInstance3D

func build(track: Node3D, planner: ApexSpeedPlanner) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = ceili(track.get_length() / 5.0)
	for i in count:
		var a: Dictionary = track.sample_at(i * 5.0)
		var b: Dictionary = track.sample_at((i + 1) * 5.0)
		var speed: float = planner.target_at(i * 5.0)
		var following: float = planner.target_at(i * 5.0 + 30)
		var tint := Color("91d760") if speed > 30 else Color("f1c761")
		if following < speed - 1.0:
			tint = Color("e5734e")
		var points: Array[Vector3] = [a.position - a.right * 0.10 + a.normal * 0.04,
			a.position + a.right * 0.10 + a.normal * 0.04, b.position + b.right * 0.10 + b.normal * 0.04,
			b.position - b.right * 0.10 + b.normal * 0.04]
		for j in [0, 2, 1, 0, 3, 2]:
			surface.set_color(tint)
			surface.add_vertex(points[j])
	surface.generate_normals()
	mesh = surface.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
