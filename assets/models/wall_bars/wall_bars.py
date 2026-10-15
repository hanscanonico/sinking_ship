"""Builds assets/models/wall_bars/wall_bars.blend: one bay of the gymnasium's wall
bars (LinerService._wall_bars), in Godot's axes, metres: x along the wall, y up, z
out of it into the room, its origin on the floor at the wall's face under the bay's
middle. Two teak uprights LinerService.BAR_BAY apart over all, standing off the wall
on their back, and round ash rungs between them every 0.15 m, up to its top,
LinerService.WALL_BARS's; nothing stands further out than BARS.

    make model-sources MODEL=wall_bars
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/wall_bars/wall_bars.py -- assets/models/wall_bars/wall_bars.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, save, sweep, triangles  # noqa: E402

# The bay's width, its top, and how far out it stands (LinerService.BAR_BAY,
# WALL_BARS and BARS); the uprights' side, and how far off the wall they stand.
BAY = 0.6
TOP = 2.28
BARS = 0.08
UPRIGHT = 0.05
OFF = 0.01
# The rungs: how far apart, the first's height, their radius and how far out their
# axis stands.
RUNG = 0.15
RUNG_RADIUS = 0.016
RUNG_OUT = 0.045
SIDES = 6


def uprights(teak):
    """The two uprights, from the floor to the top."""
    half = BAY * 0.5
    for x in (-half, half - UPRIGHT):
        box(teak, [x, 0.0, OFF], [x + UPRIGHT, TOP, BARS], skip=((1, -1),))


def rungs(ash):
    """A rung every RUNG from RUNG up, while it stands under the top's cap."""
    end = BAY * 0.5 - UPRIGHT
    height = RUNG
    while height < TOP - 0.05:
        middle = height + 0.015
        sweep(ash, [[-end, middle, RUNG_OUT], [end, middle, RUNG_OUT]], RUNG_RADIUS, SIDES, caps=False)
        height += RUNG


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    teak = Part("teak", "teak")
    ash = Part("ash", "mast")
    uprights(teak)
    rungs(ash)
    for part in (teak, ash):
        part.build(collection)
    print("wall_bars: %d triangles" % triangles(collection))
    save(out)


main()
