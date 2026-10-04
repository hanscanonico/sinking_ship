// A brawler's clothes and face, painted on the mannequin per pixel from where each
// point sits on it at rest (Brawler builds the mesh: UV holds rest x and y, UV2.x
// rest z; UV2.y is 0 on the body, and runs from 1 at a coat skirt's waist to 2 at
// its hem outside, from 3 to 4 inside). Rest space is model units: the soles
// at 0, the crown at 1.83, facing +z, arms out along x. Painting from rest keeps
// every edge crisp and riding the skin as the rig bends, for no geometry at all.
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec3 coat : source_color = vec3(0.84, 0.37, 0.0);
uniform vec3 trousers : source_color = vec3(0.23, 0.24, 0.27);
uniform vec3 skin : source_color = vec3(0.88, 0.67, 0.53);
uniform vec3 hair : source_color = vec3(0.18, 0.13, 0.1);
uniform vec3 shirt : source_color = vec3(0.92, 0.9, 0.84);
uniform vec3 leather : source_color = vec3(0.29, 0.2, 0.13);
uniform vec3 ink : source_color = vec3(0.137, 0.149, 0.18);
// Buttons and badges.
uniform vec3 trim : source_color = vec3(0.72, 0.57, 0.23);
// 0 a jersey, 1 a jacket over a shirt, 2 a greatcoat (Brawler.Coat).
uniform int garment = 0;
// How low the coat's skirt hangs, in rest height (Brawler.SKIRT_HEMS).
uniform float skirt_hem = 1.0;
// 0 clean-shaven, 1 a moustache, 2 a full beard (Brawler.Whiskers).
uniform int whiskers = 0;
// The hands' glow as a shove winds up and lands, 0…1.
uniform vec3 flash_colour : source_color = vec3(1.0);
uniform float flash = 0.0;
// A shove coming, 0…1: a wind-up's warmth, rising through a charge to 1 when it is
// full. It lights the body's edge — never its middle, which keeps the seat's colour
// — and the forearms, from ember toward white-hot, beating faster as it rises.
uniform vec3 heat_colour : source_color = vec3(1.0, 0.42, 0.08);
uniform vec3 heat_core : source_color = vec3(1.0, 0.94, 0.76);
uniform float heat = 0.0;

const float LINING_LIFT = 0.3;
// The legs under a skirt take the sun's shadow of it as well as the lining's dark;
// below the hem they are lifted by no brighter a colour than LEG_CAP, so a pale
// coat's lining never lights pale legs in a dark room.
const float LEG_LIFT = 0.45;
const float LEG_CAP = 0.3;
// The heat's rim: how tightly it hugs the edge, how bright it burns, and its beat
// from a wind-up's to a full charge's, in radians a second. The forearms glow from
// FOREARM_FROM out to the cuff.
const float RIM_POWER = 2.5;
const float RIM_GLOW = 2.2;
const float BEAT_SLOW = 9.0;
const float BEAT_FAST = 24.0;
const float FOREARM_FROM = 0.5;

varying vec3 rest;
varying float skirt;

void vertex() {
	rest = vec3(UV.x, UV.y, UV2.x);
	skirt = UV2.y;
}

// 1 inside the ellipse at centre c with radii r, in the face's x/y.
float spot(vec2 p, vec2 c, vec2 r) {
	vec2 d = (p - c) / r;
	return step(dot(d, d), 1.0);
}

vec3 face(vec3 base) {
	vec2 p = vec2(abs(rest.x), rest.y);
	// Hair over the crown and down the back of the head, a hairline at the brow.
	float line = 1.785 - 0.1 * smoothstep(0.04, -0.06, rest.z);
	vec3 c = rest.y > line ? hair : base;
	if (rest.z < 0.045) {
		return c;
	}
	// The features are inked a little lighter than the outline, so the face stays
	// a face rather than holes.
	vec3 drawn = mix(base, ink, 0.6);
	// A nose: its shaded side and its foot, under the eyes.
	if (rest.x > 0.003 && rest.x < 0.008 && p.y > 1.652 && p.y < 1.682) {
		c = drawn;
	}
	if (p.x < 0.011 && abs(p.y - 1.652) < 0.0025) {
		c = drawn;
	}
	// A mouth, set straight: a curve either way reads as a grin or a scowl.
	bool mouth = p.x < 0.017 && abs(p.y - 1.628) < 0.0022;
	if (mouth) {
		c = drawn;
	}
	// A moustache under the nose, parted and drooping to its tapered ends — level and
	// wide, one reads as a grin up close — and with a beard round the jaw, clear of
	// the lips.
	float droop = 1.641 - 0.3 * max(p.x - 0.01, 0.0);
	float taper = 0.008 * (1.0 - 0.5 * p.x / 0.036);
	if (whiskers > 0 && p.x > 0.002 && p.x < 0.036 && abs(p.y - droop) < taper) {
		c = hair;
	}
	bool lips = p.x < 0.022 && abs(p.y - 1.629) < 0.006;
	if (whiskers == 2 && rest.y < 1.62 + 0.4 * p.x && !lips) {
		c = hair;
	}
	// Eyes: an ink pupil in a pale ring, so they read in a brim's shade as well.
	if (spot(p, vec2(0.032, 1.69), vec2(0.0145, 0.019)) > 0.5) {
		c = mix(shirt, base, 0.35);
	}
	if (spot(p, vec2(0.03, 1.688), vec2(0.0095, 0.0145)) > 0.5) {
		c = ink;
	}
	// Brows, tipped down toward the nose: a frown that reads from across a deck.
	float brow_y = 1.722 + 0.22 * (p.x - 0.033);
	if (abs(p.y - brow_y) < 0.0075 && p.x > 0.013 && p.x < 0.056) {
		c = mix(hair, ink, 0.5);
	}
	return c;
}

vec3 torso(float ax) {
	float y = rest.y;
	if (garment == 0) {
		// A fisherman's jersey: a ribbed roll neck and welt, over a belt.
		if (y < 0.975) {
			return y > 0.935 ? leather : trousers;
		}
		return y < 1.03 ? coat * 0.78 : coat;
	}
	float hem = garment == 2 ? 0.0 : 0.86;
	if (garment == 1 && rest.z > 0.0) {
		// A jacket's fronts part below the last button.
		hem = mix(0.98, hem, smoothstep(0.02, 0.1, ax));
	}
	if (y < hem) {
		return trousers;
	}
	// The coat's front opens on a shirt and a neckerchief, below a turned collar.
	float open_from = garment == 2 ? 1.36 : 1.2;
	float open = (y - open_from) * (garment == 2 ? 0.3 : 0.26);
	if (rest.z > 0.03 && ax < open) {
		return ax < 0.016 && y < 1.44 ? ink : shirt;
	}
	if (rest.z > 0.03 && ax < open + 0.014 && y > open_from) {
		return coat * 0.72;
	}
	// Buttons down the front: one row on a jacket, two on a greatcoat.
	float row = garment == 2 ? 0.06 : 0.0;
	float pitch = 0.09;
	float near_button = abs(fract((y - 0.02) / pitch) - 0.5) * pitch;
	float top = garment == 2 ? 1.36 : 1.18;
	if (rest.z > 0.05 && y > 0.9 && y < top && abs(ax - row) < 0.013 && near_button < 0.012) {
		return trim;
	}
	return coat;
}

void fragment() {
	float ax = abs(rest.x);
	vec3 c;
	float glow = 0.0;
	float forearm = 0.0;
	// The lining, inside a skirt and on the thighs under it, and the legs just below
	// the hem stand in the skirt's shadow: lifted by the lining's own colour — dark
	// trousers would gain nothing from a lift in proportion to theirs — so they read
	// as cloth rather than a hole.
	vec3 lining = coat * 0.78;
	vec3 shade = lining;
	float lift = 0.0;
	if (skirt > 2.5) {
		c = lining;
		lift = LINING_LIFT;
	} else if (skirt > 0.5) {
		c = skirt > 1.93 ? coat * 0.78 : coat;
	} else if (ax > 0.22 && rest.y > 1.25) {
		// The arm: a sleeve, a cuff — the jersey's rib or the shirt's — and a hand.
		forearm = smoothstep(FOREARM_FROM, 0.745, ax);
		if (ax > 0.745) {
			c = skin;
			glow = flash;
		} else if (ax > 0.7) {
			c = garment == 0 ? coat * 0.78 : shirt;
		} else {
			c = coat;
		}
	} else if (rest.y > 1.54) {
		c = face(skin);
	} else if (rest.y > 1.47 && ax < 0.1) {
		// The neck, inside the jersey's roll or a collar turned up on the coat.
		c = garment == 0 ? coat * 0.78 : (rest.y > 1.505 ? skin : shirt);
	} else if (rest.y > 0.86) {
		c = torso(ax);
	} else if (rest.y > 0.17) {
		// Under a skirt the thighs wear the coat's lining, so none shows through it.
		bool under = garment == 2 || garment == 1 && rest.z < 0.0;
		c = under && rest.y > skirt_hem ? coat * 0.78 : trousers;
		// Fading out down the leg below the hem, as the skirt's shadow does, and only
		// behind, where the tails hang: in front the legs stand clear of the hem.
		float behind = rest.y > skirt_hem ? 1.0 : smoothstep(0.03, -0.03, rest.z);
		float leg = rest.y > skirt_hem ? LINING_LIFT : LEG_LIFT;
		lift = under ? leg * smoothstep(skirt_hem - 0.35, skirt_hem, rest.y) * behind : 0.0;
		shade = rest.y > skirt_hem ? lining : min(lining, vec3(LEG_CAP));
	} else {
		// Boots, with a turned-down top.
		c = rest.y > 0.145 ? leather * 1.25 : leather * 0.6;
	}
	// The glow tints the hand as well as lighting it, so it reads from across a deck
	// without washing the hand out to a blank shape up close.
	ALBEDO = mix(c, flash_colour, glow * 0.5);
	ROUGHNESS = 0.8;
	EMISSION = flash_colour * glow * 0.8 + shade * lift;
	if (heat > 0.0) {
		float beat = 0.8 + 0.2 * sin(TIME * mix(BEAT_SLOW, BEAT_FAST, heat));
		float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), RIM_POWER);
		vec3 burn = mix(heat_colour, heat_core, heat * heat * max(edge, forearm));
		EMISSION += burn * (edge * RIM_GLOW + forearm) * heat * beat;
	}
}
