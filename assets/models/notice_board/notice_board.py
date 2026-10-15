"""Builds assets/models/notice_board/notice_board.blend: a notice board flat on its
wall (LinerService._notice_board), in Godot's axes, metres: x along the wall, y up,
z out of it into the room, its origin on the wall's face at the board's middle. Cork
in a moulded frame, four printed notices pinned to it with brass pins, one curling at its
foot; its box is LinerService.NOTICE_BOARD, flat to its wall.

    make model-sources MODEL=notice_board
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/notice_board/notice_board.py -- \\
        assets/models/notice_board/notice_board.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, save, slab, stud, triangles  # noqa: E402

# The cork's half size and how far out its face stands; the frame round it, its
# width and depth.
CORK = (0.3, 0.22)
CORK_OUT = 0.012
FRAME = 0.025
DEPTH = 0.022
# The notices: (middle along, middle up, half width, half height), and how far the
# last one's foot curls out.
NOTICES = [
    (-0.17, 0.08, 0.08, 0.1),
    (0.06, 0.1, 0.1, 0.07),
    (0.12, -0.1, 0.09, 0.09),
    (-0.12, -0.11, 0.07, 0.08),
]
CURL = 0.012
# The print on each: its lines' (share of its width, thickness), from its head.
PRINT = [(0.8, 0.008), (0.95, 0.004), (0.7, 0.004)]
Z = [0.0, 0.0, 1.0]


def frame(wood, cork):
    """The cork, and the frame's four rails round it."""
    w, h = CORK
    slab(cork, [[-w, -h, CORK_OUT], [w, -h, CORK_OUT], [w, h, CORK_OUT], [-w, h, CORK_OUT]], Z)
    back = ((2, -1),)
    box(wood, [-w - FRAME, h, 0.0], [w + FRAME, h + FRAME, DEPTH], skip=back)
    box(wood, [-w - FRAME, -h - FRAME, 0.0], [w + FRAME, -h, DEPTH], skip=back)
    for x in (-w - FRAME, w):
        box(wood, [x, -h, 0.0], [x + FRAME, h, DEPTH], skip=back + ((1, -1), (1, 1)))


def notices(paper, brass, ink):
    """Each notice flat on the cork, pinned at its head under a printed heading and
    two lines; the last curling at its foot."""
    z = CORK_OUT + 0.002
    for index, (x, y, w, h) in enumerate(NOTICES):
        low = y - h
        if index == len(NOTICES) - 1:
            bend = y - h * 0.5
            slab(paper, [[x - w, bend, z], [x + w, bend, z], [x + w, y + h, z], [x - w, y + h, z]], Z)
            curl = [[x - w, low, z + CURL], [x + w, low, z + CURL], [x + w, bend, z], [x - w, bend, z]]
            slab(paper, curl, [0.0, 0.5, 1.0])
        else:
            slab(paper, [[x - w, low, z], [x + w, low, z], [x + w, y + h, z], [x - w, y + h, z]], Z)
        stud(brass, [x, y + h - 0.015, z], Z, 0.005, 0.004)
        for line, (share, thick) in enumerate(PRINT):
            top = y + h - 0.03 - line * 0.022
            right = x - w + 0.015 + (w * 2.0 - 0.03) * share
            print_at = [[x - w + 0.015, top - thick, z + 0.0008], [right, top - thick, z + 0.0008]]
            print_at += [[right, top, z + 0.0008], [x - w + 0.015, top, z + 0.0008]]
            slab(ink, print_at, Z)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    wood = Part("frame", "frame")
    cork = Part("cork", "cork")
    paper = Part("notices", "chart")
    brass = Part("pins", "brass")
    ink = Part("print", "dark")
    frame(wood, cork)
    notices(paper, brass, ink)
    for part in (wood, cork, paper, brass, ink):
        part.build(collection)
    print("notice_board: %d triangles" % triangles(collection))
    save(out)


main()
