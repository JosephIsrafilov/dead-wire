shader_type spatial;
// A paraffin flame: anchored at the wick, tapering to a tip that sways a
// little, blue at the root, yellow in the body, orange at the tip. The mesh
// is a sphere centred on the node; the vertex stage lifts it so the node is
// the wick, which makes LampLife's height scaling grow the flame upward.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float half_height = 0.028;
uniform float sway = 0.0035;
uniform float sway_hz = 0.9;
uniform vec3 root_color : source_color = vec3(0.18, 0.22, 0.55);
uniform vec3 body_color : source_color = vec3(1.0, 0.86, 0.5);
uniform vec3 tip_color : source_color = vec3(1.0, 0.5, 0.16);
uniform float brightness = 1.6;

varying float height01;
varying float rim;

void vertex() {
	float h = clamp((VERTEX.y + half_height) / (2.0 * half_height), 0.0, 1.0);
	height01 = h;
	VERTEX.y += half_height;
	VERTEX.xz *= mix(1.0, 0.25, smoothstep(0.35, 1.0, h));
	float t = TIME * sway_hz * 6.2831;
	float bend = h * h;
	VERTEX.x += (sin(t) * 0.6 + sin(t * 2.31 + 1.3) * 0.4) * sway * bend;
	VERTEX.z += (sin(t * 1.37 + 0.7) * 0.5) * sway * bend;
}

void fragment() {
	vec3 color = mix(root_color, body_color, smoothstep(0.02, 0.28, height01));
	color = mix(color, tip_color, smoothstep(0.62, 1.0, height01));
	// Soft edge: the silhouette fades instead of reading as a hard bulb.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fade = smoothstep(0.0, 0.55, facing) * (1.0 - smoothstep(0.85, 1.0, height01) * 0.6);
	ALBEDO = color * brightness * fade;
}
