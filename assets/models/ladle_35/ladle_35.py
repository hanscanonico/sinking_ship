"""Builds assets/models/ladle_35/ladle_35.blend: a tinned ladle hanging 0.35 m under the
galley's rack (LinerService.LADLES), as tools/ladle.py builds every size of it.

    make model-sources MODEL=ladle_35
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/ladle_35/ladle_35.py -- \\
        assets/models/ladle_35/ladle_35.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/ladle.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from ladle import build  # noqa: E402

build("ladle_35", 0.35, 6)
