// The sea, drawn on the world plane y = 0 out to the horizon (SeaAndSky), and the
// water inside her, each cell's at its own level (InnerWater, D7) — the sea leaves
// out her cells' boxes, where theirs is drawn instead. Its ripple (sea_ripple.gdshaderinc)
// averages to the plane, so the drawn waterline never strays from the one the sim tests;
// the waves are shading only. A wind raises them: many trains of every length, each its
// own way off the wind and running as fast as deep water's waves of its length do, the
// finer ones roughened and calmed by drifting gusts; a train too fine for the pixels it
// would be drawn in is left out, and its slopes blur the mirror instead, so the far sea
// is smooth and nothing shimmers.
//
// It is lit as water is (water_optics.gdshaderinc): looking down into it, the eye sees
// the light the sea scatters back up and whatever lies under the surface — bent by the
// waves and dimmed and tinted by the water between, so a drowned deck shows a few
// metres down before the sea's blue swallows it; looking out across it, more and more
// of what it mirrors, by Fresnel's law: the dusk sky, and the ship or anything else
// drawn over the water where a ray off the surface meets it. The sun lays a path of
// glitter on it, smooth far off and breaking near the eye into points that flash and
// are gone; the crests glow green between the eye and a low sun; foam where the hull, a
// flooded deck or a body cuts the plane, rings spreading round the bodies wading or
// swimming in it (wader_rings.gdshaderinc), sparse whitecaps, and churn where the bow
// goes under; and it hazes into exactly the sky's horizon. In a room of the ship, under
// a ceiling, it takes no sky, sun or whitecaps. Seen from under it, it is a bright
// wobbling ceiling.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

#include "res://scenes/art/sea_ripple.gdshaderinc"
#include "res://scenes/art/dusk.gdshaderinc"
#include "res://scenes/art/wader_rings.gdshaderinc"
#include "res://scenes/art/water_optics.gdshaderinc"

// The sea's own colours, which the water in her cells takes too (InnerWater): the deep
// blue it scatters back up, the green of its shallows, and its foam. And the sun's
// glints on it.
uniform vec4 deep_colour : source_color = vec4(0.09, 0.27, 0.42, 1.0);
uniform vec4 shallow_colour : source_color = vec4(0.1, 0.46, 0.53, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.97, 1.0, 0.99, 1.0);
uniform vec4 glint_colour : source_color = vec4(1.0, 0.95, 0.82, 1.0);
// The green the crests take with a low sun behind them, and how much.
uniform vec4 crest_colour : source_color = vec4(0.16, 0.62, 0.55, 1.0);
uniform float crest_glow = 0.35;
// How much of each colour of light a metre of sea takes out (linear, per metre): red
// first, so what lies under it goes green, then blue, then is lost in the sea's own.
uniform vec3 absorption = vec3(0.9, 0.32, 0.2);
// How far a drowned surface seen through the waves is thrown aside, per metre it lies
// under the surface and per unit of the waves' slope.
uniform float refraction = 0.45;
// Foam is brighter than white, so it stays white through the tonemap.
uniform float foam_glow = 1.3;
// Metres below the surface that foam: a solid edge, then lace a little deeper.
uniform float foam_depth = 0.035;
uniform float lace_depth = 0.2;
// The wind the waves run before (world x and z, a unit vector), and the waves it raises:
// WAVES trains, the longest wave_length metres from crest to crest and each next one
// wave_shorten as long, turned off the wind by up to wave_spread radians — the shorter
// the further — each its own steepness (wave_steepness at the longest, rising to
// wave_steepness_fine at the finest: wave number times height).
uniform vec2 wind = vec2(0.83, 0.56);
uniform float wave_length = 40.0;
uniform float wave_shorten = 0.76;
uniform float wave_spread = 1.2;
uniform float wave_steepness = 0.06;
uniform float wave_steepness_fine = 0.14;
// The gusts that roughen and calm the finer waves in drifting patches: per metre, and
// how much rougher and calmer than the mean they make them.
uniform float gust_scale = 0.035;
uniform vec2 gust_range = vec2(0.45, 1.4);
// The mean square slope of the ripples finer than any train — what turns the sun's
// mirror image into a path of glitter — and how bright the sun's glints are.
uniform float ripple_slope = 0.02;
uniform float glint_strength = 1.0;
// The glitter near the eye: metres from the eye it reaches, and the share of the
// ripples' slope the smooth path keeps there, the rest flashing as points; the side of
// a facet that can flash, in metres; how often a facet turns, a second; the share of a
// facet that flashes; the most of the facets that flash at once, where the waves
// mirror the sun straight at the eye; how much narrower than the glints' path the
// facets flash in, so they gather on the faces of the waves turned just so; and how
// bright the brightest flash is.
uniform float glitter_reach = 100.0;
uniform float glint_near = 0.2;
uniform float glitter_cell = 0.05;
uniform float glitter_rate = 3.0;
uniform float glitter_dot = 0.3;
uniform float glitter_share = 0.2;
uniform float glitter_narrow = 0.35;
uniform float glitter_flash = 10.0;
// Metres over which the whitecaps, the waterline's lace and the rings fade out; and the
// share of that reach the graphics preset draws them to (SeaAndSky), fading out as much
// sooner. Past where they have faded, none of them is worked out at all.
uniform float detail_reach = 150.0;
uniform float fine_share = 1.0;
// Out past mirror_reach metres from the eye the sea mirrors the sky alone; nearer, as
// far as the graphics preset marches a ray off it (water_mirror).
uniform float mirror_reach = 90.0;
// How far up and down the screen the ripples draw a mirrored image out, as a share of
// its height, and that much again for every ~7 metres the ray ran to meet it.
uniform float mirror_blur = 0.004;
// Metres over which the sea hazes into the horizon.
uniform float haze_begin = 16.0;
uniform float haze_end = 650.0;
// Toward the sun (SeaAndSky sets it from the scene's light).
uniform vec3 sun_direction = vec3(0.44, 0.53, 0.73);
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
// to the ship's height. The sea in a room is under a ceiling and takes no sky, sun or
// whitecap.
uniform sampler2D rooms : hint_default_black, filter_nearest, repeat_disable;
uniform sampler2D room_edges : hint_default_black, filter_linear, repeat_disable;
uniform mat4 world_to_rooms = mat4(1.0);
// The boxes of her cells whose water is drawn as their own (InnerWater.boxes), ship
// metres, as many as she has (SeaAndSky.cell_mask): a texel of each box's low corner,
// then one of its high, in order along her from aft; with the box round them all; and
// from the world to her ship space. The sea draws nothing inside one. A cell's own water
// is indoors: under a deck, it takes no sky, sun or whitecap.
uniform mat4 world_to_ship = mat4(1.0);
uniform sampler2D cells : filter_nearest, repeat_disable;
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

const int WAVES = 16;
// Deep water's waves run at sqrt(g k) radians a second.
const float GRAVITY = 9.81;
// The train whose crests the whitecaps break on, and how many of the longest trains
// the mirror's image wavers on.
const int CAPPED = 3;
const int SWELL = 6;
// exp(sin x - 1), the shape of every train — peaked crests, broad troughs — averages
// this over a wave, and the square of its slope this.
const float SHAPE_MEAN = 0.4658;
const float SHAPE_SLOPE2 = 0.1076;

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

// Lace: a fine net of meandering lines where two drifting noises cross, 0…1.
float lace(vec2 p, float t, float width) {
	float a = value_noise(p + vec2(t * 0.3, t * 0.2));
	float b = value_noise(p * 1.5 + vec2(-t * 0.25, t * 0.3) + 11.0);
	return 1.0 - smoothstep(0.0, width, abs(a - b));
}

// Train [i] of the waves: its heading (a unit vector), wave number and steepness, and
// its phase at [xz] at [time] — its crest where the phase's sine is 1.
void wave_train(
	int i, vec2 xz, float time, out vec2 heading, out float k, out float steep, out float phase
) {
	float share = float(i) / float(WAVES - 1);
	float turn = (fract(float(i) * 0.618034 + 0.27) - 0.5) * 2.0 * wave_spread;
	turn *= mix(0.3, 1.0, share);
	heading = vec2(
		wind.x * cos(turn) - wind.y * sin(turn), wind.x * sin(turn) + wind.y * cos(turn)
	);
	float length_ = wave_length * pow(wave_shorten, float(i));
	k = TAU / length_;
	steep = mix(wave_steepness, wave_steepness_fine, share);
	phase = dot(heading, xz) * k - sqrt(GRAVITY * k) * time + float(i) * 2.39996;
}

// The sea's surface at [xz] at [time], a pixel spanning [footprint] metres of it there,
// its finer trains roughened by [gust]: xy its slope along x and z, z its height over its
// mean, in metres, and w the mean square slope of the trains too fine to draw there,
// left out of xy; and in [swell] the slope of the SWELL longest trains alone. A train is
// drawn while a wave of it spans eight pixels or more, and gone by four.
vec4 sea_waves(vec2 xz, float time, float footprint, float gust, out vec2 swell) {
	vec2 slope = vec2(0.0);
	float height = 0.0;
	float unseen = 0.0;
	swell = vec2(0.0);
	for (int i = 0; i < WAVES; i++) {
		vec2 heading;
		float k;
		float steep;
		float phase;
		wave_train(i, xz, time, heading, k, steep, phase);
		steep *= mix(1.0, gust, float(i) / float(WAVES - 1));
		float drawn = 1.0 - smoothstep(0.125, 0.25, footprint * k / TAU);
		float shape = exp(sin(phase) - 1.0);
		slope += heading * (steep * shape * cos(phase) * drawn);
		height += steep / k * (shape - SHAPE_MEAN) * drawn;
		unseen += steep * steep * SHAPE_SLOPE2 * (1.0 - drawn);
		if (i == SWELL - 1) {
			swell = slope;
		}
	}
	return vec4(slope, height, unseen);
}

// The glitter of the sun near the eye, 0…1: the surface as facets glitter_cell across,
// each a ripple too fine to draw — turned its own way, and turning again glitter_rate
// times a second, each on its own beat — flashing where it happens to mirror the sun at
// the eye: as often as [lobe] (0…1, the facets' share of their most) says the sea there
// does, most of them faintly and a few hard. Drawn on two sizes of facet, whichever
// spans a few pixels, so the points stay a pixel or two across at any distance.
float glitter_at(vec2 xz, float time, float lobe, float size) {
	vec2 at = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * xz / size;
	vec2 cell = floor(at);
	float seed = hash(cell + size * 31.0);
	float beat = floor(time * glitter_rate + seed * 9.0);
	float roll = hash(cell * 1.31 + vec2(beat * 0.618, beat * 1.7) + 3.0);
	vec2 spot = vec2(hash(cell + beat + 7.0), hash(cell.yx + beat + 13.0)) * 0.5 + 0.25;
	float point = 1.0 - smoothstep(glitter_dot * 0.4, glitter_dot * 0.5, length(fract(at) - spot));
	float hard = pow(hash(cell + vec2(beat * 2.3, 21.0)), 4.0);
	return step(1.0 - lobe * glitter_share, roll) * point * (0.15 + 0.85 * hard);
}

float glitter(vec2 xz, float time, float lobe, float footprint) {
	if (lobe < 0.02) {
		return 0.0;
	}
	// The facet size whose points span about two pixels here, between two octaves.
	float level = log2(max(footprint * 4.0 / glitter_cell, 1.0));
	float low = floor(level);
	float blend = level - low;
	float size = glitter_cell * exp2(low);
	float near = glitter_at(xz, time, lobe, size);
	float far = glitter_at(xz, time, lobe, size * 2.0);
	return mix(near, far, blend);
}

void vertex() {
	vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Calm toward the fine grid's edge, so the skirt beyond it meets it seamlessly.
	float edge = max(abs(VERTEX.x), abs(VERTEX.z));
	VERTEX.y += sea_ripple(at.xz, TIME) * (1.0 - smoothstep(80.0, 115.0, edge));
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 ceiling(float t, vec3 look, float dist, vec2 slope) {
	// Snell's window: the sky shows straight up, the sea mirrors itself at a slant —
	// the window's rim wobbling with the waves overhead.
	vec3 bent = normalize(look - vec3(slope.x, 0.0, slope.y) * 0.6);
	float window = smoothstep(0.62, 0.74, bent.y);
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
	for (int i = 0; i < cell_count; i++) {
		vec3 low = texelFetch(cells, ivec2(i * 2, 0), 0).xyz;
		// In order along her: no box further on starts aft of this point.
		if (low.x >= ship.x) {
			break;
		}
		vec3 high = texelFetch(cells, ivec2(i * 2 + 1, 0), 0).xyz;
		if (all(greaterThan(ship, low)) && all(lessThan(ship, high))) {
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
	// Metres of sea a pixel spans here, the long way across it: before any branch, as a
	// screen derivative must be.
	float footprint = max(length(dFdx(world.xz)), length(dFdy(world.xz)));
	float gust = mix(
		gust_range.x,
		gust_range.y,
		value_noise(world.xz * gust_scale + vec2(TIME * 0.012, -TIME * 0.009))
	);
	vec2 swell;
	vec4 sea = sea_waves(world.xz, TIME, footprint, gust, swell);
	vec3 normal = normalize(vec3(-sea.x, 1.0, -sea.y));
	if (!FRONT_FACING) {
		ALBEDO = ceiling(t, look, dist, sea.xy);
		ALPHA = 1.0;
	} else {
		vec3 sun = normalize(sun_direction);
		float fine_reach = detail_reach * fine_share;
		float detail = 1.0 - smoothstep(fine_reach * 0.3, fine_reach, dist);
		vec3 on_map = (world_to_rooms * vec4(world, 1.0)).xyz;
		vec2 room = texture(rooms, on_map.xz).rg;
		bool in_room = texture(room_edges, on_map.xz).r > 0.0;
		float sky_over = indoors || in_room && on_map.y > room.r && on_map.y < room.g ? 0.0 : 1.0;

		// What is drawn behind this point of the surface, and the vertical metres down to
		// it; nothing drawn behind it stands at the far plane, open sea. A depth sample
		// nearer than the surface is the rim of something in front of it, read between
		// the samples of a view drawn at a lower render scale: open sea too, not a
		// waterline to foam along.
		vec3 view = water_drawn_at(SCREEN_UV, INV_PROJECTION_MATRIX);
		bool open_sea = view.z > VERTEX.z + 0.1;
		vec3 behind = (INV_VIEW_MATRIX * vec4(view, 1.0)).xyz;
		float below = open_sea ? 1e3 : max(world.y - behind.y, 0.0);

		// The light the sea scatters back up: its deep blue, and on a crest between the eye
		// and a low sun, the green of the light through the wave.
		vec3 body = dusk_dim(deep_colour.rgb);
		vec2 toward_sun = normalize(sun.xz + vec2(1e-5));
		float backlit = pow(max(dot(normalize(look.xz + vec2(1e-5)), toward_sun), 0.0), 4.0);
		float crest = smoothstep(0.0, 0.25, sea.z) * backlit * sky_over;
		body = mix(body, dusk_dim(crest_colour.rgb), crest * crest_glow);

		// Under the surface: what lies there, as far as the light from it gets through.
		// The point drawn behind is thrown aside along the waves' slope, the further the
		// deeper it lies, and looked up where that is drawn — unless what is drawn there
		// stands in front of the surface, from which no light through it comes.
		vec3 under = body;
		if (below < 12.0) {
			vec3 thrown = behind + vec3(sea.x, 0.0, sea.y) * min(below, 2.5) * refraction;
			vec2 uv = water_screen_uv((VIEW_MATRIX * vec4(thrown, 1.0)).xyz, PROJECTION_MATRIX);
			vec3 there = water_drawn_at(uv, INV_PROJECTION_MATRIX);
			bool off_screen = any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)));
			if (off_screen || there.z > VERTEX.z - 0.02) {
				uv = SCREEN_UV;
				there = view;
			}
			vec3 through = exp(-absorption * distance(there, VERTEX));
			under = mix(body, water_screen(uv), through);
		}

		// What it mirrors: the dusk sky, or under a ceiling the dark; and where a ray off
		// the surface — off the swell only, so the image wavers rather than breaking up,
		// and drawn out a little up and down the screen as rippled water draws it — meets
		// what is drawn over the water, that: looked for only where the surface mirrors
		// enough of it to see.
		vec3 mirror = reflect(look, normal);
		mirror.y = abs(mirror.y);
		vec3 mirrored = mix(body * 0.4, dusk_sky(mirror, sun), sky_over);
		float facing = max(dot(normal, -look), 1e-3);
		float mirroring = water_fresnel(facing);
		if (water_mirror > 0 && dist < mirror_reach && mirroring > MIRROR_SEEN) {
			vec3 calm = normalize(vec3(-swell.x, 1.0, -swell.y));
			vec3 ray = reflect(look, calm);
			ray.y = abs(ray.y);
			vec4 found = water_mirror_trace(
				VERTEX, (VIEW_MATRIX * vec4(ray, 0.0)).xyz, water_mirror, 0.2 + dist * 0.02,
				world.y - 0.15, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX
			);
			float reach = 1.0 - smoothstep(mirror_reach * 0.6, mirror_reach, dist);
			reach *= smoothstep(MIRROR_SEEN, MIRROR_SEEN * 2.0, mirroring);
			if (found.z > 0.0) {
				vec2 drawn_out = vec2(0.0, mirror_blur * (1.0 + found.w * 0.15));
				vec3 image = water_screen(found.xy) * 0.5;
				image += water_screen(found.xy + drawn_out) * 0.25;
				image += water_screen(found.xy - drawn_out) * 0.25;
				mirrored = mix(mirrored, image, found.z * reach);
			}
		}
		vec3 colour = mix(under, mirrored, mirroring);

		// The sun's glints: its mirror image spread into a path by the slopes of every
		// wave too fine to draw here, smooth far off. Near the eye the ripples are each
		// their own facet: the smooth path narrows to the drawn waves' own highlights, and
		// the ripples flash as points across the rest of it.
		vec3 half_way = normalize(sun - look);
		float nh = max(dot(normal, half_way), 1e-3);
		float nh2 = nh * nh;
		float glittering = 1.0 - smoothstep(glitter_reach * 0.25, glitter_reach, dist);
		float spread = sea.w + ripple_slope * mix(1.0, glint_near, glittering);
		float lobe = exp((nh2 - 1.0) / (nh2 * spread)) / (PI * spread * nh2 * nh2);
		float glint = lobe * water_fresnel(dot(half_way, -look)) / (4.0 * facing);
		glint *= step(0.0, dot(normal, sun)) * glint_strength * sky_over;
		float facets = exp((nh2 - 1.0) / (nh2 * (sea.w + ripple_slope) * glitter_narrow));
		float sparkle = glitter(world.xz, TIME, facets, footprint);
		sparkle *= glittering * detail * sky_over * glitter_flash;
		colour += dusk_dim(glint_colour.rgb) * (glint + sparkle);

		// Whitecaps on the open sea only, never over a drowned deck's shallows.
		float deep = smoothstep(1.0, 1.4, below);

		// Sparse whitecaps: short crescents on the crests of one train where a slow
		// drifting gust lifts them, so each breaks and fades on its own. The gust bends
		// the crest line a little and widens the cap in its middle, tapering it to its
		// tips; a soft painted edge. Seen close they are spilling froth rather than
		// a painted swoosh: softer edged and tipped, fading behind the crest, broken up
		// inside, and smaller and fainter right by the eye. Out past the near water a
		// slow swell of size sets each cap wider or narrower than the next, its edge
		// softens with the distance, and the froth breaks it into patches, so the far
		// sea holds no row of matching crescents.
		float whitecap = 0.0;
		if (detail * deep > 0.0) {
			vec2 heading;
			float k;
			float steep;
			float phase;
			wave_train(CAPPED, world.xz, TIME, heading, k, steep, phase);
			vec2 crestwise = vec2(
				dot(world.xz, vec2(-heading.y, heading.x)), dot(world.xz, heading)
			);
			float gusting = value_noise(crestwise * vec2(0.45, 0.12) + vec2(t * 0.08, -t * 0.05));
			float bent = phase + (gusting - 0.85) * 3.0;
			// 0 on a crest's top, ±0.5 down in the troughs either side; above 0 ahead of it.
			float across = fract(bent / TAU + 0.25) - 0.5;
			float near = 1.0 - smoothstep(5.0, 45.0, dist);
			float far = smoothstep(45.0, 200.0, dist);
			// Each cap's size, from half to a little over its own; by the eye, its own.
			float size = mix(0.5, 1.2, value_noise(world.xz * 0.02));
			float width = (gusting - 0.78) * 0.3 * mix(0.6, 1.0, smoothstep(1.5, 6.0, dist));
			width *= mix(size, 1.0, near);
			float edge = 0.015 + 0.012 * near + 0.03 * far;
			whitecap = smoothstep(0.0, edge, width - abs(across) * 2.0);
			// -1 at the cap's lip, ahead, 1 at its back: the back spills into broken froth.
			float behind_crest = clamp(-across * 2.0 / max(width, 1e-3), -1.0, 1.0);
			float spilling = min(near * 1.5, 1.0) * smoothstep(-0.6, 0.6, behind_crest);
			float spill = value_noise(world.xz * vec2(4.0, 7.0) + vec2(t * 0.5, -t * 0.35));
			whitecap *= mix(1.0, smoothstep(0.3, 0.6, spill) * 0.8, spilling);
			// Away from the eye the same froth breaks a cap into patches.
			whitecap *= mix(1.0, smoothstep(0.25, 0.6, spill), 0.5 * (1.0 - near));
			// Its tips, where the gust that lifts it dies away, thin out into the sea.
			whitecap *= mix(1.0, smoothstep(0.004, 0.035, width), near);
			// Out past the near water a cap is no stroke at all but a few ragged patches
			// of foam: a soft band along the crest, straight rather than bent into a
			// crescent, where the gust lifts it, broken by froth riding with the wave
			// and drifting across it, so each patch gathers and fades over a few seconds
			// and no crescent's outline survives.
			float patchy = smoothstep(10.0, 20.0, dist);
			if (patchy > 0.0) {
				float straight = fract(phase / TAU + 0.25) - 0.5;
				float riding = phase / k;
				float clump = value_noise(
					vec2(crestwise.x * 0.8, riding * 1.1) + vec2(t * 0.11, -t * 0.07) + 17.0
				);
				float froth = clump * 0.7 + spill * 0.3;
				float lifted = smoothstep(0.7, 0.9, gusting);
				float band = 1.0 - smoothstep(0.02, 0.1, abs(straight));
				float patches = smoothstep(0.5, 0.75, froth) * band * lifted * 0.85;
				whitecap = mix(whitecap, patches, patchy);
			}
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
		colour = mix(colour, foam_colour.rgb * foam_glow, whitecap);

		// The waterline: a thin solid edge that laps in and out, then lace beyond it;
		// none deeper than either reaches.
		if (below <= max(foam_depth, lace_depth) && detail > 0.0) {
			float lap = value_noise(world.xz * 2.2 + vec2(t * 0.6, -t * 0.4));
			float edge = step(below, foam_depth * (0.45 + 0.55 * lap));
			float lacing = 0.09 * clamp(1.0 - below / lace_depth, 0.05, 1.0);
			float laced = lace(world.xz * 3.2, t, lacing);
			float foam = max(edge, laced * step(below, lace_depth)) * detail;
			colour = mix(colour, foam_colour.rgb * foam_glow, foam);
		}

		// Rings spreading round the bodies in it, only on the near water.
		if (wader_count > 0 && detail > 0.0) {
			float rings = wader_rings(world, TIME) * detail;
			colour = mix(colour, foam_colour.rgb * foam_glow, rings);
		}

		float haze = pow(smoothstep(haze_begin, haze_end, dist), 0.55);
		ALBEDO = mix(colour, dusk_sky(look, sun), haze);
		ALPHA = 1.0;
	}
}
