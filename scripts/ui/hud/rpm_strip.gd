class_name ApexRPMStrip
extends Control
## Shift lights use the actual engine RPM divided by its configured limit.

const SEGMENTS: int = 14
var fraction: float = 0.0
var value: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(192, 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_fraction(amount: float) -> void:
	var next: float = clampf(amount, 0.0, 1.0) if is_finite(amount) else 0.0
	if is_equal_approx(fraction, next):
		return
	fraction = next
	value = fraction * 100.0
	queue_redraw()

func _draw() -> void:
	var gap: float = 3.0
	var width: float = (size.x - gap * (SEGMENTS - 1)) / SEGMENTS
	var active: int = ceili(fraction * SEGMENTS)
	for index: int in SEGMENTS:
		var color := Color(0.37, 0.41, 0.47, 0.38)
		if index < active:
			color = Color("f4f5f7") if index < 9 else Color("ff4b55")
			if fraction > 0.96:
				color = Color("ff4b55")
		draw_rect(Rect2(index * (width + gap), 0, width, size.y), color)
