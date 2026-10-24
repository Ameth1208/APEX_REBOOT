class_name ApexUI
extends RefCounted
## Shared garage/editor typography. The race HUD keeps its own compact theme.

const FONT = preload("res://assets/fonts/barlow/BarlowSemiCondensed-Medium.ttf")
const BOLD = preload("res://assets/fonts/barlow/BarlowSemiCondensed-Bold.ttf")
const Forms = preload("res://scripts/ui/menu/form_theme.gd")
const INK := Color("f1f4f6")
const MUTED := Color("9ca7b7")
const ACCENT := Color("ff4b55")
const PANEL := Color(0.035, 0.043, 0.059, 0.96)

static func style(color: Color, border: Color = Color("303846"), radius: int = 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(maxi(radius, 4))
	box.content_margin_left = 13
	box.content_margin_right = 13
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 16
	result.set_color("font_color", "Label", INK)
	result.set_stylebox("panel", "PanelContainer", style(PANEL))
	for type: String in ["Button", "OptionButton"]:
		result.set_font("font", type, BOLD)
		result.set_stylebox("normal", type, style(Color("151d29"), Color("303b4b"), 5))
		result.set_stylebox("hover", type, style(Color("242e3c"), Color("db646d"), 5))
		result.set_stylebox("pressed", type, style(Color("49222d"), ACCENT, 5))
		result.set_stylebox("disabled", type, style(Color("10151d"), Color("202732"), 5))
		var focus := style(Color.TRANSPARENT, ACCENT)
		focus.set_border_width_all(2)
		result.set_stylebox("focus", type, focus)
		result.set_color("font_color", type, INK)
		result.set_color("font_hover_color", type, Color.WHITE)
		result.set_color("font_pressed_color", type, INK)
		result.set_color("font_disabled_color", type, Color("687280"))
	result.set_stylebox("background", "ProgressBar", style(Color("263140"), Color.TRANSPARENT, 1))
	result.set_stylebox("fill", "ProgressBar", style(ACCENT, ACCENT, 1))
	result.set_stylebox("panel", "PopupMenu", style(Color("141b26")))
	result.set_stylebox("hover", "PopupMenu", style(Color("4b2530"), Color.TRANSPARENT))
	result.set_color("font_color", "PopupMenu", INK)
	result.set_stylebox("panel", "TabContainer", style(Color("0b111b"), Color("2c3441"), 6))
	for type: String in ["TabContainer", "TabBar"]:
		result.set_font("font", type, BOLD)
		var selected := style(Color("1d242f"), ACCENT, 1)
		selected.border_width_left = 0
		selected.border_width_right = 0
		selected.border_width_top = 0
		selected.border_width_bottom = 3
		result.set_stylebox("tab_selected", type, selected)
		result.set_stylebox("tab_unselected", type, style(Color("101620"), Color.TRANSPARENT, 1))
		result.set_stylebox("tab_hovered", type, style(Color("262b35"), Color.TRANSPARENT, 1))
		result.set_color("font_selected_color", type, INK)
		result.set_color("font_unselected_color", type, MUTED)
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("separation", "HBoxContainer", 10)
	Forms.apply(result)
	return result

static func label(text: String, size: int = 16, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func button(text: String, action: Callable, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 44
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(action)
	if primary:
		result.add_theme_stylebox_override("normal", style(ACCENT, ACCENT, 2))
		result.add_theme_stylebox_override("hover", style(Color("ff727c"), Color("ff727c"), 2))
		result.add_theme_stylebox_override("pressed", style(Color("d92e43"), Color("d92e43"), 2))
		for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			result.add_theme_color_override(key, Color("1e080c"))
	return result

static func option(parent: VBoxContainer, title: String, items: Array, selected: int, action: Callable) -> OptionButton:
	parent.add_child(label(title.to_upper(), 12, MUTED))
	var select := OptionButton.new()
	for item in items:
		select.add_item(str(item))
	select.select(clampi(selected, 0, items.size() - 1))
	select.custom_minimum_size.y = 38
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.fit_to_longest_item = false
	select.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	select.item_selected.connect(action)
	parent.add_child(select)
	return select
