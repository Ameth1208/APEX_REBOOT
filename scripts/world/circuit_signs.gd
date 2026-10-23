class_name ApexCircuitSigns
extends RefCounted
## Braking-reference boards mark substantial bends; they are cues, not AI targets.

const Obstacles = preload("res://scripts/physics/static_obstacle_collision.gd")

static func build(parent: Node3D, track: Node3D) -> void:
	var white: StandardMaterial3D = ApexMesh.material(Color("cecdc4"), 0.0, 0.75)
	var dark: StandardMaterial3D = ApexMesh.material(Color("292d2f"), 0.1, 0.65)
	var solid: StaticBody3D = Obstacles.group(parent, "BrakingMarkerCollisions")
	var space: PhysicsDirectSpaceState3D = parent.get_world_3d().direct_space_state
	var last_corner: float = -250.0
	var length_m: float = float(track.get_length())
	for index: int in range(ceili(length_m / 40.0)):
		var distance: float = float(index) * 40.0
		if distance - last_corner < 240.0:
			continue
		var sample: Dictionary = track.sample_at(distance)
		var future: Dictionary = track.sample_at(minf(distance + 25.0, length_m))
		if Vector3(sample.forward).angle_to(future.forward) < 0.14:
			continue
		last_corner = distance
		var side: float = 1.0 if Vector3(sample.forward).cross(future.forward).y >= 0.0 else -1.0
		for metres: int in [150, 100, 50]:
			if not bool(track.closed) and distance < float(metres):
				continue
			var approach: Dictionary = track.sample_at(distance - float(metres))
			var offset: float = float(approach.width) * 0.5 + float(track.definition.runoff_width) + 2.1
			var point: Vector3 = approach.position + approach.right * side * offset
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 40, point - Vector3.UP * 80, 1))
			if hit.is_empty() or hit.collider.get_meta("is_road", false) or hit.collider.get_meta("obstacle", false):
				continue
			var basis: Basis = Basis(approach.right, approach.normal, -approach.forward).orthonormalized()
			_board(parent, solid, Transform3D(basis, hit.position), metres, white, dark)

static func _board(parent: Node3D, solid: StaticBody3D, pose: Transform3D, metres: int,
		white: Material, dark: Material) -> void:
	var root: Node3D = Node3D.new()
	root.name = "BrakeReference" + str(metres)
	root.transform = pose
	parent.add_child(root)
	ApexMesh.box(root, Vector3(0, 0.75, 0), Vector3(0.92, 1.2, 0.09), dark).visibility_range_end = 260.0
	ApexMesh.box(root, Vector3(0, 0.75, 0.055), Vector3(0.80, 1.08, 0.024), white).visibility_range_end = 260.0
	ApexMesh.box(root, Vector3(0, 0.26, -0.05), Vector3(0.09, 0.52, 0.1), dark).visibility_range_end = 260.0
	var label: Label3D = Label3D.new()
	label.text = str(metres)
	label.font_size = 62
	label.outline_size = 0
	label.pixel_size = 0.008
	label.modulate = Color("171c20")
	label.position = Vector3(0, 0.80, 0.085)
	label.visibility_range_end = 240.0
	root.add_child(label)
	Obstacles.box(solid, pose.translated_local(Vector3(0, 0.75, 0)), Vector3(0.92, 1.2, 0.12))
