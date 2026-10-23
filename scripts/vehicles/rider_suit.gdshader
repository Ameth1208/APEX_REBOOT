shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin_texture : source_color, filter_linear_mipmap;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap;
uniform bool cockpit = false;
uniform vec3 suit_color : source_color = vec3(0.075, 0.095, 0.14);
uniform vec3 panel_color : source_color = vec3(0.70, 0.75, 0.80);
uniform vec3 accent_color : source_color = vec3(0.12, 0.62, 0.88);

void fragment() {
	// UV2 stores bind-pose x/y; skinning cannot slide the seams or cockpit mask.
	vec2 rest = UV2;
	float side = abs(rest.x);
	if (cockpit && side < 0.43 && rest.y > 0.92) { discard; }
	float cloth = 1.0 - smoothstep(1.525, 1.55, rest.y);
	float panel = smoothstep(0.17, 0.22, side) * (1.0 - smoothstep(0.66, 0.70, side));
	panel *= smoothstep(1.28, 1.33, rest.y) * (1.0 - smoothstep(1.50, 1.53, rest.y));
	float stripe = 1.0 - smoothstep(0.014, 0.020, abs(rest.y - 1.28 - side * 0.25));
	stripe *= 1.0 - smoothstep(0.62, 0.67, side);
	vec3 clothing = mix(suit_color, panel_color, panel);
	clothing = mix(clothing, accent_color, stripe);
	float zipper = (1.0 - smoothstep(0.004, 0.008, side)) * step(1.0, rest.y) * step(rest.y, 1.46);
	clothing = mix(clothing, vec3(0.28), zipper);
	ALBEDO = mix(texture(skin_texture, UV).rgb, clothing, cloth);
	ROUGHNESS = mix(0.68, 0.78, cloth);
	SPECULAR = 0.3;
	METALLIC = 0.0;
	NORMAL_MAP = mix(texture(skin_normal, UV).rgb, vec3(0.5, 0.5, 1.0), cloth);
	NORMAL_MAP_DEPTH = 0.5;
}
