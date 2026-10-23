class_name ApexScreens
extends CanvasLayer

signal start_requested
signal changed(key: String, value: Variant)
signal action_requested(action: String)
signal track_applied(definition: Dictionary)

var root := Control.new()
var menu: ApexMainMenu
var hud: ApexHUD
var modal: ApexModal
var options: ApexOptionsPanel
var editor: Control
var loading: ApexModal

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ApexUI.make_theme()

func show_menu(values: Dictionary, career: ApexCareer) -> void:
	clear_overlay()
	_release(hud)
	hud = null
	_release(menu)
	menu = ApexMainMenu.new()
	root.add_child(menu)
	menu.build(values, career)
	menu.start_requested.connect(func(): start_requested.emit())
	menu.changed.connect(func(key: String, value: Variant): changed.emit(key, value))
	menu.editor_requested.connect(func(): action_requested.emit("editor"))
	menu.options_requested.connect(func(): action_requested.emit("options"))

func show_hud(session: ApexRaceSession) -> void:
	_release(menu)
	menu = null
	_release(hud)
	clear_overlay()
	hud = ApexHUD.new()
	root.add_child(hud)
	hud.build(session)
	hud.pause_requested.connect(func(): action_requested.emit("pause"))

func show_modal(title: String, subtitle: String, actions: Dictionary) -> void:
	clear_overlay()
	if is_instance_valid(hud): hud.visible = false
	modal = ApexModal.new()
	root.add_child(modal)
	modal.build(title, subtitle, actions)
	modal.chosen.connect(func(action: String): action_requested.emit(action))

func show_loading(text: String) -> void:
	show_modal("PREPARANDO PISTA", text, {})

func show_results(result: Dictionary, career_text: String) -> void:
	clear_overlay()
	if is_instance_valid(hud): hud.visible = false
	var results := ApexRaceResults.new()
	modal = results
	root.add_child(results)
	results.show_result(result, career_text)
	results.chosen.connect(func(action: String): action_requested.emit(action))

func show_options(values: Dictionary) -> void:
	clear_overlay()
	if is_instance_valid(hud): hud.visible = false
	options = ApexOptionsPanel.new()
	root.add_child(options)
	options.build(values)
	options.changed.connect(func(key: String, value: Variant): changed.emit(key, value))
	options.closed.connect(func(): action_requested.emit("close_overlay"))

func show_editor(definition: Dictionary) -> void:
	clear_overlay()
	if is_instance_valid(hud): hud.visible = false
	editor = load("res://scripts/ui/track_editor.gd").new()
	root.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.applied.connect(func(data: Dictionary): track_applied.emit(data))
	editor.closed.connect(func(): action_requested.emit("close_overlay"))
	editor.open(definition)

func clear_overlay() -> void:
	_release(modal)
	_release(options)
	_release(editor)
	modal = null
	options = null
	editor = null
	if is_instance_valid(hud): hud.visible = true

func _release(node: Variant) -> void:
	if is_instance_valid(node) and not node.is_queued_for_deletion():
		node.get_parent().remove_child(node)
		node.queue_free()
