// Wreckage on the sea (Flotsam), lit like the ship — toon diffuse, no specular —
// and darkened toward the crew's ink at each piece's rim. Afloat, a piece rides the
// drawn sea's ripple (sea_ripple.gdshaderinc) at its middle, so it bobs with the
// water it sits in; falling through the air, it does not.
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;

#include "res://scenes/art/sea_ripple.gdshaderinc"

uniform vec4 ink : source_color = vec4(0.137, 0.149, 0.18, 1.0);
uniform float rim_strength = 0.45;

varying float rim;

void vertex() {
	// Within a few centimetres of the sea plane a piece is afloat.
	float afloat = 1.0 - smoothstep(0.05, 0.3, abs(NODE_POSITION_WORLD.y));
	float ripple = sea_ripple(NODE_POSITION_WORLD.xz, TIME) * afloat;
	// The world's up in the piece's own frame: it is turned, never scaled.
	VERTEX += vec3(MODEL_MATRIX[0].y, MODEL_MATRIX[1].y, MODEL_MATRIX[2].y) * ripple;
	rim = UV.x;
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, ink.rgb, rim * rim_strength);
}
