extends SceneTree
## Render the actual UI components without loading a race or changing preferences.
## godot_console --path . --script res://tools/ui_preview.gd

func _initialize() -> void:
	_preview.call_deferred()

func _preview() -> void:
	var host := Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = ApexUI.make_theme()
	var settings := ApexSettings.new()
	DirAccess.make_dir_recursive_absolute("user://qa/ui")
	for resolution: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = resolution
		var options := ApexOptionsPanel.new()
		host.add_child(options)
		options.build(settings.values)
		options._select_category(1)
		await _shot("settings", resolution)
		host.remove_child(options)
		options.queue_free()
		var pause := ApexModal.new()
		host.add_child(pause)
		pause.build("PAUSA", "Tu sesión está detenida.", {"resume": "CONTINUAR", "restart": "REINICIAR", "camera": "CAMBIAR CÁMARA", "photo": "MODO FOTO", "controls": "CONTROLES", "settings": "AJUSTES", "garage": "VOLVER AL GARAJE"})
		await _shot("pause", resolution)
		host.remove_child(pause)
		pause.queue_free()
		var results := ApexRaceResults.new()
		host.add_child(results)
		results.show_result({"position": 3, "racers": 8, "total": 754.567, "best": 102.38}, "")
		await _shot("results", resolution)
		host.remove_child(results)
		results.queue_free()
		var cluster := ApexInstrumentCluster.new()
		host.add_child(cluster)
		cluster.build(false)
		cluster.position = Vector2((resolution.x - 560) * 0.5, resolution.y - 238)
		cluster.update_state({"speed_kph": 168, "rpm": 6400, "gear": 4, "throttle": 0.7, "brake": 0.2}, 8000)
		await create_timer(0.5).timeout
		await _shot("instruments", resolution)
		host.remove_child(cluster)
		cluster.queue_free()
	print("APEX_UI_PREVIEW_COMPLETE")
	quit()

func _shot(screen: String, resolution: Vector2i) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "user://qa/ui/%s-%dx%d.png" % [screen, resolution.x, resolution.y]
	var result: Error = root.get_texture().get_image().save_png(path)
	print("UI_PREVIEW ", result, " ", ProjectSettings.globalize_path(path))
