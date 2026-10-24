class_name ApexControlsPanel
extends VBoxContainer

signal changed(key: String, value: Variant)
var _values: Dictionary
var _buttons: Dictionary = {}
var _waiting: String = ""
var _notice: Label
var _wheel_status: Label
var _wheel_readout: Label

func build(values: Dictionary) -> void:
	_values = values
	visibility_changed.connect(_cancel_hidden)
	add_theme_constant_override("separation", 8)
	_notice = ApexUI.label("Elige una acción y pulsa su nueva tecla. Esc cancela la captura.", 14, ApexUI.MUTED)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_notice)
	for action: String in ApexBindings.EDITABLE:
		var row := HBoxContainer.new()
		add_child(row)
		var caption := ApexUI.label(str(ApexBindings.LABELS[action]), 15)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var key := ApexUI.button(ApexBindings.label_for(action), func(): _capture(action))
		key.custom_minimum_size.x = 175
		row.add_child(key)
		_buttons[action] = key
	add_child(ApexUI.button("Restaurar teclas predeterminadas", _restore))
	var hint := ApexUI.label("Mando: stick izquierdo, RT/R2 y LT/L2. Logitech G923: detección automática en PC; por defecto usa eje 0 para dirección, 5 para acelerador y 4 para freno. Las zonas muertas se ajustan en Conducción.", 14, ApexUI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var devices: PackedInt32Array = Input.get_connected_joypads()
	var wheel_name: String = "No detectado"
	for device: int in devices:
		var name: String = Input.get_joy_name(device)
		if name.to_lower().contains("g923") or name.to_lower().contains("wheel") or name.to_lower().contains("logitech"):
			wheel_name = "%s · dispositivo %d" % [name, device]
	_wheel_status = ApexUI.label("Estado del volante: " + wheel_name, 14, ApexUI.ACCENT if wheel_name != "No detectado" else ApexUI.MUTED)
	_wheel_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_wheel_status)
	_wheel_readout = ApexUI.label("Lectura: —", 13, ApexUI.MUTED)
	add_child(_wheel_readout)
	add_child(ApexUI.button("Guardar volante completamente a la izquierda", func(): _capture_wheel_value("wheel_steering_min")))
	add_child(ApexUI.button("Guardar centro del volante", func(): _capture_wheel_value("wheel_steering_center")))
	add_child(ApexUI.button("Guardar volante completamente a la derecha", func(): _capture_wheel_value("wheel_steering_max")))
	add_child(ApexUI.button("Guardar acelerador suelto", func(): _capture_wheel_value("wheel_throttle_min")))
	add_child(ApexUI.button("Guardar acelerador a fondo", func(): _capture_wheel_value("wheel_throttle_max")))
	add_child(ApexUI.button("Guardar freno suelto", func(): _capture_wheel_value("wheel_brake_min")))
	add_child(ApexUI.button("Guardar freno a fondo", func(): _capture_wheel_value("wheel_brake_max")))

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _wheel_readout == null:
		return
	var device: int = _wheel_device()
	if device < 0:
		_wheel_readout.text = "Lectura: conecta el G923 y vuelve a abrir esta pantalla."
		return
	var s: float = Input.get_joy_axis(device, int(_values.get("wheel_steering_axis", 0)))
	var a: float = Input.get_joy_axis(device, int(_values.get("wheel_throttle_axis", 5)))
	var b: float = Input.get_joy_axis(device, int(_values.get("wheel_brake_axis", 4)))
	_wheel_readout.text = "Lectura · dirección %.3f · acelerador %.3f · freno %.3f" % [s, a, b]

func _wheel_device() -> int:
	var requested: int = int(_values.get("wheel_device", -1))
	var devices: PackedInt32Array = Input.get_connected_joypads()
	if requested >= 0 and requested in devices:
		return requested
	for device: int in devices:
		var name: String = Input.get_joy_name(device).to_lower()
		if name.contains("g923") or name.contains("wheel") or name.contains("logitech"):
			return device
	return -1

func _capture_wheel_value(key: String) -> void:
	var device: int = _wheel_device()
	if device < 0:
		_notice.text = "No se detecta el G923. Conéctalo y vuelve a intentarlo."
		return
	var axis_key: String = "wheel_steering_axis" if key.begins_with("wheel_steering") else ("wheel_throttle_axis" if key.contains("throttle") else "wheel_brake_axis")
	var value: float = Input.get_joy_axis(device, int(_values.get(axis_key, 0)))
	var next_values: Dictionary = _values.duplicate(true)
	next_values[key] = value
	_values = next_values
	changed.emit(key, value)
	_notice.text = "%s guardado: %.3f" % [key, value]

func _capture(action: String) -> void:
	_waiting = action
	_refresh()
	_buttons[action].text = "Pulsa una tecla…"
	_notice.text = "Nueva tecla para %s. Esc cancela." % str(ApexBindings.LABELS[action])

func _cancel_hidden() -> void:
	if not is_visible_in_tree():
		_waiting = ""
		_refresh()

func _input(event: InputEvent) -> void:
	if _waiting.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE:
		_waiting = ""
		_notice.text = "Cambio cancelado."
		_refresh()
		return
	var code: int = int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	var error: String = ApexBindings.conflict(_waiting, code)
	if not error.is_empty() or event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
		_notice.text = error if not error.is_empty() else "Usa una tecla sin Ctrl, Alt, Shift ni Meta."
		return
	var bindings: Dictionary = _values.get("key_bindings", {}).duplicate(true)
	bindings[_waiting] = code
	changed.emit("key_bindings", bindings)
	_waiting = ""
	_notice.text = "Tecla guardada. Puedes usarla al volver a la pista."
	_refresh()

func _restore() -> void:
	_waiting = ""
	changed.emit("key_bindings", {})
	_notice.text = "Teclas predeterminadas restauradas."
	_refresh()

func _refresh() -> void:
	for action: String in _buttons:
		_buttons[action].text = ApexBindings.label_for(action)
