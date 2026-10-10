// Froth lying on the water inside her (InnerWater), flat on its surface: where a pour
// lands, white water boiling outward in a patch of the sea's lace as long as it pours;
// and where a cell's water reaches the top of an opening, the air it blows out of it
// breaking the surface in a burst of bubbles — rings that spread and pop and a froth
// that thins out after them; and over a pocket whose air leaks (SH29), small bubbles
// popping on the water over the leak as long as it leaks, riding the sea's ripple
// where that water is the sea. Lit as the water under it is (inner_water.gdshader): by
// a room's lamps, or the sun where it is open to the sky; never glowing.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

#include "res://scenes/art/sea_ripple.gdshaderinc"

uniform vec4 foam_colour : source_color = vec4(0.97, 1.0, 0.99, 1.0);
uniform vec4 water_colour : source_color = vec4(0.1, 0.46, 0.53, 1.0);
// Metres across the patch, each way, so its lace keeps its size.
uniform vec2 extent = vec2(1.0, 1.0);
// How hard it boils, 0…1.
uniform float strength = 1.0;
// For a burst of air, how far through it, 0…1; below 0 for a pour's landing, which
// boils as long as the pour does.
uniform float burst = -1.0;
uniform float outdoor = 0.0;
// A pocket's leak rather than a pour's landing or a burst.
uniform bool leaking = false;
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

float lace(vec2 p, float t, float width) {
	float a = value_noise(p + vec2(t * 0.3, t * 0.2));
	float b = value_noise(p * 1.5 + vec2(-t * 0.25, t * 0.3) + 11.0);
	return 1.0 - smoothstep(0.0, width, abs(a - b));
}

// Bubbles breaking the surface: rings on a jittered grid of [size] metres, each
// swelling and popping on its own clock, 0…1.
float bubbles(vec2 p, float size, float t) {
	vec2 grid = p / size;
	vec2 id = floor(grid);
	vec2 inside = fract(grid) - 0.5 - (vec2(hash(id), hash(id + 5.3)) - 0.5) * 0.5;
	float life = fract(t * (0.8 + hash(id + 2.1)) + hash(id + 9.4));
	float radius = mix(0.08, 0.38, life);
	float ring = 1.0 - smoothstep(0.0, 0.06, abs(length(inside) - radius));
	return ring * (1.0 - life) * step(0.35, hash(id + 4.2));
}

void vertex() {
	// On the sea, up and down with its ripple, as the sea is drawn.
	vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sea_ripple(at.xz, TIME) * outdoor;
}

void fragment() {
	vec2 at = UV * extent;
	vec2 off = (UV - 0.5) * 2.0;
	float from_middle = length(off) + (value_noise(at * 2.5 + TIME * 0.3) - 0.5) * 0.5;
	float t = TIME;
	float cover = 0.0;
	if (leaking) {
		// Small bubbles rising to pop over the leak, thickest over it.
		float fizz = bubbles(at, 0.22, t * 1.3) + bubbles(at + 3.7, 0.3, t * 0.9);
		float foam = lace(at * 4.0, t * 1.5, 0.15) * 0.5;
		cover = min(fizz + foam, 1.0) * (1.0 - smoothstep(0.15, 0.9, from_middle)) * strength;
	} else if (burst < 0.0) {
		// Boiling out from where it lands, thinning toward a ragged rim.
		float boil = lace(at * 2.6 - off * t * 0.8, t * 2.0, 0.12);
		boil = max(boil, smoothstep(0.55, 0.8, value_noise(at * 5.0 + vec2(t * 1.3, -t))));
		cover = boil * (1.0 - smoothstep(0.35, 1.0, from_middle)) * mix(0.5, 1.0, strength);
		cover = max(cover, bubbles(at, 0.18, t) * (1.0 - smoothstep(0.5, 1.0, from_middle)));
	} else {
		// A burst: rings spreading out of the middle, then froth left to thin away.
		float spread = mix(0.25, 1.0, sqrt(burst));
		float ring = 1.0 - smoothstep(0.0, 0.12, abs(from_middle - spread));
		float popping = bubbles(at, 0.14, t * 1.6) * (1.0 - smoothstep(0.0, spread, from_middle));
		float left = lace(at * 3.0, t, 0.1) * (1.0 - smoothstep(spread * 0.6, spread, from_middle));
		cover = max(max(ring * (1.0 - burst), popping), left * 0.7) * (1.0 - burst * burst);
		cover *= strength;
	}
	ALBEDO = mix(water_colour.rgb, foam_colour.rgb, smoothstep(0.1, 0.5, cover));
	ALPHA = clamp(cover, 0.0, 0.9);
	ROUGHNESS = 1.0;
	AO = mix(indoor_ambient, 1.0, outdoor);
	AO_LIGHT_AFFECT = 0.0;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float lit = LIGHT_IS_DIRECTIONAL
		? smoothstep(0.0, 0.12, facing) * outdoor
		: mix(lamp_bounce, 1.0, smoothstep(-0.2, 0.55, facing)) * (1.0 - outdoor);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit / PI;
}
