"""Builds assets/models/luggage_rack/luggage_rack.blend: the luggage rack over a folded
berth in a narrow cabin (CabinDressing._rack), over head height, with a strapped
leather suitcase and a rolled, tied blanket on it, as tools/luggage.py builds a
luggage shelf. Its box is CabinDressing.LUGGAGE_RACK.

    make model-sources MODEL=luggage_rack
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/luggage_rack/luggage_rack.py -- \
        assets/models/luggage_rack/luggage_rack.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/luggage.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from luggage import build, bundle, suitcase  # noqa: E402

HALF = 0.55
LOW = 2.05
DEPTH = 0.28


def luggage(parts, top):
    suitcase(parts["leather"], parts["dark"], parts["brass"], -0.45, 0.05, top, top + 0.17, 0.03, 0.235, (-0.32, -0.08))
    bundle(parts["linen"], parts["rope"], 0.15, 0.42, top, 0.04, 0.23)


build("luggage_rack", HALF, LOW, DEPTH, (-0.45, 0.45), luggage)
