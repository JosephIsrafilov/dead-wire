shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size = 1.0;
uniform float levels = 32.0;
uniform float vignette = 0.22;
uniform float dither_strength = 1.85;
// Film grain on the render grid (GDD 35.1: subtle and constant). Strongest in
// the mid-tones, nearly gone in black and on the lamp-lit paper.
uniform float grain = 0.022;
uniform float grain_fps = 24.0;
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
    float ordered = ((BAYER[index] + 0.5) / 16.0 - 0.5) * (dither_strength / safe_levels);
    vec3 color = textureLod(screen_texture, snapped_uv, 0.0).rgb;
    vec2 offset = SCREEN_UV - 0.5;
    color *= 1.0 - clamp(vignette, 0.0, 0.35) * dot(offset, offset) * 2.0;
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    float grain_weight = smoothstep(0.0, 0.12, luma) * (1.0 - smoothstep(0.55, 0.95, luma));
    float noise = grain_hash(cell, floor(TIME * grain_fps)) - 0.5;
    color += noise * grain * grain_weight;
    color = floor((color + ordered) * safe_levels + 0.5) / safe_levels;
    COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
