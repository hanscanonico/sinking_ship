"""Builds assets/models/capital_32/capital_32.blend: a public room's pilaster capital
(LinerPublic._pilaster), 0.32 m along its wall (RoomDressing.CAPITALS), 0.16 m tall and
LinerPublic.DEPTH out, over a shaft LinerPublic.PILASTER wide and out, as
tools/capital.py builds every width of it. Painted white, swapped for its room's own.

    make model-sources MODEL=capital_32
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/capital_32/capital_32.py -- assets/models/capital_32/capital_32.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/capital.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from capital import build  # noqa: E402

build("capital_32", 0.32, 0.16, 0.11, (0.24, 0.1))
