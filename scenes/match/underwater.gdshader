// The tint over the view from under the sea (Underwater): brighter and greener
// looking up toward the surface and the nearer it the eye is, darker looking down,
// with shafts of light slanting down from the surface. The direction each pixel
// looks along comes from the eye's axes and field of view.
shader_type canvas_item;

uniform vec3 eye_right = vec3(1.0, 0.0, 0.0);
uniform vec3 eye_up = vec3(0.0, 1.0, 0.0);
uniform vec3 eye_back = vec3(0.0, 0.0, 1.0);
// The tangents of half the field of view, across and up.
uniform vec2 eye_tan = vec2(1.0, 0.56);
// Metres the eye is under the surface, and over which the light from above fades.
uniform float depth = 0.0;
uniform float light_depth = 14.0;
// The way the shafts run: down, slanted away from the sun.
uniform vec3 shaft_axis = vec3(-0.3, -0.9, -0.3);
uniform vec4 deep_tint : source_color = vec4(0.03, 0.15, 0.27, 0.5);
uniform vec4 lit_tint : source_color = vec4(0.2, 0.55, 0.52, 0.3);
uniform vec4 shaft_colour : source_color = vec4(0.62, 0.9, 0.82, 1.0);

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

void fragment() {
	vec2 ndc = UV * 2.0 - 1.0;
	vec3 look = normalize(eye_right * ndc.x * eye_tan.x - eye_up * ndc.y * eye_tan.y - eye_back);
	float near = exp(-depth / light_depth);
	vec4 tint = mix(deep_tint, lit_tint, smoothstep(-0.6, 0.9, look.y) * near);
	// Lines along the axis, so they fan out from where it vanishes overhead; patterned
	// by which way round the axis a pixel looks, sampled on a circle so no seam shows.
	vec3 axis = normalize(shaft_axis);
	vec3 side = normalize(cross(axis, vec3(0.0, 0.0, 1.0)));
	vec3 other = cross(axis, side);
	vec2 round_axis = normalize(vec2(dot(look, side), dot(look, other)) + vec2(1e-5));
	float rays = value_noise(round_axis * 6.0 + vec2(TIME * 0.11, 0.0));
	rays *= value_noise(round_axis * 11.0 + vec2(3.0, -TIME * 0.07));
	float shaft = smoothstep(0.15, 0.4, rays) * smoothstep(0.1, 0.9, -dot(look, axis)) * near;
	tint.rgb = mix(tint.rgb, shaft_colour.rgb, shaft * 0.6);
	tint.a = mix(tint.a, 0.6, shaft * 0.45);
	COLOR = tint;
}
