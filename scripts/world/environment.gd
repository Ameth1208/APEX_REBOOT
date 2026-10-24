class_name ApexEnvironment
extends Node3D

var sun: DirectionalLight3D = DirectionalLight3D.new()
var world: WorldEnvironment = WorldEnvironment.new()
var sky_material: ShaderMaterial = ShaderMaterial.new()
var night: bool = false
var _wetness: float = 0.0
var _showroom: bool = false

func _ready() -> void:
	sky_material.shader = preload("res://shaders/motorsport_sky.gdshader")
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_SKY
	world.environment.sky = sky
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	world.environment.ambient_light_sky_contribution = 0.66
	world.environment.ambient_light_color = Color("8f9ba5")
	world.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment.tonemap_exposure = 0.90
	world.environment.glow_enabled = true
	world.environment.glow_intensity = 0.12
	world.environment.glow_hdr_threshold = 1.4
	world.environment.fog_enabled = true
	world.environment.fog_aerial_perspective = 0.60
	world.environment.fog_sky_affect = 0.10
	world.environment.fog_sun_scatter = 0.08
	add_child(world)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.10
	sun.shadow_normal_bias = 2.0
	sun.light_angular_distance = 0.55
	add_child(sun)
	set_quality("Equilibrado")
	set_night(false)

func set_quality(quality: String) -> void:
	var high: bool = quality == "Alto"
	var low: bool = quality == "Rendimiento"
	RenderingServer.directional_shadow_atlas_set_size(4096 if high else (1024 if low else 2048), false)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 180.0 if high else (85.0 if low else 135.0)
	sun.shadow_bias = 0.10 if high else 0.24
	sun.shadow_normal_bias = 2.0 if high else 4.0

func set_render_features(settings: Dictionary) -> void:
	sun.shadow_enabled = bool(settings.get("render_shadows", true))
	world.environment.fog_enabled = bool(settings.get("render_fog", true))

func set_night(enabled: bool) -> void:
	night = enabled
	_showroom = false
	sun.rotation_degrees = Vector3(-26.0, -158.0, 0.0) if night else Vector3(-38.0, -40.0, 0.0)
	sun.light_color = Color("b7c9e5") if night else Color("fff1dc")
	world.environment.fog_enabled = true
	world.environment.ambient_light_energy = 0.25 if night else 0.42
	world.environment.fog_light_color = Color("192434") if night else Color("bac8cf")
	sky_material.set_shader_parameter("studio", false)
	sky_material.set_shader_parameter("night_amount", 1.0 if night else 0.0)
	sky_material.set_shader_parameter("sun_direction", sun.basis.z.normalized())
	_update_weather()

func set_wetness(value: float) -> void:
	_wetness = clampf(value, 0.0, 1.0)
	TrackMaterials.set_wetness(_wetness)
	_update_weather()

func _update_weather() -> void:
	if _showroom:
		return
	world.environment.fog_density = lerpf(0.00095, 0.0024, _wetness)
	sun.light_energy = 0.23 if night else lerpf(0.87, 0.60, _wetness)
	sky_material.set_shader_parameter("cloud_cover", lerpf(0.30, 0.86, _wetness))

func set_showroom() -> void:
	_showroom = true
	sky_material.set_shader_parameter("studio", true)
	sun.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
	sun.light_color = Color("f4f6fa")
	sun.light_energy = 0.62
	world.environment.ambient_light_energy = 0.48
	world.environment.fog_enabled = false
