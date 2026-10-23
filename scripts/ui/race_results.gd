class_name ApexRaceResults
extends ApexModal

func show_result(result: Dictionary, career_text: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.023, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 850
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(ApexUI.label("APEX REBOOT  /  RESULTADOS", 14, ApexUI.ACCENT))
	var retired: bool = bool(result.get("retired", false))
	box.add_child(ApexUI.label("SESIÓN TERMINADA" if retired else "BANDERA A CUADROS", 33))
	var heading: String = "RETIRADA · DNF" if retired else "POSICIÓN %d / %d" % [int(result.position), int(result.racers)]
	box.add_child(ApexUI.label(heading, 23, ApexUI.ACCENT))
	var summary: String = "%s  %s   ·   Mejor %s" % ["Tiempo de etapa" if not result.get("closed", true) else "Tiempo total", ApexLapTracker.format_time(float(result.total)), ApexLapTracker.format_time(float(result.best))]
	summary += "\nRecorridos válidos %d · inválidos %d" % [int(result.get("valid_laps", 0)), int(result.get("invalid_laps", 0))]
	if result.get("autopilot", false):
		summary += " · Piloto IA utilizado"
	box.add_child(ApexUI.label(summary, 16, ApexUI.MUTED))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for title: String in ["POS", "PILOTO", "ESTADO", "TIEMPO", "MEJOR"]:
		grid.add_child(ApexUI.label(title, 12, ApexUI.MUTED))
	for row: Dictionary in result.get("classification", []):
		var color: Color = ApexUI.ACCENT if bool(row.get("is_player", false)) else Color.WHITE
		var status: String = "DNF" if row.get("retired", false) else str(row.get("status", ""))
		for value: String in [str(row.get("position", "—")), str(row.get("name", "Piloto")), status, ApexLapTracker.format_time(float(row.get("total", 0.0))), ApexLapTracker.format_time(float(row.get("best", 0.0)))]:
			grid.add_child(ApexUI.label(value, 15, color))
	if not career_text.is_empty():
		var progression := ApexUI.label(career_text, 16, ApexUI.ACCENT)
		progression.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(progression)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var retry := ApexUI.button("VOLVER A CORRER", func(): chosen.emit("restart"), true)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(retry)
	var garage := ApexUI.button("VOLVER AL GARAJE", func(): chosen.emit("garage"))
	garage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(garage)
