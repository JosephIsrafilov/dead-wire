shader_type spatial;

varying vec3 local_pos;
varying vec3 local_normal;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float mottling(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(cell), hash2(cell + vec2(1, 0)), f.x),
		mix(hash2(cell + vec2(0, 1)), hash2(cell + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec2 uv = vec2(abs(local_normal.x) > abs(local_normal.z) ? local_pos.z : local_pos.x, local_pos.y);
	vec2 texel = floor(uv * 42.0) / 42.0;
	float wash = mottling(texel * 2.7);
	float fleck = mottling(texel * 31.0);
	float seam = smoothstep(0.91, 0.99, fract(texel.x / 0.49)) * 0.020;
	vec3 base = vec3(0.37, 0.32, 0.246);
	ALBEDO = base * (0.92 + wash * 0.23 + fleck * 0.085 - seam);
	ROUGHNESS = 0.93;
}
