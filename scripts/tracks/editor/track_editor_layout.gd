class_name TrackEditorLayout
extends RefCounted

static func build(parent: Control) -> Dictionary:
	var ui: Dictionary = {"buttons": {}}
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ApexUI.style(Color("0b1018")))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var header: HBoxContainer = GeoUi.row(layout)
	var title: Label = GeoUi.label(header, "EDITOR DE PISTAS", 25)
	title.add_theme_font_override("font", ApexUI.BOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.buttons["real_route"] = GeoUi.button(header, "RUTA REAL · MAPA / GPS")
	ui.buttons["close"] = GeoUi.button(header, "Volver")
	var bar: HBoxContainer = GeoUi.row(layout)
	for pair: Array in [["undo", "Deshacer"], ["redo", "Rehacer"], ["fit", "Centrar"], ["save", "Guardar"], ["load", "Cargar"], ["import", "Importar JSON"], ["export", "Exportar"]]:
		ui.buttons[pair[0]] = GeoUi.button(bar, pair[1])
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	ui.buttons["apply"] = ApexUI.button("APLICAR Y CONDUCIR", func(): pass, true)
	bar.add_child(ui.buttons["apply"])
	var content: HBoxContainer = GeoUi.row(layout)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(left)
	ui.map = TrackMap.new()
	left.add_child(ui.map)
	ui.profile = RouteProfilePanel.new()
	left.add_child(ui.profile)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.x = 290
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	ui.fields = TrackEditorFields.new()
	ui.fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ui.fields)
	ui.status = GeoUi.label(layout, "", 13)
	ui.status.add_theme_color_override("font_color", ApexUI.MUTED)
	ui.profile.layout_changed.connect(func(): _arrange(parent, ui))
	parent.resized.connect(func(): _arrange(parent, ui), CONNECT_DEFERRED)
	_arrange.call_deferred(parent, ui)
	return ui

static func _arrange(parent: Control, ui: Dictionary) -> void:
	ui.map.custom_minimum_size.y = (96 if ui.profile._expanded else 160) if parent.size.y < 700 else 240
	ui.profile.set_compact(parent.size.y < 700)
