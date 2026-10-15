"""Builds assets/models/serving_hatch/serving_hatch.blend: a plain dining saloon's
serving hatch from the galley (LinerDining._hatch) — two panelled shutters drawn down
in its opening, brass pulls where they meet, a mitred architrave round it under a
moulded head, and a serving shelf on two brackets under it — in Godot's axes, metres:
x along the wall (Wall.right), y up, z out from the wall's face, its origin on the
wall's face at the opening's middle, LinerDining.HATCH_HEIGHT over the floor. Its
opening is LinerDining.HATCH each way from there, its architrave HATCH_RIM round it,
its shelf HATCH_SILL thick and out under that and its brackets HATCH_BRACKET under the
shelf. The shutters are painted teak, swapped for the saloon's shutter paint.

    make model-sources MODEL=serving_hatch
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/serving_hatch/serving_hatch.py -- \
        assets/models/serving_hatch/serving_hatch.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import RIM_LOOP, Part, box, fresh_scene, panel, save, slab, stud, triangles  # noqa: E402

# LinerDining's HATCH (the opening's half size), HATCH_RIM, HATCH_SILL (its thickness
# and depth) and HATCH_BRACKET.
OPENING = (0.55, 0.35)
RIM = 0.06
SILL = (0.03, 0.06)
BRACKET = 0.1
# How far the architrave stands off the wall, the shutters' faces, and the head's
# height and depth.
TRIM = 0.016
LEAF = 0.008
HEAD = 0.035
HEAD_OUT = 0.03

BACK = (2, -1)
FLOOR = (1, -1)
TOP = (1, 1)
ENDS = ((0, -1), (0, 1))
X = [1.0, 0.0, 0.0]
Y = [0.0, 1.0, 0.0]
Z = [0.0, 0.0, 1.0]


def architrave(frame):
    """The architrave round the opening: one mitred frame flat on the wall, inked round
    its outside a loop in, its sides square to the wall; the moulded head along its
    top and its foot the shelf's."""
    half_x, half_y = OPENING
    outer_x = half_x + RIM
    top = half_y + RIM - HEAD
    low = -half_y - RIM
    edge = [[-outer_x, low], [-outer_x, top], [outer_x, top], [outer_x, low]]
    loop = [[-outer_x + RIM_LOOP, low], [-outer_x + RIM_LOOP, top], [outer_x - RIM_LOOP, top], [outer_x - RIM_LOOP, low]]
    opening = [[-half_x, -half_y], [-half_x, half_y], [half_x, half_y], [half_x, -half_y]]
    for k in range(3):
        for a, b, ink in ((edge, loop, 1.0), (loop, opening, 0.0)):
            corners = [a[k] + [TRIM], a[k + 1] + [TRIM], b[k + 1] + [TRIM], b[k] + [TRIM]]
            frame.face([frame.point(c) for c in corners], [ink, ink, 0.0, 0.0], Z)
    # Under the opening, down to the shelf.
    slab(frame, [[-outer_x, low, TRIM], [outer_x, low, TRIM], [half_x, -half_y, TRIM], [-half_x, -half_y, TRIM]], Z)
    for side in (-1.0, 1.0):
        x = side * outer_x
        slab(frame, [[x, low, 0.0], [x, top, 0.0], [x, top, TRIM], [x, low, TRIM]], [side, 0.0, 0.0])
    # The reveal round the shutters, from the architrave's face back to theirs.
    for (xa, ya), (xb, yb) in zip(opening, opening[1:] + opening[:1]):
        inward = [-(yb - ya), xb - xa, 0.0]
        slab(frame, [[xa, ya, LEAF], [xb, yb, LEAF], [xb, yb, TRIM], [xa, ya, TRIM]], [-v for v in inward])
    box(frame, [-outer_x, top, 0.0], [outer_x, half_y + RIM, HEAD_OUT], rim=0.012, skip=(BACK, TOP), plain=ENDS + (FLOOR,))


def shutters(teak, dark, brass):
    """The two shutters drawn down in the opening, each a raised panel in its moulding,
    the dark line where they meet and a brass pull either side of it."""
    half_x, half_y = OPENING
    for side in (-1.0, 1.0):
        middle = side * half_x * 0.5
        panel(teak, [middle, 0.0, LEAF], X, Y, (half_x * 0.5 - 0.004, half_y), 0.015)
        panel(teak, [middle, 0.0, LEAF + 0.003], X, Y, (half_x * 0.5 - 0.06, half_y - 0.06), 0.012, hollow=True)
        stud(brass, [side * 0.035, -0.05, LEAF], Z, 0.014, 0.008, 4, math.pi / 4.0)
    slab(dark, [[-0.004, -half_y, LEAF + 0.001], [0.004, -half_y, LEAF + 0.001], [0.004, half_y, LEAF + 0.001], [-0.004, half_y, LEAF + 0.001]], Z)


def shelf(frame):
    """The serving shelf under the architrave and a bracket under each end of it."""
    outer_x = OPENING[0] + RIM
    top = -OPENING[1] - RIM
    box(frame, [-outer_x, top - SILL[0], 0.0], [outer_x, top, SILL[1]], rim=0.01, skip=(BACK,), plain=ENDS + (FLOOR,))
    foot = top - SILL[0]
    for side in (-1.0, 1.0):
        x = side * (outer_x - 0.08)
        reach = SILL[1] - 0.012
        tip = [[0.0, foot], [0.0, foot - BRACKET], [reach, foot]]
        for dx in (-0.012, 0.012):
            slab(frame, [[x + dx, y, z] for z, y in tip], [dx, 0.0, 0.0])
        slab(frame, [[x - 0.012, foot - BRACKET, 0.0], [x + 0.012, foot - BRACKET, 0.0], [x + 0.012, foot, reach], [x - 0.012, foot, reach]], [0.0, -BRACKET, reach])


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    frame = Part("frame", "frame")
    teak = Part("teak", "teak")
    dark = Part("dark", "dark")
    brass = Part("brass", "brass")
    architrave(frame)
    shutters(teak, dark, brass)
    shelf(frame)
    for part in (frame, teak, dark, brass):
        part.build(collection)
    print("serving_hatch: %d triangles" % triangles(collection))
    save(out)


main()
