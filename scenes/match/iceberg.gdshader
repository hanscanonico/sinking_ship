// The iceberg (Iceberg): glacier ice, lit by the dusk's sun and sky. Snow lies on what
// faces up; the cliffs are old ice laid down in strata, a band of bluer ice here and
// there among them, fluted by melt running down them and cut through by a crevasse
// refrozen blue; the sea's wash has worn a band of clear, wet, greener ice over the
// waterline, and foam climbs it and drains away as the swell runs up and falls back.
// Ice passes the light on under its surface, so its faces in shadow glow a pale blue
// rather than going grey, and with the eye toward the sun its edges glow through.
// Under the sea it is lit by what light gets down to it (sea_light), as her hull is.
// The patterns ride in the berg's own frame, so they move with it as it drifts; the
// finest fade out with the distance before they can shimmer.
//
// Fogged as the dusk fogs the ship, though never wholly — far off it is a pale shape
// in the fog, as the sea is, where the ship would be lost in it — and hazed into the
// horizon over distance as the sea under it is (water.gdshader); or, with the eye
// under the sea, fogged as the view under it is.
shader_type spatial;
render_mode cull_back;

#include "res://scenes/art/dusk.gdshaderinc"
#include "res://scenes/art/waterline.gdshaderinc"

uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform float haze_begin = 16.0;
uniform float haze_end = 650.0;
// The dusk's fog (Environment), and the most of it the ice ever takes.
uniform vec4 fog_colour : source_color = vec4(0.78, 0.64, 0.63, 1.0);
uniform float fog_begin = 16.0;
uniform float fog_end = 110.0;
uniform float fog_curve = 1.6;
uniform float fog_most = 0.7;
uniform vec4 under_fog_colour : source_color = vec4(0.03, 0.17, 0.26, 1.0);
uniform float under_fog_end = 7.0;
uniform float under_fog_curve = 1.0;
// Whether the eye is under the sea (Underwater).
uniform bool under = false;

// The snow, the old blue ice of its bands and crevasses, and the clear ice the sea has
// washed smooth over the waterline.
uniform vec4 snow_colour : source_color = vec4(0.96, 0.97, 0.98, 1.0);
uniform vec4 blue_ice_colour : source_color = vec4(0.22, 0.5, 0.74, 1.0);
uniform vec4 washed_colour : source_color = vec4(0.42, 0.8, 0.82, 1.0);
// The light the ice passes on under its surface: how much it lifts every face, and
// how much more glows through its edges with the eye toward the sun.
uniform vec4 scatter_colour : source_color = vec4(0.5, 0.76, 0.92, 1.0);
uniform float scatter = 0.35;
uniform float backlight = 0.9;
// How steep a face still holds snow: its normal's height, 0…1.
uniform float snow_slope = 0.5;
// Strata: layers a metre, and how blue the bands among them are.
uniform float strata = 1.6;
uniform float band_blue = 0.35;
// How deep the melt's flutes are cut, and the crevasse's blue.
uniform float flute_depth = 0.06;
uniform float crevasse_blue = 0.5;
// Metres over the sea the clear washed band reaches, and the swell's run up it at
// most; the foam it leaves, and the light the foam gives back even in shadow.
uniform float washed_height = 1.4;
uniform float wash_height = 0.8;
uniform vec4 foam_colour : source_color = vec4(0.97, 1.0, 0.99, 1.0);
uniform float foam_glow = 0.55;
// Metres from the eye over which the fine detail fades out.
uniform float detail_reach = 140.0;

// One layer of the strata in BAND_EVERY is a band of bluer ice, or would be: half of
// them are.
const float BAND_EVERY = 3.0;
// The swell runs up the ice from 2 − WASH_MOST to WASH_MOST of wash_height round the
// berg.
const float WASH_MOST = 1.3;

// The berg's own frame: metres, the sea at y = 0.
varying vec3 berg_pos;
varying vec3 berg_normal;
varying vec3 world_vertex;

void vertex() {
	berg_pos = VERTEX;
	berg_normal = NORMAL;
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Value noise in space, 0…1.
float noise3(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(
			mix(hash3(cell), hash3(cell + vec3(1.0, 0.0, 0.0)), u.x),
			mix(hash3(cell + vec3(0.0, 1.0, 0.0)), hash3(cell + vec3(1.0, 1.0, 0.0)), u.x),
			u.y
		),
		mix(
			mix(hash3(cell + vec3(0.0, 0.0, 1.0)), hash3(cell + vec3(1.0, 0.0, 1.0)), u.x),
			mix(hash3(cell + vec3(0.0, 1.0, 1.0)), hash3(cell + vec3(1.0, 1.0, 1.0)), u.x),
			u.y
		),
		u.z
	);
}

void fragment() {
	vec3 p = berg_pos;
	vec3 n = normalize(berg_normal);
	vec3 look = world_vertex - CAMERA_POSITION_WORLD;
	float dist = length(look);
	vec3 sun = normalize(sun_direction);
	// Metres of ice a pixel spans here: the finer patterns go before they shimmer.
	float footprint = max(length(dFdx(world_vertex)), length(dFdy(world_vertex)));
	float detail = 1.0 - smoothstep(detail_reach * 0.4, detail_reach, dist);
	float fine = detail * (1.0 - smoothstep(0.03, 0.12, footprint));
	float steep = 1.0 - smoothstep(0.55, 0.85, abs(n.y));
	float above = world_vertex.y - sea_ripple(world_vertex.xz, TIME);

	// Strata: thin level layers, warped as the glacier flowed and tilted as the berg
	// calved, each a little lighter or darker than the next; and here and there among
	// them a band of old blue ice, coming and going along its length.
	float warp = noise3(p * vec3(0.11, 0.05, 0.11));
	float uneven = noise3(p * vec3(0.4, 1.1, 0.4) + 21.0);
	float layer = p.y * strata + (warp - 0.5) * 4.0 + (uneven - 0.5) * 0.9;
	layer += p.x * 0.08 + p.z * 0.05;
	float under_layer = hash3(vec3(floor(layer) - 1.0, 1.0, 9.0));
	float this_layer = hash3(vec3(floor(layer), 1.0, 9.0));
	float shade = mix(under_layer, this_layer, smoothstep(0.0, 0.3, fract(layer)));
	shade = mix(1.0, mix(0.96, 1.02, shade), fine);
	float coarse = layer / BAND_EVERY;
	float banding = step(0.5, hash3(vec3(floor(coarse), 7.0, 3.0)));
	banding *= smoothstep(0.45, 0.75, noise3(p * 0.2 + 3.0));
	float band = 1.0 - smoothstep(0.02, 0.09, abs(fract(coarse) - 0.5));
	float banded = band * banding * band_blue * fine;
	// A crevasse the glacier opened and its melt refroze in: a sheet of clear blue ice
	// straight through the berg, a stripe down its cliffs where it comes out, here
	// plain and there lost in the white.
	float wander = (noise3(p * vec3(0.3, 0.1, 0.3)) - 0.5) * 0.6;
	float sheet = abs(dot(p, vec3(0.8, 0.22, 0.56)) - 2.0 + wander);
	float crevasse = 1.0 - smoothstep(0.12, 0.4, sheet);
	crevasse *= smoothstep(0.3, 0.6, noise3(p * 0.15 + 9.0)) * crevasse_blue * detail;
	// Flutes the melt cuts running down a cliff.
	float flute = noise3(vec3(p.x * 1.4, p.y * 0.12, p.z * 1.4));
	// Snow wherever a face holds it, raggedly at its edge.
	float drift = noise3(p * 0.7 + 11.0);
	float snow = smoothstep(snow_slope - 0.1, snow_slope + 0.1, n.y + (drift - 0.5) * 0.4);

	// The swell's run up the ice and back, rising and falling round the berg, and the
	// broken foam it leaves under the line it reached; wet ice a little over that. None
	// of it under the sea, nor higher than the swell ever runs.
	float foam = 0.0;
	float wet = 0.0;
	if (above >= 0.0 && above < wash_height * WASH_MOST * 1.6 + 0.1) {
		float swell = sin(TIME * 0.9 + dot(world_vertex.xz, vec2(0.31, 0.19)));
		float reach = mix(2.0 - WASH_MOST, WASH_MOST, noise3(p * vec3(0.8, 0.0, 0.8)));
		float run = wash_height * (0.55 + 0.45 * swell) * reach;
		// Two drifts of froth turned off the berg's axes and each other's, so no grid
		// shows.
		vec3 q = vec3(p.x * 0.8 + p.z * 0.6, p.y, p.z * 0.8 - p.x * 0.6);
		float froth = noise3(vec3(q.x * 2.2, q.y * 4.0 - TIME * 0.5, q.z * 2.2)) * 0.65;
		froth += noise3(vec3(q.z * 5.1, q.y * 7.0 - TIME * 0.9, q.x * 5.1) + 4.0) * 0.35;
		foam = (1.0 - smoothstep(run * 0.5, run, above)) * smoothstep(0.42, 0.62, froth);
		foam = max(foam, 1.0 - smoothstep(0.03, 0.08, above)) * steep * detail;
		wet = 1.0 - smoothstep(run, run * 1.6 + 0.1, above);
	}
	float washed = 1.0 - smoothstep(washed_height * 0.3, washed_height, above);

	// The model's ice, its strata, bands and crevasse on the cliffs, the snow, and the
	// sea's washed band, wet as high as the swell runs.
	float blue = (banded + crevasse) * steep * (1.0 - washed);
	vec3 ice = COLOR.rgb * shade;
	ice = mix(ice, blue_ice_colour.rgb, blue);
	ice *= mix(1.0, 0.86, smoothstep(0.4, 0.8, flute) * steep * detail);
	ice = mix(ice, snow_colour.rgb, snow * (1.0 - washed));
	ice = mix(ice, washed_colour.rgb, washed * 0.65);
	ice *= mix(1.0, 0.78, wet);
	// The light glowing back out of the ice: bluest in its blue ice and its clear washed
	// band, least through snow, and most where no sun falls to outshine it.
	vec3 view_normal = NORMAL;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(view_normal, 0.0)).xyz;
	float sunward = max(dot(world_normal, sun), 0.0);
	float glowing = scatter * (1.0 + blue * 0.6 + washed * 0.8) * mix(1.0, 0.45, snow);
	vec3 emission = dusk_dim(scatter_colour.rgb) * glowing * (1.6 - sunward) * ice;

	// Its edges with the eye toward the sun: the light through the thin ice there.
	float rim = pow(1.0 - clamp(dot(view_normal, VIEW), 0.0, 1.0), 3.0);
	float toward = pow(max(dot(look / max(dist, 0.001), sun), 0.0), 3.0);
	emission += dusk_dim(scatter_colour.rgb) * backlight * rim * toward * (1.0 - snow * 0.5);

	ice = mix(ice, foam_colour.rgb, foam);
	emission = mix(emission, foam_colour.rgb * foam_glow, foam);

	// Under the sea, lit only by what light gets down to it.
	vec3 light_left = sea_light(world_vertex, TIME);
	ALBEDO = ice * light_left;
	EMISSION = emission * light_left;
	ROUGHNESS = mix(mix(0.5, 0.85, snow), 0.15, max(wet, washed * 0.6));
	SPECULAR = 0.5;

	// The flutes in relief: the normal bent by their slope across the screen.
	float relief = flute * flute_depth * steep * fine;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 across_y = cross(dpdy, view_normal);
	vec3 across_x = cross(view_normal, dpdx);
	float det = dot(dpdx, across_y);
	vec3 slope = sign(det) * (dFdx(relief) * across_y + dFdy(relief) * across_x);
	NORMAL = normalize(abs(det) * view_normal - slope);

	if (under) {
		FOG = vec4(under_fog_colour.rgb, pow(clamp(dist / under_fog_end, 0.0, 1.0), under_fog_curve));
	} else {
		float haze = pow(smoothstep(haze_begin, haze_end, dist), 0.55);
		float fog = pow(clamp((dist - fog_begin) / max(fog_end - fog_begin, 0.001), 0.0, 1.0), fog_curve);
		fog *= fog_most;
		float most = max(haze, fog);
		vec3 sky = dusk_sky(look / max(dist, 0.001), sun);
		FOG = vec4(mix(fog_colour.rgb, sky, haze / max(most, 0.0001)), most);
	}
}
