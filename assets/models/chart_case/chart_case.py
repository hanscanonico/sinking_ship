"""Builds assets/models/chart_case/chart_case.blend: what hangs on a wheelhouse's after
wall (RoomDressing._chart_wall) — a shallow teak chart case of two drawers on its
brackets, a fiddle along its top, and over it a chart pinned in its frame — in Godot's
axes, metres: x along the wall (Wall.right), y up, z out from the wall's face into the
room, its origin on the floor at the wall's face under the case's middle. Nothing
stands further out than RoomDressing.CHART_CASE's depth, a wall fitting's.

    make model-sources MODEL=chart_case
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/chart_case/chart_case.py -- \
        assets/models/chart_case/chart_case.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, box, fresh_scene, save, slab, triangles, tube  # noqa: E402

# The case: its half length, its depth off the wall, its underside and top.
HALF = 0.5
DEPTH = 0.09
LOW = 0.7
HIGH = 0.98
# The chart's frame: its middle's height, its half size; the paper's.
CHART_HEIGHT = 1.45
FRAME = (0.27, 0.3)
PAPER = (0.23, 0.26)
FRAME_DEPTH = 0.018

BACK = (2, -1)
FRONT = [0.0, 0.0, 1.0]


def case(frame, teak, brass):
    """The case, its drawers' raised fronts with their brass pulls, its brackets and
    the fiddle round its top."""
    box(frame, [-HALF, LOW, 0.0], [HALF, HIGH, DEPTH], skip=(BACK,))
    for drawer in range(2):
        middle = LOW + 0.07 + drawer * 0.13
        box(teak, [-HALF + 0.05, middle - 0.05, DEPTH], [HALF - 0.05, middle + 0.05, DEPTH + 0.008], rim=0.012, skip=(BACK,))
        for side in (-1.0, 1.0):
            at = side * 0.2
            tube(brass, [at - 0.05, middle, DEPTH + 0.008], [at + 0.05, middle, DEPTH + 0.008], [(0.009, 0.0, 0.0), (0.009, 1.0, 0.0)], 5, caps=(True, True))
    # The fiddle: a low rail along the top's front and ends, so nothing slides off.
    box(frame, [-HALF, HIGH, DEPTH - 0.018], [HALF, HIGH + 0.03, DEPTH], rim=0.008, skip=((1, -1),))
    for side in (-1.0, 1.0):
        x0, x1 = sorted((side * HALF, side * (HALF - 0.018)))
        box(frame, [x0, HIGH, 0.0], [x1, HIGH + 0.03, DEPTH - 0.018], rim=0.008, skip=(BACK, (1, -1)))
    # A knee under each end, its face a triangle from the wall out under the case.
    for side in (-1.0, 1.0):
        x = side * (HALF - 0.08)
        drop = 0.24
        for face in (-1.0, 1.0):
            edge = x + face * 0.015
            points = [[edge, LOW, 0.0], [edge, LOW, DEPTH - 0.01], [edge, LOW - drop, 0.0]]
            slab(frame, points, [face, 0.0, 0.0])
        slope = [[x - 0.015, LOW, DEPTH - 0.01], [x + 0.015, LOW, DEPTH - 0.01], [x + 0.015, LOW - drop, 0.0], [x - 0.015, LOW - drop, 0.0]]
        slab(frame, slope, [0.0, -DEPTH, drop])


def chart(frame, paper, dark, upholstery):
    """The chart in its frame: the paper, a coast, its rhumb lines and a compass rose."""
    box(frame, [-FRAME[0], CHART_HEIGHT - FRAME[1], 0.0], [FRAME[0], CHART_HEIGHT + FRAME[1], FRAME_DEPTH], rim=0.02, skip=(BACK,))
    z = FRAME_DEPTH + 0.002
    corners = [[-PAPER[0], CHART_HEIGHT - PAPER[1], z], [PAPER[0], CHART_HEIGHT - PAPER[1], z], [PAPER[0], CHART_HEIGHT + PAPER[1], z], [-PAPER[0], CHART_HEIGHT + PAPER[1], z]]
    slab(paper, corners, FRONT)
    ink_z = z + 0.001

    def line(points, width):
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            dx, dy = bx - ax, by - ay
            length = math.hypot(dx, dy) or 1.0
            nx, ny = -dy / length * width, dx / length * width
            quad = [
                [ax + nx, CHART_HEIGHT + ay + ny, ink_z],
                [ax - nx, CHART_HEIGHT + ay - ny, ink_z],
                [bx - nx, CHART_HEIGHT + by - ny, ink_z],
                [bx + nx, CHART_HEIGHT + by + ny, ink_z],
            ]
            slab(dark, quad, FRONT)

    # A coast running down the chart's left side into a bay, and a headland.
    line([(-0.23, 0.22), (-0.15, 0.17), (-0.16, 0.08), (-0.08, 0.02), (-0.12, -0.07), (-0.05, -0.15), (-0.09, -0.26)], 0.004)
    # Two courses laid off across it.
    line([(-0.04, -0.1), (0.2, 0.12)], 0.002)
    line([(-0.07, 0.0), (0.21, -0.2)], 0.002)
    # The compass rose: eight points round a centre.
    centre = (0.11, -0.05)
    for k in range(8):
        a = math.pi * 0.25 * k
        reach = 0.07 if k % 2 == 0 else 0.04
        tip = (centre[0] + math.cos(a) * reach, centre[1] + math.sin(a) * reach)
        left = (centre[0] + math.cos(a + 0.4) * 0.012, centre[1] + math.sin(a + 0.4) * 0.012)
        right = (centre[0] + math.cos(a - 0.4) * 0.012, centre[1] + math.sin(a - 0.4) * 0.012)
        points = [[p[0], CHART_HEIGHT + p[1], ink_z + 0.0005] for p in (right, tip, left)]
        slab(upholstery, points, FRONT)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    parts = {paint: Part(paint, paint) for paint in ("frame", "teak", "brass", "chart", "dark", "upholstery")}
    case(parts["frame"], parts["teak"], parts["brass"])
    chart(parts["frame"], parts["chart"], parts["dark"], parts["upholstery"])
    for part in parts.values():
        part.build(collection)
    print("chart_case: %d triangles" % triangles(collection))
    save(out)


main()
