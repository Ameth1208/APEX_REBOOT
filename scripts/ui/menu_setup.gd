class_name ApexMenuSetup
extends VBoxContainer
## Only the choices that affect the selected session are visible.

const Choice = preload("res://scripts/ui/menu/menu_choice.gd")
signal changed(key: String, value: Variant)
var options: Dictionary
var career: ApexCareer
var event_picker: OptionButton
var _laps: Control
var _rivals: Control
var _event: Control
var _track: Control

func build(values: Dictionary, progression: ApexCareer) -> void:
	options = values
	career = progression
	add_theme_constant_override("separation", 10)
	var modes := ["Libre", "Contrarreloj", "Carrera", "Campeonato"]
	_choice("Sesión", modes, modes.find(str(values.mode)), func(i: int):
		changed.emit("mode", modes[i])
		_update_context(modes[i]))
	var track_names: Array = []
	for i in ApexCatalog.entries("tracks").size():
		track_names.append(ApexCatalog.track(i).get("name", "Circuito %d" % (i + 1)))
	_track = _choice("Circuito", track_names, int(values.track), func(i: int): changed.emit("track", i))
	var event_names: Array = []
	for i in range(career.unlocked + 1):
		event_names.append(ApexCareer.EVENTS[i].name)
	_event = VBoxContainer.new()
	add_child(_event)
	event_picker = ApexUI.option(_event, "Etapa del campeonato", event_names, int(values.get("career_event", 0)), func(i: int): changed.emit("career_event", i))
	_laps = _choice("Vueltas", ["1 vuelta", "2 vueltas", "3 vueltas", "5 vueltas", "10 vueltas"], [1, 2, 3, 5, 10].find(int(values.laps)), func(i: int): changed.emit("laps", [1, 2, 3, 5, 10][i]))
	_rivals = _choice("Parrilla", ["Sin rivales", "1 rival", "2 rivales", "3 rivales", "4 rivales", "5 rivales"], int(values.opponents), func(i: int): changed.emit("opponents", i))
	_choice("Conducción", ["Asistida", "Sport", "Experta"], ["Assisted", "Sport", "Expert"].find(str(values.assists)), func(i: int): changed.emit("assists", ["Assisted", "Sport", "Expert"][i]))
	var environments := ["Día · seco", "Noche · seco", "Día · húmedo", "Noche · húmedo"]
	var environment_index: int = (1 if values.night else 0) + (2 if float(values.wetness) > 0 else 0)
	_choice("Condiciones", environments, environment_index, func(i: int):
		changed.emit("night", i % 2 == 1)
		changed.emit("wetness", 0.7 if i >= 2 else 0.0))
	_update_context(str(values.mode))

func _choice(title: String, items: Array, selected: int, callback: Callable) -> Control:
	var choice: VBoxContainer = Choice.new()
	add_child(choice)
	choice.build(title, items, selected)
	choice.selected.connect(callback)
	return choice

func _update_context(mode: String) -> void:
	_event.visible = mode == "Campeonato"
	event_picker.disabled = not _event.visible
	_track.visible = mode != "Campeonato"
	_laps.visible = mode in ["Carrera", "Contrarreloj"]
	_rivals.visible = mode == "Carrera"
