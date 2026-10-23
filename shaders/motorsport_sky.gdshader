shader_type sky;

uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.3;
uniform vec3 sun_direction = vec3(0.45, 0.55, 0.70);
uniform bool studio = false;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + 1.0), f.x), f.y);
}

vec3 atmosphere(vec3 ray) {
	float elevation = max(ray.y, 0.0);
	float gradient = pow(elevation, 0.48);
	vec3 clear = mix(vec3(0.44, 0.52, 0.57), vec3(0.075, 0.19, 0.33), gradient);
	float facing_sun = max(dot(ray, normalize(sun_direction)), 0.0);
	clear += vec3(0.24, 0.16, 0.075) * pow(facing_sun, 12.0) * (1.0 - gradient);
	vec2 plane = ray.xz / max(ray.y + 0.12, 0.04) * 1.8;
	float shape = noise(plane) * 0.58 + noise(plane * 2.13 + 17.0) * 0.28;
	shape += noise(plane * 4.23 - 23.0) * 0.14;
	float clouds = smoothstep(0.69 - cloud_cover * 0.34, 0.88 - cloud_cover * 0.34, shape);
	clouds *= smoothstep(-0.025, 0.12, ray.y);
	vec3 cloud_color = mix(vec3(0.49, 0.52, 0.53), vec3(0.79, 0.79, 0.73), shape);
	clear = mix(clear, cloud_color, clouds * 0.88);
	clear *= 1.0 - cloud_cover * 0.19;
	clear += vec3(2.3, 1.9, 1.4) * smoothstep(0.99983, 0.99998, facing_sun) * (1.0 - clouds);
	vec3 dark = mix(vec3(0.017, 0.027, 0.047), vec3(0.003, 0.008, 0.021), gradient);
	dark = mix(dark, vec3(0.027, 0.034, 0.047), clouds * 0.78);
	float stars = step(0.997, hash(floor(ray.xz / max(ray.y + 0.22, 0.1) * 180.0)));
	dark += vec3(0.10, 0.12, 0.16) * stars * smoothstep(0.12, 0.65, ray.y) * (1.0 - clouds);
	dark += vec3(0.65, 0.72, 0.81) * smoothstep(0.99978, 0.99993, facing_sun) * (1.0 - clouds);
	vec3 result = mix(clear, dark, night_amount);
	if (ray.y < 0.0) {
		result = mix(result, mix(vec3(0.075, 0.086, 0.064), vec3(0.006, 0.011, 0.015), night_amount), 1.0 - smoothstep(-0.45, 0.0, ray.y));
	}
	return result;
}

void sky() {
	// Render both paths directly: RADIANCE background reads black on GLES Compatibility.
	COLOR = atmosphere(EYEDIR);
	if (studio) {
		float strip = smoothstep(0.90, 0.95, abs(EYEDIR.x)) * smoothstep(-0.1, 0.5, EYEDIR.y);
		COLOR = mix(vec3(0.065, 0.087, 0.11), vec3(0.60, 0.67, 0.75), strip);
	}
}
