"""Builds assets/models/fire_buckets/fire_buckets.blend: three fire buckets in their
rack on a wall (RoomDressing.fire_buckets), in Godot's axes, metres: x along the wall,
y up, z out of it into the room, its origin on the wall's face under the rack's middle
at RoomDressing.HEADROOM over the floor, nothing under it. The buckets are the
round-bottomed kind, so nobody takes one for another use: each stands through a hole
in the rack's board, its bottom under it, painted red, a white band round it lettered
FIRE toward the room, its rim rolled.

    make model-sources MODEL=fire_buckets
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/fire_buckets/fire_buckets.py -- \\
        assets/models/fire_buckets/fire_buckets.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, cap, fresh_scene, lathe, save, triangles  # noqa: E402

# The rack's board: half its length, its depth out from the wall, its underside and top.
HALF = 0.45
DEPTH = 0.3
BOARD = (0.06, 0.09)
# The buckets: PITCH apart along it, OUT from the wall; eight-sided, a side square to
# the room.
PITCH = 0.29
OUT = 0.15
SIDES = 8
PHASE = math.pi / SIDES
# A bucket's turned profile, (radius, height, ink), from its round bottom to its rim,
# the white band between BAND's two heights.
LOWER = [(0.0, 0.0, 0.0), (0.08, 0.025, 0.0), (0.104, 0.1, 0.0)]
BAND = [(0.104, 0.1, 0.0), (0.108, 0.155, 0.0)]
UPPER = [(0.108, 0.155, 0.0), (0.113, 0.245, 0.0), (0.118, 0.275, 1.0)]
# The letters on the band: their height and stroke, each one's width and the gap
# between; each letter its strokes as (left, bottom, right, top) in shares of its box.
LETTER = (0.026, 0.0045)
WIDE = 0.015
GAP = 0.005
FIRE = [
    [(0, 0, 0.3, 1), (0, 0.85, 1, 1), (0, 0.45, 0.8, 0.6)],
    [(0.35, 0, 0.65, 1)],
    [(0, 0, 0.3, 1), (0, 0.85, 1, 1), (0, 0.45, 1, 0.6), (0.7, 0.45, 1, 1), (0.6, 0, 0.95, 0.45)],
    [(0, 0, 0.3, 1), (0, 0.85, 1, 1), (0, 0.45, 0.8, 0.6), (0, 0, 1, 0.15)],
]
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])


def rack(part):
    """The board along the wall the buckets stand through."""
    box(
        part,
        [-HALF, BOARD[0], 0.0],
        [HALF, BOARD[1], DEPTH],
        skip=((2, -1.0),),
        plain=((0, -1.0), (0, 1.0), (1, 1.0)),
    )


def bucket(red, white, dark, x):
    """One bucket round x along the wall, its band and its letters."""
    centre = [x, 0.0, OUT]
    lathe(red, centre, UP, LOWER, SIDES, phase=PHASE)
    lathe(white, centre, UP, BAND, SIDES, phase=PHASE)
    rows = lathe(red, centre, UP, UPPER, SIDES, phase=PHASE)
    # The water in it, under its rim.
    cap(dark, rows[-1], [x, UPPER[-1][1], OUT], [0.0, 1.0, 0.0], 0.0)
    # The band's side toward the room: flat, its middle the apothem out.
    radius = (BAND[0][0] + BAND[1][0]) * 0.5
    face = OUT + radius * math.cos(math.pi / SIDES) + 0.003
    middle = (BAND[0][1] + BAND[1][1]) * 0.5
    across = len(FIRE) * WIDE + (len(FIRE) - 1) * GAP
    left = x - across * 0.5
    bottom = middle - LETTER[0] * 0.5
    for index, strokes in enumerate(FIRE):
        start = left + index * (WIDE + GAP)
        for a, b, c, d in strokes:
            x0 = start + a * WIDE
            x1 = start + max(c * WIDE, a * WIDE + LETTER[1])
            y0 = bottom + b * LETTER[0]
            y1 = bottom + max(d * LETTER[0], b * LETTER[0] + LETTER[1])
            corners = [[x0, y0, face], [x1, y0, face], [x1, y1, face], [x0, y1, face]]
            dark.face([dark.point(p) for p in corners], [0.0] * 4, [0.0, 0.0, 1.0])


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    parts = {paint: Part(paint, paint) for paint in ("frame", "fire_bucket", "white", "dark")}
    rack(parts["frame"])
    for index in range(3):
        bucket(parts["fire_bucket"], parts["white"], parts["dark"], (index - 1) * PITCH)
    for part in parts.values():
        part.build(collection, sharp_angle=50.0)
    print("fire_buckets: %d triangles" % triangles(collection))
    save(out)


main()
