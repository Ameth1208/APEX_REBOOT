extends RefCounted
## UI V2: vehicle is the protagonist. Modes on the left as plain text,
## minimal controls, big condensed typography, no card grids.

const Card = preload("res://scripts/ui/menu/vehicle_card.gd")
const Appearance = preload("res://scripts/ui/menu/garage_appearance.gd")

static func build(menu: Control, career: ApexCareer) -> Dictionary:
	var ui: Dictionary = {"cards": []}
	# Header: APEX + version right.
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(header)
	ui.header = header
	var brand := ApexUI.label("APEX", 32)
	brand.add_theme_font_override("font", ApexUI.BOLD)
	header.add_child(brand)
	var reboot := ApexUI.label("REBOOT", 13, ApexUI.ACCENT)
	reboot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(reboot)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	nav.add_theme_constant_override("margin_left", 32)
	header.add_child(nav)
	ui.nav = nav
	var conduct := ApexUI.button("CONDUCIR", func(): menu.show_section("drive"))
	conduct.flat = true
	conduct.custom_minimum_size = Vector2(112, 44)
	nav.add_child(conduct)
	var garage := ApexUI.button("GARAJE", func(): menu.show_section("garage"))
	garage.flat = true
	garage.custom_minimum_size = Vector2(92, 44)
	nav.add_child(garage)
	var create := ApexUI.button("CREAR PISTA", func(): menu.load_track_requested.emit())
	create.flat = true
	create.custom_minimum_size = Vector2(132, 44)
	nav.add_child(create)
	var settings := ApexUI.button("AJUSTES", func(): menu.options_requested.emit())
	settings.flat = true
	settings.custom_minimum_size = Vector2(100, 44)
	nav.add_child(settings)
	ui.drive_nav = conduct
	ui.garage_nav = garage
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var version := ApexUI.label(str(ProjectSettings.get_setting("application/config/version", "")), 11, ApexUI.MUTED)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(version)
	# Vehicle identity (top-left, below modes).
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 2)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(identity)
	ui.identity = identity
	ui.category = ApexUI.label("", 12, ApexUI.ACCENT)
	identity.add_child(ui.category)
	ui.name_label = ApexUI.label("", 34)
	ui.name_label.add_theme_font_override("font", ApexUI.BOLD)
	ui.name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(ui.name_label)
	ui.details = ApexUI.label("", 15, ApexUI.MUTED)
	identity.add_child(ui.details)
	# Vehicle strip at bottom (compact).
	ui.collection_label = ApexUI.label("VEHÍCULOS", 11, ApexUI.MUTED)
	menu.add_child(ui.collection_label)
	var strip := ScrollContainer.new()
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.follow_focus = true
	menu.add_child(strip)
	ui.strip = strip
	var collection := HBoxContainer.new()
	collection.add_theme_constant_override("separation", 6)
	strip.add_child(collection)
	for i: int in ApexCatalog.entries("vehicles").size():
		var card: Button = Card.new()
		collection.add_child(card)
		card.build(ApexCatalog.vehicle(i), i)
		card.pressed.connect(func(): menu.changed.emit("vehicle", i))
		ui.cards.append(card)
	# Right panel: condensed setup.
	_build_panel(menu, career, ui)
	return ui

static func _build_panel(menu: Control, career: ApexCareer, ui: Dictionary) -> void:
	var panel := PanelContainer.new()
	var style := ApexUI.style(Color(0.030, 0.038, 0.053, 0.94), Color("343b46"))
	style.border_width_left = 3
	style.border_color = ApexUI.ACCENT
	panel.add_theme_stylebox_override("panel", style)
	menu.add_child(panel)
	ui.panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var heading := ApexUI.label("CONDUCIR", 24)
	ui.heading = heading
	heading.add_theme_font_override("font", ApexUI.BOLD)
	box.add_child(heading)
	var hint := ApexUI.label("Elige una modalidad y sal a la pista.", 15, ApexUI.MUTED)
	ui.hint = hint
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	ui.session_hint = ApexUI.label("", 14, Color("c8d1db"))
	ui.session_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(ui.session_hint)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tabs_visible = false
	box.add_child(tabs)
	ui.tabs = tabs
	var setup_box := _page(tabs, "SESIÓN")
	ui.setup = ApexMenuSetup.new()
	setup_box.add_child(ui.setup)
	ui.setup.build(menu.values, career)
	ui.setup.changed.connect(func(key: String, value: Variant): menu.changed.emit(key, value))
	var look_box := _page(tabs, "DISEÑO")
	ui.merge(Appearance.build(look_box, menu))
	# Drive button: big, primary.
	ui.drive = ApexUI.button("CONTINUAR   ›", func(): menu.start_requested.emit(), true)
	ui.drive.custom_minimum_size.y = 52
	ui.drive.add_theme_font_size_override("font_size", 22)
	box.add_child(ui.drive)
	ui.choose_vehicle = ApexUI.button("ELEGIR VEHÍCULO  ›", func(): menu.show_section("drive"), true)
	box.add_child(ui.choose_vehicle)

static func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	return box

static func arrange(menu: Control, ui: Dictionary) -> void:
	if ui.is_empty() or menu.size.x < 1.0:
		return
	var margin: float = clampf(menu.size.x * 0.03, 24, 48)
	var side: float = clampf(menu.size.x * 0.24, 280, 350)
	# Header across top.
	ui.header.position = Vector2(margin, 16)
	ui.header.size = Vector2(menu.size.x - margin * 2.0, 44)
	# Identity: below modes, left side.
	ui.identity.position = Vector2(margin, maxf(352.0, menu.size.y * 0.55))
	ui.identity.size = Vector2(menu.size.x * 0.4, 110)
	ui.name_label.add_theme_font_size_override("font_size", clampi(int(menu.size.x / 28.0), 26, 42))
	# Vehicle strip at bottom.
	ui.collection_label.position = Vector2(margin, menu.size.y - margin - 162)
	ui.collection_label.size = Vector2(menu.size.x, 18)
	ui.strip.position = Vector2(margin, menu.size.y - margin - 138)
	ui.strip.size = Vector2(menu.size.x - margin * 2.0 - side - 16.0, 94)
	# Right panel.
	ui.panel.position = Vector2(menu.size.x - side - margin, 72)
	ui.panel.size = Vector2(side, maxf(400, menu.size.y - 72 - margin))
	# Compact cards.
	var card_width: float = 164.0
	for card: Button in ui.cards:
		card.custom_minimum_size.x = card_width
