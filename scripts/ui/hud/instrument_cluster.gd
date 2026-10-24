class_name ApexInstrumentCluster
extends Control
## Driving essentials, centred at the bottom of the screen.

const SIZE := Vector2(560, 214)
const WHITE := Color("f4f5f7")
const MUTED := Color("a9b1bd")
const RED := Color("ff4b55")
const DIGITS = preload("res://assets/fonts/barlow/BarlowSemiCondensed-Bold.ttf")
var speed: Label
var gear: Label
var rpm_value: Label
var rpm: ApexRPMStrip
var throttle_input: ApexCompactPedal
var brake_input: ApexCompactPedal
var handbrake_input: ApexCompactPedal
var assists: Label
var _speed_target: float = 0.0
var _speed_display: float = 0.0
var _speed_ratio: float = 0.0
var _rpm_ratio: float = 0.0
var _shift_flash: float = 0.0

func build(is_motorcycle: bool) -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rpm = ApexRPMStrip.new()
	rpm.position = Vector2(168, 15)
	rpm.size = Vector2(224, 8)
	add_child(rpm)
	_label("RPM", 11, MUTED, Rect2(28, 46, 145, 18))
	rpm_value = _label("0", 38, WHITE, Rect2(28, 61, 145, 47))
	rpm_value.add_theme_font_override("font", DIGITS)
	gear = _label("N", 88, WHITE, Rect2(144, 30, 100, 98))
	gear.add_theme_font_override("font", DIGITS)
	gear.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed = _label("0", 72, WHITE, Rect2(248, 34, 156, 80))
	speed.add_theme_font_override("font", DIGITS)
	speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var units: Label = _label("KM/H", 13, MUTED, Rect2(420, 90, 78, 20))
	units.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	assists = _label("", 10, RED, Rect2(204, 120, 156, 17))
	assists.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	throttle_input = _pedal("ACEL.", 28)
	brake_input = _pedal("FRENO", 196)
	handbrake_input = _pedal("TRASERO" if is_motorcycle else "MANO", 364)
	queue_redraw()

func _process(delta: float) -> void:
	var previous_display: float = _speed_display
	var previous_ratio: float = _speed_ratio
	var previous_flash: float = _shift_flash
	_speed_display = move_toward(_speed_display, _speed_target, maxf(1.0, absf(_speed_target - _speed_display) * delta * 9.0))
	_speed_ratio = clampf(_speed_display / 300.0, 0.0, 1.0)
	_shift_flash = maxf(0.0, _shift_flash - delta)
	if is_instance_valid(speed) and roundi(previous_display) != roundi(_speed_display):
		speed.text = str(roundi(_speed_display))
	if not is_equal_approx(previous_ratio, _speed_ratio) or (previous_flash > 0.0) != (_shift_flash > 0.0):
		queue_redraw()

func update_state(data: Dictionary, max_rpm: float) -> void:
	var speed_kph: float = _finite_nonnegative(data.get("speed_kph", 0.0))
	var engine_rpm: float = _finite_nonnegative(data.get("rpm", 0.0))
	var limit: float = maxf(max_rpm, 1.0) if is_finite(max_rpm) else 1.0
	_speed_target = minf(speed_kph, 9999.0)
	var next_gear: String = _gear_text(int(data.get("gear", 0)))
	if gear.text != next_gear:
		gear.text = next_gear
		gear.add_theme_font_size_override("font_size", 66 if gear.text.length() > 1 else 88)
	rpm_value.text = str(roundi(minf(engine_rpm, 99999.0)))
	_rpm_ratio = clampf(engine_rpm / limit, 0.0, 1.0)
	rpm.set_fraction(_rpm_ratio)
	if _rpm_ratio > 0.92:
		_shift_flash = 0.12
	throttle_input.set_amount(float(data.get("throttle", 0.0)))
	brake_input.set_amount(float(data.get("brake", 0.0)))
	handbrake_input.set_amount(float(data.get("handbrake", 0.0)))
	var active: PackedStringArray = []
	if bool(data.get("abs_active", false)):
		active.append("ABS")
	if bool(data.get("tcs_active", false)):
		active.append("TCS")
	assists.text = "  ·  ".join(active)
	assists.visible = not active.is_empty()

func _draw() -> void:
	# A shallow translucent band keeps the driving scene visible.
	var silhouette := PackedVector2Array([
		Vector2(0, 16), Vector2(148, 16), Vector2(164, 0), Vector2(396, 0),
		Vector2(412, 16), Vector2(560, 16), Vector2(560, 205),
		Vector2(542, 214), Vector2(18, 214), Vector2(0, 205)])
	draw_colored_polygon(silhouette, Color(0.018, 0.027, 0.044, 0.58))
	draw_line(Vector2(20, 208), Vector2(540, 208), Color(1, 1, 1, 0.18), 1.0)
	draw_line(Vector2(166, 3), Vector2(394, 3), RED, 2.0, true)
	draw_line(Vector2(22, 141), Vector2(538, 141), Color(0.65, 0.69, 0.75, 0.16), 1.0)
	# Shift indicator is intentionally brief feedback, not a persistent pulse.
	if _shift_flash > 0.0:
		for index: int in range(5):
			var x: float = 174.0 + float(index) * 28.0
			draw_rect(Rect2(x, 4, 21, 3), RED if index > 2 else Color("f4c76b"))

func _pedal(text: String, x: float) -> ApexCompactPedal:
	var pedal := ApexCompactPedal.new()
	pedal.position = Vector2(x, 139)
	pedal.size = Vector2(136, 38)
	add_child(pedal)
	pedal.setup(text)
	return pedal

func _label(text: String, font_size: int, color: Color, rect: Rect2) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

static func _finite_nonnegative(value: Variant) -> float:
	var number: float = float(value)
	return maxf(0.0, number) if is_finite(number) else 0.0

static func _gear_text(value: int) -> String:
	if value < 0:
		return "R"
	if value == 0:
		return "N"
	return str(value) if value < 100 else "—"
