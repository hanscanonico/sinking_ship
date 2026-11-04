// A cargo lamp's tin shade among its fellows' (LampGlobes): toon-lit, no specular, both sides.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_disabled;

#include "res://scenes/art/lamp_globe.gdshaderinc"

void vertex() {
	fade_distance = length(VIEW_MATRIX * MODEL_MATRIX[3]);
}

void fragment() {
	ALBEDO = albedo.rgb;
	if (faded(FRAGCOORD.xy)) {
		discard;
	}
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.5;
}
