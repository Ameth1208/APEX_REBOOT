class_name TrackCreationFlow
extends Control
## Simplified track creation: 3 options, auto-processing, minimal questions.
## Philosophy: algorithm understands → generates → user corrects exceptions.

signal create_requested(source: String, data: Variant)
signal closed

var _panel: PanelContainer
var _status: Label
var _progress: ProgressBar
var _choice_box: VBoxContainer
var _result_box: VBoxContainer
var _current_file: String = ""

func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ApexUI.style(Color("0b1018")))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	_panel.add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	# Header.
	var header: HBoxContainer = HBoxContainer.new()
	layout.add_child(header)
	var title: Label = Label.new()
	title.text = "CREAR PISTA"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_font_override("font", ApexUI.BOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn: Button = Button.new()
	close_btn.text = "Volver"
	close_btn.pressed.connect(func(): closed.emit(); hide())
	header.add_child(close_btn)
	# Subtitle.
	var subtitle: Label = Label.new()
	subtitle.text = "¿Cómo quieres crearla?"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", ApexUI.MUTED)
	layout.add_child(subtitle)
	# Choice buttons.
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 10)
	layout.add_child(_choice_box)
	_add_choice("DIBUJAR EN MAPA", "Dibuja el trazado directamente sobre el mapa", "draw")
	_add_choice("IMPORTAR GPX / GEOJSON", "Usa un archivo de ruta existente", "import")
	_add_choice("CREAR DESDE RUTA REAL", "Selecciona una ruta del catálogo", "catalog")
	# Status area (hidden initially).
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", ApexUI.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	layout.add_child(_status)
	_progress = ProgressBar.new()
	_progress.visible = false
	_progress.custom_minimum_size.y = 6
	layout.add_child(_progress)
	# Result area (hidden initially).
	_result_box = VBoxContainer.new()
	_result_box.visible = false
	_result_box.add_theme_constant_override("separation", 8)
	layout.add_child(_result_box)

func _add_choice(title: String, desc: String, action: String) -> void:
	var btn: Button = Button.new()
	btn.text = title + "\n" + desc
	btn.alignment = HBoxContainer.ALIGNMENT_LEFT
	btn.custom_minimum_size.y = 52
	btn.pressed.connect(func(): _on_choice(action))
	_choice_box.add_child(btn)

func _on_choice(action: String) -> void:
	match action:
		"draw":
			create_requested.emit("draw", {})
			hide()
		"import":
			_open_file_dialog()
		"catalog":
			create_requested.emit("catalog", {})
			hide()

func _open_file_dialog() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.gpx, *.geojson, *.json ;Archivos de ruta"])
	dialog.title = "Importar ruta"
	dialog.file_selected.connect(func(path: String) -> void:
		_current_file = path
		_process_import(path))
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))

func _process_import(path: String) -> void:
	_show_status("Leyendo archivo...")
	_progress.visible = true
	_progress.value = 10
	_choice_box.visible = false
	# Read the file.
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_show_status("Error: no se pudo leer el archivo.")
		return
	var text: String = file.get_as_text()
	file.close()
	_progress.value = 30
	_show_status("Analizando ruta...")
	# Parse using the importer.
	var format: String = path.get_extension().to_lower()
	var result: Dictionary = RouteImporter.parse(text, format)
	if not result.get("ok", false):
		_show_status("Error: " + str(result.get("error", "desconocido")))
		return
	_progress.value = 60
	_show_status("Ruta detectada. Generando pista...")
	# Show result.
	_show_result(result)

func _show_result(result: Dictionary) -> void:
	_progress.value = 100
	_status.visible = false
	_progress.visible = false
	_result_box.visible = true
	for child: Node in _result_box.get_children():
		_result_box.remove_child(child)
		child.queue_free()
	var definition: Dictionary = result.get("definition", {})
	var name: String = str(definition.get("name", "Ruta sin nombre"))
	# Title.
	var title: Label = Label.new()
	title.text = name
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_font_override("font", ApexUI.BOLD)
	_result_box.add_child(title)
	# Stats.
	var stats: Array[String] = []
	var points: Array = definition.get("points", [])
	var total_dist: float = 0.0
	for i: int in range(1, points.size()):
		var p0: Vector3 = points[i - 1]
		var p1: Vector3 = points[i]
		total_dist += Vector2(p1.x - p0.x, p1.z - p0.z).length()
	stats.append("%.1f km" % (total_dist / 1000.0))
	if definition.get("closed", false):
		stats.append("circuito cerrado")
	var surface: String = str(definition.get("recon", {}).get("surface", "asphalt"))
	stats.append(surface.to_upper())
	var stats_label: Label = Label.new()
	stats_label.text = "  ·  ".join(stats)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", ApexUI.MUTED)
	_result_box.add_child(stats_label)
	# Checkmarks.
	for item: String in ["Ruta procesada", "Terreno listo", "Entorno detectado"]:
		var check: Label = Label.new()
		check.text = "✓ " + item
		check.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		_result_box.add_child(check)
	# Generate button.
	var generate: Button = Button.new()
	generate.text = "GENERAR PISTA"
	generate.custom_minimum_size.y = 48
	generate.pressed.connect(func():
		create_requested.emit("import", result)
		hide())
	_result_box.add_child(generate)
	# Advanced toggle.
	var advanced: Button = Button.new()
	advanced.text = "Controles avanzados >"
	advanced.flat = true
	advanced.alignment = HBoxContainer.ALIGNMENT_CENTER
	advanced.add_theme_color_override("font_color", ApexUI.MUTED)
	advanced.pressed.connect(func():
		_show_status("Controles avanzados disponibles en el editor de pistas."))
	_result_box.add_child(advanced)

func _show_status(text: String) -> void:
	_status.text = text
	_status.visible = true

func open() -> void:
	_choice_box.visible = true
	_status.visible = false
	_progress.visible = false
	_result_box.visible = false
	show()