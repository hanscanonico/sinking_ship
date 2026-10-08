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
// DECK at the bow (when bow.w is 1): forward of bow.x the rows close on the stem head
// at bow.y from bow.z either side of the centreline, so the forecastle's planking runs
// to a point at the stem inside a darker margin plank margin_plank wide; outboard of
// it the deck is plated steel, bow_plate, in plates bow_plate_size.
uniform vec4 bow = vec4(0.0);
uniform float margin_plank = 0.24;
uniform vec4 bow_plate : source_color = vec4(0.4, 0.3, 0.26, 1.0);
uniform float bow_plate_size = 1.2;
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
// HOUSE's plating: seams plate_height apart up from the foot, butts plate_width
// apart along, a row of rivets over each seam, and grime: streaks of rust run down
// from under the trim, and dirt gathers over the foot.
uniform float plate_height = 0.8;
uniform float plate_width = 1.7;
uniform float rivet_spacing = 0.12;
uniform float rivet_radius = 0.01;
uniform vec4 grime_colour : source_color = vec4(0.45, 0.33, 0.25, 1.0);
uniform float grime = 0.25;
// FUNNEL: the black top.
uniform vec4 top_colour : source_color = vec4(0.11, 0.11, 0.12, 1.0);
uniform float top_depth = 1.3;
// PLATE (an engine room's steel): on a wall, plates bulkhead_plate (along, up) with a
// rivet row over each seam and a dark kick (foot_colour) at the foot; underfoot,
// checker plate — raised lugs in alternate directions, lugs apart — in plates of
// tread_plate; overhead, plain plating.
uniform vec2 bulkhead_plate = vec2(1.2, 0.9);
uniform float kick_height = 0.16;
uniform float lugs = 0.055;
uniform vec2 tread_plate = vec2(1.8, 1.2);
// ROUGH (a hold's timber): unpainted boards, rough_board wide on a wall and
// rough_floor wide underfoot and overhead, butted every rough_length, uneven in
// tone, with dark gaps between them.
uniform float rough_board = 0.2;
uniform float rough_floor = 0.26;
uniform float rough_length = 4.4;

#ifdef CUT_AWAY
// The observer's cut-away: nothing above it is drawn, and the inside of whatever
// it slices shows as a flat section.
uniform float cut_above = 1e6;
uniform vec4 section_colour : source_color = vec4(0.2, 0.19, 0.2, 1.0);
#endif

#ifdef PIECE
// One piece of a broken hull (ShipArt.span, SH33): nothing of the ship outside its
// stretch along her is drawn, and the inside of what the cut leaves open shows as a dark
// torn section.
uniform vec2 piece_span = vec2(-1e6, 1e6);
uniform vec4 torn_colour : source_color = vec4(0.09, 0.08, 0.08, 1.0);
#endif

#ifdef NEAR_FADE
// The rooms' furnishings (ship_near.gdshader): a piece that fades (ShipMesh.fading)
// starts to go within near_fade.y of the eye and is gone within near_fade.x —
// screen-door, still opaque — by its nearest point, so a closed box goes whole rather
// than open onto its culled inside; a long piece only within near_piece of that
// point. Per vertex, CUSTOM0 is its piece's middle and 1 when it fades, CUSTOM1 its
// half size.
uniform vec2 near_fade = vec2(0.3, 0.6);
uniform float near_piece = 0.4;
varying float piece_near;
#endif

const int PLAIN = 0;
const int DECK = 1;
const int HULL = 2;
const int HOUSE = 3;
const int CABIN = 4;
const int FUNNEL = 5;
const int PLATE = 8;
const int ROUGH = 9;

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

// 1 on a rivet of the row riding [param over] above each seam of [param d], whose
// rivets stand [param spacing] apart along [param along]; faded out once a rivet
// would be smaller than a pixel.
float rivets(float along, float d, float over) {
	vec2 at = vec2((fract(along / rivet_spacing + 0.5) - 0.5) * rivet_spacing, d - over);
	float fw = max(fwidth(along), 1e-5);
	float dot_ = 1.0 - smoothstep(rivet_radius - fw, rivet_radius + fw, length(at));
	return dot_ * clamp(rivet_radius * 2.0 / fw - 0.5, 0.0, 1.0);
}

// Steel deck plating: plates bow_plate_size square, seams riveted.
vec3 plated() {
	vec2 seam = (fract(ship_pos.xz / bow_plate_size + 0.5) - 0.5) * bow_plate_size;
	float plating = max(line(seam.x, 0.006), line(seam.y, 0.006));
	plating = max(plating, 0.8 * rivets(ship_pos.z, seam.x, 0.03));
	return bow_plate.rgb * (1.0 - 0.3 * plating);
}

vec3 planks(vec3 base) {
	float z = ship_pos.z;
	float margin = 0.0;
	if (bow.w > 0.5 && ship_pos.x > bow.x) {
		float share = clamp((ship_pos.x - bow.x) / (bow.y - bow.x), 0.0, 0.95);
		z *= 1.0 / (1.0 - share * share);
		if (abs(z) > bow.z) {
			return plated();
		}
		margin = step(bow.z - margin_plank, abs(z));
	}
	float row = floor(z / plank_width);
	float across = (fract(z / plank_width) - 0.5) * plank_width;
	float along = ship_pos.x / plank_length + hash(vec2(row, 7.0));
	float piece = floor(along);
	float butt = (fract(along) - 0.5) * plank_length;
	float tone = mix(0.86, 1.1, hash(vec2(row, piece)));
	float grain = 0.96 + 0.04 * sin(ship_pos.x * 7.0 + hash(vec2(piece, row)) * 40.0 + sin(ship_pos.z * 31.0));
	vec3 colour = base * tone * grain * (1.0 - 0.28 * margin);
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

// Where a point stands along a wall: x along one facing z, z along one facing x.
float wall_along() {
	return abs(ship_normal.x) > 0.5 ? ship_pos.z : ship_pos.x;
}

vec3 house(vec3 base) {
	if (bands.y < trim_depth) {
		return trim_colour.rgb;
	}
	if (bands.x < foot_height) {
		return foot_colour.rgb;
	}
	float along = wall_along();
	float seam_d = (fract(bands.x / plate_height + 0.5) - 0.5) * plate_height;
	float butt_d = (fract(along / plate_width + 0.5) - 0.5) * plate_width;
	float plating = max(line(seam_d, 0.006), 0.7 * line(butt_d, 0.005));
	plating = max(plating, 0.8 * rivets(along, seam_d, 0.035));
	float column = floor(along / 0.06);
	float length_ = mix(0.3, 1.4, hash(vec2(column, 3.0)));
	float streak = step(0.8, hash(vec2(column, 11.0)));
	streak *= 1.0 - smoothstep(0.0, length_, bands.y - trim_depth);
	float dirt = 1.0 - smoothstep(0.0, 0.4, bands.x - foot_height);
	vec3 colour = mix(base, grime_colour.rgb, grime * max(streak * 0.6, dirt * 0.5));
	return colour * (1.0 - 0.22 * plating);
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

// How much of a pattern repeating every [param period] along [param d] still shows: 0
// once a repeat is narrower than a few pixels, so a fine pattern fades to its mean
// colour with distance rather than shimmering.
float shows(float d, float period) {
	return 1.0 - smoothstep(0.15, 0.5, fwidth(d) / period);
}

vec3 plate(vec3 base) {
	if (ship_normal.y > 0.5) {
		vec2 cell = floor(ship_pos.xz / lugs);
		vec2 f = fract(ship_pos.xz / lugs) - 0.5;
		f = mod(cell.x + cell.y, 2.0) > 0.5 ? vec2(f.x + f.y, f.x - f.y) : vec2(f.x - f.y, f.x + f.y);
		float lug = 1.0 - smoothstep(0.8, 1.0, abs(f.x) / 0.5 + abs(f.y) / 0.14);
		vec3 colour = base * (0.9 + 0.3 * lug * shows(ship_pos.x, lugs));
		vec2 seam = (fract(ship_pos.xz / tread_plate + 0.5) - 0.5) * tread_plate;
		return colour * (1.0 - 0.35 * max(line(seam.x, 0.006), line(seam.y, 0.006)));
	}
	if (ship_normal.y < -0.5) {
		vec2 seam = (fract(ship_pos.xz / bulkhead_plate.xx + 0.5) - 0.5) * bulkhead_plate.x;
		return base * (1.0 - 0.25 * max(line(seam.x, 0.006), line(seam.y, 0.006)));
	}
	if (bands.x < kick_height) {
		return foot_colour.rgb;
	}
	float along = wall_along();
	float seam_d = (fract((bands.x - kick_height) / bulkhead_plate.y + 0.5) - 0.5) * bulkhead_plate.y;
	float butt_d = (fract(along / bulkhead_plate.x + 0.5) - 0.5) * bulkhead_plate.x;
	float plating = max(line(seam_d, 0.006), 0.8 * line(butt_d, 0.006));
	plating = max(plating, 0.8 * rivets(along, seam_d, 0.035));
	plating = max(plating, 0.8 * rivets(bands.x, butt_d, 0.035));
	float dirt = 1.0 - smoothstep(0.0, 0.5, bands.x - kick_height);
	return base * (1.0 - 0.3 * plating) * (1.0 - 0.18 * dirt);
}

vec3 rough(vec3 base) {
	bool flat_ = abs(ship_normal.y) > 0.5;
	float width = flat_ ? rough_floor : rough_board;
	float across = flat_ ? ship_pos.z : ship_pos.y;
	float along = flat_ ? ship_pos.x : wall_along();
	float row = floor(across / width);
	float gap = (fract(across / width) - 0.5) * width;
	float run = along / rough_length + hash(vec2(row, 5.0));
	float piece = floor(run);
	float butt = (fract(run) - 0.5) * rough_length;
	float tone = mix(0.78, 1.12, hash(vec2(row, piece)));
	float grain = 0.92 + 0.08 * sin(along * 8.0 + hash(vec2(piece, row)) * 30.0 + sin(across * 27.0) * 2.0);
	vec3 colour = base * tone * mix(1.0, grain, shows(across, width));
	float seam = max(line(abs(gap) - width * 0.5, 0.012), line(abs(butt) - rough_length * 0.5, 0.008));
	return mix(colour, seam_colour.rgb * 0.55, seam * 0.9);
}

void vertex() {
	ship_pos = VERTEX;
	ship_normal = NORMAL;
	bands = UV;
	outdoor = UV2.y * (1.0 - indoors);
#ifdef NEAR_FADE
	// The ship's placement is rigid: its inverse is its turn transposed.
	vec3 eye = transpose(mat3(MODEL_MATRIX)) * (CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz);
	vec3 off = max(abs(eye - CUSTOM0.xyz) - CUSTOM1.xyz, 0.0);
	piece_near = CUSTOM0.w > 0.5 ? length(off) : 1e6;
#endif
}

void fragment() {
#ifdef PIECE
	if (ship_pos.x < piece_span.x || ship_pos.x > piece_span.y) {
		discard;
	}
#endif
#ifdef CUT_AWAY
	if (ship_pos.y > cut_above) {
		discard;
	}
#endif
#ifdef NEAR_FADE
	float shown = smoothstep(near_fade.x, near_fade.y, max(piece_near, length(VERTEX) - near_piece));
	// Interleaved gradient noise: a screen-door threshold per pixel.
	if (shown <= fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))))) {
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
	} else if (finish == PLATE) {
		colour = plate(colour);
	} else if (finish == ROUGH) {
		colour = rough(colour);
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
#ifdef PIECE
	if (!FRONT_FACING) {
		ALBEDO = vec3(0.0);
		EMISSION = torn_colour.rgb;
	}
#endif
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
