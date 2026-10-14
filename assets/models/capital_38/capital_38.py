"""Builds assets/models/capital_38/capital_38.blend: the first-class dining saloon's
pilaster capital (LinerDining._pilaster), 0.38 m along its wall (RoomDressing.CAPITALS),
LinerDining.CAPITAL_HEIGHT tall and CAPITAL.y out, over a shaft LinerDining.PILASTER
wide and out, as tools/capital.py builds every width of it. Painted white, swapped for
the saloon's gilt.

    make model-sources MODEL=capital_38
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/capital_38/capital_38.py -- assets/models/capital_38/capital_38.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/capital.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from capital import build  # noqa: E402

build("capital_38", 0.38, 0.18, 0.115, (0.3, 0.1))
