extends Node3D
## Original full-face helmet: open shell aperture and a transparent curved visor.

const RADII := Vector3(0.145, 0.165, 0.165)

func build() -> void:
	var shell := _material(Color("d6dce3"), 0.30, 0.23)
	shell.vertex_color_use_as_albedo = true
	_add(_surface(false), shell, "Shell")
	var glass := _material(Color(0.08, 0.14, 0.20, 0.82), 0.24, 0.14)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add(_surface(true), glass, "Visor")

func _surface(visor: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var rows := 24
	var columns := 48
	for row in rows + 1:
		var latitude := lerpf(-PI / 2.0, PI / 2.0, float(row) / rows)
		if visor:
			latitude = lerpf(-0.21, 0.47, float(row) / rows)
		for column in columns + 1:
			var longitude := lerpf(-PI, PI, float(column) / columns)
			if visor:
				longitude = lerpf(-1.07, 1.07, float(column) / columns)
			var direction := Vector3(sin(longitude) * cos(latitude), sin(latitude), -cos(longitude) * cos(latitude))
			vertices.append(direction * RADII * (1.008 if visor else 1.0))
			normals.append((direction / RADII).normalized())
			var stripe := absf(direction.x) > 0.10 and absf(direction.x) < 0.23 and latitude > 0.3
			colors.append(Color("2385bb") if stripe else Color.WHITE)
	for row in rows:
		for column in columns:
			var latitude := lerpf(-PI / 2.0, PI / 2.0, (float(row) + 0.5) / rows)
			var longitude := lerpf(-PI, PI, (float(column) + 0.5) / columns)
			if not visor and absf(longitude) < 1.04 and latitude > -0.21 and latitude < 0.47:
				continue
			var i := row * (columns + 1) + column
			indices.append_array(PackedInt32Array([i, i + 1, i + columns + 1, i + 1, i + columns + 2, i + columns + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _add(mesh: ArrayMesh, material: Material, label: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
