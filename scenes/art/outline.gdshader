// An inverted hull: the mesh again, grown along its normals and drawn from
// inside, so a brawler keeps a dark edge against the deck and the sea. A vertex
// colour's alpha scales the growth: 0 where an inner rim of the mesh must not be
// inked (Brawler), 1 — as with no colours at all — everywhere else.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 ink : source_color = vec4(0.137, 0.149, 0.18, 1.0);
// Model units, before the brawler's scale.
uniform float width = 0.014;
// More width per metre from the eye, so an edge a shove coming lights holds its
// size on the screen across a deck; 0 for the ink alone.
uniform float reach = 0.0;
// How strongly the edge throbs brighter, 0…1: a full charge's.
uniform float beat = 0.0;

// The throb's rate, in radians a second: about 2.7 Hz, under the 3 a flash keeps to.
const float BEAT_RATE = 17.0;
const float BEAT_BRIGHT = 0.7;

void vertex() {
	float far = reach > 0.0 ? -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z : 0.0;
	VERTEX += NORMAL * (width + reach * far) * COLOR.a;
}

void fragment() {
	ALBEDO = ink.rgb * (1.0 + beat * BEAT_BRIGHT * (0.5 + 0.5 * sin(TIME * BEAT_RATE)));
}
