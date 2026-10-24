// The water standing in one of her cells (InnerWater): the sea's own colours, lit as
// an indoor face of the ship is (ship.gdshaderinc) — by the room's lamps and a little
// of the sky's ambient, never the sun — so a dark room's water stays dark but for the
// lamps' glints on its wobbling surface. Through it, what lies under it — the planks of
// a floor, a stair, a body — wavering with the surface and dimmed by the water on the
// way up (water_optics.gdshaderinc): clear under a film of water, green and then lost
// in the sea's own colour a couple of metres down; and, the more the lower the eye
// looks across it, the room mirrored in it — its walls, its lamps, its doorways, where
// a ray off it meets them on the screen, else the lit room's tone — so a grazing eye
// reads water, not a shadow on the floor. Where it meets a wall, a body or anything
// standing in it, the sea's lap of foam and lace, and rings spreading round a body
// wading or swimming in it (wader_rings.gdshaderinc). Its foam is white water: lit by a
// warm lamp it stays pale, not the lamp's hue. Seen from under it, a dim grey ceiling,
// silvered where it meets a wall and as the eye looks low along it, not the lamps' hue.
// Its sheet is level with the world, turned against her lean (CellSurface), and drawn
// only inside its cell's box, in ship metres: so it piles into the box's low corner and
// never pokes through a deck, a wall or her side. Under a pocket (SH29) it glows
// faintly, the sea's light coming up through it, the only light a sealed space under
// water has. On an open well's deck, under the sky, the sun and the sky's whole ambient
// light it instead.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

#include "res://scenes/art/wader_rings.gdshaderinc"
#include "res://scenes/art/water_optics.gdshaderinc"

uniform vec4 deep_colour : source_color = vec4(0.09, 0.27, 0.42, 1.0);
uniform vec4 shallow_colour : source_color = vec4(0.1, 0.46, 0.53, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.97, 1.0, 0.99, 1.0);
// How much of each colour of light a metre of it takes out — murkier than the open
// sea's (water.gdshader), churned up as it is inside her — and how far what lies under
// it is thrown aside by the wobble, per metre it lies under the surface and per unit of
// slope.
uniform vec3 absorption = vec3(1.4, 0.75, 0.55);
uniform float refraction = 0.3;
// How far up and down the screen its ripples draw a mirrored image out, as a share of
// its height, and that much again for every ~7 metres the ray ran to meet it.
uniform float mirror_blur = 0.004;
// Metres under the surface that foam: a frayed lap fading out over foam_depth, then
// faint lace a little deeper, at most lace_strength of white.
uniform float foam_depth = 0.15;
uniform float lace_depth = 0.25;
uniform float lace_strength = 0.3;
// The share of the sky's ambient light it keeps indoors, as the ship's indoor faces
// do, and the share of a lamp's light a surface turned from it still takes.
uniform float indoor_ambient = 0.35;
uniform float lamp_bounce = 0.35;
// How bright a lamp's glint on it is, and how tight.
uniform float glint = 0.9;
uniform float glint_tightness = 70.0;
// What a sheet seen low across it mirrors indoors where a ray off it meets nothing
// drawn: a lit room's tone, taken by the lamps as the walls are, so a dark room's water
// mirrors only darkness. How fast the mirror falls off as the eye looks down into it,
// and how much of what it mirrors the sheet takes at the most — more than Fresnel's law
// gives, so a dim room's water reads as water rather than a shadow on the floor.
uniform vec4 indoor_tone : source_color = vec4(0.72, 0.68, 0.6, 1.0);
uniform float mirror_falloff = 2.0;
uniform float mirror_strength = 0.8;
// The share of a churning sheet's boiling foam that lights itself, so it reads white
// even in a dim hold.
uniform float churn_glow = 0.45;
// How much of a lamp's hue its foam sheds, so under a warm lamp foam reads pale: 0 takes
// the lamp's colour as it is, 1 only its brightness.
uniform float foam_pale = 0.85;
// Seen from under it: the ceiling's dim grey-blue, how much of the lamps' hue it sheds,
// the silver it turns where it meets a wall within rim_width metres, how much of that
// silver lights itself, and how silvery it reads as the eye looks low along it.
uniform vec4 underside_colour : source_color = vec4(0.16, 0.2, 0.23, 1.0);
uniform float underside_pale = 0.8;
uniform vec4 rim_colour : source_color = vec4(0.82, 0.88, 0.9, 1.0);
uniform float rim_width = 0.18;
uniform float rim_glow = 0.35;
uniform float underside_sheen = 0.45;

// The world to her ship space, as drawn this frame (InnerWater), and the box this sheet's
// cell stands in there.
uniform mat4 world_to_ship = mat4(1.0);
uniform vec3 clip_low = vec3(0.0);
uniform vec3 clip_high = vec3(0.0);
uniform float pocket_glow = 0.0;
// 1 for an open well's water, under the open sky; 0 under a deck.
uniform float outdoor = 0.0;
// How hard it churns as the sea pours in and it climbs her, 0…1 (InnerWater.inflow):
// a rough wobble, broad bright streaks and white foam boiling up all over it. 0 is calm
// water.
uniform float inflow : hint_range(0.0, 1.0) = 0.0;

varying vec3 world;
// The share of the lamps' hue this fragment sheds (foam, the underside), and the calm
// wobble's normal its lamps' glints turn on, fragment to light.
varying float pale;
varying vec3 calm;

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

// Value noise eased by a quintic, so its contours bend smoothly across the cells' edges
// instead of kinking into polygons there.
float smooth_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// Two octaves of it, the second turned and offset, so no cell's outline lines up with
// the next and none closes.
float soft_noise(vec2 p) {
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	return smooth_noise(p) * 0.65 + smooth_noise(turn * p * 2.1 + 17.0) * 0.35;
}

// Foam's faint lace, 0…1: wide soft lines where two drifting soft noises cross, kept only
// in sparse drifting patches and thinned by a fine one — a blurred tracery of broken foam,
// never a web.
float soft_lace(vec2 p, float t, float width) {
	mat2 turn = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6));
	float a = soft_noise(p + vec2(t * 0.3, t * 0.2));
	float b = soft_noise(turn * p * 1.3 + vec2(-t * 0.25, t * 0.3) + 11.0);
	float net = 1.0 - smoothstep(0.0, width, abs(a - b));
	float pieces = smooth_noise(turn * p * 0.55 + vec2(-t * 0.12, t * 0.09) + 23.0);
	float thin = smooth_noise(p * 4.5 + vec2(t * 0.4, -t * 0.3) + 37.0);
	return net * net * smoothstep(0.5, 0.85, pieces + (thin - 0.5) * 0.3) * (0.3 + 0.7 * thin);
}

// A fine net of meandering lines where two drifting noises cross, 0…1 (water.gdshader).
float lace(vec2 p, float t, float width) {
	float a = value_noise(p + vec2(t * 0.3, t * 0.2));
	float b = value_noise(p * 1.5 + vec2(-t * 0.25, t * 0.3) + 11.0);
	return 1.0 - smoothstep(0.0, width, abs(a - b));
}

// Foam's lace, 0…1: the net broken by a coarser drifting noise into scattered pieces and
// frayed by a fine one, so no line closes into a crescent and no piece has a clean outline.
float broken_lace(vec2 p, float t, float width) {
	float net = lace(p, t, width);
	float pieces = value_noise(p * 0.8 + vec2(-t * 0.12, t * 0.09) + 23.0);
	float fray = value_noise(p * 9.0 + vec2(t * 0.4, -t * 0.3) + 37.0);
	return net * smoothstep(0.4, 0.75, pieces + (fray - 0.5) * 0.4) * (0.45 + 0.55 * fray);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ship = (world_to_ship * vec4(world, 1.0)).xyz;
	if (any(lessThan(ship, clip_low)) || any(greaterThan(ship, clip_high))) {
		discard;
	}
	float t = TIME;
	// A slow wobble of the surface: what turns a lamp's glint on it about.
	vec2 slope = vec2(
		value_noise(world.xz * 1.7 + vec2(t * 0.35, -t * 0.25)),
		value_noise(world.xz * 1.7 + vec2(-t * 0.3, t * 0.4) + 7.0)
	) - 0.5;
	slope += (vec2(
		value_noise(world.xz * 5.3 + vec2(-t * 0.8, t * 0.6) + 3.0),
		value_noise(world.xz * 5.3 + vec2(t * 0.7, t * 0.5) + 13.0)
	) - 0.5) * 0.5;
	float wobble = 0.35 + 1.8 * inflow;
	vec3 up = normalize(vec3(-slope.x * wobble, 1.0, -slope.y * wobble));
	NORMAL = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz) * (FRONT_FACING ? 1.0 : -1.0);
	// The mirror, the underside's sheen and the lamps' glints follow the calm wobble
	// only: the churn's steep slopes would turn them into hard crescents of the lamps'
	// and the room's hue.
	calm = normalize(vec3(-slope.x * 0.35, 1.0, -slope.y * 0.35));
	calm = normalize((VIEW_MATRIX * vec4(calm, 0.0)).xyz) * (FRONT_FACING ? 1.0 : -1.0);
	float grazing = 1.0 - abs(dot(calm, VIEW));
	AO = mix(indoor_ambient, 1.0, outdoor);
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 1.0;
	vec3 view = water_drawn_at(SCREEN_UV, INV_PROJECTION_MATRIX);
	if (!FRONT_FACING) {
		// Seen from under it: a dim grey ceiling, silvered where it meets a wall — what
		// is behind it lies within rim_width of it — and as the eye looks low along it,
		// the light it turns back down, not the lamps' hue.
		float gap = max(VERTEX.z - view.z, 0.0);
		float rim = 1.0 - smoothstep(0.0, rim_width, gap);
		float sheen = pow(grazing, mirror_falloff) * underside_sheen;
		float silver = max(rim, sheen);
		ALBEDO = mix(underside_colour.rgb, rim_colour.rgb, silver);
		ALPHA = mix(0.85, 0.95, rim);
		EMISSION = shallow_colour.rgb * pocket_glow + rim_colour.rgb * rim * rim_glow;
		pale = mix(underside_pale, 1.0, silver);
	} else {
		vec3 behind = (INV_VIEW_MATRIX * vec4(view, 1.0)).xyz;
		// Vertical metres from the surface down to what is behind it; a depth sample
		// nearer than the surface is the rim of something in front of it.
		bool rim = view.z > VERTEX.z + 0.1;
		float below = rim ? 1e3 : max(world.y - behind.y, 0.0);
		// What lies under it — the floor, a stair, a body — thrown aside by the wobble,
		// the further the deeper it lies, and dimmed by the water between it and the eye:
		// clear under a film of water, green a little deeper, lost in the sea's own colour
		// a couple of metres down. Looked up where it is drawn once thrown, unless what is
		// drawn there stands in front of the surface.
		vec3 through = vec3(0.0);
		vec3 under = vec3(0.0);
		if (below < 6.0) {
			vec3 thrown = behind + vec3(slope.x, 0.0, slope.y) * wobble * min(below, 1.5)
				* refraction;
			vec2 uv = water_screen_uv((VIEW_MATRIX * vec4(thrown, 1.0)).xyz, PROJECTION_MATRIX);
			vec3 there = water_drawn_at(uv, INV_PROJECTION_MATRIX);
			bool off_screen = any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)));
			if (off_screen || there.z > VERTEX.z - 0.02) {
				uv = SCREEN_UV;
				there = view;
			}
			through = exp(-absorption * distance(there, VERTEX));
			under = water_screen(uv);
		}
		// What it mirrors, as much as Fresnel's law gives at the calm wobble — indoors, at
		// least as much as the mirror's own falloff — what a ray off it meets over the
		// water, drawn out a little up and down the screen as rippled water draws it;
		// meeting nothing drawn, indoors, the lit room's tone, taken by the lamps as the
		// walls are, so a dark room's water mirrors only darkness. Looked for only where
		// the surface mirrors enough of it to see.
		float sheen = pow(grazing, mirror_falloff) * mirror_strength * (1.0 - outdoor);
		float mirroring = max(water_fresnel(1.0 - grazing), sheen);
		vec4 found = vec4(0.0);
		vec3 image = vec3(0.0);
		if (water_mirror > 0 && mirroring > MIRROR_SEEN) {
			found = water_mirror_trace(
				VERTEX, reflect(-VIEW, calm), water_mirror, 0.1 + length(VERTEX) * 0.02,
				world.y - 0.05, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX
			);
			found.z *= smoothstep(MIRROR_SEEN, MIRROR_SEEN * 2.0, mirroring);
			if (found.z > 0.0) {
				vec2 drawn_out = vec2(0.0, mirror_blur * (1.0 + found.w * 0.15));
				image = water_screen(found.xy) * 0.5;
				image += water_screen(found.xy + drawn_out) * 0.25;
				image += water_screen(found.xy - drawn_out) * 0.25;
			}
		}
		// Lit by the room: the water's own colour where what lies under it is lost, and
		// the room's tone where the mirror meets nothing drawn. Lit already, and so
		// given off as it is: what lies under it and what the mirror meets.
		vec3 colour = deep_colour.rgb * (vec3(1.0) - through) * (1.0 - mirroring);
		colour += indoor_tone.rgb * mirroring * (1.0 - found.z) * (1.0 - outdoor);
		vec3 shown = under * through * (1.0 - mirroring) + image * mirroring * found.z;
		// Drifting streaks on it, a little lighter and broken: water, not a painted floor.
		float streak = broken_lace(world.xz * 0.9, t * 0.15, 0.03 + 0.06 * inflow);
		float streaking = streak * (0.25 + 0.9 * inflow);
		colour = mix(colour, shallow_colour.rgb * 1.25, streaking);
		shown *= 1.0 - streaking;
		// Foam boiling up all over it while the sea pours in; none on calm water.
		float boiling = 0.0;
		if (inflow > 0.0) {
			float boil = value_noise(world.xz * 3.0 + t * vec2(1.2, -0.9));
			boil = mix(boil, value_noise(world.xz * 7.0 + t * vec2(-1.6, 1.3) + 5.0), 0.35);
			boiling = smoothstep(0.75 - 0.3 * inflow, 0.95, boil) * inflow;
			colour = mix(colour, foam_colour.rgb, boiling);
		}
		float foamed = boiling;
		if (below <= lace_depth) {
			// The lap where it meets a wall: a wide band fading out from the wall, its
			// reach swelling and shrinking and its edge frayed by noise, never a drawn line.
			float lap = value_noise(world.xz * 2.4 + vec2(t * 0.6, -t * 0.4));
			float fray = soft_noise(world.xz * 6.0 + vec2(-t * 0.5, t * 0.35) + 41.0);
			float reach = 1.0 - below / (foam_depth * (0.6 + 0.8 * lap));
			float edge = smoothstep(0.0, 0.9, reach + (fray - 0.5) * 0.8) * (0.55 + 0.3 * fray);
			float shallows = clamp(1.0 - below / lace_depth, 0.0, 1.0);
			float lacing = soft_lace(world.xz * 2.2, t, 0.14) * lace_strength * shallows;
			float foam = max(edge, lacing);
			colour = mix(colour, foam_colour.rgb, foam);
			foamed = max(foamed, foam);
		}
		// Rings spreading round the bodies wading or swimming in it.
		if (wader_count > 0) {
			float rings = wader_rings(world, t);
			colour = mix(colour, foam_colour.rgb, rings);
			foamed = max(foamed, rings);
		}
		ALBEDO = colour;
		// Its foam, white water, sheds the lamps' hue: pale under a warm lamp.
		pale = foamed * foam_pale;
		ALPHA = 1.0;
		EMISSION = shown * (1.0 - foamed);
		// Brighter along the drifting streaks, as light through a moving surface is.
		EMISSION += shallow_colour.rgb * pocket_glow * (0.6 + 0.8 * streak);
		// Its boiling foam lights itself in part, white in a dim hold.
		EMISSION += foam_colour.rgb * boiling * churn_glow;
	}
}

void light() {
	// Lamps only, as an indoor face (ship.gdshaderinc): the sun never reaches it — but
	// for an open well's, which the sun lights and no lamp does.
	// Foam and the underside shed the lamp's hue and keep its brightness.
	vec3 tone = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.299, 0.587, 0.114))), pale);
	float facing = dot(NORMAL, LIGHT);
	float sunlit = LIGHT_IS_DIRECTIONAL ? outdoor : 1.0 - outdoor;
	float lit = mix(lamp_bounce, 1.0, smoothstep(-0.2, 0.55, facing)) * sunlit;
	DIFFUSE_LIGHT += tone * ATTENUATION * lit / PI;
	float shine = pow(max(dot(reflect(-LIGHT, calm), VIEW), 0.0), glint_tightness);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * smoothstep(0.35, 0.6, shine) * glint * sunlit;
}
