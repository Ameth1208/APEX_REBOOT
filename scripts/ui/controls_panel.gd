class_name ApexControlsPanel
extends VBoxContainer

signal changed(key: String, value: Variant)
var _values: Dictionary
var _buttons: Dictionary = {}
var _waiting: String = ""
var _notice: Label

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
	var hint := ApexUI.label("Mando: stick izquierdo para dirigir, RT/R2 para acelerar, LT/L2 para frenar. Los mandos conservan su asignación al cambiar las teclas.", 14, ApexUI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

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
