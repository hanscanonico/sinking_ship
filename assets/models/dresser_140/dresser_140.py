"""Builds assets/models/dresser_140/dresser_140.blend: a galley's plate rack 1.4 m wide
(LinerService.DRESSERS), as tools/dresser.py builds every size of it.

    make model-sources MODEL=dresser_140
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/dresser_140/dresser_140.py -- \\
        assets/models/dresser_140/dresser_140.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/dresser.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from dresser import build  # noqa: E402

build("dresser_140", 1.4)
