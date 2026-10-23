extends RefCounted
## Small CPU particle pools work in native Compatibility and WebGL exports.

static var _puff_mesh: QuadMesh

static func puff(parent: Node3D, label: String, amount: int = 28) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.name = label
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = 1.2
	particles.lifetime_randomness = 0.3
	particles.fixed_fps = 24
	particles.local_coords = false
	particles.direction = Vector3.UP
	particles.spread = 32.0
	particles.gravity = Vector3(0, 0.7, 0)
	particles.initial_velocity_min = 0.3
	particles.initial_velocity_max = 1.8
	particles.scale_amount_min = 0.14
	particles.scale_amount_max = 0.55
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.12
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	particles.color_ramp = ramp
	particles.mesh = _mesh()
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)
	return particles

static func sparks(parent: Node3D) -> CPUParticles3D:
	var particles: CPUParticles3D = puff(parent, "ImpactSparks", 24)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.38
	particles.gravity = Vector3(0, -7, 0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 8.0
	particles.spread = 75.0
	particles.scale_amount_min = 0.015
	particles.scale_amount_max = 0.06
	particles.color = Color(1.0, 0.54, 0.12, 1.0)
	return particles

static func _mesh() -> QuadMesh:
	if _puff_mesh != null:
		return _puff_mesh
	_puff_mesh = QuadMesh.new()
	_puff_mesh.size = Vector2.ONE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = false
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	material.albedo_texture = texture
	_puff_mesh.material = material
	return _puff_mesh
