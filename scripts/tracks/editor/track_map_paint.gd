class_name TrackMapPaint
extends RefCounted

static func draw(map: TrackMap, sampler: TrackSampler) -> void:
	map.draw_style_box(map._background(), Rect2(Vector2.ZERO, map.size))
	var grid_step: float = 50.0 * map.zoom
	if grid_step > 8.0:
		var origin: Vector2 = map.to_screen(Vector2.ZERO)
		for x: int in range(int(fposmod(origin.x, grid_step)), int(map.size.x), maxi(1, int(grid_step))):
			map.draw_line(Vector2(x, 0), Vector2(x, map.size.y), Color(0.16, 0.22, 0.25, 0.48))
		for y: int in range(int(fposmod(origin.y, grid_step)), int(map.size.y), maxi(1, int(grid_step))):
			map.draw_line(Vector2(0, y), Vector2(map.size.x, y), Color(0.16, 0.22, 0.25, 0.48))
	var samples: Array[Dictionary] = sampler.samples
	var points: Array = map.definition.get("points", [])
	if samples.size() < 2:
		return
	var stride: int = maxi(1, samples.size() / 1800)
	var segments: int = samples.size() if sampler.closed else samples.size() - 1
	for index: int in range(0, segments, stride):
		var a: Vector3 = samples[index].position
		var next_index: int = mini(index + stride, segments) % samples.size()
		var b: Vector3 = samples[next_index].position
		var horizontal: float = Vector2(b.x - a.x, b.z - a.z).length()
		var grade: float = 100.0 * (b.y - a.y) / maxf(0.01, horizontal)
		var start: Vector2 = map.to_screen(Vector2(a.x, a.z))
		var end: Vector2 = map.to_screen(Vector2(b.x, b.z))
		var width: float = maxf(4.0, float(samples[index].width) * map.zoom)
		map.draw_line(start, end, Color("101618"), width + 3.0, true)
		map.draw_line(start, end, ElevationProfile.grade_color(grade), width, true)
	for index: int in range(points.size()):
		var point: Vector2 = map.to_screen(Vector2(float(points[index].x), float(points[index].z)))
		var chosen: bool = index == map.selected
		map.draw_circle(point, 7.0 if chosen else 3.5, Color("f3fff7") if chosen else Color("10252b"))
		if chosen or points.size() < 30:
			var label: String = "%d · %.1f m" % [index + 1, float(points[index].y)] if chosen else str(index + 1)
			map.draw_string(ThemeDB.fallback_font, point + Vector2(10, -9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e0f1f3"))
	if not sampler.closed:
		for index: int in [0, points.size() - 1]:
			var p: Vector2 = map.to_screen(Vector2(float(points[index].x), float(points[index].z)))
			map.draw_string(ThemeDB.fallback_font, p + Vector2(12, 20), "SALIDA" if index == 0 else "META", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("caff62"))
	map.draw_string(ThemeDB.fallback_font, Vector2(14, 23), "PENDIENTE LOCAL  ·  azul: bajada  ·  verde: suave  ·  naranja: subida", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c0d3d9"))
	map.draw_string(ThemeDB.fallback_font, Vector2(14, map.size.y - 14), "Doble clic: añadir · Arrastrar: mover · Rueda: zoom · Botón central: desplazar", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8da4ae"))
