extends RefCounted
## Imported GLB/FBX scenes and OBJ meshes share the same visual pipeline.

const MAX_CACHED_MODELS: int = 2
static var _resources: Dictionary = {}

static func instantiate(path: String) -> Node3D:
	# Keep a bounded strong reference: otherwise the PackedScene can leave Godot's
	# weak resource cache after instantiation and get loaded again for every rival.
	var resource: Resource = _resources.get(path)
	if resource == null:
		resource = load(path)
		if resource != null:
			if _resources.size() >= MAX_CACHED_MODELS:
				_resources.erase(_resources.keys()[0])
			_resources[path] = resource
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
