class_name ApexModal
extends Control

signal chosen(action: String)

func build(title: String, subtitle: String, buttons: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", ApexUI.style(Color(0.035, 0.043, 0.059, 0.5), Color.TRANSPARENT, 0))
	scroll.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var accent := ColorRect.new()
	accent.color = ApexUI.ACCENT
	accent.custom_minimum_size.y = 3
	box.add_child(accent)
	box.add_child(ApexUI.label("APEX REBOOT", 12, ApexUI.ACCENT))
	var heading := ApexUI.label(title, 48)
	heading.add_theme_font_override("font", ApexUI.BOLD)
	box.add_child(heading)
	var description := ApexUI.label(subtitle, 16, ApexUI.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(380, 28)
	box.add_child(description)
	var index: int = 0
	for key in buttons:
		var button := ApexUI.button(str(buttons[key]), func(): chosen.emit(key))
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size.y = 48
		box.add_child(button)
		if index == 0:
			button.call_deferred("grab_focus")
		index += 1
