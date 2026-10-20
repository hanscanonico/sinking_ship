// Where the ship (ship.gdshaderinc) meets the sea: the world plane y = 0 (D7),
// rippled as water.gdshader draws it (sea_ripple.gdshaderinc). A lap line of foam
// where it meets a steep face and the paint darkened wet just above it — on every
// finish, so the walls of a flooded room and a deck just clear of the water take
// them too — and the hull's paint taking the sea's colour under it, so the boot-top
// never reads through the shallows as a pink band, darkening deeper into the sea's
// own hue, never blacker than the water round it. While the eye is under the sea
// (eye_under, set by Underwater) the tint eases, so a swimmer sees the plating as a
// wall and not as more of the fog. Whatever lies outdoors under the surface also
// fades into the sea's deep colour after it is lit (sea_fade), deeper the more, so a
// drowned deckhouse or funnel dark in its own shadow sinks into the water rather
// than reading as a black cut-out.

#include "res://scenes/art/sea_ripple.gdshaderinc"

uniform vec4 lap_colour : source_color = vec4(0.95, 0.98, 0.97, 1.0);
uniform vec4 sunk_colour : source_color = vec4(0.05, 0.22, 0.32, 1.0);
uniform vec4 deep_sunk_colour : source_color = vec4(0.06, 0.2, 0.3, 1.0);
uniform float lap_width = 0.1;
uniform float wet_height = 0.12;
// Metres under the sea by which the hull has taken most of the sea's colour, and by
// which it has darkened to a shape seen from under the sea.
uniform float sunk_depth = 0.12;
uniform float deep_depth = 3.0;
// 1.0 while the eye is under the sea, 0.0 over it (project.godot's shader globals).
global uniform float eye_under;
// How much of the sunk tint the eye under the sea is spared.
const float UNDER_CLEAR = 0.6;
// The sea's deep colour (water.gdshader's deep_colour, 0.09, 0.27, 0.42), which a face
// under the surface fades into after lighting, and the metres under it by which it has
// gone wholly: well inside the sea's clear_depth, before its murk steps toward opaque,
// so what shows through them has already sunk into the sea's colour instead of ending
// in a hard edge. A const takes no source_color conversion, so it is written linear.
const vec3 SEA_DEEP = vec3(0.0085, 0.0593, 0.1473);
const float FADE_DEPTH = 0.5;

// [albedo] as the sea leaves it at [world_pos] on a face turned to [world_normal],
// a hull's paint when [hull], at [time]; [lap] is how much of the lap line lies
// there, for the glow the caller adds to its emission.
vec3 sea_waterline(
	vec3 albedo, vec3 world_pos, vec3 world_normal, bool hull, float time, out float lap
) {
	float above = world_pos.y - sea_ripple(world_pos.xz, time);
	if (hull && above < 0.0) {
		vec3 sunk = mix(sunk_colour.rgb, deep_sunk_colour.rgb, smoothstep(0.0, deep_depth, -above));
		float tint = (1.0 - exp(above / sunk_depth)) * 0.95 * (1.0 - UNDER_CLEAR * eye_under);
		albedo = mix(albedo, sunk, tint);
	}
	albedo *= above > 0.0 ? mix(0.72, 1.0, smoothstep(0.0, wet_height, above)) : 1.0;
	float steep = 1.0 - abs(normalize(world_normal).y);
	float wash = sin(world_pos.x * 2.3 + world_pos.z * 1.7 + time * 1.6);
	lap = 1.0 - smoothstep(0.6, 1.0, above / (lap_width * (0.75 + 0.25 * wash)));
	lap *= step(-0.01, above) * smoothstep(0.35, 0.7, steep);
	return mix(albedo, lap_colour.rgb, lap);
}

// How far a face at [world_pos] has faded into the sea's deep colour (SEA_DEEP) at
// [time]: 0 at the surface or above it, 1 FADE_DEPTH under it, eased like the tint
// while the eye is under the sea. The caller blends its lit colour by it.
float sea_fade(vec3 world_pos, float time) {
	float under = sea_ripple(world_pos.xz, time) - world_pos.y;
	return smoothstep(0.0, FADE_DEPTH, under) * (1.0 - UNDER_CLEAR * eye_under);
}
