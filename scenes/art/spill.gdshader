// Water pouring through an opening inside her (InnerWater): over a low wall's top or
// a threshold, through a doorway or a porthole, down a stair's hole. It leaves the
// higher water level and arcs out as it falls — out as the root of how far it has
// fallen, the way a jet thrown level falls — white streaks of air racing down it, a
// trickle a few wandering strands down the middle of its opening, a flood a solid
// white-edged sheet filling it, breaking up into drops toward a foot of froth where it
// meets the water under it, where the froth there (froth.gdshader) takes it. In the
// sea's colours, lit as the ship's faces are (ship.gdshaderinc): by the lamps of the
// room it falls into, and by the sun too where it pours in from outdoors, never glowing.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec4 water_colour : source_color = vec4(0.1, 0.46, 0.53, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.97, 1.0, 0.99, 1.0);
// Metres of the sheet: how wide and how far it falls, so its streaks keep their size.
uniform vec2 extent = vec2(1.0, 1.0);
// How hard it pours, 0…1: a trickle is a few narrow strands, a flood a solid sheet.
uniform float strength = 1.0;
// How far out of its opening it has gone by its foot, in the sheet's own units, along
// whichever of its own axes runs out of the opening.
uniform vec3 thrown = vec3(0.0);
// 1 where it pours in from under the open sky, which lights it too; 0 under a deck.
uniform float outdoor = 0.0;
uniform float fall_speed = 3.5;
// Brighter than the ship's indoor faces (ship.gdshaderinc): white water scatters the
// sky's ambient kept indoors, and a lamp's light through to the face turned from it.
uniform float indoor_ambient = 0.5;
uniform float lamp_bounce = 0.6;

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

void vertex() {
	// UV.y runs down it from where it leaves the higher water, out of its opening.
	VERTEX += thrown * sqrt(clamp(UV.y, 0.0, 1.0));
}

void fragment() {
	vec2 at = UV * extent;
	float t = TIME * fall_speed;
	// How far it has fallen, quickening as it falls, so whatever rides it scrolls down
	// faster toward its foot.
	float fallen = at.y + 0.5 * at.y * at.y;
	// A trickle falls down the middle of its opening, wandering from side to side; the
	// harder it pours, the more of the opening it fills, a flood all of it. Its sides
	// ragged, in metres in from them.
	float half_width = mix(0.38, 0.5, strength);
	float wander = (value_noise(vec2(fallen * 2.5 - t * 0.9, 1.7)) - 0.5) * 0.12 * (1.0 - strength);
	float side = (half_width - abs(UV.x - 0.5 - wander)) * extent.x;
	float edge = smoothstep(0.0, 0.03 + 0.08 * value_noise(vec2(fallen * 3.0 - t, at.x)), side);
	// Weakly it falls as strands with gaps between, thinning as it falls; a flood is one
	// sheet. The strands waver slowly, the water in them racing down.
	float strands = value_noise(vec2(at.x * 9.0, fallen * 0.6 - t * 0.15));
	float gaps = mix(0.35, -0.1, strength) + 0.12 * UV.y;
	float sheet = smoothstep(gaps, gaps + 0.08, strands) * edge;
	// Toward its foot it breaks into drops, falling with it, each its own size.
	vec2 grid = vec2(at.x * 6.0, fallen * 5.0 - t * 1.3);
	vec2 id = floor(grid);
	vec2 inside = fract(grid) - 0.5 + (vec2(hash(id), hash(id + 3.1)) - 0.5) * 0.4;
	float radius = 0.12 + 0.16 * hash(id + 7.7);
	float drop = 1.0 - smoothstep(radius - 0.05, radius, length(inside));
	float breaking = smoothstep(0.55, 0.9, UV.y) * (1.0 - 0.6 * strength);
	float body = mix(sheet, max(sheet * 0.5, drop * edge), breaking) * smoothstep(0.0, 0.03, UV.y);
	// White streaks of air it carries down, long and narrow, racing down with it.
	float streak = value_noise(vec2(at.x * 22.0, fallen * 3.0 - t * 1.6));
	streak = mix(streak, value_noise(vec2(at.x * 47.0 + 3.0, fallen * 6.0 - t * 2.2)), 0.4);
	float white = smoothstep(0.42, 0.62, streak) * mix(0.8, 0.95, strength);
	// A trickle is mostly air; a sheet white at its lip, where it leaves the sill, and
	// down its edges.
	white = max(white, 0.65 * (1.0 - strength));
	white = max(white, (1.0 - smoothstep(0.0, 0.12, UV.y)) * 0.8);
	white = max(white, (1.0 - smoothstep(0.0, 0.1, side)) * strength);
	// A foot of froth where it meets the water under it: billowing white, wider than
	// the fall, boiling up and down.
	float boil = value_noise(vec2(at.x * 7.0, t * 0.7)) - 0.5;
	float foot = smoothstep(0.72, 0.95, UV.y + boil * 0.18) * mix(0.75, 1.0, strength);
	float froth_side = smoothstep(0.0, 0.05, side + 0.12 * strength + 0.04);
	float froth = foot * froth_side * (0.6 + 0.4 * value_noise(at * vec2(14.0, 9.0) - vec2(0.0, t)));
	white = max(white, foot);
	body = max(body, froth);
	ALBEDO = mix(water_colour.rgb, foam_colour.rgb, white);
	ALPHA = clamp(body * mix(mix(0.6, 0.85, strength), 0.97, white), 0.0, 0.97);
	ROUGHNESS = 1.0;
	AO = mix(indoor_ambient, 1.0, outdoor);
	AO_LIGHT_AFFECT = 0.0;
}


void light() {
	float facing = abs(dot(NORMAL, LIGHT));
	float lit = LIGHT_IS_DIRECTIONAL
		? smoothstep(0.0, 0.3, facing) * outdoor
		: mix(lamp_bounce, 1.0, smoothstep(0.0, 0.6, facing));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit / PI;
}
