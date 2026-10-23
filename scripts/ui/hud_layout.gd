class_name ApexHudLayout
extends RefCounted
## Corner panels and centred instruments share one responsive placement policy.

static func build(hud: Control, session: ApexRaceSession) -> Dictionary:
	var ui: Dictionary = {}
	hud.theme = ApexHudTheme.create()
	ui.tower = ApexRaceTower.new()
	hud.add_child(ui.tower)
	ui.tower.build(session)
	ui.timing_panel = ApexTimingPanel.new()
	hud.add_child(ui.timing_panel)
	ui.timing_panel.build(session)
	ui.cluster = ApexInstrumentCluster.new()
	hud.add_child(ui.cluster)
	ui.cluster.build(session.player.is_motorcycle)
	ui.map = ApexMinimap.new()
	hud.add_child(ui.map)
	ui.map.configure(session.track)
	ui.map.vehicles = session.vehicles
	ui.condition = ApexVehicleStatus.new()
	hud.add_child(ui.condition)
	ui.condition.setup(session.player.is_motorcycle)
	ui.telemetry_box = ApexHudTelemetry.new()
	hud.add_child(ui.telemetry_box)
	ui.telemetry_box.build()
	ui.notice_box = PanelContainer.new()
	ui.notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ui.notice_box)
	ui.message = ApexUI.label("", 18)
	ui.message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.notice_box.add_child(ui.message)
	ui.notice_box.visible = false
	ui.auto_badge = ApexUI.label("PILOTO AUTOMÁTICO", 14, Color("f4c76b"))
	ui.auto_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.auto_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.auto_badge.size = Vector2(190, 24)
	hud.add_child(ui.auto_badge)
	ui.auto_badge.visible = false
	ui.countdown = ApexUI.label("", 100)
	ui.countdown.add_theme_font_override("font", ApexHudTheme.BOLD)
	ui.countdown.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	ui.countdown.add_theme_constant_override("outline_size", 5)
	ui.countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.countdown.size = Vector2(380, 125)
	hud.add_child(ui.countdown)
	return ui

static func arrange(hud: Control, ui: Dictionary) -> void:
	if ui.is_empty() or hud.size.x <= 0.0:
		return
	var factor: float = minf(1.0, minf(hud.size.x / 1280.0, hud.size.y / 720.0))
	var margin := Vector2(28, 24) * factor
	# Hidden wrapped labels can momentarily measure at zero width. Restore the
	# intended warning-card size after their container finishes laying out.
	ui.condition.size = ui.condition.custom_minimum_size
	_place(ui.tower, margin, factor)
	_place(ui.timing_panel, Vector2(hud.size.x - margin.x - ui.timing_panel.size.x * factor, margin.y), factor)
	_place(ui.cluster, Vector2((hud.size.x - ui.cluster.size.x * factor) * 0.5, hud.size.y - margin.y - ui.cluster.size.y * factor), factor)
	_place(ui.map, Vector2(margin.x, hud.size.y - margin.y - ui.map.size.y * factor), factor)
	_place(ui.condition, Vector2(hud.size.x - margin.x - ui.condition.size.x * factor, hud.size.y - margin.y - ui.condition.size.y * factor), factor)
	_place(ui.telemetry_box, Vector2(ui.timing_panel.position.x, ui.timing_panel.position.y + (ui.timing_panel.size.y + 12) * factor), factor)
	ui.telemetry_box.size.x = ui.timing_panel.size.x
	ui.notice_box.size = Vector2(minf(430.0, hud.size.x / factor - 700.0), 66)
	_place(ui.notice_box, Vector2((hud.size.x - ui.notice_box.size.x * factor) * 0.5, margin.y + 8.0 * factor), factor)
	_place(ui.auto_badge, Vector2((hud.size.x - ui.auto_badge.size.x * factor) * 0.5, ui.cluster.position.y - 29.0 * factor), factor)
	_place(ui.countdown, (hud.size - ui.countdown.size * factor) * 0.5 - Vector2(0, 75) * factor, factor)

static func _place(control: Control, position: Vector2, factor: float) -> void:
	control.position = position
	control.scale = Vector2.ONE * factor
