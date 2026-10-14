"""Builds assets/models/chandelier/chandelier.blend: a liner's gilt electrolier, in
Godot's axes, metres, its hub at the origin, where the pendant's globe hangs
(LinerPublic._chandelier). A gilt collar over the globe and a gilt bowl under it;
eight scrolled arms sagging out of the bowl to a corona LinerPublic's CHANDELIER
round, and rods down to it from the collar; a tulip shade of sconce glass on a cup at
each arm's end and crystal drops hung round the corona. Nothing of it stands more
than CHANDELIER_RISE over the hub, where the rod from the ceiling meets its collar,
or CHANDELIER_DEPTH under it.

    make model-sources MODEL=chandelier
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/chandelier/chandelier.py -- assets/models/chandelier/chandelier.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, save, triangles  # noqa: E402
from model_shapes import lathe, sweep  # noqa: E402

# LinerPublic.CHANDELIER: the corona's outer radius.
RADIUS = 0.4
ARMS = 8
UP = (0.0, 1.0, 0.0)
# The corona: its inner and outer radii, its underside and its top.
CORONA_IN = 0.355
CORONA_LOW = -0.045
CORONA_TOP = -0.015
# Where each arm ends, its cup and shade over the corona.
REACH = 0.375


def bezier(p0, p1, p2, p3, t):
    s = 1.0 - t
    return [
        s * s * s * a + 3 * s * s * t * b + 3 * s * t * t * c + t * t * t * d
        for a, b, c, d in zip(p0, p1, p2, p3)
    ]


def gilt(collection):
    part = Part("gilt", "gilt")
    # The collar over the globe, where the ceiling's rod comes down into it.
    lathe(
        part,
        (0.0, 0.0, 0.0),
        UP,
        [
            (0.0, 0.078, 0.0),
            (0.036, 0.078, 1.0),
            (0.044, 0.094, 0.0),
            (0.036, 0.108, 1.0),
            (0.016, 0.114, 1.0),
            (0.0, 0.114, 0.0),
        ],
        8,
        math.pi / 8,
    )
    # The corona, inked round its outer edges.
    lathe(
        part,
        (0.0, 0.0, 0.0),
        UP,
        [
            (CORONA_IN, CORONA_LOW, 1.0),
            (0.3775, CORONA_LOW, 0.0),
            (RADIUS, CORONA_LOW, 1.0),
            (RADIUS, (CORONA_LOW + CORONA_TOP) * 0.5, 0.0),
            (RADIUS, CORONA_TOP, 1.0),
            (CORONA_IN, CORONA_TOP, 1.0),
            (CORONA_IN, CORONA_LOW, 1.0),
        ],
        16,
    )
    # The bowl under the globe, its finial the lowest point of the chandelier.
    lathe(
        part,
        (0.0, 0.0, 0.0),
        UP,
        [(0.0, -0.146, 0.0), (0.03, -0.125, 0.0), (0.085, -0.1, 1.0), (0.0, -0.094, 0.0)],
        8,
        math.pi / 8,
    )
    for arm in range(ARMS):
        turn = 2.0 * math.pi * (arm + 0.5) / ARMS
        out = (math.cos(turn), 0.0, math.sin(turn))

        def at(r, y):
            return [out[0] * r, y, out[2] * r]

        # A scroll out of the bowl, sagging under the corona and up into it.
        path = [
            at(*bezier((0.06, -0.104), (0.2, -0.165), (0.31, -0.1), (REACH, CORONA_TOP), t))
            for t in (0.0, 0.25, 0.5, 0.75, 1.0)
        ]
        sweep(part, path, 0.009, 4, caps=False)
        # Every other arm, a rod from the collar down to the corona's inner edge.
        if arm % 2 == 0:
            sweep(part, [at(0.03, 0.09), at(CORONA_IN + 0.004, CORONA_TOP)], 0.006, 3, caps=False)
        # The cup the shade stands in, on the corona.
        lathe(
            part,
            at(REACH, CORONA_TOP),
            UP,
            [(0.0, -0.004, 0.0), (0.032, 0.012, 1.0), (0.0, 0.012, 0.0)],
            6,
        )
    return part.build(collection, sharp_angle=70.0)


def shades(collection):
    part = Part("shades", "sconce_glass")
    for arm in range(ARMS):
        turn = 2.0 * math.pi * (arm + 0.5) / ARMS
        centre = (math.cos(turn) * REACH, CORONA_TOP, math.sin(turn) * REACH)
        lathe(
            part,
            centre,
            UP,
            [(0.0, 0.012, 0.0), (0.03, 0.045, 0.0), (0.034, 0.088, 1.0), (0.0, 0.082, 0.0)],
            6,
        )
    return part.build(collection, sharp_angle=70.0)


def drops(collection):
    part = Part("drops", "crystal")
    for drop in range(ARMS * 2):
        turn = 2.0 * math.pi * drop / (ARMS * 2)
        r = 0.378 if drop % 2 == 0 else 0.37
        long = 0.09 if drop % 2 == 0 else 0.07
        centre = (math.cos(turn) * r, CORONA_LOW, math.sin(turn) * r)
        lathe(
            part,
            centre,
            UP,
            [(0.0, -long, 0.0), (0.014, -long * 0.42, 0.0), (0.0, 0.0, 0.0)],
            4,
            turn,
        )
    return part.build(collection, sharp_angle=30.0)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    gilt(collection)
    shades(collection)
    drops(collection)
    print("chandelier: %d triangles" % triangles(collection))
    save(out)


main()
