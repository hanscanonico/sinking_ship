"""Builds assets/models/sconce_globe/sconce_globe.blend: the first-class dining
saloon's gilt sconce (LinerDining.SCONCE_MODEL) — a shield-shaped back plate, a short
scrolled arm up from it to a gallery, and a round frosted globe of glowing sconce
glass in the gallery — in Godot's axes, metres: x along the wall (Wall.right), y up, z
out from the wall's face, its origin on the wall's face at the plate's middle. The
globe, LinerDining.SCONCE_GLOBE round, stands with its middle SCONCE_OUT out from the
wall and SCONCE_LIFT over the origin.

    make model-sources MODEL=sconce_globe
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/sconce_globe/sconce_globe.py -- \
        assets/models/sconce_globe/sconce_globe.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, lathe, save, slab, stud, sweep, triangles  # noqa: E402

# The plate's half width and half height, and how far it stands off the wall.
PLATE = (0.05, 0.09)
PLATE_OUT = 0.01
# The globe: its radius, its middle's way out and up (LinerDining's SCONCE_GLOBE,
# SCONCE_OUT and the lift its plate is drawn under).
GLOBE = 0.035
OUT = 0.075
LIFT = 0.03
SIDES = 8
# The gallery and the globe turn on fewer sides, smoothed round, a corner facing the
# room.
ROUND = 6
ROUND_PHASE = math.pi / 2.0
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])


def plate(gilt):
    """The shield: an oval plate bevelled back to the wall, a boss on its foot."""
    oval = ([PLATE[0], 0.0, 0.0], [0.0, PLATE[1], 0.0], [0.0, 0.0, 1.0])
    rows = lathe(gilt, [0.0, 0.0, 0.0], oval, [(1.0, 0.0, 1.0), (0.8, PLATE_OUT, 1.0)], SIDES, phase=math.pi / SIDES)
    slab(gilt, rows[-1], [0.0, 0.0, 1.0])
    stud(gilt, [0.0, -0.06, PLATE_OUT], [0.0, 0.0, 1.0], 0.014, 0.01, 4, math.pi / 4.0)


def arm(gilt):
    """The arm, scrolled out from the plate's middle and up under the gallery."""
    foot = LIFT - GLOBE - 0.012
    path = [[0.0, -0.035, PLATE_OUT - 0.002], [0.0, foot - 0.02, OUT], [0.0, foot + 0.002, OUT]]
    sweep(gilt, path, 0.007, 4, caps=False)


def gallery_and_globe(gilt, glass):
    """The gallery cupping the globe's foot, and the globe, round, its crown closed."""
    centre = [0.0, LIFT, OUT]
    low = -GLOBE - 0.012
    lathe(gilt, centre, UP, [(0.008, low, 1.0), (0.024, -GLOBE * 0.72, 1.0)], ROUND, phase=ROUND_PHASE, wound=True)
    # Its foot inside the gallery, its middle, its shoulder and its crown.
    foot = (GLOBE * math.sin(math.pi / 5.0), -GLOBE * math.cos(math.pi / 5.0), 0.0)
    profile = [foot, (GLOBE, 0.0, 0.0), (foot[0], -foot[1], 0.0), (0.0, GLOBE, 0.0)]
    lathe(glass, centre, UP, profile, ROUND, phase=ROUND_PHASE, wound=True)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    gilt = Part("gilt", "gilt")
    glass = Part("sconce_glass", "sconce_glass")
    plate(gilt)
    arm(gilt)
    gallery_and_globe(gilt, glass)
    gilt.build(collection)
    glass.build(collection, sharp_angle=70.0)
    print("sconce_globe: %d triangles" % triangles(collection))
    save(out)


main()
