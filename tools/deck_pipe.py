"""A cast-iron pipe's mouth on the deck at the bow (ShipFittings._deck_pipe), for the
deck_pipe_NN build scripts (assets/models/deck_pipe_NN/deck_pipe_NN.py): one size
each, its flange's radius NN hundredths of a metre, never one model scaled — the
hawse pipe's mouth by the end railing and the spurling pipe the chain goes down to
its locker by. A flange bolted to the deck, a neck rising to a rounded lip, the dark
mouth inside it, and an eye on the neck its cover's chain is shackled to.

In Godot's axes, metres, the pipe's axis at the deck at the origin. Nothing of it
stands past its flange's radius or under the deck; its lip is under a toe rail's
height (ShipHull.TOE_RAIL_HEIGHT), lying flat where bodies walk.
"""

import math
import sys

from model_kit import Part, box, cap, fresh_scene, lathe, save, stud, torus, triangles

FLANGE = 0.018
# The lip's height: a base and a share of the radius.
RISE = (0.035, 0.17)
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])


def rise(radius):
    """How high its lip stands over the deck, for a flange of [radius]."""
    return RISE[0] + RISE[1] * radius


def pipe(iron, dark, radius, sides):
    """The flange, the neck, the lip and the bore, turned; the mouth's dark floor."""
    top = rise(radius)
    neck = radius * 0.74
    lip = radius * 0.84
    mouth = radius * 0.6
    rows = lathe(
        iron,
        (0.0, 0.0, 0.0),
        UP,
        [
            (radius, 0.0, 1.0),
            (radius, FLANGE, 1.0),
            (radius - 0.015, FLANGE, 0.0),
            (neck, FLANGE, 0.0),
            (neck, top - 0.022, 0.0),
            (lip, top - 0.01, 1.0),
            (lip, top, 1.0),
            (mouth, top, 1.0),
            (mouth, 0.012, 0.0),
        ],
        sides,
        wound=True,
    )
    cap(dark, rows[-1], [0.0, 0.012, 0.0], [0.0, 1.0, 0.0], 0.0)


def bolts(iron, radius, count):
    """The flange's bolt heads, between its rim and the neck."""
    middle = (radius - 0.015 + radius * 0.74) * 0.5
    for k in range(count):
        a = 2.0 * math.pi * (k + 0.5) / count
        centre = [middle * math.cos(a), FLANGE, middle * math.sin(a)]
        stud(iron, centre, [0.0, 1.0, 0.0], 0.011, 0.008)


def eye(iron, radius):
    """The eye on the neck, facing +x, its cover's chain shackled to it."""
    neck = radius * 0.74
    height = rise(radius) - 0.034
    box(iron, [neck - 0.004, height - 0.014, -0.005], [neck + 0.008, height + 0.014, 0.005], inked=False)
    axes = ([1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0])
    torus(iron, [neck + 0.017, height, 0.0], axes, 0.011, (0.0045, 0.0045), 6, 4)


def build(name, radius, sides, count):
    """Writes the .blend named on the command line: a pipe's mouth of [radius], turned
    in [sides] (a multiple of four, so its flange reaches its radius each way along x
    and z), its flange held by [count] bolts."""
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    iron = Part("iron", "steel")
    dark = Part("mouth", "dark")
    pipe(iron, dark, radius, sides)
    bolts(iron, radius, count)
    eye(iron, radius)
    iron.build(collection)
    dark.build(collection)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)
