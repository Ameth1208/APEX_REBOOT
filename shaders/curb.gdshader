shader_type spatial;

uniform vec4 red : source_color = vec4(0.63, 0.10, 0.13, 1.0);
uniform vec4 white : source_color = vec4(0.74, 0.74, 0.70, 1.0);
uniform sampler2D surface_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float stripes = sin(UV2.y * 1.2566370614);
	float edge = max(fwidth(stripes), 0.01);
	float band = smoothstep(-edge, edge, stripes);
	float grain = texture(surface_detail, UV * 18.0 / 256.0).r;
	float seams = 1.0 - smoothstep(0.0, 0.024 + fwidth(UV2.y), abs(fract(UV2.y * 0.5) - 0.5));
	ALBEDO = mix(red.rgb, white.rgb, band) * (0.92 + grain * 0.10) * (1.0 - seams * 0.10) * (1.0 - wetness * 0.17);
	ROUGHNESS = mix(0.79 + grain * 0.10, 0.28, wetness);
	SPECULAR = mix(0.23, 0.48, wetness);
}
