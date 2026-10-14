"""Builds assets/models/gauge_large/gauge_large.blend: the pressure gauge of radius
0.11 (RoomDressing.GAUGES) — gauge_small's shape, built at its own size, never a
scaled copy.

    make model-sources MODEL=gauge_large
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/gauge_large/gauge_large.py -- \\
        assets/models/gauge_large/gauge_large.blend
"""

import os
import sys

# The small gauge's builder, beside this folder; no bytecode left in its folder.
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "gauge_small"))
from gauge_small import build  # noqa: E402

build("gauge_large", 0.11, sys.argv[sys.argv.index("--") + 1])
