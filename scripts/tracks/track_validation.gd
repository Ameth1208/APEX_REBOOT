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

static func auto_repair_crossings(definition: Dictionary, thickness: float) -> Dictionary:
	## Turn a near-level crossing into a simple bridge by lifting the lower span.
	var repaired: Dictionary = definition.duplicate(true)
	# A real road crossing is not evidence of a bridge. Never fabricate elevation.
	if str(definition.get("construction_mode", "faithful")) == "faithful":
		return repaired
	var repairs: Array = repaired.get("crossing_repairs", [])
	for _pass: int in range(8):
		var sampler := TrackSampler.new()
		sampler.rebuild(repaired)
		var crossing: Dictionary = _find_crossing(sampler, thickness)
		if crossing.is_empty():
			break
		var first_control: int = int(crossing.first_control)
		var second_control: int = int(crossing.second_control)
		var points: Array = repaired.get("points", [])
		if first_control == second_control or points.is_empty():
			break
		var lower_control: int = first_control if float(crossing.first_height) <= float(crossing.second_height) else second_control
		var next_control: int = lower_control + 1
		if bool(repaired.get("closed", false)):
			next_control = next_control % points.size()
		elif next_control >= points.size():
			break
		var target_gap: float = thickness + 6.0
		var lift: float = maxf(0.75, target_gap - float(crossing.gap) + 0.5)
		points[lower_control]["y"] = float(points[lower_control].get("y", 0.0)) + lift
		points[next_control]["y"] = float(points[next_control].get("y", 0.0)) + lift
		repairs.append({"segment": lower_control, "lift_m": lift, "gap_before_m": float(crossing.gap)})
		repaired["points"] = points
	if not repairs.is_empty():
		repaired["crossing_repairs"] = repairs
	return repaired

static func _find_crossing(sampler: TrackSampler, thickness: float) -> Dictionary:
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
			var second_t: float = Vector2(c.x, c.z).distance_to(p) / maxf(0.001, Vector2(c.x, c.z).distance_to(Vector2(d.x, d.z)))
			var first_height: float = lerpf(a.y, b.y, first_t)
			var second_height: float = lerpf(c.y, d.y, second_t)
			var gap: float = absf(first_height - second_height)
			if gap < thickness + 6.0:
				return {"first_control": int(samples[i].get("control_index", i)), "second_control": int(samples[j].get("control_index", j)), "first_height": first_height, "second_height": second_height, "gap": gap}
	return {}
