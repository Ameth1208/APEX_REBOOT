class_name ApexHudTheme
extends RefCounted
## A dedicated race theme keeps the garage and editor independent of the HUD.

const FONT = preload("res://assets/fonts/barlow/BarlowSemiCondensed-SemiBold.ttf")
const BOLD = preload("res://assets/fonts/barlow/BarlowSemiCondensed-Bold.ttf")
const INK := Color("f3f5f8")
const MUTED := Color("adb5c2")
const RED := Color("ff4b55")

static func create() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 17
	result.set_color("font_color", "Label", INK)
	result.set_constant("separation", "VBoxContainer", 5)
	result.set_constant("separation", "HBoxContainer", 9)
	result.set_stylebox("panel", "PanelContainer", panel())
	return result

static func panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.047, 0.071, 0.82)
	box.border_color = Color(0.55, 0.61, 0.70, 0.30)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 13
	box.content_margin_right = 13
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box
