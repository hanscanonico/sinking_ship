"""Builds assets/models/iceberg_drydock/iceberg_drydock.blend: a drydock berg, two
towers of ice over a low saddle the sea has worn between them, on a mass under the
sea wider than over it; modelled to IcebergPlanner's measure as tools/berg_kit.py
says.

    make model-sources MODEL=iceberg_drydock
"""

import os
import random
import sys

# The shared kits, tools/model_kit.py and tools/berg_kit.py, from the repo root.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from berg_kit import Loft, foot_point, footprint, main, ring, under_rings  # noqa: E402

NAME = "iceberg_drydock"
SPREAD = 0.74
SEED = 1415
CORNERS = [
    (1.0, 0.1),
    (0.7, 0.55),
    (0.05, 0.5),
    (-0.6, 0.6),
    (-1.0, 0.15),
    (-0.85, -0.5),
    (-0.15, -0.62),
    (0.6, -0.55),
]
TOWER = [(0.5, 0.0), (0.3, 0.42), (-0.25, 0.45), (-0.5, 0.05), (-0.35, -0.45), (0.2, -0.5)]


def lofts():
    rng = random.Random(SEED)
    outline = footprint(CORNERS, rng)
    rings = under_rings(outline, rng)
    rings += [
        ring(outline, 0.45, 0.9, rng, jitter=0.02, rise=0.08),
        ring(outline, 1.0, 0.96, rng, jitter=0.02, rise=0.1),
        ring(outline, 2.6, 0.93, rng, jitter=0.03, rise=0.25),
        ring(outline, 3.8, 0.88, rng, jitter=0.04, rise=0.2),
    ]
    base = Loft(rings, foot=foot_point(), inner=0.65, lift=0.35)
    # The taller tower aft and away from her, the lower one fore.
    tall = footprint(TOWER, rng)
    at = (-0.5, -0.12)
    tall_rings = [
        ring(tall, 3.0, 1.0, rng, at, 0.04),
        ring(tall, 5.5, 1.0, rng, at, 0.04, 0.3),
        ring(tall, 7.4, 0.95, rng, at, 0.04, 0.2),
        ring(tall, 7.7, 0.78, rng, at, 0.05, 0.1),
        ring(tall, 9.3, 0.7, rng, at, 0.05, 0.2),
    ]
    low = footprint(TOWER[::-1], rng)
    low = [(-x, z) for x, z in low]
    at = (0.52, 0.0)
    low_rings = [
        ring(low, 3.0, 0.85, rng, at, 0.04),
        ring(low, 5.4, 0.83, rng, at, 0.04, 0.3),
        ring(low, 6.9, 0.72, rng, at, 0.05, 0.15),
    ]
    return [base, Loft(tall_rings, inner=0.5, lift=0.5), Loft(low_rings, inner=0.5, lift=0.4)]


main(NAME, lofts(), SPREAD, SEED, sys.argv[sys.argv.index("--") + 1])
