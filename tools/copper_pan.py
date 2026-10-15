"""A copper pan hung on the galley's rack (LinerService._pan_rack), for the
copper_pan_NNN build scripts (assets/models/copper_pan_NNN/copper_pan_NNN.py): one
size each, its radius NNN thousandths of a metre, never one model scaled. A copper
pan hung by its iron handle from an iron hook under the rack's bar, its base toward
the room, its rolled rim to the wall.

In Godot's axes, metres: x along the wall, y up, z out of it into the room, the
origin on the bar's axis at its underside, where the hook hangs from. The pan's rim's
top hangs LinerService.PAN_HANDLE under it, the pan its radius round, so its foot
hangs PAN_HANDLE and two radii under the bar.
"""

import sys

from model_kit import Part, box, fresh_scene, lathe, save, sweep, triangles

# How far under the bar the rim's top hangs (LinerService.PAN_HANDLE).
HANDLE = 0.07
# Its depth: a base and a share of the radius; its base's share of the radius.
DEPTH = (0.02, 0.25)
BASE = 0.88
# The handle's half width and half thickness; the hook's radius.
GRIP = (0.011, 0.004)
HOOK = 0.0035


def pan(copper, radius, sides):
    """The pan, turned round z: its base toward the room, round its side to the
    rolled rim at its back, its open mouth to the wall."""
    depth = DEPTH[0] + DEPTH[1] * radius
    base = radius * BASE
    centre = [0.0, -(HANDLE + radius), depth * 0.5]
    lathe(
        copper,
        centre,
        ([1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, -1.0]),
        [
            (0.0, 0.0, 0.0),
            (base - 0.015, 0.0, 0.0),
            (base, 0.0, 1.0),
            (base + 0.003, 0.012, 0.0),
            (radius - 0.003, depth - 0.012, 0.0),
            (radius, depth, 1.0),
            (radius * 0.94, depth, 1.0),
        ],
        sides,
        wound=True,
    )


def handle(iron, radius):
    """The iron handle up from the pan's rim to its hook, and the hook to the bar."""
    low = -HANDLE - 0.012
    box(iron, [-GRIP[0], low, -GRIP[1]], [GRIP[0], -0.012, GRIP[1]], inked=False, skip=((1, -1),))
    sweep(iron, [[0.0, 0.0, 0.0], [0.0, -0.016, 0.0]], HOOK, 4, caps=False)


def build(name, radius, sides):
    """Writes the .blend named on the command line: a pan of [radius], turned in
    [sides]."""
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    copper = Part("copper", "copper")
    iron = Part("iron", "dark")
    pan(copper, radius, sides)
    handle(iron, radius)
    for part in (copper, iron):
        part.build(collection)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)
