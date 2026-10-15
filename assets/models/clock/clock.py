"""Builds assets/models/clock/clock.blend: a liner's wall clock (RoomDressing.CLOCK_MODEL)
— a turned brass case and rounded bezel round a white enamel dial, twelve hour marks
on it, the quarters long, and its two hands at ten past ten round a brass boss — in
Godot's axes, metres: x along the wall (Wall.right), y up, z out from the wall's face,
its origin on the wall's face behind the dial's middle. Its bezel is
RoomDressing.CLOCK_RADIUS round, and nothing of it stands more than CLOCK_DEPTH out.

    make model-sources MODEL=clock
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/clock/clock.py -- assets/models/clock/clock.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, cap, fresh_scene, lathe, save, slab, stud, triangles  # noqa: E402

# The bezel's radius over all, the case's at the wall, and how far out its crown and
# the dial stand.
RADIUS = 0.16
CASE = 0.15
CROWN = 0.042
DIAL = 0.036
DIAL_RADIUS = 0.124
SIDES = 12
# The hour marks: from how far out to how far in, a quarter's and an hour's.
MARK_OUT = 0.112
MARK_IN = (0.088, 0.1)
MARK_WIDTH = (0.006, 0.004)
# The hands: each its length, its width at the boss and the angle it points, from 12
# clockwise as seen from the room.
HOUR = (0.062, 0.012, math.radians(-60.0 + 360.0 / 12.0 * (10.0 / 60.0)))
MINUTE = (0.092, 0.009, math.radians(60.0))

FRONT = ([1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0])
Z = [0.0, 0.0, 1.0]


def case(brass, enamel):
    """The case off the wall, its bezel rolled over the dial's edge, and the dial: inked
    at the bezel's rim and where it meets the dial, bright brass on its crown."""
    rows = lathe(
        brass,
        [0.0, 0.0, 0.0],
        FRONT,
        [(CASE, 0.0, 0.0), (RADIUS, 0.03, 1.0), (DIAL_RADIUS + 0.008, CROWN, 0.0), (DIAL_RADIUS, DIAL, 1.0)],
        SIDES,
        phase=math.pi / SIDES,
        wound=True,
    )
    cap(enamel, rows[-1], [0.0, 0.0, DIAL], Z, 0.0)


def towards(angle, reach):
    """A point on the dial reach from its middle, angle clockwise from 12."""
    return [reach * math.sin(angle), reach * math.cos(angle)]


def marks(dark):
    """Twelve hour marks, the four quarters longer and broader."""
    z = DIAL + 0.001
    for hour in range(12):
        angle = 2.0 * math.pi * hour / 12.0
        quarter = 0 if hour % 3 == 0 else 1
        side = [math.cos(angle) * MARK_WIDTH[quarter], -math.sin(angle) * MARK_WIDTH[quarter]]
        inner = towards(angle, MARK_IN[quarter])
        outer = towards(angle, MARK_OUT)
        corners = [
            [inner[0] - side[0], inner[1] - side[1], z],
            [inner[0] + side[0], inner[1] + side[1], z],
            [outer[0] + side[0], outer[1] + side[1], z],
            [outer[0] - side[0], outer[1] - side[1], z],
        ]
        slab(dark, corners, Z)


def hand(dark, length, width, angle, z):
    """A hand: a slim spade from a tail behind the boss to its point."""
    tip = towards(angle, length)
    tail = towards(angle, -length * 0.2)
    waist = towards(angle, length * 0.72)
    across = [math.cos(angle) * width * 0.5, -math.sin(angle) * width * 0.5]
    slab(dark, [[tail[0], tail[1], z], [waist[0] - across[0], waist[1] - across[1], z], [tip[0], tip[1], z], [waist[0] + across[0], waist[1] + across[1], z]], Z)


def hands(dark, brass):
    hand(dark, HOUR[0], HOUR[1], HOUR[2], DIAL + 0.002)
    hand(dark, MINUTE[0], MINUTE[1], MINUTE[2], DIAL + 0.003)
    stud(brass, [0.0, 0.0, DIAL + 0.003], Z, 0.008, 0.005, 6)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    brass = Part("brass", "brass")
    enamel = Part("enamel", "enamel")
    dark = Part("dark", "dark")
    case(brass, enamel)
    marks(dark)
    hands(dark, brass)
    for part in (brass, enamel, dark):
        part.build(collection)
    print("clock: %d triangles" % triangles(collection))
    save(out)


main()
