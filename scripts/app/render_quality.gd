class_name ApexRenderQuality
extends RefCounted

const NAMES: Array[String] = ["Automático", "Rendimiento", "Equilibrado", "Alto"]

static func tier(quality: String, scale: float) -> String:
	if quality == "Automático":
		return "Rendimiento" if scale < 0.85 else "Equilibrado"
	return quality if quality in NAMES else "Equilibrado"

static func apply_viewport(viewport: Viewport, quality: String, scale: float = 1.0) -> void:
	var resolved: String = tier(quality, scale)
	var low: bool = resolved == "Rendimiento"
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = clampf(scale, 0.70, 1.0) if quality == "Automático" else (0.80 if low else 1.0)
	viewport.msaa_3d = Viewport.MSAA_DISABLED if low else (Viewport.MSAA_4X if resolved == "Alto" else Viewport.MSAA_2X)
	var fxaa_supported: bool = RenderingServer.get_current_rendering_method() in ["forward_plus", "mobile"]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if low and fxaa_supported else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.mesh_lod_threshold = 2.5 if low else (0.75 if resolved == "Alto" else 1.5)

static func apply_scenery(node: Node, quality: String) -> void:
	var multiplier: float = 0.70 if quality == "Rendimiento" else (1.15 if quality == "Alto" else 1.0)
	for child: Node in node.get_children():
		if child is GeometryInstance3D and child.has_meta("quality_visibility_range"):
			child.visibility_range_end = float(child.get_meta("quality_visibility_range")) * multiplier
		apply_scenery(child, quality)
