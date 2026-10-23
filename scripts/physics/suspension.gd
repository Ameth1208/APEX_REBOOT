extends RefCounted
## Independent ray contacts: four tyres for cars, two for a motorcycle.
## The unloaded spring length includes sag, so ride_height is the static height.

const Layout = preload("res://scripts/physics/wheel_layout.gd")

var offsets: Array[Vector3] = []
var wheel_radius: float = 0.34
var ride_height: float = 0.62
var travel: float = 0.27
var mass_kg: float = 1450.0
var front_share: float = 0.46
var is_motorcycle: bool = false
var damping_ratio: float = 0.72
var sag: float = 0.10
var _corner_masses: PackedFloat32Array = PackedFloat32Array()
var _springs: PackedFloat32Array = PackedFloat32Array()
var _dampers: PackedFloat32Array = PackedFloat32Array()
var _queries: Array[PhysicsRayQueryParameters3D] = []

func configure(data: Dictionary, motorcycle: bool, height: float) -> void:
	is_motorcycle = motorcycle
	ride_height = height
	mass_kg = float(data.get("mass_kg", data.get("mass", 1450.0)))
	wheel_radius = float(data.get("wheel_radius_m", data.get("wheel_radius", 0.34)))
	front_share = float(data.get("front_weight_fraction", 0.48 if motorcycle else 0.46))
	travel = float(data.get("suspension_travel_m", 0.27))
	damping_ratio = float(data.get("suspension_damping_ratio", 0.72))
	sag = Layout.sag(data, motorcycle)
	offsets = Layout.offsets(data, motorcycle)
	_corner_masses.clear()
	_springs.clear()
	_dampers.clear()
	_queries.clear()
	for offset: Vector3 in offsets:
		var share: float = front_share if offset.z < 0.0 else 1.0 - front_share
		var corner_mass: float = mass_kg * share / (1.0 if motorcycle else 2.0)
		var spring: float = corner_mass * 9.81 / sag
		_corner_masses.append(corner_mass)
		_springs.append(spring)
		_dampers.append(2.0 * damping_ratio * sqrt(spring * corner_mass))
		_queries.append(PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1))

func sample(state: PhysicsDirectBodyState3D, body_rid: RID) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	var body_up: Vector3 = state.transform.basis.y.normalized()
	var space: PhysicsDirectSpaceState3D = state.get_space_state()
	for i: int in offsets.size():
		var origin: Vector3 = state.transform * offsets[i]
		# A tyre cannot touch below its fully extended spring; avoid phantom contacts.
		var query: PhysicsRayQueryParameters3D = _queries[i]
		query.from = origin
		query.to = origin - body_up * (ride_height + sag)
		if query.exclude.is_empty():
			query.exclude = [body_rid]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit["normal"]
		if normal.dot(body_up) < 0.25:
			continue
		var position: Vector3 = hit["position"]
		var relative: Vector3 = position - state.transform.origin
		var velocity: Vector3 = state.get_velocity_at_local_position(relative)
		var front: bool = offsets[i].z < 0.0
		var corner_mass: float = _corner_masses[i]
		var spring: float = _springs[i]
		var damper: float = _dampers[i]
		var compression: float = ride_height + sag - origin.distance_to(position)
		var bump_stop: float = maxf(compression - travel * 0.85, 0.0) * spring * 4.0
		var load_n: float = clampf(compression * spring + bump_stop - velocity.dot(normal) * damper, 0.0, corner_mass * 9.81 * 7.0)
		var collider: Object = hit["collider"]
		var surface: String = str(collider.get_meta("surface", "asphalt")) if is_instance_valid(collider) else "asphalt"
		contacts.append({"index": i, "position": relative, "normal": normal, "velocity": velocity, "load": load_n, "front": front, "surface": surface, "compression": compression, "corner_mass": corner_mass})
	return contacts
