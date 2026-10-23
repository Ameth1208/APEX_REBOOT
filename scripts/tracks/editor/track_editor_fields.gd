class_name TrackEditorFields
extends VBoxContainer

signal changed(key: String, value: Variant)
signal delete_pressed
signal texture_pressed(surface: String)

const LABELS: Array[String] = ["Asfalto", "Hormigón", "Grava", "Tierra", "Hierba", "Arena"]
var _inputs: Dictionary = {}
var _point_title: Label
var _refreshing: bool = false
var _selected_surface: String = "asphalt"
var _advanced_box: VBoxContainer
var _advanced_toggle: Button
var _advanced_visible: bool = false

func _ready() -> void:
	custom_minimum_size.x = 264.0
	add_theme_constant_override("separation", 8)
	# --- HEADER ---
	var title: Label = Label.new()
	title.text = "DISEÑO DEL CIRCUITO"
	title.add_theme_font_size_override("font_size", 15)
	add_child(title)
	# --- QUICK ACTIONS (always visible) ---
	var quick: HBoxContainer = HBoxContainer.new()
	quick.add_theme_constant_override("separation", 6)
	var preset_btn: Button = Button.new()
	preset_btn.text = "Montaña"
	preset_btn.tooltip_text = "Preset: relieve alto, escapatoria ancha"
	preset_btn.pressed.connect(func(): _emit("preset_mountain", true))
	quick.add_child(preset_btn)
	var preset2: Button = Button.new()
	preset2.text = "Urbano"
	preset2.tooltip_text = "Preset: plano, estrecho, sin valla"
	preset2.pressed.connect(func(): _emit("preset_urban", true))
	quick.add_child(preset2)
	var preset3: Button = Button.new()
	preset3.text = "Circuito"
	preset3.tooltip_text = "Preset: carril, peralte, valla"
	preset3.pressed.connect(func(): _emit("preset_circuit", true))
	quick.add_child(preset3)
	add_child(quick)
	# --- NAME + CLOSED ---
	var name_input: LineEdit = LineEdit.new()
	name_input.placeholder_text = "Nombre del circuito"
	name_input.max_length = 160
	name_input.text_changed.connect(func(value: String) -> void: _emit("name", value))
	add_child(name_input)
	_inputs["name"] = name_input
	var closed_input: CheckBox = CheckBox.new()
	closed_input.text = "Circuito cerrado"
	closed_input.toggled.connect(func(value: bool) -> void: _emit("closed", value))
	add_child(closed_input)
	_inputs["closed"] = closed_input
	# --- INTERPOLATION ---
	var interpolation: OptionButton = OptionButton.new()
	interpolation.add_item("Curva suavizada · Recomendado")
	interpolation.add_item("Lineal · Conservar cotas")
	interpolation.item_selected.connect(func(index: int) -> void: _emit("interpolation", "linear" if index == 1 else "catmull_rom"))
	add_child(interpolation)
	_inputs["interpolation"] = interpolation
	# --- SELECTED POINT ---
	_point_title = Label.new()
	_point_title.add_theme_font_size_override("font_size", 18)
	add_child(_point_title)
	_spin("x", "X · m", -40000.0, 40000.0, 1.0)
	_spin("z", "Z · m", -40000.0, 40000.0, 1.0)
	_spin("y", "Altura · m", -10000.0, 10000.0, 0.5)
	_spin("width", "Anchura · m", 6.0, 30.0, 0.5)
	_spin("bank", "Peralte · °", -22.0, 22.0, 0.5)
	_select("surface", "Superficie")
	# --- ADVANCED (collapsed by default) ---
	add_child(HSeparator.new())
	_advanced_toggle = Button.new()
	_advanced_toggle.text = "▸ Avanzado (terreno, texturas, estructura)"
	_advanced_toggle.flat = true
	_advanced_toggle.alignment = HBoxContainer.ALIGNMENT_LEFT
	_advanced_toggle.pressed.connect(_toggle_advanced)
	add_child(_advanced_toggle)
	_advanced_box = VBoxContainer.new()
	_advanced_box.visible = false
	_advanced_box.add_theme_constant_override("separation", 8)
	add_child(_advanced_box)
	_build_advanced()
	# --- DELETE (always visible) ---
	var remove: Button = Button.new()
	remove.text = "Eliminar punto seleccionado"
	remove.pressed.connect(func() -> void: delete_pressed.emit())
	add_child(remove)
	var hint: Label = Label.new()
	hint.text = "Los cambios se aplican al pulsar APLICAR Y CONDUCIR. F7 = Modo Física."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.65))
	hint.add_theme_font_size_override("font_size", 11)
	add_child(hint)

func _build_advanced() -> void:
	# Move previously-hidden fields into advanced box.
	_spin_into(_advanced_box, "thickness", "Espesor · m", 0.25, 8.0, 0.25)
	_spin_into(_advanced_box, "runoff_width", "Escapatoria · m", 1.0, 12.0, 0.5)
	_select_into(_advanced_box, "runoff_surface", "Material escapatoria")
	_select_into(_advanced_box, "terrain_surface", "Material terreno")
	_spin_into(_advanced_box, "terrain_hills", "Relieve · m", 0.0, 60.0, 1.0)
	var interp_label: Label = Label.new()
	interp_label.text = "Textura personalizada…"
	interp_label.add_theme_font_size_override("font_size", 13)
	_advanced_box.add_child(interp_label)
	var texture_button: Button = Button.new()
	texture_button.text = "Elegir textura de superficie"
	texture_button.pressed.connect(func() -> void: texture_pressed.emit(_selected_surface))
	_advanced_box.add_child(texture_button)

func _toggle_advanced() -> void:
	_advanced_visible = not _advanced_visible
	_advanced_box.visible = _advanced_visible
	_advanced_toggle.text = ("▾" if _advanced_visible else "▸") + " Avanzado (terreno, texturas, estructura)"

func show_point(definition: Dictionary, index: int) -> void:
	if _inputs.is_empty():
		return
	_refreshing = true
	var points: Array = definition["points"]
	var point: Dictionary = points[clampi(index, 0, points.size() - 1)]
	_point_title.text = "Punto %02d / %02d" % [index + 1, points.size()]
	_selected_surface = str(point["surface"])
	for key: String in _inputs:
		var input: Control = _inputs[key]
		var value: Variant = point.get(key, definition.get(key, 0.0))
		if input is SpinBox:
			if not is_equal_approx((input as SpinBox).value, float(value)):
				(input as SpinBox).set_value_no_signal(float(value))
		elif input is LineEdit:
			if (input as LineEdit).text != str(value):
				(input as LineEdit).text = str(value)
		elif input is CheckBox:
			(input as CheckBox).set_pressed_no_signal(bool(value))
		elif input is OptionButton:
			if key == "interpolation":
				(input as OptionButton).select(1 if str(value) == "linear" else 0)
			else:
				(input as OptionButton).select(maxi(0, TrackDefinition.SURFACES.find(str(value))))
	_refreshing = false

func _spin(key: String, title: String, minimum: float, maximum: float, step: float) -> void:
	_spin_into(self, key, title, minimum, maximum, step)

func _spin_into(parent: Control, key: String, title: String, minimum: float, maximum: float, step: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	var input: SpinBox = SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.custom_minimum_size.x = 104.0
	input.value_changed.connect(func(value: float) -> void: _emit(key, value))
	row.add_child(input)
	parent.add_child(row)
	_inputs[key] = input

func _select(key: String, title: String) -> void:
	_select_into(self, key, title)

func _select_into(parent: Control, key: String, title: String) -> void:
	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)
	var input: OptionButton = OptionButton.new()
	for item: String in LABELS:
		input.add_item(item)
	input.item_selected.connect(func(index: int) -> void: _emit(key, TrackDefinition.SURFACES[index]))
	parent.add_child(input)
	_inputs[key] = input

func _emit(key: String, value: Variant) -> void:
	if not _refreshing:
		changed.emit(key, value)