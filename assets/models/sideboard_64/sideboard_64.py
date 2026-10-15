"""Builds assets/models/sideboard_64/sideboard_64.blend: the steamer's saloon's
sideboard (CabinDressing._sideboard), 0.64 m along its wall
(CabinDressing.SIDEBOARDS): two cupboard doors under two drawers between carved
stiles, a marble top, a brass gallery rail along its back and a decanter and a pair
of glasses on it, in CabinDressing.SIDEBOARD's box, as tools/sideboard.py builds every
length of it.

    make model-sources MODEL=sideboard_64
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/sideboard_64/sideboard_64.py -- \
        assets/models/sideboard_64/sideboard_64.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/sideboard.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from sideboard import build  # noqa: E402

build("sideboard_64", 0.64, 0.78, 0.11, 2, 0.1, "enamel", things=True)
