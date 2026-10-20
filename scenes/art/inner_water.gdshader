// The water standing in one of her cells (InnerWater): the sea's own colours, lit as
// an indoor face of the ship is (ship.gdshaderinc) — by the room's lamps and a little
// of the sky's ambient, never the sun — so a dark room's water stays dark but for the
// lamps' glints on its wobbling surface — and, seen low across it, the lit room mirrored
// in it, so a grazing eye reads water, not a shadow on the floor. Over a floor just under it, see-through to the
// planks; deeper, the sea's own deep; where it meets a wall, a body or anything standing
// in it, the sea's lap of foam and lace. Seen from under it, a dim ceiling. Its sheet
// is level with the world, turned against her lean (CellSurface), and drawn only inside
// its cell's box, in ship metres: so it piles into the box's low corner and never pokes
// through a deck, a wall or her side. Under a pocket (SH29) it glows faintly, the sea's
// light coming up through it, the only light a sealed space under water has. On an open
// well's deck, under the sky, the sun and the sky's whole ambient light it instead.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec4 deep_colour : source_color = vec4(0.09, 0.27, 0.42, 1.0);
uniform vec4 shallow_colour : source_color = vec4(0.1, 0.46, 0.53, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.97, 1.0, 0.99, 1.0);
// Metres of water over which what lies under it fades from seen to hidden, and how
// much of something just under the surface still shows through.
uniform float clear_depth = 1.1;
uniform float shallow_alpha = 0.45;
// Metres under the surface that foam: a solid lap, then lace a little deeper.
uniform float foam_depth = 0.06;
uniform float lace_depth = 0.25;
// The share of the sky's ambient light it keeps indoors, as the ship's indoor faces
// do, and the share of a lamp's light a surface turned from it still takes.
uniform float indoor_ambient = 0.35;
uniform float lamp_bounce = 0.35;
// How bright a lamp's glint on it is, and how tight.
uniform float glint = 0.9;
uniform float glint_tightness = 70.0;
// What a sheet seen low across it mirrors indoors: a lit room's tone, taken by the
// lamps as the walls are, so a dark room's water mirrors only darkness. How fast the
// mirror falls off as the eye looks down into it, and how much of it the sheet takes.
uniform vec4 indoor_tone : source_color = vec4(0.72, 0.68, 0.6, 1.0);
uniform float mirror_falloff = 2.0;
uniform float mirror_strength = 0.8;
// The share of a churning sheet's boiling foam that lights itself, so it reads white
// even in a dim hold.
uniform float churn_glow = 0.45;

// The world to her ship space, as drawn this frame (InnerWater), and the box this sheet's
// cell stands in there.
uniform mat4 world_to_ship = mat4(1.0);
uniform vec3 clip_low = vec3(0.0);
uniform vec3 clip_high = vec3(0.0);
uniform float pocket_glow = 0.0;
// 1 for an open well's water, under the open sky; 0 under a deck.
uniform float outdoor = 0.0;
// How hard it churns as the sea pours in and it climbs her, 0…1 (InnerWater.inflow):
// a rough wobble, broad bright streaks and white foam boiling up all over it. 0 is calm
// water.
uniform float inflow : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// A fine net of meandering lines where two drifting noises cross, 0…1 (water.gdshader).
float lace(vec2 p, float t, float width) {
	float a = value_noise(p + vec2(t * 0.3, t * 0.2));
	float b = value_noise(p * 1.5 + vec2(-t * 0.25, t * 0.3) + 11.0);
	return 1.0 - smoothstep(0.0, width, abs(a - b));
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ship = (world_to_ship * vec4(world, 1.0)).xyz;
	if (any(lessThan(ship, clip_low)) || any(greaterThan(ship, clip_high))) {
		discard;
	}
	float t = TIME;
	// A slow wobble of the surface: what turns a lamp's glint on it about.
	vec2 slope = vec2(
		value_noise(world.xz * 1.7 + vec2(t * 0.35, -t * 0.25)),
		value_noise(world.xz * 1.7 + vec2(-t * 0.3, t * 0.4) + 7.0)
	) - 0.5;
	slope += (vec2(
		value_noise(world.xz * 5.3 + vec2(-t * 0.8, t * 0.6) + 3.0),
		value_noise(world.xz * 5.3 + vec2(t * 0.7, t * 0.5) + 13.0)
	) - 0.5) * 0.5;
	float wobble = 0.35 + 1.8 * inflow;
	vec3 up = normalize(vec3(-slope.x * wobble, 1.0, -slope.y * wobble));
	NORMAL = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz) * (FRONT_FACING ? 1.0 : -1.0);
	AO = mix(indoor_ambient, 1.0, outdoor);
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 1.0;
	if (!FRONT_FACING) {
		ALBEDO = deep_colour.rgb * 0.8;
		ALPHA = 0.85;
		EMISSION = shallow_colour.rgb * pocket_glow;
	} else {
		float depth = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view.xyz /= view.w;
		vec3 behind = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
		// Vertical metres from the surface down to what is behind it; a depth sample
		// nearer than the surface is the rim of something in front of it.
		bool rim = view.z > VERTEX.z + 0.1;
		float below = depth > 0.99999 || rim ? 1e3 : max(world.y - behind.y, 0.0);
		float murk = floor(smoothstep(0.0, clear_depth, below) * 3.0 + 0.5) / 3.0;
		vec3 colour = mix(shallow_colour.rgb, deep_colour.rgb, murk);
		float alpha = mix(shallow_alpha, 0.95, murk);
		// Indoors, the lit room mirrored in it, the more the lower the eye looks across it.
		float mirror = pow(1.0 - abs(dot(NORMAL, VIEW)), mirror_falloff);
		mirror *= mirror_strength * (1.0 - outdoor);
		colour = mix(colour, indoor_tone.rgb, mirror);
		alpha = max(alpha, mirror);
		// Drifting streaks on it, a little lighter: water, not a painted floor.
		float streak = lace(world.xz * 0.9, t * 0.15, 0.03 + 0.06 * inflow);
		colour = mix(colour, shallow_colour.rgb * 1.25, streak * (0.25 + 0.9 * inflow));
		// Foam boiling up all over it while the sea pours in; none on calm water.
		float boiling = 0.0;
		if (inflow > 0.0) {
			float boil = value_noise(world.xz * 3.0 + t * vec2(1.2, -0.9));
			boil = mix(boil, value_noise(world.xz * 7.0 + t * vec2(-1.6, 1.3) + 5.0), 0.35);
			boiling = smoothstep(0.75 - 0.3 * inflow, 0.95, boil) * inflow;
			colour = mix(colour, foam_colour.rgb, boiling);
			alpha = max(alpha, boiling * 0.92);
		}
		if (below <= lace_depth) {
			float lap = value_noise(world.xz * 2.4 + vec2(t * 0.6, -t * 0.4));
			float edge = step(below, foam_depth * (0.45 + 0.55 * lap));
			float lacing = 0.09 * clamp(1.0 - below / lace_depth, 0.05, 1.0);
			float foam = max(edge, lace(world.xz * 3.4, t, lacing));
			colour = mix(colour, foam_colour.rgb, foam);
			alpha = max(alpha, foam * 0.92);
		}
		ALBEDO = colour;
		ALPHA = alpha;
		// Brighter along the drifting streaks, as light through a moving surface is.
		EMISSION = shallow_colour.rgb * pocket_glow * (0.6 + 0.8 * streak);
		// Its boiling foam lights itself in part, white in a dim hold.
		EMISSION += foam_colour.rgb * boiling * churn_glow;
	}
}

void light() {
	// Lamps only, as an indoor face (ship.gdshaderinc): the sun never reaches it — but
	// for an open well's, which the sun lights and no lamp does.
	float facing = dot(NORMAL, LIGHT);
	float sunlit = LIGHT_IS_DIRECTIONAL ? outdoor : 1.0 - outdoor;
	float lit = mix(lamp_bounce, 1.0, smoothstep(-0.2, 0.55, facing)) * sunlit;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit / PI;
	float shine = pow(max(dot(reflect(-LIGHT, NORMAL), VIEW), 0.0), glint_tightness);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * smoothstep(0.35, 0.6, shine) * glint * sunlit;
}
