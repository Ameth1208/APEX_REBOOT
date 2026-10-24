class_name ApexMenuBackdrop
extends Control
## Shared visual field for non-race screens: technical, restrained and cheap to draw.

const GRID := Color(0.32, 0.39, 0.48, 0.10)
const INK := Color("070b12")
const RED := Color("ff4b55")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	# Technical grid fades into the lower half instead of competing with controls.
	var diagonal_count: int = ceili((size.x + size.y * 2.0) / 56.0)
	for index: int in diagonal_count:
		var x: float = -size.y + float(index) * 56.0
		draw_line(Vector2(x, 0), Vector2(x + size.y * 0.42, size.y), GRID, 1.0)
	for index: int in ceili(maxf(0.0, size.y - 80.0) / 64.0):
		var y: float = 80.0 + float(index) * 64.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(GRID, GRID.a * 0.55), 1.0)
	# Brand rail and a quiet radial focal point behind the garage vehicle.
	draw_rect(Rect2(0, 0, size.x, 3), RED)
	var center := Vector2(size.x * 0.64, size.y * 0.46)
	for radius: float in [260.0, 190.0, 120.0]:
		draw_arc(center, radius, deg_to_rad(205.0), deg_to_rad(335.0), 48, Color(RED, 0.045), 1.0, true)
	draw_line(Vector2(0, size.y - 76), Vector2(size.x, size.y - 76), Color(0.75, 0.80, 0.87, 0.12), 1.0)
