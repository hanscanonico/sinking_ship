// The dark closing in as a swimmer's breath runs out with its head under the water
// (SwimVeil, #861): a vignette from the screen's edges toward its middle, pulsing faster
// the less breath is left. One pass over the screen, drawn only while a breath is not
// full.
shader_type canvas_item;
render_mode unshaded;

// How much of the breath is gone: 0 for a full one, 1 for none left.
uniform float gone : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dark_colour : source_color = vec4(0.01, 0.02, 0.05, 1.0);
// How dark the edges go on an empty breath, and the middle with them.
uniform float edge = 0.96;
uniform float middle = 0.45;
// The beats a second at a full breath and at none.
uniform float slow = 0.8;
uniform float fast = 2.6;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 from_middle = (UV - 0.5) * vec2(aspect, 1.0) / vec2(max(aspect, 1.0) * 0.5, 0.5);
	float out_there = clamp(length(from_middle) * 0.75, 0.0, 1.0);
	// The clear middle shrinks as the breath goes.
	float clear = mix(1.1, 0.15, gone);
	float veil = smoothstep(clear - 0.45, clear + 0.35, out_there);
	float beat = 0.5 + 0.5 * sin(TIME * TAU * mix(slow, fast, gone));
	float strength = gone * gone * (0.85 + 0.15 * beat);
	COLOR = vec4(dark_colour.rgb, clamp(mix(middle, edge, veil) * strength, 0.0, 1.0));
}
