"""Builds assets/models/bell/bell.blend: the ship's bell on the foremast
(ShipFittings._bell) — an iron bracket off the mast's after side with a brace under it,
the brass bell hung from its end by its crown, its clapper and its lanyard — in Godot's
axes, metres: x fore and aft, y up, z athwartships, its origin where the bracket meets
the mast's after face, at the bracket's height, the bracket reaching aft (−x)
ShipFittings.BELL_REACH and the bell hanging at its end.

    make model-sources MODEL=bell
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/bell/bell.py -- assets/models/bell/bell.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, cap, fresh_scene, lathe, save, sphere, triangles, tube  # noqa: E402

# The bracket: how far aft it reaches off the mast, its section's half height and half
# breadth; the bell hangs under it this far in from its end.
REACH = 0.22
ARM = (0.025, 0.02)
HANG = 0.05
# The bell: its crown's top under the bracket, its lip's radius and height under it.
CROWN = -0.03
LIP = 0.1
LIP_HEIGHT = -0.22
# How far under the bracket the lanyard's end hangs.
DROP = 0.3
SIDES = 14

UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])


def bracket(iron):
    """The arm off the mast, its backing plate on the mast and the brace under it."""
    box(iron, [-REACH, -ARM[0], -ARM[1]], [0.01, ARM[0], ARM[1]], rim=0.012)
    box(iron, [-0.012, -0.2, -0.045], [0.012, 0.045, 0.045], rim=0.012)
    tube(iron, [0.0, -0.17, 0.0], [-REACH * 0.62, -ARM[0], 0.0], [(0.011, 0.0, 0.0), (0.011, 1.0, 0.0)], 6, caps=(False, False))
    # The hanger the bell's crown is shackled to.
    x = -REACH + HANG
    tube(iron, [x, -ARM[0] + 0.005, 0.0], [x, CROWN + 0.004, 0.0], [(0.012, 0.0, 0.0), (0.012, 1.0, 0.0)], 6, caps=(False, False))


def bell(brass):
    """The bell, turned: a domed crown, the waist flaring to a thickened lip, and its
    mouth hollow inside."""
    centre = [-REACH + HANG, 0.0, 0.0]
    rows = lathe(
        brass,
        centre,
        UP,
        [
            (0.03, CROWN, 0.0),
            (0.055, CROWN - 0.006, 0.0),
            (0.068, CROWN - 0.022, 1.0),
            (0.066, CROWN - 0.04, 0.0),
            (0.066, -0.11, 0.0),
            (0.074, -0.16, 0.0),
            (0.09, -0.195, 0.0),
            (LIP, LIP_HEIGHT + 0.012, 1.0),
            (LIP, LIP_HEIGHT, 1.0),
            (LIP - 0.014, LIP_HEIGHT, 1.0),
            (0.074, -0.185, 0.0),
            (0.058, -0.1, 0.0),
            (0.045, -0.05, 0.0),
        ],
        SIDES,
    )
    cap(brass, rows[0], [centre[0], CROWN + 0.004, 0.0], [0.0, 1.0, 0.0], 0.0)
    # The hollow's crown, seen from under it.
    cap(brass, rows[-1], [centre[0], -0.04, 0.0], [0.0, -1.0, 0.0], 0.0)


def clapper(iron, rope):
    """The clapper on its shank, and the lanyard spliced to it, a knot at its end."""
    x = -REACH + HANG
    tube(iron, [x, -0.05, 0.0], [x, -0.19, 0.0], [(0.006, 0.0, 0.0), (0.006, 1.0, 0.0)], 5, caps=(False, False))
    sphere(iron, [x, -0.2, 0.0], 0.022, 8, 4)
    tube(
        rope,
        [x, -0.215, 0.0],
        [x, -DROP, 0.0],
        [(0.008, 0.0, 0.0), (0.008, 0.72, 0.0), (0.016, 0.82, 0.0), (0.014, 0.95, 0.0), (0.006, 1.0, 0.0)],
        6,
    )


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    parts = {paint: Part(paint, paint) for paint in ("dark", "brass", "rope")}
    bracket(parts["dark"])
    bell(parts["brass"])
    clapper(parts["dark"], parts["rope"])
    for part in parts.values():
        part.build(collection)
    print("bell: %d triangles" % triangles(collection))
    save(out)


main()
