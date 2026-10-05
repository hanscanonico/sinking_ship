// Foam lying on the planks (SinkingFx): a shaped grain flat in its emitter's plane
// — the deck's — never standing up off it, worn away from its edge as it thins out.
// Each grain shows its own piece of a sheet of lace (FxGrains.lace), its threads
// worn thinner or thicker than the next one's, its outline ragged where the sheet's
// broad noise lets it, so no two patches are the same and overlapping ones run
// together into a band.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

#include "res://scenes/match/fx_grain.gdshaderinc"

uniform sampler2D grain : hint_default_white, filter_linear_mipmap, repeat_enable;
// How much of the sheet a grain shows, across and along it.
uniform vec2 window = vec2(0.5);
// How far the sheet's noise moves a grain's outline in or out of its round, and how
// much more of its threads one grain has lost than another, at most.
uniform float ragged = 0.55;
uniform float worn = 0.12;

// How far through its life the grain is, 0…1.
varying float age;
// Where on the sheet this grain's piece lies, and how worn its threads are, 0…1.
varying vec2 corner;
varying float wear;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	age = INSTANCE_CUSTOM.y;
	// Its slot, and the turn it took this life: a new piece each time it comes back.
	float which = float(INSTANCE_ID) * 1.618 + INSTANCE_CUSTOM.x * 7.31;
	corner = vec2(hash(which + 0.37), hash(which * 1.91 + 5.13));
	wear = hash(which * 2.77 + 11.9);
}

void fragment() {
	if (past_the_sea(height, INV_VIEW_MATRIX[3].y)) {
		discard;
	}
	vec4 sheet = texture(grain, corner + UV * window);
	vec2 off = (UV - 0.5) * 2.0;
	// Thinning out toward a ragged rim the noise draws, and gone before the quad's
	// own edge, so no grain shows a circle or a square.
	float rim = length(off) + (sheet.r - 0.5) * ragged * 2.0;
	float edge = 0.5 + worn * wear + 0.3 * smoothstep(0.45, 1.0, age);
	edge += 0.45 * smoothstep(0.45, 1.05, rim);
	edge += 0.55 * smoothstep(0.8, 1.0, max(abs(off.x), abs(off.y)));
	float cover = shape_edge(sheet.a, edge);
	ALBEDO = COLOR.rgb * glow;
	ALPHA = COLOR.a * cover * near_fade(VERTEX);
}
