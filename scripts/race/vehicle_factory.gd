class_name ApexVehicleFactory
extends RefCounted

static func create(parent: Node3D, profile: Dictionary, settings: Dictionary, pose: Transform3D, paint: String, name_tag: String) -> RigidBody3D:
	var body: RigidBody3D = load("res://scripts/vehicles/vehicle_body.gd").new()
	body.name = name_tag
	body.configure(profile)
	body.set_assist_mode(str(settings.get("assists", "Sport")))
	body.auto_transmission = bool(settings.get("automatic", true))
	body.wetness = float(settings.get("wetness", 0.0))
	body.aero_scale = float(settings.get("aero", 1.0))
	body.grip_factor *= float(settings.get("grip", 1.0))
	parent.add_child(body)
	body.reset_at(pose)
	var visual: Node3D = load("res://scripts/vehicles/vehicle_visual.gd").new()
	visual.name = "Visual"
	body.add_child(visual)
	visual.setup(profile)
	visual.position.y = -float(body.ride_height)
	visual.set_paint(ApexCatalog.paint_color(paint), paint == "Original")
	visual.set_livery(str(settings.get("livery", "Original")))
	visual.set_headlights(bool(settings.get("night", false)))
	return body
