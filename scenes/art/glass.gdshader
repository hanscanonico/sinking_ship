// A porthole's or a window's glass. Seen from inside it shows the dusk sky while
// it stands above the sea and the sea once the sea is above it — the world plane
// y = 0, the only water there is (D7) — so a flooding room watches its waterline
// climb the glass. Seen from outside it glows with the room's lamp until the sea
// puts it out.
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
// The observer's cut-away, in ship space: no glass above it.
uniform float cut_above = 1e6;

varying float world_height;
varying float ship_height;

void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	ship_height = VERTEX.y;
}

void fragment() {
	if (ship_height > cut_above) {
		discard;
	}
	float h = world_height;
	vec3 colour = h > 0.0
		? mix(above_colour.rgb, high_colour.rgb, clamp(UV.x / sky_rise, 0.0, 1.0)) * strength
		: sea_colour.rgb;
	colour = mix(colour, foam_colour.rgb, 1.0 - smoothstep(0.0, foam_width, abs(h)));
	ALBEDO = colour;
}
