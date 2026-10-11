// The iceberg (Iceberg): flat faces of ice, lit by the dusk's sun and sky, and hazed
// into the horizon over distance exactly as the sea under it is (water.gdshader) —
// so far off it is a pale shape in the haze, never a flat white cut-out — or, with
// the eye under the sea, into the fog the view under it has.
shader_type spatial;
render_mode cull_back;

#include "res://scenes/art/dusk.gdshaderinc"

uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform float haze_begin = 16.0;
uniform float haze_end = 650.0;
uniform vec4 under_fog_colour : source_color = vec4(0.03, 0.17, 0.26, 1.0);
uniform float under_fog_end = 7.0;
uniform float under_fog_curve = 1.0;
// Whether the eye is under the sea (Underwater).
uniform bool under = false;

varying vec3 world_vertex;

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	vec3 look = world_vertex - CAMERA_POSITION_WORLD;
	float dist = length(look);
	if (under) {
		FOG = vec4(under_fog_colour.rgb, pow(clamp(dist / under_fog_end, 0.0, 1.0), under_fog_curve));
	} else {
		float haze = pow(smoothstep(haze_begin, haze_end, dist), 0.55);
		FOG = vec4(dusk_sky(look / max(dist, 0.001), sun_direction), haze);
	}
}
