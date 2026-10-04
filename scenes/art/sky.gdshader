// The dusk sky (sea_and_sky.tscn): the dusk gradient (dusk.gdshaderinc), the sun's
// disc where the scene's light comes from, and two layers of painted cloud, lit
// warm on the side toward the sun. Below the horizon it darkens to the deep sea.
// The radiance — what the sky lends the scene's ambient light — is not this painted
// dusk, which is far brighter low down, but the plainer gradient the ship's light and
// shade were tuned under (ambient_sky), dimmed with the dusk. No TIME: the radiance is
// drawn again only when the dusk dims.
shader_type sky;

#include "res://scenes/art/dusk.gdshaderinc"

uniform vec4 sun_colour : source_color = vec4(1.0, 0.93, 0.78, 1.0);
// The disc's radius, as 1 - cos of its angle.
uniform float sun_size = 0.0012;
uniform vec4 cloud_lit_colour : source_color = vec4(1.0, 0.7, 0.55, 1.0);
uniform vec4 cloud_shade_colour : source_color = vec4(0.53, 0.42, 0.55, 1.0);
uniform vec4 deep_colour : source_color = vec4(0.06, 0.16, 0.25, 1.0);
// The radiance's gradient: the colours of the ProceduralSkyMaterial this sky replaced,
// and the exponents its default curves (0.15 above the horizon, 0.02 below, 0.15 for
// the sun's glow) come to in Godot's own shader; the glow reaches out to where the
// cosine to the sun falls to AMBIENT_GLOW_EDGE.
uniform vec4 ambient_top_colour : source_color = vec4(0.169, 0.227, 0.404, 1.0);
uniform vec4 ambient_horizon_colour : source_color = vec4(0.914, 0.627, 0.478, 1.0);
uniform vec4 ambient_ground_colour : source_color = vec4(0.424, 0.416, 0.522, 1.0);
uniform vec4 ambient_bottom_colour : source_color = vec4(0.078, 0.133, 0.208, 1.0);
const float AMBIENT_SKY_CURVE = 4.0;
const float AMBIENT_GROUND_CURVE = 30.0;
const float AMBIENT_GLOW_EDGE = 0.877;
const float AMBIENT_GLOW_CURVE = 22.78;

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

float billows(vec2 p) {
	float sum = value_noise(p) * 0.55;
	sum += value_noise(p * 2.1 + 3.7) * 0.28;
	sum += value_noise(p * 4.3 + 9.1) * 0.17;
	return sum;
}

// Cover (0…1) of a layer of cloud at [p] on its ceiling, where more than [cover]
// of the billows build: a firm painted edge.
float cloud(vec2 p, float cover) {
	return smoothstep(cover, cover + 0.05, billows(p));
}

// The radiance along [dir], before the sun's glow: the sky the light and shade of the
// ship were tuned under.
vec3 ambient_sky(vec3 dir) {
	if (dir.y < 0.0) {
		float low = pow(1.0 + dir.y, AMBIENT_GROUND_CURVE);
		return mix(ambient_bottom_colour.rgb, ambient_ground_colour.rgb, low);
	}
	float low = pow(1.0 - dir.y, AMBIENT_SKY_CURVE);
	return mix(ambient_top_colour.rgb, ambient_horizon_colour.rgb, low);
}

// The painted dusk along [dir], with the sun toward [sun]: what the eye sees.
vec3 painted_sky(vec3 dir, vec3 sun) {
	vec3 colour = dusk_sky(dir, sun);
	if (dir.y > 0.0) {
		float toward = dusk_toward(dir, sun);
		// Streaks thin out toward the horizon, where the haze swallows them.
		float fade = smoothstep(0.015, 0.12, dir.y);
		vec2 plane = dir.xz / (dir.y + 0.04);
		vec2 high_at = plane * vec2(0.22, 0.9) + vec2(4.1, 1.3);
		vec2 low_at = plane * vec2(0.4, 1.5) + vec2(-2.6, 7.9);
		float high = cloud(high_at, 0.58) * fade;
		float low = cloud(low_at, 0.6) * fade;
		// The edge toward the sun catches its light: less cloud a step sunward.
		vec2 sunward = normalize(sun.xz + vec2(1e-5)) * 0.18;
		float lit_edge = step(billows(low_at + sunward * vec2(0.4, 1.5)), billows(low_at));
		vec3 shade = mix(cloud_shade_colour.rgb, colour, 0.25);
		vec3 lit = mix(shade, cloud_lit_colour.rgb, 0.35 + 0.65 * toward);
		colour = mix(colour, dusk_dim(mix(shade, lit, 0.5)), high * 0.7);
		colour = mix(colour, dusk_dim(mix(shade, lit, 0.4 + 0.6 * lit_edge)), low * 0.9);
	} else {
		colour = mix(colour, dusk_dim(deep_colour.rgb), smoothstep(0.06, 0.35, -dir.y));
	}
	float disc = smoothstep(1.0 - sun_size * 1.2, 1.0 - sun_size, dot(dir, sun));
	return mix(colour, dusk_dim(sun_colour.rgb) * 1.6, disc);
}

void sky() {
	vec3 dir = EYEDIR;
	if (AT_CUBEMAP_PASS) {
		vec3 colour = ambient_sky(dir);
		if (LIGHT0_ENABLED && dir.y >= 0.0) {
			float edge = cos(LIGHT0_SIZE);
			float off = (edge - dot(LIGHT0_DIRECTION, dir)) / (edge - AMBIENT_GLOW_EDGE);
			float glow = off < 0.0 ? 1.0 : pow(max(1.0 - off, 0.0), AMBIENT_GLOW_CURVE);
			colour = mix(colour, LIGHT0_COLOR * LIGHT0_ENERGY, glow);
		}
		COLOR = dusk_dim(colour);
	} else {
		vec3 sun = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.44, 0.53, 0.73));
		COLOR = painted_sky(dir, sun);
	}
}
