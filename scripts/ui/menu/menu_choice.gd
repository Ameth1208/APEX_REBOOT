extends VBoxContainer
## A focused value with left/right navigation for mouse, keyboard or gamepad.

signal selected(index: int)
var index: int = 0
var items: Array = []
var value_button: Button

func build(title: String, choices: Array, selection: int) -> void:
	items = choices
	index = clampi(selection, 0, maxi(0, items.size() - 1))
	add_theme_constant_override("separation", 3)
	add_child(ApexUI.label(title.to_upper(), 11, ApexUI.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	add_child(row)
	var previous := ApexUI.button("‹", func(): advance(-1))
	previous.custom_minimum_size = Vector2(29, 33)
	previous.focus_mode = Control.FOCUS_NONE
	row.add_child(previous)
	value_button = ApexUI.button("", func(): advance(1))
	value_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_button.custom_minimum_size.y = 33
	value_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_button.clip_text = true
	value_button.gui_input.connect(_navigate)
	row.add_child(value_button)
	var next := ApexUI.button("›", func(): advance(1))
	next.custom_minimum_size = Vector2(29, 33)
	next.focus_mode = Control.FOCUS_NONE
	row.add_child(next)
	_refresh()

func advance(direction: int) -> void:
	if items.is_empty():
		return
	index = posmod(index + direction, items.size())
	_refresh()
	selected.emit(index)

func _navigate(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		advance(-1 if event.is_action_pressed("ui_left") else 1)
		value_button.accept_event()

func _refresh() -> void:
	value_button.text = str(items[index]) if not items.is_empty() else "—"
	value_button.tooltip_text = value_button.text
