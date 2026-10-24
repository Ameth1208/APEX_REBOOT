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
var backdrop: ApexMenuBackdrop

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop = ApexMenuBackdrop.new()
	add_child(backdrop)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ApexUI.make_theme()

func show_menu(values: Dictionary, career: ApexCareer) -> void:
	# The showroom is rendered behind the menu. An opaque canvas hid every car.
	backdrop.visible = false
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
	menu.load_track_requested.connect(func(): action_requested.emit("load_track"))
	menu.options_requested.connect(func(): action_requested.emit("options"))
	menu.credits_requested.connect(func(): action_requested.emit("credits"))

func show_hud(session: ApexRaceSession) -> void:
	backdrop.visible = false
	_release(menu)
	menu = null
	_release(hud)
	clear_overlay()
	hud = ApexHUD.new()
	root.add_child(hud)
	hud.build(session)
	hud.pause_requested.connect(func(): action_requested.emit("pause"))

func show_modal(title: String, subtitle: String, actions: Dictionary) -> void:
	backdrop.visible = false
	clear_overlay()
	if is_instance_valid(hud): hud.visible = false
	modal = ApexModal.new()
	root.add_child(modal)
	modal.build(title, subtitle, actions)
	modal.chosen.connect(func(action: String): action_requested.emit(action))

func show_loading(text: String) -> void:
	show_modal("PREPARANDO PISTA", text, {})

func show_results(result: Dictionary, career_text: String) -> void:
	backdrop.visible = false
	clear_overlay()
	if is_instance_valid(hud): hud.visible = false
	var results := ApexRaceResults.new()
	modal = results
	root.add_child(results)
	results.show_result(result, career_text)
	results.chosen.connect(func(action: String): action_requested.emit(action))

func show_options(values: Dictionary) -> void:
	backdrop.visible = true
	clear_overlay()
	if is_instance_valid(hud): hud.visible = false
	options = ApexOptionsPanel.new()
	root.add_child(options)
	options.build(values)
	options.changed.connect(func(key: String, value: Variant): changed.emit(key, value))
	options.closed.connect(func(): action_requested.emit("close_overlay"))

func show_editor(definition: Dictionary) -> void:
	backdrop.visible = true
	clear_overlay()
	if is_instance_valid(hud): hud.visible = false
	editor = load("res://scripts/ui/track_editor.gd").new()
	root.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.applied.connect(func(data: Dictionary): track_applied.emit(data))
	editor.closed.connect(func(): action_requested.emit("close_overlay"))
	editor.open(definition)

func show_creation_flow() -> void:
	backdrop.visible = true
	clear_overlay()
	if is_instance_valid(hud): hud.visible = false
	editor = load("res://scripts/ui/track_creation_flow.gd").new()
	root.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.create_requested.connect(func(source: String, data: Variant):
		if source == "import" and data is Dictionary and data.has("definition"):
			track_applied.emit(data["definition"])
		elif source == "load" and data is Dictionary:
			# Open the saved definition in the real editor instead of dropping it.
			show_editor(data)
		elif source == "draw":
			action_requested.emit("editor")
		elif source == "route":
			action_requested.emit("route_planner"))
	editor.closed.connect(func(): action_requested.emit("close_overlay"))
	if editor.has_method("open"):
		editor.open()

func show_route_planner(definition: Dictionary) -> void:
	show_editor(definition)
	var route_dialog: Variant = editor.get("_real_route") if is_instance_valid(editor) else null
	if route_dialog != null:
		route_dialog.call_deferred("open", {})

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
