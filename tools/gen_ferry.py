#!/usr/bin/env python3
"""Writes the ferry's layout and structure, data/ships/ferry.tres (SH35).

The layout and structure are generated: change her here, then `make ship SHIP=ferry`.
`make ship-gen-check` (part of `make verify`) fails when the committed .tres is not what
this writes, so a hand edit to the .tres is caught. The sim reads only the .tres (D6).

A 60 m ro-ro ferry, bigger than the steamer and the trawler and far smaller than the
Titanic: her car deck one undivided cell running her length just above her waterline,
a bow door and a stern door at its ends; under it her engine room and her crew's
quarters, joined by a watertight door, between her peaks and her tanks; over it her
passenger deck — a saloon, a galley and a lounge in a house with walkways down both its
sides and an open deck aft — and her bridge deck, the wheelhouse forward and her funnel
aft. Her signature is the fast capsize an open car deck gives: water loose on a deck
that wide rolls her over in minutes. Her sections are lofted here from a few numbers, as
the trawler's (tools/gen_trawler.py), and the dressed art draws her hull from them
(SectionHull; ShipLayout.dressed). Every number is est. until a playtest or the census
says otherwise.

Ship-local metres: x toward the bow, z to starboard, y up, origin on the car deck — her
main deck — amidships.

Usage: tools/gen_ferry.py <out.tres>
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
rail_geo = []  # per railing, (platform, from, to)
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
        rail_geo.append((on, ends[k], ends[k + 1]))

def ladder(lid, plat, a, b):
    f = []
    plat = holding(a, b, plat)
    if plat != 0:
        f.append(("platform", str(plat)))
    f.append(("from", "Vector2(%s, %s)" % (num(a[0]), num(a[1]))))
    f.append(("to", "Vector2(%s, %s)" % (num(b[0]), num(b[1]))))
    ladders.append(sub("Ladder_" + lid, "7_ladder", f))

# A crate of freight left on the car deck: the steamer's cargo crate (SH10), the same
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

# Her heights (est.): the lower deck — the engine room's plates and the crew quarters'
# floor — 2.6 m under the car deck; the passenger deck 4.8 m over it, a car deck's
# headroom; the bridge deck — the house's roof — 2.8 m over that, and the wheelhouse's
# top 2.6 m over the bridge deck. 7 m is her half beam; the car deck's sides stand 6.4 m
# out, its bow 4.6 m, and the lower deck's linings 5.4 m.
LOWER = -2.6
PASS = 4.8
BRIDGE = 7.6
TOP = 10.2
BEAM = 7.0
CAR_SIDE = 6.4
CAR_BOW = 4.6
LINING = 5.4
# The house on the passenger deck, to the middle of its walls: x from its after face to
# its forward face, and its half breadth; the walkways down its sides run out to the
# deck's edge. The wheelhouse on the bridge deck, the same.
HOUSE = (-18.0, 18.0, 5.0)
WHEEL = (11.0, 17.0, 4.0)
PASS_SIDE = 6.4
BRIDGE_SIDE = HOUSE[2] + T
BRIDGE_AFT = -21.6
# Every door onto an open deck is weathertight, over a sill a step high (est.).
SILL = 0.3

# The stairs (est.), each 1.1 m wide: two down from the car deck to the engine room and
# two to the crew quarters, through hatches in it, each climbing forward to its head;
# two up from the car deck to the passenger deck, inside the house; two up from the
# open deck aft to the bridge deck; and the wheelhouse's own stair up from the lounge.
ENGINE_STAIRS = [(-19.0, -15.9, -3.6, -2.5), (-19.0, -15.9, 2.5, 3.6)]
QUARTERS_STAIRS = [(1.0, 4.1, -3.6, -2.5), (1.0, 4.1, 2.5, 3.6)]
CAR_STAIRS = [(-6.0, -0.5, -4.7, -3.6), (-6.0, -0.5, 3.6, 4.7)]
AFT_STAIRS = [(-25.0, BRIDGE_AFT, -4.6, -3.5), (-25.0, BRIDGE_AFT, 3.5, 4.6)]
WHEEL_STAIR = (12.0, 15.4, -0.55, 0.55)

# --- Platforms. The car deck first: the main deck the lints walk from (D6), round the
# hatches down to the engine room and the crew quarters; its bow narrowing to the bow
# door.
CAR = holed("car_deck", "car deck", -29.5, 18.0, -CAR_SIDE, CAR_SIDE, 0.0, ENGINE_STAIRS + QUARTERS_STAIRS)
CAR_BOW_DECK = platform("car_deck_bow", "car deck", 18.0, 22.0, -CAR_BOW, CAR_BOW)
ENGINE_FLOOR = platform("engine_floor", "lower deck", -24.0, -10.0, -LINING, LINING, LOWER)
QUARTERS_FLOOR = platform("quarters_floor", "lower deck", -10.0, 6.0, -LINING, LINING, LOWER)
# The passenger deck, her shell's top: round the car deck's stairs up into the house, its
# foredeck narrowing toward her stem.
PAX = holed("passenger_deck", "passenger deck", -29.5, 20.0, -PASS_SIDE, PASS_SIDE, PASS, CAR_STAIRS)
FORE = platform("foredeck", "passenger deck", 20.0, 25.0, -4.0, 4.0, PASS)
# The bridge deck, the house's roof carried aft over the open deck: round the
# wheelhouse's stair.
BRIDGE_DECK = holed("bridge_deck", "bridge deck", BRIDGE_AFT, HOUSE[1], -BRIDGE_SIDE, BRIDGE_SIDE, BRIDGE,
                    [WHEEL_STAIR])
pieces_after()

# --- Ramps.
for tag, (x0, x1, z0, z1) in zip(["port", "starboard"], ENGINE_STAIRS):
    ramp("engine_" + tag, x0, z0, x1 - x0, z1 - z0, LOWER, 0)
for tag, (x0, x1, z0, z1) in zip(["port", "starboard"], QUARTERS_STAIRS):
    ramp("quarters_" + tag, x0, z0, x1 - x0, z1 - z0, LOWER, 0)
for tag, (x0, x1, z0, z1) in zip(["port", "starboard"], CAR_STAIRS):
    ramp("car_" + tag, x0, z0, x1 - x0, z1 - z0, 0, PASS)
for tag, (x0, x1, z0, z1) in zip(["port", "starboard"], AFT_STAIRS):
    ramp("aft_" + tag, x0, z0, x1 - x0, z1 - z0, PASS, BRIDGE)
ramp("wheelhouse_stair", WHEEL_STAIR[0], WHEEL_STAIR[2], WHEEL_STAIR[1] - WHEEL_STAIR[0],
     WHEEL_STAIR[3] - WHEEL_STAIR[2], PASS, BRIDGE)

# --- Blockers. Below the car deck: the engine room's and the crew quarters' sides and
# ends, the watertight door between them, and her two main engines aft of the engine
# room's stairs.
wall_x("engine_aft", -24.0, -LINING, LINING, LOWER, 0)
wall_x_doors("bulkhead_engine", -10.0, -LINING, LINING, [(-DOOR / 2, DOOR / 2)], LOWER, 0)
wall_x("quarters_forward", 6.0, -LINING, LINING, LOWER, 0)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z("engine_" + side, sign * LINING, -24.0, -10.0, LOWER, 0)
    wall_z("quarters_" + side, sign * LINING, -10.0, 6.0, LOWER, 0)
    box("main_engine_" + side, -23.0, -20.4, *sorted((sign * 0.7, sign * 2.1)), LOWER, LOWER + 1.8)
# The car deck: her stern door's inner face, her sides' linings, the shoulders where it
# narrows into her bow and the bow door's inner face.
wall_x("stern_door", -29.5, -CAR_SIDE, CAR_SIDE, 0, PASS)
wall_x("bow_door", 22.0, -CAR_BOW, CAR_BOW, 0, PASS)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z("car_" + side, sign * CAR_SIDE, -29.5, 18.0, 0, PASS)
    wall_z("car_bow_" + side, sign * CAR_BOW, 18.0, 22.0, 0, PASS)
    wall_x("car_shoulder_" + side, 18.0, *sorted((sign * CAR_BOW, sign * CAR_SIDE)), 0, PASS)
# The house on the passenger deck: two doors aft onto the open deck, one each side into
# the saloon and the lounge off the walkways; inside, the saloon aft, the galley and
# the lounge forward, two doorways between each.
x0, x1, half = HOUSE
wall_x_doors("house_aft", x0, -half, half, [(-3.3, -2.2), (2.2, 3.3)], PASS, BRIDGE, SILL)
wall_x("house_forward", x1, -half, half, PASS, BRIDGE)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z_doors("house_" + side, sign * half, x0, x1, [(-12.55, -12.55 + DOOR), (12.0, 12.0 + DOOR)], PASS, BRIDGE,
                 SILL)
INNER_DOORS = [(-2.75, -1.65), (1.65, 2.75)]
wall_x_doors("saloon_forward", 2.0, -half, half, INNER_DOORS, PASS, BRIDGE)
wall_x_doors("galley_forward", 8.0, -half, half, INNER_DOORS, PASS, BRIDGE)
# The wheelhouse on the bridge deck, a door either side and one aft, roofed over; her
# funnel abaft it, over the engine room's after end.
x0, x1, half = WHEEL
wall_x_doors("wheelhouse_aft", x0, -half, half, [(1.8, 1.8 + DOOR)], BRIDGE, TOP, SILL)
wall_x("wheelhouse_forward", x1, -half, half, BRIDGE, TOP)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z_doors("wheelhouse_" + side, sign * half, x0, x1, [(15.6, 15.6 + DOOR)], BRIDGE, TOP, SILL)
box("wheelhouse_roof", x0 - T, x1 + T, -half - T, half + T, TOP - T, TOP)
FUNNEL_AT = (-8.0, 0.0, 1.0, 13.0)  # x, z, radius, top
cylinder("funnel", FUNNEL_AT[0], FUNNEL_AT[1], FUNNEL_AT[2], BRIDGE, FUNNEL_AT[3])
# Her deck furniture (est.), after every other blocker so none of theirs moves, each drawn
# as its shape says (DeckFurniture): the engine room's skylight on the bridge deck abaft
# the funnel, a hop up; and seat lockers, a step and a half up — against the wheelhouse's
# after wall short of its door, against the house's after wall between its doors, and a
# row of two across the open deck aft between its seats' starts.
box("skylight_engine_room", -14.0, -11.0, -1.0, 1.0, BRIDGE, BRIDGE + 0.8)
SEAT_LOCKER = (0.5, 0.45)  # deep, and tall
box("seat_locker_wheelhouse", WHEEL[0] - T - SEAT_LOCKER[0], WHEEL[0] - T, -3.4, 1.2, BRIDGE,
    BRIDGE + SEAT_LOCKER[1])
box("seat_locker_house", HOUSE[0] - T - SEAT_LOCKER[0], HOUSE[0] - T, -1.6, 1.6, PASS, PASS + SEAT_LOCKER[1])
for tag, (z0, z1) in [("port", (-2.6, -0.2)), ("starboard", (0.2, 2.6))]:
    box("seat_locker_aft_" + tag, -24.5, -24.5 + SEAT_LOCKER[0], z0, z1, PASS, PASS + SEAT_LOCKER[1])
# Her saloon's furniture, after her deck furniture so none of it moves, each drawn as its
# shape says (FurnitureDressing): two booths either side — a table 0.75 m tall, a bench
# 0.45 along each of its long sides — outboard of the way between its aft and forward
# doors, between the ways in from its aft doors and its side doors and between those and
# the stairs up through its floor, 0.5 m off the walls and clear of the seat and of the
# pendants over its middle (est.).
TABLE, BENCH = 0.75, 0.45
for k, (x0, x1) in enumerate([(-17.0, -14.0), (-10.3, -7.3)]):
    for tag, sign in [("port", -1), ("starboard", 1)]:
        booth = "saloon_%s_%d" % (tag, k + 1)
        box("table_" + booth, x0, x1, *sorted((sign * 3.0, sign * 3.6)), PASS, PASS + TABLE)
        for side, (near, far) in [("in", (2.55, 2.9)), ("out", (3.7, 4.05))]:
            box("bench_%s_%s" % (booth, side), x0, x1, *sorted((sign * near, sign * far)), PASS, PASS + BENCH)

# --- Railings: the passenger deck's edges all round — its open deck aft, the walkways,
# the foredeck —, the bridge deck's, open where the stairs from the open deck land, and
# three sides of every stair hole, the fourth its stair's head.
railing("transom", PAX, (-29.5, -PASS_SIDE), (-29.5, PASS_SIDE))
for tag, sign in [("port", -1), ("starboard", 1)]:
    railing("walkway_" + tag, PAX, (-29.5, sign * PASS_SIDE), (20.0, sign * PASS_SIDE))
    railing("foredeck_step_" + tag, PAX, (20.0, sign * 4.0), (20.0, sign * PASS_SIDE))
    railing("foredeck_" + tag, FORE, (20.0, sign * 4.0), (25.0, sign * 4.0))
    railing("bridge_deck_" + tag, BRIDGE_DECK, (BRIDGE_AFT, sign * BRIDGE_SIDE), (HOUSE[1], sign * BRIDGE_SIDE))
railing("foredeck_fwd", FORE, (25.0, -4.0), (25.0, 4.0))
railing("bridge_deck_fwd", BRIDGE_DECK, (HOUSE[1], -BRIDGE_SIDE), (HOUSE[1], BRIDGE_SIDE))
railing("bridge_deck_aft_port", BRIDGE_DECK, (BRIDGE_AFT, -BRIDGE_SIDE), (BRIDGE_AFT, AFT_STAIRS[0][2]))
railing("bridge_deck_aft_middle", BRIDGE_DECK, (BRIDGE_AFT, AFT_STAIRS[0][3]), (BRIDGE_AFT, AFT_STAIRS[1][2]))
railing("bridge_deck_aft_starboard", BRIDGE_DECK, (BRIDGE_AFT, AFT_STAIRS[1][3]), (BRIDGE_AFT, BRIDGE_SIDE))

def hatch_rails(rid, plat, hole, *open_sides):
    x0, x1, z0, z1 = hole
    sides = {"x0": ((x0, z0), (x0, z1)), "x1": ((x1, z0), (x1, z1)),
             "z0": ((x0, z0), (x1, z0)), "z1": ((x0, z1), (x1, z1))}
    for tag, (a, b) in sides.items():
        if tag not in open_sides:
            railing("%s_%s" % (rid, tag), plat, a, b)

for tag, hole in zip(["port", "starboard"], ENGINE_STAIRS):
    hatch_rails("engine_hatch_" + tag, CAR, hole, "x1")
for tag, hole in zip(["port", "starboard"], QUARTERS_STAIRS):
    hatch_rails("quarters_hatch_" + tag, CAR, hole, "x1")
for tag, hole in zip(["port", "starboard"], CAR_STAIRS):
    hatch_rails("car_stair_" + tag, PAX, hole, "x1")
hatch_rails("wheelhouse_stair", BRIDGE_DECK, WHEEL_STAIR, "x1")

# --- Boarding ladders, one down each side of the open deck aft: a swimmer climbs back
# aboard there (SH5).
ladder("port", PAX, (-27.0, -PASS_SIDE), (-26.0, -PASS_SIDE))
ladder("starboard", PAX, (-27.0, PASS_SIDE), (-26.0, PASS_SIDE))

# --- Four crates of freight left on the car deck, against her sides.
for tag, x in [("aft", -22.0), ("forward", 10.0)]:
    crate(tag + "_port", x, 0, -5.5)
    crate(tag + "_starboard", x, 0, 5.5)

# --- Rooms, to the middle of their walls.
room("engine_room", "engine room", -24.0, -10.0, -LINING, LINING, LOWER)
room("crew_quarters", "crew quarters", -10.0, 6.0, -LINING, LINING, LOWER)
room("car_deck", "car deck", -29.5, 18.0, -CAR_SIDE, CAR_SIDE, 0)
room("saloon", "saloon", HOUSE[0], 2.0, -HOUSE[2], HOUSE[2], PASS)
room("galley", "galley", 2.0, 8.0, -HOUSE[2], HOUSE[2], PASS)
room("lounge", "lounge", 8.0, HOUSE[1], -HOUSE[2], HOUSE[2], PASS)
room("wheelhouse", "wheelhouse", WHEEL[0], WHEEL[1], -WHEEL[2], WHEEL[2], BRIDGE)

# Ten seats: four on the car deck, two on the open deck aft, one each in the saloon and
# the lounge, two on the bridge deck.
spawns = [
    (-24.0, 0, 0.0), (-12.0, 0, -2.0), (-12.0, 0, 2.0), (8.0, 0, 0.0),
    (-27.0, PASS, -2.0), (-27.0, PASS, 2.0), (-10.0, PASS, 0.0), (10.0, PASS, -3.0),
    (-14.0, BRIDGE, -2.0), (0.0, BRIDGE, 2.0),
]
# The seats a match on her takes (est.): the plan's 6–10 at most, from one as every ship.
SEATS = (1, 10)

def arr(script, ids):
    return "Array[ExtResource(\"%s\")]([%s])" % (script, ", ".join('SubResource("%s")' % i for i in ids))

# --- The structure (§5b.2), est. throughout: her hull, lofted here from her
# dimensions; her cells, walls, openings and mass. `make ship-check` floats her on it,
# level, at her waterline, and sinks her on her sure hit.
FREEBOARD = 1.4
WATERLINE = -FREEBOARD
KEEL = -4.2  # 2.8 m of draught
X_AFT, X_FORE = -30.0, 30.0  # her transom, her stem's head at the passenger deck
# Her lines (est.): a boxy midship section — a superellipse of power BILGE from her car
# deck down to her keel, a ferry's flat floor and hard bilge — its waterlines closing on
# the stem past FORE_SHOULDER (at her car deck and over, at her keel), as one minus the
# square of the way there, and on the transom past AFT_SHOULDER, to TRANSOM_SHARE of her
# breadth (over the transom's lower edge, at her keel): a broad, flat stern. A raked stem
# STEM_RAKE aft per metre down from its head to STEM_KNEE, rounding into her keel at
# X_FOOT; a transom whose lower edge stands at Y_TRANSOM, the run under it sweeping up
# from her keel at X_POST.
BILGE = 4.0
FORE_SHOULDER = (16.0, 8.0)
AFT_SHOULDER = -18.0
TRANSOM_SHARE = (0.95, 0.5)
STEM_RAKE = 0.6
STEM_KNEE = -2.5
X_FOOT = 23.0
X_POST = -23.0
Y_TRANSOM = -1.0

def clamp(v, a, b):
    return min(max(v, a), b)

def lerp(a, b, t):
    return a + (b - a) * t

def stem_x(y):
    line = X_FORE - (PASS - y) * STEM_RAKE
    if y >= STEM_KNEE:
        return line
    knee = X_FORE - (PASS - STEM_KNEE) * STEM_RAKE
    share = (STEM_KNEE - y) / (STEM_KNEE - KEEL)
    return X_FOOT + (knee - X_FOOT) * math.sqrt(max(1.0 - share * share, 0.0))

def bottom(x):
    """Her lowest point at x: her keel, the run swept up to her transom, or her stem."""
    if x > X_FOOT:
        low, high = KEEL, PASS
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
    """Her shell's top at x: the passenger deck, the car deck closed in under it her
    whole length."""
    return PASS

# The houses on her decks, enclosed: (x0, x1, half breadth, foot, top) — to their walls'
# outer faces.
HOUSES = [(HOUSE[0] - T, HOUSE[1] + T, HOUSE[2] + T, PASS, BRIDGE),
          (WHEEL[0] - T, WHEEL[1] + T, WHEEL[2] + T, BRIDGE, TOP)]
SIDE_POINTS = 14
# Sections stand for no more than SECTION_MAX of hull, between her ends and every
# cell's, so no cell splits a section.
SECTION_MAX = 2.0
SECTION_BREAKS = sorted({X_AFT, -24.0, -10.0, 6.0, 20.0, X_FORE} | {h[i] for h in HOUSES for i in (0, 1)})
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

# Every deck in her hull stands inside it, at its corners: one under her car deck clear
# of her shell, the walls along its edges with it; one on her car deck or her shell's
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
# kind's). Under the car deck, five compartments between four watertight bulkheads, the
# car deck their top: her aft peak over her steering gear; the engine room and the crew
# quarters, each over a bilge the length of it; her tanks; her fore peak. The middle
# three each between two wing tanks outboard of their linings (the plan's lengthwise
# wall in a wide cell, R23): a gash biting less deep than a wing is wide floods that side
# alone, and she lists. Over them the car deck, one cell from her stern door to her bow
# door and from side to side — no wall stands across it, so water on it runs to
# whichever side she lists to (the open car deck's capsize: Herald of Free Enterprise,
# Estonia) —, empty of vehicles; and her two houses.
WINGED = [("engine", "engine_room", -24, -10, LOWER, "MACHINERY"),
          ("quarters", "crew_quarters", -10, 6, LOWER, "ACCOMMODATION"),
          ("tank", "tanks", 6, 20, KEEL, "VOID")]
CELLS = [("aft_peak", X_AFT, -24, KEEL, 0, -BEAM, BEAM, "VOID", None)]
for wing, inner, x0, x1, floor, kind in WINGED:
    CELLS += [("%s_wing_p" % wing, x0, x1, KEEL, 0, -BEAM, -LINING, "VOID", None),
              (inner, x0, x1, floor, 0, -LINING, LINING, kind, None),
              ("%s_wing_s" % wing, x0, x1, KEEL, 0, LINING, BEAM, "VOID", None)]
CELLS += [
    ("fore_peak", 20, X_FORE, KEEL, 0, -BEAM, BEAM, "VOID", None),
    ("car_deck", X_AFT, X_FORE, 0, PASS, -BEAM, BEAM, "CARGO", 0.95),  # no vehicles aboard: 0.95
    ("passenger_house", HOUSES[0][0], HOUSES[0][1], PASS, BRIDGE, -HOUSES[0][2], HOUSES[0][2], "ACCOMMODATION",
     None),
    ("wheelhouse", HOUSES[1][0], HOUSES[1][1], BRIDGE, TOP, -HOUSES[1][2], HOUSES[1][2], "ACCOMMODATION", None),
    # Under the lower deck's plates, a bilge the length of each compartment over it.
    ("engine_bilge", -24, -10, KEEL, LOWER, -LINING, LINING, "VOID", None),
    ("quarters_bilge", -10, 6, KEEL, LOWER, -LINING, LINING, "VOID", None),
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

# Her four watertight bulkheads across her, to her car deck — the bulkhead deck:
# (name, x, top, collapse head est.), each spanning her car deck's breadth, which covers
# it; and the wing tanks' linings along her, leaky (est.): (name, z, from x, to x, top,
# collapse head). A head across a wall is the water's over the foot of each panel of it
# (SinkFailures): est., a bulkhead is built for the head from her keel to her car deck
# and gives way at 2.25× it, starting to leak by WALL_LEAK at five sixths of that; a
# lining — the wing tanks' inner skin, leaking through its LEAK — gives way at 1.5× it,
# so a wing flooded to the sea holds it; a wall the hit ended beside at half.
BUILT_FOR = 0.0 - KEEL
BULKHEADS = [("bulkhead_aft_peak", -24, 0.0, 2.25 * BUILT_FOR), ("bulkhead_engine", -10, 0.0, 2.25 * BUILT_FOR),
             ("bulkhead_quarters", 6, 0.0, 2.25 * BUILT_FOR), ("bulkhead_collision", 20, 0.0, 2.25 * BUILT_FOR)]
WALL_LEAK = 0.002
LININGS = [("%s_lining_%s" % (wing, tag), sign * LINING, x0, x1, 0.0, 1.5 * BUILT_FOR)
           for wing, _inner, x0, x1, _floor, _kind in WINGED for tag, sign in [("p", -1), ("s", 1)]]
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
for name, x, top, collapse in BULKHEADS:
    half = round(min(breadth(x, top), CAR_SIDE), 4)
    walls.append((name, "ACROSS", x, (-half, half), KEEL, top, collapse, parted(0, x, KEEL, top, -half, half)))
for name, z, x0, x1, top, collapse in LININGS:
    walls.append((name, "ALONG", z, (x0, x1), KEEL, top, collapse, parted(2, z, KEEL, top, x0, x1)))

# Openings: (name, kind, joins, centre, size, fields). size is the rectangle's extent
# along x, y and z, zero across the axis it is flat on.
SEA, SKY = "sea", "sky"
openings = []

def opening(name, kind, a, b, centre, size, **fields):
    openings.append((name, kind, [a or SKY, b or SKY], centre, size, fields))

# Doorways: open, as Q15 built them, from over their sills; in a watertight wall, a
# watertight door, shut by the ship at the hit over 10 s and jammed open one time in
# seven (est.), weeping 0.005 m² round its seals under the 2.6 m of the engine room it
# closes and giving way under 5 m of water. A doorway onto an open deck opens onto the
# sky.
watertight = {(w[2], cell) for w in walls if w[1] == "ACROSS" for cell in w[7]}
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
        if axis == 0 and (at, a) in watertight and (at, b) in watertight:
            opening("wtd_engine", "WATERTIGHT_DOOR", a, b, centre, size, starts="OPEN",
                    shuts_at_hit=True, shut_time=10.0, flip_chance=0.15, leak_head=0.0 - LOWER,
                    collapse_head=5.0, leak_area=0.005)
            continue
        tag = "door_%s_%s" % (a, b or SKY)
        opening("%s_%d" % (tag, sum(1 for o in openings if o[0].startswith(tag))), "DOOR", a, b,
                centre, size, starts="OPEN")

# Her bow door and stern door, the car deck's ends to the sea, each as wide as the car
# deck's end and 4.2 m high over a 0.3 m sill: shut and dogged, left open one time in ten
# at the bow and one in twenty at the stern (est.: the Herald sailed with hers open),
# their seals — a ro-ro door's are seldom tight — weeping 0.05 m² under half a metre of
# water and each giving way under 3 m: the Estonia's visor tore off in a seaway (est.).
DOOR_SILL, DOOR_HEIGHT = 0.3, 4.2
for name, x, half, chance in [("bow_door", X_FORE, CAR_BOW, 0.1), ("stern_door", X_AFT, CAR_SIDE, 0.05)]:
    opening(name, "DOOR", "car_deck", SEA, (x, DOOR_SILL + DOOR_HEIGHT * 0.5, 0), (0, DOOR_HEIGHT, 2 * half),
            starts="SHUT", flip_chance=chance, leak_head=0.5, collapse_head=3.0, leak_area=0.05)
# Holes in her decks: the car deck's stairs up into the house — water on a floor runs
# up and down them — and the wheelhouse's.
for tag, (x0, x1, z0, z1) in zip(["p", "s"], CAR_STAIRS):
    opening("stair_car_deck_passenger_house_" + tag, "STAIRWELL", "car_deck", "passenger_house",
            ((x0 + x1) * 0.5, PASS, (z0 + z1) * 0.5), (x1 - x0, 0, z1 - z0), starts="OPEN")
x0, x1, z0, z1 = WHEEL_STAIR
opening("stair_passenger_house_wheelhouse", "STAIRWELL", "passenger_house", "wheelhouse",
        ((x0 + x1) * 0.5, BRIDGE, (z0 + z1) * 0.5), (x1 - x0, 0, z1 - z0), starts="OPEN")
# The hatches down from the car deck to the engine room and the crew quarters, as the
# trawler's ways into her old voids: battened and dogged watertight, a body going down
# one opening it as a doorway's door is opened — shut to the water, it never weeps nor
# gives way.
def hatch(name, under, over, hole, deck):
    x0, x1, z0, z1 = hole
    opening(name, "HATCH", under, over, ((x0 + x1) * 0.5, deck, (z0 + z1) * 0.5), (x1 - x0, 0, z1 - z0),
            starts="SHUT")

for tag, hole in zip(["p", "s"], ENGINE_STAIRS):
    hatch("hatch_engine_room_" + tag, "engine_room", "car_deck", hole, 0.0)
for tag, hole in zip(["p", "s"], QUARTERS_STAIRS):
    hatch("hatch_crew_quarters_" + tag, "crew_quarters", "car_deck", hole, 0.0)
# The engine room's air, drawn down from the car deck through two vents in it either side
# of her centreline, always open (0.1 m² each, est.): water on the car deck pours down
# them. The car deck's own ventilation, two trunks up to the open deck aft, always open
# (0.5 m² each, est.).
for tag, z in [("p", -4.5), ("s", 4.5)]:
    opening("vent_engine_room_" + tag, "VENT", "engine_room", "car_deck", (-12.0, 0.0, z), (0.4, 0, 0.4),
            area=0.1, starts="OPEN")
    opening("vent_car_deck_" + tag, "VENT", "car_deck", SKY, (-27.5, PASS, z * 1.3), (0.8, 0, 0.8), area=0.5,
            starts="OPEN")
# The lower deck's plates are not watertight (est., as the trawler's): 0.3 m² of gaps
# between each compartment and the bilge under it.
for below, above in [("engine_bilge", "engine_room"), ("quarters_bilge", "crew_quarters")]:
    b = cell_box(below)
    opening("floor_" + above, "FLOOR_GAPS", below, above, ((b[0] + b[1]) * 0.5, LOWER, (b[4] + b[5]) * 0.5),
            (b[1] - b[0], 0, b[5] - b[4]), area=0.3, starts="OPEN")
# The wings' leaks through their linings, and the air pipe each breathes through up
# into the car deck, a 100 mm pipe (est., as the trawler's).
AIR_PIPE = 0.008
for wing, inner, x0, x1, _floor, _kind in WINGED:
    b = cell_box(inner)
    for tag in ["p", "s"]:
        w = cell_box("%s_wing_%s" % (wing, tag))
        z = b[4] if w[4] < b[4] else b[5]
        opening("leak_%s_wing_%s" % (wing, tag), "LEAK", "%s_wing_%s" % (wing, tag), inner,
                ((b[0] + b[1]) * 0.5, (b[2] + b[3]) * 0.5, z), (b[1] - b[0], b[3] - b[2], 0), area=WING_LEAK,
                starts="OPEN")
        opening("pipe_%s_wing_%s" % (wing, tag), "VENT", "%s_wing_%s" % (wing, tag), "car_deck",
                (x0 + 1.0, 0.0, (w[4] + w[5]) * 0.5), (0.09, 0, 0.09), area=AIR_PIPE, starts="OPEN")

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

# Mass (est.): where her weight sits — her hull to the passenger deck, her house and
# wheelhouse, her engines, her fuel and water in her tanks, her outfit and the people
# aboard. Her ballast is what the generator settles: as heavy as she must be to float at
# her waterline, and where along and across her it puts her weight over her lift, so she
# floats there level. Her GM comes out about 2.4 m, a laden ro-ro ferry's (est.): stiff
# while her car deck is dry, and far less than the free surface of water loose across it
# takes away.
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
MASS = [  # (name, kg, centre, (from x, to x))
    ("hull steel", 760e3, (-1.0, 1.0, 0.0), (-30, 30)),
    ("house and wheelhouse", 260e3, (-1.0, 6.4, 0.0), (-18, 18)),
    ("funnel and uptakes", 15e3, (-8.0, 10.0, 0.0), (-9, -7)),
    ("main engines and gearboxes", 90e3, (-21.7, -1.6, 0.0), (-23, -20.4)),
    ("generators and pumps", 35e3, (-14.0, -1.9, 0.0), (-19, -10)),
    ("fuel and fresh water", 110e3, (13.0, -3.0, 0.0), (6, 20)),
    ("outfit and passengers", 200e3, (0.0, 5.8, 0.0), (-18, 18)),
    ("crew quarters and stores", 30e3, (-2.0, -1.9, 0.0), (-10, 6)),
    ("anchors and windlass", 15e3, (23.0, 4.0, 0.0), (21, 25)),
]
BALLAST_Y = KEEL + 0.3
BALLAST_REACH = 8.0  # either side of its centre
weight = displaced * SEA_DENSITY
ballast = weight - sum(m[1] for m in MASS)
ballast_x = (weight * along / displaced - sum(m[1] * m[2][0] for m in MASS)) / ballast
ballast_z = (weight * across / displaced - sum(m[1] * m[2][2] for m in MASS)) / ballast
assert ballast > 0, "she is heavier than she floats"
assert cell_at(ballast_x, BALLAST_Y, ballast_z), "her solved ballast must lie in one of her cells"
MASS.append(("ballast", round(ballast, 1), (round(ballast_x, 4), BALLAST_Y, round(ballast_z, 4)),
             (round(ballast_x - BALLAST_REACH, 4), round(ballast_x + BALLAST_REACH, 4))))
gravity_y = sum(m[1] * m[2][1] for m in MASS) / weight
GM = lift_y / displaced + waterplane / displaced - gravity_y
# How her mass turns, the water moving with her, and how her motions die away (est.:
# roll 0.4 of her beam, pitch 0.25 of her length; the steamer's added mass and damping).
MOTION = [("roll_radius", 5.6), ("pitch_radius", 15.0), ("added_mass", 1.0),
          ("heave_damping", 0.5), ("roll_damping", 0.08), ("pitch_damping", 0.5)]
# Two liferafts either side of her bridge deck, useless on the high side past a list of
# 20° — modern rules (§5b.2).
LIFEBOATS = [("liferaft_port_aft", -1, -14.0, 20.0), ("liferaft_starboard_aft", 1, -14.0, 20.0),
             ("liferaft_port_forward", -1, 4.0, 20.0), ("liferaft_starboard_forward", 1, 4.0, 20.0)]
# What the sinking fails (§5b.1, est.): her funnel, 5.4 m over the bridge deck, stayed to
# 30° of list and 15° of trim, down in 1.5 s, crushing nothing it lands on — the
# wheelhouse stands further forward than it is tall; her generator in her engine room,
# drowned by 0.8 m of water over its foot, stopped past 25° of list or 12° of trim
# (SOLAS-based) and running again 3° back within both, its emergency power lighting her
# house and her wheelhouse for 30 minutes; a bilge pump in her engine room, 0.05 m³/s
# while it runs.
FUNNEL = dict(name="funnel", base=(FUNNEL_AT[0], BRIDGE, FUNNEL_AT[1]), height=FUNNEL_AT[3] - BRIDGE,
              radius=FUNNEL_AT[2], list=30.0, trim=15.0, fall=1.5, crushes=[])
GENERATOR = dict(name="generator", cell="engine_room", base=(-13.0, LOWER, 4.0), drowns=0.8,
                 list=25.0, trim=12.0, recovers=3.0, minutes=30.0, emergency=["passenger_house", "wheelhouse"])
PUMPS = [("bilge_pump", "engine_room", 0.05)]
# The bending her hull carries (est.: she cannot break), in N·m.
STRENGTH = (900e6, 800e6)
# Where along her and up her shell an iceberg's gash can be at all (est.): clear of her
# stem and her transom, from 0.2 m under her car deck down to 0.2 m over her keel.
HIT_ZONE_X = (-29.5, 29.5)
HIT_ZONE_Y = (KEEL + 0.2, -0.2)
# The must-sink rule's last rung (§5b.1, est.): a 26 m gash down her starboard side from
# the engine room into the crew quarters, 1 m under her waterline, 80 mm as one even slit
# and biting 2.5 m in, through her wing tanks into both, every door shut. `make ship-check` proves she
# founders on it within the bake's cap.
SURE_HIT = [("start_x", -22), ("length", 26), ("depth_start", 1), ("depth_end", 1),
            ("width", 0.08), ("bite", 2.5)]

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
sub("Structure", "9_structure", [
    ("waterline_y", num(WATERLINE)), ("keel_y", num(KEEL)),
    ("sections", arr("10_section", section_ids)), ("cells", arr("11_cell", cell_ids)),
    ("walls", arr("12_wall", wall_ids)), ("openings", arr("13_opening", opening_ids)),
    ("mass", arr("14_mass", mass_ids))] + [(k, num(v)) for k, v in MOTION] + [
    ("fittings", arr("16_fitting", fitting_ids)),
    ("strength", 'SubResource("%s")' % sub("Strength", "17_strength", [
        ("hog", num(STRENGTH[0])), ("sag", num(STRENGTH[1]))])),
    ("hit_zone_x", "Vector2(%s, %s)" % (num(HIT_ZONE_X[0]), num(HIT_ZONE_X[1]))),
    ("hit_zone_y", "Vector2(%s, %s)" % (num(HIT_ZONE_Y[0]), num(HIT_ZONE_Y[1]))),
    ("sure_hit", 'SubResource("%s")' % sub("Sure_hit", "15_hit", [(k, num(v)) for k, v in SURE_HIT]))])

# Her lifebuoys (#273), each hung on a railing span along her side that faces the sea —
# the layout lint holds every station to one: the span along `side` (1 starboard, -1 port)
# of the deck `h` high that runs over `x`, the outermost there. It hangs between the two
# posts nearest the span's middle, as her art draws a post every POST along a span; its
# pos is the point of the span it hangs from, at its deck's height. Its size is the
# lifebuoy kind's (data/props/lifebuoy.tres); she carries fewer than her seats.
POST = 1.5
LIFEBUOY = [("radius", 0.33), ("height", 0.075), ("mass", 2.5), ("grip_angle_deg", 20), ("friction", 3)]

def lifebuoy(x, side, h):
    found = [k for k, (on, a, b) in enumerate(rail_geo)
             if a[1] == b[1] and a[1] * side > 0 and abs(plat_geo[on][4] - h) < 1e-6
             and min(a[0], b[0]) < x < max(a[0], b[0])]
    assert found, "no railing along side %s of the deck at %s over %s" % (side, h, x)
    k = max(found, key=lambda k: abs(rail_geo[k][1][1]))
    _on, a, b = rail_geo[k]
    posts = max(1, math.ceil(math.hypot(b[0] - a[0], b[1] - a[1]) / POST))
    t = (math.floor((posts - 1) * 0.5) + 0.5) / posts
    at = (a[0] + (b[0] - a[0]) * t, h, a[1] + (b[1] - a[1]) * t)
    f = [("kind", '&"lifebuoy"'), ("railing", str(k)), ("pos", "Vector3(%s, %s, %s)" % tuple(num(c) for c in at))]
    f += [(field, num(v)) for field, v in LIFEBUOY]
    props.append(sub("Lifebuoy_%d" % sum(1 for p in props if p.startswith("Lifebuoy_")), "8_prop", f))

lifebuoy(-20.5, -1, 4.8)
lifebuoy(-10.0, 1, 4.8)
lifebuoy(0.5, -1, 4.8)
lifebuoy(11.0, 1, 4.8)

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
      "masses: %.1f t, ballast %.1f t at x %.3f z %.3f, GM %.2f m" % (weight / 1000, ballast / 1000, ballast_x,
                                                                     ballast_z, GM))
