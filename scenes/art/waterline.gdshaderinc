// Where the ship (ship.gdshaderinc) meets the sea: the world plane y = 0 (D7),
// rippled as water.gdshader draws it (sea_ripple.gdshaderinc). A lap line of foam
// where it meets a steep face and the paint darkened wet just above it — on every
// finish, so the walls of a flooded room and a deck just clear of the water take
// them too — and the hull's paint taking the sea's colour under it, so the boot-top
// never reads through the shallows as a pink band, darkening deeper to a shape seen
// from under the sea.

#include "res://scenes/art/sea_ripple.gdshaderinc"

uniform vec4 lap_colour : source_color = vec4(0.95, 0.98, 0.97, 1.0);
uniform vec4 sunk_colour : source_color = vec4(0.05, 0.22, 0.32, 1.0);
uniform vec4 deep_sunk_colour : source_color = vec4(0.02, 0.06, 0.09, 1.0);
uniform float lap_width = 0.1;
uniform float wet_height = 0.12;
// Metres under the sea by which the hull has taken most of the sea's colour, and by
// which it has darkened to a shape seen from under the sea.
uniform float sunk_depth = 0.12;
uniform float deep_depth = 3.0;

// [albedo] as the sea leaves it at [world_pos] on a face turned to [world_normal],
// a hull's paint when [hull], at [time]; [lap] is how much of the lap line lies
// there, for the glow the caller adds to its emission.
vec3 sea_waterline(
	vec3 albedo, vec3 world_pos, vec3 world_normal, bool hull, float time, out float lap
) {
	float above = world_pos.y - sea_ripple(world_pos.xz, time);
	if (hull && above < 0.0) {
		vec3 sunk = mix(sunk_colour.rgb, deep_sunk_colour.rgb, smoothstep(0.0, deep_depth, -above));
		albedo = mix(albedo, sunk, (1.0 - exp(above / sunk_depth)) * 0.9);
	}
	albedo *= above > 0.0 ? mix(0.72, 1.0, smoothstep(0.0, wet_height, above)) : 1.0;
	float steep = 1.0 - abs(normalize(world_normal).y);
	float wash = sin(world_pos.x * 2.3 + world_pos.z * 1.7 + time * 1.6);
	lap = 1.0 - smoothstep(0.6, 1.0, above / (lap_width * (0.75 + 0.25 * wash)));
	lap *= step(-0.01, above) * smoothstep(0.35, 0.7, steep);
	return mix(albedo, lap_colour.rgb, lap);
}
