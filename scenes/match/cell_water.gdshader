// A cell's water over the observer's view (CellOverlay): drawn over everything, unlit,
// both sides, its box filled to the world height its water stands at however she leans
// — a bright line along the walls where it meets them — and its surface a sheet level
// with the world, drawn only inside the box, in ship metres.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform vec4 water_colour : source_color = vec4(0.1, 0.5, 1.0, 0.55);
uniform vec4 level_colour : source_color = vec4(0.62, 0.96, 1.0, 0.95);
// How deep under the level the line along the walls reaches, in metres.
uniform float level_thick = 0.05;
// The world to her ship space, as drawn this frame.
uniform mat4 world_to_ship = mat4(1.0);
// The world height the cell's water stands at, the box it is drawn in, and whether
// this is its surface, all in level_colour, rather than its walls.
instance uniform float level = 0.0;
instance uniform vec3 clip_low = vec3(0.0);
instance uniform vec3 clip_high = vec3(0.0);
instance uniform bool surface = false;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ship = (world_to_ship * vec4(world, 1.0)).xyz;
	if (any(lessThan(ship, clip_low)) || any(greaterThan(ship, clip_high))) {
		discard;
	}
	if (!surface && world.y > level) {
		discard;
	}
	vec4 colour = surface || world.y > level - level_thick ? level_colour : water_colour;
	ALBEDO = colour.rgb;
	ALPHA = colour.a;
}
