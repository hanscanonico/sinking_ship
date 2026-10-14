"""Builds assets/models/break_door/break_door.blend: the teak weather door in the face
of a break in the decks (ShipFittings._break_door), shut in its frame on a raised
sill — two fielded panels, a louvre over them, a brass kick plate along its foot,
strap hinges on one side and a brass lever handle on the other — in Godot's axes,
metres: x along the face, y up, z out of it, its origin on the face at the foot of
the sill's middle. Its door is ShipFittings.BREAK_DOOR, standing on the sill; its
box over all is BREAK_DOOR_BOX.

    make model-sources MODEL=break_door
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/break_door/break_door.py -- \
        assets/models/break_door/break_door.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, panel, save, slab, triangles, tube  # noqa: E402

# The door's half width and height (ShipFittings.BREAK_DOOR), the sill it stands on
# and how far out the sill stands, and the frame's bar and how far out it stands.
HALF = 0.36
TALL = 1.5
SILL = 0.06
SILL_OUT = 0.08
BAR = 0.07
FRAME_OUT = 0.05
# The door's face, sunk into its frame: its panels' ground, its fielded panels, and
# its stiles' and rails' faces.
GROUND = 0.02
FIELD = 0.026
FACE = 0.035
STILE = 0.09
# Its rails, foot to head, as (bottom, top) over the deck; the louvre between the
# last two.
RAILS = [(SILL, 0.3), (0.78, 0.9), (1.2, 1.28), (1.46, SILL + TALL)]
SLATS = 4

RIGHT = (1.0, 0.0, 0.0)
UP = (0.0, 1.0, 0.0)
OUT = (0.0, 0.0, 1.0)
BACK = (2, -1)


def frame(wood):
    """The frame round the door, on the face, and the sill under it."""
    top = SILL + TALL
    for side in (-1.0, 1.0):
        low = [min(side * HALF, side * (HALF + BAR)), SILL, 0.0]
        high = [max(side * HALF, side * (HALF + BAR)), top + BAR, FRAME_OUT]
        box(wood, low, high, skip=(BACK, (1, -1), (1, 1)), plain=((0, -1), (0, 1)))
    box(wood, [-HALF, top, 0.0], [HALF, top + BAR, FRAME_OUT], skip=(BACK, (0, -1), (0, 1), (1, 1)), plain=((1, -1),))
    box(wood, [-HALF - BAR, 0.0, 0.0], [HALF + BAR, SILL, SILL_OUT], skip=(BACK, (1, -1)), plain=((0, -1), (0, 1)))


def leaf(teak, dark):
    """The door: its stiles and rails over the panels' ground, its two fielded
    panels, and the louvre's slats over a dark ground."""
    top = SILL + TALL
    slab(teak, [[-HALF, SILL, GROUND], [HALF, SILL, GROUND], [HALF, RAILS[2][1], GROUND], [-HALF, RAILS[2][1], GROUND]], OUT)
    slab(teak, [[-HALF, RAILS[3][0], GROUND], [HALF, RAILS[3][0], GROUND], [HALF, top, GROUND], [-HALF, top, GROUND]], OUT)
    inner = HALF - STILE
    for side in (-1.0, 1.0):
        low = [min(side * HALF, side * inner), SILL, GROUND]
        high = [max(side * HALF, side * inner), top, FACE]
        box(teak, low, high, skip=(BACK, (1, -1), (1, 1), (0, side)), plain=((0, -side),))
    for index, (bottom, head) in enumerate(RAILS):
        skip = [BACK, (0, -1), (0, 1)]
        plain = []
        for end, faces in (((1, -1), index > 0), ((1, 1), index < len(RAILS) - 1)):
            (plain if faces else skip).append(end)
        box(teak, [-inner, bottom, GROUND], [inner, head, FACE], skip=tuple(skip), plain=tuple(plain))
    for low, high in ((RAILS[0][1], RAILS[1][0]), (RAILS[1][1], RAILS[2][0])):
        middle = [0.0, (low + high) * 0.5, FIELD]
        panel(teak, middle, RIGHT, UP, (inner - 0.025, (high - low) * 0.5 - 0.025))
    low, high = RAILS[2][1], RAILS[3][0]
    slab(dark, [[-inner, low, GROUND], [inner, low, GROUND], [inner, high, GROUND], [-inner, high, GROUND]], OUT)
    pitch = (high - low) / SLATS
    for k in range(SLATS):
        foot = low + pitch * (k + 0.2)
        corners = [[-inner, foot, FACE - 0.002], [inner, foot, FACE - 0.002], [inner, foot + pitch * 0.9, GROUND + 0.002], [-inner, foot + pitch * 0.9, GROUND + 0.002]]
        slab(teak, corners, [0.0, 0.6, 0.8])


def hardware(brass, iron):
    """The kick plate along its foot, its strap hinges at +x, and its lever handle and
    keyhole at -x."""
    panel(brass, [0.0, (SILL + 0.02 + RAILS[0][1] - 0.04) * 0.5, FACE + 0.0015], RIGHT, UP, (HALF - 0.03, (RAILS[0][1] - 0.04 - SILL - 0.02) * 0.5), rim=0.008)
    for height in (0.42, 1.36):
        box(iron, [HALF - 0.17, height - 0.02, FACE], [HALF, height + 0.02, FACE + 0.004], inked=False, skip=(BACK, (0, 1)))
        knuckle = [(0.012, 0.0, 0.0), (0.012, 1.0, 0.0)]
        tube(iron, [HALF + 0.004, height - 0.06, FACE + 0.012], [HALF + 0.004, height + 0.06, FACE + 0.012], knuckle, 6, caps=(False, False))
    handle = -HALF + STILE * 0.5
    box(brass, [handle - 0.022, 0.92, FACE], [handle + 0.022, 1.1, FACE + 0.006], inked=False, skip=(BACK,))
    lever = [(0.008, 0.0, 0.0), (0.008, 1.0, 0.0)]
    tube(brass, [handle, 1.05, FACE + 0.006], [handle, 1.05, FACE + 0.04], lever, 6, caps=(False, False))
    tube(brass, [handle - 0.008, 1.05, FACE + 0.04], [handle + 0.1, 1.05, FACE + 0.04], [(0.009, 0.0, 0.0), (0.009, 1.0, 0.0)], 6, caps=(False, True))
    slab(iron, [[handle - 0.005, 0.95, FACE + 0.0065], [handle + 0.005, 0.95, FACE + 0.0065], [handle + 0.005, 0.985, FACE + 0.0065], [handle - 0.005, 0.985, FACE + 0.0065]], OUT)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    parts = {paint: Part(paint, paint) for paint in ("frame", "teak", "dark", "brass")}
    frame(parts["frame"])
    leaf(parts["teak"], parts["dark"])
    hardware(parts["brass"], parts["dark"])
    for part in parts.values():
        part.build(collection)
    print("break_door: %d triangles" % triangles(collection))
    save(out)


main()
