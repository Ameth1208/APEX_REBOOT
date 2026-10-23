extends Node
## Automated visual smoke pass. Run the editor with -- --qa.

var app: Node3D

func run(root_app: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = root_app
	await get_tree().process_frame
	await get_tree().process_frame
	await shot("01-garage")
	app.change_setting("livery", "Heritage")
	await get_tree().create_timer(0.3).timeout
	await shot("01b-garage-livery")
	app.change_setting("livery", "Original")
	app.settings.values.vehicle = 0
	app.settings.values.mode = "Carrera"
	app.settings.values.opponents = 1
	app.settings.values.night = false
	await app.start_race()
	app.race.autopilot = true
	await get_tree().create_timer(5.0).timeout
	await shot("02-race-day")
	app.race.player.set_controls(0, 1, 0)
	get_tree().paused = true
	app.environment.set_night(true)
	app.scenery.night = true
	app.race.set_lights(true)
	await get_tree().create_timer(1.0).timeout
	await shot("03-race-night")
	app.handle_action("editor")
	await get_tree().create_timer(0.4).timeout
	await shot("04-editor")
	app.handle_action("close_overlay")
	app.handle_action("options")
	await get_tree().create_timer(0.4).timeout
	await shot("05-options")
	app.show_garage()
	app.change_setting("vehicle", 1)
	app.change_setting("livery", "Endurance")
	await get_tree().create_timer(0.5).timeout
	await shot("06-motorcycle")
	app.settings.values.mode = "Libre"
	await app.start_race()
	app.camera.mode = 2
	await get_tree().create_timer(0.4).timeout
	await shot("07-motorcycle-cockpit")
	print("APEX_UI_SMOKE_PASS")
	get_tree().quit(0)

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("HEADLESS_STAGE ", name)
		return
	await RenderingServer.frame_post_draw
	var path: String = "user://qa/" + name + ".png"
	DirAccess.make_dir_recursive_absolute("user://qa")
	var err: Error = get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT ", err, " ", ProjectSettings.globalize_path(path))
