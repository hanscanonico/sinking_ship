// A grain of the sinking's effects (SinkingFx): a particle turned to face the eye,
// its picture tinted by the particle's colour. It fades out as it nears the eye,
// from clear_to in to clear_from, so nothing it draws stands in the eye's face. And
// the sea plane (y = 0) cuts it: drawn after the sea, which writes no depth, a grain
// fallen under it would show over it from above, and one over it through it from
// below; the part on the eye's far side of the plane is not drawn.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_disable;
uniform float clear_from = 0.9;
uniform float clear_to = 3.0;

varying float height;

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
	if ((height < 0.0) != (INV_VIEW_MATRIX[3].y < 0.0)) {
		discard;
	}
	vec4 tint = texture(grain, UV) * COLOR;
	ALBEDO = tint.rgb;
	ALPHA = tint.a * smoothstep(clear_from, clear_to, length(VERTEX));
}
