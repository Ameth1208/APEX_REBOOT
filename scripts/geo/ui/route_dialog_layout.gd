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
	var title: Label = GeoUi.label(header, "DEL MAPA A LA PISTA", 27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.close = GeoUi.button(header, "Volver al editor")
	GeoUi.label(layout, "Traza puntos siguiendo la carretera o importa una ruta GPS. Cada segmento se convierte en una pista editable.", 14)
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
	var attribution: LinkButton = LinkButton.new()
	attribution.text = GeoServices.setting("map_attribution", "© OpenStreetMap contributors")
	attribution.uri = GeoServices.setting("map_license_url", "https://www.openstreetmap.org/copyright")
	attribution.add_theme_font_size_override("font_size", 13)
	map_column.add_child(attribution)
	GeoUi.label(map_column, "Clic: añadir · Clic derecho: quitar último · Botón central: desplazar · Rueda: zoom", 12)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.x = 320
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var side: VBoxContainer = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	scroll.add_child(side)
	GeoUi.label(side, "TU RECORRIDO", 17)
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
	GeoUi.label(side, "ALTURAS DEL TERRENO", 17)
	ui.provider = OptionButton.new()
	ui.provider.add_item("SRTM ~30 m · Open Topo Data")
	ui.provider.add_item("Copernicus GLO-90 · Open-Meteo")
	ui.provider.select(1 if OS.has_feature("web") else 0)
	side.add_child(ui.provider)
	ui.replace = CheckBox.new()
	ui.replace.text = "Sustituir también las cotas del archivo"
	side.add_child(ui.replace)
	ui.elevate = GeoUi.button(side, "Obtener cotas y analizar")
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
	GeoUi.label(side, "La ruta sigue los puntos dibujados: no se ajusta automáticamente a las calles. Anchura, peralte y paisaje se editan después.", 12)
	ui.status = GeoUi.label(layout, "Mapa centrado en Bogotá. Puedes ir a cualquier coordenada o importar tu propio archivo.", 13)
	var footer: HBoxContainer = GeoUi.row(layout)
	var hint: Label = GeoUi.label(footer, "Las rutas abiertas conservan su salida y llegada; no se añade una carretera de regreso.", 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.create = GeoUi.button(footer, "Crear pista y ver perfil ›")
	return ui
