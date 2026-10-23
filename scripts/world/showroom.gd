class_name ApexShowroom
extends Node3D

var vehicle: Node3D
var target: Node3D = Node3D.new()

func _ready() -> void:
	var floor_material: ShaderMaterial = ShaderMaterial.new()
	floor_material.shader = preload("res://shaders/showroom_floor.gdshader")
	ApexMesh.box(self, Vector3(0, -0.30, 0), Vector3(80, 0.2, 80), floor_material)
	var platform: MeshInstance3D = ApexMesh.cylinder(self, Vector3(0, -0.10, 0), 4.0, 0.18, ApexMesh.material(Color("3b444c"), 0.10, 0.68))
	(platform.mesh as CylinderMesh).radial_segments = 96
	var accent: StandardMaterial3D = ApexMesh.material(Color("d52b36"), 0.22, 0.32)
	accent.emission_enabled = true
	accent.emission = Color("be2533")
	accent.emission_energy_multiplier = 0.60
	var edge: MeshInstance3D = ApexMesh.cylinder(self, Vector3(0, -0.11, 0), 4.025, 0.045, accent)
	(edge.mesh as CylinderMesh).radial_segments = 96
	var wall: StandardMaterial3D = ApexMesh.material(Color("171e26"), 0.05, 0.88)
	ApexMesh.box(self, Vector3(0, 3.2, -10), Vector3(30, 6.8, 0.35), wall)
	for x: float in [-9.0, -4.5, 4.5, 9.0]:
		ApexMesh.box(self, Vector3(x, 3.2, -9.77), Vector3(0.04, 6.6, 0.06), ApexMesh.material(Color("46505b"), 0.4, 0.6))
	var nameplate: Label3D = Label3D.new()
	nameplate.text = "A P E X"
	nameplate.font_size = 132
	nameplate.outline_size = 0
	nameplate.pixel_size = 0.018
	nameplate.modulate = Color("cbd2d7")
	nameplate.position = Vector3(0, 4.7, -9.74)
	add_child(nameplate)
	ApexMesh.box(self, Vector3(0, 3.72, -9.72), Vector3(2.4, 0.045, 0.04), accent)
	_key_light(Vector3(3.8, 5.5, 2.5), Color("fff4e6"), 2.3)
	_key_light(Vector3(-4.2, 3.5, -1.4), Color("b9d3ed"), 1.7)
	_key_light(Vector3(1.0, 5.5, -4.8), Color("e8eff7"), 1.7)
	add_child(target)

func _key_light(origin: Vector3, color: Color, energy: float) -> void:
	var light: SpotLight3D = SpotLight3D.new()
	light.position = origin
	light.light_color = color
	light.light_energy = energy
	light.spot_range = 16.0
	light.spot_angle = 48.0
	light.spot_attenuation = 0.55
	add_child(light)
	light.look_at(Vector3(0, 0.65, 0))

func show_vehicle(profile: Dictionary, paint: String, livery: String = "Original") -> void:
	if is_instance_valid(vehicle):
		remove_child(vehicle)
		vehicle.queue_free()
	vehicle = load("res://scripts/vehicles/vehicle_visual.gd").new()
	add_child(vehicle)
	vehicle.setup(profile)
	target.set_meta("view_distance", maxf(3.2, float(profile.get("length_m", 4.5)) * 1.4))
	vehicle.set_paint(ApexCatalog.paint_color(paint), paint == "Original")
	vehicle.set_livery(livery)
