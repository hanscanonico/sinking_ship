// Rings spreading over the water round the bodies in it, shared by the sea
// (water.gdshader) and the water in her cells (inner_water.gdshader): the nearest
// bodies to the eye that wade or swim (MatchView.waders), each a world foot point on
// the water it is in and how fast it moves, 0…1. A ring on one sheet only — its water's
// height — fading out within WADER_REACH of its body, brighter the faster it goes.
// With no wader_count none is worked out at all.

const int WADER_SLOTS = 8;
// Metres a ring reaches out to, how far apart rings run, per metre, and how fast
// they spread; the share of a ring's crest that is white; how far off the body's water
// a sheet still takes its rings.
const float WADER_REACH = 6.0;
const float WADER_SPACING = 1.5;
const float WADER_PACE = 1.2;
const float WADER_CREST = 0.44;
const float WADER_SHEET = 0.5;

uniform vec4 waders[WADER_SLOTS];
uniform int wader_count = 0;

// How white the rings round the waders make the water at the world point [at], 0…1.
float wader_rings(vec3 at, float time) {
	float rings = 0.0;
	for (int i = 0; i < wader_count; i++) {
		vec4 wader = waders[i];
		float r = distance(at.xz, wader.xz);
		if (r > WADER_REACH || abs(at.y - wader.y) > WADER_SHEET) {
			continue;
		}
		float crest = abs(fract(r * WADER_SPACING - time * WADER_PACE) - 0.5) - WADER_CREST;
		float ring = smoothstep(0.0, 0.5 - WADER_CREST, crest);
		ring *= exp(-r * 0.6) * (0.3 + 0.7 * wader.w);
		ring *= 1.0 - smoothstep(WADER_REACH * 0.7, WADER_REACH, r);
		rings = max(rings, ring);
	}
	return rings;
}
