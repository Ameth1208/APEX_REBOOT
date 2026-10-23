shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.2, 0.3, 0.14, 1.0);
uniform float grain_scale = 8.0;
uniform float variation = 0.2;
uniform float patch_scale = 0.15;
uniform bool is_concrete = false;
uniform int surface_kind = 0;
uniform bool road_surface = false;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D surface_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D custom_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_custom_texture = false;
uniform bool blend_mode = false;

// Surface colours for blending: R=sand, G=grass, B=dirt, A=concrete.
const vec3 COL_SAND = vec3(0.70, 0.63, 0.48);
const vec3 COL_GRASS = vec3(0.24, 0.30, 0.18);
const vec3 COL_DIRT = vec3(0.41, 0.31, 0.23);
const vec3 COL_CONCRETE = vec3(0.58, 0.58, 0.55);

void fragment() {
	// UV is in world metres; UV2 is lateral metres / distance along the road.
	float pixel_size = max(length(dFdx(UV)), length(dFdy(UV)));
	float detail = 1.0 - smoothstep(0.6, 2.3, pixel_size * grain_scale);
	float grain = texture(surface_detail, UV * grain_scale / 256.0).r;
	float patches = texture(surface_detail, UV * patch_scale / 256.0 + vec2(0.31)).g;
	float broad = texture(surface_detail, UV * 0.025 / 256.0 + vec2(0.53)).b;
	float relief = (grain - 0.5) * 0.010;
	float rough = 0.87 + (grain - 0.5) * 0.15;
	vec3 color = base_color.rgb * (0.94 + (grain - 0.5) * variation + (patches - 0.5) * variation);
	if (blend_mode) {
		// Vertex colour weights: R=sand, G=grass, B=dirt, A=concrete.
		vec4 w = COLOR;
		float total = w.r + w.g + w.b + w.a + 0.0001;
		vec3 sand_c = COL_SAND * (0.94 + (grain - 0.5) * variation);
		vec3 grass_c = COL_GRASS * mix(0.80, 1.16, patches);
		vec3 dirt_c = COL_DIRT * mix(0.68, 1.32, grain);
		vec3 conc_c = COL_CONCRETE;
		vec2 joint = abs(fract(UV / 5.0) - 0.5);
		float line = smoothstep(0.492 - pixel_size * 0.015, 0.5, max(joint.x, joint.y));
		conc_c *= 1.0 - line * 0.27;
		color = (sand_c * w.r + grass_c * w.g + dirt_c * w.b + conc_c * w.a) / total;
		// Relief blends too.
		float relief_blend = (w.r * 0.4 + w.g * 2.0 + w.b * 4.0 + w.a * 0.25) / total;
		relief *= relief_blend;
	} else if (surface_kind == 0) {
		color *= 1.0 - smoothstep(0.62, 0.83, broad) * 0.13;
		rough = 0.78 + grain * 0.13;
		relief *= 0.32;
		if (road_surface) {
			float rubber = exp(-pow(abs(UV2.x) * 0.35, 4.0)) * (0.055 + patches * 0.075);
			float tyre_offset = (abs(UV2.x) - 0.85) * 2.5;
			float tyre_paths = exp(-tyre_offset * tyre_offset);
			color *= 1.0 - rubber - tyre_paths * 0.026;
			rough -= rubber * 0.25;
		}
	} else if (is_concrete) {
		vec2 joint = abs(fract(UV / 5.0) - 0.5);
		float line = smoothstep(0.492 - pixel_size * 0.015, 0.5, max(joint.x, joint.y));
		color *= 1.0 - line * 0.27;
		relief *= 0.25;
	} else if (surface_kind == 2) {
		color *= mix(0.68, 1.32, grain);
		relief *= 4.0;
	} else if (surface_kind == 4) {
		color = mix(color, vec3(0.090, 0.086, 0.044), smoothstep(0.52, 0.8, broad) * 0.42);
		color *= mix(0.80, 1.16, patches);
		relief *= 2.0;
	} else if (surface_kind == 5) {
		color *= 0.95 + sin(UV.x * 5.0 + patches * 6.0) * 0.025 * detail;
		relief *= 0.40;
	}
	if (use_custom_texture) {
		color = texture(custom_texture, UV * 0.25).rgb;
	}
	float sealed = surface_kind <= 1 ? 1.0 : 0.0;
	float puddle = smoothstep(0.67 - wetness * 0.21, 0.85 - wetness * 0.15, patches);
	float film = wetness * mix(0.16, 0.48 + puddle * 0.52, sealed);
	ALBEDO = color * (1.0 - wetness * mix(0.20, 0.32, sealed));
	ROUGHNESS = mix(rough, 0.095, film);
	SPECULAR = mix(0.24, 0.55, wetness * sealed);
	AO = mix(0.91, 1.0, grain);
	float height = relief * detail * (1.0 - film * 0.82);
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 across_y = cross(dy, NORMAL);
	vec3 across_x = cross(NORMAL, dx);
	float determinant = dot(dx, across_y);
	vec3 slope = dFdx(height) * across_y + dFdy(height) * across_x;
	if (abs(determinant) > 0.000001) {
		NORMAL = normalize(abs(determinant) * NORMAL - sign(determinant) * slope);
	}
}
