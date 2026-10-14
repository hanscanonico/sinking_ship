"""Builds assets/models/berth/berth.blend: a berth slung overhead along a wall
(RoomDressing.slung_berth), in Godot's axes, metres: x along the wall, its head
toward -x, y up, z out of the wall into the room, its origin on the wall's face under
the berth's middle at its underside (RoomDressing.HEADROOM over the floor). It is
RoomDressing.BERTH long and deep: a board on battens between a head and a foot end, a
side board along its front, a mattress, a pillow at its head and a blanket folded in
three on its foot half, and on each end's cap, at RoomDressing.BERTH_EYE, the steel
eye its chain goes up from (the chain itself is drawn by the placing code, for every
deckhead stands at its own height). The blanket is painted `blanket`, which the
placing code repaints in the cabin's own colour.

    make model-sources MODEL=berth
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/berth/berth.py -- assets/models/berth/berth.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, save, stud, triangles  # noqa: E402

# RoomDressing.BERTH: its length along the wall and its depth out from it.
HALF = 0.95
DEPTH = 0.7
# Its ends: their thickness and their height; the cap on each one's front corner, its
# top, and the eye on it the chain goes up from (RoomDressing.BERTH_EYE).
END = 0.05
TALL = 0.4
CAP = (0.07, 0.38, 0.44)
EYE = (0.915, 0.46, 0.665)
# The side board along its front, and the board the mattress lies on, on its battens.
SIDE = 0.05
SIDE_TALL = 0.1
BATTEN = 0.03
BOARD = 0.02
MATTRESS = 0.19
INNER = HALF - END
WALL = (2, -1.0)


def frame(part):
    """The ends, the side board, the bed board and the battens under it."""
    for sign in (-1.0, 1.0):
        outer = sign * HALF
        inner = sign * INNER
        low = [min(outer, inner), 0.0, 0.0]
        high = [max(outer, inner), TALL, DEPTH]
        box(part, low, high, skip=(WALL,), plain=((1, -1.0), (1, 1.0), (2, 1.0)))
        cap_in = sign * (HALF - CAP[0])
        box(
            part,
            [min(outer, cap_in), CAP[1], DEPTH - CAP[0]],
            [max(outer, cap_in), CAP[2], DEPTH],
            skip=(WALL,),
            plain=((0, -sign), (1, -1.0), (1, 1.0)),
        )
    box(
        part,
        [-INNER, 0.0, DEPTH - SIDE],
        [INNER, SIDE_TALL, DEPTH],
        skip=(WALL, (0, -1.0), (0, 1.0), (2, -1.0)),
        plain=((1, -1.0), (1, 1.0)),
    )
    # The bed board's underside, between the battens.
    box(
        part,
        [-INNER, BATTEN, 0.0],
        [INNER, BATTEN + BOARD, DEPTH - SIDE],
        inked=False,
        skip=(WALL, (0, -1.0), (0, 1.0), (1, 1.0), (2, 1.0)),
    )
    for x in (-0.45, 0.0, 0.45):
        box(
            part,
            [x - 0.03, 0.0, 0.0],
            [x + 0.03, BATTEN, DEPTH - SIDE],
            inked=False,
            skip=(WALL, (1, 1.0), (2, 1.0)),
        )


def bedding(linen):
    """The mattress the length of the berth and the pillow at its head."""
    box(
        linen,
        [-INNER, BATTEN + BOARD, 0.0],
        [INNER, MATTRESS, DEPTH - 0.06],
        skip=(WALL, (0, -1.0), (0, 1.0), (1, -1.0)),
        rim=0.025,
    )
    box(
        linen,
        [-INNER + 0.02, MATTRESS, 0.06],
        [-0.5, 0.3, DEPTH - 0.12],
        skip=(WALL, (0, -1.0), (1, -1.0)),
        rim=0.03,
    )


def blanket(part):
    """The blanket folded in three on the foot half, its folds showing along its front,
    proud of the mattress."""
    low = 0.0
    high = INNER
    bottom = MATTRESS
    top = MATTRESS + 0.1
    front = DEPTH - 0.03
    box(part, [low, bottom, 0.06], [high, top, front], skip=(WALL, (0, 1.0), (1, -1.0), (2, 1.0)))
    # Its front: its three layers, a fold inked between each two, a rim loop either side.
    rows = [(bottom, 1.0), (bottom + 0.012, 0.0)]
    for share in (1.0 / 3.0, 2.0 / 3.0):
        fold = bottom + (top - bottom) * share
        rows += [(fold - 0.01, 0.0), (fold, 1.0), (fold + 0.01, 0.0)]
    rows += [(top - 0.012, 0.0), (top, 1.0)]
    for (y0, ink0), (y1, ink1) in zip(rows, rows[1:]):
        corners = [[low, y0, front], [high, y0, front], [high, y1, front], [low, y1, front]]
        part.face([part.point(c) for c in corners], [ink0, ink0, ink1, ink1], [0.0, 0.0, 1.0])


def eyes(steel):
    """The eye on each end's cap its chain hangs from."""
    for sign in (-1.0, 1.0):
        stud(steel, [sign * EYE[0], CAP[2], EYE[2]], [0.0, 1.0, 0.0], 0.018, EYE[1] - CAP[2])


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    parts = {paint: Part(paint, paint) for paint in ("frame", "linen", "blanket", "steel")}
    frame(parts["frame"])
    bedding(parts["linen"])
    blanket(parts["blanket"])
    eyes(parts["steel"])
    for part in parts.values():
        part.build(collection)
    print("berth: %d triangles" % triangles(collection))
    save(out)


main()
