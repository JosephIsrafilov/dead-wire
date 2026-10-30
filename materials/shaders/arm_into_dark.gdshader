shader_type spatial;
// Overlay for the operator's own arm (plan 5.5): the sleeve falls into the dark
// toward the frame edge. The parts of the arm nearest the eye (shoulder and
// elbow, which the lamp never reaches) are darkened; the hand and cuff at the
// paper keep their own material untouched. Distances are from the camera.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

uniform float fade_near = 0.32;
uniform float fade_far = 0.62;
uniform float darkness : hint_range(0.0, 1.0) = 0.93;

void fragment() {
	float distance_to_eye = length(VERTEX);
	ALBEDO = vec3(0.0);
	ALPHA = darkness * (1.0 - smoothstep(fade_near, fade_far, distance_to_eye));
}
