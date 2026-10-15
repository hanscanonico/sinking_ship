"""Builds assets/models/masthead_light/masthead_light.blend: the steaming light on the
mast's fore side (DeckWorks.mast) — a brass lantern with a ribbed dioptric lens round
its middle, a hood and a capped chimney over it and a ring to lift it by, standing on
an iron shelf off a plate on the mast with a brace under it — in Godot's axes,
metres: x fore and aft, y up, z athwartships, its origin on the mast's fore face at
the shelf's top, the lantern standing forward (+x) of it. The lens's middle is
DeckWorks.MASTHEAD_LENS over and out from the origin, where the light's glow is hung.

    make model-sources MODEL=masthead_light
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/masthead_light/masthead_light.py -- \
        assets/models/masthead_light/masthead_light.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, lathe, save, stud, torus, triangles, tube  # noqa: E402

# The lantern's axis out from the mast's face; its lens from LENS[0] to LENS[1] up,
# LENS_RADIUS round at its ribs.
OUT = 0.15
LENS = (0.06, 0.2)
LENS_RADIUS = 0.1
SIDES = 12
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])


def lantern(brass):
    """Its foot under the lens and its top over it, hood, chimney and cap, turned."""
    centre = (OUT, 0.0, 0.0)
    foot = [
        (0.0, 0.0, 0.0),
        (0.09, 0.0, 0.0),
        (0.1, 0.0, 1.0),
        (0.1, 0.015, 0.0),
        (0.1, LENS[0] - 0.015, 0.0),
        (0.1, LENS[0], 1.0),
        (0.092, LENS[0], 0.0),
        (0.0, LENS[0], 0.0),
    ]
    lathe(brass, centre, UP, foot, SIDES, wound=True)
    top = [
        (0.0, LENS[1], 0.0),
        (0.092, LENS[1], 0.0),
        (0.1, LENS[1], 1.0),
        (0.1, LENS[1] + 0.015, 0.0),
        (0.1, LENS[1] + 0.035, 0.0),
        (0.1, LENS[1] + 0.05, 1.0),
        (0.122, LENS[1] + 0.06, 1.0),
        (0.105, LENS[1] + 0.075, 0.0),
        (0.05, LENS[1] + 0.13, 0.0),
        (0.04, LENS[1] + 0.14, 1.0),
        (0.04, LENS[1] + 0.155, 0.0),
        (0.04, LENS[1] + 0.18, 0.0),
        (0.075, LENS[1] + 0.195, 1.0),
        (0.075, LENS[1] + 0.205, 1.0),
        (0.055, LENS[1] + 0.215, 0.0),
        (0.0, LENS[1] + 0.235, 0.0),
    ]
    lathe(brass, centre, UP, top, SIDES, wound=True)
    # The ring on its cap.
    axes = ([0.0, 1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0])
    torus(brass, [OUT, LENS[1] + 0.265, 0.0], axes, 0.03, (0.006, 0.006), 8, 3)


def lens(glass, brass):
    """The lens, ribbed round its middle, and the guards across its face."""
    rows = [(0.093, LENS[0], 0.0)]
    ribs = 4
    for k in range(ribs):
        low = LENS[0] + (LENS[1] - LENS[0]) * k / ribs
        high = LENS[0] + (LENS[1] - LENS[0]) * (k + 1) / ribs
        rows.append((LENS_RADIUS, low + (high - low) * 0.35, 0.0))
        rows.append((0.093, high, 0.0))
    lathe(glass, (OUT, 0.0, 0.0), UP, rows, SIDES)
    for angle in (-50.0, 0.0, 50.0):
        a = math.radians(angle)
        x = OUT + (LENS_RADIUS + 0.008) * math.cos(a)
        z = (LENS_RADIUS + 0.008) * math.sin(a)
        tube(brass, [x, LENS[0], z], [x, LENS[1], z], [(0.006, 0.0, 0.0), (0.006, 1.0, 0.0)], 4, caps=(False, False))


def bracket(iron):
    """The plate on the mast, the shelf off it and the brace under the shelf."""
    box(iron, [-0.01, -0.2, -0.06], [0.012, 0.03, 0.06], rim=0.012)
    box(iron, [0.012, -0.022, -0.11], [OUT + 0.12, 0.0, 0.11], rim=0.012)
    tube(iron, [0.012, -0.17, 0.0], [OUT + 0.06, -0.022, 0.0], [(0.012, 0.0, 0.0), (0.012, 1.0, 0.0)], 5, caps=(False, False))
    for y in (-0.16, 0.015):
        for z in (-0.035, 0.035):
            stud(iron, [0.012, y, z], [1.0, 0.0, 0.0], 0.012, 0.01)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    brass = Part("lantern", "brass")
    glass = Part("lens", "sconce_glass")
    iron = Part("bracket", "dark")
    lantern(brass)
    lens(glass, brass)
    bracket(iron)
    for part in (brass, glass, iron):
        part.build(collection)
    print("masthead_light: %d triangles" % triangles(collection))
    save(out)


main()
