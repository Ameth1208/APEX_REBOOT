extends RefCounted
## Shared, generated leaf sprays: cutout silhouettes without external assets.

static var _shared_material: ShaderMaterial

static func material() -> ShaderMaterial:
	if _shared_material != null:
		return _shared_material
	var shader: Shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_sprays : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float weight = smoothstep(1.7, 6.7, VERTEX.y);
	VERTEX.x += sin(world.x * 0.13 + world.z * 0.17 + TIME * 1.4) * weight * 0.11;
	VERTEX.z += cos(world.x * 0.09 + TIME * 1.1) * weight * 0.06;
}
void fragment() {
	vec4 leaf = texture(leaf_sprays, UV);
	ALBEDO = COLOR.rgb * leaf.rgb;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.32;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
	BACKLIGHT = COLOR.rgb * 0.24;
}
"""
	_shared_material = ShaderMaterial.new()
	_shared_material.shader = shader
	_shared_material.set_shader_parameter("leaf_sprays", _texture())
	return _shared_material

static func add(surface: SurfaceTool, center: Vector3, scale: Vector3,
		color: Color, rng: RandomNumberGenerator, conifer: bool = false) -> void:
	var count: int = 7 if conifer else 12
	var rotation: float = rng.randf_range(0.0, TAU)
	for index: int in range(count):
		var y: float = 1.0 - 2.0 * (float(index) + 0.5) / float(count)
		var angle: float = rotation + float(index) * 2.39996
		var radius: float = sqrt(1.0 - y * y)
		var normal: Vector3 = Vector3(cos(angle) * radius, y, sin(angle) * radius)
		var origin: Vector3 = center + normal * scale * rng.randf_range(0.35, 0.68)
		var right: Vector3 = Vector3.UP.cross(normal).normalized().rotated(normal, rng.randf_range(-0.9, 0.9))
		var up: Vector3 = normal.cross(right)
		right *= (scale.x + scale.z) * 0.30 * rng.randf_range(0.85, 1.12)
		up *= scale.y * rng.randf_range(0.60, 0.78)
		var tint: Color = color.lerp(Color("afbd79"), maxf(y, 0.0) * 0.12) * rng.randf_range(0.91, 1.04)
		_card(surface, origin, right, up, normal, tint, conifer)

static func _card(surface: SurfaceTool, center: Vector3, right: Vector3, up: Vector3,
		normal: Vector3, tint: Color, conifer: bool) -> void:
	var points: PackedVector3Array = PackedVector3Array([center - right - up, center + right - up,
		center + right + up, center - right + up])
	var left: float = 0.5 if conifer else 0.0
	var uv: PackedVector2Array = PackedVector2Array([Vector2(left, 1), Vector2(left + 0.5, 1),
		Vector2(left + 0.5, 0), Vector2(left, 0)])
	for index: int in [0, 2, 1, 0, 3, 2]:
		surface.set_uv(uv[index])
		surface.set_color(tint.srgb_to_linear())
		surface.set_normal((normal + Vector3.UP * 0.30 + (points[index] - center) * 0.12).normalized())
		surface.add_vertex(points[index])

static func _texture() -> ImageTexture:
	var image: Image = Image.create(512, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.85, 0.87, 0.79, 0.0))
	# Each half is one padded spray. Broad leaves and fine needles share a draw call.
	_leaf(image, Vector2(128, 236), Vector2(128, 28), 2.2, 0.62)
	for level: int in range(6):
		var t: float = float(level) / 6.0
		var base: Vector2 = Vector2(128, 220 - level * 28)
		for side: float in [-1.0, 1.0]:
			var tip: Vector2 = base + Vector2(side * (66.0 - t * 16.0), -30.0 - t * 17.0)
			_leaf(image, base, tip, 23.0 - t * 5.0, 0.86 + t * 0.12)
	_leaf(image, Vector2(128, 65), Vector2(128, 17), 16.0, 0.98)
	_leaf(image, Vector2(384, 238), Vector2(384, 24), 2.0, 0.59)
	for level: int in range(8):
		var base: Vector2 = Vector2(384, 219 - level * 24)
		for side: float in [-1.0, 1.0]:
			var tip: Vector2 = base + Vector2(side * (71.0 - level * 5.0), -36.0)
			_leaf(image, base, tip, 1.7, 0.71)
			var axis: Vector2 = (tip - base).normalized()
			var across: Vector2 = Vector2(-axis.y, axis.x)
			for needle: int in range(6):
				var root: Vector2 = base.lerp(tip, 0.14 + float(needle) * 0.15)
				for direction: float in [-1.0, 1.0]:
					_leaf(image, root, root + axis * 12.0 + across * direction * 18.0, 3.0, 0.90 + float(needle) * 0.014)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _leaf(image: Image, base: Vector2, tip: Vector2, width: float, shade: float) -> void:
	var length: float = base.distance_to(tip)
	var axis: Vector2 = (tip - base) / length
	var across: Vector2 = Vector2(-axis.y, axis.x)
	var minimum: Vector2i = Vector2i((base.min(tip) - Vector2.ONE * width).floor()).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	var maximum: Vector2i = Vector2i((base.max(tip) + Vector2.ONE * width).ceil()).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			var delta: Vector2 = Vector2(x + 0.5, y + 0.5) - base
			var t: float = delta.dot(axis) / length
			if t <= 0.0 or t >= 1.0:
				continue
			var span: float = sin(t * PI) * width
			var lateral: float = delta.dot(across)
			if absf(lateral) > span:
				continue
			var light: float = shade * (0.91 + lateral / maxf(span, 1.0) * 0.075)
			if absf(lateral) < 0.65:
				light *= 1.09
			image.set_pixel(x, y, Color(light, light * 1.015, light * 0.93, 1.0))
