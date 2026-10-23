extends RefCounted
## A measured garage layout leaves the vehicle visible between its controls.

const Card = preload("res://scripts/ui/menu/vehicle_card.gd")
const Appearance = preload("res://scripts/ui/menu/garage_appearance.gd")

static func build(menu: Control, career: ApexCareer) -> Dictionary:
	var ui: Dictionary = {"cards": []}
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(header)
	ui.header = header
	var brand := ApexUI.label("APEX", 37)
	brand.add_theme_font_override("font", ApexUI.BOLD)
	header.add_child(brand)
	var reboot := ApexUI.label("REBOOT", 15, ApexUI.ACCENT)
	reboot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(reboot)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var version := ApexUI.label("GARAJE  /  " + str(ProjectSettings.get_setting("application/config/version", "")), 12, ApexUI.MUTED)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(version)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 3)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(identity)
	ui.identity = identity
	ui.category = ApexUI.label("", 13, ApexUI.ACCENT)
	identity.add_child(ui.category)
	ui.name_label = ApexUI.label("", 42)
	ui.name_label.add_theme_font_override("font", ApexUI.BOLD)
	ui.name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(ui.name_label)
	ui.details = ApexUI.label("", 16, ApexUI.MUTED)
	identity.add_child(ui.details)
	ui.collection_label = ApexUI.label("COLECCIÓN", 12, ApexUI.MUTED)
	menu.add_child(ui.collection_label)
	var strip := ScrollContainer.new()
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.follow_focus = true
	menu.add_child(strip)
	ui.strip = strip
	var collection := HBoxContainer.new()
	collection.add_theme_constant_override("separation", 8)
	strip.add_child(collection)
	for i: int in ApexCatalog.entries("vehicles").size():
		var card: Button = Card.new()
		collection.add_child(card)
		card.build(ApexCatalog.vehicle(i), i)
		card.pressed.connect(func(): menu.changed.emit("vehicle", i))
		ui.cards.append(card)
	_build_panel(menu, career, ui)
	return ui

static func _build_panel(menu: Control, career: ApexCareer, ui: Dictionary) -> void:
	var panel := PanelContainer.new()
	var style := ApexUI.style(Color(0.030, 0.038, 0.053, 0.94), Color("343b46"))
	style.border_width_top = 3
	style.border_color = ApexUI.ACCENT
	panel.add_theme_stylebox_override("panel", style)
	menu.add_child(panel)
	ui.panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var heading := ApexUI.label("PREPARA TU SALIDA", 21)
	heading.add_theme_font_override("font", ApexUI.BOLD)
	box.add_child(heading)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.all_tabs_in_front = true
	box.add_child(tabs)
	ui.tabs = tabs
	var setup_box := _page(tabs, "SESIÓN")
	ui.setup = ApexMenuSetup.new()
	setup_box.add_child(ui.setup)
	ui.setup.build(menu.values, career)
	ui.setup.changed.connect(func(key: String, value: Variant): menu.changed.emit(key, value))
	var look_box := _page(tabs, "DISEÑO")
	ui.merge(Appearance.build(look_box, menu))
	ui.drive = ApexUI.button("CONDUCIR   ›", func(): menu.start_requested.emit(), true)
	ui.drive.custom_minimum_size.y = 48
	ui.drive.add_theme_font_size_override("font_size", 20)
	box.add_child(ui.drive)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	for pair: Array in [["EDITOR", "editor_requested"], ["AJUSTES", "options_requested"]]:
		var action: String = pair[1]
		var button := ApexUI.button(pair[0], func(): menu.emit_signal(action))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 34
		button.add_theme_font_size_override("font_size", 14)
		buttons.add_child(button)

static func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	return box

static func arrange(menu: Control, ui: Dictionary) -> void:
	if ui.is_empty() or menu.size.x < 1.0:
		return
	var margin: float = clampf(menu.size.x * 0.025, 20, 40)
	var side: float = clampf(menu.size.x * 0.255, 292, 368)
	var left: float = menu.size.x - margin * 2.0 - side - 24.0
	ui.header.position = Vector2(margin, 18)
	ui.header.size = Vector2(menu.size.x - margin * 2.0, 52)
	ui.identity.position = Vector2(margin, 92 if menu.size.y < 620 else 112)
	ui.identity.size = Vector2(left, 100)
	ui.name_label.add_theme_font_size_override("font_size", 29 if menu.size.y < 620 else clampi(int(left / 18.0), 32, 46))
	ui.details.visible = menu.size.y >= 620
	ui.panel.position = Vector2(menu.size.x - side - margin, 88)
	ui.panel.size = Vector2(side, maxf(380, menu.size.y - 88 - margin))
	ui.strip.position = Vector2(margin, menu.size.y - margin - 88)
	ui.strip.size = Vector2(left, 88)
	ui.collection_label.position = ui.strip.position - Vector2(0, 25)
	ui.collection_label.size = Vector2(left, 20)
	var card_width: float = floorf((left - 24) / 4.0) if left >= 700 else floorf((left - 8) / 2.0)
	for card: Button in ui.cards:
		card.custom_minimum_size.x = maxf(166, card_width)
