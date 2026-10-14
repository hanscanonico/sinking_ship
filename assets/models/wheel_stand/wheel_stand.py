"""Builds assets/models/wheel_stand/wheel_stand.blend: what stands against a
wheelhouse's forward wall (RoomDressing._wheel_wall) — the steering wheel on its
pedestal, the binnacle to port of it with its quadrantal spheres, and the engine-order
telegraph to starboard — in Godot's axes, metres: x along the wall (Wall.right), y up,
z out from the wall's face into the room, its origin on the floor at the wall's face
under the wheel's hub. Nothing stands further out than RoomDressing.WHEEL_STAND's
depth, a wall fitting's.

    make model-sources MODEL=wheel_stand
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/wheel_stand/wheel_stand.py -- \
        assets/models/wheel_stand/wheel_stand.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, cap, fresh_scene, lathe, save, sphere, torus, triangles, tube  # noqa: E402

# The wheel: its hub over the floor and out from the wall, its rim's radius and
# thickness, and how far its handles reach from the hub.
HUB = [0.0, 1.0, 0.085]
WHEEL = 0.32
THICK = 0.022
REACH = 0.41
SPOKES = 8
# The binnacle and the telegraph, along the wall from the wheel.
BINNACLE = -0.51
TELEGRAPH = 0.5
# The binnacle's spheres: either side of it, this high, this big.
SPHERE_OUT = 0.13
SPHERE_HEIGHT = 1.26
SPHERE = 0.05
# The telegraph's dial: its middle's height and its radius.
DIAL_HEIGHT = 1.2
DIAL = 0.18

UP = ([1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0])
OUT = ([1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0])
BACK = (2, -1)


def pedestal(frame, brass):
    """The steering pedestal: a plinth, a panelled shaft, a brass band and a head, and
    the brass bearing the wheel's spindle comes out of."""
    box(frame, [-0.15, 0.0, 0.0], [0.15, 0.07, 0.095], skip=(BACK, (1, -1)))
    box(frame, [-0.11, 0.07, 0.0], [0.11, 0.8, 0.07], skip=(BACK, (1, -1), (1, 1)))
    box(brass, [-0.125, 0.8, 0.0], [0.125, 0.85, 0.078], skip=(BACK,))
    box(frame, [-0.12, 0.85, 0.0], [0.12, 0.93, 0.075], skip=(BACK, (1, -1)))
    box(brass, [-0.03, 0.93, 0.0], [0.03, 0.975, 0.05], inked=False, skip=(BACK, (1, -1)))
    middle = [HUB[0], HUB[1], 0.0]
    tube(brass, middle, [HUB[0], HUB[1], HUB[2] - THICK], [(0.04, 0.0, 0.0), (0.04, 1.0, 0.0)], 10)


def wheel(teak, brass):
    """The wheel: a rim of teak, its spokes running out through it into turned handles,
    and a brass boss over the hub."""
    middle = [HUB[0], HUB[1], HUB[2] - THICK * 0.5]
    torus(teak, middle, OUT, WHEEL - THICK * 0.5, (THICK, THICK * 0.55), 20, 5)
    # Share of the way from the boss to a handle's tip: radius.
    start = 0.03
    # Straight through the rim, swelling into the handle past it.
    stations = [(start, 0.011), (WHEEL + 0.025, 0.011), (0.372, 0.016), (REACH, 0.008)]
    for k in range(SPOKES):
        a = 2.0 * math.pi * k / SPOKES
        d = [math.cos(a), math.sin(a), 0.0]
        root = [middle[i] + d[i] * start for i in range(3)]
        tip = [middle[i] + d[i] * REACH for i in range(3)]
        profile = [(r, (s - start) / (REACH - start), 0.0) for s, r in stations]
        tube(teak, root, tip, profile, 5)
    face = [HUB[0], HUB[1], HUB[2] - THICK]
    tube(brass, face, [HUB[0], HUB[1], HUB[2] + 0.013], [(0.05, 0.0, 0.0), (0.05, 0.6, 1.0), (0.032, 1.0, 0.0)], 10)


def binnacle(teak, brass, dark):
    """The binnacle: a turned teak pillar under a brass bowl and hood, its lamp's
    chimney on top, and the two soft-iron spheres either side on brass brackets."""
    centre = [BINNACLE, 0.0, 0.0]
    lathe(
        teak,
        centre,
        UP,
        [
            (0.1, 0.0, 1.0),
            (0.1, 0.02, 0.0),
            (0.1, 0.06, 1.0),
            (0.08, 0.08, 0.0),
            (0.064, 0.15, 0.0),
            (0.066, 0.8, 0.0),
            (0.09, 0.96, 0.0),
            (0.092, 1.0, 1.0),
        ],
        8,
        half=True,
    )
    rows = lathe(
        brass,
        centre,
        UP,
        [
            (0.096, 0.995, 1.0),
            (0.098, 1.015, 0.0),
            (0.098, 1.13, 0.0),
            (0.1, 1.15, 1.0),
            (0.092, 1.165, 0.0),
            (0.08, 1.215, 0.0),
            (0.045, 1.255, 0.0),
            (0.022, 1.27, 0.0),
            (0.022, 1.33, 0.0),
            (0.042, 1.342, 1.0),
            (0.02, 1.36, 0.0),
        ],
        8,
        half=True,
    )
    cap(brass, rows[-1], [BINNACLE, 1.36, 0.0], [0.0, 1.0, 0.0], 0.0, closed=False)
    for side in (-1.0, 1.0):
        at = [BINNACLE + side * SPHERE_OUT, SPHERE_HEIGHT, SPHERE]
        sphere(dark, at, SPHERE, 8, 6)
        inner = BINNACLE + side * 0.07
        outer = BINNACLE + side * (SPHERE_OUT + 0.01)
        low, high = min(inner, outer), max(inner, outer)
        box(brass, [low, SPHERE_HEIGHT - SPHERE - 0.014, 0.015], [high, SPHERE_HEIGHT - SPHERE, 0.075], inked=False)


def telegraph(brass, enamel, upholstery, machine):
    """The engine-order telegraph: a brass pillar under a drum-headed dial, its face
    marked with the orders and the STOP sector in red, its lever over it."""
    lathe(
        brass,
        [TELEGRAPH, 0.0, 0.0],
        UP,
        [
            (0.085, 0.0, 1.0),
            (0.085, 0.02, 0.0),
            (0.085, 0.04, 1.0),
            (0.055, 0.07, 0.0),
            (0.042, 0.15, 0.0),
            (0.045, 0.9, 0.0),
            (0.06, DIAL_HEIGHT - DIAL + 0.04, 0.0),
        ],
        6,
        half=True,
    )
    centre = [TELEGRAPH, DIAL_HEIGHT, 0.0]
    face = 0.066
    rows = lathe(
        brass,
        centre,
        OUT,
        [
            (DIAL - 0.015, 0.0, 0.0),
            (DIAL, 0.03, 0.0),
            (DIAL, 0.055, 1.0),
            (DIAL - 0.01, 0.07, 0.0),
            (DIAL - 0.03, face, 1.0),
        ],
        12,
    )
    cap(enamel, rows[-1], [TELEGRAPH, DIAL_HEIGHT, face], [0.0, 0.0, 1.0], 0.0)
    # The STOP sector at the top, and the orders' ticks round the upper half.
    front = face + 0.002
    sector = []
    for k in range(4):
        a = math.radians(70.0 + 40.0 * k / 3)
        sector.append((math.cos(a), math.sin(a)))
    for (ca, sa), (cb, sb) in zip(sector, sector[1:]):
        quad = [[TELEGRAPH + c * r, DIAL_HEIGHT + s * r, front] for c, s, r in ((ca, sa, 0.07), (cb, sb, 0.07), (cb, sb, 0.13), (ca, sa, 0.13))]
        upholstery.face([upholstery.point(p) for p in quad], [0.0] * 4, [0.0, 0.0, 1.0])
    for k in range(7):
        a = math.radians(-10.0 + 200.0 * k / 6)
        c, s = math.cos(a), math.sin(a)
        n = [-s * 0.004, c * 0.004]
        quad = [
            [TELEGRAPH + c * r + n[0] * side, DIAL_HEIGHT + s * r + n[1] * side, front]
            for r, side in ((0.115, -1.0), (0.115, 1.0), (0.142, 1.0), (0.142, -1.0))
        ]
        machine.face([machine.point(p) for p in quad], [0.0] * 4, [0.0, 0.0, 1.0])
    # The lever: a boss on the dial's middle, an arm up to starboard, a grip on its end.
    tube(brass, [TELEGRAPH, DIAL_HEIGHT, face], [TELEGRAPH, DIAL_HEIGHT, face + 0.018], [(0.024, 0.0, 0.0), (0.024, 1.0, 0.0)], 8)
    arm = [TELEGRAPH, DIAL_HEIGHT, face + 0.012]
    lean = math.radians(48.0)
    tip = [TELEGRAPH + math.cos(lean) * 0.165, DIAL_HEIGHT + math.sin(lean) * 0.165, face + 0.012]
    tube(brass, arm, tip, [(0.011, 0.0, 0.0), (0.008, 1.0, 0.0)], 5)
    tube(brass, [tip[0], tip[1], face + 0.004], [tip[0], tip[1], 0.1], [(0.013, 0.0, 0.0), (0.017, 0.55, 0.0), (0.013, 1.0, 0.0)], 6)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    parts = {paint: Part(paint, paint) for paint in ("frame", "teak", "brass", "dark", "enamel", "upholstery", "machine")}
    pedestal(parts["frame"], parts["brass"])
    wheel(parts["teak"], parts["brass"])
    binnacle(parts["teak"], parts["brass"], parts["dark"])
    telegraph(parts["brass"], parts["enamel"], parts["upholstery"], parts["machine"])
    for part in parts.values():
        part.build(collection)
    print("wheel_stand: %d triangles" % triangles(collection))
    save(out)


main()
