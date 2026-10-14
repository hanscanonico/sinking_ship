"""Builds assets/models/handwheel_large/handwheel_large.blend: the handwheel of
radius 0.15 (RoomDressing.HANDWHEELS), an engine's starting wheel — handwheel_small's
shape, built at its own size on five spokes, never a scaled copy.

    make model-sources MODEL=handwheel_large
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/handwheel_large/handwheel_large.py -- \\
        assets/models/handwheel_large/handwheel_large.blend
"""

import os
import sys

# The small wheel's builder, beside this folder; no bytecode left in its folder.
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "handwheel_small"))
from handwheel_small import build  # noqa: E402

build("handwheel_large", 0.15, 0.015, 5, 14, sys.argv[sys.argv.index("--") + 1])
