"""Builds assets/models/handwheel_small/handwheel_small.blend: a valve's handwheel of
radius 0.11 (RoomDressing.HANDWHEELS), and, called by handwheel_large.py, its larger
variant — a steel rim on its spokes, a brass boss and the spindle behind it — in
Godot's axes, metres, its hub's face at the origin facing +z, the spindle reaching
RoomDressing.HANDWHEEL_SPINDLE back to the valve it turns.

    make model-sources MODEL=handwheel_small
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/handwheel_small/handwheel_small.py -- \\
        assets/models/handwheel_small/handwheel_small.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, save, torus, triangles, tube  # noqa: E402

SPINDLE = 0.05
OUT = ([1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0])


def build(name, radius, thick, spokes, segments, out):
    """A handwheel of radius to its rim's middle line and of thick, on spokes, its rim
    in segments."""
    collection = fresh_scene()
    steel = Part("bright_steel", "bright_steel")
    brass = Part("brass", "brass")
    middle = [0.0, 0.0, -thick * 0.5]
    torus(steel, middle, OUT, radius - thick * 0.5, (thick * 0.85, thick * 0.55), segments, 4)
    boss = thick * 1.4
    for k in range(spokes):
        a = 2.0 * math.pi * k / spokes + math.pi * 0.5
        d = [math.cos(a), math.sin(a), 0.0]
        root = [d[i] * boss * 0.7 + middle[i] for i in range(3)]
        tip = [d[i] * (radius - thick * 0.6) + middle[i] for i in range(3)]
        tube(steel, root, tip, [(thick * 0.42, 0.0, 0.0), (thick * 0.32, 1.0, 0.0)], 4, caps=(False, False))
    tube(brass, [0.0, 0.0, -thick], [0.0, 0.0, 0.006], [(boss, 0.0, 0.0), (boss, 0.7, 1.0), (boss * 0.7, 1.0, 0.0)], 6)
    tube(steel, [0.0, 0.0, -thick], [0.0, 0.0, -SPINDLE], [(thick * 0.75, 0.0, 0.0), (thick * 0.75, 1.0, 0.0)], 4, caps=(False, False))
    for part in (steel, brass):
        part.build(collection)
    print("%s: %d triangles" % (name, triangles(collection)))
    save(out)


if __name__ == "__main__":
    build("handwheel_small", 0.11, 0.012, 4, 12, sys.argv[sys.argv.index("--") + 1])
