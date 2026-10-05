// A soft grain of the sinking's effects (SinkingFx) — dust, a bubble: a particle
// turned to face the eye, its picture tinted by the particle's colour.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

#include "res://scenes/match/fx_grain.gdshaderinc"

uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_disable;

void vertex() {
	// Facing the eye, turned by the particle's angle, at the particle's scale.
	mat4 facing = mat4(
		normalize(INV_VIEW_MATRIX[0]),
		normalize(INV_VIEW_MATRIX[1]),
		normalize(INV_VIEW_MATRIX[2]),
		MODEL_MATRIX[3]
	);
	float turn = INSTANCE_CUSTOM.x;
	facing = facing * mat4(
		vec4(cos(turn), -sin(turn), 0.0, 0.0),
		vec4(sin(turn), cos(turn), 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	facing = facing * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	height = (facing * vec4(VERTEX, 1.0)).y;
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	if (past_the_sea(height, INV_VIEW_MATRIX[3].y)) {
		discard;
	}
	vec4 tint = texture(grain, UV) * COLOR;
	ALBEDO = tint.rgb * glow;
	ALPHA = tint.a * near_fade(VERTEX);
}
