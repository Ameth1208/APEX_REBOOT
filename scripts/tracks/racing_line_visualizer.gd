class_name RacingLineVisualizer
extends Node3D
## Draws the dynamic racing line in 3D, following the road surface.
## Colours update in real-time based on the player's brake risk.

const Intelligence = preload("res://scripts/tracks/track_intelligence.gd")

var _intelligence: TrackIntelligence
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _player_index: int = 0
var _player_speed: float = 0.0
var _is_braking: bool = false
var _refresh_timer: float = 0.0
var _refresh_rate: float = 1.0 / 15.0
var _smoothed_colors: PackedColorArray = PackedColorArray()
var _visible: bool = true
var _line_width: float = 0.35

func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = false
	_material.render_priority = 10
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(_mesh_instance)
	visible = true

func set_intelligence(intel: TrackIntelligence) -> void:
	_intelligence = intel
	if _intelligence != null:
		_smoothed_colors.resize(_intelligence.sample_count())
		_smoothed_colors.fill(Color.GREEN)
	_rebuild_mesh()

func set_player_state(index: int, speed: float, braking: bool) -> void:
	_player_index = index
	_player_speed = speed
	_is_braking = braking

func set_line_visible(value: bool) -> void:
	_visible = value
	visible = value
	# A hidden optional visualizer must not keep evaluating braking risk.
	set_process(value)

func toggle_visible() -> void:
	set_line_visible(not _visible)

func is_visible_line() -> bool:
	return _visible

func _process(delta: float) -> void:
	if _intelligence == null or not _visible:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = _refresh_rate
		_update_colors()
		_rebuild_mesh_near_player()

func _update_colors() -> void:
	var n: int = _intelligence.sample_count()
	if n == 0:
		return
	# Compute risk for each sample near the player.
	var player_pos: int = _player_index
	var lookahead_samples: int = int(_player_speed * _intelligence.lookahead_s / _intelligence.sample_spacing)
	for i: int in range(n):
		var risk_data: Dictionary = _intelligence.brake_risk(i, _player_speed, _is_braking, _refresh_rate)
		var target_color: Color = risk_data["color"]
		# Smooth colour transitions (Section 49).
		var k: float = 1.0 - exp(-8.0 * _refresh_rate)
		if i < _smoothed_colors.size():
			_smoothed_colors[i] = _smoothed_colors[i].lerp(target_color, k)

## Only rebuild mesh segments near the player (chunk-based, not entire track).
func _rebuild_mesh_near_player() -> void:
	if _intelligence == null or _intelligence.sample_count() < 2:
		return
	var player_idx: int = _player_index
	var n: int = _intelligence.sample_count()
	# Only draw ~60 samples ahead and 10 behind (about 140m at 2m spacing).
	var start_i: int = maxi(0, player_idx - 10)
	var end_i: int = mini(n, player_idx + 60)
	if end_i - start_i < 2:
		return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up: Vector3 = Vector3.UP
	var segment_skip: int = 2
	var segment_gap: float = 0.35
	for i: int in range(start_i, end_i - segment_skip, segment_skip):
		var j: int = mini(i + segment_skip, end_i - 1)
		var p0: Vector3 = _intelligence.samples[i]["position"] + up * 0.03
		var p1: Vector3 = _intelligence.samples[j]["position"] + up * 0.03
		var right0: Vector3 = _intelligence.samples[i].get("right", Vector3.RIGHT)
		var right1: Vector3 = _intelligence.samples[j].get("right", Vector3.RIGHT)
		var offset0: float = _intelligence.line_offsets[i]
		var offset1: float = _intelligence.line_offsets[j]
		var dir: Vector3 = (p1 - p0).normalized()
		p0 += dir * segment_gap * 0.5
		p1 -= dir * segment_gap * 0.5
		var w0: Vector3 = p0 + right0 * (offset0 - _line_width * 0.5)
		var w1: Vector3 = p0 + right0 * (offset0 + _line_width * 0.5)
		var w2: Vector3 = p1 + right1 * (offset1 + _line_width * 0.5)
		var w3: Vector3 = p1 + right1 * (offset1 - _line_width * 0.5)
		var c0: Color = _smoothed_colors[i] if i < _smoothed_colors.size() else Color.GREEN
		c0.a = 0.7
		var c1: Color = _smoothed_colors[mini(j, _smoothed_colors.size() - 1)]
		c1.a = 0.7
		st.set_color(c0); st.add_vertex(w0)
		st.set_color(c0); st.add_vertex(w1)
		st.set_color(c1); st.add_vertex(w2)
		st.set_color(c0); st.add_vertex(w0)
		st.set_color(c1); st.add_vertex(w2)
		st.set_color(c1); st.add_vertex(w3)
	st.generate_normals()
	_mesh_instance.mesh = st.commit()
	_mesh_instance.material_override = _material

func _rebuild_mesh() -> void:
	if _intelligence == null or _intelligence.sample_count() < 2:
		return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = _intelligence.sample_count()
	var up: Vector3 = Vector3.UP
	# Discrete segments (Section 23): draw every other sample, skip gaps.
	var segment_skip: int = 2
	var segment_gap: float = 0.35
	for i: int in range(0, n - segment_skip, segment_skip):
		var j: int = mini(i + segment_skip, n - 1)
		var p0: Vector3 = _intelligence.samples[i]["position"] + up * 0.03
		var p1: Vector3 = _intelligence.samples[j]["position"] + up * 0.03
		var right0: Vector3 = _intelligence.samples[i].get("right", Vector3.RIGHT)
		var right1: Vector3 = _intelligence.samples[j].get("right", Vector3.RIGHT)
		var offset0: float = _intelligence.line_offsets[i]
		var offset1: float = _intelligence.line_offsets[j]
		# Shorten ends to create gaps between segments.
		var dir: Vector3 = (p1 - p0).normalized()
		p0 += dir * segment_gap * 0.5
		p1 -= dir * segment_gap * 0.5
		var w0: Vector3 = p0 + right0 * (offset0 - _line_width * 0.5)
		var w1: Vector3 = p0 + right0 * (offset0 + _line_width * 0.5)
		var w2: Vector3 = p1 + right1 * (offset1 + _line_width * 0.5)
		var w3: Vector3 = p1 + right1 * (offset1 - _line_width * 0.5)
		var c0: Color = _smoothed_colors[i] if i < _smoothed_colors.size() else Color.GREEN
		c0.a = 0.7
		var c1: Color = _smoothed_colors[mini(j, _smoothed_colors.size() - 1)]
		c1.a = 0.7
		st.set_color(c0); st.add_vertex(w0)
		st.set_color(c0); st.add_vertex(w1)
		st.set_color(c1); st.add_vertex(w2)
		st.set_color(c0); st.add_vertex(w0)
		st.set_color(c1); st.add_vertex(w2)
		st.set_color(c1); st.add_vertex(w3)
	st.generate_normals()
	_mesh_instance.mesh = st.commit()
	_mesh_instance.material_override = _material
