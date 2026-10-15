"""Builds assets/models/stockpot/stockpot.blend: a lidded copper stockpot hung by
its iron bail on the galley's rack (LinerService._pan_rack), in Godot's axes,
metres: x along the wall, y up, z out of it into the room, the origin on the rack's
bar's axis at its underside, where the bail's crown hangs from. Its rim stands
LinerService.STOCKPOT's top under the bar and its base its depth under that; a lug
each side along the wall holds the bail's ends.

    make model-sources MODEL=stockpot
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/stockpot/stockpot.py -- assets/models/stockpot/stockpot.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, lathe, save, sweep, triangles  # noqa: E402

# Its radius, how far under the bar its rim stands, and its base.
RADIUS = 0.09
RIM = 0.045
BASE = 0.19
SIDES = 8
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])
# The bail: its section's radius, how far under the bar its ends are held, and the
# points it is swept through.
BAIL = 0.004
LUG = 0.075
BAIL_POINTS = 7


def pot(copper):
    """The pot and its lid, turned: from the middle of its base round its side, over
    the rim's bead and up the lid to its knob."""
    lathe(
        copper,
        [0.0, -BASE, 0.0],
        UP,
        [
            (0.0, 0.0, 0.0),
            (RADIUS - 0.018, 0.0, 0.0),
            (RADIUS - 0.006, 0.0, 1.0),
            (RADIUS - 0.003, 0.012, 0.0),
            (RADIUS, BASE - RIM - 0.014, 0.0),
            (RADIUS + 0.003, BASE - RIM - 0.003, 1.0),
            (RADIUS - 0.016, BASE - RIM + 0.008, 0.0),
            (0.016, BASE - 0.022, 0.0),
            (0.0, BASE - 0.018, 0.0),
        ],
        SIDES,
        phase=math.pi / SIDES,
        wound=True,
    )


def bail(iron):
    """The lugs either side along the wall and the bail arched from one over the lid
    to the other, its crown at the origin."""
    reach = RADIUS + 0.008
    for side in (-1.0, 1.0):
        x = side * (RADIUS + 0.004)
        box(iron, [x - 0.006, -LUG - 0.012, -0.01], [x + 0.006, -LUG + 0.008, 0.01], inked=False)
    path = []
    for k in range(BAIL_POINTS):
        a = math.pi * k / (BAIL_POINTS - 1)
        path.append([reach * math.cos(a), -LUG + (LUG - BAIL) * math.sin(a), 0.0])
    sweep(iron, path, BAIL, 4, caps=False)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    copper = Part("copper", "copper")
    iron = Part("iron", "dark")
    pot(copper)
    bail(iron)
    for part in (copper, iron):
        part.build(collection)
    print("stockpot: %d triangles" % triangles(collection))
    save(out)


main()
