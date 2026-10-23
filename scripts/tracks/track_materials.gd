class_name TrackMaterials
extends RefCounted

const SHADER: Shader = preload("res://shaders/terrain.gdshader")
const CURB_SHADER: Shader = preload("res://shaders/curb.gdshader")
const SURFACES: Array[String] = ["asphalt", "concrete", "gravel", "dirt", "grass", "sand"]
const COLORS: Dictionary = {"asphalt": Color("343a3e"), "concrete": Color("93938b"),
	"gravel": Color("837967"), "dirt": Color("68503a"),
	"grass": Color("3c4c2f"), "sand": Color("b3a27c")}
static var _materials: Array[WeakRef] = []
static var _wetness: float = 0.0
static var _detail_texture: ImageTexture

static func ground(surface: String, road: bool = false) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("base_color", COLORS.get(surface, COLORS["asphalt"]))
	material.set_shader_parameter("grain_scale", 25.0 if surface == "asphalt" else 9.0)
	material.set_shader_parameter("variation", 0.23 if surface == "asphalt" else 0.36)
	material.set_shader_parameter("patch_scale", 0.16 if surface == "grass" else 0.32)
	material.set_shader_parameter("is_concrete", surface == "concrete")
	material.set_shader_parameter("surface_kind", maxi(0, SURFACES.find(surface)))
	material.set_shader_parameter("wetness", _wetness)
	material.set_shader_parameter("road_surface", road)
	material.set_shader_parameter("surface_detail", detail_texture())
	_materials.append(weakref(material))
	return material

static func detail_texture() -> ImageTexture:
	if _detail_texture != null:
		return _detail_texture
	# One deterministic tile replaces repeated per-pixel procedural noise. Mips
	# suppress the crawling grain that otherwise looks like shimmer at speed.
	var data: PackedByteArray = PackedByteArray()
	data.resize(256 * 256 * 3)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 74219
	for i: int in range(data.size()):
		data[i] = random.randi() % 256
	var image: Image = Image.create_from_data(256, 256, false, Image.FORMAT_RGB8, data)
	image.generate_mipmaps()
	_detail_texture = ImageTexture.create_from_image(image)
	return _detail_texture

static func curbs() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = CURB_SHADER
	material.set_shader_parameter("surface_detail", detail_texture())
	material.set_shader_parameter("wetness", _wetness)
	_materials.append(weakref(material))
	return material

static func set_wetness(value: float) -> void:
	_wetness = clampf(value, 0.0, 1.0)
	var alive: Array[WeakRef] = []
	for reference: WeakRef in _materials:
		var material: ShaderMaterial = reference.get_ref() as ShaderMaterial
		if material != null:
			material.set_shader_parameter("wetness", _wetness)
			alive.append(reference)
	_materials = alive

static func flat(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
