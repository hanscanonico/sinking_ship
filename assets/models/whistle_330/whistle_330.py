"""Builds assets/models/whistle_330/whistle_330.blend: what tools/funnel_fittings.py says of a
funnel's whistle, made for a funnel 3.3 m round at scale 2.0
(DeckWorks.FUNNEL_FITTINGS).

    make model-sources MODEL=whistle_330
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/whistle_330/whistle_330.py -- assets/models/whistle_330/whistle_330.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/funnel_fittings.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from funnel_fittings import build_whistle  # noqa: E402

build_whistle("whistle_330", 2.0)
