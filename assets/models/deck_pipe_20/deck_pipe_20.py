"""Builds assets/models/deck_pipe_20/deck_pipe_20.blend: a cast-iron pipe's mouth on
the deck at the bow, its flange 0.2 m round (ShipFittings.DECK_PIPES), as
tools/deck_pipe.py builds every size of it.

    make model-sources MODEL=deck_pipe_20
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/deck_pipe_20/deck_pipe_20.py -- \
        assets/models/deck_pipe_20/deck_pipe_20.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/deck_pipe.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from deck_pipe import build  # noqa: E402

build("deck_pipe_20", 0.2, 12, 6)
