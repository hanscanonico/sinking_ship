"""Builds assets/models/stowed_crate_80/stowed_crate_80.blend: a crate stowed on a
hold's tween deck, 0.8 m square and 0.68 m tall (CargoHold.STOWED_CRATES), as
tools/stowed_crate.py builds every size of it.

    make model-sources MODEL=stowed_crate_80
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/stowed_crate_80/stowed_crate_80.py -- \
        assets/models/stowed_crate_80/stowed_crate_80.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/stowed_crate.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from stowed_crate import build  # noqa: E402

build("stowed_crate_80", 0.8, 0.68)
