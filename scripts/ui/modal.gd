class_name ApexModal
extends Control

signal chosen(action: String)

func build(title: String, subtitle: String, buttons: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 460
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(ApexUI.label("APEX REBOOT", 12, ApexUI.ACCENT))
	var heading := ApexUI.label(title, 31)
	heading.add_theme_font_override("font", ApexUI.BOLD)
	box.add_child(heading)
	var description := ApexUI.label(subtitle, 16, ApexUI.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(420, 28)
	box.add_child(description)
	var index: int = 0
	for key in buttons:
		var button := ApexUI.button(str(buttons[key]), func(): chosen.emit(key), index == 0)
		button.custom_minimum_size.y = 36
		box.add_child(button)
		if index == 0:
			button.call_deferred("grab_focus")
		index += 1
