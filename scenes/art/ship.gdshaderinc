// Every paint of the dressed ship (ShipArt) in one shader, lit like the crew —
// toon diffuse, no specular — and darkened toward the crew's ink at each face's
// rim, so a box reads as a bevelled piece rather than a box. The mesh is in ship
// space, so a pattern laid on ship coordinates stays put as the ship tilts.
//
// Per vertex (ShipMesh): COLOR is the paint's base colour; UV.x the height above
// the piece's foot and UV.y the depth below its top, for bands of trim; UV2.x how
// far into the face's rim the point lies; UV2.y whether it stands outdoors. An
// indoor face never takes the sun, whatever the shadow map says, and takes only a
// little of the sky's ambient — what the lamps leave dark stays dim, never black;
// an outdoor face takes no lamp.

#include "res://scenes/art/waterline.gdshaderinc"

uniform int finish = 0;
uniform vec4 ink : source_color = vec4(0.137, 0.149, 0.18, 1.0);
uniform float rim_strength = 0.6;
// The share of the sky's ambient light an indoor face keeps.
uniform float indoor_ambient = 0.35;
// How far indoors (0…1) a piece that moves stands — a crate (ShipArt), built
// outdoors: it takes its faces in as it crosses a doorway, never at once.
uniform float indoors = 0.0;
// The share of a lamp's light a face turned away from it still takes: what the
// room's walls would bounce back.
uniform float lamp_bounce = 0.35;
// A deck about to give way (ShipArt.show_sinking): tinted toward flash_colour and
// glowing with it, by flash (0 or 1 as the telegraph blinks).
uniform float flash = 0.0;
uniform vec4 flash_colour : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform float flash_strength = 0.7;

// DECK: planks fore and aft, caulked seams, butts staggered plank to plank.
uniform vec4 seam_colour : source_color = vec4(0.25, 0.17, 0.11, 1.0);
uniform float plank_width = 0.16;
uniform float plank_length = 3.6;
uniform float seam_width = 0.012;
// HULL: red oxide below the boot line, a pale riband under the sheer, and the
// plating's strakes as faint lines.
uniform vec4 bottom_colour : source_color = vec4(0.557, 0.169, 0.133, 1.0);
uniform vec4 riband_colour : source_color = vec4(0.91, 0.886, 0.824, 1.0);
uniform float boot_height = -3.0;
uniform float riband_depth = 0.12;
uniform float strake_height = 0.9;
// HOUSE (a superstructure's outside) and CABIN (a room's inside): a trim band
// under the top, a foot band or a panelled dado up from the foot.
uniform vec4 trim_colour : source_color = vec4(0.54, 0.35, 0.21, 1.0);
uniform vec4 foot_colour : source_color = vec4(0.48, 0.32, 0.21, 1.0);
uniform float trim_depth = 0.16;
uniform float foot_height = 0.12;
uniform float panel_width = 0.55;
// FUNNEL: the black top.
uniform vec4 top_colour : source_color = vec4(0.11, 0.11, 0.12, 1.0);
uniform float top_depth = 1.3;

#ifdef CUT_AWAY
// The observer's cut-away: nothing above it is drawn, and the inside of whatever
// it slices shows as a flat section.
uniform float cut_above = 1e6;
uniform vec4 section_colour : source_color = vec4(0.2, 0.19, 0.2, 1.0);
#endif

const int PLAIN = 0;
const int DECK = 1;
const int HULL = 2;
const int HOUSE = 3;
const int CABIN = 4;
const int FUNNEL = 5;

varying vec3 ship_pos;
varying vec3 ship_normal;
varying vec2 bands;
varying float outdoor;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 1 on a line of half-width [param half] about 0 of [param d], faded out once the
// line would be thinner than a pixel.
float line(float d, float half) {
	float fw = max(fwidth(d), 1e-5);
	return (1.0 - smoothstep(half - fw, half + fw, abs(d))) * clamp(half * 2.0 / fw - 0.5, 0.0, 1.0);
}

vec3 planks(vec3 base) {
	float row = floor(ship_pos.z / plank_width);
	float across = (fract(ship_pos.z / plank_width) - 0.5) * plank_width;
	float along = ship_pos.x / plank_length + hash(vec2(row, 7.0));
	float piece = floor(along);
	float butt = (fract(along) - 0.5) * plank_length;
	float tone = mix(0.86, 1.1, hash(vec2(row, piece)));
	float grain = 0.96 + 0.04 * sin(ship_pos.x * 7.0 + hash(vec2(piece, row)) * 40.0 + sin(ship_pos.z * 31.0));
	vec3 colour = base * tone * grain;
	float seam = max(
		line(abs(across) - plank_width * 0.5, seam_width),
		line(abs(butt) - plank_length * 0.5, seam_width)
	);
	return mix(colour, seam_colour.rgb, seam * 0.85);
}

vec3 hull(vec3 base) {
	float y = ship_pos.y;
	vec3 colour = y < boot_height ? bottom_colour.rgb : base;
	float strake = (fract((y - boot_height) / strake_height) - 0.5) * strake_height;
	colour *= 1.0 - 0.25 * line(abs(strake) - strake_height * 0.5, 0.01);
	return bands.y < riband_depth ? riband_colour.rgb : colour;
}

vec3 house(vec3 base) {
	if (bands.y < trim_depth) {
		return trim_colour.rgb;
	}
	return bands.x < foot_height ? foot_colour.rgb : base;
}

vec3 cabin(vec3 base) {
	float rail = 0.95;
	if (bands.y < 0.07 || abs(bands.x - rail) < 0.035) {
		return trim_colour.rgb;
	}
	if (bands.x < rail) {
		float along = ship_pos.x + ship_pos.z;
		float groove = line((fract(along / panel_width) - 0.5) * panel_width, 0.008);
		return foot_colour.rgb * (1.0 - 0.3 * groove);
	}
	return base;
}

void vertex() {
	ship_pos = VERTEX;
	ship_normal = NORMAL;
	bands = UV;
	outdoor = UV2.y * (1.0 - indoors);
}

void fragment() {
#ifdef CUT_AWAY
	if (ship_pos.y > cut_above) {
		discard;
	}
#endif
	vec3 colour = COLOR.rgb;
	if (finish == DECK && ship_normal.y > 0.5) {
		colour = planks(colour);
	} else if (finish == HULL) {
		colour = hull(colour);
	} else if (finish == HOUSE) {
		colour = house(colour);
	} else if (finish == CABIN) {
		colour = cabin(colour);
	} else if (finish == FUNNEL && bands.y < top_depth) {
		colour = top_colour.rgb;
	}
	float rim = smoothstep(0.0, 1.0, UV2.x);
	ALBEDO = mix(colour, ink.rgb, rim * rim_strength);
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float lap;
	ALBEDO = sea_waterline(ALBEDO, world_pos, world_normal, finish == HULL, TIME, lap);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	AO = mix(indoor_ambient, 1.0, outdoor);
	AO_LIGHT_AFFECT = 0.0;
	ALBEDO = mix(ALBEDO, flash_colour.rgb, flash * flash_strength);
	EMISSION = flash_colour.rgb * flash * flash_strength;
	EMISSION += lap_colour.rgb * lap * 0.2;
#ifdef CUT_AWAY
	if (!FRONT_FACING) {
		ALBEDO = vec3(0.0);
		EMISSION = section_colour.rgb;
	}
#endif
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float lit = LIGHT_IS_DIRECTIONAL
		? smoothstep(0.0, 0.12, facing) * outdoor
		: mix(lamp_bounce, 1.0, smoothstep(-0.2, 0.55, facing)) * (1.0 - outdoor);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit / PI;
}
