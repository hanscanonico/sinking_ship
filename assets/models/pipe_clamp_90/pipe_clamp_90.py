"""Builds assets/models/pipe_clamp_90/pipe_clamp_90.blend: what tools/funnel_fittings.py says of a
funnel's pipe clamp, made for a funnel 0.9 m round at scale 1.0
(DeckWorks.FUNNEL_FITTINGS).

    make model-sources MODEL=pipe_clamp_90
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/pipe_clamp_90/pipe_clamp_90.py -- assets/models/pipe_clamp_90/pipe_clamp_90.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py and tools/funnel_fittings.py, three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from funnel_fittings import build_pipe_clamp  # noqa: E402

build_pipe_clamp("pipe_clamp_90", 1.0)
