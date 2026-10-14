"""Builds assets/models/lifeboat/lifeboat.blend: a double-ended clinker ship's boat
under a ridged canvas cover, in Godot's axes — x fore and aft, y up, z athwartships —
metres, its keel's middle at the origin. Its box over all is ShipFittings'
LIFEBOAT_LENGTH × LIFEBOAT_DEPTH × LIFEBOAT_BEAM: 4.0 × 0.9 × 1.1.

    make model-sources MODEL=lifeboat
    blender --background --factory-startup --python-exit-code 1 \
        --python assets/models/lifeboat/lifeboat.py -- assets/models/lifeboat/lifeboat.blend
"""

import math
import os
import sys

# The shared kit, tools/model_kit.py, from the repo root three folders up.
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "..", "tools"))
from model_kit import Part, fresh_scene, save, triangles  # noqa: E402

# The hull: its half length to the stems' inner line, half breadth at the gunwale, the
# keel's depth under the hull's bottom, the gunwale's height midships, the sheer's rise
# and the bottom's rocker toward the stems.
HL = 1.95
HB = 0.505
KEEL = 0.05
GUN = 0.70
SHEER = 0.14
ROCKER = 0.12
# Clinker: strakes a side, how far proud a strake's lower edge stands of the one under
# it, and the inked band along a lap, as a share of the girth.
STRAKES = 6
LAP = 0.014
RIM = 0.022
# The rubbing strake under the gunwale; the keel and stems' bar; the cover's ridge
# over the gunwale, its overhang and its hem's drop; its straps.
RS_PROUD = 0.03
RS_TOP = 0.045
RS_BOTTOM = 0.10
BAR_WIDTH = 0.06
BAR_DEPTH = 0.05
STEM_HEAD = 0.88
RIDGE = 0.19
OVERHANG = 0.045
HEM = 0.035
STRAPS = [-1.4, -0.84, -0.28, 0.28, 0.84, 1.4]
STRAP_WIDTH = 0.035
STRAP_PROUD = 0.004
STATIONS = 20


def fullness(t):
    return max(0.0, 1.0 - abs(t) ** 2.2) ** 0.75


def half(t):
    return HB * fullness(t)


def bottom(t):
    return KEEL + ROCKER * t**4


def gunwale(t):
    return GUN + SHEER * t * t


def hull_point(t, s, side):
    """A point of the hull's section at t (-1 aft … 1 fore), s of the way round from
    the gunwale (0) to the keel (1), on side (1 starboard, -1 port)."""
    angle = s * math.pi * 0.5
    # Full and round midships, turning to a V toward the stems.
    out = half(t) * max(0.0, math.cos(angle)) ** (0.7 + 1.8 * t**4)
    y = bottom(t) + (gunwale(t) - bottom(t)) * (1.0 - math.sin(angle))
    return [t * HL, y, side * out]


def hull_out(t, s, side):
    """The hull's outward normal in its section's plane there, as (y, z)."""
    e = 1e-4
    a = hull_point(t, max(0.0, s - e), 1)
    b = hull_point(t, min(1.0, s + e), 1)
    dz = b[2] - a[2]
    dy = b[1] - a[1]
    length = math.hypot(dz, dy) or 1.0
    return (dz / length, side * -dy / length)


def lapped(t, s, side, share):
    """The hull point at s, pushed out by share of the lap."""
    p = hull_point(t, s, side)
    oy, oz = hull_out(t, s, side)
    lap = LAP * min(1.0, 2.0 * fullness(t)) * share
    return [p[0], p[1] + oy * lap, p[2] + oz * lap]


def station_ts():
    return [math.sin(math.pi * 0.5 * (-1.0 + 2.0 * j / STATIONS)) for j in range(STATIONS + 1)]


def section_rows():
    """The section's rows down one side: (s, share of the lap, ink)."""
    bounds = [k / STRAKES for k in range(STRAKES + 1)]
    rows = []
    for k in range(STRAKES):
        a, b = bounds[k], bounds[k + 1]
        last = k == STRAKES - 1
        rim = RIM / (b - a)
        if k > 0:
            rows.append((a, 0.0, 1.0))
            rows.append((a + RIM, 0.0 if last else rim, 0.0))
        else:
            rows.append((a, 0.0, 0.0))
        rows.append((b - RIM, 0.0 if last else 1.0 - rim, 0.0))
        rows.append((b, 0.0 if last else 1.0, 1.0))
    return rows


def axis_out(middle):
    return [0.0, middle[1] - 0.4, middle[2]]


def hull(collection):
    part = Part("hull", "white")
    rows = section_rows()
    stations = []
    inks = []
    ts = station_ts()
    for t in ts:
        section = [lapped(t, s, 1, share) for s, share, _ in rows]
        section += [lapped(t, s, -1, share) for s, share, _ in reversed(rows[:-1])]
        stations.append(section)
    column_inks = [ink for _, _, ink in rows] + [ink for _, _, ink in reversed(rows[:-1])]
    for t in ts:
        # The stems are hard edges: ink at the hull's ends.
        inks.append([1.0 if abs(t) > 0.9999 else ink for ink in column_inks])
    part.grid(stations, None, axis_out, row_inks=inks)
    return part.build(collection)


def rubbing_strakes(collection):
    part = Part("rubbing_strake", "teak")
    ts = [t for t in station_ts() if abs(t) < 0.96]
    ts = [-0.96] + ts + [0.96]
    for side in (1, -1):
        rows = []
        for t in ts:
            x = t * HL
            g = gunwale(t)
            # Tapered off at its ends.
            outer = side * (half(t) + RS_PROUD * min(1.0, max(0.25, (0.98 - abs(t)) / 0.08)))
            top = g - RS_TOP
            low = g - RS_BOTTOM
            s_top = math.asin(min(1.0, RS_TOP / (g - bottom(t)))) * 2.0 / math.pi
            s_low = math.asin(min(1.0, RS_BOTTOM / (g - bottom(t)))) * 2.0 / math.pi
            inner_top = hull_point(t, s_top, side)
            inner_low = hull_point(t, s_low, side)
            inner_top[2] -= side * 0.004
            inner_low[2] -= side * 0.004
            rows.append(
                [
                    inner_top,
                    [x, top, outer],
                    [x, top - 0.012, outer],
                    [x, low + 0.012, outer],
                    [x, low, outer],
                    inner_low,
                ]
            )
        part.grid(rows, [1.0, 1.0, 0.0, 0.0, 1.0, 1.0], lambda m, side=side: [0.0, 0.0, side])
        for end, row in ((-1.0, rows[0]), (1.0, rows[-1])):
            part.fan(row, [end, 0.0, 0.0])
    return part.build(collection)


def keel(collection):
    """The keel along her bottom and the stems up her ends, one bar."""
    part = Part("keel", "teak")
    path = [(-HL, STEM_HEAD), (-HL, bottom(-1.0))]
    path += [(t * HL, bottom(t)) for t in station_ts()[1:-1]]
    path += [(HL, bottom(1.0)), (HL, STEM_HEAD)]
    centre = (0.0, 0.45)
    outs = []
    for k, (x, y) in enumerate(path):
        normals = []
        for a, b in ((k - 1, k), (k, k + 1)):
            if a < 0 or b >= len(path):
                continue
            dx = path[b][0] - path[a][0]
            dy = path[b][1] - path[a][1]
            length = math.hypot(dx, dy)
            n = (dy / length, -dx / length)
            if n[0] * (x - centre[0]) + n[1] * (y - centre[1]) < 0.0:
                n = (-n[0], -n[1])
            normals.append(n)
        nx = sum(n[0] for n in normals)
        ny = sum(n[1] for n in normals)
        length = math.hypot(nx, ny)
        n = (nx / length, ny / length)
        # A mitred corner reaches further out, so the bar keeps its depth round it.
        stretch = 1.0 / max(0.5, n[0] * normals[0][0] + n[1] * normals[0][1])
        outs.append((n[0] * stretch, n[1] * stretch))
    w = BAR_WIDTH * 0.5
    profile = [
        (w, -0.02, 1.0),
        (w, BAR_DEPTH - 0.01, 0.0),
        (w, BAR_DEPTH, 1.0),
        (w - 0.01, BAR_DEPTH, 0.0),
        (-w + 0.01, BAR_DEPTH, 0.0),
        (-w, BAR_DEPTH, 1.0),
        (-w, BAR_DEPTH - 0.01, 0.0),
        (-w, -0.02, 1.0),
    ]
    rows = []
    for (x, y), (nx, ny) in zip(path, outs):
        rows.append([[x + nx * o, y + ny * o, z] for z, o, _ in profile])
    part.grid(
        rows,
        [ink for _, _, ink in profile],
        lambda m: [m[0] * 0.2, m[1] - 0.45, m[2]],
    )
    for row in (rows[0], rows[-1]):
        part.fan(row, [0.0, 1.0, 0.0])
    return part.build(collection)


def cover_profile(t, proud=0.0, hem=True):
    """The cover across her at t, starboard hem to port hem, with each point's ink."""
    f = fullness(t)
    g = gunwale(t)
    h = half(t)
    drop = HEM * min(1.0, 2.0 * f)
    edge = h + OVERHANG * f
    one_side = [
        ([h - 0.002, g - drop, 1], 1.0),
        ([edge, g - drop, 1], 1.0),
        ([edge, g - drop + 0.02 * min(1.0, 2.0 * f), 1], 0.0),
        ([h + OVERHANG * f * 0.6, g + 0.03 * f, 1], 0.0),
        ([h * 0.5, g + RIDGE * 0.72 * f, 1], 0.0),
    ]
    if not hem:
        one_side = one_side[1:]
    points = []
    for (z, y, _), ink in one_side:
        points.append(([t * HL, y, z], ink))
    points.append(([t * HL, g + RIDGE * f, 0.0], 0.0))
    for (z, y, _), ink in reversed(one_side):
        points.append(([t * HL, y, -z], ink))
    if proud:
        lifted = []
        for p, ink in points:
            out = [0.0, p[1] - (g - 0.25), p[2]]
            length = math.hypot(out[1], out[2]) or 1.0
            lifted.append(([p[0], p[1] + out[1] / length * proud, p[2] + out[2] / length * proud], ink))
        points = lifted
    return points


def cover(collection):
    part = Part("cover", "canvas")
    rows = []
    for t in station_ts():
        rows.append([p for p, _ in cover_profile(t)])
    inks = [ink for _, ink in cover_profile(0.0)]
    part.grid(rows, inks, lambda m: [0.0, m[1] - 0.45, m[2]])
    return part.build(collection)


def straps(collection):
    part = Part("straps", "rope")
    for x in STRAPS:
        rows = []
        for along in (x - STRAP_WIDTH * 0.5, x + STRAP_WIDTH * 0.5):
            t = along / HL
            profile = cover_profile(t, STRAP_PROUD, hem=False)
            rows.append([p for p, _ in profile])
        inks = [ink for _, ink in cover_profile(0.0, hem=False)]
        part.grid(rows, inks, lambda m: [0.0, m[1] - 0.45, m[2]])
    return part.build(collection)


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    collection = fresh_scene()
    hull(collection)
    rubbing_strakes(collection)
    keel(collection)
    cover(collection)
    straps(collection)
    print("lifeboat: %d triangles" % triangles(collection))
    save(out)


main()
