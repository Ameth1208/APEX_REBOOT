extends SceneTree
## Read-only audit of imported wheel centres before physical hub snapping.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for path: String in ApexCatalog.entries("vehicles"):
		var profile: Dictionary = ApexCatalog.read_json(path)
		profile["align_wheels_to_physics"] = false
		var visual := VehicleVisual.new()
		root.add_child(visual)
		var started := Time.get_ticks_msec()
		visual.setup(profile)
		var offsets: Array[Vector3] = preload("res://scripts/physics/wheel_layout.gd").offsets(profile, profile.kind == "motorcycle")
		print("ALIGN ", profile.id, " setup_ms=", Time.get_ticks_msec() - started, " bounds=", visual.dimensions)
		for wheel: Dictionary in visual._wheels:
			print("  hub ", wheel.index, " imported=", wheel.base_position, " target=", offsets[wheel.index], " displacement=", Vector2(wheel.base_position.x - offsets[wheel.index].x, wheel.base_position.z - offsets[wheel.index].z))
		visual.free()
	quit()
