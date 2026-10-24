extends Button
## Focusable, compact collection tile with a single red selection edge.

var _active: bool = false
var _caption: Label
var _normal: StyleBoxFlat
var _selected: StyleBoxFlat
var _base_caption: String = ""

func build(profile: Dictionary, index: int) -> void:
	custom_minimum_size = Vector2(164, 86)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = str(profile.get("display_name", "Vehículo"))
	_normal = ApexUI.style(Color(0.06, 0.08, 0.11, 0.86), Color("37404d"), 2)
	_selected = ApexUI.style(Color(0.21, 0.08, 0.11, 0.95), ApexUI.ACCENT, 2)
	_selected.border_width_bottom = 3
	add_theme_stylebox_override("normal", _normal)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 9)
	add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	_caption = ApexUI.label("%02d  /  %s" % [index + 1, str(profile.get("category_label", "VEHÍCULO")).to_upper()], 11, ApexUI.MUTED)
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.clip_text = true
	_base_caption = _caption.text
	box.add_child(_caption)
	var title := ApexUI.label(str(profile.get("short_name", profile.get("display_name", "Vehículo"))), 21)
	title.add_theme_font_override("font", ApexUI.BOLD)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	box.add_child(title)
	var specification := ApexUI.label("%d kW  ·  %s" % [int(profile.get("engine_power_kw", 0)), str(profile.get("drive", "RWD"))], 11, ApexUI.MUTED)
	specification.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(specification)

func set_selected(active: bool) -> void:
	if active == _active:
		return
	_active = active
	_caption.text = "✓  SELECCIONADO" if active else _base_caption
	add_theme_stylebox_override("normal", _selected if active else _normal)
	_caption.add_theme_color_override("font_color", ApexUI.ACCENT if active else ApexUI.MUTED)
