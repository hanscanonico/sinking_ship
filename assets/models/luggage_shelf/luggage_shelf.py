"""Builds assets/models/luggage_shelf/luggage_shelf.blend: the shelf over a cabin's
doorway (CabinDressing.luggage_shelf), over head height, with a strapped suitcase on
it, as tools/luggage.py builds a luggage shelf. Its box is CabinDressing.LUGGAGE_SHELF.

    make model-sources MODEL=luggage_shelf
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/luggage_shelf/luggage_shelf.py -- \
        assets/models/luggage_shelf/luggage_shelf.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/luggage.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from luggage import build, suitcase  # noqa: E402

HALF = 0.35
LOW = 2.1
DEPTH = 0.3


def luggage(parts, top):
    suitcase(parts["upholstery"], parts["dark"], parts["brass"], -0.24, 0.24, top, top + 0.18, 0.04, 0.26, (-0.13, 0.13))


build("luggage_shelf", HALF, LOW, DEPTH, (-0.25, 0.25), luggage)
