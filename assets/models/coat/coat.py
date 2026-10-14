"""Builds assets/models/coat/coat.blend: an overcoat hung from a brass hook on a cabin's
wall (CabinDressing.coat) — narrow at the collar, its shoulders sloping and its skirt
flaring to the hem, full across its front, its sleeves hanging at its sides, a row of
brass buttons down its fly and two pocket flaps — in Godot's axes, metres: x along the
wall (Wall.right), y up, z out from the wall's face into the room, its origin on the
floor at the wall's face under the hook. Its collar and cuffs are painted blanket, for
the placing code to draw in its cabin's colour. Nothing stands further out than
CabinDressing.COAT's depth.

    make model-sources MODEL=coat
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/coat/coat.py -- assets/models/coat/coat.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, save, slab, stud, sweep, triangles  # noqa: E402

HOOK = 1.75
# Its outline: (height, half width, ink) from the collar down to the hem, a row just
# in from the collar and the hem so their ink stays a band.
ROWS = [(1.71, 0.07, 1.0), (1.69, 0.1, 0.0), (1.62, 0.18, 0.0), (1.3, 0.19, 0.0), (1.0, 0.218, 0.0), (0.98, 0.22, 1.0)]
# Across it: (share of its half width, ink), its sides inked, and how far out its
# middle and its sides stand.
COLUMNS = [(-1.0, 1.0), (-0.9, 0.0), (-0.4, 0.0), (0.0, 0.0), (0.4, 0.0), (0.9, 0.0), (1.0, 1.0)]
FRONT = 0.075
SIDE = 0.03
# The sleeves: from the shoulder to the cuff, out from the front, and their radius.
SHOULDER = (0.17, 1.58)
CUFF = (0.205, 1.12)
SLEEVE = 0.035
SLEEVE_OUT = 0.06
# The collar: (height, half width) from the neck down to its V, and across it (share
# of its half width, ink), inked at its edges.
COLLAR = [(1.706, 0.068), (1.69, 0.1), (1.665, 0.11), (1.62, 0.06), (1.57, 0.0)]
COLLAR_COLUMNS = [(-1.0, 1.0), (-0.75, 0.0), (0.0, 0.0), (0.75, 0.0), (1.0, 1.0)]

Z = [0.0, 0.0, 1.0]


def out_at(share):
    """How far out the coat's front stands at share of its half width."""
    return SIDE + (FRONT - SIDE) * (1.0 - share * share)


def body(leather):
    """Its front, full across its middle, and its sides, shoulders and hem back to the
    wall."""
    rows = []
    inks = []
    for height, half, row_ink in ROWS:
        rows.append([[share * half, height, out_at(share)] for share, _ in COLUMNS])
        inks.append([max(row_ink, ink) for _, ink in COLUMNS])
    leather.grid(rows, None, lambda p: Z, row_inks=inks)
    # Its sides from the front's edge back to the wall, and its shoulders and hem.
    for side in (-1.0, 1.0):
        for (h0, w0, _), (h1, w1, _) in zip(ROWS, ROWS[1:]):
            quad = [[side * w0, h0, SIDE], [side * w1, h1, SIDE], [side * w1, h1, 0.0], [side * w0, h0, 0.0]]
            slab(leather, quad, [side * (h0 - h1), w1 - w0, 0.0], 1.0)
    for height, half, _ in (ROWS[0], ROWS[-1]):
        up = 1.0 if height == ROWS[0][0] else -1.0
        for (s0, _), (s1, _) in zip(COLUMNS, COLUMNS[1:]):
            quad = [[s0 * half, height, out_at(s0)], [s1 * half, height, out_at(s1)], [s1 * half, height, 0.0], [s0 * half, height, 0.0]]
            slab(leather, quad, [0.0, up, 0.0], 1.0)


def half_at(height):
    """The coat's half width at height, between its outline's rows."""
    for (h0, w0, _), (h1, w1, _) in zip(ROWS, ROWS[1:]):
        if h1 <= height <= h0:
            return w0 + (w1 - w0) * (h0 - height) / (h0 - h1)
    return ROWS[-1][1]


def collar(cloth):
    """A turned-down collar from the neck to a V at the chest, lying on its front."""
    rows = []
    for height, half in COLLAR:
        body = half_at(height)
        rows.append([[share * half, height, out_at(share * half / body) + 0.006] for share, _ in COLLAR_COLUMNS])
    inks = [[ink for _, ink in COLLAR_COLUMNS] for _ in COLLAR]
    inks[0] = [1.0] * len(COLLAR_COLUMNS)
    cloth.grid(rows, None, lambda p: Z, row_inks=inks)


def sleeves(leather, cloth):
    """A sleeve down each side from its shoulder, bent a little at the elbow, and a
    cuff round its end."""
    for side in (-1.0, 1.0):
        elbow = (SHOULDER[0] + CUFF[0]) * 0.5 + 0.015
        path = [
            [side * SHOULDER[0], SHOULDER[1], SLEEVE_OUT],
            [side * elbow, (SHOULDER[1] + CUFF[1]) * 0.5, SLEEVE_OUT],
            [side * CUFF[0], CUFF[1], SLEEVE_OUT],
        ]
        sweep(leather, path, SLEEVE, 6, ink=0.0, caps=True)
        back = [c + (e - c) * 0.8 for e, c in zip(path[2], path[1])]
        sweep(cloth, [back, path[2]], SLEEVE + 0.003, 6, ink=0.0, caps=False)


def fittings(brass, dark):
    """The hook, the fly down the front with its buttons, and the pocket flaps."""
    sweep(brass, [[0.0, HOOK - 0.03, 0.0], [0.0, HOOK - 0.03, 0.035], [0.0, HOOK + 0.0, 0.05]], 0.007, 4, caps=False)
    stud(brass, [0.0, HOOK - 0.03, 0.0], Z, 0.02, 0.006, 4)
    fly = FRONT + 0.0015
    slab(dark, [[-0.003, 1.0, fly], [0.003, 1.0, fly], [0.003, 1.62, fly], [-0.003, 1.62, fly]], Z)
    for button in range(3):
        stud(brass, [0.035, 1.5 - button * 0.14, FRONT - 0.001], Z, 0.013, 0.007, 5)
    for side in (-1.0, 1.0):
        x0 = side * 0.06
        x1 = side * 0.16
        z0 = out_at(0.3) + 0.0015
        z1 = out_at(0.75) + 0.0015
        slab(dark, [[x0, 1.205, z0], [x1, 1.205, z1], [x1, 1.215, z1], [x0, 1.215, z0]], Z)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    leather = Part("leather", "leather")
    brass = Part("brass", "brass")
    dark = Part("dark", "dark")
    cloth = Part("collar", "blanket")
    body(leather)
    collar(cloth)
    sleeves(leather, cloth)
    fittings(brass, dark)
    for part in (leather, cloth, brass, dark):
        part.build(collection)
    print("coat: %d triangles" % triangles(collection))
    save(out)


main()
