#!/usr/bin/env python3
"""Writes the ore freighter's layout and structure, data/ships/freighter.tres (SH38).

The layout and structure are generated: change her here, then `make ship SHIP=freighter`.
`make ship-gen-check` (part of `make verify`) fails when the committed .tres is not what
this writes, so a hand edit to the .tres is caught. The sim reads only the .tres (D6).

A 180 m Great Lakes ore carrier — a laker, after the Edmund Fitzgerald scaled down from
her 222 m —, between the ferry and the Titanic: long, slab-sided and shallow for her
length, two islands of accommodation 150 m apart and nothing but open spar deck between
them. Aft, her engine house over her engine room — the galley and the mess, the officers'
cabins on its roof, the boat deck, and her funnel; forward, her forecastle house of crew
cabins with the pilothouse on its roof, the bridge deck. Between them the spar deck runs
120 m past a row of twenty hatch coamings, low blockers to fight round, a railing down
each side. Under it her ore holds, one long space parted only by two screen bulkheads
that are not watertight (the Fitzgerald's were not), between ballast tanks along her
sides and under her. Her signature is that she breaks in two: her long girder is weak for
her length, weakest at her hatch row where the screen bulkheads stand, and a hold
flooding through a hit loads her until the bending passes what it keeps. Her sections
are lofted here from a few numbers, as the ferry's (tools/gen_ferry.py), and the dressed
art draws her hull from them (SectionHull; ShipLayout.dressed). Every number is est.
until a playtest or the census says otherwise.

Ship-local metres: x toward the bow, z to starboard, y up, origin on the spar deck — her
main deck — amidships.

Usage: tools/gen_freighter.py <out.tres>
"""
import math
import re
import struct
import sys

out = sys.argv[1]

def num(v):
    v = round(v, 4)
    if v == int(v):
        return str(int(v))
    return repr(v)

def rect(x, z, w, d):
    return "Rect2(%s, %s, %s, %s)" % (num(x), num(z), num(w), num(d))

def rect_xz(x0, x1, z0, z1):
    return rect(x0, z0, x1 - x0, z1 - z0)

subs = []
platforms, ramps, blockers, railings, ladders, rooms, props = [], [], [], [], [], [], []
used = set()
# The same pieces as numbers, for the structure below: (x0, x1, z0, z1, height) per
# platform; (x0, x1, z0, z1, axis, start, end) per ramp; (x0, x1, z0, z1, bottom, top,
# is a box) per blocker; (x0, x1, z0, z1, floor, name) per room; and every doorway as
# (axis, at, from, to, bottom): a gap in a wall along x = at (axis 0) or z = at (axis 2).
plat_geo, ramp_geo, block_geo, room_geo, doorways = [], [], [], [], []

def sub(kind_id, script, fields):
    assert kind_id not in used, kind_id
    used.add(kind_id)
    body = ["[sub_resource type=\"Resource\" id=\"%s\"]" % kind_id, "script = ExtResource(\"%s\")" % script]
    for k, v in fields:
        body.append("%s = %s" % (k, v))
    subs.append("\n".join(body))
    return kind_id

def platform(pid, name, x0, x1, z0, z1, h=0.0):
    plat_geo.append((x0, x1, z0, z1, h))
    f = [("name", '&"%s"' % name), ("area", rect_xz(x0, x1, z0, z1))]
    if h != 0.0:
        f.append(("height", num(h)))
    platforms.append(sub("Platform_" + pid, "1_plat", f))
    return len(platforms) - 1

# The steepest stair a body climbs: its rise a body's radius on under a step, both
# read from data/rules/brawl.tres.
def rule(key):
    with open("data/rules/brawl.tres") as f:
        return float(re.search(r"^%s = ([\d.]+)$" % key, f.read(), re.M).group(1))

STEEPEST = rule("step_height") / rule("body_radius")

def ramp(rid, x, z, w, d, start, end, axis=0):
    """A stair from start (at x, or z across her) to end (at x + w, or z + d), its
    area w along her by d across."""
    assert abs(end - start) / (w if axis == 0 else d) <= STEEPEST, "stair %s too steep to climb" % rid
    ramp_geo.append((x, x + w, z, z + d, axis, start, end))
    f = [("area", rect(x, z, w, d))]
    if axis == 1:
        f.append(("axis", "1"))
    if start != 0.0:
        f.append(("start_height", num(start)))
    if end != 0.0:
        f.append(("end_height", num(end)))
    ramps.append(sub("Ramp_" + rid, "2_ramp", f))

def holed(pid, name, x0, x1, z0, z1, h, holes):
    """The deck x0…x1 by z0…z1 at h less holes [(x0, x1, z0, z1)], as the trawler's
    generator lays one: in bands along z between the holes' sides, each band round the
    holes in it. Its largest piece stands where the deck stood in the platforms' order,
    the rest after all her decks (pieces_after()), so no other platform's index moves.
    Returns the largest piece's index."""
    pieces = []
    zs = sorted({z0, z1} | {v for o in holes for v in o[2:] if z0 < v < z1})
    for c, d in zip(zs, zs[1:]):
        across_band = sorted(o for o in holes if o[2] <= c and d <= o[3])
        edges = [x0] + [v for o in across_band for v in o[:2]] + [x1]
        for e, f in zip(edges[::2], edges[1::2]):
            if f - e > 1e-6:
                pieces.append((e, f, c, d))
    pieces.sort(key=lambda p: -(p[1] - p[0]) * (p[3] - p[2]))
    first = platform(pid, name, *pieces[0], h)
    for k, piece in enumerate(pieces[1:]):
        later.append(("%s_%d" % (pid, k + 1), name, piece, h))
    return first

later = []

def pieces_after():
    for pid, name, piece, h in later:
        platform(pid, name, *piece, h)

def box(bid, x0, x1, z0, z1, bottom, top):
    block_geo.append((x0, x1, z0, z1, bottom, top, True))
    f = [("area", rect_xz(x0, x1, z0, z1))]
    if bottom != 0.0:
        f.append(("bottom", num(bottom)))
    f.append(("top", num(top)))
    blockers.append(sub("Blocker_" + bid, "3_block", f))

def cylinder(bid, cx, cz, r, bottom, top):
    block_geo.append((cx - r, cx + r, cz - r, cz + r, bottom, top, False))
    f = [("shape", "1"), ("centre", "Vector2(%s, %s)" % (num(cx), num(cz))), ("radius", num(r))]
    if bottom != 0.0:
        f.append(("bottom", num(bottom)))
    f.append(("top", num(top)))
    blockers.append(sub("Blocker_" + bid, "3_block", f))

# A railing breaks span by span (SH10), as the steamer's: a run longer than
# RAIL_SECTION is laid as touching spans of about that length.
RAIL_SECTION = 3.5

def edge_holds(plat, a, b):
    """Whether the segment a…b (x, z) lies along an edge of platform plat, as
    ShipPlatform.edge_holds has it."""
    x0, x1, z0, z1, _h = plat_geo[plat]
    near = lambda u, v: abs(u - v) < 1e-5
    inside = all(x0 - 0.001 <= p[0] <= x1 + 0.001 and z0 - 0.001 <= p[1] <= z1 + 0.001 for p in (a, b))
    return inside and (any(near(a[0], x) and near(b[0], x) for x in (x0, x1))
                       or any(near(a[1], z) and near(b[1], z) for z in (z0, z1)))

def holding(a, b, plat):
    """The platform a railing or a ladder from a to b stands on: plat, else the piece of
    the deck plat is in whose edge holds it — a deck laid round holes is in pieces."""
    if edge_holds(plat, a, b):
        return plat
    height = plat_geo[plat][4]
    for other in range(len(plat_geo)):
        if plat_geo[other][4] == height and edge_holds(other, a, b):
            return other
    raise AssertionError("no edge of the deck at %s holds %s…%s" % (height, a, b))

def cuts(plat, a, b):
    """Where the run a…b crosses from one piece of plat's deck to the next: the ends,
    along it, of every platform at its height whose edge it runs along."""
    height = plat_geo[plat][4]
    along_x = abs(a[1] - b[1]) < 1e-9
    line = a[1] if along_x else a[0]
    lo, hi = sorted((a[0], b[0]) if along_x else (a[1], b[1]))
    found = set()
    for x0, x1, z0, z1, h in plat_geo:
        across = (z0, z1) if along_x else (x0, x1)
        if h == height and across[0] - 1e-6 <= line <= across[1] + 1e-6:
            found |= {v for v in ((x0, x1) if along_x else (z0, z1)) if lo + 1e-6 < v < hi - 1e-6}
    points = sorted(found, reverse=(b[0] < a[0]) if along_x else (b[1] < a[1]))
    return [a] + [(v, line) if along_x else (line, v) for v in points] + [b]

def railing(rid, plat, a, b):
    """A railing from a to b along an edge of plat's deck, in spans of about
    RAIL_SECTION, broken where the deck's pieces meet so each span stands on one."""
    ends = []
    for p, q in zip(cuts(plat, a, b), cuts(plat, a, b)[1:]):
        length = abs(q[0] - p[0]) + abs(q[1] - p[1])  # every railing runs along x or z
        count = -(-length // RAIL_SECTION)
        step = round(length / count * 2) / 2
        ends += [p] + [(p[0] + (q[0] - p[0]) * step * k / length, p[1] + (q[1] - p[1]) * step * k / length)
                       for k in range(1, int(count))]
    ends.append(b)
    for k in range(len(ends) - 1):
        f = []
        on = holding(ends[k], ends[k + 1], plat)
        if on != 0:
            f.append(("platform", str(on)))
        f.append(("from", "Vector2(%s, %s)" % (num(ends[k][0]), num(ends[k][1]))))
        f.append(("to", "Vector2(%s, %s)" % (num(ends[k + 1][0]), num(ends[k + 1][1]))))
        railings.append(sub("Railing_" + rid + ("_%d" % k if len(ends) > 2 else ""), "4_rail", f))

def ladder(lid, plat, a, b):
    f = []
    plat = holding(a, b, plat)
    if plat != 0:
        f.append(("platform", str(plat)))
    f.append(("from", "Vector2(%s, %s)" % (num(a[0]), num(a[1]))))
    f.append(("to", "Vector2(%s, %s)" % (num(b[0]), num(b[1]))))
    ladders.append(sub("Ladder_" + lid, "7_ladder", f))

# A crate of stores left on the spar deck: the steamer's cargo crate (SH10), the same
# circle, height, mass and grip.
CRATE = [("radius", 0.45), ("height", 0.8), ("mass", 200), ("grip_angle_deg", 8), ("friction", 2.5)]

def crate(cid, x, y, z):
    f = [("pos", "Vector3(%s, %s, %s)" % (num(x), num(y), num(z)))]
    f += [(k, num(v)) for k, v in CRATE]
    props.append(sub("Prop_" + cid, "8_prop", f))

def room(rid, name, x0, x1, z0, z1, floor):
    room_geo.append((x0, x1, z0, z1, floor, name))
    f = [("name", '&"%s"' % name), ("area", rect_xz(x0, x1, z0, z1))]
    if floor != 0.0:
        f.append(("floor_height", num(floor)))
    rooms.append(sub("Room_" + rid, "6_room", f))

T = 0.1  # half a wall's thickness: walls are 0.2 m, centred on a room's side
DOOR = 1.1
LINTEL = 2.1  # a door's height above its floor

def wall_x(bid, x, z0, z1, bottom, top):
    """A wall along x = const from z0 to z1 (centre line), ends overlapping corners."""
    box(bid, x - T, x + T, z0 - T, z1 + T, bottom, top)

def wall_z(bid, z, x0, x1, bottom, top):
    box(bid, x0 - T, x1 + T, z - T, z + T, bottom, top)

def wall_x_doors(bid, x, z0, z1, doors, bottom, top, sill=0.0):
    """Wall pieces along x = const with door gaps [(a, b)] in z; a lintel over each
    where the wall stands taller than a door, and a sill under each sill high."""
    edges = [z0 - T] + [v for d in doors for v in d] + [z1 + T]
    for i in range(0, len(edges), 2):
        box("%s_%d" % (bid, i // 2), x - T, x + T, edges[i], edges[i + 1], bottom, top)
    for i, d in enumerate(doors):
        if bottom + LINTEL < top:
            box("%s_lintel_%d" % (bid, i), x - T, x + T, d[0], d[1], bottom + LINTEL, top)
        if sill > 0.0:
            box("%s_sill_%d" % (bid, i), x - T, x + T, d[0], d[1], bottom, bottom + sill)
        doorways.append((0, x, d[0], d[1], bottom, sill))

def wall_z_doors(bid, z, x0, x1, doors, bottom, top, sill=0.0):
    edges = [x0 - T] + [v for d in doors for v in d] + [x1 + T]
    for i in range(0, len(edges), 2):
        box("%s_%d" % (bid, i // 2), edges[i], edges[i + 1], z - T, z + T, bottom, top)
    for i, d in enumerate(doors):
        if bottom + LINTEL < top:
            box("%s_lintel_%d" % (bid, i), d[0], d[1], z - T, z + T, bottom + LINTEL, top)
        if sill > 0.0:
            box("%s_sill_%d" % (bid, i), d[0], d[1], z - T, z + T, bottom, bottom + sill)
        doorways.append((2, z, d[0], d[1], bottom, sill))


# Her heights (est.): the spar deck — her main deck, the hatch row's — at 0; the engine
# room's plates 5 m under it; the boat deck aft and the bridge deck forward, each its
# house's roof, 2.8 m over it; and the roofs of the cabins and the pilothouse on them
# 2.6 m over that. 10.5 m is her half beam.
LOWER = -5.0
UPPER = 2.8
TOP = 5.4
BEAM = 10.5
# Her spar deck, to its edges (x from, x to, half breadth): the long deck between her
# houses, the stern deck under her engine house, and the bow deck and the foredeck by and
# before her forecastle house, each as broad as her shell lets it be (est.).
MAIN = (-66.0, 74.0, 10.4)
STERN = (-89.5, -66.0, 9.4)
BOW = (74.0, 82.0, 7.8)
FORE = (82.0, 86.0, 4.5)
# Her houses, to the middle of their walls (x from its after face to its forward face,
# and its half breadth): her engine house aft, over the engine room, and on its roof —
# the boat deck — the officers' cabins; her forecastle house forward, and on its roof —
# the bridge deck — the pilothouse. Each roof runs on OVERHANG past its house's face
# toward the hatch row, where its stairs land (est.).
ENGINE_HOUSE = (-86.0, -66.0, 7.6)
CABINS = (-80.0, -68.0, 5.5)
FORE_HOUSE = (70.0, 82.0, 6.0)
PILOTHOUSE = (75.0, 81.0, 4.5)
OVERHANG = 1.4
BOAT_SIDE = ENGINE_HOUSE[2] + T
BRIDGE_SIDE = FORE_HOUSE[2] + T
# The engine room's plates, to its linings' middles.
ENGINE_ROOM = (-84.0, -64.0, 8.0)
# Every door onto an open deck is weathertight, over a sill a step high (est.).
SILL = 0.3
# Her hatch row (est.: the Fitzgerald's 21 hatches scaled to her, one fewer): twenty
# hatches down the spar deck's middle, each 2.7 m along her by 11.8 m across at 5.9 m
# centres, its coaming 0.7 m high round a steel cover — a jump up, a blocker to fight
# round —, the gaps between them a body's way across her.
HATCHES = 20
HATCH_PITCH = 5.9
HATCH_LENGTH = 2.7
HATCH_HALF = 5.9
COAMING = 0.7
HATCH_X = [round((k - (HATCHES - 1) * 0.5) * HATCH_PITCH, 4) for k in range(HATCHES)]

# The stairs (est.), each 1.1 m wide: two down from the mess to the engine room, through
# hatches in its floor, each climbing forward to its head; two up from the spar deck to
# the boat deck before the engine house, climbing aft; and two up from it to the bridge
# deck abaft the forecastle house, climbing forward.
ENGINE_STAIRS = [(-74.0, -68.0, -6.5, -5.4), (-74.0, -68.0, 5.4, 6.5)]
BOAT_STAIRS = [(ENGINE_HOUSE[1] + OVERHANG, ENGINE_HOUSE[1] + OVERHANG + 3.4, -6.6, -5.5),
               (ENGINE_HOUSE[1] + OVERHANG, ENGINE_HOUSE[1] + OVERHANG + 3.4, 5.5, 6.6)]
BRIDGE_STAIRS = [(FORE_HOUSE[0] - OVERHANG - 3.4, FORE_HOUSE[0] - OVERHANG, -5.0, -3.9),
                 (FORE_HOUSE[0] - OVERHANG - 3.4, FORE_HOUSE[0] - OVERHANG, 3.9, 5.0)]

# --- Platforms. The spar deck first: the main deck the lints walk from (D6); then the
# stern deck round the stairs down to the engine room, and her bow's decks narrowing to
# her stem.
SPAR = platform("spar_deck", "spar deck", MAIN[0], MAIN[1], -MAIN[2], MAIN[2])
STERN_DECK = holed("stern_deck", "spar deck", STERN[0], STERN[1], -STERN[2], STERN[2], 0.0, ENGINE_STAIRS)
BOW_DECK = platform("bow_deck", "spar deck", BOW[0], BOW[1], -BOW[2], BOW[2])
FOREDECK = platform("foredeck", "spar deck", FORE[0], FORE[1], -FORE[2], FORE[2])
ENGINE_FLOOR = platform("engine_floor", "engine room", ENGINE_ROOM[0], ENGINE_ROOM[1], -ENGINE_ROOM[2],
                        ENGINE_ROOM[2], LOWER)
BOAT_DECK = platform("boat_deck", "boat deck", ENGINE_HOUSE[0], ENGINE_HOUSE[1] + OVERHANG, -BOAT_SIDE,
                     BOAT_SIDE, UPPER)
BRIDGE_DECK = platform("bridge_deck", "bridge deck", FORE_HOUSE[0] - OVERHANG, FORE_HOUSE[1], -BRIDGE_SIDE,
                       BRIDGE_SIDE, UPPER)
pieces_after()

# --- Ramps.
for tag, (x0, x1, z0, z1) in zip(["port", "starboard"], ENGINE_STAIRS):
    ramp("engine_" + tag, x0, z0, x1 - x0, z1 - z0, LOWER, 0)
for tag, (x0, x1, z0, z1) in zip(["port", "starboard"], BOAT_STAIRS):
    ramp("boat_" + tag, x0, z0, x1 - x0, z1 - z0, UPPER, 0)
for tag, (x0, x1, z0, z1) in zip(["port", "starboard"], BRIDGE_STAIRS):
    ramp("bridge_" + tag, x0, z0, x1 - x0, z1 - z0, 0, UPPER)

# --- Blockers. Below the spar deck: the engine room's ends and linings, and her main
# engine abaft its stairs.
x0, x1, half = ENGINE_ROOM
wall_x("engine_aft", x0, -half, half, LOWER, 0)
wall_x("engine_forward", x1, -half, half, LOWER, 0)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z("engine_" + side, sign * half, x0, x1, LOWER, 0)
box("main_engine", -82.0, -77.0, -1.5, 1.5, LOWER, LOWER + 2.5)
# The hatch row's coamings, covers on.
for k, x in enumerate(HATCH_X):
    box("hatch_%d" % (k + 1), x - HATCH_LENGTH * 0.5, x + HATCH_LENGTH * 0.5, -HATCH_HALF, HATCH_HALF, 0,
        COAMING)
# The engine house: two doors forward onto the spar deck, one each side, one aft onto
# her fantail; inside, the galley aft and the mess forward, two doorways between them.
INNER_DOORS = [(-2.75, -1.65), (1.65, 2.75)]
x0, x1, half = ENGINE_HOUSE
wall_x_doors("engine_house_aft", x0, -half, half, [(-DOOR / 2, DOOR / 2)], 0, UPPER, SILL)
wall_x_doors("engine_house_forward", x1, -half, half, [(-4.0, -4.0 + DOOR), (4.0 - DOOR, 4.0)], 0, UPPER, SILL)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z_doors("engine_house_" + side, sign * half, x0, x1, [(-83.0, -83.0 + DOOR)], 0, UPPER, SILL)
wall_x_doors("galley_forward", -76.0, -half, half, INNER_DOORS, 0, UPPER)
# The officers' cabins on the boat deck, a door forward and one aft, roofed over; her
# funnel abaft them, over the engine room's after end.
x0, x1, half = CABINS
wall_x_doors("cabins_aft", x0, -half, half, [(-DOOR / 2, DOOR / 2)], UPPER, TOP, SILL)
wall_x_doors("cabins_forward", x1, -half, half, [(-DOOR / 2, DOOR / 2)], UPPER, TOP, SILL)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z("cabins_" + side, sign * half, x0, x1, UPPER, TOP)
box("cabins_roof", x0 - T, x1 + T, -half - T, half + T, TOP - T, TOP)
FUNNEL_AT = (-84.0, 0.0, 1.2, 11.0)  # x, z, radius, top
cylinder("funnel", FUNNEL_AT[0], FUNNEL_AT[1], FUNNEL_AT[2], UPPER, FUNNEL_AT[3])
# The forecastle house: two doors aft onto the spar deck and one each side; inside, the
# crew's cabins aft and the forward cabins, two doorways between them.
x0, x1, half = FORE_HOUSE
wall_x_doors("fore_house_aft", x0, -half, half, [(-2.7, -2.7 + DOOR), (2.7 - DOOR, 2.7)], 0, UPPER, SILL)
wall_x("fore_house_forward", x1, -half, half, 0, UPPER)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z_doors("fore_house_" + side, sign * half, x0, x1, [(72.0, 72.0 + DOOR)], 0, UPPER, SILL)
wall_x_doors("crew_cabins_forward", 76.0, -half, half, INNER_DOORS, 0, UPPER)
# The pilothouse on the bridge deck, a door either side and one aft, roofed over.
x0, x1, half = PILOTHOUSE
wall_x_doors("pilothouse_aft", x0, -half, half, [(-DOOR / 2, DOOR / 2)], UPPER, TOP, SILL)
wall_x("pilothouse_forward", x1, -half, half, UPPER, TOP)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z_doors("pilothouse_" + side, sign * half, x0, x1, [(79.0, 79.0 + DOOR)], UPPER, TOP, SILL)
box("pilothouse_roof", x0 - T, x1 + T, -half - T, half + T, TOP - T, TOP)

# --- Furniture: tables and their benches on her cabins' floors, after every other
# blocker so none of theirs moves. Each is drawn as its shape says (FurnitureDressing): a
# table 0.75 m tall, a jump up, a bench 0.45 along its long sides, a step and a half.
# Every one keeps clear a lane 1.5 m either side of a room's centre line, the ways in
# from its doorways, and 1.0 m in plan from its pendant and its seat; and 1.0 m off a
# wall's face, so a body standing on one keeps its head out of the berths slung along
# the walls (LinerBerths: 0.7 m out, from 1.85 m over the floor) (est.).
TABLE, BENCH = 0.75, 0.45
BENCH_DEPTH, BENCH_GAP = 0.35, 0.1


def mess_table(fid, x0, x1, half_in, half_out, floor, sign):
    """A table from x0 to x1, from half_in to half_out off her centre line on her side
    sign, and a bench along each of its long sides."""
    box("table_" + fid, x0, x1, *sorted((sign * half_in, sign * half_out)), floor, floor + TABLE)
    for tag, edge, away in [("in", half_in, -1), ("out", half_out, 1)]:
        near, far = edge + away * BENCH_GAP, edge + away * (BENCH_GAP + BENCH_DEPTH)
        box("bench_%s_%s" % (fid, tag), x0, x1, *sorted((sign * near, sign * far)), floor, floor + BENCH)


# The officers' cabins: two tables either side of the way between their doors, clear of
# the seat and the pendant over their middle.
for k, (x0, x1) in enumerate([(-78.8, -76.6), (-71.4, -69.2)]):
    for side, sign in [("port", -1), ("starboard", 1)]:
        mess_table("officers_%s_%d" % (side, k + 1), x0, x1, 2.0, 2.9, UPPER, sign)
# The crew's cabins and the forward cabins: a table either side, outboard of the ways in
# from their doorways — the crew's past their side doors' way across them.
for rid, x0, x1, half_in, half_out in [("crew", 73.6, 74.9, 3.6, 4.4), ("forward", 77.4, 80.6, 3.6, 4.4)]:
    for side, sign in [("port", -1), ("starboard", 1)]:
        mess_table("%s_%s" % (rid, side), x0, x1, half_in, half_out, 0, sign)
# The mess: two tables either side of its middle, between the lane down it and the
# stairs down to the engine room, clear of the seat and of the pendants over them.
for k, (x0, x1) in enumerate([(-74.6, -72.4), (-69.6, -67.4)]):
    for side, sign in [("port", -1), ("starboard", 1)]:
        mess_table("mess_%s_%d" % (side, k + 1), x0, x1, 2.2, 3.0, 0, sign)

# --- Railings: the spar deck's edges all round — down both her sides, the steps where it
# narrows, her fantail and her stem —, the boat deck's and the bridge deck's, open where
# their stairs land, and three sides of each hole down to the engine room, the fourth its
# stair's head.
for tag, sign in [("port", -1), ("starboard", 1)]:
    railing("side_" + tag, SPAR, (MAIN[0], sign * MAIN[2]), (MAIN[1], sign * MAIN[2]))
    railing("stern_step_" + tag, SPAR, (MAIN[0], sign * STERN[2]), (MAIN[0], sign * MAIN[2]))
    railing("bow_step_" + tag, SPAR, (MAIN[1], sign * BOW[2]), (MAIN[1], sign * MAIN[2]))
    railing("stern_" + tag, STERN_DECK, (STERN[0], sign * STERN[2]), (STERN[1], sign * STERN[2]))
    railing("bow_" + tag, BOW_DECK, (BOW[0], sign * BOW[2]), (BOW[1], sign * BOW[2]))
    railing("foredeck_step_" + tag, BOW_DECK, (BOW[1], sign * FORE[2]), (BOW[1], sign * BOW[2]))
    railing("foredeck_" + tag, FOREDECK, (FORE[0], sign * FORE[2]), (FORE[1], sign * FORE[2]))
    railing("boat_deck_" + tag, BOAT_DECK, (ENGINE_HOUSE[0], sign * BOAT_SIDE),
            (ENGINE_HOUSE[1] + OVERHANG, sign * BOAT_SIDE))
    railing("bridge_deck_" + tag, BRIDGE_DECK, (FORE_HOUSE[0] - OVERHANG, sign * BRIDGE_SIDE),
            (FORE_HOUSE[1], sign * BRIDGE_SIDE))
railing("fantail", STERN_DECK, (STERN[0], -STERN[2]), (STERN[0], STERN[2]))
railing("stem", FOREDECK, (FORE[1], -FORE[2]), (FORE[1], FORE[2]))
railing("boat_deck_aft", BOAT_DECK, (ENGINE_HOUSE[0], -BOAT_SIDE), (ENGINE_HOUSE[0], BOAT_SIDE))
railing("bridge_deck_forward", BRIDGE_DECK, (FORE_HOUSE[1], -BRIDGE_SIDE), (FORE_HOUSE[1], BRIDGE_SIDE))

def open_where(rid, plat, x, half, stairs):
    """A railing across a deck's end at x from -half to half, open over each stair's
    head."""
    ends = [-half] + [v for s in stairs for v in s[2:]] + [half]
    for k, (a, b) in enumerate(zip(ends[::2], ends[1::2])):
        railing("%s_%d" % (rid, k + 1), plat, (x, a), (x, b))

open_where("boat_deck_forward", BOAT_DECK, ENGINE_HOUSE[1] + OVERHANG, BOAT_SIDE, BOAT_STAIRS)
open_where("bridge_deck_aft", BRIDGE_DECK, FORE_HOUSE[0] - OVERHANG, BRIDGE_SIDE, BRIDGE_STAIRS)

def hatch_rails(rid, plat, hole, *open_sides):
    x0, x1, z0, z1 = hole
    sides = {"x0": ((x0, z0), (x0, z1)), "x1": ((x1, z0), (x1, z1)),
             "z0": ((x0, z0), (x1, z0)), "z1": ((x0, z1), (x1, z1))}
    for tag, (a, b) in sides.items():
        if tag not in open_sides:
            railing("%s_%s" % (rid, tag), plat, a, b)

for tag, hole in zip(["port", "starboard"], ENGINE_STAIRS):
    hatch_rails("engine_hatch_" + tag, STERN_DECK, hole, "x1")

# --- Boarding ladders, two down each side of the spar deck: a swimmer climbs back aboard
# there (SH5).
for tag, sign in [("port", -1), ("starboard", 1)]:
    for place, x in [("aft", -40.0), ("forward", 40.0)]:
        ladder("%s_%s" % (place, tag), SPAR, (x, sign * MAIN[2]), (x + 1.0, sign * MAIN[2]))

# --- Two crates of stores left on the spar deck before her engine house, against her
# sides.
crate("stores_port", -60.0, 0, -9.5)
crate("stores_starboard", -60.0, 0, 9.5)

# --- Rooms, to the middle of their walls.
room("engine_room", "engine room", ENGINE_ROOM[0], ENGINE_ROOM[1], -ENGINE_ROOM[2], ENGINE_ROOM[2], LOWER)
room("galley", "galley", ENGINE_HOUSE[0], -76.0, -ENGINE_HOUSE[2], ENGINE_HOUSE[2], 0)
room("mess", "mess", -76.0, ENGINE_HOUSE[1], -ENGINE_HOUSE[2], ENGINE_HOUSE[2], 0)
room("officers_cabins", "officers' cabins", CABINS[0], CABINS[1], -CABINS[2], CABINS[2], UPPER)
room("crew_cabins", "crew cabins", FORE_HOUSE[0], 76.0, -FORE_HOUSE[2], FORE_HOUSE[2], 0)
room("forward_cabins", "forward cabins", 76.0, FORE_HOUSE[1], -FORE_HOUSE[2], FORE_HOUSE[2], 0)
room("pilothouse", "pilothouse", PILOTHOUSE[0], PILOTHOUSE[1], -PILOTHOUSE[2], PILOTHOUSE[2], UPPER)

# Twelve seats: six down the spar deck — four by her rails, two in gaps of the hatch row
# —, one each in the galley and the mess, one on the boat deck and one in the officers'
# cabins, one on the bridge deck and one in the pilothouse: two islands 150 m apart.
GAP = (HATCH_X[4] + HATCH_X[5]) * 0.5
spawns = [
    (-45.0, 0, 8.5), (-15.0, 0, -8.5), (15.0, 0, 8.5), (45.0, 0, -8.5), (GAP, 0, 0.0), (-GAP, 0, 0.0),
    (-81.0, 0, 0.0), (-71.0, 0, 0.0), (-66.0, UPPER, 0.0), (-74.0, UPPER, 0.0),
    (71.0, UPPER, 0.0), (78.0, UPPER, 0.0),
]
# The seats a match on her takes (est.): twelve at most, from one as every ship.
SEATS = (1, 12)

def arr(script, ids):
    return "Array[ExtResource(\"%s\")]([%s])" % (script, ", ".join('SubResource("%s")' % i for i in ids))

# --- The structure (§5b.2), est. throughout: her hull, lofted here from her
# dimensions; her cells, walls, openings and mass. `make ship-check` floats her on it,
# level, at her waterline, and sinks her on her sure hit.
FREEBOARD = 2.5
WATERLINE = -FREEBOARD
KEEL = -10.5  # 8 m of draught, loaded with ore: a laker's freeboard is small
X_AFT, X_FORE = -90.0, 90.0  # her transom, her stem's head at the spar deck
# Her lines (est.): a laker's box — a superellipse of power BILGE from her spar deck down
# to her keel, a flat floor and a hard bilge, and a long parallel body —, its waterlines
# closing on the stem past FORE_SHOULDER (at her spar deck, at her keel), as one minus the
# square of the way there: a blunt bow; and on the transom past AFT_SHOULDER, to
# TRANSOM_SHARE of her breadth (over the transom's lower edge, at her keel). A stem
# raked STEM_RAKE aft per metre down from its head to STEM_KNEE, rounding into her keel at
# X_FOOT; a transom whose lower edge stands at Y_TRANSOM, the run under it sweeping up
# from her keel at X_POST.
BILGE = 8.0
FORE_SHOULDER = (74.0, 64.0)
AFT_SHOULDER = -70.0
TRANSOM_SHARE = (0.9, 0.3)
STEM_RAKE = 0.3
STEM_KNEE = -6.0
X_FOOT = 84.0
X_POST = -78.0
Y_TRANSOM = -1.5
# Her inside (est.): the double bottom's top, the tank top, 1.5 m over her keel; the
# ballast tanks' inner skins, the hold's linings, LINING out from her centreline; the
# hold from the engine room's forward bulkhead to the bulkhead before her fore tank,
# parted into three by two screen bulkheads SCREEN either side of amidships, each in a
# gap of the hatch row.
DB_TOP = KEEL + 1.5
LINING = 8.0
SCREEN = round((HATCH_X[5] + HATCH_X[6]) * 0.5, 4) * -1
HOLD_ENDS = (ENGINE_ROOM[1], 64.0)
FORE_TANK = 72.0  # her collision bulkhead, the fore peak's after face

def clamp(v, a, b):
    return min(max(v, a), b)

def lerp(a, b, t):
    return a + (b - a) * t

def stem_x(y):
    line = X_FORE - (0.0 - y) * STEM_RAKE
    if y >= STEM_KNEE:
        return line
    knee = X_FORE - (0.0 - STEM_KNEE) * STEM_RAKE
    share = (STEM_KNEE - y) / (STEM_KNEE - KEEL)
    return X_FOOT + (knee - X_FOOT) * math.sqrt(max(1.0 - share * share, 0.0))

def bottom(x):
    """Her lowest point at x: her keel, the run swept up to her transom, or her stem."""
    if x > X_FOOT:
        low, high = KEEL, 0.0
        for _ in range(48):
            middle = (low + high) * 0.5
            if stem_x(middle) < x:
                low = middle
            else:
                high = middle
        return high
    if x < X_POST:
        share = (X_POST - x) / (X_POST - X_AFT)
        return Y_TRANSOM + (KEEL - Y_TRANSOM) * math.sqrt(max(1.0 - share * share, 0.0))
    return KEEL

def breadth(x, y):
    """Her half breadth at (x, y), up to the sheer."""
    if x < X_AFT or y < bottom(x) - 1e-9 or x >= stem_x(y):
        return 0.0
    depth = clamp(y / KEEL, 0.0, 1.0)
    base = BEAM * (1.0 - depth ** BILGE) ** (1.0 / BILGE)
    shoulder = lerp(FORE_SHOULDER[1], FORE_SHOULDER[0], clamp((y - KEEL) / -KEEL, 0.0, 1.0))
    t = clamp((x - shoulder) / (stem_x(y) - shoulder), 0.0, 1.0)
    fore = 1.0 - t * t
    s = clamp((AFT_SHOULDER - x) / (AFT_SHOULDER - X_AFT), 0.0, 1.0)
    rise = clamp((y - KEEL) / (Y_TRANSOM - KEEL), 0.0, 1.0)
    share = lerp(TRANSOM_SHARE[1], TRANSOM_SHARE[0], rise)
    aft = 1.0 - (1.0 - share) * s * s
    return base * fore * aft

def sheer(x):
    """Her shell's top at x: the spar deck, flush her whole length."""
    return 0.0

# The houses on her decks, enclosed: (x0, x1, half breadth, foot, top) — to their walls'
# outer faces.
HOUSES = [(h[0] - T, h[1] + T, h[2] + T, foot, roof)
          for h, foot, roof in [(ENGINE_HOUSE, 0.0, UPPER), (CABINS, UPPER, TOP), (FORE_HOUSE, 0.0, UPPER),
                                (PILOTHOUSE, UPPER, TOP)]]
SIDE_POINTS = 14
# Sections stand for no more than SECTION_MAX of hull, between her ends and every
# cell's, so no cell splits a section: twice the ferry's, for a hull three times as long
# whose middle is one section over again.
SECTION_MAX = 4.0
SECTION_BREAKS = sorted({X_AFT, ENGINE_ROOM[0], -SCREEN, SCREEN, X_FORE, FORE_TANK} | set(HOLD_ENDS)
                        | {h[i] for h in HOUSES for i in (0, 1)})
OUTLINE_TOLERANCE = 0.01


def section_outline(x):
    """The outline of everything enclosed at x, counter-clockwise in (z, y): from her
    keel up her starboard side, over her houses, down her port side."""
    low, top = bottom(x), sheer(x)
    side = []
    for i in range(SIDE_POINTS + 1):
        y = top - (top - low) * math.sin(math.pi * 0.5 * i / SIDE_POINTS)
        side.append((breadth(x, y), y))
    side.reverse()
    points = [(0.0, low)] + side
    houses_up, houses_down = [], []
    for x0, x1, half, foot, roof in HOUSES:
        if x0 < x < x1:
            houses_up += [(half, foot), (half, roof)]
            houses_down = [(-half, roof), (-half, foot)] + houses_down
    points += houses_up + houses_down + [(-z, y) for z, y in reversed(side)]
    outline = []
    for z, y in points:
        point = (round(z, 4) + 0.0, round(y, 4) + 0.0)
        if not outline or point != outline[-1]:
            outline.append(point)
    if outline[-1] == outline[0]:
        outline.pop()
    return simplified(outline, OUTLINE_TOLERANCE)

def simplified(outline, tolerance):
    """Douglas–Peucker on a closed outline, as the steamer's generator does it."""
    def far(a, b, chain):
        best, at = -1.0, None
        dz, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dz, dy)
        for k, p in enumerate(chain):
            if length > 0.0:
                off = abs(dz * (p[1] - a[1]) - dy * (p[0] - a[0])) / length
            else:
                off = math.hypot(p[0] - a[0], p[1] - a[1])
            if off > best:
                best, at = off, k
        return best, at

    def keep(a, b, chain):
        if not chain:
            return []
        off, at = far(a, b, chain)
        if off <= tolerance:
            return []
        return keep(a, chain[at], chain[:at]) + [chain[at]] + keep(chain[at], b, chain[at + 1:])

    start = outline[0]
    split = max(range(len(outline)), key=lambda k: math.hypot(outline[k][0] - start[0],
                                                             outline[k][1] - start[1]))
    first, second = outline[1:split], outline[split + 1:]
    return ([start] + keep(start, outline[split], first) + [outline[split]]
            + keep(outline[split], start, second))

sections = []  # (x, length, outline)
for a, b in zip(SECTION_BREAKS, SECTION_BREAKS[1:]):
    count = math.ceil((b - a) / SECTION_MAX - 1e-9)
    for k in range(count):
        length = (b - a) / count
        x = round(a + length * (k + 0.5), 4)
        sections.append((x, round(length, 4), section_outline(x)))

# Every deck in her hull stands inside it, at its corners: one under her spar deck clear
# of her shell, the walls along its edges with it; one on her spar deck, her shell's
# top no wider than her.
CLEARANCE = 0.05
for x0, x1, z0, z1, h in plat_geo:
    for x in (x0 + 0.01, x1 - 0.01):
        if h <= sheer(x):
            room_for = max(-z0, z1) + (CLEARANCE + T if h < 0 else 0.0)
            assert breadth(x, h) >= room_for - 1e-9, ("platform outside her", x, h)

def f32(v):
    return struct.unpack("f", struct.pack("f", v))[0]

def joins():
    """Every stair's two ends meet a deck at its height, as Surfaces.joins finds them:
    each end's edge, its corners and its middle, inside a platform's Rect2 in single
    precision, where a rectangle's far side is its corner plus its size."""
    def end_of(a, b):
        return f32(f32(a) + f32(b - a))
    for x0, x1, z0, z1, axis, start, end in ramp_geo:
        for which, height in [(0, start), (1, end)]:
            if axis == 0:
                x = f32(x0) if which == 0 else end_of(x0, x1)
                points = [(x, f32(z0)), (x, end_of(z0, z1))]
            else:
                z = f32(z0) if which == 0 else end_of(z0, z1)
                points = [(f32(x0), z), (end_of(x0, x1), z)]
            points.append(tuple(f32((a + b) * 0.5) for a, b in zip(*points)))
            holds = lambda p, q: (f32(p[0]) <= q[0] <= end_of(p[0], p[1])
                                  and f32(p[2]) <= q[1] <= end_of(p[2], p[3]))
            for q in points:
                assert any(abs(f32(h) - f32(height)) < 1e-6 and holds(p, q) for *p, h in plat_geo), \
                    "stair %s's end %d at %s meets no deck" % ((x0, x1, z0, z1), which, q)

joins()

def clip(polygon, axis, value, keep_below):
    """Sutherland–Hodgman: the part of polygon (z, y) on one side of the line where
    coordinate axis (0 z, 1 y) is value."""
    kept = []
    for i, p in enumerate(polygon):
        q = polygon[(i + 1) % len(polygon)]
        fp = (p[axis] - value) * (1 if keep_below else -1)
        fq = (q[axis] - value) * (1 if keep_below else -1)
        if fp <= 0:
            kept.append(p)
        if (fp <= 0) != (fq <= 0):
            t = fp / (fp - fq)
            kept.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return kept

def area_and_centre(polygon):
    twice = mz = my = 0.0
    for i, p in enumerate(polygon):
        q = polygon[(i + 1) % len(polygon)]
        cross = p[0] * q[1] - q[0] * p[1]
        twice += cross
        mz += (p[0] + q[0]) * cross
        my += (p[1] + q[1]) * cross
    if twice <= 0:
        return 0.0, 0.0, 0.0
    return twice * 0.5, mz / (3 * twice), my / (3 * twice)

def hull_in(x0, x1, y0, y1, z0, z1):
    """How much of the box the sections enclose, in m³."""
    volume = 0.0
    for x, length, outline in sections:
        overlap = min(x1, x + length * 0.5) - max(x0, x - length * 0.5)
        if overlap <= 0:
            continue
        part = outline
        for axis, value, below in [(0, z1, True), (0, z0, False), (1, y1, True), (1, y0, False)]:
            if part:
                part = clip(part, axis, value, below)
        if len(part) >= 3:
            volume += overlap * area_and_centre(part)[0]
    return volume

# Cells (§5b.2): (name, x0, x1, y0, y1, z0, z1, kind, permeability or None for its
# kind's). Under the spar deck, between four watertight bulkheads, the spar deck their
# top: her aft peak; the engine room, her shell its sides; the hold, in three between its
# screen bulkheads, each over its own double-bottom tank and between two wing tanks
# outboard of its linings — her ballast tanks, empty, she being loaded; her fore tank; her
# fore peak. Ore fills the hold's bottom, CARGO's permeability. Over the spar deck her
# four houses.
HOLDS = [("3", HOLD_ENDS[0], -SCREEN), ("2", -SCREEN, SCREEN), ("1", SCREEN, HOLD_ENDS[1])]
CELLS = [("aft_peak", X_AFT, ENGINE_ROOM[0], KEEL, 0, -BEAM, BEAM, "VOID", None),
         ("engine_room", ENGINE_ROOM[0], ENGINE_ROOM[1], KEEL, 0, -BEAM, BEAM, "MACHINERY", None)]
for hold, x0, x1 in HOLDS:
    CELLS += [("wing_%s_p" % hold, x0, x1, KEEL, 0, -BEAM, -LINING, "VOID", None),
              ("hold_" + hold, x0, x1, DB_TOP, 0, -LINING, LINING, "CARGO", None),
              ("wing_%s_s" % hold, x0, x1, KEEL, 0, LINING, BEAM, "VOID", None),
              ("bottom_" + hold, x0, x1, KEEL, DB_TOP, -LINING, LINING, "VOID", None)]
CELLS += [
    ("fore_tank", HOLD_ENDS[1], FORE_TANK, KEEL, 0, -BEAM, BEAM, "VOID", None),
    ("fore_peak", FORE_TANK, X_FORE, KEEL, 0, -BEAM, BEAM, "VOID", None),
    ("engine_house", HOUSES[0][0], HOUSES[0][1], 0, UPPER, -HOUSES[0][2], HOUSES[0][2], "ACCOMMODATION", None),
    ("cabins", HOUSES[1][0], HOUSES[1][1], UPPER, TOP, -HOUSES[1][2], HOUSES[1][2], "ACCOMMODATION", None),
    ("forecastle_house", HOUSES[2][0], HOUSES[2][1], 0, UPPER, -HOUSES[2][2], HOUSES[2][2], "ACCOMMODATION",
     None),
    ("pilothouse", HOUSES[3][0], HOUSES[3][1], UPPER, TOP, -HOUSES[3][2], HOUSES[3][2], "ACCOMMODATION", None),
]
KINDS = ["ACCOMMODATION", "MACHINERY", "CARGO", "STORES", "VOID", "BUNKER", "OPEN_WELL"]
# Air leaks out through rivets, seams and vents: 10⁻³ m² per 1 000 m³ (est.).
AIR_LEAK = 1e-6

def cell_at(x, y, z):
    for c in CELLS:
        if c[1] < x < c[2] and c[3] < y < c[4] and c[5] < z < c[6]:
            return c[0]
    return None

def cell_box(name):
    return next(c for c in CELLS if c[0] == name)[1:7]

# Her four watertight bulkheads across her, to her spar deck — the bulkhead deck:
# (name, x), each to her spar deck and spanning its breadth there, which covers it; and
# the hold's linings along her, leaky (est.): (name, z, from x, to x, top, collapse
# head). A head across a wall is the water's over the foot of each panel of it
# (SinkFailures): est., a
# bulkhead is built for the head from her keel to her spar deck and gives way at 2.25×
# it, starting to leak by WALL_LEAK at five sixths of that; a lining — the wing tanks'
# inner skin, leaking through its LEAK — gives way at 1.5× it, so a wing flooded to the
# sea holds it; a wall the hit ended beside at half. The screen bulkheads are no walls:
# the hold's water runs through them (below).
BUILT_FOR = 0.0 - KEEL
BULKHEADS = [("bulkhead_aft_peak", ENGINE_ROOM[0]), ("bulkhead_engine", ENGINE_ROOM[1]),
             ("bulkhead_hold", HOLD_ENDS[1]), ("bulkhead_collision", FORE_TANK)]
WALL_LEAK = 0.002
LININGS = [("hold_%s_lining_%s" % (hold, tag), sign * LINING, x0, x1, 0.0, 1.5 * BUILT_FOR)
           for hold, x0, x1 in HOLDS for tag, sign in [("p", -1), ("s", 1)]]
WING_LEAK = 0.002

def parted(axis, at, y0, y1, along0, along1):
    """The cells with a face on the plane where axis (0 x, 2 z) is at, overlapping the
    wall from y0 to y1 and from along0 to along1 along its other axis."""
    found = []
    for c in CELLS:
        lo, hi = (c[1], c[2]) if axis == 0 else (c[5], c[6])
        olo, ohi = (c[5], c[6]) if axis == 0 else (c[1], c[2])
        touches = abs(lo - at) < 1e-6 or abs(hi - at) < 1e-6
        if touches and c[3] < y1 and c[4] > y0 and olo < along1 and ohi > along0:
            found.append(c[0])
    return found

walls = []  # (name, axis, at, span, bottom, top, collapse, cells)
for name, x in BULKHEADS:
    half = round(min(breadth(x, 0.0), next(d[2] for d in [STERN, MAIN, BOW, FORE] if d[0] <= x <= d[1])), 4)
    walls.append((name, "ACROSS", x, (-half, half), KEEL, 0.0, 2.25 * BUILT_FOR, parted(0, x, KEEL, 0.0, -half, half)))
for name, z, x0, x1, top, collapse in LININGS:
    walls.append((name, "ALONG", z, (x0, x1), DB_TOP, top, collapse, parted(2, z, DB_TOP, top, x0, x1)))

# Openings: (name, kind, joins, centre, size, fields). size is the rectangle's extent
# along x, y and z, zero across the axis it is flat on.
SEA, SKY = "sea", "sky"
openings = []

def opening(name, kind, a, b, centre, size, **fields):
    openings.append((name, kind, [a or SKY, b or SKY], centre, size, fields))

# Doorways: open, as Q15 built them, from over their sills. A doorway onto an open deck
# opens onto the sky. None pierces a watertight wall: every one is in a house.
for axis, at, d0, d1, foot, sill in doorways:
    middle = (d0 + d1) * 0.5
    probes = [at - T - 0.01, at + T + 0.01]
    beside = [c for c in CELLS for p in probes
              if (c[1] < p < c[2] and c[5] < middle < c[6] if axis == 0 else c[1] < middle < c[2] and c[5] < p < c[6])]
    over_sill = foot + sill
    levels = sorted({over_sill, foot + LINTEL} | {y for c in beside for y in (c[3], c[4]) if over_sill < y < foot + LINTEL})
    for y0, y1 in zip(levels, levels[1:]):
        y = (y0 + y1) * 0.5
        a, b = [cell_at(p, y, middle) if axis == 0 else cell_at(middle, y, p) for p in probes]
        if a == b:
            continue
        if a is None:
            a, b = b, None
        face = at
        if b is None:
            inside = cell_box(a)
            lo, hi = (inside[0], inside[1]) if axis == 0 else (inside[4], inside[5])
            face = lo if abs(lo - at) < abs(hi - at) else hi
        centre = (face, y, middle) if axis == 0 else (middle, y, face)
        size = (0, y1 - y0, d1 - d0) if axis == 0 else (d1 - d0, y1 - y0, 0)
        tag = "door_%s_%s" % (a, b or SKY)
        opening("%s_%d" % (tag, sum(1 for o in openings if o[0].startswith(tag))), "DOOR", a, b,
                centre, size, starts="OPEN")

# Her hatch covers, each over the hold under it: steel, clamped down round its coaming,
# left unclamped one time in a hundred (est.: the Fitzgerald's were a suspect), their
# gaskets weeping 0.02 m² under 0.3 m of water and each cover giving way under 2.5 m.
HATCH_LEAK = 0.02
for k, x in enumerate(HATCH_X):
    opening("hatch_%d" % (k + 1), "HATCH", cell_at(x, -1.0, 0.0), SKY, (x, 0.0, 0.0),
            (HATCH_LENGTH, 0, 2 * HATCH_HALF), starts="SHUT", flip_chance=0.01, leak_head=0.3,
            collapse_head=2.5, leak_area=HATCH_LEAK)
# The screen bulkheads between the holds, steel screens that keep the ore apart and not
# the water (est.): 0.15 m² of gaps across each, from the tank top to the spar deck.
SCREEN_GAPS = 0.15
for (aft, _a0, x), (fore, _f0, _f1) in zip(HOLDS, HOLDS[1:]):
    opening("screen_%s_%s" % (aft, fore), "LEAK", "hold_" + aft, "hold_" + fore, (x, DB_TOP * 0.5, 0.0),
            (0, -DB_TOP, 2 * LINING), area=SCREEN_GAPS, starts="OPEN")
# The hatches down from the mess to the engine room, as the ferry's: battened and dogged
# watertight, a body going down one opening it as a doorway's door is opened — shut to
# the water, it never weeps nor gives way.
def hatch(name, under, over, hole, deck):
    x0, x1, z0, z1 = hole
    opening(name, "HATCH", under, over, ((x0 + x1) * 0.5, deck, (z0 + z1) * 0.5), (x1 - x0, 0, z1 - z0),
            starts="SHUT")

for tag, hole in zip(["p", "s"], ENGINE_STAIRS):
    hatch("hatch_engine_room_" + tag, "engine_room", "engine_house", hole, 0.0)
# The engine room's air, drawn down through two ventilators on the spar deck before her
# engine house, under the boat deck's overhang, always open (0.2 m² each, est.).
for tag, z in [("p", -9.0), ("s", 9.0)]:
    opening("vent_engine_room_" + tag, "VENT", "engine_room", SKY, (ENGINE_ROOM[1] - 1.0, 0.0, z),
            (0.6, 0, 0.6), area=0.2, starts="OPEN")
# Each wing's leak through its lining, and the air pipe each ballast tank breathes
# through, a 100 mm pipe (est., as the ferry's): up to the spar deck from a wing, up into
# the hold from a double bottom.
AIR_PIPE = 0.008
for hold, x0, x1 in HOLDS:
    b = cell_box("hold_" + hold)
    for tag in ["p", "s"]:
        wing = "wing_%s_%s" % (hold, tag)
        w = cell_box(wing)
        z = b[4] if w[4] < b[4] else b[5]
        opening("leak_" + wing, "LEAK", wing, "hold_" + hold, ((b[0] + b[1]) * 0.5, (b[2] + b[3]) * 0.5, z),
                (b[1] - b[0], b[3] - b[2], 0), area=WING_LEAK, starts="OPEN")
        opening("pipe_" + wing, "VENT", wing, SKY, (x0 + 1.0, 0.0, (w[4] + w[5]) * 0.5), (0.09, 0, 0.09),
                area=AIR_PIPE, starts="OPEN")
    opening("pipe_bottom_" + hold, "VENT", "bottom_" + hold, "hold_" + hold, (x0 + 1.0, DB_TOP, 0.0),
            (0.09, 0, 0.09), area=AIR_PIPE, starts="OPEN")

# Glass in every wall of a house of hers that faces the sky over her shell's top, where
# the art sets it (ShipFittings._windows, with its numbers, placed as the trawler's
# generator places them). Each joins the cell holding its room to the sky. Shut, a window
# breaks under 2 m of water (est., as the steamer's).
WINDOW_HEIGHT, WINDOW_SPACING, WINDOW_MARGIN = 1.45, 1.3, 0.4
WINDOW, NARROW_WINDOW, WINDOW_FRAME = (0.55, 0.6), (0.38, 0.6), 0.06
WALL_MAX, FULL_WALL, INSIDE, OPEN_ROOM_HEIGHT, PROBE, SLIVER = 0.3, 1.9, 0.02, 2.5, 0.15, 0.01
SALOON_AREA = 15.0  # a room on her top deck smaller than this is a helm (RoomDressing)
OUTWARD = [(0, -1), (1, 0), (0, 1), (-1, 0)]  # per side of a room, (x, z) out of it
SIDE_TAGS = ["p", "f", "s", "a"]

def ceiling(floor, x, z):
    over = [h for x0, x1, z0, z1, h in plat_geo if h > floor + SLIVER and x0 <= x <= x1 and z0 <= z <= z1]
    return min(over) if over else floor + OPEN_ROOM_HEIGHT

def outdoors(x, y, z):
    for x0, x1, z0, z1, floor, _name in room_geo:
        if y < floor - INSIDE or not (x0 - INSIDE <= x <= x1 + INSIDE and z0 - INSIDE <= z <= z1 + INSIDE):
            continue
        if y <= ceiling(floor, x, z) + INSIDE:
            return False
    return True

def under_a_ramp(x, z, height):
    for x0, x1, z0, z1, axis, start, end in ramp_geo:
        if x0 <= x <= x1 and z0 <= z <= z1:
            along, first, length = (x, x0, x1 - x0) if axis == 0 else (z, z0, z1 - z0)
            if lerp(start, end, min(max((along - first) / length, 0.0), 1.0)) > height - 0.5:
                return True
    return False

def on_side(house, side, distance, depth):
    line = [house[2], house[1], house[3], house[0]][side]
    x, z = (distance, line) if side % 2 == 0 else (line, distance)
    return x - OUTWARD[side][0] * depth, z - OUTWARD[side][1] * depth

def wall_runs(house):
    """The full walls on house's floor along its sides, as ShipSpace.wall_runs: per run
    (side, from, to, half thickness)."""
    x0, x1, z0, z1, floor, _name = house
    runs = []
    for side in range(4):
        along_x = side % 2 == 0
        line = [z0, x1, z1, x0][side]
        low, high = (x0, x1) if along_x else (z0, z1)
        pieces, half = [], 0.0
        for bx0, bx1, bz0, bz1, foot, top, is_box in block_geo:
            if not is_box or min(bx1 - bx0, bz1 - bz0) > WALL_MAX:
                continue
            if abs(foot - floor) >= 0.05 or top - foot <= FULL_WALL:
                continue
            if not (bx0 - INSIDE < x1 and bx1 + INSIDE > x0 and bz0 - INSIDE < z1 and bz1 + INSIDE > z0):
                continue
            thick = (bz0, bz1) if along_x else (bx0, bx1)
            if thick[1] - thick[0] > WALL_MAX or not thick[0] - SLIVER <= line <= thick[1] + SLIVER:
                continue
            half = (thick[1] - thick[0]) * 0.5
            span = (bx0, bx1) if along_x else (bz0, bz1)
            pieces.append((max(span[0], low), min(span[1], high)))
        merged = []
        for piece in sorted(pieces):
            if piece[1] - piece[0] < SLIVER:
                continue
            if merged and piece[0] <= merged[-1][1] + SLIVER:
                merged[-1] = (merged[-1][0], max(merged[-1][1], piece[1]))
            else:
                merged.append(piece)
        for a, b in merged:
            a, b = max(a, low + half), min(b, high - half)
            if b - a > SLIVER:
                runs.append((side, a, b, half))
    return runs

def clear_of_stairs(house, run, height):
    side, a, b, half = run
    found, start = [], None
    count = max(1, math.ceil((b - a) / 0.05))
    for i in range(count + 1):
        along = lerp(a, b, i / count)
        x, z = on_side(house, side, along, -(half + 0.1))
        clear = i < count and not under_a_ramp(x, z, height + 0.5)
        if clear and start is None:
            start = along
        elif not clear and start is not None:
            found.append((start, along))
            start = None
    return found

FURNITURE_HEIGHT = 1.2  # a box on a floor no taller is furniture, not machinery (ShipSpace)

def machinery_in(house):
    x0, x1, z0, z1, floor, _name = house
    return any(is_box and min(bx1 - bx0, bz1 - bz0) > WALL_MAX and abs(foot - floor) < 0.05
               and top - foot > FURNITURE_HEIGHT
               and x0 <= (bx0 + bx1) * 0.5 <= x1 and z0 <= (bz0 + bz1) * 0.5 <= z1
               for bx0, bx1, bz0, bz1, foot, top, is_box in block_geo)

def windows():
    """Her windows, as ShipFittings._windows places glass: the walls of her rooms that
    face the sky over her shell's top. Returns the rooms whose cell it could not name."""
    unnamed = []
    top_floor = max(r[4] for r in room_geo)
    for house in room_geo:
        x0, x1, z0, z1, floor, name = house
        helm = not machinery_in(house) and floor >= top_floor and (x1 - x0) * (z1 - z0) < SALOON_AREA
        height = floor + WINDOW_HEIGHT
        for run in wall_runs(house):
            side, a, b, half = run
            stretches = clear_of_stairs(house, run, height) if helm else [(a, b)]
            spots = []
            for s0, s1 in stretches:
                first, last = s0 + WINDOW_MARGIN, s1 - WINDOW_MARGIN
                if last >= first:
                    count = math.floor((last - first) / WINDOW_SPACING) + 1
                    spots += [((first + last) * 0.5 + (i - (count - 1) * 0.5) * WINDOW_SPACING, WINDOW)
                              for i in range(count)]
                elif len(stretches) > 1 and s1 - s0 >= NARROW_WINDOW[0] + WINDOW_FRAME * 2 + 0.04:
                    spots.append(((s0 + s1) * 0.5, NARROW_WINDOW))
            for spot, size in spots:
                bx, bz = on_side(house, side, spot, -(half + PROBE))
                if not outdoors(bx, height, bz) or under_a_ramp(bx, bz, height):
                    continue
                # Under her shell's top, or onto a cell of hers: no sky beyond it.
                if height < sheer(bx) or cell_at(bx, height, bz) is not None:
                    continue
                x, z = on_side(house, side, spot, 0)
                away = OUTWARD[side]
                holder = cell_at(x - away[0] * (half + 0.01), height, z - away[1] * (half + 0.01))
                if holder is None:
                    unnamed.append(name)
                    continue
                box_of = cell_box(holder)
                if side % 2 == 0:
                    centre = (x, height, box_of[4] if away[1] < 0 else box_of[5])
                    extent = (size[0], size[1], 0)
                else:
                    centre = (box_of[0] if away[0] < 0 else box_of[1], height, z)
                    extent = (0, size[1], size[0])
                tag = "window_%s_%s" % (holder, SIDE_TAGS[side])
                number = sum(1 for o in openings if o[0].startswith(tag)) + 1
                opening("%s%d" % (tag, number), "WINDOW", holder, SKY, centre, extent, starts="SHUT",
                        collapse_head=2.0)
    return unnamed

# A window whose room no cell holds is left out, and said (none is, today).
for skipped in sorted(set(windows())):
    print("no cell holds %s: its windows left out" % skipped, file=sys.stderr)

# Mass (est.): where her weight sits — her hull to the spar deck, her hatch covers, her
# two houses, her engine and her fuel, her anchors, her crew and stores. Her ore is what
# the generator settles: as heavy as she must be to float at her waterline, and where
# along her it puts her weight over her lift, so she floats there level — loaded evenly
# down her holds, as a laker loads, its pile 4 m deep on the tank top.
with open("data/physics/sea.tres") as sea_file:
    SEA_DENSITY = float(re.search(r"^sea_density = (\S+)$", sea_file.read(), re.M).group(1))
displaced = along = across = lift_y = 0.0
waterplane = 0.0
for x, length, outline in sections:
    under = clip(outline, 1, WATERLINE, True)
    if len(under) >= 3:
        area, z, y = area_and_centre(under)
        displaced += area * length
        along += area * length * x
        across += area * length * z
        lift_y += area * length * y
    waterplane += 2.0 / 3.0 * breadth(x, WATERLINE) ** 3 * length
ROW = (HATCH_X[0] - HATCH_LENGTH * 0.5, HATCH_X[-1] + HATCH_LENGTH * 0.5)
MASS = [  # (name, kg, centre, (from x, to x))
    ("hull steel", 6200e3, (0.0, -5.4, 0.0), (X_AFT, X_FORE)),
    ("hatch covers and coamings", 500e3, (0.0, 0.4, 0.0), ROW),
    ("engine house and cabins", 700e3, (-76.0, 2.4, 0.0), (ENGINE_HOUSE[0], ENGINE_HOUSE[1])),
    ("forecastle house and pilothouse", 250e3, (76.0, 2.2, 0.0), (FORE_HOUSE[0], FORE_HOUSE[1])),
    ("funnel", 40e3, (FUNNEL_AT[0], 6.9, 0.0), (FUNNEL_AT[0] - FUNNEL_AT[2], FUNNEL_AT[0] + FUNNEL_AT[2])),
    ("main engine and boilers", 600e3, (-78.0, -6.5, 0.0), (ENGINE_ROOM[0], -72.0)),
    ("fuel and fresh water", 700e3, (-74.0, -9.2, 0.0), ENGINE_ROOM[:2]),
    ("anchors and windlass", 60e3, (84.0, 0.5, 0.0), (80.0, 88.0)),
    ("crew and stores", 50e3, (-76.0, 1.4, 0.0), (ENGINE_HOUSE[0], ENGINE_HOUSE[1])),
]
ORE_Y = DB_TOP + 2.0
ORE_REACH = 58.0  # either side of its centre
weight = displaced * SEA_DENSITY
ore = weight - sum(m[1] for m in MASS)
ore_x = (weight * along / displaced - sum(m[1] * m[2][0] for m in MASS)) / ore
ore_z = (weight * across / displaced - sum(m[1] * m[2][2] for m in MASS)) / ore
assert ore > 0, "she is heavier than she floats"
assert cell_at(ore_x, ORE_Y, ore_z), "her solved ore must lie in one of her cells"
assert HOLD_ENDS[0] <= ore_x - ORE_REACH and ore_x + ORE_REACH <= HOLD_ENDS[1], "her ore must lie in her holds"
MASS.append(("ore", round(ore, 1), (round(ore_x, 4), ORE_Y, round(ore_z, 4)),
             (round(ore_x - ORE_REACH, 4), round(ore_x + ORE_REACH, 4))))
gravity_y = sum(m[1] * m[2][1] for m in MASS) / weight
GM = lift_y / displaced + waterplane / displaced - gravity_y
# How her mass turns, the water moving with her, and how her motions die away (est.:
# roll 0.4 of her beam, pitch 0.25 of her length; the steamer's added mass and damping).
MOTION = [("roll_radius", 8.4), ("pitch_radius", 45.0), ("added_mass", 1.0),
          ("heave_damping", 0.5), ("roll_damping", 0.08), ("pitch_damping", 0.5)]
# Her two lifeboats either side of her boat deck and two liferafts either side of her
# bridge deck, useless on the high side past a list of 20° (§5b.2).
LIFEBOATS = [("lifeboat_port", -1, -76.0, 20.0), ("lifeboat_starboard", 1, -76.0, 20.0),
             ("liferaft_port_forward", -1, 78.0, 20.0), ("liferaft_starboard_forward", 1, 78.0, 20.0)]
# What the sinking fails (§5b.1, est.): her funnel, 8.2 m over the boat deck, stayed to
# 30° of list and 15° of trim, down in 2 s; her generator in her engine room, drowned by
# 0.8 m of water over its foot, stopped past 25° of list or 12° of trim (SOLAS-based) and
# running again 3° back within both, its emergency power lighting both her islands for
# 30 minutes — the piece a break leaves without it goes dark; a bilge pump in her engine
# room, 0.05 m³/s while it runs.
FUNNEL = dict(name="funnel", base=(FUNNEL_AT[0], UPPER, FUNNEL_AT[1]), height=FUNNEL_AT[3] - UPPER,
              radius=FUNNEL_AT[2], list=30.0, trim=15.0, fall=2.0)
GENERATOR = dict(name="generator", cell="engine_room", base=(-70.0, LOWER, -3.0), drowns=0.8,
                 list=25.0, trim=12.0, recovers=3.0, minutes=30.0,
                 emergency=["engine_house", "cabins", "forecastle_house", "pilothouse"])
PUMPS = [("bilge_pump", "engine_room", 0.05)]
# The bending her hull carries (est.), in N·m, and where along her she can break —
# (name, x, the share of that strength the spot keeps): a laker's girder is shallow for
# her length, and weakest along her hatch row, where twenty hatches cut her deck plating
# away; the screen bulkheads stand in two of its gaps. Est., measured on her hits: her ore
# alone sags her amidships by about 0.39 of this strength, 0.6 of what the midships spot
# keeps; her middle hold flooded faster than its screens pass the water on sags her by
# about 0.86, past it, and she parts there (test_freighter_flooding's hold).
STRENGTH = (2.0e9, 1.8e9)
WEAK_SPOTS = [("hatch_row_aft", -SCREEN, 0.8), ("hatch_row_midships", 0.0, 0.65), ("hatch_row_forward", SCREEN, 0.8)]
# Where along her and up her shell an iceberg's gash can be at all (est.): clear of her
# stem and her transom, from 0.2 m under her spar deck down to 0.2 m over her keel.
HIT_ZONE_X = (X_AFT + 0.5, X_FORE - 0.5)
HIT_ZONE_Y = (KEEL + 0.2, -0.2)
# The must-sink rule's last rung (§5b.1, est.): a 70 m gash down her starboard side
# through her two after holds' wings into them, 3 m under her waterline, 100 mm as one
# even slit and biting 3 m in, every door shut. `make ship-check` proves she founders on
# it within the bake's cap.
SURE_HIT = [("start_x", -60), ("length", 70), ("depth_start", 3), ("depth_end", 3),
            ("width", 0.1), ("bite", 3.0)]

def vec3(v):
    return "Vector3(%s, %s, %s)" % tuple(num(c) for c in v)

def names(items):
    return "Array[StringName]([%s])" % ", ".join('&"%s"' % i for i in items)

section_ids = []
for i, (x, length, outline) in enumerate(sections):
    flat = ", ".join("%s, %s" % (num(z), num(y)) for z, y in outline)
    section_ids.append(sub("Section_%d" % i, "10_section", [
        ("x", num(x)), ("length", num(length)), ("outline", "PackedVector2Array(%s)" % flat)]))
cell_ids = []
for name, x0, x1, y0, y1, z0, z1, kind, permeability in CELLS:
    inside = hull_in(x0, x1, y0, y1, z0, z1)
    box_volume = (x1 - x0) * (y1 - y0) * (z1 - z0)
    inner = [r[5] for r in room_geo if cell_at((r[0] + r[1]) * 0.5, r[4] + 0.1, (r[2] + r[3]) * 0.5) == name]
    f = [("name", '&"%s"' % name), ("low", vec3((x0, y0, z0))), ("high", vec3((x1, y1, z1)))]
    if KINDS.index(kind) != 0:
        f.append(("kind", str(KINDS.index(kind))))
    if permeability is not None:
        f.append(("permeability", num(permeability)))
    f.append(("shape", num(min(inside / box_volume, 1.0))))
    if inner:
        f.append(("rooms", names(inner)))
    # Three figures of it: num()'s four places would round a small cell's leak to none.
    f.append(("leak_area", ("%.8f" % float("%.3g" % (inside * AIR_LEAK))).rstrip("0")))
    cell_ids.append(sub("Cell_" + name, "11_cell", f))
wall_ids = []
for name, axis, at, span, bottom_y, top, collapse, parts in walls:
    f = [("name", '&"%s"' % name)]
    if axis == "ALONG":
        f.append(("axis", "1"))
    f += [("at", num(at)), ("span", "Vector2(%s, %s)" % (num(span[0]), num(span[1]))),
          ("bottom", num(bottom_y)), ("top", num(top)), ("collapse_head", num(collapse))]
    if axis == "ACROSS":
        f += [("leak_head", num(collapse / 1.5 * 1.25)), ("leak_area", num(WALL_LEAK))]
    f.append(("cells", names(parts)))
    wall_ids.append(sub("Wall_" + name, "12_wall", f))
OPENING_KINDS = ["DOOR", "WATERTIGHT_DOOR", "PORTHOLE", "WINDOW", "STAIRWELL", "HATCH", "OVER_WALL",
                 "FLOOR_GAPS", "LEAK", "VENT", "FREEING_PORT", "OPEN"]
opening_ids = []
for name, kind, joins, centre, size, fields in openings:
    f = [("name", '&"%s"' % name)]
    if OPENING_KINDS.index(kind) != 0:
        f.append(("kind", str(OPENING_KINDS.index(kind))))
    f += [("joins", names(joins)), ("centre", vec3(centre)), ("size", vec3(size))]
    if fields.get("area"):
        f.append(("area", num(fields["area"])))
    if fields.get("starts", "OPEN") == "SHUT":
        f.append(("starts", "1"))
    if fields.get("flip_chance"):
        f.append(("flip_chance", num(fields["flip_chance"])))
    if fields.get("shuts_at_hit"):
        f.append(("shuts_at_hit", "true"))
    for key in ["shut_time", "leak_head", "collapse_head", "leak_area"]:
        if fields.get(key):
            f.append((key, num(fields[key])))
    opening_ids.append(sub("Opening_" + name, "13_opening", f))
mass_ids = []
for name, kg, centre, reach in MASS:
    mass_ids.append(sub("Mass_" + name.replace(" ", "_"), "14_mass", [
        ("name", '&"%s"' % name), ("mass", num(kg)), ("centre", vec3(centre)),
        ("along", "Vector2(%s, %s)" % (num(reach[0]), num(reach[1])))]))
fitting_ids = []
for name, side, x, limit in LIFEBOATS:
    fitting_ids.append(sub("Fitting_" + name, "16_fitting", [
        ("name", '&"%s"' % name), ("side", str(side)), ("x", num(x)),
        ("list_limit_deg", num(limit))]))
fitting_ids.append(sub("Fitting_" + FUNNEL["name"], "16_fitting", [
    ("kind", "1"), ("name", '&"%s"' % FUNNEL["name"]), ("x", num(FUNNEL["base"][0])),
    ("list_limit_deg", num(FUNNEL["list"])), ("trim_limit_deg", num(FUNNEL["trim"])),
    ("base", vec3(FUNNEL["base"])), ("height", num(FUNNEL["height"])),
    ("radius", num(FUNNEL["radius"])), ("fall_time", num(FUNNEL["fall"]))]))
fitting_ids.append(sub("Fitting_" + GENERATOR["name"], "16_fitting", [
    ("kind", "2"), ("name", '&"%s"' % GENERATOR["name"]), ("x", num(GENERATOR["base"][0])),
    ("list_limit_deg", num(GENERATOR["list"])), ("trim_limit_deg", num(GENERATOR["trim"])),
    ("base", vec3(GENERATOR["base"])), ("drowns_at", num(GENERATOR["drowns"])),
    ("recovers_deg", num(GENERATOR["recovers"])),
    ("emergency_minutes", num(GENERATOR["minutes"])),
    ("emergency_cells", names(GENERATOR["emergency"])), ("cell", '&"%s"' % GENERATOR["cell"])]))
for name, cell, rate in PUMPS:
    fitting_ids.append(sub("Fitting_" + name, "16_fitting", [
        ("kind", "3"), ("name", '&"%s"' % name), ("cell", '&"%s"' % cell), ("rate", num(rate))]))
weak_ids = [sub("Weak_" + name, "18_weak", [("name", '&"%s"' % name), ("x", num(x)), ("share", num(share))])
            for name, x, share in WEAK_SPOTS]
sub("Structure", "9_structure", [
    ("waterline_y", num(WATERLINE)), ("keel_y", num(KEEL)),
    ("sections", arr("10_section", section_ids)), ("cells", arr("11_cell", cell_ids)),
    ("walls", arr("12_wall", wall_ids)), ("openings", arr("13_opening", opening_ids)),
    ("mass", arr("14_mass", mass_ids))] + [(k, num(v)) for k, v in MOTION] + [
    ("fittings", arr("16_fitting", fitting_ids)),
    ("strength", 'SubResource("%s")' % sub("Strength", "17_strength", [
        ("hog", num(STRENGTH[0])), ("sag", num(STRENGTH[1])), ("weak", arr("18_weak", weak_ids))])),
    ("hit_zone_x", "Vector2(%s, %s)" % (num(HIT_ZONE_X[0]), num(HIT_ZONE_X[1]))),
    ("hit_zone_y", "Vector2(%s, %s)" % (num(HIT_ZONE_Y[0]), num(HIT_ZONE_Y[1]))),
    ("sure_hit", 'SubResource("%s")' % sub("Sure_hit", "15_hit", [(k, num(v)) for k, v in SURE_HIT]))])

head = """[gd_resource type="Resource" script_class="ShipLayout" format=3]

[ext_resource type="Script" path="res://core/ship_platform.gd" id="1_plat"]
[ext_resource type="Script" path="res://core/ship_ramp.gd" id="2_ramp"]
[ext_resource type="Script" path="res://core/ship_blocker.gd" id="3_block"]
[ext_resource type="Script" path="res://core/ship_railing.gd" id="4_rail"]
[ext_resource type="Script" path="res://core/ship_layout.gd" id="5_layout"]
[ext_resource type="Script" path="res://core/ship_room.gd" id="6_room"]
[ext_resource type="Script" path="res://core/ship_ladder.gd" id="7_ladder"]
[ext_resource type="Script" path="res://core/ship_prop.gd" id="8_prop"]
[ext_resource type="Script" path="res://core/sinking/ship_structure.gd" id="9_structure"]
[ext_resource type="Script" path="res://core/sinking/hull_section.gd" id="10_section"]
[ext_resource type="Script" path="res://core/sinking/flood_cell.gd" id="11_cell"]
[ext_resource type="Script" path="res://core/sinking/ship_wall.gd" id="12_wall"]
[ext_resource type="Script" path="res://core/sinking/ship_opening.gd" id="13_opening"]
[ext_resource type="Script" path="res://core/sinking/mass_item.gd" id="14_mass"]
[ext_resource type="Script" path="res://core/sinking/iceberg_hit.gd" id="15_hit"]
[ext_resource type="Script" path="res://core/sinking/ship_fitting.gd" id="16_fitting"]
[ext_resource type="Script" path="res://core/sinking/girder_strength.gd" id="17_strength"]
[ext_resource type="Script" path="res://core/sinking/weak_spot.gd" id="18_weak"]
"""
res = ["[resource]", 'script = ExtResource("5_layout")', "freeboard = " + num(FREEBOARD),
       "deck_thickness = " + num(2 * T),
       "platforms = " + arr("1_plat", platforms),
       "ramps = " + arr("2_ramp", ramps),
       "blockers = " + arr("3_block", blockers),
       "railings = " + arr("4_rail", railings),
       "ladders = " + arr("7_ladder", ladders),
       "spawns = Array[Vector3]([%s])" % ", ".join("Vector3(%s, %s, %s)" % tuple(num(c) for c in s) for s in spawns),
       "min_seats = %d" % SEATS[0], "max_seats = %d" % SEATS[1],
       "props = " + arr("8_prop", props),
       "rooms = " + arr("6_room", rooms),
       "dressed = false",
       'structure = SubResource("Structure")']
with open(out, "w") as f:
    f.write(head + "\n" + "\n\n".join(subs) + "\n\n" + "\n".join(res) + "\n")
print(len(platforms), "platforms", len(ramps), "ramps", len(blockers), "blockers", len(railings), "railings", len(ladders), "ladders", len(props), "props", len(rooms), "rooms")
print(len(sections), "sections", len(CELLS), "cells", len(walls), "walls", len(openings), "openings", len(MASS),
      "masses: %.1f t, ore %.1f t at x %.3f z %.3f, GM %.2f m" % (weight / 1000, ore / 1000, ore_x,
                                                                 ore_z, GM))
