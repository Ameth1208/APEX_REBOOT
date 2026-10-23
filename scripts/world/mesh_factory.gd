class_name ApexMesh
extends RefCounted

static func material(color: Color, metallic: float = 0.0, roughness: float = 0.65) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result

static func box(parent: Node3D, position: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	instance.mesh = shape
	instance.material_override = mat
	instance.position = position
	parent.add_child(instance)
	return instance

static func cylinder(parent: Node3D, position: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top
	shape.height = height
	shape.radial_segments = 32
	instance.mesh = shape
	instance.material_override = mat
	instance.position = position
	parent.add_child(instance)
	return instance
