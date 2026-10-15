"""Builds assets/models/bath_lantern/bath_lantern.blend: a Moorish brass lantern
round a pendant's globe in the Turkish bath (LinerBath._lantern), in Godot's axes,
metres: y up, its origin where the pendant hangs under the ceiling, nothing over it.
An eight-sided canopy under a ceiling rose, four ogee ribs out and down from it to a
pierced band round the globe, crenellated in pointed merlons, LinerBath.LANTERN
round, its foot LinerBath.LANTERN_DROP under the globe's middle (ShipLamp.CORD under
the origin), and four ribs in under it to a pendant drop. Its box is
LinerBath.LANTERN_BOX.

    make model-sources MODEL=bath_lantern
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/bath_lantern/bath_lantern.py -- \\
        assets/models/bath_lantern/bath_lantern.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, lathe, save, sweep, triangles  # noqa: E402

# The band's radius, its foot under the origin (ShipLamp.CORD + LinerBath.
# LANTERN_DROP) and its height; its merlons' height.
RADIUS = 0.2
FOOT = 0.4
BAND = 0.06
MERLON = 0.04
SIDES = 8
PHASE = math.pi / SIDES
UP = ([1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0])
# The canopy's rim: its radius and how far under the origin.
CANOPY = (0.11, 0.13)
# The ribs' section; the drop's foot under the origin.
RIB = 0.007
DROP = 0.62


def canopy(brass):
    """The ceiling rose, the stem and the canopy, turned: down from the rose round
    the canopy's dome to its rim, and in under it to the stem."""
    lathe(
        brass,
        [0.0, 0.0, 0.0],
        UP,
        [
            (0.0, -0.02, 0.0),
            (0.05, -0.02, 1.0),
            (0.05, 0.0, 1.0),
            (0.0, 0.0, 0.0),
        ],
        SIDES,
        phase=PHASE,
        wound=True,
    )
    lathe(
        brass,
        [0.0, -CANOPY[1], 0.0],
        UP,
        [
            (0.0, 0.0, 0.0),
            (CANOPY[0], 0.0, 1.0),
            (CANOPY[0] * 0.75, 0.035, 0.0),
            (0.03, 0.08, 0.0),
            (0.012, CANOPY[1] - 0.02, 0.0),
            (0.0, CANOPY[1] - 0.02, 0.0),
        ],
        SIDES,
        phase=PHASE,
        wound=True,
    )


def band(brass, dark):
    """The band round the globe, inked at its edges, its piercings dark, and the
    pointed merlons standing on its top edge."""
    foot = -FOOT
    rows = lathe(
        brass,
        [0.0, foot, 0.0],
        UP,
        [
            (RADIUS - 0.006, BAND, 1.0),
            (RADIUS - 0.006, 0.0, 1.0),
            (RADIUS, 0.0, 1.0),
            (RADIUS, 0.012, 0.0),
            (RADIUS, BAND - 0.012, 0.0),
            (RADIUS, BAND, 1.0),
            (RADIUS - 0.006, BAND, 1.0),
        ],
        SIDES,
        phase=PHASE,
    )
    top = rows[-2]
    for k in range(SIDES):
        a = top[k]
        b = top[(k + 1) % SIDES]
        middle = [(a[i] + b[i]) * 0.5 for i in range(3)]
        tip = [middle[0], foot + BAND + MERLON, middle[2]]
        outward = [middle[0], 0.0, middle[2]]
        brass.face([brass.point(p) for p in (a, b, tip)], [1.0, 1.0, 0.0], outward)
        brass.face([brass.point(p) for p in (b, a, tip)], [1.0, 1.0, 0.0], [-outward[0], 0.0, -outward[2]])
        # A pointed piercing in the middle of each face of the band.
        low = [(a[i] * 0.72 + b[i] * 0.28) for i in range(3)]
        high = [(a[i] * 0.28 + b[i] * 0.72) for i in range(3)]
        y0 = foot + 0.01
        y1 = foot + BAND - 0.026
        k_out = 1.002
        points = [
            [low[0] * k_out, y0, low[2] * k_out],
            [high[0] * k_out, y0, high[2] * k_out],
            [high[0] * k_out, y1, high[2] * k_out],
            [middle[0] * k_out, y1 + 0.018, middle[2] * k_out],
            [low[0] * k_out, y1, low[2] * k_out],
        ]
        dark.face([dark.point(p) for p in points], [0.0] * 5, outward)


def ribs(brass):
    """Four ogee ribs from the canopy's rim out and down to the band, and four in
    under the band to the drop."""
    for index in range(4):
        t = 2.0 * math.pi * (index + 0.5) / 4.0
        out = [math.cos(t), 0.0, math.sin(t)]

        def at(radius, height, out=out):
            return [out[0] * radius, height, out[2] * radius]

        upper = [at(CANOPY[0] - 0.01, -CANOPY[1]), at(0.17, -0.2), at(0.19, -0.3), at(RADIUS - 0.003, -FOOT + 0.01)]
        sweep(brass, upper, RIB, 3, caps=False)
        lower = [at(RADIUS - 0.003, -FOOT), at(0.12, -0.5), at(0.03, -DROP + 0.05)]
        sweep(brass, lower, RIB, 3, caps=False)


def drop(brass):
    """The pendant drop the lower ribs meet: a little onion and its point."""
    lathe(
        brass,
        [0.0, -DROP, 0.0],
        UP,
        [
            (0.0, 0.0, 0.0),
            (0.022, 0.03, 0.0),
            (0.03, 0.05, 1.0),
            (0.0, 0.065, 0.0),
        ],
        SIDES,
        phase=PHASE,
        wound=True,
    )


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    brass = Part("brass", "brass")
    dark = Part("piercing", "dark")
    canopy(brass)
    band(brass, dark)
    ribs(brass)
    drop(brass)
    for part in (brass, dark):
        part.build(collection)
    print("bath_lantern: %d triangles" % triangles(collection))
    save(out)


main()
