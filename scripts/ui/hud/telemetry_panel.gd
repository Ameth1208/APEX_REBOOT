class_name ApexHudTelemetry
extends PanelContainer
## Detailed diagnostics are available only when the player explicitly opens them.

var details: Label

func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(294, 0)
	size = Vector2(294, 300)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var heading := ApexUI.label("TELEMETRÍA", 14, ApexHudTheme.RED)
	column.add_child(heading)
	details = ApexUI.label("", 16, ApexHudTheme.MUTED)
	details.autowrap_mode = TextServer.AUTOWRAP_OFF
	details.add_theme_constant_override("line_spacing", 4)
	column.add_child(details)
	visible = false

func update_state(data: Dictionary, camera_mode: String) -> void:
	var lines: PackedStringArray = [
		"Cámara  " + camera_mode,
		"Suelo  %s · contactos %d" % [str(data.surface), int(data.grounded_wheels)],
		"Carga aero  %.0f N" % float(data.downforce_n),
		"Dirección  %+.1f°" % rad_to_deg(float(data.steer_angle)),
		"Inclinación  %+.1f°" % rad_to_deg(float(data.lean_angle)),
		"Deslizamiento  %.2f" % float(data.tire_slip),
		"Rebufo  %.0f %%" % (float(data.get("draft_strength", 0.0)) * 100.0),
		"Carga conservada  %.0f %%" % (float(data.get("downforce_multiplier", 1.0)) * 100.0),
		"Estado motor  %d %%" % roundi(float(data.get("engine_health", 1.0)) * 100),
		"Estado dirección  %d %%" % roundi(float(data.get("steering_health", 1.0)) * 100),
		"Estado aero  %d %%" % roundi(float(data.get("aero_health", 1.0)) * 100),
		"ABS  %s    TCS  %s" % ["activo" if data.abs_active else "—", "activo" if data.tcs_active else "—"]]
	details.text = "\n".join(lines)
