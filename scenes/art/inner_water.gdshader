// The water standing in one of her cells (InnerWater): the sea's own colours, lit as
// an indoor face of the ship is (ship.gdshaderinc) — by the room's lamps and a little
// of the sky's ambient, never the sun — so a dark room's water stays dark but for the
// lamps' glints on its wobbling surface. Over a floor just under it, see-through to the
// planks; deeper, the sea's own deep; where it meets a wall, a body or anything standing
// in it, the sea's lap of foam and lace. Seen from under it, a dim ceiling. Its sheet
// is level with the world, turned against her lean (CellSurface), and drawn only inside
// its cell's box, in ship metres: so it piles into the box's low corner and never pokes
// through a deck, a wall or her side.
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
uniform float foam_depth = 0.04;
uniform float lace_depth = 0.25;
// The share of the sky's ambient light it keeps indoors, as the ship's indoor faces
// do, and the share of a lamp's light a surface turned from it still takes.
uniform float indoor_ambient = 0.35;
uniform float lamp_bounce = 0.35;
// How bright a lamp's glint on it is, and how tight.
uniform float glint = 0.9;
uniform float glint_tightness = 70.0;

// The world to her ship space, as drawn this frame (InnerWater), and the box this sheet's
// cell stands in there.
uniform mat4 world_to_ship = mat4(1.0);
instance uniform vec3 clip_low = vec3(0.0);
instance uniform vec3 clip_high = vec3(0.0);

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
	vec3 up = normalize(vec3(-slope.x * 0.35, 1.0, -slope.y * 0.35));
	NORMAL = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz) * (FRONT_FACING ? 1.0 : -1.0);
	AO = indoor_ambient;
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 1.0;
	if (!FRONT_FACING) {
		ALBEDO = deep_colour.rgb * 0.8;
		ALPHA = 0.85;
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
		// Drifting streaks on it, a little lighter: water, not a painted floor.
		float streak = lace(world.xz * 0.9, t * 0.15, 0.03);
		colour = mix(colour, shallow_colour.rgb * 1.25, streak * 0.25);
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
	}
}

void light() {
	// Lamps only, as an indoor face (ship.gdshaderinc): the sun never reaches it.
	if (!LIGHT_IS_DIRECTIONAL) {
		float facing = dot(NORMAL, LIGHT);
		float lit = mix(lamp_bounce, 1.0, smoothstep(-0.2, 0.55, facing));
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit / PI;
		float shine = pow(max(dot(reflect(-LIGHT, NORMAL), VIEW), 0.0), glint_tightness);
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * smoothstep(0.35, 0.6, shine) * glint;
	}
}
