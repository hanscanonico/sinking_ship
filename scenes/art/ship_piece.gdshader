// The dressed ship's paints (ship.gdshaderinc) for one piece of a broken hull (SH33): a
// variant of its own, so a ship that never breaks never pays for the discard; both faces
// drawn, so the hull's inside shows through its torn end.
shader_type spatial;
render_mode cull_disabled;

#define PIECE
#include "res://scenes/art/ship.gdshaderinc"
