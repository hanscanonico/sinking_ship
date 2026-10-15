"""Builds assets/models/sconce_tulip/sconce_tulip.blend: a liner's brass wall sconce
(RoomDressing.SCONCE_MODEL) — an oval back plate, an arm curving out and up from it to
a turned cup, and an upright tulip shade of glowing sconce glass in the cup — in
Godot's axes, metres: x along the wall (Wall.right), y up, z out from the wall's face,
its origin on the wall's face at the plate's middle. Nothing of it stands more than
RoomDressing.SCONCE_REACH out, nor more than SCONCE_RISE over its origin.

    make model-sources MODEL=sconce_tulip
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/sconce_tulip/sconce_tulip.py -- \
        assets/models/sconce_tulip/sconce_tulip.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, lathe, save, slab, sweep, triangles  # noqa: E402

# The back plate's half width and half height, and how far it stands off the wall.
PLATE = (0.035, 0.07)
PLATE_OUT = 0.01
# The shade's axis out from the wall, and its foot's height over the plate's middle.
AXIS = 0.058
FOOT = 0.06
SIDES = 8
# The cup and the shade turn on fewer sides, smoothed round, a corner facing the room.
ROUND = 6
ROUND_PHASE = math.pi / 2.0
# The shade's profile up its axis from the cup: (radius, height over FOOT, ink); its
# lip at the top, RoomDressing.SCONCE_REACH - AXIS round, and its glowing floor a
# little down inside it. Uninked, as the shade it replaces was: ink darkens the glass.
SHADE = [(0.018, 0.016, 0.0), (0.034, 0.045, 0.0), (0.042, 0.09, 0.0), (0.0, 0.084, 0.0)]
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])


def plate(brass):
    """The oval plate, its edge bevelled back to the wall."""
    oval = ([PLATE[0], 0.0, 0.0], [0.0, PLATE[1], 0.0], [0.0, 0.0, 1.0])
    rows = lathe(brass, [0.0, 0.0, 0.0], oval, [(1.0, 0.0, 1.0), (0.82, PLATE_OUT, 1.0)], SIDES, phase=math.pi / SIDES)
    slab(brass, rows[-1], [0.0, 0.0, 1.0])


def arm(brass):
    """The arm from the plate's lower half sloping out and up, then straight up under
    the cup."""
    path = [[0.0, -0.025, PLATE_OUT - 0.002], [0.0, -0.005, AXIS], [0.0, FOOT + 0.004, AXIS]]
    sweep(brass, path, 0.007, 4, caps=False)


def cup_and_shade(brass, glass):
    """The turned cup on the arm and the tulip in it, its glowing floor a little down
    inside its lip."""
    centre = [0.0, FOOT, AXIS]
    lathe(brass, centre, UP, [(0.008, 0.0, 1.0), (SHADE[0][0], SHADE[0][1], 1.0)], ROUND, phase=ROUND_PHASE, wound=True)
    lathe(glass, centre, UP, SHADE, ROUND, phase=ROUND_PHASE, wound=True)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    brass = Part("brass", "brass")
    glass = Part("sconce_glass", "sconce_glass")
    plate(brass)
    arm(brass)
    cup_and_shade(brass, glass)
    brass.build(collection)
    glass.build(collection, sharp_angle=70.0)
    print("sconce_tulip: %d triangles" % triangles(collection))
    save(out)


main()
