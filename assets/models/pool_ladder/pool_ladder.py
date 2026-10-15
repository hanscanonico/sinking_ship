"""Builds assets/models/pool_ladder/pool_ladder.blend: the brass handrails of the
swimming bath's ladder (LinerBath.pool), in Godot's axes, metres: x out over the
water, y up, z across the pool's end, its origin on the rim's top over its inner
edge at the middle of the pool's aft end. Two brass tubes LinerBath.LADDER_SPAN
apart rise out of the water HANDLE_BAR in from the rim's face, bend over in a
gooseneck HANDLE over the rim and come down onto it HANDLE_BACK back, each foot in a
flange. Nothing stands higher than HANDLE and a bar's half over the rim, so a body
on it steps over them; its box is LinerBath.LADDER.

    make model-sources MODEL=pool_ladder
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/pool_ladder/pool_ladder.py -- \\
        assets/models/pool_ladder/pool_ladder.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, cap, fresh_scene, lathe, save, sweep, triangles  # noqa: E402

# LinerBath's ladder: its handles' span, height over the rim and reach back over
# it, and the bar's side; how far under the rim the water stands (WATER_DOWN).
SPAN = 0.45
HANDLE = 0.2
BACK = 0.16
BAR = 0.035
WATER = 0.035
# The tube's radius, its bends' radius, how far under the water it starts, and the
# flange round its foot.
TUBE = 0.016
BEND = 0.06
WET = 0.03
FLANGE = (0.03, 0.008)
SIDES = 8
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])


def arc(centre, start, steps):
    """[steps] points round a quarter circle of BEND about [centre] (x, y), from the
    angle [start], anticlockwise."""
    points = []
    for k in range(1, steps):
        a = start + math.pi * 0.5 * k / steps
        points.append((centre[0] + BEND * math.cos(a), centre[1] + BEND * math.sin(a)))
    return points


def rail(brass, z):
    """One handrail across the pool's end at [z]: up out of the water, over and down
    onto the rim."""
    face = BAR
    foot = face - BACK
    path = [(face, -WATER - WET), (face, HANDLE - BEND)]
    path += arc((face - BEND, HANDLE - BEND), 0.0, 3)
    path += [(face - BEND, HANDLE), (foot + BEND, HANDLE)]
    path += arc((foot + BEND, HANDLE - BEND), math.pi * 0.5, 3)
    path += [(foot, HANDLE - BEND), (foot, 0.0)]
    sweep(brass, [[x, y, z] for x, y in path], TUBE, SIDES, caps=False)
    rows = lathe(brass, [foot, 0.0, z], UP, [(FLANGE[0], 0.0, 1.0), (FLANGE[0], FLANGE[1], 1.0), (TUBE + 0.004, FLANGE[1] + 0.004, 0.0)], SIDES)
    cap(brass, rows[-1], [foot, FLANGE[1] + 0.004, z], [0.0, 1.0, 0.0], 0.0)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    brass = Part("brass", "brass")
    for side in (-1.0, 1.0):
        rail(brass, side * SPAN * 0.5)
    brass.build(collection)
    print("pool_ladder: %d triangles" % triangles(collection))
    save(out)


main()
