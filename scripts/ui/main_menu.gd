class_name ApexMainMenu
extends Control
## Garage composition and incremental state updates.

const Layout = preload("res://scripts/ui/menu/garage_layout.gd")
signal start_requested
signal editor_requested
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
	_arrange.call_deferred()
	_ui.drive.call_deferred("grab_focus")

func update_vehicle(index: int) -> void:
	var profile: Dictionary = ApexCatalog.vehicle(index)
	if index != _vehicle_index:
		_vehicle_index = index
		name_label.text = str(profile.get("display_name", "Vehículo"))
		category_label.text = str(profile.get("category_label", "Vehículo")).to_upper()
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
	if _paint_name != str(values.paint):
		_paint_name = str(values.paint)
		_ui.paint_label.text = "COLOR  /  " + _paint_name.to_upper()
		for i: int in _ui.swatches.size():
			_ui.swatches[i].set_pressed_no_signal(ApexCatalog.PAINT_NAMES[i] == _paint_name)

func _arrange() -> void:
	Layout.arrange(self, _ui)
	_queue_reveal_selected()

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
