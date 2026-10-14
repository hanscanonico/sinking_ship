"""Builds assets/models/washstand/washstand.blend: a cabin's washstand flat on its wall
(CabinDressing.washstand) — a varnished cabinet of two doors hung off the wall under
a marble top and its splashback, a basin and a jug on it, a towel over a brass rail
beside it and a mirror over it — in Godot's axes, metres: x along the wall
(Wall.right), y up, z out from the wall's face into the room, its origin on the floor
at the wall's face under the cabinet's middle. Nothing stands further out than
CabinDressing.WASHSTAND's depth, a wall fitting's.

    make model-sources MODEL=washstand
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/washstand/washstand.py -- assets/models/washstand/washstand.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, cap, fresh_scene, lathe, panel, save, slab, stud, sweep, triangles  # noqa: E402

# The cabinet: its half length, its depth off the wall, its underside and top.
HALF = 0.25
DEPTH = 0.08
LOW = 0.25
HIGH = 0.86
# The marble top over it, a little longer and deeper, and its splashback.
TOP = (0.28, 0.04, 0.1)
SPLASH = 0.12
# The mirror's middle's height and its frame's half size; the glass's.
MIRROR = 1.55
FRAME = (0.2, 0.25)
GLASS = (0.16, 0.21)
FRAME_DEPTH = 0.012
# The towel rail's height and its run along the wall left of the cabinet.
RAIL = 0.75
RAIL_FROM = -0.3
RAIL_TO = -0.5

BACK = (2, -1)
X = [1.0, 0.0, 0.0]
Y = [0.0, 1.0, 0.0]
Z = [0.0, 0.0, 1.0]


def cabinet(frame, teak, brass):
    """The cabinet, its two doors' raised panels and their brass knobs."""
    box(frame, [-HALF, LOW, 0.0], [HALF, HIGH, DEPTH], skip=(BACK,))
    middle = (LOW + HIGH) * 0.5
    for side in (-1.0, 1.0):
        panel(teak, [side * HALF * 0.5, middle, DEPTH + 0.003], X, Y, (HALF * 0.5 - 0.03, (HIGH - LOW) * 0.5 - 0.05))
        stud(brass, [side * 0.035, middle + 0.05, DEPTH + 0.003], Z, 0.012, 0.014, 5)


def top(enamel):
    """The marble top and the splashback along the wall behind it."""
    high = HIGH + TOP[1]
    box(enamel, [-TOP[0], HIGH, 0.0], [TOP[0], high, TOP[2]], skip=(BACK,))
    box(enamel, [-TOP[0], high, 0.0], [TOP[0], high + SPLASH, 0.014], inked=False, skip=(BACK, (1, -1)))


def basin_and_jug(enamel, dark):
    """A wash basin, oval to fit the top, and a jug standing beside it with its
    handle toward the basin."""
    high = HIGH + TOP[1]
    # Its axes: an oval 2.2 times as long along the wall as it is deep.
    oval = ([2.2, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0])
    centre = [-0.05, high, 0.052]
    rows = lathe(enamel, centre, oval, [(0.03, 0.0, 0.0), (0.045, 0.045, 0.0), (0.048, 0.05, 1.0)], 8)
    # The water inside, just under its lip.
    water = [[centre[0] + (p[0] - centre[0]) * 0.94, high + 0.046, centre[2] + (p[2] - centre[2]) * 0.94] for p in rows[-1]]
    cap(dark, water, [centre[0], high + 0.046, centre[2]], Y, 0.0)
    jug = [0.17, high, 0.05]
    profile = [(0.034, 0.0, 1.0), (0.045, 0.07, 0.0), (0.03, 0.16, 0.0), (0.04, 0.2, 1.0)]
    rings = lathe(enamel, jug, (X, [0.0, 0.0, -1.0], Y), profile, 6)
    cap(dark, rings[-1], [jug[0], jug[1] + 0.2, jug[2]], Y, 0.0)
    handle = [[0.135, high + 0.17, 0.05], [0.1, high + 0.12, 0.05], [0.13, high + 0.06, 0.05]]
    sweep(enamel, handle, 0.008, 4, caps=False)


def mirror(frame, glass):
    """The mirror in its frame over the basin."""
    box(frame, [-FRAME[0], MIRROR - FRAME[1], 0.0], [FRAME[0], MIRROR + FRAME[1], FRAME_DEPTH], inked=False, skip=(BACK, (2, 1)))
    panel(frame, [0.0, MIRROR, FRAME_DEPTH], X, Y, FRAME, 0.02)
    z = FRAME_DEPTH + 0.002
    slab(glass, [[-GLASS[0], MIRROR - GLASS[1], z], [GLASS[0], MIRROR - GLASS[1], z], [GLASS[0], MIRROR + GLASS[1], z], [-GLASS[0], MIRROR + GLASS[1], z]], Z)


def towel(brass, linen, stripe):
    """A brass rail out from the wall and along it, and a towel hung over it, its two
    halves either side of the rail and a coloured stripe across each near its hem."""
    out = 0.05
    sweep(brass, [[RAIL_FROM, RAIL, 0.0], [RAIL_FROM, RAIL, out], [RAIL_TO, RAIL, out], [RAIL_TO, RAIL, 0.0]], 0.008, 4, caps=False)
    a = RAIL_FROM - 0.03
    b = RAIL_TO + 0.03
    hem = RAIL - 0.26
    box(linen, [b, hem, out - 0.016], [a, RAIL + 0.012, out + 0.016], inked=False, skip=((1, -1),))
    for face, sign in ((out + 0.0165, 1.0), (out - 0.0165, -1.0)):
        stripe_low = hem + 0.035
        corners = [[b, stripe_low, face], [a, stripe_low, face], [a, stripe_low + 0.025, face], [b, stripe_low + 0.025, face]]
        slab(stripe, corners, [0.0, 0.0, sign])


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    frame = Part("frame", "frame")
    teak = Part("teak", "teak")
    brass = Part("brass", "brass")
    enamel = Part("enamel", "enamel")
    dark = Part("dark", "dark")
    glass = Part("mirror", "mirror")
    linen = Part("linen", "linen")
    stripe = Part("stripe", "upholstery")
    cabinet(frame, teak, brass)
    top(enamel)
    basin_and_jug(enamel, dark)
    mirror(frame, glass)
    towel(brass, linen, stripe)
    for part in (frame, teak, brass, enamel, dark, glass, linen, stripe):
        part.build(collection)
    print("washstand: %d triangles" % triangles(collection))
    save(out)


main()
