// The dressed ship's paints (ship.gdshaderinc) for the rooms' furnishings: a variant
// of its own that fades a piece out near the eye, so only they pay for the discard.
shader_type spatial;
render_mode cull_back;

#define NEAR_FADE
#include "res://scenes/art/ship.gdshaderinc"
