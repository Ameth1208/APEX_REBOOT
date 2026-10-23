extends RefCounted
## Contact compression is absolute spring compression; the model rests at sag.
## This changes wheel display positions only, never collision or suspension forces.

const Layout = preload("res://scripts/physics/wheel_layout.gd")

static func sync(wheels: Array[Dictionary], contacts: Array, profile: Dictionary, delta: float) -> void:
	var motorcycle := str(profile.get("kind", profile.get("category", ""))) == "motorcycle"
	var sag := Layout.sag(profile, motorcycle)
	var travel := maxf(float(profile.get("suspension_travel_m", 0.27)), 0.0)
	var smoothing := 1.0 - exp(-30.0 * maxf(delta, 0.0))
	var compression_by_index: Dictionary = {}
	var locked_by_index: Dictionary = {}
	for contact: Dictionary in contacts:
		compression_by_index[int(contact.get("index", -1))] = float(contact.get("compression", 0.0))
		locked_by_index[int(contact.get("index", -1))] = bool(contact.get("locked", false))
	for wheel: Dictionary in wheels:
		var pivot := wheel["pivot"] as Node3D
		if not is_instance_valid(pivot):
			continue
		var base: Vector3 = wheel["base_position"]
		var index := int(wheel.get("index", Layout.index(wheel["front"], base.x >= 0.0, motorcycle)))
		wheel["locked"] = bool(locked_by_index.get(index, false))
		# A missing contact means an unloaded wheel at full extension.
		var compression := float(compression_by_index.get(index, 0.0))
		var offset := clampf(compression, 0.0, travel) - minf(sag, travel)
		var position := base
		position.y = lerpf(pivot.position.y, base.y + offset, smoothing)
		pivot.position = position
