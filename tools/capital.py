"""A pilaster's capital flat on its wall under the ceiling (RoomDressing.CAPITALS), for
the capital_NN build scripts (assets/models/capital_NN/capital_NN.py): one width
each, NN hundredths of a metre, never one model scaled. A moulded abacus under the
ceiling, a bell narrowing from it to the shaft's width, a volute scrolled at each of
its upper corners and a rosette between them, over a necking band at the shaft's
head. The pilaster's shaft is the placing code's, sized to its wall.

In Godot's axes, metres: x along the wall (Wall.right), y up, z out from the wall's
face, its origin on the wall's face at the capital's top middle, under the ceiling;
it hangs down from there. It is painted white all over, the paint the placing code
swaps for its room's.
"""

import math
import sys

from model_kit import Part, box, cap, fresh_scene, lathe, save, stud, triangles

BACK = (2, -1)
TOP = (1, 1)
# Faces drawn whole: the narrow ends and undersides, inked by their neighbours' rims.
SIDES = ((0, -1), (0, 1), (1, -1))
Z = [0.0, 0.0, 1.0]


def build(name, width, height, depth, shaft):
    """capital_NN, [width] along its wall, [height] tall and [depth] out, over a shaft
    [shaft] wide (x) and out (y); written to the path after --."""
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    part = Part(name, "white")
    half = width * 0.5
    abacus = height * 0.22
    neck = height * 0.18
    bell_low = -height + neck
    # The abacus under the ceiling, the full width and depth.
    box(part, [-half, -abacus, 0.0], [half, 0.0, depth], skip=(BACK, TOP), plain=SIDES)
    # The bell: its front a trapezoid from under the abacus in to the shaft's width,
    # uninked: the abacus's and the necking's rims ink its edges.
    face = depth - 0.012
    top_half = half - 0.02
    low_half = shaft[0] * 0.5 + 0.006
    front = [[-low_half, bell_low, face], [low_half, bell_low, face], [top_half, -abacus, face], [-top_half, -abacus, face]]
    part.face([part.point(p) for p in front], [0.0, 0.0, 0.0, 0.0], Z)
    for side in (-1.0, 1.0):
        ends = [[side * low_half, bell_low, 0.0], [side * low_half, bell_low, face], [side * top_half, -abacus, face], [side * top_half, -abacus, 0.0]]
        part.face([part.point(p) for p in ends], [0.0, 0.0, 0.0, 0.0], [side, -0.3, 0.0])
    # A volute at each upper corner, inked round its rim, and a rosette between them.
    eye = height * 0.12
    for side in (-1.0, 1.0):
        centre = [side * (top_half - eye * 0.9), -abacus - eye * 1.05, face]
        rows = lathe(part, centre, ([1.0, 0.0, 0.0], [0.0, 1.0, 0.0], Z), [(eye, 0.0, 1.0), (eye * 0.55, 0.012, 0.0)], 5, phase=side * 0.4)
        cap(part, rows[-1], [centre[0], centre[1], face + 0.012], Z, 0.0)
    stud(part, [0.0, -abacus - height * 0.2, face], Z, height * 0.1, 0.014, 4, math.pi / 4.0)
    # The necking band round the shaft's head.
    box(part, [-low_half - 0.008, -height, 0.0], [low_half + 0.008, bell_low, shaft[1] + 0.008], skip=(BACK, TOP), plain=SIDES)
    part.build(collection)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)
