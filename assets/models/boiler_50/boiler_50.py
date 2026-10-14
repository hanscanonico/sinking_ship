"""Builds assets/models/boiler_50/boiler_50.blend: a Scotch boiler's front of radius
0.5 m, in its engine room's bulkhead (EngineRoom._boiler, EngineRoom.BOILER_FRONTS),
as tools/boiler_front.py builds every size of it.

    make model-sources MODEL=boiler_50
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/boiler_50/boiler_50.py -- assets/models/boiler_50/boiler_50.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/boiler_front.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from boiler_front import build  # noqa: E402

build(0.5)
