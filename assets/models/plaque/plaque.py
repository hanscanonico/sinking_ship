"""Builds assets/models/plaque/plaque.blend: the gymnasium's brass plaque on its
teak board (LinerService._plaque), in Godot's axes, metres: x along the wall, y up,
z out of it into the room, its origin on the wall's face at the board's middle. The
board's edges chamfered, the plate screwed to it at its corners and engraved in
three lines; its box is LinerService.PLAQUE, flat to its wall.

    make model-sources MODEL=plaque
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/plaque/plaque.py -- assets/models/plaque/plaque.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, save, slab, stud, triangles  # noqa: E402

# The board: its half size, its depth and its chamfer; the plate's half size and
# depth over it.
BOARD = (0.2, 0.14)
DEPTH = 0.016
CHAMFER = 0.008
PLATE = (0.16, 0.1)
PLATE_DEPTH = 0.003
# The engraving: each line's height over the middle and its words' (left, right).
LINES = [
    (0.045, [(-0.12, -0.03), (-0.01, 0.12)]),
    (0.0, [(-0.13, -0.06), (-0.04, 0.03), (0.05, 0.13)]),
    (-0.045, [(-0.09, 0.0), (0.02, 0.09)]),
]
STROKE = 0.0075
Z = [0.0, 0.0, 1.0]


def board(teak):
    """The board: its face, and its four chamfered edges down to the wall."""
    w, h = BOARD
    c = CHAMFER
    face = [[-w + c, -h + c, DEPTH], [w - c, -h + c, DEPTH], [w - c, h - c, DEPTH], [-w + c, h - c, DEPTH]]
    foot = [[-w, -h, 0.0], [w, -h, 0.0], [w, h, 0.0], [-w, h, 0.0]]
    slab(teak, face, Z)
    for k in range(4):
        n = (k + 1) % 4
        middle = [(face[k][i] + face[n][i]) * 0.5 for i in range(2)]
        outward = [middle[0], middle[1], 0.05]
        teak.face([teak.point(p) for p in (foot[k], foot[n], face[n], face[k])], [1.0, 1.0, 1.0, 1.0], outward)


def plate(brass, dark):
    """The plate over the board, its screws and its engraved lines."""
    w, h = PLATE
    box(brass, [-w, -h, DEPTH], [w, h, DEPTH + PLATE_DEPTH], skip=((2, -1),), plain=((0, -1), (0, 1), (1, -1), (1, 1)))
    top = DEPTH + PLATE_DEPTH
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            stud(brass, [sx * (w - 0.014), sy * (h - 0.014), top], Z, 0.006, 0.003)
    for height, words in LINES:
        for left, right in words:
            z = top + 0.0008
            corners = [[left, height - STROKE, z], [right, height - STROKE, z], [right, height + STROKE, z], [left, height + STROKE, z]]
            slab(dark, corners, Z)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    teak = Part("teak", "teak")
    brass = Part("brass", "brass")
    dark = Part("engraving", "dark")
    board(teak)
    plate(brass, dark)
    for part in (teak, brass, dark):
        part.build(collection)
    print("plaque: %d triangles" % triangles(collection))
    save(out)


main()
