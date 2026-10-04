// The dusk the sky (sky.gdshader) and the sea (water.gdshader) share: one
// gradient, so the far sea fades into exactly the colour the sky has just above
// the horizon and the two meet in one line. Below the horizon it holds the
// horizon's colour. gloom (0…1) dims and cools it all as the sinking advances
// (SeaAndSky) — presentation only.

uniform vec4 zenith_colour : source_color = vec4(0.2, 0.24, 0.43, 1.0);
uniform vec4 high_colour : source_color = vec4(0.48, 0.42, 0.6, 1.0);
uniform vec4 low_colour : source_color = vec4(0.82, 0.55, 0.56, 1.0);
uniform vec4 horizon_colour : source_color = vec4(0.93, 0.68, 0.55, 1.0);
// The horizon under the sun, and the halo round it.
uniform vec4 glow_colour : source_color = vec4(1.0, 0.8, 0.56, 1.0);
// What the dusk greys toward as it dims.
uniform vec4 gloom_colour : source_color = vec4(0.36, 0.38, 0.52, 1.0);
uniform float gloom : hint_range(0.0, 1.0) = 0.0;

// How far round the horizon toward the sun [dir] looks: 1 under it, 0 away.
float dusk_toward(vec3 dir, vec3 sun) {
	return dot(normalize(dir.xz + vec2(1e-5)), normalize(sun.xz + vec2(1e-5))) * 0.5 + 0.5;
}

vec3 dusk_dim(vec3 colour) {
	float grey = dot(colour, vec3(0.3, 0.55, 0.15));
	return mix(colour, gloom_colour.rgb * grey * 1.4, gloom * 0.45) * (1.0 - 0.3 * gloom);
}

// The sky along [dir] with the sun toward [sun], both unit vectors.
vec3 dusk_sky(vec3 dir, vec3 sun) {
	vec3 d = normalize(vec3(dir.x, max(dir.y, 0.0), dir.z));
	float toward = dusk_toward(d, sun);
	vec3 colour = mix(horizon_colour.rgb, glow_colour.rgb, toward * toward * toward);
	colour = mix(colour, low_colour.rgb, smoothstep(0.0, 0.14, d.y));
	colour = mix(colour, high_colour.rgb, smoothstep(0.1, 0.45, d.y));
	colour = mix(colour, zenith_colour.rgb, smoothstep(0.4, 1.0, d.y));
	// A thin bright line along the horizon, brightest under the sun.
	colour += glow_colour.rgb * exp(-d.y * 60.0) * (0.06 + 0.14 * toward * toward);
	float halo = max(dot(d, sun), 0.0);
	colour += glow_colour.rgb * (0.3 * pow(halo, 6.0) + 0.5 * pow(halo, 60.0));
	return dusk_dim(colour);
}
