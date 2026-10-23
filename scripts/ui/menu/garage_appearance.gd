extends RefCounted
## Paint and liveries share a dedicated garage tab.

static func build(parent: VBoxContainer, menu: Control) -> Dictionary:
	var result: Dictionary = {"swatches": []}
	result.paint_label = ApexUI.label("COLOR", 12, ApexUI.MUTED)
	parent.add_child(result.paint_label)
	var swatches := GridContainer.new()
	swatches.columns = 4
	swatches.add_theme_constant_override("h_separation", 8)
	swatches.add_theme_constant_override("v_separation", 8)
	parent.add_child(swatches)
	var group := ButtonGroup.new()
	for i: int in ApexCatalog.PAINT_NAMES.size():
		var paint_name: String = ApexCatalog.PAINT_NAMES[i]
		var button := ApexUI.button("ORIG." if i == 0 else "", func(): menu.changed.emit("paint", paint_name))
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(48, 35)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = paint_name
		if i > 0:
			var color: Color = ApexCatalog.PAINT_COLORS[i]
			button.add_theme_stylebox_override("normal", ApexUI.style(color, Color("606978"), 2))
			var pressed := ApexUI.style(color, Color.WHITE, 2)
			pressed.set_border_width_all(3)
			button.add_theme_stylebox_override("pressed", pressed)
			button.add_theme_stylebox_override("hover", ApexUI.style(color.lightened(0.12), Color.WHITE, 2))
		swatches.add_child(button)
		result.swatches.append(button)
	parent.add_child(ApexUI.label("DECORACIÓN", 12, ApexUI.MUTED))
	var livery := OptionButton.new()
	livery.custom_minimum_size.y = 39
	livery.fit_to_longest_item = false
	livery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	livery.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(livery)
	result.livery = livery
	var note := ApexUI.label("Tu combinación queda guardada para este vehículo.", 14, ApexUI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)
	return result
