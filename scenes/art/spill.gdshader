// Water pouring through an opening inside her (InnerWater): over a low wall's top,
// through a doorway or a porthole, down a stair's hole — a sheet falling from where
// it leaves the higher water to where it meets the lower, streaked white where it
// tumbles, glassy where it is thick, ragged at its sides and boiling into foam at its
// foot. Drawn in the sea's own colours, so it reads as the same water.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 water_colour : source_color = vec4(0.1, 0.46, 0.53, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.97, 1.0, 0.99, 1.0);
// Metres of the sheet: how wide and how far it falls, so its streaks keep their size.
instance uniform vec2 extent = vec2(1.0, 1.0);
// How hard it pours, 0…1: a trickle is a thin broken lace, a flood a solid sheet.
instance uniform float strength = 1.0;
uniform float fall_speed = 3.5;
// Foam is brighter than white, so it stays white through the tonemap (water.gdshader).
uniform float foam_glow = 1.3;

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

void fragment() {
	// UV.x across the sheet, UV.y down it from where it leaves the higher water.
	vec2 at = UV * extent;
	float t = TIME * fall_speed;
	// Streaks: noise stretched down the fall, scrolling with it, quickening as it falls.
	float fallen = at.y + 0.5 * at.y * at.y;
	float streak = value_noise(vec2(at.x * 9.0, fallen * 1.2 - t));
	streak = mix(streak, value_noise(vec2(at.x * 23.0 + 3.0, fallen * 2.5 - t * 1.4)), 0.4);
	// Ragged sides, narrowing a little as it falls; thinner where it pours weakly.
	float side = min(UV.x, 1.0 - UV.x) * extent.x;
	float edge = smoothstep(0.0, 0.08 + 0.1 * value_noise(vec2(fallen * 3.0 - t, at.x)), side);
	float body = mix(0.35, 0.85, strength) * edge;
	body *= smoothstep(0.0, 0.05, UV.y);
	body *= mix(1.0, step(0.45 - 0.4 * strength, streak), 0.6);
	// White where it tumbles and boils at its foot, glassy sea-green between.
	float white = smoothstep(0.55, 0.85, streak) * mix(0.4, 0.8, strength);
	white = max(white, smoothstep(0.75, 1.0, UV.y) * edge);
	ALBEDO = mix(water_colour.rgb, foam_colour.rgb * foam_glow, white);
	ALPHA = clamp(body + white * 0.4 * edge, 0.0, 0.95);
}
