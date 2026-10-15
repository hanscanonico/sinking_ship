"""Builds assets/models/copper_pan_120/copper_pan_120.blend: a copper pan 0.12 m round
hung on the galley's rack (LinerService.PANS), as tools/copper_pan.py builds every
size of it.

    make model-sources MODEL=copper_pan_120
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/copper_pan_120/copper_pan_120.py -- \\
        assets/models/copper_pan_120/copper_pan_120.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/copper_pan.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from copper_pan import build  # noqa: E402

build("copper_pan_120", 0.12, 8)
