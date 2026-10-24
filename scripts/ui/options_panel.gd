class_name ApexOptionsPanel
extends Control

signal closed
signal changed(key: String, value: Variant)
var _values: Dictionary
var tabs: TabContainer
var _navigation: VBoxContainer
var _categories: Array[Button] = []

func build(values: Dictionary) -> void:
	_values = values
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.03, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(ApexUI.label("AJUSTES", 40))
	box.add_child(ApexUI.label("Conducción, cámara y rendimiento · tus preferencias se guardan automáticamente", 14, ApexUI.MUTED))
	tabs = TabContainer.new()
	tabs.tabs_visible = false
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 32)
	box.add_child(content)
	_navigation = VBoxContainer.new()
	_navigation.custom_minimum_size.x = 180
	_navigation.add_theme_constant_override("separation", 8)
	content.add_child(_navigation)
	content.add_child(tabs)
	var controls := ApexControlsPanel.new()
	_page("CONTROLES").add_child(controls)
	controls.changed.connect(func(key: String, value: Variant): changed.emit(key, value))
	controls.build(values)
	_build_display(_page("GRÁFICOS"))
	_slider(_page("AUDIO"), "Volumen general", "volume", 0.0, 1.0, 0.05, "")
	_build_driving(_page("Conducción"))
	_build_hud(_page("HUD"))
	_build_camera(_page("Accesibilidad"))
	_select_category(0)
	var done := ApexUI.button("‹  VOLVER", func(): closed.emit())
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.custom_minimum_size.x = 230
	box.add_child(done)
	done.call_deferred("grab_focus")

func _page(caption: String) -> VBoxContainer:
	var index: int = _categories.size()
	var category := ApexUI.button(caption.to_upper(), func(): _select_category(index))
	category.alignment = HORIZONTAL_ALIGNMENT_LEFT
	category.flat = true
	_navigation.add_child(category)
	_categories.append(category)
	var scroll := ScrollContainer.new()
	scroll.name = caption
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	box.add_child(ApexUI.label(caption.to_upper(), 26))
	return box

func _select_category(index: int) -> void:
	tabs.current_tab = index
	for i: int in _categories.size():
		_categories[i].add_theme_color_override("font_color", ApexUI.ACCENT if i == index else ApexUI.MUTED)

func _advanced(box: VBoxContainer, title: String) -> VBoxContainer:
	var content := VBoxContainer.new()
	var toggle := ApexUI.button("▸  " + title, func():
		content.visible = not content.visible)
	toggle.flat = true
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(toggle)
	content.visible = false
	box.add_child(content)
	return content

func _build_driving(box: VBoxContainer) -> void:
	ApexUI.option(box, "Ayudas", ["Asistida · ABS, tracción y estabilidad", "Sport · ABS", "Experta · sin ayudas"], ["Assisted", "Sport", "Expert"].find(str(_values.assists)), func(i: int): changed.emit("assists", ["Assisted", "Sport", "Expert"][i]))
	ApexUI.option(box, "Cambio", ["Automático", "Manual"], 0 if _values.automatic else 1, func(i: int): changed.emit("automatic", i == 0))
	ApexUI.option(box, "Nivel de los rivales", ["Accesible", "Normal", "Experto"], ["Easy", "Normal", "Expert"].find(str(_values.get("ai_difficulty", "Normal"))), func(i: int): changed.emit("ai_difficulty", ["Easy", "Normal", "Expert"][i]))
	_check(box, "Trazada orientativa", "racing_line")
	box = _advanced(box, "Controles avanzados")
	_slider(box, "Respuesta de la dirección", "steering_response", 0.4, 2.5, 0.1, "×")
	_slider(box, "Curva del stick · mayor valor, centro más suave", "steering_curve", 0.6, 2.5, 0.1, "×")
	_slider(box, "Curva de acelerador y freno", "pedal_curve", 0.5, 2.5, 0.1, "×")
	_slider(box, "Zona muerta de dirección", "steering_deadzone", 0.0, 0.4, 0.01, "")
	_slider(box, "Zona muerta de gatillos", "pedal_deadzone", 0.0, 0.3, 0.01, "")
	box.add_child(ApexUI.label("VOLANTE LOGITECH G923 · PC", 12, ApexUI.MUTED))
	_spin(box, "Eje de dirección", "wheel_steering_axis", 0, 15)
	_spin(box, "Eje del acelerador", "wheel_throttle_axis", 0, 15)
	_spin(box, "Eje del freno", "wheel_brake_axis", 0, 15)
	_check(box, "Invertir dirección del volante", "wheel_invert_steering")
	_slider(box, "Carga aerodinámica", "aero", 0.0, 2.0, 0.1, "×")
	_slider(box, "Adherencia de neumáticos", "grip", 0.6, 1.4, 0.05, "×")

func _build_camera(box: VBoxContainer) -> void:
	_slider(box, "Campo de visión vertical", "camera_fov", 50.0, 95.0, 1.0, "°")
	_slider(box, "Acompañar inclinación de moto", "camera_bank", 0.0, 1.0, 0.05, "")
	_slider(box, "Movimiento de cabeza y respuesta a impactos", "camera_motion", 0.0, 1.0, 0.05, "")
	var text := ApexUI.label("Cambia la vista durante la conducción. Persecución, depósito y piloto acompañan la moto al máximo por defecto. Reduce el movimiento para una cámara más estable. Estos ajustes solo cambian la imagen.", 16, ApexUI.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)

func _build_hud(box: VBoxContainer) -> void:
	_check(box, "Mostrar minimapa", "hud_minimap")
	_check(box, "Mostrar clasificación", "hud_standings")
	_check(box, "Mostrar tiempos", "hud_timing")
	_slider(box, "Tamaño del velocímetro", "hud_cluster_scale", 0.7, 1.2, 0.05, "×")

func _build_display(box: VBoxContainer) -> void:
	_check(box, "Pantalla completa", "fullscreen")
	var qualities := ["Automático", "Rendimiento", "Equilibrado", "Alto"]
	ApexUI.option(box, "Calidad de imagen", qualities, maxi(0, qualities.find(str(_values.quality))), func(i: int): changed.emit("quality", qualities[i]))
	box = _advanced(box, "Opciones gráficas avanzadas")
	_check(box, "Vegetación y árboles", "render_vegetation")
	_check(box, "Edificios del entorno", "render_buildings")
	_check(box, "Agua y superficies lejanas", "render_water")
	_check(box, "Postes y lámparas", "render_lamps")
	_check(box, "Props decorativos", "render_props")
	_check(box, "Sombras dinámicas", "render_shadows")
	_check(box, "Niebla atmosférica", "render_fog")
	var text := ApexUI.label("Automático adapta la imagen para buscar una conducción fluida. Rendimiento prioriza la respuesta; Equilibrado y Alto mantienen su nivel de detalle. Los menús y el HUD conservan su nitidez. F8 guarda un informe de rendimiento.", 16, ApexUI.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)

func _check(box: VBoxContainer, title: String, key: String) -> void:
	var check := CheckButton.new()
	check.text = title
	check.button_pressed = bool(_values.get(key, false))
	check.toggled.connect(func(value: bool): changed.emit(key, value))
	box.add_child(check)

func _slider(box: VBoxContainer, title: String, key: String, low: float, high: float, step: float, suffix: String) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var caption := ApexUI.label(title, 15)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(caption)
	var value_label := ApexUI.label("%.2f%s" % [float(_values[key]), suffix], 15, ApexUI.ACCENT)
	row.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(_values[key])
	slider.custom_minimum_size.y = 24
	slider.value_changed.connect(func(value: float):
		value_label.text = "%.2f%s" % [value, suffix]
		changed.emit(key, value))
	box.add_child(slider)

func _spin(box: VBoxContainer, title: String, key: String, low: int, high: int) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var caption := ApexUI.label(title, 15)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = 1.0
	spin.value = int(_values.get(key, low))
	spin.custom_minimum_size = Vector2(120, 38)
	spin.value_changed.connect(func(value: float): changed.emit(key, int(value)))
	row.add_child(spin)
