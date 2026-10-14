"""Builds assets/models/deck_pipe_13/deck_pipe_13.blend: a cast-iron pipe's mouth on
the deck at the bow, its flange 0.13 m round (ShipFittings.DECK_PIPES), as
tools/deck_pipe.py builds every size of it.

    make model-sources MODEL=deck_pipe_13
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/deck_pipe_13/deck_pipe_13.py -- \
        assets/models/deck_pipe_13/deck_pipe_13.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/deck_pipe.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from deck_pipe import build  # noqa: E402

build("deck_pipe_13", 0.13, 12, 4)
