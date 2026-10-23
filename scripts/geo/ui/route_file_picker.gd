class_name RouteFilePicker
extends Node

signal loaded(text: String, filename: String)
signal failed(text: String)

const MAX_BYTES: int = 12 * 1024 * 1024
var _dialog: FileDialog
var _callback: JavaScriptObject

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_callback = JavaScriptBridge.create_callback(_web_loaded)
		JavaScriptBridge.eval("""
		window.apexRouteFiles = { open: function(callback) {
		  const input = document.createElement('input');
		  input.type = 'file'; input.accept = '.gpx,.geojson,.json';
		  input.onchange = function() {
		    const file = input.files[0]; if (!file) return;
		    if (file.size > 12582912) { callback('error', '', 'El archivo supera 12 MB.'); return; }
		    const reader = new FileReader();
		    reader.onload = () => callback('ok', file.name, reader.result);
		    reader.onerror = () => callback('error', '', 'No se pudo leer el archivo.');
		    reader.readAsText(file);
		  }; input.click();
		}};
		""", true)
	else:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.filters = PackedStringArray(["*.gpx,*.geojson,*.json ; Rutas GPX / GeoJSON"])
		_dialog.title = "Importar ruta geográfica"
		_dialog.file_selected.connect(_native_loaded)
		add_child(_dialog)

func choose() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("apexRouteFiles").open(_callback)
	else:
		_dialog.popup_centered(Vector2i(880, 580))

func _native_loaded(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		failed.emit("No se pudo abrir el archivo.")
	elif file.get_length() > MAX_BYTES:
		failed.emit("El archivo supera 12 MB; recorta la ruta antes de importarla.")
	else:
		loaded.emit(file.get_as_text(), path.get_file())

func _web_loaded(arguments: Array) -> void:
	if arguments.size() != 3:
		return
	if str(arguments[0]) == "ok":
		loaded.emit(str(arguments[2]), str(arguments[1]))
	else:
		failed.emit(str(arguments[2]))
