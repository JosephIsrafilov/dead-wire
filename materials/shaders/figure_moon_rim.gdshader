shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec3 core_color : source_color = vec3(0.012, 0.015, 0.022);
uniform vec3 rim_color : source_color = vec3(0.22, 0.32, 0.48);
uniform float rim_power : hint_range(1.0, 6.0) = 3.2;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.34;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	float top_bias = clamp(NORMAL.y * 0.75 + 0.35, 0.12, 1.0);
	ALBEDO = mix(core_color, rim_color, clamp(fresnel * rim_strength * top_bias, 0.0, 0.45));
}
