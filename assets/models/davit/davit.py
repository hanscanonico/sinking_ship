"""Builds assets/models/davit/davit.blend: a radial davit for the lifeboats, in
Godot's axes, metres, its post's axis at the deck's edge height at the origin, its
swan neck curving out toward +z over the boat. Its post rises ShipFittings' DAVIT_RISE
and bends through a quarter circle of DAVIT_REACH, so its tip stands DAVIT_REACH out
and DAVIT_RISE + DAVIT_REACH up; its foot DAVIT_FOOT under the deck.

    make model-sources MODEL=davit
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/davit/davit.py -- assets/models/davit/davit.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, save, triangles  # noqa: E402

R = 0.045
RISE = 1.3
REACH = 0.785
FOOT = 0.5
SIDES = 10
ARC_STEPS = 12
RIM = 0.02
COLLAR = 0.068
COLLAR_HALF = 0.035
CLEAT_HEIGHT = 1.0
ROPE = 0.011


def ring(centre, tangent, radius, sides):
    """A circle round centre, square to tangent (which lies in the y/z plane)."""
    tx, ty, tz = tangent
    # One axis across the davit's plane (x), the other in it, square to the tangent.
    bx, by, bz = 0.0, -tz, ty
    points = []
    for k in range(sides):
        a = 2.0 * math.pi * k / sides
        c, s = math.cos(a), math.sin(a)
        points.append([centre[0] + radius * c, centre[1] + radius * s * by, centre[2] + radius * s * bz])
    return points


def tube(collection):
    part = Part("davit", "white")
    path = [([0.0, -FOOT, 0.0], [0, 1, 0], 1.0), ([0.0, -FOOT + RIM, 0.0], [0, 1, 0], 0.0)]
    path.append(([0.0, RISE, 0.0], [0, 1, 0], 0.0))
    last = math.pi * 0.5 - RIM / REACH
    angles = [last * k / ARC_STEPS for k in range(1, ARC_STEPS + 1)] + [math.pi * 0.5]
    for angle in angles:
        centre = [0.0, RISE + REACH * math.sin(angle), REACH * (1.0 - math.cos(angle))]
        tangent = [0.0, math.cos(angle), math.sin(angle)]
        path.append((centre, tangent, 1.0 if angle == math.pi * 0.5 else 0.0))
    rows = [ring(c, t, R, SIDES) for c, t, _ in path]
    inks = [[ink] * SIDES for _, _, ink in path]

    def axis_out(middle):
        # Out from the nearest point of the davit's centre line.
        if middle[1] <= RISE:
            return [middle[0], 0.0, middle[2]]
        dy = middle[1] - RISE
        dz = middle[2] - REACH
        length = math.hypot(dy, dz) or 1.0
        near = [0.0, RISE + dy / length * REACH, REACH + dz / length * REACH]
        return [m - n for m, n in zip(middle, near)]

    part.grid(rows, None, axis_out, closed=True, row_inks=inks)
    part.fan(rows[0], [0.0, -1.0, 0.0])
    part.fan(rows[-1], [0.0, 0.0, 1.0])
    return part


def collar(part, y):
    """A collar round the post, its middle at height y."""
    profile = [
        (R - 0.002, y + COLLAR_HALF, 1.0),
        (COLLAR, y + COLLAR_HALF, 1.0),
        (COLLAR, y + COLLAR_HALF - 0.012, 0.0),
        (COLLAR, y - COLLAR_HALF + 0.012, 0.0),
        (COLLAR, y - COLLAR_HALF, 1.0),
        (R - 0.002, y - COLLAR_HALF, 1.0),
    ]
    rows = []
    for k in range(SIDES + 1):
        a = 2.0 * math.pi * k / SIDES
        rows.append([[r * math.cos(a), h, r * math.sin(a)] for r, h, _ in profile])
    part.grid(rows, [ink for _, _, ink in profile], lambda m: [m[0], 0.0, m[2]])


def box(part, low, high):
    """An axis-aligned box from low to high, uninked (a dark paint shows no rim)."""
    x0, y0, z0 = low
    x1, y1, z1 = high
    corners = [
        [x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0],
        [x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1],
    ]
    ids = [part.point(c) for c in corners]
    middle = [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2]
    for face in ([0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [0, 3, 7, 4], [1, 2, 6, 5]):
        centre = [sum(corners[i][axis] for i in face) / 4 - middle[axis] for axis in range(3)]
        part.face([ids[i] for i in face], [0.0] * 4, centre)


def cleat(collection):
    part = Part("cleat", "dark")
    box(part, [-0.012, CLEAT_HEIGHT - 0.02, R - 0.005], [0.012, CLEAT_HEIGHT + 0.02, R + 0.03])
    box(part, [-0.012, CLEAT_HEIGHT - 0.08, R + 0.03], [0.012, CLEAT_HEIGHT + 0.08, R + 0.052])
    return part.build(collection)


def hauling_part(collection):
    """The fall's hauling part, from under the davit's head block down to the cleat."""
    part = Part("hauling_part", "rope")
    top = [0.0, RISE + REACH - R - 0.17, REACH - 0.035]
    low = [0.0, CLEAT_HEIGHT + 0.07, R + 0.06]
    d = [b - a for a, b in zip(top, low)]
    length = math.sqrt(sum(c * c for c in d))
    tangent = [c / length for c in d]
    rows = [ring(top, tangent, ROPE, 6), ring(low, tangent, ROPE, 6)]
    axis = top

    def out(middle):
        # Away from the rope's line.
        rel = [m - a for m, a in zip(middle, axis)]
        along = sum(r * t for r, t in zip(rel, tangent))
        return [r - along * t for r, t in zip(rel, tangent)]

    part.grid(rows, [0.0] * 6, out, closed=True)
    return part.build(collection)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    post = tube(collection)
    collar(post, 0.0)
    collar(post, -FOOT + 0.08)
    post.build(collection)
    cleat(collection)
    hauling_part(collection)
    print("davit: %d triangles" % triangles(collection))
    save(out)


main()
