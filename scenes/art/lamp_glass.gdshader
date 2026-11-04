// A lamp's glass among its fellows' (LampGlobes): unshaded, glowing as its lamp burns —
// INSTANCE_CUSTOM.r its glow (the material's emission energy), .g 1 on her emergency
// power, when it glows red.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, unshaded;

#include "res://scenes/art/lamp_globe.gdshaderinc"

uniform vec4 glow : source_color;
uniform vec4 emergency_glow : source_color;
varying vec2 lit;

void vertex() {
	fade_distance = length(VIEW_MATRIX * MODEL_MATRIX[3]);
	lit = INSTANCE_CUSTOM.rg;
}

void fragment() {
	ALBEDO = albedo.rgb;
	if (faded(FRAGCOORD.xy)) {
		discard;
	}
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.5;
	EMISSION = mix(glow.rgb, emergency_glow.rgb, lit.y) * lit.x;
}
