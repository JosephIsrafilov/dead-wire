shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D road_color : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D road_normal : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D road_rough : filter_nearest_mipmap, repeat_enable;
varying vec3 world_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1, 0)), f.x),
		mix(hash21(cell + vec2(0, 1)), hash21(cell + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Shared world coordinates keep road and shoulders continuous on separate meshes.
	vec2 p = floor(world_pos.xz * 36.0) / 36.0;
	float wear = value_noise(p * vec2(0.26, 0.79));
	float broken_edge = value_noise(p * 0.94) - 0.5;
	float avenue_width = 6.9 + broken_edge * 2.2;
	float road = 1.0 - smoothstep(avenue_width - 0.65, avenue_width + 0.85, abs(p.y - 23.1));
	road *= smoothstep(-64.0, -58.0, p.x);
	float approach = (1.0 - smoothstep(2.8, 5.6, abs(p.x + broken_edge)))
		* smoothstep(1.8, 3.8, p.y) * (1.0 - smoothstep(23.0, 26.0, p.y));
	road = max(road, approach);
	float drift = (value_noise(vec2(p.x * 0.13, 3.7)) - 0.5) * 0.85;
	float ruts = 0.0;
	for (int i = 0; i < 4; i++) {
		float lane = float(i) * 1.46 - 2.19;
		float groove = abs(p.y - 23.1 - lane - drift);
		ruts = max(ruts, (1.0 - smoothstep(0.09, 0.34, groove)) * (0.34 + 0.66 * wear));
	}
	float wet = smoothstep(0.49, 0.77, wear) * ruts * road;
	float dust = value_noise(p * 4.9);
	float gravel = step(0.93, hash21(floor(p * 18.0))) * (0.45 + 0.55 * dust);
	vec3 clay = mix(vec3(0.115, 0.072, 0.044), vec3(0.259, 0.177, 0.109), 0.34 + wear * 0.55);
	clay = mix(clay, vec3(0.079, 0.051, 0.033), ruts * (0.30 + wet * 0.42));
	float thaw = smoothstep(0.30, 0.68, value_noise(p * 0.52) + broken_edge * 0.3);
	vec3 sod = mix(vec3(0.129, 0.093, 0.055), vec3(0.102, 0.121, 0.061), thaw);
	vec2 uv = vec2(p.x, -p.y) * 0.41;
	float aggregate = texture(road_color, uv).r;
	float pool = smoothstep(0.68, 0.83, value_noise(p * vec2(0.34, 2.0))) * ruts * road;
	vec3 soil = mix(sod, clay, road) * mix(0.73, 1.40, aggregate);
	ALBEDO = max(vec3(0.02), soil * (1.0 - pool * 0.29) + (dust - 0.5) * 0.031 + gravel * 0.040);
	NORMAL_MAP = texture(road_normal, uv).rgb;
	NORMAL_MAP_DEPTH = mix(0.77, 0.14, pool);
	ROUGHNESS = mix(texture(road_rough, uv).r, 0.35, max(pool, wet * 0.74));
}
