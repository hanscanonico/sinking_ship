// The iceberg (Iceberg): flat faces of ice, lit by the dusk's sun and sky; fogged as
// the dusk fogs the ship, though never wholly — far off it is a pale shape in the
// fog, as the sea is, where the ship would be lost in it — and hazed into the
// horizon over distance as the sea under it is (water.gdshader); or, with the eye
// under the sea, fogged as the view under it is.
shader_type spatial;
render_mode cull_back;

#include "res://scenes/art/dusk.gdshaderinc"

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
		float fog = pow(clamp((dist - fog_begin) / max(fog_end - fog_begin, 0.001), 0.0, 1.0), fog_curve);
		fog *= fog_most;
		float most = max(haze, fog);
		vec3 sky = dusk_sky(look / max(dist, 0.001), sun_direction);
		FOG = vec4(mix(fog_colour.rgb, sky, haze / max(most, 0.0001)), most);
	}
}
