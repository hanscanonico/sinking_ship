"""Builds assets/models/waste_pipe_head/waste_pipe_head.blend: the head of the waste
steam pipe up a funnel's after face (DeckWorks.funnel) — a flanged joint where the
pipe up the funnel ends at its top, the pipe standing on over the rim to a flared
bell mouth, black inside, and the stay that holds it to the funnel's rim — in Godot's
axes, metres: x toward the funnel, y up, z athwartships, its origin on the pipe's
axis at the funnel's top, the funnel's face DeckWorks.FUNNEL_PIPE_OUT along +x. Its
box is DeckWorks.WASTE_PIPE_HEAD_BOX.

    make model-sources MODEL=waste_pipe_head
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/waste_pipe_head/waste_pipe_head.py -- \
        assets/models/waste_pipe_head/waste_pipe_head.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, cap, fresh_scene, lathe, save, stud, triangles  # noqa: E402

# The funnel's face along +x, the pipe's radius (DeckWorks.FUNNEL_PIPE), how far its
# mouth stands over the funnel's top and its mouth's radius.
OUT = 0.16
PIPE = 0.06
RISE = 0.5
MOUTH = 0.1
# The funnel's rim stands this far proud of its face and this deep under its top.
RIM = (0.04, 0.12)
SIDES = 12
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])


def pipe(iron):
    """The joint's flange, the pipe on over it and its flared mouth, turned, and the
    bore's floor down it."""
    rows = [
        (PIPE - 0.003, -0.02, 0.0),
        (PIPE + 0.022, -0.02, 1.0),
        (PIPE + 0.022, 0.0, 1.0),
        (PIPE, 0.0, 0.0),
        (PIPE, RISE - 0.12, 0.0),
        (MOUTH - 0.015, RISE - 0.03, 0.0),
        (MOUTH, RISE - 0.012, 1.0),
        (MOUTH, RISE, 1.0),
        (MOUTH - 0.014, RISE, 1.0),
        (PIPE - 0.008, RISE - 0.1, 0.0),
    ]
    ring = lathe(iron, (0.0, 0.0, 0.0), UP, rows, SIDES, wound=True)
    cap(iron, ring[-1], [0.0, RISE - 0.1, 0.0], [0.0, 1.0, 0.0], 0.0)
    for k in range(4):
        angle = 2.0 * math.pi * (k + 0.5) / 4
        at = [(PIPE + 0.011) * math.cos(angle), 0.0, (PIPE + 0.011) * math.sin(angle)]
        stud(iron, at, [0.0, 1.0, 0.0], 0.008, 0.006)


def stay(iron):
    """The stay from the pipe to the funnel's rim, and its clip round the pipe."""
    y = -RIM[1] * 0.5
    face = OUT - RIM[0]
    box(iron, [PIPE - 0.004, y - 0.02, -0.012], [face - 0.012, y + 0.02, 0.012], rim=0.01)
    box(iron, [face - 0.012, y - 0.04, -0.04], [face, y + 0.04, 0.04], rim=0.01, skip=((0, 1),))


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    iron = Part("pipe", "dark")
    pipe(iron)
    stay(iron)
    iron.build(collection)
    print("waste_pipe_head: %d triangles" % triangles(collection))
    save(out)


main()
