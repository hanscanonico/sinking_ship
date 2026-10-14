"""Builds assets/models/iceberg_tabular/iceberg_tabular.blend: the widest of the
match's bergs, a flat-topped block of ice with sheer, wave-cut cliffs, a ledge a
little over half way up, and its mass under the sea wider than over it; modelled to
IcebergPlanner's measure as tools/berg_kit.py says.

    make model-sources MODEL=iceberg_tabular
"""

import os
import random
import sys

# The shared kits, tools/model_kit.py and tools/berg_kit.py, from the repo root.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from berg_kit import Loft, foot_point, footprint, main, ring, under_rings  # noqa: E402

NAME = "iceberg_tabular"
SPREAD = 0.82
SEED = 1912
CORNERS = [
    (1.0, 0.18),
    (0.82, 0.56),
    (0.28, 0.62),
    (-0.42, 0.57),
    (-0.96, 0.38),
    (-1.0, -0.22),
    (-0.58, -0.62),
    (0.12, -0.7),
    (0.74, -0.52),
]


def lofts():
    rng = random.Random(SEED)
    outline = footprint(CORNERS, rng)
    rings = under_rings(outline, rng)
    rings += [
        # A notch the waves cut, the lip over it, and the cliff up to a ledge.
        ring(outline, 0.45, 0.9, rng, jitter=0.02, rise=0.08),
        ring(outline, 1.0, 0.97, rng, jitter=0.02, rise=0.1),
        ring(outline, 3.2, 0.95, rng, jitter=0.03, rise=0.3),
        ring(outline, 5.6, 0.93, rng, jitter=0.03, rise=0.2),
        # The upper tier stands back from her and aft, leaving a broad ledge.
        ring(outline, 5.9, 0.8, rng, (-0.1, -0.12), jitter=0.04, rise=0.1),
        ring(outline, 7.8, 0.77, rng, (-0.1, -0.13), jitter=0.03, rise=0.3),
        ring(outline, 9.4, 0.73, rng, (-0.11, -0.14), jitter=0.03, rise=0.15),
    ]
    return [Loft(rings, foot=foot_point(), inner=0.6, lift=0.4)]


main(NAME, lofts(), SPREAD, SEED, sys.argv[sys.argv.index("--") + 1])
