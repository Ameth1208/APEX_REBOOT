extends SceneTree
## Native UI verification with a real viewport. Test terrain is explicitly synthetic.

var app: Node3D
var _failures: Array[String] = []
var _checks: int = 0
var _map_loaded: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 900)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.settings.values.fullscreen = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	app.handle_action("editor")
	await process_frame
	var editor: TrackEditor = app.screens.editor
	var dialog: RealRouteDialog = editor._real_route
	dialog.ui.map.tiles.enabled = false
	dialog.open()
	dialog._import_text(_route_text(), "prueba_sintetica.geojson")
	dialog._create()
	await process_frame
	await process_frame
	await _shot("v02-perfil")
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = resolution
		await process_frame
		await process_frame
		_check(_inside(editor._fields.get_parent()) and _inside(editor._profile), "Editor viewport and profile fit " + str(resolution))
	root.size = Vector2i(1440, 900)
	await process_frame
	if OS.get_cmdline_user_args().has("--live-map"):
		dialog.open(editor._definition)
		dialog.ui.map.tiles.enabled = true
		dialog.ui.map.fit_route()
		await process_frame
		var deadline: int = Time.get_ticks_msec() + 90000
		while not _map_complete(dialog.ui.map.tiles) and Time.get_ticks_msec() < deadline:
			await create_timer(0.2, true).timeout
		_map_loaded = dialog.ui.map.tiles.textures.size()
		print("LIVE_MAP_TILES ", _map_loaded)
		_check(_map_complete(dialog.ui.map.tiles), "Every visible map tile loaded")
		await _shot("v02-mapa")
		dialog._close()
	app.handle_action("close_overlay")
	app.settings.values.vehicle = 1
	app.settings.values.mode = "Libre"
	app.settings.values.opponents = 0
	app.settings.values.night = false
	await app.start_race()
	app.race.active = false
	app.race.countdown = 0
	app.race.player.set_controls(0.65, 0.30, 0.0, 0.4)
	await create_timer(0.3, true).timeout
	app.screens.hud.update_session(app.race, "Persecución", 0.0)
	_check(absf(app.screens.hud.throttle_input.amount - 0.65) < 0.01, "HUD reports actual smoothed throttle")
	_check(absf(app.screens.hud.brake_input.amount - 0.30) < 0.01, "HUD reports brake independently")
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = resolution
		await process_frame
		await process_frame
		_check(_inside(app.screens.hud.throttle_input) and _inside(app.screens.hud.brake_input) and _inside(app.screens.hud.map), "HUD fits " + str(resolution))
	root.size = Vector2i(1440, 900)
	await process_frame
	await _shot("v02-hud-moto")
	app.race.player.set_controls(0, 1, 0)
	app.camera.mode = 2
	await create_timer(0.1, true).timeout
	await _shot("v02-moto-piloto")
	for failure: String in _failures:
		push_error(failure)
	var report: FileAccess = FileAccess.open("user://qa/v02-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": _checks, "failures": _failures, "map_tiles": _map_loaded}, "\t"))
	report.close()
	print("V02_FEATURE_PROBE ", "PASS" if _failures.is_empty() else "FAIL", " ", _failures)
	quit(0 if _failures.is_empty() else 1)

func _inside(control: Control) -> bool:
	var rect: Rect2 = control.get_global_rect()
	var available: Rect2 = control.get_viewport_rect().grow(1)
	return available.encloses(rect)

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://qa")
	var path: String = "user://qa/" + name + ".png"
	get_root().get_texture().get_image().save_png(path)
	print("V02_SHOT ", ProjectSettings.globalize_path(path))

func _route_text() -> String:
	return '{"type":"Feature","properties":{"name":"PERFIL DE PRUEBA · COTAS SINTÉTICAS"},"geometry":{"type":"LineString","coordinates":[[-74.092,4.650,2600],[-74.092,4.652,2610],[-74.091,4.654,2645],[-74.090,4.656,2640],[-74.090,4.658,2605],[-74.091,4.660,2595]]}}'

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)

func _map_complete(tiles: MapTileCache) -> bool:
	if tiles._wanted.is_empty():
		return false
	for key: String in tiles._wanted:
		if not tiles.textures.has(key):
			return false
	return true
