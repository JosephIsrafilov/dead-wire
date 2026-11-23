shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size = 1.0;
uniform float levels = 32.0;
uniform float vignette = 0.25;
uniform float dither_strength = 1.35;
// Restrained low-res grain + shadow-weighted Bayer dithering for 1890s PSX horror.
uniform float grain = 0.026;
uniform float grain_fps = 18.0;
uniform float color_saturation = 0.88;
uniform vec3 shadow_tint = vec3(0.004, 0.007, 0.016);
uniform vec3 highlight_tint = vec3(1.03, 0.99, 0.93);
uniform float shadow_crush_factor = 0.94;
const float BAYER[16] = float[](0.0,8.0,2.0,10.0,12.0,4.0,14.0,6.0,3.0,11.0,1.0,9.0,15.0,7.0,13.0,5.0);

float grain_hash(vec2 cell, float frame) {
	vec3 p = fract(vec3(cell.xyx) * 0.1031 + frame * 0.0973);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	float safe_size = max(pixel_size, 1.0);
	float safe_levels = max(levels, 2.0);
	vec2 inv_px = SCREEN_PIXEL_SIZE;
	vec2 screen_res = 1.0 / inv_px;
	vec2 cell = floor((SCREEN_UV * screen_res) / safe_size);
	vec2 snapped_uv = clamp((cell * safe_size + safe_size * 0.5) * inv_px, vec2(0.0), vec2(1.0));
	int index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	vec3 color = textureLod(screen_texture, snapped_uv, 0.0).rgb;

	// Filmic shadow toe + subtle desaturation + cold-slate shadows / warm-kerosene highlights.
	float luma_raw = dot(color, vec3(0.299, 0.587, 0.114));
	float shadow_mask = 1.0 - smoothstep(0.03, 0.42, luma_raw);
	float hi_mask = smoothstep(0.40, 0.92, luma_raw);
	color = mix(vec3(luma_raw), color, color_saturation);
	color *= mix(1.0, shadow_crush_factor, shadow_mask);
	color += shadow_tint * shadow_mask;
	color *= mix(vec3(1.0), highlight_tint, hi_mask);

	// Organic edge vignette
	vec2 offset = SCREEN_UV - 0.5;
	color *= 1.0 - clamp(vignette, 0.0, 0.35) * dot(offset, offset) * 2.0;

	// Fine mid/shadow grain + shadow-weighted 4x4 Bayer ordered dither
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float grain_weight = smoothstep(0.0, 0.10, luma) * (1.0 - smoothstep(0.50, 0.92, luma));
	float noise = grain_hash(cell, floor(TIME * grain_fps)) - 0.5;
	color += noise * grain * grain_weight;

	float dither_gain = dither_strength * (1.0 + (1.0 - luma) * 0.65);
	float ordered = ((BAYER[index] + 0.5) / 16.0 - 0.5) * (dither_gain / safe_levels);
	color = floor((clamp(color, vec3(0.0), vec3(1.0)) + ordered) * safe_levels + 0.5) / safe_levels;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
