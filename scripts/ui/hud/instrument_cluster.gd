class_name ApexInstrumentCluster
extends Control
## Driving essentials, centred at the bottom of the screen.

const SIZE := Vector2(470, 182)
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

func build(is_motorcycle: bool) -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rpm = ApexRPMStrip.new()
	rpm.position = Vector2(139, 14)
	rpm.size = Vector2(192, 7)
	add_child(rpm)
	_label("RPM", 14, MUTED, Rect2(23, 40, 130, 20))
	rpm_value = _label("0", 28, WHITE, Rect2(23, 58, 133, 41))
	rpm_value.add_theme_font_override("font", DIGITS)
	gear = _label("N", 76, WHITE, Rect2(179, 22, 112, 99))
	gear.add_theme_font_override("font", DIGITS)
	gear.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed = _label("0", 40, WHITE, Rect2(320, 42, 124, 55))
	speed.add_theme_font_override("font", DIGITS)
	speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var units: Label = _label("KM/H", 14, MUTED, Rect2(320, 94, 124, 17))
	units.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	assists = _label("", 10, RED, Rect2(184, 113, 102, 17))
	assists.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	throttle_input = _pedal("ACEL.", 20)
	brake_input = _pedal("FRENO", 167)
	handbrake_input = _pedal("TRASERO" if is_motorcycle else "MANO", 314)
	queue_redraw()

func update_state(data: Dictionary, max_rpm: float) -> void:
	var speed_kph: float = _finite_nonnegative(data.get("speed_kph", 0.0))
	var engine_rpm: float = _finite_nonnegative(data.get("rpm", 0.0))
	var limit: float = maxf(max_rpm, 1.0) if is_finite(max_rpm) else 1.0
	speed.text = str(roundi(minf(speed_kph, 9999.0)))
	var next_gear: String = _gear_text(int(data.get("gear", 0)))
	if gear.text != next_gear:
		gear.text = next_gear
		gear.add_theme_font_size_override("font_size", 66 if gear.text.length() > 1 else 76)
	rpm_value.text = str(roundi(minf(engine_rpm, 99999.0)))
	rpm.set_fraction(engine_rpm / limit)
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
	# The shallow silhouette keeps the road visible above and around the gear.
	var silhouette := PackedVector2Array([
		Vector2(0, 37), Vector2(137, 29), Vector2(155, 0), Vector2(315, 0),
		Vector2(333, 29), Vector2(470, 37), Vector2(470, 176),
		Vector2(453, 182), Vector2(17, 182), Vector2(0, 176)])
	draw_colored_polygon(silhouette, Color(0.027, 0.038, 0.056, 0.82))
	var edge := PackedVector2Array(silhouette)
	edge.append(silhouette[0])
	draw_polyline(edge, Color(0.62, 0.67, 0.75, 0.27), 1.0, true)
	draw_line(Vector2(158, 3), Vector2(312, 3), RED, 2.0, true)
	draw_line(Vector2(166, 37), Vector2(166, 109), Color(0.65, 0.69, 0.75, 0.19), 1.0)
	draw_line(Vector2(304, 37), Vector2(304, 109), Color(0.65, 0.69, 0.75, 0.19), 1.0)
	draw_line(Vector2(20, 130), Vector2(450, 130), Color(0.65, 0.69, 0.75, 0.16), 1.0)

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
