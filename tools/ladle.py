"""A tinned ladle hung on the galley's rack (LinerService._pan_rack), for the
ladle_NN build scripts (assets/models/ladle_NN/ladle_NN.py): one length each, NN
hundredths of a metre from the bar to its bowl's foot, never one model scaled. Its
long handle hooked over at the top, its bowl's hollow toward the room.

In Godot's axes, metres: x along the wall, y up, z out of it into the room, the
origin on the bar's axis at its underside, where the hook hangs from; its bowl's
foot hangs its length under it.
"""

import math
import sys

from model_kit import Part, fresh_scene, lathe, save, sweep, triangles

# The bowl's radius and depth; the handle's section.
BOWL = 0.04
DEEP = 0.032
STEM = 0.005
AXES = ([1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, -1.0])


def bowl(tin, drop, sides):
    """The bowl, turned round z: from the middle of its back round to its lip, and in
    down its hollow, which faces the room."""
    centre = [0.0, -drop + BOWL, 0.012]
    lathe(
        tin,
        centre,
        AXES,
        [
            (0.0, DEEP, 0.0),
            (BOWL * 0.7, DEEP * 0.8, 0.0),
            (BOWL, 0.0, 1.0),
            (BOWL - 0.004, 0.0, 1.0),
            (BOWL * 0.65, DEEP * 0.6, 0.0),
            (0.0, DEEP * 0.75, 0.0),
        ],
        sides,
        # A corner of its rim straight down, at its foot.
        phase=(1.5 * math.pi) % (2.0 * math.pi / sides),
        wound=True,
    )
    return centre


def handle(tin, drop, centre):
    """The handle from the bowl's lip up to the hook it hangs by under the bar."""
    lip = centre[1] + BOWL - 0.004
    sweep(
        tin,
        [
            [0.0, lip, centre[2]],
            [0.0, lip + 0.03, centre[2] - 0.012],
            [0.0, -0.035, centre[2] - 0.012],
            [0.0, -0.012, -0.004],
            [0.0, 0.0, 0.0],
        ],
        STEM,
        4,
        caps=False,
    )


def build(name, drop, sides):
    """Writes the .blend named on the command line: a ladle hanging [drop] under its
    bar, its bowl turned in [sides]."""
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    tin = Part("tin", "tin")
    centre = bowl(tin, drop, sides)
    handle(tin, drop, centre)
    tin.build(collection)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)
