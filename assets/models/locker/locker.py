"""Builds assets/models/locker/locker.blend: a cabin's tall locker flat on its wall
(CabinDressing.locker) — a varnished carcass on a plinth under a cornice, its two
doors each a raised panel under a louvred head, and a brass knob on each — in Godot's
axes, metres: x along the wall (Wall.right), y up, z out from the wall's face into the
room, its origin on the floor at the wall's face under its middle. Nothing stands
further out than CabinDressing.LOCKER's depth, a wall fitting's.

    make model-sources MODEL=locker
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/locker/locker.py -- assets/models/locker/locker.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, panel, save, slab, stud, triangles  # noqa: E402

# The carcass: its half length, its depth off the wall and its height; the cornice's
# and the plinth's height, and how far each stands proud of it.
HALF = 0.3
DEPTH = 0.08
HEIGHT = 1.9
CORNICE = 0.06
PLINTH = 0.08
PROUD = 0.012
# Each door's half width and its face's depth; the louvres' heights and how many.
DOOR = 0.13
FACE = DEPTH + 0.003
LOUVRE_LOW = 1.42
LOUVRE_HIGH = 1.74
SLATS = 5

BACK = (2, -1)
X = [1.0, 0.0, 0.0]
Y = [0.0, 1.0, 0.0]
Z = [0.0, 0.0, 1.0]


def carcass(frame, dark):
    """The carcass between its plinth and its cornice, both a little proud."""
    top = HEIGHT - CORNICE
    box(frame, [-HALF, PLINTH, 0.0], [HALF, top, DEPTH], skip=(BACK, (1, -1), (1, 1)))
    box(frame, [-HALF - PROUD, top, 0.0], [HALF + PROUD, HEIGHT, DEPTH + PROUD], rim=0.012, skip=(BACK,))
    box(dark, [-HALF + 0.01, 0.0, 0.0], [HALF - 0.01, PLINTH, DEPTH - 0.01], inked=False, skip=(BACK, (1, -1), (1, 1)))


def door(side, teak, dark, brass):
    """One door: its face, a raised panel low on it, a louvred head of slats angled
    down out of the dark behind, and its knob by the meeting stile."""
    middle = side * (DOOR + 0.01)
    low = PLINTH + 0.02
    high = HEIGHT - CORNICE - 0.02
    panel(teak, [middle, (low + high) * 0.5, FACE], X, Y, (DOOR, (high - low) * 0.5), 0.02)
    panel(teak, [middle, (low + 1.3) * 0.5, FACE + 0.004], X, Y, (DOOR - 0.035, (1.3 - low) * 0.5 - 0.04), 0.015)
    a = middle - DOOR + 0.035
    b = middle + DOOR - 0.035
    slab(dark, [[a, LOUVRE_LOW, FACE + 0.001], [b, LOUVRE_LOW, FACE + 0.001], [b, LOUVRE_HIGH, FACE + 0.001], [a, LOUVRE_HIGH, FACE + 0.001]], Z)
    pitch = (LOUVRE_HIGH - LOUVRE_LOW) / SLATS
    for slat in range(SLATS):
        top = LOUVRE_LOW + (slat + 1) * pitch - 0.006
        bottom = top - pitch * 0.85
        out = FACE + 0.011
        slab(teak, [[a, bottom, out], [b, bottom, out], [b, top, FACE + 0.002], [a, top, FACE + 0.002]], [0.0, 0.6, 1.0])
        slab(teak, [[a, bottom, FACE + 0.002], [b, bottom, FACE + 0.002], [b, bottom, out], [a, bottom, out]], [0.0, -1.0, 0.0], 1.0)
    stud(brass, [side * 0.04, 1.0, FACE], Z, 0.014, 0.016, 6)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    frame = Part("frame", "frame")
    teak = Part("teak", "teak")
    dark = Part("dark", "dark")
    brass = Part("brass", "brass")
    carcass(frame, dark)
    for side in (-1.0, 1.0):
        door(side, teak, dark, brass)
    for part in (frame, teak, dark, brass):
        part.build(collection)
    print("locker: %d triangles" % triangles(collection))
    save(out)


main()
