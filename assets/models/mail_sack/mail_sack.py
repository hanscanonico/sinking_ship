"""Builds assets/models/mail_sack/mail_sack.blend: a mail sack hung on its hook in
the post office (LinerService._mail_sacks), in Godot's axes, metres: x along the
wall, y up, z out of it into the room, its origin on the wall's face under the hook
at RoomDressing.HEADROOM, nothing under it. A canvas sack, full and flattened
against the wall, its neck tied with a cord looped over an iron hook out from the
wall, stencilled G R — the King's cipher — toward the room; turned by
RoomDressing.facing() so its lettering is never mirrored. Its box is
LinerService.MAIL_SACK.

    make model-sources MODEL=mail_sack
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/mail_sack/mail_sack.py -- assets/models/mail_sack/mail_sack.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, lathe, save, sweep, triangles  # noqa: E402

# The sack: its axis's distance out from the wall, how much flatter it is out from
# the wall than along it, its sides, a side square to the room.
OUT = 0.175
FLAT = 0.7
SIDES = 8
PHASE = math.pi / SIDES
# Its turned profile, (half width along the wall, height, ink): from its foot, full
# and flat-faced, in to the neck, then the ruffle over the tie.
PROFILE = [
    (0.0, 0.02, 0.0),
    (0.1, 0.03, 0.0),
    (0.145, 0.09, 0.0),
    (0.145, 0.25, 0.0),
    (0.1, 0.315, 0.0),
    (0.035, 0.36, 0.0),
    (0.035, 0.375, 0.0),
    (0.06, 0.405, 1.0),
]
# The tie round the neck: its height and its thickness.
TIE = (0.367, 0.012)
# The hook: its height, how far out it reaches and how far its tip turns up.
HOOK = (0.415, 0.2, 0.015)
# The letters on the sack's face: their middle's height, their height and stroke,
# each one's width and the gap between; each its strokes as (left, bottom, right,
# top) in shares of its box.
LETTER_AT = 0.18
LETTER = (0.04, 0.008)
WIDE = 0.026
GAP = 0.022
CIPHER = [
    [(0, 0, 0.3, 1), (0, 0.85, 1, 1), (0, 0, 1, 0.15), (0.7, 0, 1, 0.55), (0.45, 0.42, 1, 0.57)],
    [(0, 0, 0.3, 1), (0, 0.85, 1, 1), (0.7, 0.45, 1, 1), (0, 0.45, 1, 0.6), (0.62, 0, 0.92, 0.4)],
]
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -FLAT], [0.0, 1.0, 0.0])


def sack(canvas):
    """The sack, turned round its axis, flattened toward the wall."""
    lathe(canvas, [0.0, 0.0, OUT], UP, PROFILE, SIDES, phase=PHASE, wound=True)


def tie(cord):
    """The cord round its neck, and its loop up over the hook."""
    neck = PROFILE[5][0]
    low = TIE[0] - TIE[1] * 0.5
    lathe(cord, [0.0, low, OUT], UP, [(neck + 0.006, 0.0, 0.0), (neck + 0.01, TIE[1] * 0.5, 0.0), (neck + 0.006, TIE[1], 0.0)], SIDES, phase=PHASE)
    loop = [[-0.02, TIE[0], OUT], [0.0, HOOK[0] + 0.008, HOOK[1] - 0.012], [0.02, TIE[0], OUT]]
    sweep(cord, loop, 0.005, 4, caps=False)


def hook(iron):
    """The hook's plate on the wall and its arm out and up."""
    box(iron, [-0.025, HOOK[0] - 0.03, 0.0], [0.025, HOOK[0] + 0.02, 0.01], inked=False, skip=((2, -1),))
    arm = [[0.0, HOOK[0], 0.005], [0.0, HOOK[0], HOOK[1] - 0.02], [0.0, HOOK[0] + 0.005, HOOK[1] - 0.004], [0.0, HOOK[0] + HOOK[2], HOOK[1]]]
    sweep(iron, arm, 0.006, 4)


def cipher(stencil):
    """G R on the sack's flat face toward the room."""
    face = OUT + FLAT * PROFILE[2][0] * math.cos(PHASE) + 0.002
    across = len(CIPHER) * WIDE + (len(CIPHER) - 1) * GAP
    left = -across * 0.5
    bottom = LETTER_AT - LETTER[0] * 0.5
    for index, strokes in enumerate(CIPHER):
        start = left + index * (WIDE + GAP)
        for a, b, c, d in strokes:
            x0 = start + a * WIDE
            x1 = start + max(c * WIDE, a * WIDE + LETTER[1])
            y0 = bottom + b * LETTER[0]
            y1 = bottom + max(d * LETTER[0], b * LETTER[0] + LETTER[1])
            corners = [[x0, y0, face], [x1, y0, face], [x1, y1, face], [x0, y1, face]]
            stencil.face([stencil.point(p) for p in corners], [0.0] * 4, [0.0, 0.0, 1.0])


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    parts = {paint: Part(paint, paint) for paint in ("sacking", "rope", "dark", "stencil")}
    sack(parts["sacking"])
    tie(parts["rope"])
    hook(parts["dark"])
    cipher(parts["stencil"])
    for part in parts.values():
        part.build(collection)
    print("mail_sack: %d triangles" % triangles(collection))
    save(out)


main()
