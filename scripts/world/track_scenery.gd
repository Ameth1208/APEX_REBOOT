class_name ApexScenery
extends Node3D

var lights: Array[SpotLight3D] = []
var target: Node3D
var night: bool = false
var _timer: float = 0.0
var _glow: StandardMaterial3D

func build(track: Node3D) -> void:
	await get_tree().physics_frame
	_glow = ApexMesh.material(Color("e8e3d9"))
	_glow.emission_enabled = true
	_glow.emission = Color("ffd9a1")
	_glow.emission_energy_multiplier = 0.10
	lights = ApexTrackLighting.build(self, track, _glow)
	ApexForest.build(self, track)
	ApexGroundCover.build(self, track)
	ApexCircuitSigns.build(self, track)
	if str(track.definition.get("name", "")).contains("Costa"):
		var material: StandardMaterial3D = ApexMesh.material(Color("264759"), 0.0, 0.19)
		var water: MeshInstance3D = ApexMesh.box(self, Vector3(0, -11, 0), Vector3(6500, 0.5, 6500), material)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.2
	if _glow != null:
		_glow.emission_energy_multiplier = 1.8 if night else 0.10
	for light: SpotLight3D in lights:
		light.visible = night and is_instance_valid(target) and light.global_position.distance_squared_to(target.global_position) < 10000.0
