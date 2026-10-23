shader_type spatial;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	vec2 cell = abs(fract(p * 0.25) - 0.5);
	float width = max(fwidth(p.x), fwidth(p.y)) * 0.25;
	float seam = smoothstep(0.497 - width, 0.5, max(cell.x, cell.y));
	float subtle = sin(p.x * 47.0) * sin(p.y * 41.0) * 0.002;
	ALBEDO = vec3(0.022, 0.029, 0.036) + vec3(subtle) - seam * 0.007;
	METALLIC = 0.18;
	ROUGHNESS = 0.54;
}
