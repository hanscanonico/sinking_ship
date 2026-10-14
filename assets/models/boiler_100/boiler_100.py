"""Builds assets/models/boiler_100/boiler_100.blend: a Scotch boiler's front of radius
1.0 m, in its engine room's bulkhead (EngineRoom._boiler, EngineRoom.BOILER_FRONTS),
as tools/boiler_front.py builds every size of it.

    make model-sources MODEL=boiler_100
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/boiler_100/boiler_100.py -- assets/models/boiler_100/boiler_100.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/boiler_front.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from boiler_front import build  # noqa: E402

build(1.0)
