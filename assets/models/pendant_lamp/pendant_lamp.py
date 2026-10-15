"""Builds assets/models/pendant_lamp/pendant_lamp.blend: a ship's electric pendant of
1912, a room's lamp (ShipLamp), in Godot's axes, metres: its origin where it hangs from
the ceiling, the pivot it swings round, y up. A brass ball swivel in the ceiling, so it
hangs plumb whatever she lists; a brass rod down to a brass gallery with a flared
skirt; an opal glass globe held in the gallery, its middle ShipLamp.CORD under the
ceiling and ShipLamp.GLOBE_RADIUS round, where the lamp's light burns. The glass is
painted sconce_glass and the brass brass: ShipLamp swaps each for the lamp's own glass
and brass, so the globe glows as its lamp burns.

    make model-sources MODEL=pendant_lamp
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/pendant_lamp/pendant_lamp.py -- \\
        assets/models/pendant_lamp/pendant_lamp.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, axes_along, fresh_scene, lathe, save, sweep, triangles  # noqa: E402

# ShipLamp.CORD and GLOBE_RADIUS: the globe's middle under the ceiling, its radius.
CORD = 0.3
GLOBE = 0.09
UP = (0.0, 1.0, 0.0)
# The swivel's ball, round the pivot; the rod; the gallery's top and its skirt's lip.
BALL = 0.016
ROD = 0.007
GALLERY_TOP = -0.186
NECK = -0.222


def brass(collection):
    part = Part("brass", "brass")
    # The ball swivel, half in the ceiling: the same whichever way the lamp swings.
    lathe(part, (0.0, 0.0, 0.0), axes_along(UP), [(0.0, -BALL, 0.0), (BALL, 0.0, 0.0), (0.0, BALL, 0.0)], 6, wound=True)
    sweep(part, [(0.0, -BALL * 0.8, 0.0), (0.0, GALLERY_TOP - 0.002, 0.0)], ROD, 4, caps=False)
    # The gallery: a collar flaring to a skirt round the globe's neck, its lip inked.
    lathe(
        part,
        (0.0, 0.0, 0.0),
        axes_along(UP),
        [(0.044, NECK - 0.004, 1.0), (0.052, NECK + 0.008, 1.0), (0.024, GALLERY_TOP - 0.004, 0.0), (0.0, GALLERY_TOP, 0.0)],
        8,
        phase=math.pi / 8,
        wound=True,
    )
    return part.build(collection, sharp_angle=50.0)


def globe(collection):
    part = Part("globe", "sconce_glass")
    # An opal globe, a little fuller over its middle than under it, closed at its foot.
    lathe(
        part,
        (0.0, 0.0, 0.0),
        axes_along(UP),
        [
            (0.0, -CORD - GLOBE, 0.0),
            (0.068, -CORD - 0.064, 0.0),
            (GLOBE, -CORD, 0.0),
            (0.078, -CORD + 0.046, 0.0),
            (0.042, NECK, 0.0),
        ],
        10,
        wound=True,
    )
    return part.build(collection, sharp_angle=70.0)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    brass(collection)
    globe(collection)
    print("pendant_lamp: %d triangles" % triangles(collection))
    save(out)


main()
