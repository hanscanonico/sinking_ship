// Foam lying on the planks (SinkingFx): a shaped grain flat in its emitter's plane
// — the deck's — never standing up off it, worn away from its edge as it thins out.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

#include "res://scenes/match/fx_grain.gdshaderinc"

uniform sampler2D grain : hint_default_white, filter_linear_mipmap, repeat_disable;

// How far through its life the grain is, 0…1.
varying float age;

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	age = INSTANCE_CUSTOM.y;
}

void fragment() {
	if (past_the_sea(height, INV_VIEW_MATRIX[3].y)) {
		discard;
	}
	float cover = shape_edge(texture(grain, UV).a, 0.5 + 0.3 * smoothstep(0.45, 1.0, age));
	ALBEDO = COLOR.rgb * glow;
	ALPHA = COLOR.a * cover * near_fade(VERTEX);
}
