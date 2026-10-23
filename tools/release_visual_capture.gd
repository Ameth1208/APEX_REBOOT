extends SceneTree
## Real main scene; one native PNG per run, also usable with --path baseline --script /absolute/path.
## User args use --key=value. Use a real display/Xvfb; this is visual QA, not a benchmark.

class CaptureSettings extends ApexSettings:
	func load_preferences(_path: String = "user://settings.cfg") -> void:
		pass
	func save_preferences(_path: String = "user://settings.cfg") -> void:
		pass

const CAMERAS := {"chase": 0, "hood": 1, "cockpit": 2, "cinematic": 3, "orbit": 4}
var options: Dictionary = {"scene": "garage", "size": "1280x720", "vehicle": "0", "track": "",
	"camera": "chase", "night": "false", "frames": "8", "seconds": "0", "drive": "false",
	"quality": "Equilibrado", "outfile": "user://qa/release-visual.png"}
var app: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not _parse():
		return
	if DisplayServer.get_name() == "headless":
		_fail("Se necesita una pantalla nativa o Xvfb: --headless no produce imágenes.")
		return
	var dimensions: PackedStringArray = str(options.size).split("x")
	if dimensions.size() != 2 or not dimensions[0].is_valid_int() or not dimensions[1].is_valid_int():
		_fail("--size debe ser ANCHOxALTO, por ejemplo 1280x720.")
		return
	var viewport_size := Vector2i(int(dimensions[0]), int(dimensions[1]))
	if viewport_size.x < 960 or viewport_size.y < 540:
		_fail("La resolución mínima del juego es 960x540.")
		return
	var vehicle_index: int = _vehicle_index(str(options.vehicle))
	var camera_index: int = int(options.camera) if str(options.camera).is_valid_int() else int(CAMERAS.get(options.camera, -1))
	if vehicle_index < 0 or camera_index < 0 or camera_index > 4:
		_fail("Vehículo o cámara desconocidos. Cámaras: chase, hood, cockpit, cinematic, orbit.")
		return
	var output: String = ProjectSettings.globalize_path(str(options.outfile))
	if not output.is_absolute_path():
		output = ProjectSettings.globalize_path("res://").path_join(output)
	if DirAccess.make_dir_recursive_absolute(output.get_base_dir()) != OK:
		_fail("No se puede crear la carpeta de salida: " + output.get_base_dir())
		return
	app = load("res://scenes/main.tscn").instantiate()
	app.settings = CaptureSettings.new()
	app.settings.values.merge({"vehicle": vehicle_index, "camera": camera_index, "night": _flag("night"),
		"quality": options.quality, "mode": "Carrera", "opponents": 3, "volume": 0.0,
		"paint": "Original", "livery": "Original", "fullscreen": false, "racing_line": false}, true)
	if not str(options.track).is_empty():
		var definition: Dictionary = ApexCatalog.read_json(str(options.track))
		if not definition.get("points", []) is Array or definition.get("points", []).size() < 2:
			_fail("--track necesita un JSON de pista APEX con points, no GeoJSON sin convertir.")
			app.free()
			return
		app.custom_track = definition
	root.size = viewport_size
	root.content_scale_size = viewport_size
	root.add_child(app)
	current_scene = app
	await process_frame
	if str(options.scene) == "race":
		await app.start_race()
		app.race.countdown = 0.0
		app.race.autopilot = _flag("drive")
		paused = not _flag("drive")
	elif str(options.scene) == "editor":
		app.handle_action("editor")
	print("RELEASE_VISUAL_READY ", options.scene, " vehicle=", vehicle_index, " size=", viewport_size)
	var deadline: int = Time.get_ticks_msec() + int(maxf(0.0, float(options.seconds)) * 1000.0)
	var frames: int = 0
	while frames < maxi(3, int(options.frames)) or Time.get_ticks_msec() < deadline:
		await process_frame
		await RenderingServer.frame_post_draw
		frames += 1
	var visual: Node = app.race.player.get_node("Visual") if str(options.scene) == "race" else app.showroom.vehicle
	if visual == null or visual.dimensions.length_squared() <= 0.0:
		_fail("El modelo 3D no se cargó. Importa primero el proyecto con el editor de Godot.")
		return
	var snapshot: Image = root.get_texture().get_image()
	if snapshot == null or snapshot.is_empty():
		_fail("El viewport no devolvió una imagen; comprueba el renderizador y la pantalla.")
		return
	var error: Error = snapshot.save_png(output)
	if error != OK:
		_fail("No se pudo guardar el PNG (error %d): %s" % [error, output])
		return
	print("RELEASE_VISUAL_CAPTURE PASS ", output, " pixels=", snapshot.get_size(), " frames=", frames)
	quit(0)

func _parse() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--help":
			print("--scene=garage|race|editor --size=1280x720 --vehicle=ID|INDEX --track=PATH.json")
			print("--camera=chase|cockpit|hood|cinematic|orbit --night --drive --quality=Equilibrado")
			print("--frames=8 --seconds=0 --outfile=PATH.png (waits for both minimums; no preferences are saved)")
			quit(0)
			return false
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if not argument.begins_with("--") or not options.has(pair[0]):
			_fail("Argumento desconocido: " + argument)
			return false
		options[pair[0]] = pair[1] if pair.size() > 1 else "true"
	if str(options.scene) not in ["garage", "race", "editor"]:
		_fail("--scene debe ser garage, race o editor.")
		return false
	if not str(options.frames).is_valid_int() or not str(options.seconds).is_valid_float():
		_fail("--frames debe ser entero y --seconds un número de segundos reales.")
		return false
	return true

func _vehicle_index(value: String) -> int:
	var catalog: Array = ApexCatalog.entries("vehicles")
	if value.is_valid_int():
		return int(value) if int(value) >= 0 and int(value) < catalog.size() else -1
	for index: int in catalog.size():
		if str(ApexCatalog.vehicle(index).get("id", "")) == value:
			return index
	return -1

func _flag(key: String) -> bool:
	return str(options[key]).to_lower() in ["true", "1", "yes"]

func _fail(message: String) -> void:
	push_error("RELEASE_VISUAL_CAPTURE FAIL: " + message)
	quit(2)
