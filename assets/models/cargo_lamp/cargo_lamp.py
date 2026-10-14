"""Builds assets/models/cargo_lamp/cargo_lamp.blend: a hold's cargo lamp of 1912 (ShipLamp,
CargoHold), in Godot's axes, metres: its origin where it hangs from the deckhead, the
pivot it swings round, y up. A brass ball swivel and cord down to a tin reflector shade,
ShipLamp.CARGO_SHADE round at its rolled rim, with a brass lampholder under it; a heavy
glass globe screwed into the holder, its middle ShipLamp.CARGO_CORD under the deckhead
and ShipLamp.GLOBE_RADIUS round, where the lamp's light burns; and a brass wire guard
round the globe, a hoop at its middle and two bows crossed under it. The glass is
painted sconce_glass, the tin steel and the brass brass: ShipLamp swaps each for the
lamp's own glass, tin and brass, so the globe glows as its lamp burns.

    make model-sources MODEL=cargo_lamp
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/cargo_lamp/cargo_lamp.py -- assets/models/cargo_lamp/cargo_lamp.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, axes_along, fresh_scene, lathe, save, sweep, triangles  # noqa: E402

# ShipLamp.CARGO_CORD, GLOBE_RADIUS and CARGO_SHADE: the globe's middle under the
# deckhead, its radius, and the shade's rim's radius.
CORD = 0.5
GLOBE = 0.09
SHADE = 0.2
UP = (0.0, 1.0, 0.0)
BALL = 0.016
# The shade's crown and its rim; the holder under the crown, which the globe's neck
# goes into.
CROWN = -0.39
RIM = -0.525
HOLDER = (0.024, -0.398, -0.428)
NECK = -0.42
# The guard: its hoop round the globe's middle, its wire, and the foot of its bows.
HOOP = 0.104
WIRE = 0.0045
FOOT = -0.6


def brass(collection):
    part = Part("brass", "brass")
    lathe(part, (0.0, 0.0, 0.0), axes_along(UP), [(0.0, -BALL, 0.0), (BALL, 0.0, 0.0), (0.0, BALL, 0.0)], 6, wound=True)
    sweep(part, [(0.0, -BALL * 0.8, 0.0), (0.0, CROWN - 0.004, 0.0)], 0.008, 4, caps=False)
    radius, top, low = HOLDER
    lathe(part, (0.0, 0.0, 0.0), axes_along(UP), [(radius, low, 1.0), (radius, top, 0.0)], 6, phase=math.pi / 6)
    # The hoop round the globe's middle.
    sides = 8
    hoop = []
    for k in range(sides + 1):
        a = 2.0 * math.pi * (k % sides) / sides
        hoop.append((HOOP * math.cos(a), -CORD, HOOP * math.sin(a)))
    sweep(part, hoop, WIRE, 3, caps=False)
    # Two bows from the shade's rim down through the hoop, crossed under the globe.
    for turn in (math.pi / 4, 3.0 * math.pi / 4):
        out = (math.cos(turn), math.sin(turn))
        bow = []
        for r, y in ((0.13, -0.47), (HOOP, -CORD), (0.072, -0.565), (0.0, FOOT)):
            bow.append((out[0] * r, y, out[1] * r))
        bow += [(-x, y, -z) for x, y, z in reversed(bow[:-1])]
        sweep(part, bow, WIRE, 3, caps=False)
    return part.build(collection, sharp_angle=50.0)


def tin(collection):
    part = Part("tin", "steel")
    # A conical reflector, its crown closed over the holder and its rim rolled, inked.
    lathe(
        part,
        (0.0, 0.0, 0.0),
        axes_along(UP),
        [(SHADE, RIM, 1.0), (0.188, RIM + 0.012, 0.0), (0.06, -0.41, 0.0), (0.04, CROWN - 0.004, 1.0), (0.0, CROWN, 0.0)],
        10,
        wound=True,
    )
    return part.build(collection, sharp_angle=40.0)


def globe(collection):
    part = Part("globe", "sconce_glass")
    # A heavy globe, its neck in the holder, closed at its foot.
    lathe(
        part,
        (0.0, 0.0, 0.0),
        axes_along(UP),
        [
            (0.0, -CORD - GLOBE, 0.0),
            (0.064, -CORD - 0.066, 0.0),
            (GLOBE, -CORD, 0.0),
            (0.066, -CORD + 0.06, 0.0),
            (0.022, NECK, 0.0),
        ],
        10,
        wound=True,
    )
    return part.build(collection, sharp_angle=70.0)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    brass(collection)
    tin(collection)
    globe(collection)
    print("cargo_lamp: %d triangles" % triangles(collection))
    save(out)


main()
