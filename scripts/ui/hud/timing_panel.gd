class_name ApexTimingPanel
extends Control
## Time, lap validity and distance progress; no invented timed sectors.

const INK := Color("f3f5f8")
const MUTED := Color("adb5c2")
const ACCENT := Color("ff4b55")
var current_label: Label
var best_label: Label
var current_caption: Label
var best_caption: Label
var progress_label: Label
var progress_bar: ProgressBar
var validity_label: Label

func build(session: ApexRaceSession) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(294, 124)
	size = custom_minimum_size
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.047, 0.071, 0.82)))
	add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	panel.add_child(stack)
	var progress_row := HBoxContainer.new()
	stack.add_child(progress_row)
	progress_label = _label("RECORRIDO", 10, MUTED)
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(progress_label)
	validity_label = _label("", 10, ACCENT)
	progress_row.add_child(validity_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 3
	progress_bar.show_percentage = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.add_theme_stylebox_override("background", _bar_style(Color(0.30, 0.35, 0.42, 0.45)))
	progress_bar.add_theme_stylebox_override("fill", _bar_style(ACCENT))
	stack.add_child(progress_bar)
	var current := HBoxContainer.new()
	current.custom_minimum_size.y = 35
	stack.add_child(current)
	current_caption = _label("ACTUAL", 12, MUTED)
	current_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current.add_child(current_caption)
	current_label = _label("0:00.000", 26)
	current_label.add_theme_font_override("font", preload("res://assets/fonts/barlow/BarlowSemiCondensed-Bold.ttf"))
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	current.add_child(current_label)
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1
	rule.color = Color(0.55, 0.61, 0.70, 0.20)
	stack.add_child(rule)
	var best := HBoxContainer.new()
	best.custom_minimum_size.y = 25
	stack.add_child(best)
	best_caption = _label("MEJOR", 12, MUTED)
	best_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best.add_child(best_caption)
	best_label = _label("—:——.———", 18)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best.add_child(best_label)
	update_session(session, 0.0)

func update_session(session: ApexRaceSession, _delta: float) -> void:
	if session.laps.is_empty():
		return
	var lap: ApexLapTracker = session.laps[0]
	var length: float = maxf(1.0, session.track.get_length())
	var valid: bool = lap.last_lap_valid if lap.finished else lap.valid
	var progress: float = clampf(lap.distance / length, 0.0, 1.0)
	if lap.finished:
		progress = 1.0
	progress_bar.value = progress * 100.0
	progress_label.text = "RECORRIDO  %d %%" % floori(progress * 100.0)
	validity_label.text = "NO VÁLIDA" if not valid else ""
	current_label.text = _time(lap.previous if lap.finished else lap.lap_time)
	current_label.modulate = Color("ff9b88") if not valid else Color.WHITE
	if session.track.closed:
		current_caption.text = "ACTUAL"
		best_caption.text = "MEJOR"
		best_label.text = ApexLapTracker.format_time(lap.best)
	else:
		current_caption.text = "TIEMPO"
		best_caption.text = "META" if lap.finished else "FALTAN"
		var remaining: float = maxf(0.0, length - lap.distance)
		best_label.text = "COMPLETADA" if lap.finished else ("%.2f km" % (remaining / 1000.0) if remaining >= 1000.0 else "%.0f m" % remaining)

static func _time(seconds: float) -> String:
	return "0:00.000" if seconds <= 0.0 else ApexLapTracker.format_time(seconds)

static func _label(value: String, font_size: int, color: Color = INK) -> Label:
	var label := ApexUI.label(value, font_size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

static func _style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(0.55, 0.61, 0.70, 0.30)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 13
	box.content_margin_right = 13
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

static func _bar_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return box
