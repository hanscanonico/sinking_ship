"""Builds assets/models/folded_berth_190/folded_berth_190.blend: a berth 1.90 m long
folded up flat against a narrow cabin's wall (CabinDressing._folded_berth,
CabinDressing.FOLDED_BERTHS) — its varnished underside in two panels, on brass hinges
at its foot, held by two leather straps and hung on chains to the wall — in Godot's
axes, metres: x along the wall (Wall.right), y up, z out from the wall's face into
the room, its origin on the floor at the wall's face under its middle. Its bedding over
its top is painted blanket, for the placing code to draw in its cabin's colour. Nothing stands further out than
CabinDressing.FOLDED_BERTH's depth, a wall fitting's.

    make model-sources MODEL=folded_berth_190
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/folded_berth_190/folded_berth_190.py -- \
        assets/models/folded_berth_190/folded_berth_190.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, panel, save, slab, stud, triangles, turned_box  # noqa: E402

LENGTH = 1.9
HALF = LENGTH * 0.5
# The folded berth: its foot and its top over the floor, its depth off the wall.
LOW = 0.42
HIGH = 1.12
DEPTH = 0.08
# The chains: from the berth's top corners up to the wall, their links' size.
CHAIN_TOP = 1.62
LINKS = 7
LINK = (0.022, 0.006)

BACK = (2, -1)
X = [1.0, 0.0, 0.0]
Y = [0.0, 1.0, 0.0]
Z = [0.0, 0.0, 1.0]


def frame(wood, teak):
    """The berth's frame and its underside's two panels."""
    box(wood, [-HALF, LOW, 0.0], [HALF, HIGH, DEPTH], skip=(BACK,))
    quarter = LENGTH * 0.25
    for side in (-1.0, 1.0):
        panel(teak, [side * quarter, (LOW + HIGH) * 0.5, DEPTH + 0.002], X, Y, (quarter - 0.07, (HIGH - LOW) * 0.5 - 0.08), 0.02)


def bedding(blanket):
    """Its bedding showing over its top, folded up with it."""
    box(blanket, [-HALF + 0.04, HIGH, 0.0], [HALF - 0.04, HIGH + 0.08, DEPTH + 0.01], skip=(BACK, (1, -1)))


def hinges(brass):
    """Two hinges at its foot, each two leaves either side of its knuckle."""
    for side in (-1.0, 1.0):
        x = side * (HALF - 0.2)
        box(brass, [x - 0.06, LOW - 0.005, 0.0], [x + 0.06, LOW + 0.045, DEPTH + 0.008], inked=False, skip=(BACK,))
        turned_box(brass, [x, LOW, DEPTH + 0.008], (X, Y, Z), (0.065, 0.008, 0.008), skip=((0, -1), (0, 1)))


def straps(leather, brass):
    """A strap over each end of its bedding: down its face from over the bedding, with
    a buckle."""
    top = HIGH + 0.08
    out = DEPTH + 0.011
    for side in (-1.0, 1.0):
        x = side * HALF * 0.65
        a = x - 0.025
        b = x + 0.025
        slab(leather, [[a, HIGH - 0.16, out], [b, HIGH - 0.16, out], [b, top, out], [a, top, out]], Z)
        slab(leather, [[a, top, out], [b, top, out], [b, top + 0.004, 0.0], [a, top + 0.004, 0.0]], Y)
        stud(brass, [x, HIGH - 0.1, out], Z, 0.022, 0.006, 4, phase=math.pi / 4)


def chains(steel):
    """A chain up each end from the berth's top corner to an eye in the wall, its links
    each turned a quarter from the last."""
    for side in (-1.0, 1.0):
        x = side * (HALF - 0.05)
        start = [x, HIGH - 0.02, 0.06]
        end = [x, CHAIN_TOP, 0.012]
        along = [e - s for s, e in zip(start, end)]
        length = math.sqrt(sum(c * c for c in along))
        along = [c / length for c in along]
        flat = [1.0, 0.0, 0.0]
        edge = [along[1] * flat[2] - along[2] * flat[1], along[2] * flat[0] - along[0] * flat[2], along[0] * flat[1] - along[1] * flat[0]]
        for link in range(LINKS):
            t = (link + 0.5) / LINKS
            middle = [s + (e - s) * t for s, e in zip(start, end)]
            across = flat if link % 2 == 0 else edge
            thin = edge if link % 2 == 0 else flat
            half = (LINK[0] * 0.5, length / LINKS * 0.5 + 0.006, LINK[1] * 0.5)
            turned_box(steel, middle, (across, along, thin), half, skip=((1, -1), (1, 1)))
        stud(steel, end, Z, 0.02, 0.01, 4, phase=math.pi / 4)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    wood = Part("frame", "frame")
    teak = Part("teak", "teak")
    brass = Part("brass", "brass")
    leather = Part("leather", "leather")
    steel = Part("steel", "steel")
    blanket = Part("bedding", "blanket")
    frame(wood, teak)
    bedding(blanket)
    hinges(brass)
    straps(leather, brass)
    chains(steel)
    for part in (wood, teak, blanket, brass, leather, steel):
        part.build(collection)
    print("folded_berth_190: %d triangles" % triangles(collection))
    save(out)


main()
