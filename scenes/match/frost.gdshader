// The cold creeping in as a swimmer's cold meter empties (FirstPersonHud): frost
// grown in from the screen's edges, feathered toward the centre and thickest where two
// edges meet: a dense rime where it has settled, and a front of fine crystals still
// growing. One pass over the screen, drawn only while the eyes swim and the meter is
// not full; the clear middle returns early, and the crystals are a texture
// FirstPersonHud builds once (their cell edges, white on black).
shader_type canvas_item;
render_mode unshaded;

// How far the cold has come: 0 for a full meter, 1 for an empty one.
uniform float cold : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D crystals : filter_linear_mipmap, repeat_enable;
uniform vec4 frost_colour : source_color = vec4(0.74, 0.86, 0.98, 1.0);
uniform vec4 rime_colour : source_color = vec4(0.96, 0.99, 1.0, 1.0);
uniform float opacity = 0.85;
// How far in from an edge the frost reaches on an empty meter, in screen heights.
uniform float reach = 0.3;
// How much further it reaches into a corner, in screen heights: one edge's frost
// gives way to the next one's over about this much.
uniform float corner = 0.12;
// The softness of the frost's front, and how far behind it the frost has settled,
// in screen heights.
uniform float feather = 0.06;
uniform float settling = 0.12;
// How many times the crystal texture repeats down the screen, coarse and fine.
uniform float coarse = 1.0;
uniform float fine = 2.7;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x);
	float b = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x);
	return mix(a, b, u.y);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	// In screen heights: x across the width, y down the height.
	vec2 at = UV * vec2(aspect, 1.0);
	vec2 in_from = min(at, vec2(aspect, 1.0) - at);
	// A soft minimum of the distances in from the two nearest edges.
	float depth = -corner * log(exp(-in_from.x / corner) + exp(-in_from.y / corner));
	float front = reach * cold;
	COLOR = vec4(0.0);
	if (depth < front + feather * 1.4) {
		float ragged = noise(at * 6.0) * 0.6 + noise(at * 17.0) * 0.4;
		front += (ragged - 0.5) * feather * 2.0;
		float frost = 1.0 - smoothstep(front - feather, front + feather * 0.3, depth);
		// 0 at the front, 1 well behind it: the old frost is dense, the new one thin.
		float settled = 1.0 - smoothstep(front - settling, front, depth);
		float growing = frost * (1.0 - settled);
		float edges = max(
			texture(crystals, at * coarse).r, texture(crystals, at * fine + 0.37).r * 0.6
		);
		float haze = (0.14 + 0.42 * settled) * (0.8 + 0.4 * ragged);
		float rime = edges * (0.2 + 0.7 * growing);
		float white = clamp(settled * 0.6 + rime, 0.0, 1.0);
		vec3 colour = mix(frost_colour.rgb, rime_colour.rgb, white);
		float strength = mix(0.55, 1.0, cold) * smoothstep(0.0, 0.05, cold);
		COLOR = vec4(colour, clamp(frost * (haze + rime), 0.0, 1.0) * strength * opacity);
	}
}
