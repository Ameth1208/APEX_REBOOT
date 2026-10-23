class_name TrackEditorStorage
extends RefCounted

signal loaded(definition: Dictionary)
signal message(text: String)
signal texture_chosen(surface: String, path: String)

var _dialog: FileDialog
var _mode: String = "load"
var _definition: Dictionary = {}
var _surface: String = "asphalt"
var _browser: RouteFilePicker

func setup(parent: Control) -> void:
	_dialog = FileDialog.new()
	_dialog.size = Vector2i(880, 580)
	_dialog.exclusive = true
	_dialog.file_selected.connect(_selected)
	parent.add_child(_dialog)
	DirAccess.make_dir_recursive_absolute("user://tracks")
	if OS.has_feature("web"):
		_browser = RouteFilePicker.new()
		parent.add_child(_browser)
		_browser.loaded.connect(func(text: String, filename: String) -> void: _read_json(text, filename))
		_browser.failed.connect(func(text: String) -> void: message.emit(text))

func save_local(definition: Dictionary) -> void:
	var title: String = str(definition.get("name", "circuito")).validate_filename()
	if title.is_empty():
		title = "circuito"
	var path: String = "user://tracks/" + title + ".json"
	_write(path, definition)

func choose(mode: String, definition: Dictionary, surface: String = "asphalt") -> void:
	_mode = mode
	_definition = definition.duplicate(true)
	_surface = surface
	if OS.has_feature("web") and mode == "import":
		_browser.choose()
		return
	if OS.has_feature("web") and mode == "export":
		if not definition.get("surface_textures", {}).is_empty():
			message.emit("Exporta paquetes con imágenes desde Windows/Linux. Guardar conserva la pista en este navegador.")
			return
		JavaScriptBridge.download_buffer(JSON.stringify(definition, "\t").to_utf8_buffer(), str(definition.get("name", "pista")).validate_filename() + ".json", "application/json")
		message.emit("Descarga del JSON solicitada al navegador.")
		return
	_dialog.access = FileDialog.ACCESS_USERDATA if mode == "load" else FileDialog.ACCESS_FILESYSTEM
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if mode == "export" else FileDialog.FILE_MODE_OPEN_FILE
	_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Texturas"]) if mode == "texture" else PackedStringArray(["*.json ; Circuitos APEX"])
	_dialog.title = {"load": "Cargar circuito guardado", "import": "Importar circuito JSON", "export": "Exportar circuito y texturas", "texture": "Elegir textura"}.get(mode, "Circuito")
	if mode == "load":
		_dialog.current_dir = "user://tracks"
	elif mode == "export":
		_dialog.current_file = str(definition.get("name", "circuito")).validate_filename() + ".json"
	_dialog.popup_centered(Vector2i(880, 580))

func _selected(path: String) -> void:
	if _mode == "export":
		_export(path)
	elif _mode == "texture":
		_import_texture(path)
	else:
		_read(path)

func _read(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		message.emit("No se pudo abrir el circuito.")
		return
	_read_json(file.get_as_text(), path)

func _read_json(text: String, path: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		message.emit("El archivo no contiene un circuito JSON válido.")
		return
	var data: Dictionary = parsed
	var points: Variant = data.get("points", [])
	if not points is Array or points.size() < (4 if data.get("closed", true) else 2):
		message.emit("La pista necesita cuatro puntos si es cerrada o dos si es abierta.")
		return
	var textures: Dictionary = data.get("surface_textures", {})
	for surface: String in textures:
		var texture_path: String = str(textures[surface])
		if not texture_path.begins_with("res://") and not texture_path.begins_with("user://") and not texture_path.is_absolute_path():
			textures[surface] = path.get_base_dir().path_join(texture_path)
	data["surface_textures"] = textures
	var error: String = TrackValidation.source_error(data)
	if not error.is_empty():
		message.emit(error)
		return
	loaded.emit(TrackDefinition.clean(data))
	message.emit("Circuito cargado: " + path.get_file())

func _import_texture(path: String) -> void:
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		message.emit("No se pudo leer esa imagen.")
		return
	DirAccess.make_dir_recursive_absolute("user://tracks/textures")
	var destination: String = "user://tracks/textures/" + _surface + "_" + str(Time.get_unix_time_from_system()).replace(".", "_") + ".png"
	if image.save_png(destination) != OK:
		message.emit("No se pudo guardar la textura.")
		return
	texture_chosen.emit(_surface, destination)
	message.emit("Textura aplicada a la superficie. Pulsa Aplicar para reconstruir.")

func _export(path: String) -> void:
	if path.get_extension().to_lower() != "json":
		path += ".json"
	var exported: Dictionary = _definition.duplicate(true)
	var textures: Dictionary = exported.get("surface_textures", {})
	var folder_name: String = path.get_file().get_basename() + "_texturas"
	for surface: String in textures:
		var source: String = str(textures[surface])
		var texture: Image = Image.load_from_file(source)
		if texture == null or texture.is_empty():
			message.emit("No se pudo exportar la textura de " + surface + ".")
			return
		var folder: String = path.get_base_dir().path_join(folder_name)
		DirAccess.make_dir_recursive_absolute(folder)
		var filename: String = surface + ".png"
		if texture.save_png(folder.path_join(filename)) != OK:
			message.emit("No se pudo copiar una textura al destino.")
			return
		textures[surface] = folder_name.path_join(filename)
	exported["surface_textures"] = textures
	_write(path, exported)

func _write(path: String, definition: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		message.emit("No se pudo guardar. Revisa el destino seleccionado.")
		return
	file.store_string(JSON.stringify(definition, "\t"))
	file.close()
	message.emit("Guardado: " + path)
