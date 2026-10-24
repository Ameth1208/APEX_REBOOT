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
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var version := ApexUI.label(str(ProjectSettings.get_setting("application/config/version", "")), 11, ApexUI.MUTED)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(version)
	# Left column: game modes as plain text (spec section 3).
	var modes := VBoxContainer.new()
	modes.add_theme_constant_override("separation", 4)
	modes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(modes)
	ui.modes = modes
	var mode_title := ApexUI.label("JUGAR", 11, ApexUI.ACCENT)
	modes.add_child(mode_title)
	ui.mode_buttons = []
	for item: Array in [["CARRERA", "Carrera"], ["CONTRARRELOJ", "Contrarreloj"], ["LIBRE", "Libre"], ["CAMPEONATO", "Campeonato"]]:
		var btn := ApexUI.button(item[0], func(): menu.changed.emit("mode", item[1]))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.custom_minimum_size.y = 30
		btn.add_theme_font_size_override("font_size", 19)
		btn.add_theme_font_override("font", ApexUI.BOLD)
		modes.add_child(btn)
		ui.mode_buttons.append({"btn": btn, "mode": item[1]})
	# Separator.
	var sep := HSeparator.new()
	modes.add_child(sep)
	# Create track.
	var create_btn := ApexUI.button("CREAR PISTA", func(): menu.editor_requested.emit())
	create_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	create_btn.flat = true
	create_btn.custom_minimum_size.y = 30
	create_btn.add_theme_font_size_override("font_size", 17)
	modes.add_child(create_btn)
	# Bottom-left: settings/credits.
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 2)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(bottom)
	ui.bottom = bottom
	for pair: Array in [["AJUSTES", "options_requested"], ["CRÉDITOS", "credits_requested"]]:
		var b := ApexUI.button(pair[0], func(): menu.emit_signal(pair[1]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.custom_minimum_size.y = 26
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", ApexUI.MUTED)
		bottom.add_child(b)
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
	var heading := ApexUI.label("PREPARA TU SALIDA", 17)
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
	# Drive button: big, primary.
	ui.drive = ApexUI.button("CONDUCIR   ›", func(): menu.start_requested.emit(), true)
	ui.drive.custom_minimum_size.y = 52
	ui.drive.add_theme_font_size_override("font_size", 22)
	box.add_child(ui.drive)

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
	# Left column: modes.
	ui.modes.position = Vector2(margin, 84)
	ui.modes.size = Vector2(240, 240)
	# Identity: below modes, left side.
	ui.identity.position = Vector2(margin, menu.size.y * 0.42)
	ui.identity.size = Vector2(menu.size.x * 0.4, 110)
	ui.name_label.add_theme_font_size_override("font_size", clampi(int(menu.size.x / 28.0), 26, 42))
	# Vehicle strip at bottom.
	ui.collection_label.position = Vector2(margin, menu.size.y - margin - 96)
	ui.collection_label.size = Vector2(menu.size.x, 18)
	ui.strip.position = Vector2(margin, menu.size.y - margin - 74)
	ui.strip.size = Vector2(menu.size.x - margin * 2.0 - side - 16.0, 74)
	# Bottom-left: settings.
	ui.bottom.position = Vector2(margin, menu.size.y - margin - 24)
	ui.bottom.size = Vector2(200, 56)
	# Right panel.
	ui.panel.position = Vector2(menu.size.x - side - margin, 72)
	ui.panel.size = Vector2(side, maxf(400, menu.size.y - 72 - margin))
	# Compact cards.
	var card_width: float = 120.0
	for card: Button in ui.cards:
		card.custom_minimum_size.x = card_width
	# Highlight active mode.
	if ui.has("mode_buttons"):
		var current_mode: String = str(menu.values.get("mode", "Carrera"))
		for entry: Dictionary in ui.mode_buttons:
			var btn: Button = entry["btn"]
			var active: bool = str(entry["mode"]) == current_mode
			btn.add_theme_color_override("font_color", ApexUI.ACCENT if active else ApexUI.INK)
