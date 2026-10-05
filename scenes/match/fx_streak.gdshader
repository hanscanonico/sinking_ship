// A streak of white water (SinkingFx): a shaped grain stretched along the way it
// flies — the particle's y, which CPUParticles3D aligns with its velocity — and
// turned about it to face the eye. It draws in to a fleck as it slows and falls;
// spray raining round the eye keeps clear of the crosshair.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

#include "res://scenes/match/fx_grain.gdshaderinc"

uniform sampler2D grain : hint_default_white, filter_linear_mipmap, repeat_disable;
// How long a streak is, as a share of its first length, when its life ends.
uniform float fleck = 0.35;
// None drawn within this share of the screen's height of its middle — the
// crosshair — fading in over as much again; 0 for drawn everywhere.
uniform float crosshair = 0.0;

void vertex() {
	float scale = length(MODEL_MATRIX[1].xyz);
	vec3 along = MODEL_MATRIX[1].xyz / max(scale, 0.0001);
	vec3 to_eye = normalize(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
	vec3 across = cross(along, to_eye);
	// Flying straight at the eye or away, it shows its head: any side will do.
	if (dot(across, across) < 0.0001) {
		across = INV_VIEW_MATRIX[0].xyz;
	}
	across = normalize(across);
	float drawn_in = mix(1.0, fleck, smoothstep(0.3, 1.0, INSTANCE_CUSTOM.y));
	mat4 placed = mat4(
		vec4(across * scale, 0.0),
		vec4(along * scale * drawn_in, 0.0),
		vec4(cross(across, along) * scale, 0.0),
		MODEL_MATRIX[3]
	);
	height = (placed * vec4(VERTEX, 1.0)).y;
	MODELVIEW_MATRIX = VIEW_MATRIX * placed;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	if (past_the_sea(height, INV_VIEW_MATRIX[3].y)) {
		discard;
	}
	float cover = shape_edge(texture(grain, UV).a, 0.5);
	ALBEDO = COLOR.rgb * glow;
	ALPHA = COLOR.a * cover * near_fade(VERTEX);
	if (crosshair > 0.0) {
		vec2 off = (SCREEN_UV - 0.5) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		ALPHA *= smoothstep(crosshair, crosshair * 2.0, length(off));
	}
}
