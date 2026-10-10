// Water pouring through an opening inside her (InnerWater): over a low wall's top or
// a threshold, through a doorway or a porthole, down a stair's hole. It leaves the
// higher water level and arcs out as it falls — out as the root of how far it has
// fallen, the way a jet thrown level falls — a low sheet torn by white where it
// tumbles, breaking up into drops toward its foot, where the froth (froth.gdshader)
// takes it. In the sea's colours, lit as the ship's faces are (ship.gdshaderinc): by a
// room's lamps indoors, by the sun where it pours in from outdoors, never glowing.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec4 water_colour : source_color = vec4(0.1, 0.46, 0.53, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.97, 1.0, 0.99, 1.0);
// Metres of the sheet: how wide and how far it falls, so its streaks keep their size.
uniform vec2 extent = vec2(1.0, 1.0);
// How hard it pours, 0…1: a trickle is a thin broken lace, a flood a solid sheet.
uniform float strength = 1.0;
// How far out of its opening it has gone by its foot, in the sheet's own units, along
// whichever of its own axes runs out of the opening.
uniform vec3 thrown = vec3(0.0);
// 1 where it pours in from under the open sky, which lights it; 0 under a deck.
uniform float outdoor = 0.0;
uniform float fall_speed = 3.5;
// As the ship's indoor faces: the sky's ambient kept indoors, a lamp's light kept by a
// face turned away from it.
uniform float indoor_ambient = 0.35;
uniform float lamp_bounce = 0.35;

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
	// Streaks stretched down the fall, scrolling with it, quickening as it falls.
	float fallen = at.y + 0.5 * at.y * at.y;
	float streak = value_noise(vec2(at.x * 26.0, fallen * 2.0 - t));
	streak = mix(streak, value_noise(vec2(at.x * 61.0 + 3.0, fallen * 4.0 - t * 1.4)), 0.45);
	// Ragged sides, narrowing a little as it falls.
	float side = min(UV.x, 1.0 - UV.x) * extent.x;
	float edge = smoothstep(0.0, 0.06 + 0.12 * value_noise(vec2(fallen * 3.0 - t, at.x)), side);
	// A sheet that tears open where it pours weakly, more as it falls.
	float tear = value_noise(vec2(at.x * 5.0, fallen * 2.0 - t * 0.8));
	float sheet = step(0.55 - 0.45 * strength + 0.25 * UV.y, tear + 0.2) * edge;
	// Toward its foot it breaks into drops, falling with it, each its own size.
	vec2 grid = vec2(at.x * 6.0, fallen * 5.0 - t * 1.3);
	vec2 id = floor(grid);
	vec2 inside = fract(grid) - 0.5 + (vec2(hash(id), hash(id + 3.1)) - 0.5) * 0.4;
	float radius = 0.12 + 0.16 * hash(id + 7.7);
	float drop = 1.0 - smoothstep(radius - 0.05, radius, length(inside));
	float breaking = smoothstep(0.45, 1.0, UV.y) * (1.0 - 0.35 * strength);
	float body = mix(sheet, drop * edge, breaking) * smoothstep(0.0, 0.06, UV.y);
	// Aerated white where it tumbles, more toward its foot and the harder it pours;
	// clear sea-green between.
	float white = smoothstep(0.35, 0.72, streak) * mix(0.55, 0.9, strength);
	white = max(white, smoothstep(0.5, 1.0, UV.y) * 0.75);
	ALBEDO = mix(water_colour.rgb, foam_colour.rgb, white);
	ALPHA = clamp(body * mix(0.55, 0.95, white), 0.0, 0.95);
	ROUGHNESS = 1.0;
	AO = mix(indoor_ambient, 1.0, outdoor);
	AO_LIGHT_AFFECT = 0.0;
}

void light() {
	float facing = abs(dot(NORMAL, LIGHT));
	float lit = LIGHT_IS_DIRECTIONAL
		? smoothstep(0.0, 0.3, facing) * outdoor
		: mix(lamp_bounce, 1.0, smoothstep(0.0, 0.6, facing)) * (1.0 - outdoor);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit / PI;
}
