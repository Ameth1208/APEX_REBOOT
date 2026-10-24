extends RefCounted
## Independent ray contacts: four tyres for cars, two for a motorcycle.
## The unloaded spring length includes sag, so ride_height is the static height.
## Computes per-wheel compression, compression rate, asymmetric damping, and bump stops.

const Layout = preload("res://scripts/physics/wheel_layout.gd")
const SurfaceSampler = preload("res://scripts/physics/surfaces/surface_sampler.gd")

static func set_osm_zones(zones: Dictionary) -> void:
	SurfaceSampler.set_osm_zones(zones)

## Determine surface at a world XZ point: OSM zones first, then collider meta.
static func surface_at_point(xz: Vector2, collider: Object) -> String:
	return SurfaceSampler.sample_surface(xz, collider)

enum Type { MACPHERSON, DOUBLE_WISHBONE, MULTILINK, LEAF_SPRING, TORSION_BEAM }

var suspension_type: Type = Type.MACPHERSON
var camber_deg: float = 0.0
var caster_deg: float = 0.0

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
	# Resolve suspension type and apply per-type defaults.
	var type_str: String = str(data.get("suspension_type", "macpherson")).to_lower()
	match type_str:
		"double_wishbone": suspension_type = Type.DOUBLE_WISHBONE
		"multilink": suspension_type = Type.MULTILINK
		"leaf_spring": suspension_type = Type.LEAF_SPRING
		"torsion_beam": suspension_type = Type.TORSION_BEAM
		_: suspension_type = Type.MACPHERSON
	camber_deg = float(data.get("camber_deg", _default_camber()))
	caster_deg = float(data.get("caster_deg", _default_caster()))
	var default_travel: float = _default_travel()
	var default_damping: float = _default_damping()
	travel = float(data.get("suspension_travel_m", default_travel))
	damping_ratio = float(data.get("suspension_damping_ratio", default_damping))
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
		# Progressive spring: stiffness increases with compression beyond 50% travel.
		var progress_ratio: float = clampf(compression / maxf(travel, 0.01), 0.0, 1.0)
		var progressive: float = 1.0 + maxf(progress_ratio - 0.5, 0.0) * 1.2 * (1.0 + 0.3 * float(suspension_type == Type.DOUBLE_WISHBONE))
		var bump_stop: float = maxf(compression - travel * 0.85, 0.0) * spring * 4.0
		var spring_force: float = compression * spring * progressive + bump_stop
		# Damping: asymmetric — bump stiffer than rebound, and never below
		# a fraction of static load so the tyre keeps contact at speed.
		var damp_velocity: float = velocity.dot(normal)
		var damper_force: float = damp_velocity * damper
		if damp_velocity < 0.0:
			damper_force *= 1.6
		# No min-load floor: let suspension settle to zero when wheel lifts.
		# The asymmetric damping already prevents overshoot at speed.
		var load_n: float = clampf(spring_force - damper_force, 0.0, corner_mass * 9.81 * 7.0)
		var collider: Object = hit["collider"]
		var surface: String = surface_at_point(Vector2(position.x, position.z), collider)
		contacts.append({"index": i, "position": relative, "normal": normal, "velocity": velocity, "load": load_n, "front": front, "surface": surface, "compression": compression, "corner_mass": corner_mass})
	return contacts

func _default_travel() -> float:
	match suspension_type:
		Type.DOUBLE_WISHBONE: return 0.26
		Type.MULTILINK: return 0.24
		Type.LEAF_SPRING: return 0.20
		Type.TORSION_BEAM: return 0.18
		_: return 0.27

func _default_damping() -> float:
	match suspension_type:
		Type.DOUBLE_WISHBONE: return 0.78
		Type.MULTILINK: return 0.75
		Type.LEAF_SPRING: return 0.70
		Type.TORSION_BEAM: return 0.72
		_: return 0.72

func _default_camber() -> float:
	match suspension_type:
		Type.DOUBLE_WISHBONE: return -0.8
		Type.MULTILINK: return -0.5
		Type.TORSION_BEAM: return -0.3
		_: return -0.5

func _default_caster() -> float:
	match suspension_type:
		Type.DOUBLE_WISHBONE: return 6.0
		Type.MULTILINK: return 5.0
		_: return 4.0
