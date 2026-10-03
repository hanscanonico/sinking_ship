// The dressed ship's paints (ship.gdshaderinc) for the observer's cut-away: a
// variant of its own, so the ship everyone plays on never pays for the discard.
shader_type spatial;
render_mode cull_disabled;

#define CUT_AWAY
#include "res://scenes/art/ship.gdshaderinc"
