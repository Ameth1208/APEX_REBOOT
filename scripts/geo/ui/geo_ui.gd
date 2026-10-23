class_name GeoUi
extends RefCounted

static func label(parent: Node, text: String, font_size: int = 14) -> Label:
	var item: Label = Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if parent is HBoxContainer:
		item.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(item)
	return item

static func button(parent: Node, text: String, callback: Callable = Callable()) -> Button:
	var item: Button = Button.new()
	item.text = text
	if callback.is_valid():
		item.pressed.connect(callback)
	parent.add_child(item)
	return item

static func spin(parent: Node, minimum: float, maximum: float, step: float, value: float) -> SpinBox:
	var item: SpinBox = SpinBox.new()
	item.min_value = minimum
	item.max_value = maximum
	item.step = step
	item.value = value
	parent.add_child(item)
	return item

static func row(parent: Node) -> HBoxContainer:
	var item: HBoxContainer = HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)
	parent.add_child(item)
	return item
