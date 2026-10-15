"""Builds assets/models/electrolier/electrolier.blend: the first-class dining saloon's
gilt electrolier round each of its pendants (LinerDining._chandelier), lighter than the
lounge's chandelier — a ceiling rose, three rods down from it to a gilt corona round
the pendant's globe, six tulip shades of sconce glass standing on the corona and a
crystal drop hung under it between each two — in Godot's axes, metres, its origin
where the pendant hangs from under the ceiling. Its corona is LinerDining.HOOP round,
its underside HOOP_DROP under the origin, at the globe's height; nothing of it rises
over the origin or hangs more than ELECTROLIER_DEPTH under it.

    make model-sources MODEL=electrolier
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/electrolier/electrolier.py -- assets/models/electrolier/electrolier.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, axes_along, fresh_scene, lathe, save, sweep, triangles  # noqa: E402

# LinerDining's HOOP, HOOP_DROP (ShipLamp.CORD and a little) and ELECTROLIER_DEPTH.
RADIUS = 0.42
LOW = -0.33
DEPTH = 0.4
# The corona: its inner radius and its top; where the shades stand round it, and the
# rods meet it.
INNER = 0.35
TOP = LOW + 0.03
MIDDLE = (RADIUS + INNER) * 0.5
SIDES = 12
SHADES = 6
# The rose under the ceiling and where the rods leave it.
ROSE = 0.14
ROD_FOOT = 0.11
UP = (0.0, 1.0, 0.0)


def gilt(collection):
    part = Part("gilt", "gilt")
    # The rose, a shallow dome under the ceiling.
    lathe(
        part,
        (0.0, 0.0, 0.0),
        axes_along(UP),
        [(ROSE, 0.0, 1.0), (0.1, -0.028, 0.0), (0.0, -0.036, 0.0)],
        6,
        phase=math.pi / 6,
        wound=True,
    )
    # The corona, inked round its underside's edges.
    lathe(
        part,
        (0.0, 0.0, 0.0),
        axes_along(UP),
        [
            (INNER, LOW, 1.0),
            (MIDDLE, LOW, 0.0),
            (RADIUS, LOW, 1.0),
            (RADIUS, TOP, 1.0),
            (INNER, TOP, 1.0),
            (INNER, LOW, 1.0),
        ],
        SIDES,
        wound=True,
    )
    # Three rods from the rose down to the corona's middle, between the shades.
    for rod in range(3):
        turn = 2.0 * math.pi * (rod * 2 + 1) / SHADES
        out = (math.cos(turn), 0.0, math.sin(turn))
        top = [out[0] * ROD_FOOT, -0.02, out[2] * ROD_FOOT]
        foot = [out[0] * MIDDLE, TOP, out[2] * MIDDLE]
        sweep(part, [top, foot], 0.007, 3, caps=False)
    return part.build(collection, sharp_angle=70.0)


def shades(collection):
    part = Part("shades", "sconce_glass")
    for shade in range(SHADES):
        turn = 2.0 * math.pi * shade / SHADES
        centre = (math.cos(turn) * MIDDLE, TOP, math.sin(turn) * MIDDLE)
        lathe(
            part,
            centre,
            axes_along(UP),
            [(0.0, 0.0, 0.0), (0.026, 0.04, 0.0), (0.04, 0.095, 1.0)],
            5,
            phase=turn,
            wound=True,
        )
    return part.build(collection, sharp_angle=70.0)


def drops(collection):
    part = Part("drops", "crystal")
    long = DEPTH + LOW
    for drop in range(SHADES):
        turn = 2.0 * math.pi * (drop + 0.5) / SHADES
        centre = (math.cos(turn) * MIDDLE, LOW, math.sin(turn) * MIDDLE)
        lathe(
            part,
            centre,
            axes_along(UP),
            [(0.0, -long, 0.0), (0.016, -long * 0.4, 0.0), (0.0, 0.0, 0.0)],
            3,
            phase=turn,
            wound=True,
        )
    return part.build(collection, sharp_angle=30.0)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    gilt(collection)
    shades(collection)
    drops(collection)
    print("electrolier: %d triangles" % triangles(collection))
    save(out)


main()
