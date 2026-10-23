extends RefCounted
## Shared primitive colliders for scenery; meshes may stay batched in MultiMesh.

static func group(parent: Node3D, title: String, surface: String = "concrete") -> StaticBody3D:
	var existing: Node = parent.get_node_or_null(NodePath(title))
	if existing is StaticBody3D:
		return existing
	var body: StaticBody3D = StaticBody3D.new()
	body.name = title
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("surface", surface)
	body.set_meta("is_road", false)
	body.set_meta("obstacle", true)
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.60
	material.bounce = 0.02
	body.physics_material_override = material
	parent.add_child(body)
	return body

static func box(body: StaticBody3D, pose: Transform3D, size: Vector3) -> void:
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size * pose.basis.get_scale().abs()
	collider.shape = shape
	collider.transform = Transform3D(pose.basis.orthonormalized(), pose.origin)
	body.add_child(collider)

static func cylinder(body: StaticBody3D, pose: Transform3D, radius: float, height: float) -> void:
	var collider: CollisionShape3D = CollisionShape3D.new()
	var scale: Vector3 = pose.basis.get_scale().abs()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius * maxf(scale.x, scale.z)
	shape.height = height * scale.y
	collider.shape = shape
	collider.transform = Transform3D(pose.basis.orthonormalized(), pose.origin)
	body.add_child(collider)
