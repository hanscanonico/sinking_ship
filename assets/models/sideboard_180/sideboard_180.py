"""Builds assets/models/sideboard_180/sideboard_180.blend: the first-class dining
saloon's sideboard (LinerDining._sideboard), 1.8 m along its wall
(CabinDressing.SIDEBOARDS): three cupboard doors under three drawers between carved
stiles, a mahogany top LinerDining.SIDEBOARD.z over the floor and SIDEBOARD.y out, and
a brass gallery rail SIDEBOARD_GALLERY over it, as tools/sideboard.py builds every
length of it.

    make model-sources MODEL=sideboard_180
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/sideboard_180/sideboard_180.py -- \
        assets/models/sideboard_180/sideboard_180.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/sideboard.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from sideboard import build  # noqa: E402

build("sideboard_180", 1.8, 1.0, 0.115, 3, 0.12, "frame")
