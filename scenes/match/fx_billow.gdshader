// A billow of steam or smoke (SinkingFx): a shaped grain facing the eye, turned by
// the particle's angle, shaded in two tones as the toon ship is — lit where its
// bumps face the sun, shade where they turn away. Its picture holds each bump's
// facing in red and green (FxGrains.billow); it is worn away from its edge over the
// last of its life rather than fading to a grey film.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

#include "res://scenes/match/fx_grain.gdshaderinc"

uniform sampler2D grain : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform vec4 lit : source_color = vec4(1.0);
uniform vec4 shade : source_color = vec4(0.7, 0.7, 0.8, 1.0);
// Toward the sun, in the world (SeaAndSky.sun).
uniform vec3 sun = vec3(0.44, 0.53, 0.73);
// How much of its edge the billow has lost by the end of its life.
uniform float wear = 0.3;

varying float age;
// The picture's right and up in view space.
varying vec3 right_view;
varying vec3 up_view;

void vertex() {
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
	float scale = length(MODEL_MATRIX[0].xyz);
	height = (facing * vec4(VERTEX * scale, 1.0)).y;
	MODELVIEW_MATRIX = VIEW_MATRIX * facing * mat4(
		vec4(scale, 0.0, 0.0, 0.0),
		vec4(0.0, scale, 0.0, 0.0),
		vec4(0.0, 0.0, scale, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	// The picture's axes in view space: the eye's own, turned by the angle.
	right_view = vec3(cos(turn), -sin(turn), 0.0);
	up_view = vec3(sin(turn), cos(turn), 0.0);
	age = INSTANCE_CUSTOM.y;
}

void fragment() {
	if (past_the_sea(height, INV_VIEW_MATRIX[3].y)) {
		discard;
	}
	vec4 picture = texture(grain, UV);
	vec2 bump = picture.rg * 2.0 - 1.0;
	vec3 facing = normalize(
		bump.x * right_view + bump.y * up_view
		+ sqrt(max(1.0 - dot(bump, bump), 0.0)) * vec3(0.0, 0.0, 1.0)
	);
	vec3 sun_view = mat3(VIEW_MATRIX) * sun;
	float toward = dot(facing, sun_view) / max(length(sun_view), 0.0001);
	float soft = max(fwidth(toward), 0.0001);
	// A low sun lights a little past the bumps' sides, as the ship's toon light does.
	float sunlit = smoothstep(-soft, soft, toward + 0.25);
	float cover = shape_edge(picture.a, 0.5 + wear * smoothstep(0.55, 1.0, age));
	ALBEDO = mix(shade.rgb, lit.rgb, sunlit) * COLOR.rgb * glow;
	ALPHA = COLOR.a * cover * near_fade(VERTEX);
}
