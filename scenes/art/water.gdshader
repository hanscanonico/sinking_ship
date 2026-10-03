// The sea, drawn on the world plane y = 0 — the only water the rules know (D7).
// Its ripple is three sines of a few centimetres that average to the plane, so
// the drawn waterline never strays from the one the sim tests. Colour comes from
// how far below the surface the opaque scene lies: a foam band where the hull, a
// flooded deck or a body cuts the plane, see-through shallows over a drowned
// deck, opaque deep water everywhere else. No screen-texture refraction.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec4 deep_colour : source_color = vec4(0.11, 0.3, 0.44, 1.0);
uniform vec4 shallow_colour : source_color = vec4(0.1, 0.46, 0.53, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.92, 0.96, 0.95, 1.0);
uniform vec4 streak_colour : source_color = vec4(0.27, 0.53, 0.66, 1.0);
// Metres of water over which a drowned surface fades from seen to hidden.
uniform float clear_depth = 1.3;
// How much of a surface just under the water still shows through.
uniform float shallow_alpha = 0.5;
uniform float murk_steps = 3.0;
// Metres below the surface that still foam.
uniform float foam_depth = 0.15;
// The ripple's peak, in metres, all three sines together.
uniform float wave_height = 0.05;
uniform float wave_speed = 0.8;
// Size of the drifting streak pattern, per metre.
uniform float streak_scale = 0.28;
uniform float streak_width = 0.022;
uniform float patch_scale = 0.035;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying vec3 world;

// Zero-mean by construction: a sum of sines about 0.
float ripple(vec2 xz, float t) {
	float a = sin(dot(xz, vec2(0.82, 0.57)) * 0.9 + t * 1.3);
	float b = sin(dot(xz, vec2(-0.36, 0.93)) * 0.57 + t * 1.0);
	float c = sin(dot(xz, vec2(0.97, -0.24)) * 0.37 + t * 0.7);
	return (a + b + c) * wave_height / 3.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void vertex() {
	vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += ripple(at.xz, TIME * wave_speed);
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 behind = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	// Vertical metres from this point of the surface down to whatever is behind it.
	float below = max(world.y - behind.y, 0.0);

	float t = TIME * wave_speed;
	vec2 drift = world.xz * streak_scale;
	float n1 = value_noise(drift + vec2(t * 0.05, t * 0.03));
	float n2 = value_noise(drift * 1.6 + vec2(-t * 0.04, t * 0.05) + 17.0);
	float streak = 1.0 - smoothstep(0.0, streak_width, abs(n1 - n2));

	// Stepped, so a drowning deck shows contour bands parallel to the waterline.
	float murk = floor(smoothstep(0.0, clear_depth, below) * murk_steps + 0.5) / murk_steps;
	vec3 colour = mix(shallow_colour.rgb, deep_colour.rgb, murk);
	// Broad, slow patches of lighter and darker sea, so open water is never flat.
	float patch = value_noise(world.xz * patch_scale + vec2(t * 0.01, -t * 0.008));
	colour *= mix(1.0, mix(0.86, 1.08, patch), murk);
	colour = mix(colour, streak_colour.rgb, streak * murk * 0.3);
	float alpha = mix(shallow_alpha, 1.0, murk);

	float lap = value_noise(world.xz * 2.2 + vec2(t * 0.6, -t * 0.4));
	float foam = step(below, foam_depth * (0.55 + 0.45 * lap));
	colour = mix(colour, foam_colour.rgb, foam);
	alpha = max(alpha, foam * 0.95);

	ALBEDO = colour;
	ALPHA = alpha;
}
