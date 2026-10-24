class_name ApexVehicleState
extends RefCounted

## Consolidated physical and dynamic state of an Apex vehicle.

var speed_mps: float = 0.0
var speed_kph: float = 0.0
var signed_speed_mps: float = 0.0
var engine_rpm: float = 1000.0
var current_gear: int = 1
var steer_angle_rad: float = 0.0
var lean_angle_rad: float = 0.0
var visual_lean_rad: float = 0.0
var grounded_wheels_count: int = 0
var total_downforce_n: float = 0.0
var peak_tire_slip: float = 0.0
var abs_active: bool = false
var tcs_active: bool = false
var stability_active: bool = false

var global_position: Vector3 = Vector3.ZERO
var linear_velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var forward_vector: Vector3 = Vector3.FORWARD
var up_vector: Vector3 = Vector3.UP
var right_vector: Vector3 = Vector3.RIGHT

var pitch_rad: float = 0.0
var roll_rad: float = 0.0
var yaw_rad: float = 0.0

var wheel_states: Array[ApexWheelState] = []
