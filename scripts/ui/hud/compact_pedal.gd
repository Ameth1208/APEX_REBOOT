class_name ApexCompactPedal
extends Control
## One applied command, rendered as a compact red bar and an exact percentage.

const RED := Color("ff4b55")
var amount: float = 0.0
var value_label: Label
var bar: ProgressBar
var caption: Label

func setup(text: String) -> void:
	custom_minimum_size = Vector2(136, 38)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption = _label(text, 14, Color("b7bdc8"))
	value_label = _label("0 %", 18, RED)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.40, 0.15, 0.20, 0.48)
	background.set_corner_radius_all(1)
	var fill: StyleBoxFlat = background.duplicate()
	fill.bg_color = RED
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)
	resized.connect(_layout)
	_layout()
	set_amount(0.0)

func set_amount(value: float) -> void:
	amount = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	bar.value = amount * 100.0
	value_label.text = "%d %%" % roundi(amount * 100.0)
	value_label.modulate = Color.WHITE if amount > 0.005 else Color(0.75, 0.75, 0.75)

func _layout() -> void:
	if not is_instance_valid(bar):
		return
	var width: float = maxf(size.x, custom_minimum_size.x)
	caption.position = Vector2(0, 4)
	caption.size = Vector2(width - 53, 19)
	value_label.position = Vector2(width - 52, 0)
	value_label.size = Vector2(52, 25)
	bar.position = Vector2(0, 29)
	bar.size = Vector2(width, 4)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
