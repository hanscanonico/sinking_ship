// A soaked deck (SinkingFx): laid on the planks, it darkens them as water darkens
// timber where DeckWetness says the deck is wet, in ragged patches rather than its
// grid of cells, and draws nothing where it is dry — the planks stay exactly as lit —
// nor under the sea, which shows drowned planks through itself. It darkens by
// veiling the planks in black: what shows through keeps its light and its shadows,
// only less of both, and black stays black through the compatibility renderer's
// tonemapping of each draw, which would crush a multiplied factor toward black.
// It lies a few millimetres over the planks and is drawn a hair nearer the eye along
// its own line of sight — the same pixels, nearer in depth — so it wins over them
// without z-fighting and without rising over the sole of a foot.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled, skip_vertex_transform;

uniform sampler2D wetness : hint_default_black, filter_linear, repeat_disable;
// How much of the planks' light a soaked patch takes away.
uniform float soaked = 0.28;
// The size of the ragged edge's grain, per metre, and how far it eats in.
uniform float grain = 2.2;
uniform float ragged = 0.35;
// The share of its distance from the eye the veil is drawn nearer it.
uniform float pull = 0.0006;

varying vec3 world;
varying vec2 deck;

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
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	deck = VERTEX.xz;
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * (1.0 - pull);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (world.y < 0.0) {
		discard;
	}
	float noise = value_noise(deck * grain) * 0.65 + value_noise(deck * grain * 3.1) * 0.35;
	float wet = texture(wetness, UV).r - (noise - 0.5) * ragged;
	wet = smoothstep(0.2, 0.55, wet) * texture(wetness, UV).r;
	if (wet <= 0.004) {
		discard;
	}
	ALBEDO = vec3(0.0);
	ALPHA = wet * soaked;
}
