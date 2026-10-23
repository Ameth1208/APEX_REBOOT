class_name ApexVehicleStatus
extends PanelContainer
## The race view shows a warning only when damage affects the vehicle.

var _state: Label
var _detail: Label
var _bike: bool = false

func setup(is_motorcycle: bool) -> void:
	_bike = is_motorcycle
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(294, 72)
	size = custom_minimum_size
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_state = ApexUI.label("", 18, ApexHudTheme.RED)
	column.add_child(_state)
	_detail = ApexUI.label("", 14, ApexHudTheme.MUTED)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail)
	visible = false

func update_state(data: Dictionary) -> void:
	var damage: float = clampf(float(data.get("damage", 0.0)), 0.0, 1.0)
	var crashed: bool = bool(data.get("crashed", false))
	visible = damage > 0.005 or crashed
	if not visible:
		return
	_state.text = "DAÑOS  %d %%" % roundi(damage * 100.0)
	_detail.text = "Rendimiento reducido" if damage > 0.15 else "Daños leves"
	if crashed:
		_state.text = "MOTO CAÍDA" if _bike else "VEHÍCULO INMOVILIZADO"
		_detail.text = "Recupera el vehículo para continuar."
