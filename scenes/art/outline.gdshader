// An inverted hull: the mesh again, grown along its normals and drawn from
// inside, so a brawler keeps a dark edge against the deck and the sea. A vertex
// colour's alpha scales the growth: 0 where an inner rim of the mesh must not be
// inked (Brawler), 1 — as with no colours at all — everywhere else.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 ink : source_color = vec4(0.137, 0.149, 0.18, 1.0);
// Model units, before the brawler's scale.
uniform float width = 0.014;

void vertex() {
	VERTEX += NORMAL * width * COLOR.a;
}

void fragment() {
	ALBEDO = ink.rgb;
}
