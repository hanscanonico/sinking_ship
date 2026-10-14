"""Builds assets/models/iceberg_wedge/iceberg_wedge.blend: the narrowest of the
match's bergs, a wedge of ice whose top slopes up away from her to a sheer cliff,
stepped by a ledge on the side toward her, on a mass under the sea wider than over
it; modelled to IcebergPlanner's measure as tools/berg_kit.py says.

    make model-sources MODEL=iceberg_wedge
"""

import os
import random
import sys

# The shared kits, tools/model_kit.py and tools/berg_kit.py, from the repo root.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from berg_kit import Loft, foot_point, footprint, main, ring, under_rings  # noqa: E402

NAME = "iceberg_wedge"
SPREAD = 0.63
SEED = 1514
CORNERS = [
    (1.0, 0.05),
    (0.62, 0.62),
    (-0.2, 0.7),
    (-0.9, 0.42),
    (-1.0, -0.25),
    (-0.45, -0.72),
    (0.4, -0.66),
]


def slope(rise):
    """Higher away from her (−z), by [rise] metres across its width."""
    return lambda x, z: -z * rise


def lofts():
    rng = random.Random(SEED)
    outline = footprint(CORNERS, rng)
    rings = under_rings(outline, rng)
    rings += [
        ring(outline, 0.45, 0.9, rng, jitter=0.02, rise=0.08),
        ring(outline, 1.0, 0.97, rng, jitter=0.02, rise=0.1),
        ring(outline, 3.0, 0.95, rng, jitter=0.03, rise=0.3, tilt=slope(0.6)),
        ring(outline, 4.4, 0.92, rng, jitter=0.03, rise=0.2, tilt=slope(1.2)),
        ring(outline, 4.7, 0.78, rng, (0.05, -0.12), 0.04, 0.1, tilt=slope(1.6)),
        ring(outline, 6.6, 0.72, rng, (0.06, -0.15), 0.04, 0.3, tilt=slope(2.6)),
        ring(outline, 7.6, 0.6, rng, (0.08, -0.2), 0.05, 0.2, tilt=slope(3.4)),
    ]
    return [Loft(rings, foot=foot_point(), inner=0.5, lift=0.6)]


main(NAME, lofts(), SPREAD, SEED, sys.argv[sys.argv.index("--") + 1])
