class_name RouteDialogLayout
extends RefCounted

static func build(parent: Control) -> Dictionary:
	var ui: Dictionary = {}
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("0d141c")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	parent.add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var header: HBoxContainer = GeoUi.row(layout)
	var title: Label = GeoUi.label(header, "01  /  PLANIFICADOR DE RUTA", 27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.close = GeoUi.button(header, "Volver al editor")
	var intro: Label = GeoUi.label(layout, "Escribe una salida y una llegada. APEX calcula la ruta vial, adapta la pista al terreno y después te deja editarla.", 15)
	intro.add_theme_color_override("font_color", Color("9aa8b8"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var planner: PanelContainer = PanelContainer.new()
	planner.add_theme_stylebox_override("panel", ApexUI.style(Color("111a25"), Color("334256"), 8))
	layout.add_child(planner)
	var planner_row: HBoxContainer = GeoUi.row(planner)
	var from_label: Label = GeoUi.label(planner_row, "DESDE", 12)
	from_label.add_theme_color_override("font_color", Color("8da2ad"))
	ui.start = LineEdit.new()
	ui.start.placeholder_text = "Baranoa, Atlántico"
	ui.start.text = "Baranoa, Atlántico"
	ui.start.custom_minimum_size.x = 210
	planner_row.add_child(ui.start)
	var arrow: Label = GeoUi.label(planner_row, "→", 22)
	arrow.add_theme_color_override("font_color", ApexUI.ACCENT)
	var to_label: Label = GeoUi.label(planner_row, "HASTA", 12)
	to_label.add_theme_color_override("font_color", Color("8da2ad"))
	ui.finish = LineEdit.new()
	ui.finish.placeholder_text = "Juan de Acosta, Atlántico"
	ui.finish.text = "Juan de Acosta, Atlántico"
	ui.finish.custom_minimum_size.x = 230
	planner_row.add_child(ui.finish)
	ui.plan = GeoUi.button(planner_row, "GENERAR RUTA  ↗")
	ui.plan.custom_minimum_size.x = 170
	ui.plan.tooltip_text = "Busca los lugares y genera una ruta siguiendo las carreteras"
	ui.plan_status = GeoUi.label(layout, "Ruta vial automática disponible. También puedes importar un GPX o añadir puntos en el mapa.", 12)
	ui.plan_status.add_theme_color_override("font_color", Color("8da2ad"))
	var bar: HBoxContainer = GeoUi.row(layout)
	ui.import_button = GeoUi.button(bar, "Importar GPX / GeoJSON…")
	GeoUi.label(bar, "Latitud", 13)
	ui.lat = GeoUi.spin(bar, -80.0, 80.0, 0.00001, 4.651)
	ui.lat.custom_minimum_size.x = 145
	GeoUi.label(bar, "Longitud", 13)
	ui.lon = GeoUi.spin(bar, -180.0, 180.0, 0.00001, -74.092)
	ui.lon.custom_minimum_size.x = 145
	ui.go = GeoUi.button(bar, "Ir")
	ui.fit = GeoUi.button(bar, "Centrar ruta")
	var content: HBoxContainer = GeoUi.row(layout)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_column: VBoxContainer = VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(map_column)
	ui.map = GeographicMap.new()
	map_column.add_child(ui.map)
	var layer_bar: HBoxContainer = GeoUi.row(map_column)
	ui.layer = CheckBox.new()
	ui.layer.text = "Vista satélite"
	ui.layer.button_pressed = true
	ui.layer.tooltip_text = "Usa imagen aérea como referencia; no modifica la geometría de la pista."
	layer_bar.add_child(ui.layer)
	var layer_hint: Label = GeoUi.label(layer_bar, "La pista se dibuja encima", 11)
	layer_hint.add_theme_color_override("font_color", Color("8da2ad"))
	var attribution: LinkButton = LinkButton.new()
	attribution.text = "© Esri — World Imagery · © OpenStreetMap contributors"
	attribution.uri = "https://www.esri.com/en-us/legal/terms/full-master-agreement"
	attribution.add_theme_font_size_override("font_size", 13)
	map_column.add_child(attribution)
	GeoUi.label(map_column, "Clic: añadir punto · Clic derecho: quitar último · Botón central: desplazar · Rueda: zoom", 12)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.x = 320
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var side: VBoxContainer = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	scroll.add_child(side)
	GeoUi.label(side, "AJUSTES DE LA PISTA", 17)
	ui.name = LineEdit.new()
	ui.name.placeholder_text = "Nombre de la ruta"
	ui.name.text = "Mi ruta real"
	side.add_child(ui.name)
	ui.routes = OptionButton.new()
	ui.routes.visible = false
	side.add_child(ui.routes)
	ui.closed = CheckBox.new()
	ui.closed.text = "Circuito cerrado (unir fin e inicio)"
	side.add_child(ui.closed)
	GeoUi.label(side, "Anchura inicial de la pista · m", 13)
	ui.width = GeoUi.spin(side, 6, 30, 0.5, 12)
	var edit: HBoxContainer = GeoUi.row(side)
	ui.undo = GeoUi.button(edit, "Quitar último")
	ui.clear = GeoUi.button(edit, "Limpiar ruta")
	ui.summary = GeoUi.label(side, "Añade al menos dos puntos.", 14)
	side.add_child(HSeparator.new())
	GeoUi.label(side, "TERRENO REAL", 17)
	ui.provider = OptionButton.new()
	ui.provider.add_item("SRTM ~30 m · Open Topo Data")
	ui.provider.add_item("Copernicus GLO-90 · Open-Meteo")
	ui.provider.select(1 if OS.has_feature("web") else 0)
	side.add_child(ui.provider)
	ui.replace = CheckBox.new()
	ui.replace.text = "Sustituir también las cotas del archivo"
	side.add_child(ui.replace)
	ui.elevate = GeoUi.button(side, "ADAPTAR AL TERRENO")
	ui.cancel = GeoUi.button(side, "Cancelar consulta")
	ui.cancel.visible = false
	ui.flat = CheckBox.new()
	ui.flat.text = "Usar plano de prueba sin cotas reales"
	side.add_child(ui.flat)
	GeoUi.label(side, "La consulta envía las coordenadas al proveedor seleccionado. La cota del terreno puede diferir de la calzada en puentes y túneles.", 12)
	var source: LinkButton = LinkButton.new()
	source.text = "Fuentes: SRTM / Copernicus / Open-Meteo"
	source.uri = "https://open-meteo.com/en/docs/elevation-api"
	source.add_theme_font_size_override("font_size", 11)
	side.add_child(source)
	side.add_child(HSeparator.new())
	GeoUi.label(side, "La ruta vial se calcula automáticamente. Aquí puedes cambiar anchura, cotas y tipo de recorrido; los detalles finos se editan después.", 12)
	ui.status = GeoUi.label(layout, "Mapa centrado en Bogotá. Puedes ir a cualquier coordenada o importar tu propio archivo.", 13)
	var footer: HBoxContainer = GeoUi.row(layout)
	var hint: Label = GeoUi.label(footer, "Las rutas abiertas conservan su salida y llegada; no se añade una carretera de regreso.", 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.create = GeoUi.button(footer, "CONTINUAR Y EDITAR  ›")
	return ui
