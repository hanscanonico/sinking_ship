"""Builds assets/models/dresser_180/dresser_180.blend: a galley's plate rack 1.8 m wide
(LinerService.DRESSERS), as tools/dresser.py builds every size of it.

    make model-sources MODEL=dresser_180
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/dresser_180/dresser_180.py -- \\
        assets/models/dresser_180/dresser_180.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/dresser.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from dresser import build  # noqa: E402

build("dresser_180", 1.8)
