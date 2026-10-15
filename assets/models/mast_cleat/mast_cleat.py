"""Builds assets/models/mast_cleat/mast_cleat.blend: a belaying cleat on a mast's side
over the deck (DeckWorks.mast), the halyards made fast to it — a teak cleat, its two
horns tapering from its waist, on two legs off a pad bolted to the mast — in Godot's
axes, metres: x along the mast's face, y up, z out of it, its origin on the mast's
face at the cleat's middle. Its box is DeckWorks.CLEAT_BOX.

    make model-sources MODEL=mast_cleat
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/mast_cleat/mast_cleat.py -- \
        assets/models/mast_cleat/mast_cleat.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, save, stud, triangles, tube  # noqa: E402

# Its horns' reach up and down, and their axis out from the face.
HORN = 0.15
OUT = 0.075


def cleat(wood):
    """The pad on the mast, the legs off it and the horns across them."""
    box(wood, [-0.032, -0.08, -0.01], [0.032, 0.08, 0.022], skip=((2, -1),))
    for y in (-0.05, 0.03):
        box(wood, [-0.018, y, 0.022], [0.018, y + 0.02, OUT - 0.008], rim=0.008, skip=((2, -1), (2, 1)))
    tube(
        wood,
        [0.0, -HORN, OUT],
        [0.0, HORN, OUT],
        [
            (0.008, 0.0, 1.0),
            (0.013, 0.08, 0.0),
            (0.019, 0.5, 0.0),
            (0.013, 0.92, 0.0),
            (0.008, 1.0, 1.0),
        ],
        6,
        caps=(True, True),
    )


def bolts(iron):
    """The pad's bolt heads."""
    for y in (-0.068, 0.068):
        stud(iron, [0.0, y, 0.022], [0.0, 0.0, 1.0], 0.009, 0.006)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    wood = Part("cleat", "teak")
    iron = Part("bolts", "dark")
    cleat(wood)
    bolts(iron)
    wood.build(collection)
    iron.build(collection)
    print("mast_cleat: %d triangles" % triangles(collection))
    save(out)


main()
