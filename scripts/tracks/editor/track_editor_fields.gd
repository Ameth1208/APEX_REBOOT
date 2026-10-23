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

func _ready() -> void:
	custom_minimum_size.x = 264.0
	add_theme_constant_override("separation", 9)
	var title: Label = Label.new()
	title.text = "DISEÑO DEL CIRCUITO"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)
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
	var interpolation: OptionButton = OptionButton.new()
	interpolation.add_item("Curva suavizada · Catmull–Rom")
	interpolation.add_item("Lineal · conservar cotas importadas")
	interpolation.item_selected.connect(func(index: int) -> void: _emit("interpolation", "linear" if index == 1 else "catmull_rom"))
	add_child(interpolation)
	_inputs["interpolation"] = interpolation
	_point_title = Label.new()
	_point_title.add_theme_font_size_override("font_size", 20)
	add_child(_point_title)
	_spin("x", "Posición X · m", -40000.0, 40000.0, 1.0)
	_spin("z", "Posición Z · m", -40000.0, 40000.0, 1.0)
	_spin("y", "Altura local · m", -10000.0, 10000.0, 0.5)
	_spin("width", "Anchura · m", 6.0, 30.0, 0.5)
	_spin("bank", "Peralte · °", -22.0, 22.0, 0.5)
	_select("surface", "Superficie del tramo")
	var texture_button: Button = Button.new()
	texture_button.text = "Elegir textura de esta superficie…"
	texture_button.pressed.connect(func() -> void: texture_pressed.emit(_selected_surface))
	add_child(texture_button)
	var remove: Button = Button.new()
	remove.text = "Eliminar punto seleccionado"
	remove.pressed.connect(func() -> void: delete_pressed.emit())
	add_child(remove)
	add_child(HSeparator.new())
	_spin("thickness", "Espesor de la pista · m", 0.25, 8.0, 0.25)
	_spin("runoff_width", "Escapatoria · m", 1.0, 12.0, 0.5)
	_select("runoff_surface", "Material de escapatoria")
	_select("terrain_surface", "Material del terreno")
	_spin("terrain_hills", "Relieve del paisaje · m", 0.0, 60.0, 1.0)
	var hint: Label = Label.new()
	hint.text = "Los cambios se reconstruyen al pulsar Aplicar. La altura y el peralte afectan a la conducción."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.6, 0.69, 0.73))
	hint.add_theme_font_size_override("font_size", 12)
	add_child(hint)

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
			# Reassigning text resets Godot's caret, selection and IME composition.
			# Only replace content when a selection/undo actually changes the value.
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
	add_child(row)
	_inputs[key] = input

func _select(key: String, title: String) -> void:
	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 13)
	add_child(label)
	var input: OptionButton = OptionButton.new()
	for item: String in LABELS:
		input.add_item(item)
	input.item_selected.connect(func(index: int) -> void: _emit(key, TrackDefinition.SURFACES[index]))
	add_child(input)
	_inputs[key] = input

func _emit(key: String, value: Variant) -> void:
	if not _refreshing:
		changed.emit(key, value)
