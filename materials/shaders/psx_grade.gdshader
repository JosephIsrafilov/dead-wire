shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size = 3.0;
uniform float levels = 32.0;
uniform float vignette = 0.22;
uniform float dither_strength = 1.85;
const float BAYER[16] = float[](0.0,8.0,2.0,10.0,12.0,4.0,14.0,6.0,3.0,11.0,1.0,9.0,15.0,7.0,13.0,5.0);
void fragment() {
    float safe_size = max(pixel_size, 1.0);
    float safe_levels = max(levels, 2.0);
    vec2 inv_px = max(SCREEN_PIXEL_SIZE, vec2(0.0001));
    vec2 screen_res = 1.0 / inv_px;
    vec2 cell = floor((SCREEN_UV * screen_res) / safe_size);
    vec2 snapped_uv = clamp((cell * safe_size + safe_size * 0.5) * inv_px, vec2(0.0), vec2(1.0));
    int index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
    float ordered = ((BAYER[index] + 0.5) / 16.0 - 0.5) * (dither_strength / safe_levels);
    vec3 color = textureLod(screen_texture, snapped_uv, 0.0).rgb;
    vec2 offset = SCREEN_UV - 0.5;
    color *= 1.0 - clamp(vignette, 0.0, 0.35) * dot(offset, offset) * 2.0;
    color = floor((color + ordered) * safe_levels + 0.5) / safe_levels;
    COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
