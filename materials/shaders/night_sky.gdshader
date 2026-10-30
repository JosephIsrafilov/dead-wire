shader_type spatial;
// The sky out of the north window: a gradient by elevation, the moon as a real
// disc where the moonlight in the room comes from, and slow clouds. A cloud
// that MoonWeather says is crossing the moon is drawn over the disc
// (cloud_cover), so the dim in the room and the cloud in the sky are one event.
// It is computed from the view direction, not from UVs, so the far quad can be
// any size and the moon stays put as the head moves.
render_mode unshaded, fog_disabled, shadows_disabled;

uniform vec3 zenith_color : source_color = vec3(0.035, 0.045, 0.085);
uniform vec3 horizon_color : source_color = vec3(0.16, 0.18, 0.24);
uniform vec3 dawn_zenith : source_color = vec3(0.32, 0.36, 0.46);
uniform vec3 dawn_horizon : source_color = vec3(0.86, 0.66, 0.5);
uniform vec3 moon_direction = vec3(-0.22, 0.42, -1.0);
uniform vec3 moon_color : source_color = vec3(0.86, 0.9, 1.0);
uniform float moon_size = 0.022;
uniform vec3 cloud_color : source_color = vec3(0.07, 0.08, 0.11);
uniform float cloud_drift = 0.004;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.0;
uniform float dawn : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir = normalize(world - CAMERA_POSITION_WORLD);
	float elevation = clamp(dir.y, 0.0, 1.0);
	float height = pow(elevation, 0.55);
	vec3 night = mix(horizon_color, zenith_color, height);
	vec3 morning = mix(dawn_horizon, dawn_zenith, height);
	vec3 color = mix(night, morning, smoothstep(0.0, 1.0, dawn));

	vec3 moon_dir = normalize(moon_direction);
	float moon_angle = acos(clamp(dot(dir, moon_dir), -1.0, 1.0));
	float disc = 1.0 - smoothstep(moon_size * 0.85, moon_size, moon_angle);
	float halo = exp(-moon_angle * 9.0) * 0.18;

	// Clouds live on a plane above the yard: project the ray onto it.
	vec2 plane = dir.xz / max(dir.y + 0.08, 0.05);
	vec2 drift = vec2(TIME * cloud_drift, TIME * cloud_drift * 0.35);
	float field = fbm(plane * 1.6 + drift * 40.0);
	float sky_clouds = smoothstep(0.55, 0.78, field) * smoothstep(0.02, 0.2, elevation);
	// The cloud MoonWeather announces: a bank over the disc while it holds.
	float near_moon = 1.0 - smoothstep(moon_size * 2.0, moon_size * 9.0, moon_angle);
	float crossing = cloud_cover * smoothstep(0.3, 0.6, fbm(plane * 3.0 + drift * 60.0)) * near_moon;
	float cloud = clamp(sky_clouds + crossing + cloud_cover * near_moon * 0.6, 0.0, 1.0);

	float moon_fade = 1.0 - smoothstep(0.0, 0.8, dawn);
	color += (moon_color * disc + moon_color * halo) * moon_fade * (1.0 - cloud * 0.92);
	// Clouds near the moon catch its light on their edges.
	vec3 lit_cloud = cloud_color + moon_color * halo * 1.4 * moon_fade;
	color = mix(color, mix(lit_cloud, morning * 0.8, dawn), cloud * 0.85);
	ALBEDO = color;
}
