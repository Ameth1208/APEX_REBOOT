shader_type spatial;
render_mode cull_disabled;

uniform float wind_strength = 0.11;
uniform float root_height = 1.7;
uniform float bend_range = 5.0;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float weight = smoothstep(root_height, root_height + bend_range, VERTEX.y);
	float sway = sin(world.x * 0.13 + world.z * 0.17 + TIME * 1.4);
	VERTEX.x += sway * weight * wind_strength;
	VERTEX.z += cos(world.x * 0.09 + TIME * 1.1) * weight * wind_strength * 0.55;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.91;
	SPECULAR = 0.22;
	BACKLIGHT = COLOR.rgb * 0.12;
}
