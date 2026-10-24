class_name ApexMainMenu
extends Control
## Garage composition and incremental state updates.

const Layout = preload("res://scripts/ui/menu/garage_layout.gd")
signal start_requested
signal editor_requested
signal load_track_requested
signal options_requested
signal credits_requested
signal changed(key: String, value: Variant)

var name_label: Label
var category_label: Label
var details: Label
var cards: Array[Button] = []
var values: Dictionary
var setup: ApexMenuSetup
var livery_select: OptionButton
var _livery_ids: Array[String] = []
var _ui: Dictionary = {}
var _vehicle_index: int = -1
var _paint_name: String = ""
var _reveal_pending: bool = false

func build(settings: Dictionary, career: ApexCareer) -> void:
	values = settings
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui = Layout.build(self, career)
	name_label = _ui.name_label
	category_label = _ui.category
	details = _ui.details
	setup = _ui.setup
	livery_select = _ui.livery
	for card: Button in _ui.cards:
		cards.append(card)
	livery_select.item_selected.connect(func(i: int): changed.emit("livery", _livery_ids[i]))
	resized.connect(_arrange)
	update_vehicle(int(values.vehicle))
	show_section("drive")
	_arrange.call_deferred()
	_ui.drive.call_deferred("grab_focus")

func update_vehicle(index: int) -> void:
	var profile: Dictionary = ApexCatalog.vehicle(index)
	if index != _vehicle_index:
		_vehicle_index = index
		name_label.text = str(profile.get("display_name", "Vehículo"))
		category_label.text = "VEHÍCULO SELECCIONADO  /  " + str(profile.get("category_label", "Vehículo")).to_upper()
		livery_select.clear()
		_livery_ids.clear()
		for livery: Dictionary in profile.get("liveries", [{"id": "Original", "name": "Original"}]):
			_livery_ids.append(str(livery.id))
			livery_select.add_item(str(livery.get("name", livery.id)))
		for i: int in cards.size():
			cards[i].set_selected(i == index)
		_ui.collection_label.text = "COLECCIÓN  /  %02d DE %02d" % [index + 1, cards.size()]
		_queue_reveal_selected()
	var livery_index: int = maxi(0, _livery_ids.find(str(values.get("livery", "Original"))))
	if livery_select.selected != livery_index:
		livery_select.select(livery_index)
	details.text = "%d kW    /    %d kg    /    %s" % [int(profile.get("engine_power_kw", 0)), int(profile.get("mass_kg", 0)), str(profile.get("drive", "RWD"))]
	if _ui.has("session_hint"):
		var track: Dictionary = ApexCatalog.track(int(values.get("track", 0)))
		_ui.session_hint.text = "CONFIGURACIÓN ACTUAL\n%s · %s" % [str(profile.get("display_name", "Vehículo")), str(track.get("name", "Pista seleccionada"))]
	if _paint_name != str(values.paint):
		_paint_name = str(values.paint)
		_ui.paint_label.text = "COLOR  /  " + _paint_name.to_upper()
		for i: int in _ui.swatches.size():
			_ui.swatches[i].set_pressed_no_signal(ApexCatalog.PAINT_NAMES[i] == _paint_name)

func _arrange() -> void:
	Layout.arrange(self, _ui)
	_queue_reveal_selected()

func show_section(section: String) -> void:
	var garage: bool = section == "garage"
	_ui.tabs.current_tab = 1 if garage else 0
	_ui.strip.visible = garage
	_ui.collection_label.visible = garage
	_ui.drive.visible = not garage
	_ui.choose_vehicle.visible = garage
	_ui.heading.text = "GARAJE" if garage else "CONDUCIR"
	_ui.hint.text = "Elige tu vehículo y personaliza su apariencia." if garage else "Prepara tu sesión con el vehículo seleccionado."
	_ui.drive_nav.add_theme_color_override("font_color", ApexUI.MUTED if garage else ApexUI.ACCENT)
	_ui.garage_nav.add_theme_color_override("font_color", ApexUI.ACCENT if garage else ApexUI.MUTED)
	if garage and not cards.is_empty():
		cards[clampi(_vehicle_index, 0, cards.size() - 1)].call_deferred("grab_focus")
		_queue_reveal_selected()
	else:
		_ui.drive.call_deferred("grab_focus")

func _queue_reveal_selected() -> void:
	if _reveal_pending or not is_inside_tree():
		return
	_reveal_pending = true
	# Scroll only after containers have applied the new card widths.
	get_tree().process_frame.connect(_reveal_selected, CONNECT_ONE_SHOT | CONNECT_DEFERRED)

func _reveal_selected() -> void:
	_reveal_pending = false
	if _vehicle_index >= 0 and _vehicle_index < cards.size():
		_ui.strip.ensure_control_visible(cards[_vehicle_index])
