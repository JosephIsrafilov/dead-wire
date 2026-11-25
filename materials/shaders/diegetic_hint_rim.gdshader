shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

instance uniform float hint_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, 1.35);
	float breath = 0.5 + 0.5 * sin(TIME * 2.4);
	float sweep = pow(max(0.0, sin((UV.x + UV.y) * 3.14159 - TIME * 1.9)), 5.0) * 0.24;
	float edge_tint = mix(0.07, 0.14, breath);
	float rim_glow = rim * mix(0.28, 0.48, breath);
	vec3 warm_amber = mix(vec3(0.98, 0.56, 0.10), vec3(1.0, 0.78, 0.28), rim);
	ALBEDO = warm_amber;
	ALPHA = clamp((edge_tint + rim_glow + sweep) * hint_strength, 0.0, 0.48);
}
