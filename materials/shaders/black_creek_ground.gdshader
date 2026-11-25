shader_type spatial;
render_mode diffuse_burley;

// Black Creek, Colorado — April 1890. The valley floor is spring-thawed clay,
// not sand: dark and slick where wagons cut it, pale where it has dried. Coal
// slag from the BC&W boilers is spread as ballast under the depot and MJ spur,
// and the adits above town leach ferric ochre ("yellow boy") toward the creek.
uniform sampler2D road_color : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D road_normal : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D road_rough : filter_nearest_mipmap, repeat_enable;
// Spring clay clumps for the ruts, and boiler cinders for the depot ballast.
uniform sampler2D clay_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D clay_normal : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D slag_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D slag_roughness : filter_nearest_mipmap, repeat_enable;

// Layout read from scripts/town/black_creek_rail_layout.gd and the street builder.
uniform float avenue_z = 23.1;
uniform float avenue_half_width = 6.9;
uniform float depot_approach_x = 0.0;
uniform float main_track_z = -18.0;
uniform float mj_spur_x = 21.0;
uniform float creek_x = 47.0;
uniform vec3 wet_clay_dark : source_color = vec3(0.150, 0.104, 0.068);
uniform vec3 wet_clay_lit : source_color = vec3(0.372, 0.268, 0.180);
uniform vec3 dry_clay : source_color = vec3(0.520, 0.404, 0.294);
uniform vec3 thaw_sod : source_color = vec3(0.208, 0.224, 0.128);
uniform vec3 slag_cinder : source_color = vec3(0.152, 0.143, 0.138);
uniform vec3 yellow_boy : source_color = vec3(0.325, 0.198, 0.088);
uniform vec3 granite_face : source_color = vec3(0.263, 0.253, 0.235);
uniform vec3 granite_shade : source_color = vec3(0.135, 0.130, 0.122);
uniform vec3 alpine_sod : source_color = vec3(0.164, 0.176, 0.106);
uniform vec3 alpine_scrub : source_color = vec3(0.212, 0.188, 0.128);

// The hillside mesh carries no usable UVs — its quads are metres wide and any
// planar projection smears into bands — so it samples the same CC0 surfaces
// triplanar from world space instead.
uniform bool triplanar_slope = false;
uniform float slope_scale = 0.21;
uniform sampler2D rock_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 cliff_warm : source_color = vec3(0.290, 0.239, 0.196);

varying vec3 world_pos;
varying vec3 world_up;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}

// Rotated octaves break up 2D lattice square patterns on flat valley ground.
float ground_noise(vec2 p) {
	vec2 q = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80)) * p;
	return value_noise(p) * 0.56 + value_noise(q * 2.13 + vec2(13.7, 5.1)) * 0.44;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Blend weights for the three world planes; square keeps the seams soft.
vec3 triplanar_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(w.x + w.y + w.z, 0.0001);
}

vec3 triplanar_albedo(sampler2D tex, vec3 p, vec3 w, float scale) {
	vec3 x = texture(tex, p.zy * scale).rgb;
	vec3 y = texture(tex, p.xz * scale).rgb;
	vec3 z = texture(tex, p.xy * scale).rgb;
	return x * w.x + y * w.y + z * w.z;
}

// A slope's own relief, not its UVs: contour strata from the world height so a
// metre-wide facet still reads as layered granite instead of a flat wash.
float strata(vec3 p, vec3 w, float scale) {
	float horizontal = value_noise(p.xz * scale * 0.5) * 0.6 + value_noise(vec2(p.y * 1.7, 0.0)) * 0.4;
	float side = value_noise(p.zy * scale * 0.5 + vec2(9.1)) * 0.6 + value_noise(vec2(p.y * 1.7, 3.0)) * 0.4;
	return mix(side, horizontal, w.y);
}

float slope_rock(vec3 p, vec3 w) {
	return smoothstep(0.55, 0.94, 1.0 - world_up.y) * (0.7 + 0.3 * ground_noise(p.xz * 0.8));
}

struct Surface {
	vec3 albedo;
	vec3 normal;
	float normal_depth;
	float roughness;
	float specular;
};

Surface ground_surface() {
	// Quantised world coordinates keep road and shoulders continuous on the two
	// separate valley boxes while matching the game's deliberately coarse grain.
	vec2 p = floor(world_pos.xz * 36.0) / 36.0;
	vec2 p_rot = mat2(vec2(0.86, -0.51), vec2(0.51, 0.86)) * p;
	float wear = ground_noise(p_rot * vec2(0.38, 0.62));
	float broken_edge = value_noise(p_rot * 0.94) - 0.5;
	float avenue_width = avenue_half_width + broken_edge * 2.2;
	float road = 1.0 - smoothstep(avenue_width - 0.65, avenue_width + 0.85, abs(p.y - avenue_z));
	road *= smoothstep(-64.0, -58.0, p.x);
	float approach_width = 2.8 + broken_edge * 1.4;
	float approach = (1.0 - smoothstep(approach_width, approach_width + 2.8, abs(p.x - depot_approach_x)))
		* smoothstep(1.8, 3.8, p.y) * (1.0 - smoothstep(23.0, 26.0, p.y));
	road = max(road, approach);

	// Four wagon ruts wander with the thaw; each holds water in its low spots.
	float drift = (value_noise(vec2(p.x * 0.13, 3.7)) - 0.5) * 0.85;
	float ruts = 0.0;
	for (int i = 0; i < 4; i++) {
		float lane = float(i) * 1.46 - 2.19;
		float groove = abs(p.y - avenue_z - lane - drift);
		ruts = max(ruts, (1.0 - smoothstep(0.09, 0.34, groove)) * (0.34 + 0.66 * wear));
	}
	float wet = smoothstep(0.44, 0.72, wear) * ruts * road;
	float pool = smoothstep(0.68, 0.83, value_noise(p * vec2(0.34, 2.0))) * ruts * road;

	// Coal slag ballast: the depot yard and the MJ spur are cindered, not dirt.
	float yard = 1.0 - smoothstep(4.4, 6.4, abs(p.y - main_track_z));
	float yard_end = 1.0 - smoothstep(52.0, 58.0, abs(p.x));
	float spur_lane = 1.0 - smoothstep(3.4, 5.2, abs(p.y - main_track_z - 8.4));
	float spur = spur_lane * (1.0 - smoothstep(0.4, 2.6, abs(p.x - mj_spur_x - 3.0)));
	float apron = (1.0 - smoothstep(5.2, 6.6, abs(p.x - 4.4)))
		* (1.0 - smoothstep(5.4, 6.8, abs(p.y + 10.2)));
	float ballast = clamp(max(max(yard * yard_end, spur), apron * 0.92), 0.0, 1.0);
	ballast *= 0.72 + 0.28 * smoothstep(0.28, 0.72, ground_noise(p * 3.1));

	// Ferric ochre ("yellow boy") where the adits above town drain into Black
	// Creek, plus the hand-cut trough run that carries the MJ seep east to the
	// water. Both are narrow, high-contrast stains — a mine creek in 1890 was
	// orange enough to be remarked on, not a faint tint.
	float to_creek = 1.0 - smoothstep(3.5, 13.5, abs(p.x - creek_x));
	float leach = to_creek * smoothstep(-44.0, -16.0, p.y) * (1.0 - smoothstep(34.0, 46.0, p.y));
	// The wooden trough from the MJ gate (x 21, z -26) downhill east to the bank.
	float along = clamp((p.x - 20.0) / 24.0, 0.0, 1.0);
	float trough_line = p.y - mix(-25.0, 6.0, along) - (value_noise(vec2(p.x * 0.7, 1.3)) - 0.5) * 1.4;
	float trough_run = (1.0 - smoothstep(0.5, 1.8, abs(trough_line)))
		* step(19.0, p.x) * (1.0 - smoothstep(creek_x - 3.0, creek_x - 0.4, p.x));
	float ochre = clamp(max(leach * smoothstep(0.46, 0.78, ground_noise(p * 1.7 + vec2(4.3))) * 0.78,
		trough_run * 0.72), 0.0, 1.0);

	vec2 uv = vec2(p.x, -p.y) * 0.41;
	vec2 clay_uv = p * 0.29;
	vec2 slag_uv = p * 0.74;
	float aggregate = texture(road_color, uv).r;
	float clay_grain = texture(clay_albedo, clay_uv).r;
	float slag_grain = texture(slag_albedo, slag_uv).r;

	// Wet clay holds the low ground; thawed sod and dry crust break it up.
	float thaw = smoothstep(0.33, 0.70, ground_noise(p * 0.52) + broken_edge * 0.3);
	vec3 clay = mix(wet_clay_dark, wet_clay_lit, 0.30 + wear * 0.52 + clay_grain * 0.20);
	clay = mix(clay, wet_clay_dark * 0.82, ruts * (0.26 + wet * 0.30));
	vec3 sod = mix(vec3(0.226, 0.166, 0.100), thaw_sod, thaw);
	vec3 soil = mix(sod, clay, road);
	vec3 crust = dry_clay * (0.82 + ground_noise(p * 1.35) * 0.22 + clay_grain * 0.22);
	soil = mix(soil, crust, (1.0 - road) * smoothstep(0.58, 0.92, 1.0 - wear) * 0.26);
	soil *= mix(0.88, 1.85, aggregate);

	vec3 cinder = slag_cinder * mix(0.70, 1.75, slag_grain);
	cinder = mix(cinder, vec3(0.196, 0.106, 0.070), smoothstep(0.72, 0.97, value_noise(p * 5.3)) * 0.55);
	soil = mix(soil, cinder, ballast);
	soil = mix(soil, yellow_boy * mix(0.68, 1.18, clay_grain), ochre * 0.62);

	soil *= 1.0 - pool * 0.36;

	// Normals come from whichever surface owns the pixel.
	vec3 road_n = texture(road_normal, uv).rgb;
	vec3 clay_n = texture(clay_normal, clay_uv).rgb;
	vec3 ballast_n = normalize(mix(road_n, clay_n, 0.5));
	vec3 surf_n = mix(mix(road_n, clay_n, road * 0.8), ballast_n, ballast);
	// Ochre silt is a smooth skin over the grain, so it softens the map.
	surf_n = normalize(mix(surf_n, vec3(0.5, 0.5, 1.0), ochre * 0.45));
	float rough = mix(texture(road_rough, uv).r, texture(slag_roughness, slag_uv).r, ballast);
	// Damp winter ruts stay dark earthy mud without sky-blue mirror stripes.
	rough = mix(rough, mix(0.78, 0.56, wet), max(pool, wet * 0.74));
	rough = mix(rough, 0.44, pool);
	Surface surf;
	surf.albedo = max(vec3(0.014), soil);
	surf.normal = surf_n;
	surf.normal_depth = mix(mix(0.74, 0.30, road), 0.52, ballast) * mix(1.0, 0.32, pool);
	surf.roughness = rough;
	surf.specular = mix(0.18, 0.28, max(pool, wet * 0.5));
	return surf;
}

// Canyon wall and terrace pass: same CC0 surfaces, sampled triplanar so a
// 2 m quad never shows a 20 m smear. Snow, scrub and granite are mixed by
// altitude and slope, matching the valley's own April snow line.
Surface slope_surface() {
	vec3 nrm = normalize(world_up);
	vec3 w = triplanar_weights(nrm);
	vec3 p = world_pos;
	float upness = clamp(nrm.y, -1.0, 1.0);
	float slope = 1.0 - abs(upness);
	float grain = ground_noise(p.xz * 0.31);
	float detail = strata(p, w, slope_scale * 4.0);

	vec3 rock = triplanar_albedo(rock_albedo, p, w, slope_scale).rgb;
	vec3 soil = triplanar_albedo(dirt_albedo, p, w, slope_scale * 0.72).rgb;
	// Local granite is warm grey; the CC0 stone reads cold under the valley light.
	rock = mix(rock, rock * cliff_warm * 2.1, 0.45);
	soil = mix(soil, soil * vec3(1.22, 0.98, 0.76) * 1.35, 0.5);

	// Altitude bands: thawed sod, scrub, bare rock, then the April snow line.
	float alt = clamp((p.y - 2.0) / 34.0, 0.0, 1.0);
	float rockiness = clamp(slope * 1.9 + (detail - 0.5) * 0.55, 0.0, 1.0);
	float snow = smoothstep(0.62, 0.93, alt + (detail - 0.5) * 0.22 - slope * 0.24);
	float sod = (1.0 - rockiness) * (1.0 - smoothstep(0.30, 0.58, alt));
	// Patches of leached yellow clay survive on the moderate faces below the rim.
	float leach = smoothstep(0.30, 0.16, alt) * smoothstep(0.55, 0.30, slope)
		* smoothstep(0.46, 0.74, grain);

	vec3 albedo = mix(soil, rock, rockiness);
	albedo = mix(albedo, mix(alpine_sod, alpine_scrub, detail), sod * 0.72);
	albedo = mix(albedo, mix(granite_shade, granite_face, detail) * 1.55, snow * 0.9);
	albedo = mix(albedo, yellow_boy * 0.72 * (0.8 + detail * 0.4), leach * 0.30);
	// The pale wash that read as a hole was an unlit flat facet: give every face
	// at least a thin layer of grain so no plate is ever a single flat colour.
	albedo *= mix(0.86, 1.20, detail);

	// Slopes carry their own normal already; a light bump keeps the facets alive.
	Surface surf;
	surf.albedo = max(vec3(0.016), albedo);
	surf.normal = normalize(mix(vec3(0.5, 0.5, 1.0), vec3(0.5 + (grain - 0.5) * 0.6, 0.5 + (detail - 0.5) * 0.6, 1.0), 0.6));
	surf.normal_depth = mix(0.55, 0.20, snow);
	surf.roughness = mix(mix(0.94, 0.86, snow), 0.72, leach * 0.5);
	surf.specular = 0.18;
	return surf;
}

void fragment() {
	Surface s = triplanar_slope ? slope_surface() : ground_surface();
	ALBEDO = s.albedo;
	NORMAL_MAP = s.normal;
	NORMAL_MAP_DEPTH = s.normal_depth;
	ROUGHNESS = s.roughness;
	SPECULAR = s.specular;
}
