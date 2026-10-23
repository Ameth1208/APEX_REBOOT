extends RefCounted
## Crisp, red-accented native fields; no screen-space effects.

static func apply(theme: Theme) -> void:
	for key: String in ["normal", "read_only"]:
		theme.set_stylebox(key, "LineEdit", _box(Color("101620"), Color("3a4351")))
	var focus := _box(Color.TRANSPARENT, Color("ff4b55"))
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", Color("f1f4f6"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("7e8999"))
	theme.set_color("caret_color", "LineEdit", Color("ff4b55"))
	theme.set_color("selection_color", "LineEdit", Color("78313e"))
	theme.set_color("font_selected_color", "LineEdit", Color.WHITE)
	for type: String in ["HSlider", "VSlider"]:
		var track := _box(Color("2d3542"), Color.TRANSPARENT)
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		track.content_margin_left = 3
		track.content_margin_right = 3
		theme.set_stylebox("slider", type, track)
		var fill := track.duplicate() as StyleBoxFlat
		fill.bg_color = Color("ff4b55")
		theme.set_stylebox("grabber_area", type, fill)
		theme.set_stylebox("grabber_area_highlight", type, fill)
	for type: String in ["CheckBox", "CheckButton"]:
		theme.set_color("font_color", type, Color("f1f4f6"))
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Color("ff4b55"))
		theme.set_stylebox("focus", type, focus)
	theme.set_icon("checked", "CheckBox", _check_icon(true))
	theme.set_icon("unchecked", "CheckBox", _check_icon(false))

static func _box(color: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(2)
	result.content_margin_left = 10
	result.content_margin_right = 10
	result.content_margin_top = 8
	result.content_margin_bottom = 8
	return result

static func _check_icon(checked: bool) -> ImageTexture:
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><rect x="1" y="1" width="16" height="16" rx="2" fill="%s" stroke="%s"/>' % ["#ff4b55" if checked else "#101620", "#ff4b55" if checked else "#626c7b"]
	if checked:
		svg += '<path d="M5 9l3 3 5-6" stroke="#210a0e" stroke-width="2" fill="none"/>'
	var image := Image.new()
	image.load_svg_from_string(svg + "</svg>")
	return ImageTexture.create_from_image(image)
