"""Builds assets/models/pipe_clamp/pipe_clamp.blend: an iron clamp holding a pipe up a
funnel's face (DeckWorks.funnel) — a strap round the pipe on a flat bar riveted to the
funnel — in Godot's axes, metres: x out of the funnel's face toward the pipe, y up,
z across, its origin on the funnel's face at the clamp's middle, the pipe's axis
DeckWorks.FUNNEL_PIPE_OUT out along +x. Its box is DeckWorks.PIPE_CLAMP_BOX.

    make model-sources MODEL=pipe_clamp
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/pipe_clamp/pipe_clamp.py -- \
        assets/models/pipe_clamp/pipe_clamp.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, save, stud, torus, triangles  # noqa: E402

# The pipe's axis out from the face and its radius (DeckWorks.FUNNEL_PIPE).
OUT = 0.16
PIPE = 0.06


def clamp(iron):
    """The foot riveted to the funnel, the bar out from it and the strap round the
    pipe."""
    box(iron, [-0.01, -0.035, -0.045], [0.008, 0.035, 0.045], rim=0.01, skip=((0, -1),), plain=((1, -1), (1, 1)))
    box(iron, [0.008, -0.016, -0.01], [OUT - PIPE, 0.016, 0.01], rim=0.008, skip=((0, -1), (0, 1)))
    axes = ([1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0])
    torus(iron, [OUT, 0.0, 0.0], axes, PIPE + 0.006, (0.006, 0.018), 8, 3)
    for z in (-0.03, 0.03):
        stud(iron, [0.008, 0.0, z], [1.0, 0.0, 0.0], 0.008, 0.006)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    iron = Part("clamp", "dark")
    clamp(iron)
    iron.build(collection)
    print("pipe_clamp: %d triangles" % triangles(collection))
    save(out)


main()
