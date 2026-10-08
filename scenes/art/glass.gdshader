// A porthole's or a window's glass. Seen from inside it shows the dusk sky while
// it stands above the sea and the sea once the sea is above it — the world plane
// y = 0, the only water there is (D7) — so a flooding room watches its waterline
// climb the glass. Seen from outside it is dark glass over the room's lamp-glow,
// mirroring the sky, until the sea puts it out.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 above_colour : source_color = vec4(0.98, 0.78, 0.6, 1.0);
uniform vec4 high_colour : source_color = vec4(0.55, 0.62, 0.8, 1.0);
uniform vec4 sea_colour : source_color = vec4(0.04, 0.2, 0.24, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.85, 0.93, 0.92, 1.0);
// Brighter than white, so the glow catches the bloom.
uniform float strength = 1.4;
// Metres over which the sky colour climbs from above_colour to high_colour.
uniform float sky_rise = 0.35;
uniform float foam_width = 0.025;
// The observer's cut-away, in ship space: no glass above it; and a piece of a broken
// hull's stretch along her (SH33): no glass outside it.
uniform float cut_above = 1e6;
uniform vec2 piece_span = vec2(-1e6, 1e6);
// Seen from outside (outside = true): dark glass over the warm glow of the lamp-lit
// room behind it, glowing most near its top, under the sky's reflection, which
// takes over as the look grazes it.
uniform bool outside = false;
uniform vec4 tint_colour : source_color = vec4(0.1, 0.11, 0.15, 1.0);
uniform vec4 glow_colour : source_color = vec4(1.0, 0.77, 0.48, 1.0);
uniform float glow = 1.4;
uniform vec4 zenith_colour : source_color = vec4(0.17, 0.23, 0.4, 1.0);
uniform vec4 horizon_colour : source_color = vec4(0.91, 0.63, 0.48, 1.0);
uniform float pane_height = 0.6;
// A diagonal glint across the glass, laid on the ship so it stays put on a pane.
uniform float glint = 0.35;

varying float world_height;
varying float ship_height;
varying vec3 ship_point;

void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	ship_height = VERTEX.y;
	ship_point = VERTEX;
}

vec3 outside_glass(vec3 normal, vec3 view, float reflected_up, float rise) {
	float room = smoothstep(0.0, pane_height, rise);
	vec3 inside = mix(tint_colour.rgb, glow_colour.rgb * glow, 0.4 + 0.6 * room);
	vec3 sky = reflected_up > 0.0
		? mix(horizon_colour.rgb, zenith_colour.rgb, smoothstep(0.0, 0.6, reflected_up))
		: mix(horizon_colour.rgb * 0.7, sea_colour.rgb, smoothstep(0.0, 0.25, -reflected_up));
	float grazing = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 3.0);
	float across = fract(dot(ship_point, vec3(0.8, 1.2, 0.8)) * 1.4);
	float streak = smoothstep(0.0, 0.04, across) * (1.0 - smoothstep(0.1, 0.16, across));
	return mix(mix(inside, sky, 0.18 + 0.7 * grazing), vec3(1.0), glint * streak);
}

void fragment() {
	if (ship_height > cut_above || ship_point.x < piece_span.x || ship_point.x > piece_span.y) {
		discard;
	}
	float h = world_height;
	vec3 colour = h > 0.0
		? mix(above_colour.rgb, high_colour.rgb, clamp(UV.x / sky_rise, 0.0, 1.0)) * strength
		: sea_colour.rgb;
	if (outside && h > 0.0) {
		float up = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).y;
		colour = outside_glass(NORMAL, VIEW, up, UV.x);
	}
	colour = mix(colour, foam_colour.rgb, 1.0 - smoothstep(0.0, foam_width, abs(h)));
	ALBEDO = colour;
}
