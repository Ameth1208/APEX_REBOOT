extends Node3D
## Original protective overboot; follows the human's ankle, under the same lean.

var _upper: MeshInstance3D

func build() -> void:
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color("151a22")
	rubber.roughness = 0.82
	var toe := CapsuleMesh.new()
	toe.radius = 0.062
	toe.height = 0.31
	toe.radial_segments = 20
	toe.rings = 8
	var shoe := MeshInstance3D.new()
	shoe.mesh = toe
	shoe.material_override = rubber
	shoe.rotation.x = PI / 2.0
	shoe.position = Vector3(0, -0.055, -0.085)
	shoe.scale.x = 0.91
	add_child(shoe)
	var sleeve := CylinderMesh.new()
	sleeve.top_radius = 0.067
	sleeve.bottom_radius = 0.052
	sleeve.height = 0.19
	sleeve.radial_segments = 20
	_upper = MeshInstance3D.new()
	_upper.mesh = sleeve
	_upper.material_override = rubber
	add_child(_upper)

func follow_leg(direction: Vector3) -> void:
	var axis := direction.normalized()
	_upper.position = axis * 0.055
	_upper.basis = Basis(Quaternion(Vector3.UP, axis))
