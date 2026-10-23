class_name ApexPhoto
extends RefCounted

static func capture(viewport: Viewport, hud: Control) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://photos")
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "user://photos/apex-%s.png" % stamp
	var error: Error = viewport.get_texture().get_image().save_png(path)
	if is_instance_valid(hud):
		hud.notify("Foto guardada: " + ProjectSettings.globalize_path(path) if error == OK else "No se pudo guardar la foto")
