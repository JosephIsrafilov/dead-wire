shader_type canvas_item;
render_mode unshaded;
uniform float prescale = 1.0;

// Exactly the bilinear sample of a nearest-upscaled intermediate image.
// Four source fetches avoid allocating the larger intermediate render target.
void fragment() {
    vec2 source_size = vec2(textureSize(TEXTURE, 0));
    vec2 p = UV * source_size * prescale - 0.5;
    vec2 base = floor(p);
    vec2 blend = fract(p);
    vec2 a = (floor(base / prescale) + 0.5) / source_size;
    vec2 b = (floor((base + 1.0) / prescale) + 0.5) / source_size;
    vec4 top = mix(texture(TEXTURE, a), texture(TEXTURE, vec2(b.x, a.y)), blend.x);
    vec4 bottom = mix(texture(TEXTURE, vec2(a.x, b.y)), texture(TEXTURE, b), blend.x);
    COLOR = mix(top, bottom, blend.y);
}
