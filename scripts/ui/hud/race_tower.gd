class_name ApexRaceTower
extends Control
## Compact race order. Red marks the player; gaps are relative to that player.

const Intervals = preload("res://scripts/ui/hud/intervals.gd")
const INK := Color("f3f5f8")
const MUTED := Color("adb5c2")
const ACCENT := Color("ff4b55")
var title_label: Label
var lap_label: Label
var position_label: Label
var driver_labels: Array[Label] = []
var interval_labels: Array[Label] = []
var place_labels: Array[Label] = []
var row_controls: Array[PanelContainer] = []
var rows: Array[Dictionary] = []
var _stripes: Array[ColorRect] = []
var _gaps := Intervals.new()
var _refresh: float = 0.0
var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat

func build(session: ApexRaceSession) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count: int = session.vehicles.size() if session.vehicles.size() > 1 else 0
	custom_minimum_size = Vector2(310, 75 + count * 29)
	size = custom_minimum_size
	_normal_style = _row_style(false)
	_selected_style = _row_style(true)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _background(Color(0.035, 0.047, 0.071, 0.82)))
	add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 34
	header.add_theme_constant_override("separation", 9)
	stack.add_child(header)
	var stripe := ColorRect.new()
	stripe.color = ACCENT
	stripe.custom_minimum_size = Vector2(4, 0)
	header.add_child(stripe)
	title_label = _label(str(session.settings.get("mode", "Carrera")).to_upper(), 16)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	position_label = _label("", 18)
	position_label.add_theme_font_override("font", preload("res://assets/fonts/barlow/BarlowSemiCondensed-Bold.ttf"))
	position_label.custom_minimum_size.x = 82
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(position_label)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 11
	header.add_child(spacer)
	lap_label = _label("", 17)
	lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lap_label.custom_minimum_size.y = 34
	stack.add_child(lap_label)
	var rule := ColorRect.new()
	rule.color = Color(0.55, 0.61, 0.70, 0.24)
	rule.custom_minimum_size.y = 1
	stack.add_child(rule)
	for index: int in count:
		_add_row(stack)
	update_session(session, 0.0)

func update_session(session: ApexRaceSession, delta: float) -> void:
	if session.laps.is_empty():
		return
	var lap: ApexLapTracker = session.laps[0]
	position_label.visible = session.vehicles.size() > 1
	if not session.track.closed:
		lap_label.text = "ETAPA"
	elif session.settings.get("mode", "") == "Libre":
		lap_label.text = "VUELTA %d" % lap.lap
	else:
		lap_label.text = "VUELTA %d / %d" % [mini(lap.lap, int(session.settings.laps)), int(session.settings.laps)]
	_gaps.update_session(session, delta)
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.20
	rows = session.classification()
	for index: int in row_controls.size():
		var row: Dictionary = rows[index]
		var player: bool = bool(row.is_player)
		var retired: bool = bool(row.retired)
		if player:
			position_label.text = "%d / %d" % [int(row.position), rows.size()]
		place_labels[index].text = str(row.position)
		driver_labels[index].text = str(row.name).to_upper()
		interval_labels[index].text = _gaps.text_for(session, int(row.index))
		interval_labels[index].modulate = ACCENT if retired else INK
		_stripes[index].color = ACCENT if player else Color(0.55, 0.60, 0.68, 0.35)
		row_controls[index].modulate = Color(1, 1, 1, 0.55) if retired else Color.WHITE
		row_controls[index].add_theme_stylebox_override("panel", _selected_style if player else _normal_style)

func reset_intervals() -> void:
	_gaps.clear()
	_refresh = 0.0

func _add_row(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 29
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _normal_style)
	parent.add_child(panel)
	row_controls.append(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var place := _label("", 15, MUTED)
	place.custom_minimum_size.x = 20
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(place)
	place_labels.append(place)
	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(3, 14)
	stripe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stripe)
	_stripes.append(stripe)
	var driver := _label("", 18)
	driver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	driver.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	driver.clip_text = true
	row.add_child(driver)
	driver_labels.append(driver)
	var interval := _label("—", 15, MUTED)
	interval.custom_minimum_size.x = 66
	interval.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(interval)
	interval_labels.append(interval)

static func _label(value: String, font_size: int, color: Color = INK) -> Label:
	var label := ApexUI.label(value, font_size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

static func _background(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(0.55, 0.61, 0.70, 0.30)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_bottom = 4
	return box

static func _row_style(player: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.44, 0.12, 0.18, 0.52) if player else Color(0.045, 0.061, 0.085, 0.25)
	box.content_margin_left = 9
	box.content_margin_right = 12
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	return box
