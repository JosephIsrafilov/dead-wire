shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, specular_disabled;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float edge = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 1.8);
	// Bounded reflection of the room rather than a hot reflection of the wick inside.
	const float roughness = 0.15;
	vec3 half_vector = normalize(v + normalize(vec3(-0.78, 0.25, 0.37)));
	float glint = pow(max(dot(n, half_vector), 0.0), 1.0 / (roughness * roughness));
	ALBEDO = mix(vec3(0.14, 0.125, 0.105), vec3(0.34, 0.22, 0.12), edge)
		+ glint * vec3(0.25, 0.21, 0.155);
	ALPHA = mix(0.28, 0.35, edge);
}
