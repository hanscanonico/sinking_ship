// A room lamp's part drawn among its fellows' (LampGlobes): what StandardMaterial3D draws
// for ShipLamp's materials, the screen-door fade near the eye (ShipLamp.fade_near) judged
// by the lamp's own origin, as a lamp drawn alone is by its node's.
uniform vec4 albedo : source_color;
uniform float distance_fade_min;
uniform float distance_fade_max;
varying float fade_distance;

// Set in vertex(), where MODEL_MATRIX carries the instance's transform: the lamp's
// origin, from the eye.
// Whether the fragment at [fragcoord] is dithered away, as BaseMaterial3D's
// DISTANCE_FADE_PIXEL_DITHER does it.
bool faded(vec2 fragcoord) {
	const vec3 magic = vec3(0.06711056f, 0.00583715f, 52.9829189f);
	float fade = clamp(smoothstep(distance_fade_min, distance_fade_max, fade_distance), 0.0, 1.0);
	return fade < 0.001 || fade < fract(magic.z * fract(dot(fragcoord, magic.xy)));
}
