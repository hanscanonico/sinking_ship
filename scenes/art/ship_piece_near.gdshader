// The dressed ship's paints (ship.gdshaderinc) for the furnishings of one piece of a
// broken hull (SH33): cut to its stretch, and faded near the eye.
shader_type spatial;
render_mode cull_back;

#define PIECE
#define NEAR_FADE
#include "res://scenes/art/ship.gdshaderinc"
