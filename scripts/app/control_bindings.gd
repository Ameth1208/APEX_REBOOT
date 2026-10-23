class_name ApexBindings
extends RefCounted
## Physical keys stay stable across keyboard layouts; labels use the local layout.

const EDITABLE: Array[String] = ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reverse", "shift_up", "shift_down", "camera_next", "reset_car"]
const LABELS: Dictionary = {
	"accelerate": "Acelerar", "brake": "Frenar", "steer_left": "Girar a la izquierda",
	"steer_right": "Girar a la derecha", "handbrake": "Freno trasero / de mano",
	"reverse": "Marcha atrás", "shift_up": "Subir marcha", "shift_down": "Bajar marcha",
	"camera_next": "Cambiar cámara", "reset_car": "Recolocar y reparar",
	"pause_game": "Pausa", "toggle_lights": "Faros", "toggle_night": "Día / noche",
	"editor": "Editor", "telemetry": "Telemetría", "autopilot": "Piloto IA",
	"photo": "Modo foto", "performance_report": "Informe de rendimiento", "screenshot": "Captura"
}
static var _labels: Dictionary = {}

static func invalidate() -> void:
	_labels.clear()

static func label_for(action: String) -> String:
	if _labels.has(action):
		return str(_labels[action])
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var physical: int = int(event.physical_keycode)
			var local: int = physical
			if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
				local = int(DisplayServer.keyboard_get_keycode_from_physical(physical))
			_labels[action] = OS.get_keycode_string(local if local != 0 else physical)
			return str(_labels[action])
	return "—"

static func conflict(action: String, code: int) -> String:
	if code in [0, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return "Elige una tecla sin modificadores."
	for other: String in LABELS:
		if other == action or not InputMap.has_action(other):
			continue
		for event: InputEvent in InputMap.action_get_events(other):
			if event is InputEventKey and int(event.physical_keycode) == code:
				return "Esa tecla ya controla: %s." % str(LABELS[other])
	return ""

static func driving_help(motorcycle: bool = false) -> String:
	return "%s / %s  Acelerar / frenar     %s / %s  Dirección     %s  %s" % [label_for("accelerate"), label_for("brake"), label_for("steer_left"), label_for("steer_right"), label_for("handbrake"), "Freno trasero" if motorcycle else "Freno de mano"]
