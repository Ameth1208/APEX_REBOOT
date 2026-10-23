class_name ApexPedalIndicator
extends VBoxContainer
## Displays the normalized command used by the powertrain/brake model, 0..100%.

var value_label: Label
var bar: ProgressBar
var amount: float = 0.0

func setup(title: String) -> void:
	add_theme_constant_override("separation", 3)
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	var caption: Label = ApexUI.label(title, 13, Color("e6cdd0"))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	value_label = ApexUI.label("0 %", 16, Color("ff6268"))
	value_label.custom_minimum_size.x = 58
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color("321d25")
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	var fill: StyleBoxFlat = background.duplicate()
	fill.bg_color = Color("ff4b55")
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

func set_amount(value: float) -> void:
	amount = clampf(value, 0, 1)
	bar.value = amount * 100.0
	value_label.text = "%d %%" % roundi(amount * 100.0)
	value_label.modulate = Color.WHITE if amount > 0.005 else Color(0.65, 0.65, 0.65)
