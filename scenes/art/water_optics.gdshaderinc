// What water sees of the scene round it, shared by the sea (water.gdshader) and the
// water in her cells (inner_water.gdshader): the opaque scene as drawn this frame, read
// back from the screen and the depth buffer — what lies under the surface, bent as
// light through a moving surface is and dimmed by the water it crosses on its way to
// the eye, and what stands over it, mirrored where a ray off the surface meets it.
// The compatibility renderer keeps the screen sRGB-encoded, so a colour read back is
// made linear again before it is mixed.

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
// How many strides a ray off the water marches looking for what it mirrors: the
// graphics preset's (SeaAndSky.show_graphics, project.godot's shader globals), the
// same for every water; 0 mirrors none of the scene.
global uniform int water_mirror;

// Water's reflectance looking straight down into it, for Schlick's Fresnel term; and
// the least share of the light a surface mirrors for what it mirrors to be looked for:
// less is lost in the light through it.
const float WATER_F0 = 0.02;
const float MIRROR_SEEN = 0.05;

// How much of the light reaching a surface of water it mirrors, seen [facing] (the
// cosine between the eye and the surface's normal) off it.
float water_fresnel(float facing) {
	float off = 1.0 - clamp(facing, 0.0, 1.0);
	float off2 = off * off;
	return WATER_F0 + (1.0 - WATER_F0) * off2 * off2 * off;
}

// The screen's colour at [uv], linear.
vec3 water_screen(vec2 uv) {
	vec3 srgb = max(texture(screen_texture, uv).rgb, vec3(0.0));
	return mix(
		pow((srgb + vec3(0.055)) / 1.055, vec3(2.4)),
		srgb / 12.92,
		lessThan(srgb, vec3(0.04045))
	);
}

// Where the opaque scene drawn at [uv] stands, in view space ([inv_projection] the
// view's INV_PROJECTION_MATRIX); for nothing drawn there, a point far out along the
// pixel's ray.
vec3 water_drawn_at(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

// Where the view-space point [at] is drawn on the screen ([projection] the view's
// PROJECTION_MATRIX), as a UV.
vec2 water_screen_uv(vec3 at, mat4 projection) {
	vec4 clip = projection * vec4(at, 1.0);
	return clip.xy / clip.w * 0.5 + 0.5;
}

// Where a ray from the view-space point [from] along the view-space direction [way]
// first passes behind what is drawn — the mirror image of it in the water — marched in
// [steps] strides, the first [stride] metres long and each STRIDE_GROWTH times the
// last, then narrowed to the crossing: xy its screen UV, z how sure the find is — 0 for
// none, fading toward the screen's edges, where the scene the ray meets runs out, and
// toward the march's end — and w how far the ray ran, in metres. [inv_view]
// (INV_VIEW_MATRIX) and [floor_y] keep it to what stands over the water: a ray off a
// surface never meets what lies under it.
const float STRIDE_GROWTH = 1.35;
vec4 water_mirror_trace(
	vec3 from, vec3 way, int steps, float stride, float floor_y,
	mat4 projection, mat4 inv_projection, mat4 inv_view
) {
	float travel = 0.0;
	float last = 0.0;
	for (int i = 0; i < steps; i++) {
		last = travel;
		travel += stride;
		vec3 at = from + way * travel;
		if (at.z > -0.05) {
			break;
		}
		vec2 uv = water_screen_uv(at, projection);
		if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
			break;
		}
		vec3 drawn = water_drawn_at(uv, inv_projection);
		// The ray has passed behind what is drawn there, by no more than it could have
		// slipped through it since the last stride.
		float behind = drawn.z - at.z;
		if (behind > 0.0 && behind < stride * 1.5 + 0.25) {
			float low = last;
			float high = travel;
			for (int j = 0; j < 5; j++) {
				float middle = (low + high) * 0.5;
				vec3 probe = from + way * middle;
				vec2 probed = water_screen_uv(probe, projection);
				if (water_drawn_at(probed, inv_projection).z > probe.z) {
					high = middle;
				} else {
					low = middle;
				}
			}
			vec3 hit = from + way * high;
			uv = water_screen_uv(hit, projection);
			vec3 met = (inv_view * vec4(water_drawn_at(uv, inv_projection), 1.0)).xyz;
			if (met.y < floor_y) {
				return vec4(0.0);
			}
			vec2 edge = smoothstep(vec2(0.0), vec2(0.1), uv);
			edge *= smoothstep(vec2(0.0), vec2(0.1), 1.0 - uv);
			float ending = 1.0 - smoothstep(0.6, 1.0, float(i) / float(steps));
			return vec4(uv, edge.x * edge.y * ending, high);
		}
		stride *= STRIDE_GROWTH;
	}
	return vec4(0.0);
}
