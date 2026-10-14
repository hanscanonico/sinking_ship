"""Builds assets/models/gauge_small/gauge_small.blend: a pressure gauge of radius
0.085 (RoomDressing.GAUGES), and, called by gauge_large.py, its larger variants — a
brass case and bezel round a white face, its graduations and needle, and the stem
it is piped by — in Godot's axes, metres, its face's middle at the origin facing +z,
the case's back RoomDressing.GAUGE_BACK behind it.

    make model-sources MODEL=gauge_small
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/gauge_small/gauge_small.py -- \\
        assets/models/gauge_small/gauge_small.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, cap, fresh_scene, lathe, save, slab, triangles, tube  # noqa: E402

RADIUS = 0.085
BACK = 0.01
SIDES = 12
OUT = ([1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0])
FRONT = [0.0, 0.0, 1.0]


def build(name, radius, out):
    collection = fresh_scene()
    brass = Part("brass", "brass")
    face = Part("gauge", "gauge")
    dark = Part("dark", "dark")
    r = radius
    rows = lathe(
        brass,
        [0.0, 0.0, 0.0],
        OUT,
        [
            (r, -BACK, 0.0),
            (r, 0.006, 1.0),
            (r * 0.93, 0.013, 0.0),
            (r * 0.85, 0.004, 1.0),
        ],
        SIDES,
    )
    cap(face, rows[-1], [0.0, 0.0, 0.004], FRONT, 0.0)
    z = 0.005
    # Graduations round three quarters of the face, from lower left to lower right.
    for k in range(5):
        a = math.radians(225.0 - 270.0 * k / 4)
        c, s = math.cos(a), math.sin(a)
        w = 0.003
        quad = [[c * r * q - s * w * e, s * r * q + c * w * e, z] for q, e in ((0.62, -1.0), (0.62, 1.0), (0.78, 1.0), (0.78, -1.0))]
        slab(dark, quad, FRONT)
    # The needle, from a short tail through the hub up to the right.
    a = math.radians(55.0)
    c, s = math.cos(a), math.sin(a)
    w = 0.004
    needle = [[-c * r * 0.15 - s * w, -s * r * 0.15 + c * w, z + 0.001], [-c * r * 0.15 + s * w, -s * r * 0.15 - c * w, z + 0.001], [c * r * 0.72, s * r * 0.72, z + 0.001]]
    slab(dark, needle, FRONT)
    hub = [[0.008 * math.cos(math.pi * k / 3), 0.008 * math.sin(math.pi * k / 3), z + 0.002] for k in range(6)]
    cap(brass, hub, [0.0, 0.0, z + 0.003], FRONT, 0.0)
    # The stem under it, down to its pipe.
    tube(brass, [0.0, -r * 0.9, -BACK * 0.5], [0.0, -r - 0.035, -BACK * 0.5], [(0.009, 0.0, 0.0), (0.009, 1.0, 0.0)], 6, caps=(False, False))
    for part in (brass, face, dark):
        part.build(collection)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)


if __name__ == "__main__":
    build("gauge_small", RADIUS, sys.argv[sys.argv.index("--") + 1])
