extends MultiMeshInstance3D
## A fixed-size pool of surface-aligned rubber marks; never grows with lap count.

const CAPACITY: int = 512
const LIFETIME: float = 35.0
var _previous: Dictionary = {}
var _ages: PackedFloat32Array = PackedFloat32Array()
var _strengths: PackedFloat32Array = PackedFloat32Array()
var _cursor: int = 0
var _count: int = 0
var _time: float = 0.0

func _ready() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2.ONE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	material.albedo_color = Color(0.035, 0.032, 0.03)
	plane.material = material
	multimesh.mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ages.resize(CAPACITY)
	_strengths.resize(CAPACITY)
	_ages.fill(LIFETIME)

func clear_connections() -> void:
	_previous.clear()

func update_contacts(contacts: Array, origin: Vector3, motorcycle: bool, delta: float) -> void:
	_time += delta
	if _time < 0.07:
		return
	for i: int in _count:
		_ages[i] += _time
		var alpha: float = _strengths[i] * clampf((LIFETIME - _ages[i]) / 8.0, 0.0, 1.0)
		multimesh.set_instance_color(i, Color(1, 1, 1, alpha))
	_time = 0.0
	var current: Dictionary = {}
	for wheel: Dictionary in contacts:
		var index: int = int(wheel["index"])
		var normal: Vector3 = wheel["normal"]
		var point: Vector3 = origin + Vector3(wheel["position"]) + normal * 0.022
		var paved: bool = str(wheel["surface"]) in ["asphalt", "concrete"]
		var slip: float = float(wheel.get("slide_speed", 0.0))
		var sliding: bool = paved and slip > 1.4 and float(wheel["load"]) > 80.0
		if sliding and _previous.has(index):
			_draw_segment(Vector3(_previous[index]), point, normal, 0.13 if motorcycle else 0.24, clampf(slip / 10.0, 0.18, 0.72))
		if sliding:
			current[index] = point
	_previous = current

func _draw_segment(from: Vector3, to: Vector3, normal: Vector3, width: float, opacity: float) -> void:
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < 0.06 or length > 12.0:
		return
	var tangent: Vector3 = delta.slide(normal).normalized()
	if tangent.length_squared() < 0.1:
		return
	var right: Vector3 = normal.cross(tangent).normalized()
	var pose: Transform3D = Transform3D(Basis(right * width, normal, tangent * length), (from + to) * 0.5)
	multimesh.set_instance_transform(_cursor, pose)
	multimesh.set_instance_color(_cursor, Color(1, 1, 1, opacity))
	_ages[_cursor] = 0.0
	_strengths[_cursor] = opacity
	_cursor = (_cursor + 1) % CAPACITY
	_count = mini(_count + 1, CAPACITY)
	multimesh.visible_instance_count = _count
