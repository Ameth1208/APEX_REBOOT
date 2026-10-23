extends RefCounted
## Imported GLB/FBX scenes and OBJ meshes share the same visual pipeline.

static func instantiate(path: String) -> Node3D:
	var resource := load(path)
	if resource is PackedScene:
		var instance: Node = (resource as PackedScene).instantiate()
		if instance is Node3D:
			return instance as Node3D
		instance.free()
	elif resource is Mesh:
		var instance := MeshInstance3D.new()
		instance.name = "ImportedMesh"
		instance.mesh = resource as Mesh
		return instance
	push_error("Vehicle model must be a 3D scene or Mesh: " + path)
	return null
