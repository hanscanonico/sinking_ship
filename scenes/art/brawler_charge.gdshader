// A charge's sparks and speed lines (BrawlerCharge): every streak is a quad its
// vertices start collapsed on — a spark on the fist or shoulder it streams off, a
// line on the chest — and this shader flies, stretches and fades it from TIME, so
// nothing moves on the CPU. NORMAL is the way the body faces; COLOR.r a streak's
// seed, COLOR.g 0 for a spark and 1 for a line, COLOR.b a line's height; UV.x runs
// -1…1 across a streak, UV.y 0 at its tail to 1 at its head.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, world_vertex_coords;

uniform vec3 hot : source_color = vec3(1.0, 0.5, 0.12);
uniform vec3 core : source_color = vec3(1.0, 0.95, 0.75);
// How full the charge is, 0…1, and how much of a walk it moves at, 0…1.
uniform float fill = 0.0;
uniform float moving = 0.0;

// Of the sparks, the share that fly at an empty charge; all of them at a full one,
// faster, longer and brighter.
const float SPARKS_FROM = 0.3;
const float SPARK_RATE = 1.8;
const float SPARK_RATE_FULL = 3.4;
const float SPARK_RISE = 1.5;
const float SPARK_BACK = 0.9;
const float SPARK_FLIGHT = 0.4;
const float SPARK_WIDTH = 0.016;
// A speed line: how far behind the body it starts and runs, how long and wide.
const float LINE_RATE = 2.2;
const float LINE_FROM = 0.3;
const float LINE_RUN = 0.9;
const float LINE_LENGTH = 0.55;
const float LINE_WIDTH = 0.014;

varying vec2 across_along;
varying float shown;

void vertex() {
	float seed = COLOR.r;
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 ahead = NORMAL - up * dot(NORMAL, up);
	ahead = length(ahead) > 0.001 ? normalize(ahead) : vec3(1.0, 0.0, 0.0);
	vec3 side = cross(up, ahead);
	vec3 head;
	vec3 tail;
	if (COLOR.g < 0.5) {
		float rate = mix(SPARK_RATE, SPARK_RATE_FULL, fill);
		float life = fract(TIME * rate + seed * 13.7);
		float lateral = fract(seed * 91.3) - 0.5;
		vec3 flight = up * SPARK_RISE * (0.7 + 0.6 * fract(seed * 37.1)) - ahead * SPARK_BACK
			+ side * lateral;
		head = VERTEX + flight * life * SPARK_FLIGHT;
		tail = head - flight * (0.03 + 0.04 * fill);
		float flying = step(seed, mix(SPARKS_FROM, 1.0, fill));
		shown = flying * (1.0 - life) * smoothstep(0.0, 0.08, life) * (0.6 + 0.4 * fill);
	} else {
		float phase = fract(TIME * LINE_RATE + seed * 5.3);
		float lateral = (fract(seed * 7.9) - 0.5) * 0.7;
		head = VERTEX + up * COLOR.b + side * lateral - ahead * (LINE_FROM + phase * LINE_RUN);
		tail = head - ahead * LINE_LENGTH * moving;
		shown = moving * (0.4 + 0.6 * fill) * sin(phase * PI);
	}
	vec3 middle = mix(tail, head, UV.y);
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 width = cross(head - tail, eye - middle);
	float wide = COLOR.g < 0.5 ? SPARK_WIDTH : LINE_WIDTH;
	width = length(width) > 0.00001 ? normalize(width) * wide : vec3(0.0);
	VERTEX = middle + width * UV.x * step(0.001, shown);
	across_along = UV;
}

void fragment() {
	float edge = 1.0 - abs(across_along.x);
	float along = across_along.y;
	// A hot white core along the middle and the head, an ember rim, crisp edges.
	ALBEDO = mix(hot, core, smoothstep(0.4, 0.9, edge) * (0.4 + 0.6 * along));
	ALPHA = clamp(shown * smoothstep(0.0, 0.35, edge) * (0.5 + 0.5 * along) * 1.5, 0.0, 1.0);
}
