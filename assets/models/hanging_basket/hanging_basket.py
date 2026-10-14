"""Builds assets/models/hanging_basket/hanging_basket.blend: a wicker basket of green
hung from the verandah café's ceiling (LinerPublic._basket) — a brass rod down from
its hook, three chains spreading from the rod to the basket's rim, a woven bowl, a
mound of leaves over it and trails of ivy over its rim — in Godot's axes, metres, its
origin at the hook under the ceiling. The basket is LinerPublic.BASKET round, its rim
BASKET_DROP under the hook and BASKET_DEPTH over its foot; the leaves spread no
further than BASKET_SPREAD round and nothing of it hangs under the basket's foot.
Its wicker is painted rope and its leaves canvas, the placing code's to swap for the
café's own.

    make model-sources MODEL=hanging_basket
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/hanging_basket/hanging_basket.py -- \
        assets/models/hanging_basket/hanging_basket.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, lathe, save, sweep, triangles  # noqa: E402

# LinerPublic's BASKET, BASKET_DROP, BASKET_DEPTH and BASKET_SPREAD.
RADIUS = 0.18
DROP = 0.35
DEPTH = 0.16
SPREAD = 0.24
# Where the rod ends and the chains spread from.
RING = -0.2
SIDES = 8
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])


def hanger(brass):
    """The rod from the hook and the three chains to the rim."""
    sweep(brass, [[0.0, 0.0, 0.0], [0.0, RING, 0.0]], 0.008, 3, caps=False)
    for k in range(3):
        a = 2.0 * math.pi * k / 3.0
        rim = [RADIUS * 0.95 * math.cos(a), -DROP, RADIUS * 0.95 * math.sin(a)]
        sweep(brass, [[0.0, RING, 0.0], rim], 0.005, 3, caps=False)


def bowl(wicker):
    """The woven bowl, its rim rolled, its round foot."""
    profile = [(0.0, -DROP - DEPTH, 0.0), (0.1, -DROP - DEPTH + 0.012, 0.0), (0.165, -DROP - 0.07, 0.0), (RADIUS, -DROP, 1.0)]
    lathe(wicker, [0.0, 0.0, 0.0], UP, profile, SIDES, phase=math.pi / SIDES, wound=True)


def greenery(leaves):
    """A mound of leaves spilling over the rim, and three trails of ivy over it."""
    profile = [(RADIUS * 0.96, -DROP - 0.01, 0.0), (SPREAD, -DROP + 0.045, 0.0), (0.14, -DROP + 0.09, 0.0), (0.0, -DROP + 0.1, 0.0)]
    lathe(leaves, [0.0, 0.0, 0.0], UP, profile, SIDES, wound=True)
    for k in range(3):
        a = 2.0 * math.pi * (k + 0.5) / 3.0
        u = [math.cos(a), math.sin(a)]
        reach = [0.2, 0.22, 0.21]
        fall = [-DROP + 0.01, -DROP - 0.06, -DROP - 0.13 + 0.02 * (k % 2)]
        path = [[r * u[0], y, r * u[1]] for r, y in zip(reach, fall)]
        sweep(leaves, path, 0.016, 3, caps=False)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    brass = Part("brass", "brass")
    wicker = Part("wicker", "rope")
    leaves = Part("leaves", "canvas")
    hanger(brass)
    bowl(wicker)
    greenery(leaves)
    for part in (brass, wicker, leaves):
        part.build(collection)
    print("hanging_basket: %d triangles" % triangles(collection))
    save(out)


main()
