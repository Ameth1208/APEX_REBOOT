class_name PhysicsDebugOverlay
extends Control
## On-screen physics visualiser: force vectors, contact points, tyre loads,
## slip, temperature and suspension state. Toggle with F8.

var _vehicle: RigidBody3D
var _enabled: bool = false
var _canvas: CanvasItem
var _labels: Array[Label] = []
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_build_labels()
	hide()

func _build_labels() -> void:
	var keys: Array[String] = [
		"SUPERFICIE", "CARGA FL / FR / RL / RR", "SLIP LATERAL", "SLIP LONG",
		"TEMP GOMAS °C", "MU EFECTIVO", "FUERZA MOTOR N", "FRENO N",
		"DOWNFORCE N", "DRAG N", "VEL m/s", "GIRO °", "RUEDAS EN SUELO",
		"ABS", "TCS", "TEMPERATURA OK"
	]
	for i: int in range(keys.size()):
		var label: Label = Label.new()
		label.position = Vector2(12.0, 12.0 + float(i) * 20.0)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 3)
		label.text = keys[i]
		_canvas.add_child(label)
		_labels.append(label)
	# Force vector legend
	var legend: Label = Label.new()
	legend.position = Vector2(12.0, 12.0 + float(keys.size()) * 20.0 + 8.0)
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	legend.text = "F8: ocultar · Verde=contacto · Amarillo=freno · Azul=tracción · Rojo=slide"
	_canvas.add_child(legend)

func set_vehicle(v: RigidBody3D) -> void:
	_vehicle = v

func toggle() -> void:
	_enabled = not _enabled
	visible = _enabled

func is_enabled() -> bool:
	return _enabled

func _process(_delta: float) -> void:
	if not _enabled or not is_instance_valid(_vehicle):
		return
	_update_labels()
	queue_redraw()

func _update_labels() -> void:
	var v = _vehicle
	var t: Dictionary = v.telemetry() if v.has_method("telemetry") else {}
	var contacts: Array = v.get("wheel_contacts") if "wheel_contacts" in v else []
	var idx: int = 0
	_set_label(idx, "SUPERFICIE: %s" % str(t.get("surface", "?"))); idx += 1
	# Load by wheel index (FL/FR/RL/RR), not contact order.
	var wheel_labels: Array[String] = ["FL", "FR", "RL", "RR"]
	if v.is_motorcycle:
		wheel_labels = ["F", "R"]
	var loads_by_wheel: Array = []
	for c: Dictionary in contacts:
		var wi: int = int(c.get("index", 0))
		var label: String = wheel_labels[wi] if wi < wheel_labels.size() else str(wi)
		loads_by_wheel.append("%s:%.0f" % [label, float(c.get("load", 0.0))])
	var load_str: String = "  ".join(loads_by_wheel) if loads_by_wheel.size() > 0 else "sin contacto"
	_set_label(idx, "CARGA: %s" % load_str); idx += 1
	# Weight transfer: left vs right totals.
	var left_total: float = 0.0
	var right_total: float = 0.0
	for c: Dictionary in contacts:
		var wi: int = int(c.get("index", 0))
		var is_left: bool = (wi == 0 or wi == 2) if not v.is_motorcycle else false
		if is_left:
			left_total += float(c.get("load", 0.0))
		else:
			right_total += float(c.get("load", 0.0))
	if left_total > 0 and right_total > 0:
		var avg: float = (left_total + right_total) * 0.5
		var diff_pct: float = (right_total - left_total) / maxf(avg, 1.0) * 100.0
		_set_label(idx, "LATERAL: %.1f%% %s" % [absf(diff_pct), "→ der" if diff_pct > 0 else "← izq"]); idx += 1
	else:
		_set_label(idx, ""); idx += 1
	_set_label(idx, "SLIP LATERAL: %.2f" % float(t.get("tire_slip", 0.0))); idx += 1
	var slip_long: float = 0.0
	for c: Dictionary in contacts:
		slip_long = maxf(slip_long, absf(float(c.get("slide_speed", 0.0))))
	_set_label(idx, "SLIDE SPEED: %.1f m/s" % slip_long); idx += 1
	_set_label(idx, "TEMP GOMAS: %.1f °C" % float(t.get("tyre_temp_c", 20.0))); idx += 1
	_set_label(idx, "GIRO: %.1f°" % rad_to_deg(float(t.get("steer_angle", 0.0)))); idx += 1
	_set_label(idx, "RUEDAS: %d" % int(t.get("grounded_wheels", 0))); idx += 1
	_set_label(idx, "VEL: %.1f km/h" % float(t.get("speed_kph", 0.0))); idx += 1
	_set_label(idx, "DOWNFORCE: %.0f N" % float(t.get("downforce_n", 0.0))); idx += 1
	_set_label(idx, "ABS: %s" % ("SÍ" if bool(t.get("abs_active", false)) else "no")); idx += 1
	_set_label(idx, "TCS: %s" % ("SÍ" if bool(t.get("tcs_active", false)) else "no")); idx += 1
	_set_label(idx, "MOTOR: %.0f rpm · %d marcha" % [float(t.get("rpm", 0.0)), int(t.get("gear", 1))]); idx += 1
	var temp: float = float(t.get("tyre_temp_c", 20.0))
	var temp_status: String = "FRÍO" if temp < 40.0 else ("ÓPTIMO" if temp <= 95.0 else "CALIENTE")
	_set_label(idx, "GOMAS: %s" % temp_status); idx += 1
	# Fill remaining
	while idx < _labels.size():
		_set_label(idx, ""); idx += 1

func _set_label(index: int, text: String) -> void:
	if index < _labels.size():
		_labels[index].text = text

func _draw() -> void:
	if not _enabled or not is_instance_valid(_vehicle):
		return
	var vp: Vector2 = size
	var center: Vector2 = vp * 0.5
	# Draw wheel contact force vectors projected to screen.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var contacts: Array = _vehicle.get("wheel_contacts") if "wheel_contacts" in _vehicle else []
	for c: Dictionary in contacts:
		var world_pos: Vector3 = _vehicle.global_transform * Vector3(c.get("position", Vector3.ZERO))
		var screen: Vector2 = camera.unproject_position(world_pos)
		var s: Vector2 = Vector2(screen.x, screen.y)
		# Contact dot (green).
		draw_circle(s, 6.0, Color(0.2, 1.0, 0.3, 0.9))
		# Load vector (up, scaled).
		var load: float = float(c.get("load", 0.0))
		var load_len: float = clampf(load * 0.003, 4.0, 60.0)
		var normal: Vector3 = c.get("normal", Vector3.UP)
		var tip_world: Vector3 = world_pos + normal * load_len * 0.1
		var tip: Vector2 = camera.unproject_position(tip_world)
		draw_line(s, Vector2(tip.x, tip.y), Color(0.3, 0.8, 1.0, 0.85), 2.5)
		# Slip direction (red if sliding).
		var slide: float = absf(float(c.get("slide_speed", 0.0)))
		if slide > 0.5:
			var slip_len: float = clampf(slide * 4.0, 6.0, 80.0)
			var vel: Vector3 = c.get("velocity", Vector3.ZERO)
			if vel.length() > 0.1:
				var slip_world: Vector3 = world_pos + vel.normalized() * slip_len * 0.1
				var slip_screen: Vector2 = camera.unproject_position(slip_world)
				draw_line(s, Vector2(slip_screen.x, slip_screen.y), Color(1.0, 0.25, 0.2, 0.85), 2.5)
	# Centre-of-mass marker.
	var com: Vector2 = camera.unproject_position(_vehicle.global_position)
	draw_circle(Vector2(com.x, com.y), 4.0, Color(1.0, 1.0, 0.3, 0.8))