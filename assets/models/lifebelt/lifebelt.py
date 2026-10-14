"""Builds assets/models/lifebelt/lifebelt.blend: a cork lifebuoy hung flat on a wall
(RoomDressing.lifebelt), in Godot's axes, metres: its middle at the origin on the
wall's face, facing +z, y up. Its ring, RoomDressing.LIFEBELT_RADIUS round and
LIFEBELT_DEPTH out from the wall, is canvas-covered and painted red with a white band
on each diagonal; its grab line is seized to it at each band and hangs in four
bights round it between them.

    make model-sources MODEL=lifebelt
    blender --background --factory-startup --python-exit-code 1 \\
        --python assets/models/lifebelt/lifebelt.py -- assets/models/lifebelt/lifebelt.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, save, sweep, triangles  # noqa: E402

# The ring's section, round the axis z: (radius, out from the wall), from inside its
# hole round its face to its outside, both ends on the wall.
SECTION = [(0.19, 0.0), (0.205, 0.05), (0.26, 0.075), (0.315, 0.05), (0.33, 0.0)]
# Twelve strips round it; every third, from the second, white.
STRIPS = 12
# The grab line: its thickness, where it is seized on the ring, how far out its bights
# hang and how far they sag.
LINE = 0.008
SEIZED = (0.328, 0.04)
BIGHT = 0.035
SAG = 0.03
# The points each bight is swept through, its seizing the first.
BIGHT_POINTS = 4


def ring(red, white):
    """The ring in its strips, each in its paint."""
    for index in range(STRIPS):
        part = white if index % 3 == 1 else red
        a = 2.0 * math.pi * index / STRIPS
        b = 2.0 * math.pi * (index + 1) / STRIPS
        rows = []
        for radius, out in SECTION:
            rows.append(
                [[radius * math.cos(a), radius * math.sin(a), out], [radius * math.cos(b), radius * math.sin(b), out]]
            )

        def outward(middle):
            # Out of the ring's round section, from the circle through its middle.
            centre = 0.26
            r = math.hypot(middle[0], middle[1]) or 1.0
            return [middle[0] - middle[0] / r * centre, middle[1] - middle[1] / r * centre, middle[2]]

        part.grid(rows, [0.0, 0.0], outward)


def grab_line(rope):
    """The line round it, seized at each white band's middle, in a bight between
    hanging out from it and down."""
    path = []
    for quarter in range(4):
        for step in range(BIGHT_POINTS):
            t = step / BIGHT_POINTS
            a = math.pi * (0.25 + 0.5 * quarter + 0.5 * t)
            hang = math.sin(math.pi * t)
            radius = SEIZED[0] + BIGHT * hang
            path.append([radius * math.cos(a), radius * math.sin(a) - SAG * hang, SEIZED[1]])
    path.append(path[0])
    sweep(rope, path, LINE, 3, caps=False)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    parts = {paint: Part(paint, paint) for paint in ("lifebelt", "white", "rope")}
    ring(parts["lifebelt"], parts["white"])
    grab_line(parts["rope"])
    for part in parts.values():
        part.build(collection, sharp_angle=60.0)
    print("lifebelt: %d triangles" % triangles(collection))
    save(out)


main()
