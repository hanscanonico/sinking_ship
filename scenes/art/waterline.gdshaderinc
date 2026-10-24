// Where the ship (ship.gdshaderinc) meets the sea: the world plane y = 0 (D7),
// rippled as water.gdshader draws it (sea_ripple.gdshaderinc). A lap line of foam
// where it meets a steep face and the paint darkened wet just above it — on every
// finish, so the walls of a flooded room and a deck just clear of the water take
// them too. Under the surface, whatever lies outdoors is lit only by what light gets
// down to it (sea_light): the sun's and the sky's, each colour the less the deeper,
// red first — so a drowned deck or the hull's boot-top goes green, then blue, then
// dark as the sea takes it. The sea's own surface (water.gdshader) dims it again on
// the way back up to an eye over the water, as the fog does for an eye under it.

#include "res://scenes/art/sea_ripple.gdshaderinc"

uniform vec4 lap_colour : source_color = vec4(0.95, 0.98, 0.97, 1.0);
uniform float lap_width = 0.1;
uniform float wet_height = 0.12;
// How much of each colour of light a metre of sea takes out (water.gdshader's
// absorption, linear, per metre), and how much longer than straight down the light's
// way down to a drowned face is: the sun's slant, bent steeper by the surface, and
// the sky's light, from all round.
const vec3 SEA_ABSORPTION = vec3(0.9, 0.32, 0.2);
const float LIGHT_SLANT = 1.3;

// [albedo] as the sea leaves it at [world_pos] on a face turned to [world_normal], at
// [time]; [lap] is how much of the lap line lies there, for the glow the caller adds
// to its emission.
vec3 sea_waterline(vec3 albedo, vec3 world_pos, vec3 world_normal, float time, out float lap) {
	float above = world_pos.y - sea_ripple(world_pos.xz, time);
	albedo *= above > 0.0 ? mix(0.72, 1.0, smoothstep(0.0, wet_height, above)) : 1.0;
	float steep = 1.0 - abs(normalize(world_normal).y);
	float wash = sin(world_pos.x * 2.3 + world_pos.z * 1.7 + time * 1.6);
	lap = 1.0 - smoothstep(0.6, 1.0, above / (lap_width * (0.75 + 0.25 * wash)));
	lap *= step(-0.01, above) * smoothstep(0.35, 0.7, steep);
	return mix(albedo, lap_colour.rgb, lap);
}

// The share of each colour of the light over the sea that reaches a face at
// [world_pos] at [time]: all of it at the surface or above it, less and bluer the
// deeper it lies. The caller dims its colour, and whatever light it gives off, by it.
vec3 sea_light(vec3 world_pos, float time) {
	float under = max(sea_ripple(world_pos.xz, time) - world_pos.y, 0.0);
	return exp(-SEA_ABSORPTION * under * LIGHT_SLANT);
}
