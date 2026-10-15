"""Builds assets/models/pilaster_base/pilaster_base.blend: a public room's pilaster's
base (LinerPublic._pilaster) — a plinth on the floor and a moulding stepping in from
it to the shaft — in Godot's axes, metres: x along the wall (Wall.right), y up, z out
from the wall's face, its origin on the floor at the wall's face under its middle.
It is LinerPublic.PILASTER_BASE over all, the shaft LinerPublic.PILASTER wide and out
standing on it; painted white, swapped for its room's own.

    make model-sources MODEL=pilaster_base
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/pilaster_base/pilaster_base.py -- \
        assets/models/pilaster_base/pilaster_base.blend
"""

import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, save, triangles  # noqa: E402

# The base over all: along the wall, tall, out from it; the plinth's height in it.
BASE = (0.3, 0.15, 0.11)
PLINTH = 0.1
# The shaft standing on it: its width and how far out.
SHAFT = (0.24, 0.1)
BACK = (2, -1)
FLOOR = (1, -1)
# Faces drawn whole: its ends and its top, inked by the front's rims.
PLAIN = ((0, -1), (0, 1), (1, 1))


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    part = Part("pilaster_base", "white")
    half = BASE[0] * 0.5
    box(part, [-half, 0.0, 0.0], [half, PLINTH, BASE[2]], skip=(BACK, FLOOR), plain=PLAIN)
    # The moulding, halfway in from the plinth to the shaft.
    step = (half + SHAFT[0] * 0.5) * 0.5
    box(part, [-step, PLINTH, 0.0], [step, BASE[1], (BASE[2] + SHAFT[1]) * 0.5], skip=(BACK, FLOOR), plain=PLAIN)
    part.build(collection)
    print("pilaster_base: %d triangles" % triangles(collection))
    save(out)


main()
