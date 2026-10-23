extends RefCounted
## Original graphic designs in normalized vehicle coordinates, without bitmaps.

const PATTERNS := {
	"twin_stripes": 0, "diagonal_blocks": 1, "pinstripes": 2,
	"speed_blocks": 3, "chevrons": 4, "circuit_lines": 5,
	"central_band": 6, "cross_bands": 7, "swept_wings": 8,
	"nose_wedge": 9, "checker_tail": 10, "edge_ribbons": 11,
}

const CODE := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform vec4 paint_color : source_color = vec4(1.0);
uniform vec4 secondary_color : source_color = vec4(1.0);
uniform vec4 accent_color : source_color = vec4(1.0);
uniform mat4 mesh_to_vehicle;
uniform vec3 vehicle_size = vec3(2.0, 1.2, 4.5);
uniform bool textured = false;
uniform bool normal_mapped = false;
uniform float normal_strength = 1.0;
uniform bool preserve_livery = true;
uniform int pattern = -1;
uniform float paint_metallic = 0.2;
uniform float paint_roughness = 0.28;
varying vec3 vehicle_position;

float band(float coordinate, float center, float width) {
    return 1.0 - smoothstep(width, width + 0.008, abs(coordinate - center));
}

void vertex() {
    vehicle_position = (mesh_to_vehicle * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 original = source_tint.rgb;
    if (textured) { original *= texture(source_texture, UV).rgb; }
    float lightest = max(original.r, max(original.g, original.b));
    float mask = 1.0;
    vec3 result_color = paint_color.rgb;
    if (pattern < 0) {
        if (textured && preserve_livery) {
            mask = smoothstep(0.07, 0.28, original.r - max(original.g, original.b));
            mask *= smoothstep(0.12, 0.4, original.r);
        }
    } else {
        vec3 p = vehicle_position / max(vehicle_size, vec3(0.01));
        float side = smoothstep(0.27, 0.39, abs(p.x));
        float secondary = 0.0;
        float accent = 0.0;
        if (pattern == 0) {
            secondary = band(abs(p.x), 0.12, 0.043);
            accent = band(abs(p.x), 0.179, 0.009);
            secondary = max(secondary, side * band(p.y, 0.26, 0.047));
        } else if (pattern == 1) {
            float diagonal = p.z + p.x * 0.8;
            secondary = smoothstep(0.015, 0.03, diagonal);
            accent = band(diagonal, -0.022, 0.015);
        } else if (pattern == 2) {
            secondary = band(abs(p.x), 0.12, 0.008);
            accent = max(side * band(p.y, 0.33, 0.014), band(p.x, 0.0, 0.010));
        } else if (pattern == 3) {
            float slash = p.z + p.y * 0.55;
            secondary = band(slash, 0.20, 0.10);
            accent = band(slash, 0.055, 0.024);
        } else if (pattern == 4) {
            float chevron = fract(abs(p.x) * 1.7 + p.z * 2.5 + p.y * 0.45);
            secondary = smoothstep(0.59, 0.62, chevron);
            accent = band(chevron, 0.50, 0.032);
        } else if (pattern == 5) {
            float sweep = p.y + p.z * 0.25;
            secondary = band(sweep, 0.48, 0.022);
            accent = max(band(sweep, 0.35, 0.011), band(abs(p.x), 0.10, 0.010));
        } else if (pattern == 6) {
            secondary = band(p.x, 0.0, 0.098);
            accent = band(abs(p.x), 0.129, 0.018);
        } else if (pattern == 7) {
            secondary = max(band(p.z, -0.24, 0.047), band(p.z, 0.24, 0.060));
            accent = max(band(p.z, -0.166, 0.012), band(p.z, 0.326, 0.013));
        } else if (pattern == 8) {
            float wing = abs(p.x) * 0.65 - p.z;
            secondary = band(wing, 0.22, 0.035);
            accent = band(wing, 0.13, 0.011);
        } else if (pattern == 9) {
            secondary = 1.0 - smoothstep(0.012, 0.025, abs(p.x) + p.z * 0.45 + 0.05);
            accent = band(abs(p.x) + p.z * 0.45, 0.006, 0.013);
            secondary = max(secondary, side * band(p.y, 0.30, 0.060));
        } else if (pattern == 10) {
            float checker = mod(floor((p.x + 0.5) * 12.0) + floor((p.z + 0.5) * 18.0), 2.0);
            secondary = checker * smoothstep(0.05, 0.09, p.z);
            accent = band(p.z, 0.045, 0.014);
            secondary = max(secondary, band(abs(p.x), 0.11, 0.035));
        } else {
            float ribbon = p.y + 0.065 * sin(p.z * 12.0);
            secondary = max(band(ribbon, 0.34, 0.022), band(p.x, 0.0, 0.025));
            accent = band(ribbon, 0.43, 0.014);
        }
        result_color = mix(result_color, secondary_color.rgb, secondary);
        result_color = mix(result_color, accent_color.rgb, accent);
        // Retain black details contained within a selected body texture.
        if (textured) { mask = smoothstep(0.025, 0.10, lightest); }
    }
    float shade = textured ? (0.70 + 0.30 * lightest) : 1.0;
    ALBEDO = mix(original, result_color * shade, mask);
    METALLIC = paint_metallic;
    ROUGHNESS = paint_roughness;
    CLEARCOAT = 0.7;
    CLEARCOAT_ROUGHNESS = 0.18;
    if (normal_mapped) {
        NORMAL_MAP = texture(source_normal, UV).rgb;
        NORMAL_MAP_DEPTH = normal_strength;
    }
}
"""

static func create() -> Shader:
	var shader := Shader.new()
	shader.code = CODE
	return shader

static func pattern_id(name: String) -> int:
	return int(PATTERNS.get(name, -1))
