"""Builds assets/models/furnace_fire/furnace_fire.blend: the fire in an open furnace's
mouth (ShipLamp, EngineRoom), in Godot's axes, metres: its origin on the bulkhead's face
at the mouth's middle, y up, z out of the face into the room. A heap of glowing coals
filling the mouth, ShipLamp.MOUTH across and up, from its foot to a ragged crown under
the mouth's top, standing ShipLamp.MOUTH_PROUD out, behind the boiler front's grate
bars (tools/boiler_front.py); the firebox's dark crown shows over it. Painted
sconce_glass, which ShipLamp swaps for the fire's own glowing material.

    make model-sources MODEL=furnace_fire
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/furnace_fire/furnace_fire.py -- \\
        assets/models/furnace_fire/furnace_fire.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, save, triangles  # noqa: E402

# ShipLamp.MOUTH, halved, and MOUTH_PROUD.
MOUTH = (0.21, 0.13)
PROUD = 0.045
# The crown's height over the mouth's middle at each of its points, left to right,
# as a share of the mouth's half height: the coals heaped high in the middle.
CROWN = [0.35, 0.75, 0.5, 0.9, 1.0, 0.7, 0.95, 0.55, 0.3]
# The coals bulge toward the bars over their middle, no further than this.
BULGE = 0.003


def coals(collection):
    part = Part("coals", "sconce_glass")
    low = []
    high = []
    for index, share in enumerate(CROWN):
        x = -MOUTH[0] + 2.0 * MOUTH[0] * index / (len(CROWN) - 1)
        low.append(part.point((x, -MOUTH[1], PROUD)))
        y = MOUTH[1] * share
        middle = (-MOUTH[1] + y) * 0.5
        high.append(part.point((x, y, PROUD)))
        low.append(part.point((x, middle, PROUD + BULGE)))
    feet = low[0::2]
    waists = low[1::2]
    for k in range(len(CROWN) - 1):
        n = k + 1
        part.face([feet[k], feet[n], waists[n], waists[k]], [0.0] * 4, (0.0, 0.0, 1.0))
        part.face([waists[k], waists[n], high[n], high[k]], [0.0] * 4, (0.0, 0.0, 1.0))
    return part.build(collection, sharp_angle=80.0)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    coals(collection)
    print("furnace_fire: %d triangles" % triangles(collection))
    save(out)


main()
