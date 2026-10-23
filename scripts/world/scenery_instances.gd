class_name ApexSceneryInstances
extends RefCounted
## Spatial batches keep distant vegetation out of the visible draw budget.

static func build(parent: Node3D, title: String, mesh: Mesh, material: Material,
		transforms: Array[Transform3D], distance: float, shadows: bool = true) -> void:
	var groups: Dictionary = {}
	for pose: Transform3D in transforms:
		var key: Vector2i = Vector2i(floori(pose.origin.x / 160.0), floori(pose.origin.z / 160.0))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(pose)
	for key: Vector2i in groups:
		var poses: Array = groups[key]
		var center: Vector3 = Vector3.ZERO
		for pose: Transform3D in poses:
			center += pose.origin
		center /= float(poses.size())
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = title
		instance.position = center
		instance.multimesh = MultiMesh.new()
		instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		instance.multimesh.mesh = mesh
		instance.multimesh.instance_count = poses.size()
		instance.material_override = material
		instance.visibility_range_end = distance
		instance.set_meta("quality_visibility_range", distance)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for index: int in range(poses.size()):
			var pose: Transform3D = poses[index]
			pose.origin -= center
			instance.multimesh.set_instance_transform(index, pose)
		parent.add_child(instance)
