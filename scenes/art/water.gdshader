// The sea, drawn on the world plane y = 0 out to the horizon (SeaAndSky), and the
// water inside her, each cell's at its own level (InnerWater, D7) — the sea leaves
// out her cells' boxes, where theirs is drawn instead. Its ripple (sea_ripple.gdshaderinc) averages to
// the plane, so the drawn waterline never strays from the one the sim tests; the
// swell is shading only. Colour comes from how far below the surface the opaque
// scene lies: lacy foam where the hull, a flooded deck or a body cuts the plane,
// see-through shallows over a drowned deck, open sea everywhere else. The open sea
// is deep blue underfoot and takes the dusk sky (dusk.gdshaderinc) toward the
// horizon, with a glint toward the sun, swell at three scales and sparse whitecaps
// that fade with distance, and hazes into exactly the sky's horizon; in a room of
// the ship, under a ceiling, it takes none of the sky, glint or whitecaps. Seen from
// under it, it is a bright wobbling ceiling. No screen-texture refraction.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

#include "res://scenes/art/sea_ripple.gdshaderinc"
#include "res://scenes/art/dusk.gdshaderinc"

uniform vec4 deep_colour : source_color = vec4(0.09, 0.27, 0.42, 1.0);
uniform vec4 shallow_colour : source_color = vec4(0.1, 0.46, 0.53, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.97, 1.0, 0.99, 1.0);
uniform vec4 streak_colour : source_color = vec4(0.27, 0.53, 0.66, 1.0);
uniform vec4 glint_colour : source_color = vec4(1.0, 0.95, 0.82, 1.0);
// Metres of water over which a drowned surface fades from seen to hidden.
uniform float clear_depth = 1.3;
// How much of a surface just under the water still shows through.
uniform float shallow_alpha = 0.5;
uniform float murk_steps = 3.0;
// Metres below the surface that foam: a solid edge, then lace a little deeper.
uniform float foam_depth = 0.035;
uniform float lace_depth = 0.2;
// Foam is brighter than white, so it stays white through the tonemap.
uniform float foam_glow = 1.3;
// Size of the drifting streak pattern, per metre.
uniform float streak_scale = 0.28;
uniform float streak_width = 0.022;
uniform float patch_scale = 0.035;
// Toward the sun (SeaAndSky sets it from the scene's light).
uniform vec3 sun_direction = vec3(0.44, 0.53, 0.73);
// How much the open sea mirrors the sky at a grazing look, and how steep its swell.
uniform float sky_reflection = 0.85;
uniform float swell_slope = 0.16;
// Metres over which the swell's detail, the streaks and the whitecaps fade out; and
// the share of that reach the graphics preset draws them to (SeaAndSky), fading out
// as much sooner. Past where they have faded, none of them is worked out at all.
uniform float detail_reach = 150.0;
uniform float fine_share = 1.0;
// Metres over which the sea hazes into the horizon.
uniform float haze_begin = 16.0;
uniform float haze_end = 650.0;
// The bow's churn (SeaAndSky): where, which way the stem runs (the ship's x on the
// sea, a unit vector), how far along it and across it, and how hard (0…1).
uniform vec2 churn_centre = vec2(0.0);
uniform vec2 churn_axis = vec2(1.0, 0.0);
uniform float churn_radius = 7.0;
uniform float churn_breadth = 0.45;
uniform float churn = 0.0;
// The ship's rooms seen from above (SeaAndSky.room_map): the lowest floor and the
// highest ceiling over each cell, ship metres; how far inside a room each cell's
// middle stands, read between them so a wall runs where it stands
// (SeaAndSky.room_edges); and from the world to those maps, x and z to their UV and y
// to the ship's height. The sea in a room is under a ceiling and takes no sky, glint
// or whitecap.
uniform sampler2D rooms : hint_default_black, filter_nearest, repeat_disable;
uniform sampler2D room_edges : hint_default_black, filter_linear, repeat_disable;
uniform mat4 world_to_rooms = mat4(1.0);
// The boxes of her cells whose water is drawn as their own (InnerWater.boxes), ship
// metres, with the box round them all; and from the world to her ship space. The sea
// draws nothing inside one. A cell's own water is indoors: under a deck, it takes no
// sky, glint or whitecap.
uniform mat4 world_to_ship = mat4(1.0);
uniform vec4 cell_low[16];
uniform vec4 cell_high[16];
uniform int cell_count = 0;
uniform vec3 cells_low = vec3(0.0);
uniform vec3 cells_high = vec3(0.0);
uniform bool indoors = false;
// From under the sea: the sky through the surface overhead, the sea mirrored by it
// at a slant, and the fog the view under the sea has (Underwater sets it).
uniform vec4 window_colour : source_color = vec4(0.58, 0.86, 0.8, 1.0);
uniform vec4 mirror_colour : source_color = vec4(0.07, 0.3, 0.34, 1.0);
uniform vec4 under_fog_colour : source_color = vec4(0.03, 0.17, 0.26, 1.0);
uniform float under_fog_end = 7.0;
uniform float under_fog_curve = 1.0;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// One train of swell: xy its slope along x and z, z its height, all scaled by
// [amp]; [dir] its heading, [k] its wavenumber.
vec3 swell(vec2 xz, vec2 dir, float k, float amp, float phase) {
	float at = dot(xz, dir) * k + phase;
	return vec3(dir * cos(at), sin(at)) * amp;
}

// Lace: a fine net of meandering lines where two drifting noises cross, 0…1.
float lace(vec2 p, float t, float width) {
	float a = value_noise(p + vec2(t * 0.3, t * 0.2));
	float b = value_noise(p * 1.5 + vec2(-t * 0.25, t * 0.3) + 11.0);
	return 1.0 - smoothstep(0.0, width, abs(a - b));
}

void vertex() {
	vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Calm toward the fine grid's edge, so the skirt beyond it meets it seamlessly.
	float edge = max(abs(VERTEX.x), abs(VERTEX.z));
	VERTEX.y += sea_ripple(at.xz, TIME) * (1.0 - smoothstep(80.0, 115.0, edge));
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 ceiling(float t, vec3 look, float dist) {
	// Snell's window: the sky shows straight up, the sea mirrors itself at a slant.
	float window = smoothstep(0.62, 0.74, look.y);
	float wobble = value_noise(world.xz * 0.7 + vec2(t * 0.25, -t * 0.2)) * 0.6;
	wobble += value_noise(world.xz * 2.1 + vec2(-t * 0.4, t * 0.3) + 5.0) * 0.4;
	vec3 colour = mix(mirror_colour.rgb, window_colour.rgb, window);
	colour *= 0.8 + 0.4 * smoothstep(0.45, 0.6, wobble);
	float fog = pow(clamp(dist / under_fog_end, 0.0, 1.0), under_fog_curve);
	return mix(colour, under_fog_colour.rgb, fog);
}

// Whether the world point [at] lies in one of her cells' boxes.
bool in_cells(vec3 at) {
	vec3 ship = (world_to_ship * vec4(at, 1.0)).xyz;
	if (any(lessThan(ship, cells_low)) || any(greaterThan(ship, cells_high))) {
		return false;
	}
	for (int i = 0; i < 16; i++) {
		if (i >= cell_count) {
			break;
		}
		if (all(greaterThan(ship, cell_low[i].xyz)) && all(lessThan(ship, cell_high[i].xyz))) {
			return true;
		}
	}
	return false;
}

void fragment() {
	if (cell_count > 0 && in_cells(world)) {
		discard;
	}
	float t = TIME * SEA_RIPPLE_SPEED;
	vec3 to_frag = world - CAMERA_POSITION_WORLD;
	float dist = length(to_frag);
	vec3 look = to_frag / max(dist, 1e-4);
	if (!FRONT_FACING) {
		ALBEDO = ceiling(t, look, dist);
		ALPHA = 1.0;
	} else {
		float depth = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view.xyz /= view.w;
		vec3 behind = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
		// Vertical metres from this point of the surface down to whatever is behind
		// it; nothing drawn behind it is open sea, however near the far plane. A depth
		// sample nearer than the surface is the rim of something in front of it, read
		// between the samples of a view drawn at a lower render scale: open sea too,
		// not a waterline to foam along.
		bool rim = view.z > VERTEX.z + 0.1;
		float below = depth > 0.99999 || rim ? 1e3 : max(world.y - behind.y, 0.0);
		float fine_reach = detail_reach * fine_share;
		float detail = 1.0 - smoothstep(fine_reach * 0.3, fine_reach, dist);
		vec3 on_map = (world_to_rooms * vec4(world, 1.0)).xyz;
		vec2 room = texture(rooms, on_map.xz).rg;
		bool in_room = texture(room_edges, on_map.xz).r > 0.0;
		float sky_over = indoors || in_room && on_map.y > room.r && on_map.y < room.g ? 0.0 : 1.0;
		float middle = mix(0.4, 1.0, 1.0 - smoothstep(detail_reach * 0.3, detail_reach, dist));
		middle *= 1.0 - smoothstep(detail_reach, detail_reach * 2.7, dist);

		// Swell at three scales, the finest fading first and the middle gone by a few
		// hundred metres, as a tilt of the normal: nothing finer than a pixel shimmers.
		vec3 s = swell(world.xz, vec2(0.83, 0.56), 0.22, 1.0, t * 0.9);
		s += swell(world.xz, vec2(-0.45, 0.89), 0.61, 0.55, t * 1.4) * middle;
		s += swell(world.xz, vec2(0.96, -0.28), 1.7, 0.3 * detail, t * 2.2);
		vec3 normal = normalize(vec3(-s.x * swell_slope, 1.0, -s.y * swell_slope));

		// The open sea: deep underfoot, the sky mirrored at a slant, lighter where
		// the swell faces the sun, in a few flat steps like the rest of the toon look.
		vec3 sun = normalize(sun_direction);
		vec3 mirrored = reflect(look, normal);
		mirrored.y = abs(mirrored.y);
		float fresnel = pow(1.0 - clamp(dot(-look, normal), 0.0, 1.0), 4.0);
		float facing = dot(normal, sun) - sun.y;
		float shade = floor(clamp(facing * 6.0, -1.0, 1.0) * 1.5 + 0.5) / 1.5;
		vec3 open = dusk_dim(deep_colour.rgb) * (1.0 + 0.12 * shade);
		float patch = value_noise(world.xz * patch_scale + vec2(t * 0.01, -t * 0.008));
		open *= mix(0.88, 1.08, patch);
		// Each detail below is worked out only where it shows, so the far sea costs
		// less than the near: past where it has faded it is left out, never faded.
		if (detail > 0.0) {
			vec2 drift = world.xz * streak_scale;
			float streak = lace(drift, t * 0.15, streak_width);
			streak = max(streak, lace(drift * 0.31 + 7.0, t * 0.1, streak_width * 0.7) * 0.7);
			open = mix(open, dusk_dim(streak_colour.rgb), streak * 0.1 * detail);
		}
		float mirroring = clamp(fresnel * sky_reflection, 0.0, 1.0) * sky_over;
		open = mix(open, dusk_sky(mirrored, sun), mirroring);

		// The glint: a soft path toward the sun, sparkling in flat dashes a few pixels
		// long — where a pixel spans a few centimetres of sea (about a milliradian a
		// pixel, seen at a slant), not so near that a dash is a flake, nor so far that
		// it is salt.
		float toward = max(dot(mirrored, sun), 0.0);
		float footprint = dist * 0.001 / max(-look.y, 0.01);
		float sparkling = smoothstep(0.02, 0.04, footprint) * detail;
		sparkling *= 1.0 - smoothstep(0.06, 0.14, footprint);
		float glint = pow(toward, 40.0) * 0.5;
		if (sparkling > 0.0) {
			float sparkle = value_noise(world.xz * vec2(4.6, 10.2) + vec2(t * 1.8, -t * 1.2));
			glint += step(1.0 - pow(toward, 12.0) * 0.15, sparkle) * sparkling;
		}
		glint = clamp(glint, 0.0, 1.0) * (1.0 - gloom * 0.5) * sky_over;
		open = mix(open, dusk_dim(glint_colour.rgb), glint);

		// Whitecaps on the open sea only, never over a drowned deck's shallows.
		float deep = smoothstep(1.0, 1.4, below);

		// Sparse whitecaps: short crescents on the middle swell's crests where a slow
		// drifting gust lifts them, so each breaks and fades on its own. The gust bends
		// the crest line a little and widens the cap in its middle, tapering it to its
		// tips; a soft painted edge. Seen close they are spilling froth rather than
		// a painted swoosh: softer edged and tipped, fading behind the crest, broken up
		// inside, and smaller and fainter right by the eye.
		float whitecap = 0.0;
		if (detail * deep > 0.0) {
			vec2 crestwise = vec2(
				dot(world.xz, vec2(0.89, 0.45)), dot(world.xz, vec2(-0.45, 0.89))
			);
			float gust = value_noise(crestwise * vec2(0.45, 0.12) + vec2(t * 0.08, -t * 0.05));
			float bent = crestwise.y * 0.61 + t * 1.4 + (gust - 0.85) * 3.0;
			// 0 on a crest's top, ±0.5 down in the troughs either side.
			float across = fract(bent / 6.2832 + 0.25) - 0.5;
			float near = 1.0 - smoothstep(5.0, 45.0, dist);
			float width = (gust - 0.78) * 0.3 * mix(0.6, 1.0, smoothstep(1.5, 6.0, dist));
			whitecap = smoothstep(0.0, 0.015 + 0.012 * near, width - abs(across) * 2.0);
			// -1 at the cap's lip, 1 at its back: the back spills into broken froth.
			float behind_crest = clamp(across * 2.0 / max(width, 1e-3), -1.0, 1.0);
			float spilling = min(near * 1.5, 1.0) * smoothstep(-0.6, 0.6, behind_crest);
			float spill = value_noise(world.xz * vec2(4.0, 7.0) + vec2(t * 0.5, -t * 0.35));
			whitecap *= mix(1.0, smoothstep(0.3, 0.6, spill) * 0.8, spilling);
			// Its tips, where the gust that lifts it dies away, thin out into the sea.
			whitecap *= mix(1.0, smoothstep(0.004, 0.035, width), near);
			whitecap *= mix(0.5, 1.0, smoothstep(1.5, 5.0, dist)) * detail * deep;
		}

		// The bow's churn: foam streaming along the stem line on the open water round
		// where it meets the sea, ragged at its rim and finer toward it, thinning out
		// over a drowned deck along a broken line rather than cut along its edge, and
		// never over its see-through shallows.
		// Nothing churns until the bow goes down: no boil reaches the froth's threshold.
		if (churn > 0.0) {
			vec2 from = world.xz - churn_centre;
			vec2 stem = vec2(dot(from, churn_axis), dot(from, vec2(-churn_axis.y, churn_axis.x)));
			float reach = length(stem / vec2(churn_radius, churn_radius * churn_breadth));
			reach += (value_noise(world.xz * 0.7 + vec2(t * 0.1, 0.0)) - 0.5) * 0.8;
			float churned = churn * (1.0 - smoothstep(0.3, 1.0, reach));
			float boil = value_noise(stem * vec2(4.0, 8.0) + vec2(t * 0.7, -t * 0.5));
			float frothed = smoothstep(1.0 - churned * 0.22, 1.02 - churned * 0.22, boil);
			float streamed = lace(stem * vec2(2.4, 6.0), t * 2.0, 0.045) * churned * detail;
			float broken = (value_noise(world.xz * 0.9 + 3.0) - 0.5) * 0.8;
			float over_deep = smoothstep(0.95, 2.0, below + broken);
			whitecap = max(whitecap, max(frothed, streamed) * over_deep);
		}
		whitecap *= sky_over;
		open = mix(open, foam_colour.rgb * foam_glow, whitecap);

		// Stepped, so a drowning deck shows contour bands parallel to the waterline.
		float murk = floor(smoothstep(0.0, clear_depth, below) * murk_steps + 0.5) / murk_steps;
		vec3 colour = mix(shallow_colour.rgb, open, murk);
		float alpha = mix(shallow_alpha, 1.0, murk);

		// The waterline: a thin solid edge that laps in and out, then lace beyond it;
		// none deeper than either reaches.
		if (below <= max(foam_depth, lace_depth) && detail > 0.0) {
			float lap = value_noise(world.xz * 2.2 + vec2(t * 0.6, -t * 0.4));
			float edge = step(below, foam_depth * (0.45 + 0.55 * lap));
			float lacing = 0.09 * clamp(1.0 - below / lace_depth, 0.05, 1.0);
			float laced = lace(world.xz * 3.2, t, lacing);
			float foam = max(edge, laced * step(below, lace_depth)) * detail;
			colour = mix(colour, foam_colour.rgb * foam_glow, foam);
			alpha = max(alpha, foam * 0.92);
		}

		float haze = pow(smoothstep(haze_begin, haze_end, dist), 0.55);
		ALBEDO = mix(colour, dusk_sky(look, sun), haze);
		ALPHA = mix(alpha, 1.0, haze);
	}
}
