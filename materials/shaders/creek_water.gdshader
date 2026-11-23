shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert;

uniform sampler2D water_tex : source_color, filter_nearest, repeat_enable;
uniform float flow_speed = 0.24;
uniform vec4 tint_color : source_color = vec4(0.24, 0.38, 0.46, 0.88);
uniform vec4 foam_color : source_color = vec4(0.84, 0.90, 0.94, 0.92);

void fragment() {
	vec2 uv_a = UV * vec2(1.5, 8.0) + vec2(0.0, TIME * flow_speed);
	vec2 uv_b = UV * vec2(2.2, 6.0) + vec2(0.18, TIME * flow_speed * 0.68);
	vec3 tex_a = texture(water_tex, uv_a).rgb;
	vec3 tex_b = texture(water_tex, uv_b).rgb;
	float luma = dot((tex_a + tex_b) * 0.5, vec3(0.3, 0.59, 0.11));
	float foam = smoothstep(0.64, 0.88, luma);
	ALBEDO = mix(tint_color.rgb * (0.78 + luma * 0.42), foam_color.rgb, foam * 0.65);
	ALPHA = clamp(tint_color.a + foam * 0.10, 0.72, 0.96);
	ROUGHNESS = 0.25;
}
