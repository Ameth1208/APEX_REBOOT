class_name RouteProfilePanel
extends VBoxContainer

signal control_selected(index: int)
signal layout_changed

var analysis: Dictionary = {}
var _definition: Dictionary = {}
var _chart: ElevationProfile
var _metrics: Label
var _detail: Label
var _source: Label
var _window: OptionButton
var _original: CheckBox
var _toggle: Button
var _compact: bool = false
var _expanded: bool = false

func _ready() -> void:
	add_theme_constant_override("separation", 5)
	var header: HBoxContainer = GeoUi.row(self)
	var title: Label = GeoUi.label(header, "PERFIL Y PENDIENTES", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GeoUi.label(header, "Ventana", 12)
	_window = OptionButton.new()
	for value: int in [50, 100, 250]:
		_window.add_item("%d m" % value, value)
	_window.select(1)
	header.add_child(_window)
	_window.item_selected.connect(func(_index: int) -> void: set_definition(_definition))
	_original = CheckBox.new()
	_original.text = "Perfil original"
	header.add_child(_original)
	_original.toggled.connect(func(_value: bool) -> void: _render())
	_toggle = Button.new()
	_toggle.text = "Ver perfil"
	_toggle.visible = false
	_toggle.toggle_mode = true
	_toggle.add_theme_font_size_override("font_size", 12)
	header.add_child(_toggle)
	_toggle.toggled.connect(func(value: bool): _expanded = value; set_compact(_compact); layout_changed.emit())
	_metrics = GeoUi.label(self, "", 13)
	_chart = ElevationProfile.new()
	add_child(_chart)
	_chart.sample_selected.connect(_selected)
	_detail = GeoUi.label(self, "Pasa el cursor por el perfil para consultar la pendiente y seleccionar el tramo.", 12)
	_source = GeoUi.label(self, "", 11)
	_source.add_theme_color_override("font_color", Color("8da2ad"))

func set_compact(compact: bool) -> void:
	_compact = compact
	if not is_instance_valid(_chart):
		return
	_toggle.visible = compact
	_toggle.text = "Ocultar" if _expanded else "Ver perfil"
	for control: Control in [_chart, _metrics, _detail, _source]:
		control.visible = not compact or _expanded
	_chart.custom_minimum_size.y = 92 if compact else 150
	if compact and _expanded:
		_detail.hide()
		_source.hide()

func set_definition(definition: Dictionary) -> void:
	_definition = definition
	if not is_instance_valid(_chart):
		return
	analysis = RouteAnalyser.analyse(definition, float(_window.get_selected_id()))
	_original.disabled = definition.get("raw_route", []).is_empty()
	_render()

func _render() -> void:
	var original: bool = _original.button_pressed and not _original.disabled
	var data: Dictionary = analysis.get("raw", {}) if original else analysis.get("constructed", analysis)
	var absolute: bool = _definition.has("geo")
	var profile: Array = data.get("profile", []).duplicate(true)
	if not absolute:
		for sample: Dictionary in profile:
			sample["elevation_m"] = sample.get("height_m")
	_chart.set_profile(profile, absolute)
	_metrics.text = "%.2f km · subida %s m / bajada %s m · cota %s–%s m · pendiente máx. +%s / %s %%" % [
		float(data.get("horizontal_distance_m", 0.0)) / 1000.0,
		_number(data.get("elevation_gain_m")), _number(data.get("elevation_loss_m")),
		_number(data.get("min_elevation_m" if absolute else "min_height_m")), _number(data.get("max_elevation_m" if absolute else "max_height_m")),
		_number(data.get("max_uphill_pct"), 1), _number(data.get("max_downhill_pct"), 1)]
	var geo: Dictionary = _definition.get("geo", {})
	var label: String = "Original del archivo" if original else "Pista construida"
	var source: String = str(geo.get("elevation_source", "Alturas locales del editor"))
	if geo.get("is_flat_test", false):
		source = "PLANO DE PRUEBA · sin altimetría real"
	_source.text = "%s · %s · Ventana solicitada: %d m; cada muestra indica su ventana efectiva." % [label, source, _window.get_selected_id()]
	if not original and geo.get("edited_after_import", false):
		_source.text += " Geometría modificada en el editor."
	if not data.get("elevation_complete", true):
		_source.text += " Hay cotas ausentes; no se calculan totales completos."

func _selected(sample: Dictionary) -> void:
	var grade: String = _number(sample.get("grade_pct"), 2)
	var angle: String = "—" if sample.get("grade_pct") == null else "%.2f°" % rad_to_deg(atan(float(sample.grade_pct) / 100.0))
	_detail.text = "%.0f m de ruta · cota %s m · pendiente %s %% (%s) · sobre %.0f m horizontales" % [
		float(sample.get("distance_m", 0.0)), _number(sample.get("elevation_m"), 1), grade, angle, float(sample.get("window_m", 0.0))]
	var index: int = int(sample.get("control_index", -1))
	if index < 0:
		var best: int = 2147483647
		for i: int in range(_definition.get("points", []).size()):
			if int(_definition.points[i].get("raw_index", -1)) < 0:
				continue
			var difference: int = absi(int(_definition.points[i].get("raw_index", i)) - int(sample.get("raw_index", 0)))
			if difference < best:
				best = difference
				index = i
	if index >= 0:
		control_selected.emit(index)

func select_control(index: int) -> void:
	for i: int in range(_chart.profile.size()):
		if int(_chart.profile[i].get("control_index", -1)) == index:
			_chart.selected = i
			_chart.queue_redraw()
			return

func _number(value: Variant, places: int = 0) -> String:
	if value == null:
		return "—"
	return ("%." + str(places) + "f") % float(value)
