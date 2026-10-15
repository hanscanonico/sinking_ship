"""Builds assets/models/crosstree_60/crosstree_60.blend: a mast's crosstree near its
head, made for a mast 0.6 m round (DeckWorks.CROSSTREES), as tools/crosstree.py builds
every size of it.

    make model-sources MODEL=crosstree_60
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/crosstree_60/crosstree_60.py -- \
        assets/models/crosstree_60/crosstree_60.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/crosstree.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from crosstree import build  # noqa: E402

build("crosstree_60", 0.6)
