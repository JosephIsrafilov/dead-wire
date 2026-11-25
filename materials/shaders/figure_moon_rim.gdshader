shader_type spatial;
render_mode unshaded, fog_disabled;

// Unshaded lunar silhouette shader for the Stage 1.1 window figure.
// No dynamic light or emission is added (the yard stays dark per GDD section 10);
// outer contours catch faint cold upper-left moonlight off the night sky while
// inward hollows and cloth folds drop into soot-black.
// On figure_head, pallor_strength subtly lifts sculpted frontal bone structure
// (cheekbones, nose bridge, jaw) while keeping orbital hollows pitch-black.
uniform vec3 core_color : source_color = vec3(0.006, 0.008, 0.013);
uniform vec3 rim_color : source_color = vec3(0.21, 0.31, 0.46);
uniform float rim_power : hint_range(1.0, 8.0) = 3.2;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.34;
// 0 = coat/head/hat contour rim; 1 = uncanny eye sclera/pupil facing readout.
uniform float catch_glint : hint_range(0.0, 1.0) = 0.0;
uniform float top_bias_amount : hint_range(0.0, 1.0) = 0.42;
uniform float pallor_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool use_vertex_occlusion = true;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float facing = clamp(dot(n, v), 0.0, 1.0);
	float edge = pow(1.0 - facing, rim_power);
	vec3 moon_view = normalize(vec3(-0.44, 0.78, -0.34));
	float moon_side = mix(0.28, 1.0, smoothstep(-0.40, 0.68, dot(n, moon_view)));
	float up_bias = clamp(n.y * 0.65 + 0.42, 0.14, 1.0);
	float weight = mix(edge * moon_side, pow(facing, rim_power), catch_glint);
	float keep = mix(1.0, up_bias, top_bias_amount * (1.0 - catch_glint));
	float max_rim = mix(0.54, 0.85, catch_glint);
	float rim = clamp(weight * rim_strength * keep, 0.0, max_rim);
	vec3 lit = mix(core_color, rim_color, rim);
	if (pallor_strength > 0.001) {
		float moon_face = mix(0.35, 1.0, clamp(dot(n, normalize(vec3(-0.28, 0.45, 0.85))), 0.0, 1.0));
		vec3 bone_pallor = vec3(0.115, 0.132, 0.155) * pow(facing, 1.15) * moon_face;
		lit += bone_pallor * pallor_strength;
	}
	if (use_vertex_occlusion) {
		lit *= COLOR.rgb;
	}
	ALBEDO = lit;
}
