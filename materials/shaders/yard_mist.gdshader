shader_type spatial;
// Layered low-lying yard mist outside the north bay window.
// Unshaded, soft smoothstep edges on both axes so layers never read as flat
// cards, slowly drifting on the wind and lifting with MoonWeather.dawn.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 night_color : source_color = vec3(0.13, 0.16, 0.23);
uniform vec3 dawn_color : source_color = vec3(0.47, 0.50, 0.55);
uniform float density : hint_range(0.0, 1.0) = 0.24;
uniform float drift_speed = 0.014;
uniform float noise_scale = 2.4;
uniform float phase_offset = 0.0;
uniform float dawn_amount : hint_range(0.0, 1.0) = 0.0;
uniform float moon_dim : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p *= 2.04;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float edge_x = smoothstep(0.0, 0.22, uv.x) * (1.0 - smoothstep(0.78, 1.0, uv.x));
	float edge_y = smoothstep(0.0, 0.30, uv.y) * (1.0 - smoothstep(0.48, 0.98, uv.y));
	float mask = edge_x * edge_y;

	vec2 drift = vec2(TIME * drift_speed + phase_offset, TIME * drift_speed * 0.25);
	float n1 = fbm(uv * vec2(noise_scale * 1.6, noise_scale) + drift);
	float n2 = fbm(uv * vec2(noise_scale * 3.1, noise_scale * 1.8) - drift * 0.65);
	float wisp = smoothstep(0.28, 0.78, n1 * 0.65 + n2 * 0.35);

	float dawn_eased = smoothstep(0.0, 1.0, dawn_amount);
	vec3 col = mix(night_color, dawn_color, dawn_eased);
	float light_scale = mix(1.0 - moon_dim * 0.32, 1.0, dawn_eased);
	col *= mix(0.92, 1.08, dawn_eased) * light_scale;

	float dawn_lift = mix(1.0, 0.72, smoothstep(0.45, 1.0, dawn_eased));
	ALBEDO = col;
	ALPHA = clamp(mask * wisp * density * dawn_lift, 0.0, 0.65);
}
