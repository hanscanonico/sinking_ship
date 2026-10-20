// The water on the lens after the eye surfaces (LensDrops): a dozen drops, each its
// own from a hash of its number — where it starts, how big, how fast it slides — run
// down the view, leaving a short thinning streak over them. Inside a drop the view
// behind is bent and flipped a little, as a bead of water does, and its rim is dark;
// the whole fades with how wet the lens still is.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
// How wet the lens is, 1 just surfaced to 0 dry (LensDrops.wetness).
uniform float wet = 0.0;
// Seconds since the eye came up: how far each drop has slid.
uniform float since = 0.0;

const int DROPS = 12;
// A drop's radius, as a share of the view's height, smallest to largest.
const vec2 RADIUS = vec2(0.018, 0.045);
// How fast a drop starts sliding, in view heights a second, and how it speeds up.
const vec2 SPEED = vec2(0.05, 0.18);
const float GRAVITY = 0.12;
// How long a streak trails over its drop, at most, in view heights, and how wide it
// runs as a share of its drop.
const float STREAK = 0.14;
const float STREAK_WIDTH = 0.35;
// How far the view is bent inside a drop, as a share of how far from its middle: past
// 1 the view behind shows flipped and shrunk, as through a bead. How dark its rim, how
// bright the glint of light on its upper side, and how far a streak bends what is
// behind it, as a share of its width.
const float BEND = 2.6;
const float RIM = 0.4;
const float GLINT = 0.45;
const float STREAK_BEND = 1.5;

vec4 hash4(float n) {
	vec4 p = fract(vec4(n) * vec4(0.1031, 0.1030, 0.0973, 0.1099) + 0.37);
	p += dot(p, p.wzxy + 33.33);
	return fract((p.xxyz + p.yzzw) * p.zywx);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 at = vec2(UV.x * aspect, UV.y);
	vec2 bend = vec2(0.0);
	float cover = 0.0;
	float rim = 0.0;
	float glint = 0.0;
	for (int i = 0; i < DROPS; i++) {
		vec4 h = hash4(float(i) + 1.0);
		float radius = mix(RADIUS.x, RADIUS.y, h.z * h.z);
		float speed = mix(SPEED.x, SPEED.y, h.w);
		// Big drops slide quicker, as on glass.
		float slid = speed * since + 0.5 * GRAVITY * h.z * since * since;
		vec2 centre = vec2(h.x * aspect, mix(-0.05, 0.75, h.y) + slid);
		vec2 off = at - centre;
		// A bead a little taller than wide.
		vec2 shaped = off / vec2(radius, radius * 1.2);
		float r = length(shaped);
		float drop = 1.0 - smoothstep(0.85, 1.0, r);
		if (drop > cover) {
			cover = drop;
			bend = -off * BEND;
			rim = smoothstep(0.6, 0.95, r) * drop;
			glint = 1.0 - smoothstep(0.0, 0.22, length(shaped - vec2(-0.3, -0.4)));
		}
		// The streak it leaves above it, as long as it has slid, thinning upward.
		float trail = clamp(slid, 0.0, STREAK);
		float up = clamp(-off.y / max(trail, 1e-4), 0.0, 1.0);
		float width = radius * STREAK_WIDTH * (1.0 - up);
		float across = off.x / max(width, 1e-5);
		float streak = (1.0 - smoothstep(0.6, 1.0, abs(across)));
		streak *= step(off.y, 0.0) * step(-trail, off.y) * (1.0 - up);
		if (streak > cover) {
			cover = streak;
			bend = vec2(-across * width * STREAK_BEND, 0.0);
			rim = 0.0;
			glint = 0.0;
		}
	}
	vec2 look = SCREEN_UV + vec2(bend.x / aspect, bend.y);
	vec3 behind = texture(screen, look).rgb;
	behind *= 1.0 - RIM * rim;
	behind += vec3(GLINT * glint);
	COLOR = vec4(behind, cover * wet);
}
