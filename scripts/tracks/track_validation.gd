class_name TrackValidation
extends RefCounted

static func source_error(definition: Dictionary) -> String:
	if bool(definition.get("requires_elevation", false)):
		return "Completa las cotas de la ruta o confirma una versión plana antes de conducir."
	if not definition.has("points"):
		return ""
	var points: Variant = definition["points"]
	var minimum: int = 4 if bool(definition.get("closed", true)) else 2
	if not points is Array or points.size() < minimum:
		return "El recorrido necesita al menos %d puntos." % minimum
	for point: Variant in points:
		if not point is Dictionary:
			return "La ruta contiene un punto inválido."
		for key: String in ["x", "y", "z"]:
			var value: Variant = point.get(key, null)
			if not (value is float or value is int) or not is_finite(float(value)):
				return "Todos los puntos necesitan coordenadas y elevaciones numéricas completas."
	var segments: int = points.size() if bool(definition.get("closed", true)) else points.size() - 1
	for i: int in range(segments):
		var a: Vector3 = TrackDefinition.position(points[i])
		var b: Vector3 = TrackDefinition.position(points[(i + 1) % points.size()])
		if Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) < 0.001 and absf(a.y - b.y) > 0.001:
			return "Dos puntos forman un salto vertical sin carretera horizontal. Revisa sus cotas o elimina el duplicado."
	return ""

static func layout_error(sampler: TrackSampler, thickness: float) -> String:
	if sampler.length_m < 120.0:
		return "Separa los puntos: el circuito debe medir al menos 120 metros."
	var samples: Array[Dictionary] = sampler.samples
	var stride: int = 4
	var segments: int = samples.size() if sampler.closed else samples.size() - 1
	for i: int in range(0, segments, stride):
		var a: Vector3 = samples[i]["position"]
		var end_i: int = mini(i + stride, segments)
		var b: Vector3 = samples[end_i % samples.size()]["position"]
		for j: int in range(end_i + stride, segments, stride):
			var end_j: int = mini(j + stride, segments)
			if sampler.closed and i == 0 and end_j == segments:
				continue
			var c: Vector3 = samples[j]["position"]
			var d: Vector3 = samples[end_j % samples.size()]["position"]
			var crossing: Variant = Geometry2D.segment_intersects_segment(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), Vector2(d.x, d.z))
			if crossing == null:
				continue
			var p: Vector2 = crossing
			var first_t: float = Vector2(a.x, a.z).distance_to(p) / maxf(0.001, Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)))
			var next_t: float = Vector2(c.x, c.z).distance_to(p) / maxf(0.001, Vector2(c.x, c.z).distance_to(Vector2(d.x, d.z)))
			var gap: float = absf(lerpf(a.y, b.y, first_t) - lerpf(c.y, d.y, next_t))
			if gap < thickness + 6.0:
				return "Dos tramos se cruzan con solo %.1f m de separación. Eleva uno para dejar al menos %.1f m, o separa sus puntos." % [gap, thickness + 6.0]
	return ""
