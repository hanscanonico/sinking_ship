#!/usr/bin/env python3
"""Writes the barque's layout and structure, data/ships/barque.tres (SH37).

The layout and structure are generated: change her here, then `make ship SHIP=barque`.
`make ship-gen-check` (part of `make verify`) fails when the committed .tres is not what
this writes, so a hand edit to the .tres is caught. The sim reads only the .tres (D6).

A 50 m steel three-masted barque, a sail-training ship: a flush main deck between a
raised poop aft — her saloon under it, the charthouse and the wheel on it — and a short
fo'c'sle; a deckhouse amidships, her galley. Below her main deck the 'tween deck, the
cadets' berths and their mess, one cell from side to side and nearly her whole length;
under it her hold, a small auxiliary engine room aft and her sail locker forward, split
by bulkheads that stand only as high as the 'tween deck — few and low, as an old ship's
are. Four companionways and her main hatch open onto the 'tween deck from her main deck.
Her three masts carry her weight high, so her GM is small. Her signature is the
knockdown: heeled by water in a side tank, the sea reaching her main deck pours in at her
companionways and her main hatch when they were left open, onto a deck no wall divides,
and lays her on her side (the Marques, 1984; the Albatross, 1961). Her sections are
lofted here from a few numbers, as the trawler's (tools/gen_trawler.py) and the ferry's
(tools/gen_ferry.py), and the dressed art draws her hull from them (SectionHull;
ShipLayout.dressed). Every number is est. until a playtest or the census says otherwise.

Ship-local metres: x toward the bow, z to starboard, y up, origin on her main deck
amidships.

Usage: tools/gen_barque.py <out.tres>
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

# A crate of stores on her main deck: the steamer's cargo crate (SH10), the same
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

# Her heights (est.): the 'tween deck 2.5 m under her main deck and the floor of her hold,
# her engine room and her sail locker 2.25 m under that, over her floors and her ballast;
# the poop and the fo'c'sle 2.2 m over her main deck, the charthouse's top 2.2 m over the
# poop, the deckhouse's 2.3 m over her main deck. 4.5 m is her half beam: her main deck
# runs 4.2 m out between her bulwarks, her side tanks' linings 3.3 m out, the 'tween
# deck's sides, her hold's floor 2.4 m, her engine room's and her sail locker's narrower,
# where her lines close.
# Heights single precision holds exactly where a floor is walked: -2.5, -4.75.
TWEEN = -2.5
LOWER = -4.75
POOP = 2.2
FCSLE = 2.2
CHART_TOP = 4.4
HOUSE_TOP = 2.3
BEAM = 4.5
WAIST = 4.2
TWEEN_SIDE = 3.3
HOLD_SIDE = 2.4
LINING = TWEEN_SIDE
ENGINE_SIDE = 1.8
LOCKER_SIDE = 1.7
# Along her: her poop's break, her fo'c'sle's; her bulkheads — the aft peak's and the
# collision bulkhead, to her main deck; the engine room's and the sail locker's, to the
# 'tween deck only —; the 'tween deck's floor from the aft peak's bulkhead to where her bow
# narrows it; the hold's floor to where her bow narrows it under; the sail locker's.
POOP_BREAK = -14.0
FCSLE_BREAK = 18.0
AFT_PEAK = -19.0
ENGINE_FWD = -12.0
LOCKER_AFT = 10.0
COLLISION = 20.0
TWEEN_FWD = 16.0
LOCKER_FWD = 16.0
# The houses, to the middle of their walls: x from aft to forward, and their half breadth.
SALOON = (-21.0, POOP_BREAK, 3.6)
DECKHOUSE = (-6.0, -1.0, 2.0)
CHARTHOUSE = (-21.0, -17.0, 1.5)
FORECASTLE = (FCSLE_BREAK, 21.0, 2.5)
# Every door onto an open deck is weathertight, over a sill a step high (est.).
SILL = 0.3

# Her masts (est.), each stepped on her main deck: (name, x, radius, top). A barque's
# lower masts and topmasts and topgallants as one spar each, 0.2 m round — the crosstree
# made for it (DeckWorks.CROSSTREES) — standing 24 m to 30 m over her deck.
MASTS = [("mizzen", -11.0, 0.2, 24.0), ("main", 2.0, 0.2, 30.0), ("fore", 15.0, 0.2, 28.0)]

# The stairs (est.), each 1.1 m wide: two companionways aft and two forward down from her
# main deck to the 'tween deck through hatches in it, port and starboard, each climbing
# forward to its head; two down from the 'tween deck to the hold, one to the engine room
# and one to the sail locker; two up from her main deck onto the poop, at its break,
# climbing aft, and two onto the fo'c'sle, climbing forward.
COMPANIONWAYS = [(-10.4, -7.4, -3.1, -2.0), (-10.4, -7.4, 2.0, 3.1), (9.0, 12.0, -3.1, -2.0), (9.0, 12.0, 2.0, 3.1)]
COMPANIONWAY_TAGS = ["aft_p", "aft_s", "fore_p", "fore_s"]
HOLD_STAIRS = [(-1.0, 1.8, -2.0, -0.9), (-1.0, 1.8, 0.9, 2.0)]
ENGINE_STAIR = (-16.0, -13.2, -0.55, 0.55)
LOCKER_STAIR = (11.0, 13.8, -0.55, 0.55)
POOP_STAIRS = [(POOP_BREAK, POOP_BREAK + 2.8, -3.5, -2.4), (POOP_BREAK, POOP_BREAK + 2.8, 2.4, 3.5)]
FCSLE_STAIRS = [(FCSLE_BREAK - 2.8, FCSLE_BREAK, -3.0, -1.9), (FCSLE_BREAK - 2.8, FCSLE_BREAK, 1.9, 3.0)]
# Her main hatch amidships, its coaming and its cover a hop up; the hatch under it in the
# 'tween deck, boarded over.
MAIN_HATCH = (4.5, 8.0, -1.5, 1.5)
HATCH_TOP = 0.6

# --- Platforms. Her main deck first: the main deck the lints walk from (D6), round her
# companionways.
MAIN = holed("main_deck", "main deck", POOP_BREAK, FCSLE_BREAK, -WAIST, WAIST, 0.0, COMPANIONWAYS)
SALOON_FLOOR = platform("saloon_floor", "main deck", SALOON[0], SALOON[1], -SALOON[2], SALOON[2])
FCSLE_FLOOR = platform("forecastle_floor", "main deck", FORECASTLE[0], FORECASTLE[1], -FORECASTLE[2],
                       FORECASTLE[2])
# The 'tween deck, round the stairs down to the hold, the engine room and the sail locker.
TWEEN_DECK = holed("tween_deck", "tween deck", AFT_PEAK, TWEEN_FWD, -TWEEN_SIDE, TWEEN_SIDE, TWEEN,
                   HOLD_STAIRS + [ENGINE_STAIR, LOCKER_STAIR])
ENGINE_FLOOR = platform("engine_floor", "lower deck", AFT_PEAK, ENGINE_FWD, -ENGINE_SIDE, ENGINE_SIDE, LOWER)
HOLD_FLOOR = platform("hold_floor", "lower deck", ENGINE_FWD, LOCKER_AFT, -HOLD_SIDE, HOLD_SIDE, LOWER)
LOCKER_FLOOR = platform("locker_floor", "lower deck", LOCKER_AFT, LOCKER_FWD, -LOCKER_SIDE, LOCKER_SIDE, LOWER)
# The poop deck, narrowing over her counter; the fo'c'sle head, narrowing to her stem.
POOP_SIDE = (4.0, 3.6)
POOP_DECK = platform("poop_deck", "poop deck", -21.0, POOP_BREAK, -POOP_SIDE[0], POOP_SIDE[0], POOP)
POOP_AFT = platform("poop_aft", "poop deck", -24.0, -21.0, -POOP_SIDE[1], POOP_SIDE[1], POOP)
FCSLE_SIDE = (3.35, 1.8)
FCSLE_DECK = platform("forecastle_deck", "forecastle", FCSLE_BREAK, 21.0, -FCSLE_SIDE[0], FCSLE_SIDE[0], FCSLE)
FCSLE_HEAD = platform("forecastle_head", "forecastle", 21.0, 23.5, -FCSLE_SIDE[1], FCSLE_SIDE[1], FCSLE)
pieces_after()

# --- Ramps.
for tag, (x0, x1, z0, z1) in zip(COMPANIONWAY_TAGS, COMPANIONWAYS):
    ramp("companionway_" + tag, x0, z0, x1 - x0, z1 - z0, TWEEN, 0)
for tag, (x0, x1, z0, z1) in zip(["port", "starboard"], HOLD_STAIRS):
    ramp("hold_" + tag, x0, z0, x1 - x0, z1 - z0, LOWER, TWEEN)
for tag, (x0, x1, z0, z1) in [("engine_room", ENGINE_STAIR), ("sail_locker", LOCKER_STAIR)]:
    ramp(tag, x0, z0, x1 - x0, z1 - z0, LOWER, TWEEN)
for tag, (x0, x1, z0, z1) in zip(["port", "starboard"], POOP_STAIRS):
    ramp("poop_" + tag, x0, z0, x1 - x0, z1 - z0, POOP, 0)
for tag, (x0, x1, z0, z1) in zip(["port", "starboard"], FCSLE_STAIRS):
    ramp("forecastle_" + tag, x0, z0, x1 - x0, z1 - z0, 0, FCSLE)

# --- Blockers. Below: the 'tween deck's linings and ends, the cadets' berths parted from
# their mess by a bulkhead with two doorways; the engine room's, the hold's and the sail
# locker's sides and ends, and her auxiliary engine.
wall_x("tween_aft", AFT_PEAK, -TWEEN_SIDE, TWEEN_SIDE, TWEEN, 0)
wall_x("tween_forward", TWEEN_FWD, -TWEEN_SIDE, TWEEN_SIDE, TWEEN, 0)
wall_x_doors("berths_forward", 4.0, -TWEEN_SIDE, TWEEN_SIDE, [(-2.75, -1.65), (1.65, 2.75)], TWEEN, 0)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z("tween_" + side, sign * TWEEN_SIDE, AFT_PEAK, TWEEN_FWD, TWEEN, 0)
    wall_z("engine_" + side, sign * ENGINE_SIDE, AFT_PEAK, ENGINE_FWD, LOWER, TWEEN)
    wall_z("hold_" + side, sign * HOLD_SIDE, ENGINE_FWD, LOCKER_AFT, LOWER, TWEEN)
    wall_z("locker_" + side, sign * LOCKER_SIDE, LOCKER_AFT, LOCKER_FWD, LOWER, TWEEN)
wall_x("engine_aft", AFT_PEAK, -ENGINE_SIDE, ENGINE_SIDE, LOWER, TWEEN)
wall_x("bulkhead_engine", ENGINE_FWD, -HOLD_SIDE, HOLD_SIDE, LOWER, TWEEN)
wall_x("bulkhead_locker", LOCKER_AFT, -HOLD_SIDE, HOLD_SIDE, LOWER, TWEEN)
wall_x("locker_forward", LOCKER_FWD, -LOCKER_SIDE, LOCKER_SIDE, LOWER, TWEEN)
ENGINE = (-18.6, -17.0, -0.6, 0.6)
box("engine", *ENGINE, LOWER, LOWER + 1.4)
# The poop's break across her deck, a door in it into the saloon; the saloon's sides and
# its after wall, the steering flat abaft it.
wall_x_doors("poop_break", POOP_BREAK, -WAIST, WAIST, [(-DOOR / 2, DOOR / 2)], 0, POOP, SILL)
x0, x1, half = SALOON
wall_x("saloon_aft", x0, -half, half, 0, POOP)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z("saloon_" + side, sign * half, x0, x1, 0, POOP)
# The deckhouse amidships, her galley: a door forward and one aft, roofed over.
x0, x1, half = DECKHOUSE
wall_x_doors("deckhouse_aft", x0, -half, half, [(-DOOR / 2, DOOR / 2)], 0, HOUSE_TOP, SILL)
wall_x_doors("deckhouse_forward", x1, -half, half, [(-DOOR / 2, DOOR / 2)], 0, HOUSE_TOP, SILL)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z("deckhouse_" + side, sign * half, x0, x1, 0, HOUSE_TOP)
box("deckhouse_roof", x0 - T, x1 + T, -half - T, half + T, HOUSE_TOP - T, HOUSE_TOP)
# The charthouse on the poop, the wheel's shelter: a door either side, roofed over.
x0, x1, half = CHARTHOUSE
wall_x("charthouse_aft", x0, -half, half, POOP, CHART_TOP)
wall_x("charthouse_forward", x1, -half, half, POOP, CHART_TOP)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z_doors("charthouse_" + side, sign * half, x0, x1, [(-19.55, -19.55 + DOOR)], POOP, CHART_TOP, SILL)
box("charthouse_roof", x0 - T, x1 + T, -half - T, half + T, CHART_TOP - T, CHART_TOP)
# The fo'c'sle's break across her deck, a door in it; the fo'c'sle's sides and its
# forward wall.
wall_x_doors("forecastle_break", FCSLE_BREAK, -WAIST, WAIST, [(-DOOR / 2, DOOR / 2)], 0, FCSLE, SILL)
x0, x1, half = FORECASTLE
wall_x("forecastle_forward", x1, -half, half, 0, FCSLE)
for side, sign in [("port", -1), ("starboard", 1)]:
    wall_z("forecastle_" + side, sign * half, x0, x1, 0, FCSLE)
# On deck: her main hatch's coaming and cover, and her three masts.
box("main_hatch", *MAIN_HATCH, 0, HATCH_TOP)
for name, x, radius, top in MASTS:
    cylinder(name + "_mast", x, 0, radius, 0, top)
# Her saloon's furniture, after every other blocker so none of theirs moves, each drawn
# as its shape says (FurnitureDressing): a table 0.75 m tall either side of the way in
# from its door, a bench 0.45 along its inboard side; each 0.5 m off the walls and 1.0 m
# in plan from the pendant over the room's middle (est.).
TABLE, BENCH = 0.75, 0.45
for side, sign in [("port", -1), ("starboard", 1)]:
    box("table_saloon_" + side, -20.0, -17.0, *sorted((sign * 2.15, sign * 2.85)), 0, TABLE)
    box("bench_saloon_" + side, -20.0, -17.0, *sorted((sign * 1.65, sign * 2.0)), 0, BENCH)

# --- Railings: her main deck's bulwarks, the poop's and the fo'c'sle's edges — open where
# a stair lands, and along the fo'c'sle's break, a drop onto her main deck as the
# trawler's —, and three sides of every stair hole, the fourth its stair's head.
for tag, sign in [("port", -1), ("starboard", 1)]:
    railing("waist_" + tag, MAIN, (POOP_BREAK, sign * WAIST), (FCSLE_BREAK, sign * WAIST))
    railing("poop_" + tag, POOP_DECK, (-21.0, sign * POOP_SIDE[0]), (POOP_BREAK, sign * POOP_SIDE[0]))
    railing("poop_step_" + tag, POOP_DECK, (-21.0, sign * POOP_SIDE[1]), (-21.0, sign * POOP_SIDE[0]))
    railing("poop_aft_" + tag, POOP_AFT, (-24.0, sign * POOP_SIDE[1]), (-21.0, sign * POOP_SIDE[1]))
    railing("forecastle_" + tag, FCSLE_DECK, (FCSLE_BREAK, sign * FCSLE_SIDE[0]), (21.0, sign * FCSLE_SIDE[0]))
    railing("forecastle_step_" + tag, FCSLE_DECK, (21.0, sign * FCSLE_SIDE[1]), (21.0, sign * FCSLE_SIDE[0]))
    railing("forecastle_head_" + tag, FCSLE_HEAD, (21.0, sign * FCSLE_SIDE[1]), (23.5, sign * FCSLE_SIDE[1]))
railing("taffrail", POOP_AFT, (-24.0, -POOP_SIDE[1]), (-24.0, POOP_SIDE[1]))
railing("forecastle_head_fwd", FCSLE_HEAD, (23.5, -FCSLE_SIDE[1]), (23.5, FCSLE_SIDE[1]))
railing("poop_front_port", POOP_DECK, (POOP_BREAK, -POOP_SIDE[0]), (POOP_BREAK, POOP_STAIRS[0][2]))
railing("poop_front_middle", POOP_DECK, (POOP_BREAK, POOP_STAIRS[0][3]), (POOP_BREAK, POOP_STAIRS[1][2]))
railing("poop_front_starboard", POOP_DECK, (POOP_BREAK, POOP_STAIRS[1][3]), (POOP_BREAK, POOP_SIDE[0]))

def hatch_rails(rid, plat, hole, *open_sides):
    x0, x1, z0, z1 = hole
    sides = {"x0": ((x0, z0), (x0, z1)), "x1": ((x1, z0), (x1, z1)),
             "z0": ((x0, z0), (x1, z0)), "z1": ((x0, z1), (x1, z1))}
    for tag, (a, b) in sides.items():
        if tag not in open_sides:
            railing("%s_%s" % (rid, tag), plat, a, b)

for tag, hole in zip(COMPANIONWAY_TAGS, COMPANIONWAYS):
    hatch_rails("companionway_" + tag, MAIN, hole, "x1")
for tag, hole in zip(["port", "starboard"], HOLD_STAIRS):
    hatch_rails("hold_hatch_" + tag, TWEEN_DECK, hole, "x1")
hatch_rails("engine_hatch", TWEEN_DECK, ENGINE_STAIR, "x1")
hatch_rails("locker_hatch", TWEEN_DECK, LOCKER_STAIR, "x1")

# --- Boarding ladders, one down each side of her waist: a swimmer climbs back aboard
# there (SH5).
ladder("port", MAIN, (6.0, -WAIST), (7.0, -WAIST))
ladder("starboard", MAIN, (6.0, WAIST), (7.0, WAIST))

# --- Two crates of stores on her main deck, on her centreline between her companionways.
crate("aft", -9.0, 0, 0.0)
crate("forward", 10.5, 0, 0.0)

# --- Rooms, to the middle of their walls.
room("engine_room", "engine room", AFT_PEAK, ENGINE_FWD, -ENGINE_SIDE, ENGINE_SIDE, LOWER)
room("hold", "hold", ENGINE_FWD, LOCKER_AFT, -HOLD_SIDE, HOLD_SIDE, LOWER)
room("sail_locker", "sail locker", LOCKER_AFT, LOCKER_FWD, -LOCKER_SIDE, LOCKER_SIDE, LOWER)
room("berths", "cadets' berths", AFT_PEAK, 4.0, -TWEEN_SIDE, TWEEN_SIDE, TWEEN)
room("mess", "cadets' mess", 4.0, TWEEN_FWD, -TWEEN_SIDE, TWEEN_SIDE, TWEEN)
room("saloon", "saloon", SALOON[0], SALOON[1], -SALOON[2], SALOON[2], 0)
room("galley", "galley", DECKHOUSE[0], DECKHOUSE[1], -DECKHOUSE[2], DECKHOUSE[2], 0)
room("forecastle", "forecastle", FORECASTLE[0], FORECASTLE[1], -FORECASTLE[2], FORECASTLE[2], 0)
room("charthouse", "charthouse", CHARTHOUSE[0], CHARTHOUSE[1], -CHARTHOUSE[2], CHARTHOUSE[2], POOP)

# Eight seats: five on her main deck — one in the galley —, two on the poop, one on the
# fo'c'sle.
spawns = [
    (-12.5, 0, 0.0), (-3.5, 0, 0.0), (3.5, 0, -3.0), (3.5, 0, 3.0), (13.5, 0, 0.0),
    (-15.5, POOP, 0.0), (-22.5, POOP, 0.0), (19.5, FCSLE, 0.0),
]
# The seats a match on her takes (est.): the steamer's 1–8.
SEATS = (1, 8)

def arr(script, ids):
    return "Array[ExtResource(\"%s\")]([%s])" % (script, ", ".join('SubResource("%s")' % i for i in ids))

# --- The structure (§5b.2), est. throughout: her hull, lofted here from her
# dimensions; her cells, walls, openings and mass. `make ship-check` floats her on it,
# level, at her waterline, and sinks her on her sure hit.
FREEBOARD = 1.5
WATERLINE = -FREEBOARD
KEEL = -5.6  # 4.1 m of draught
X_AFT, X_FORE = -24.0, 26.0  # her counter's end at the poop, her stem's head at the fo'c'sle
STEM_HEAD = FCSLE
# Her lines (est.): a round-bilged midship section — a superellipse of power BILGE from
# her main deck down to her keel, a sailing ship's deep, easy bilge — its waterlines
# closing on the stem past FORE_SHOULDER (at her main deck and over, at her keel), as one
# minus the square of the way there, and on her counter past AFT_SHOULDER, to
# TRANSOM_SHARE of her breadth (over the counter's lower edge, at her keel): a fine run
# under an overhanging counter. A raked stem STEM_RAKE aft per metre down from its head to
# STEM_KNEE, rounding into her keel at X_FOOT; her counter's lower edge standing at
# Y_TRANSOM, over her waterline, the run under it sweeping up from her keel at X_POST.
BILGE = 2.2
FORE_SHOULDER = (16.0, 8.0)
AFT_SHOULDER = -12.0
TRANSOM_SHARE = (0.85, 0.15)
STEM_RAKE = 0.5
STEM_KNEE = -3.0
X_FOOT = 19.0
X_POST = -18.0
Y_TRANSOM = -0.5

def clamp(v, a, b):
    return min(max(v, a), b)

def lerp(a, b, t):
    return a + (b - a) * t

def stem_x(y):
    line = X_FORE - (STEM_HEAD - y) * STEM_RAKE
    if y >= STEM_KNEE:
        return line
    knee = X_FORE - (STEM_HEAD - STEM_KNEE) * STEM_RAKE
    share = (STEM_KNEE - y) / (STEM_KNEE - KEEL)
    return X_FOOT + (knee - X_FOOT) * math.sqrt(max(1.0 - share * share, 0.0))

def bottom(x):
    """Her lowest point at x: her keel, the run swept up to her counter, or her stem."""
    if x > X_FOOT:
        low, high = KEEL, STEM_HEAD
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
    """Her shell's top at x: the poop, the fo'c'sle, or her main deck between them."""
    if x < POOP_BREAK:
        return POOP
    if x > FCSLE_BREAK:
        return FCSLE
    return 0.0

# The houses on her decks, enclosed: (x0, x1, half breadth, foot, top) — to their walls'
# outer faces.
HOUSES = [(DECKHOUSE[0] - T, DECKHOUSE[1] + T, DECKHOUSE[2] + T, 0.0, HOUSE_TOP),
          (CHARTHOUSE[0] - T, CHARTHOUSE[1] + T, CHARTHOUSE[2] + T, POOP, CHART_TOP)]
SIDE_POINTS = 14
# Sections stand for no more than SECTION_MAX of hull, between her ends and every
# cell's, so no cell splits a section.
SECTION_MAX = 2.0
SECTION_BREAKS = sorted({X_AFT, AFT_PEAK, POOP_BREAK, ENGINE_FWD, LOCKER_AFT, FCSLE_BREAK, COLLISION, X_FORE}
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

# Every deck in her hull stands inside it, at its corners: one under her main deck clear
# of her shell, the walls along its edges with it; one on her main deck or her shell's
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
# kind's). Under her main deck: her aft peak over her rudder; the 'tween deck, one cell
# from the aft peak's bulkhead to the collision bulkhead and from lining to lining — no
# wall stands along it, so water on it runs to whichever side she heels to; under it the
# engine room, the hold and the sail locker, from her keel to the 'tween deck, parted by
# bulkheads no higher; outboard of them all, the length of them and from her keel to her
# main deck, her side tanks behind their linings, her fresh water's and her water
# ballast's, empty (the plan's lengthwise wall in a wide cell, R23): a gash biting less
# deep than a tank is wide floods that side alone, and she heels; her fore peak. Over her
# main deck the poop, the fo'c'sle and her two houses.
CELLS = [
    ("aft_peak", X_AFT, AFT_PEAK, KEEL, 0, -BEAM, BEAM, "VOID", None),
    ("side_tank_p", AFT_PEAK, COLLISION, KEEL, 0, -BEAM, -LINING, "VOID", None),
    ("engine_room", AFT_PEAK, ENGINE_FWD, KEEL, TWEEN, -LINING, LINING, "MACHINERY", None),
    ("hold", ENGINE_FWD, LOCKER_AFT, KEEL, TWEEN, -LINING, LINING, "CARGO", 0.9),  # empty but her ballast: 0.90
    ("sail_locker", LOCKER_AFT, COLLISION, KEEL, TWEEN, -LINING, LINING, "STORES", None),
    ("side_tank_s", AFT_PEAK, COLLISION, KEEL, 0, LINING, BEAM, "VOID", None),
    ("fore_peak", COLLISION, X_FORE, KEEL, 0, -BEAM, BEAM, "VOID", None),
    ("tween_deck", AFT_PEAK, COLLISION, TWEEN, 0, -LINING, LINING, "ACCOMMODATION", None),
    ("poop", X_AFT, POOP_BREAK, 0, POOP, -BEAM, BEAM, "ACCOMMODATION", None),
    ("forecastle", FCSLE_BREAK, X_FORE, 0, FCSLE, -BEAM, BEAM, "ACCOMMODATION", None),
    ("deckhouse", HOUSES[0][0], HOUSES[0][1], 0, HOUSE_TOP, -HOUSES[0][2], HOUSES[0][2], "ACCOMMODATION", None),
    ("charthouse", HOUSES[1][0], HOUSES[1][1], POOP, CHART_TOP, -HOUSES[1][2], HOUSES[1][2], "ACCOMMODATION",
     None),
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

# Her four bulkheads across her: (name, x, top, collapse head est.) — the aft peak's and
# the collision bulkhead to her main deck, the engine room's and the sail locker's only to
# the 'tween deck, as an old ship's were —, each spanning the deck over it. A head across
# a wall is the water's over the foot of each panel of it (SinkFailures): est., a bulkhead
# is built for the head from her keel to its top and gives way at 2× it — riveted and
# older than the ferry's —, starting to leak by WALL_LEAK at five sixths of that; a wall
# the hit ended beside at half.
BULKHEADS = [("bulkhead_aft_peak", AFT_PEAK, 0.0, SALOON[2]), ("bulkhead_engine", ENGINE_FWD, TWEEN, None),
             ("bulkhead_locker", LOCKER_AFT, TWEEN, None), ("bulkhead_collision", COLLISION, 0.0, FORECASTLE[2])]
WALL_LEAK = 0.002
# The side tanks' linings along her, leaky (est.): (name, z, top, collapse head) — the
# tanks' inner skin, leaking through its LEAK, giving way at 1.5× the head from her keel to
# her main deck, so a tank flooded to the sea holds it.
LININGS = [("side_tank_lining_%s" % tag, sign * LINING, 0.0, 1.5 * (0.0 - KEEL))
           for tag, sign in [("p", -1), ("s", 1)]]
TANK_LEAK = 0.001  # through the lining of each space inboard of a tank

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
for name, x, top, under in BULKHEADS:
    # Under the poop and the fo'c'sle a bulkhead to her main deck spans the floor over it.
    half = round(breadth(x, top) if under is None else min(breadth(x, top), under), 4)
    collapse = 2.0 * (top - KEEL)
    walls.append((name, "ACROSS", x, (-half, half), KEEL, top, collapse, parted(0, x, KEEL, top, -half, half)))
for name, z, top, collapse in LININGS:
    walls.append((name, "ALONG", z, (AFT_PEAK, COLLISION), KEEL, top, collapse,
                  parted(2, z, KEEL, top, AFT_PEAK, COLLISION)))

# Openings: (name, kind, joins, centre, size, fields). size is the rectangle's extent
# along x, y and z, zero across the axis it is flat on.
SEA, SKY = "sea", "sky"
openings = []

def opening(name, kind, a, b, centre, size, **fields):
    openings.append((name, kind, [a or SKY, b or SKY], centre, size, fields))

# Doorways: open, as Q15 built them, from over their sills. None pierces a watertight
# wall. A doorway onto an open deck opens onto the sky.
watertight = {(w[2], cell) for w in walls for cell in w[7]}
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
        assert not (axis == 0 and (at, a) in watertight and (at, b) in watertight), "a door in a bulkhead"
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

def hatch(name, under, over, hole, deck, **fields):
    x0, x1, z0, z1 = hole
    opening(name, "HATCH", under, over, ((x0 + x1) * 0.5, deck, (z0 + z1) * 0.5), (x1 - x0, 0, z1 - z0),
            starts="SHUT", **fields)

# Her companionways and her main hatch, the 'tween deck's ways to the sky — her signature.
# Each companionway is a hood over its stair, its slide and doors shut, left open one time
# in four (est.: a training ship under sail keeps hers open for the watch below, as the
# Marques did); shut, its slide weeps 0.005 m² under 1.5 m of water and gives way under
# 4 m. Her main hatch is battened under its tarpaulins, left open one time in ten
# (est.: working cargo or stores), weeping 0.01 m² under a metre of water and giving way
# under 3 m, as the trawler's fish hatch.
for tag, hole in zip(COMPANIONWAY_TAGS, COMPANIONWAYS):
    hatch("companionway_" + tag, "tween_deck", SKY, hole, 0.0, flip_chance=0.25, leak_head=1.5,
          collapse_head=4.0, leak_area=0.005)
hatch("main_hatch", "tween_deck", SKY, MAIN_HATCH, 0.0, flip_chance=0.1, leak_head=1.0, collapse_head=3.0,
      leak_area=0.01)
# The hatch under it in the 'tween deck down to her hold, boarded over: its boards weep
# 0.01 m² under a metre of water and give way under 3 m (est.).
hatch("lower_hatch", "hold", "tween_deck", MAIN_HATCH, TWEEN, leak_head=1.0, collapse_head=3.0, leak_area=0.01)
# The hatches down from the 'tween deck to the hold, the engine room and the sail locker,
# as the ferry's ways down from her car deck: battened and dogged watertight, a body going
# down one opening it as a doorway's door is opened — shut to the water, it never weeps
# nor gives way.
for tag, hole in zip(["p", "s"], HOLD_STAIRS):
    hatch("hatch_hold_" + tag, "hold", "tween_deck", hole, TWEEN)
hatch("hatch_engine_room", "engine_room", "tween_deck", ENGINE_STAIR, TWEEN)
hatch("hatch_sail_locker", "sail_locker", "tween_deck", LOCKER_STAIR, TWEEN)
# The 'tween deck's air, two cowl ventilators on her main deck abaft her main hatch either
# side of her centreline, always open (0.05 m² each, est.).
for tag, z in [("p", -0.8), ("s", 0.8)]:
    opening("vent_tween_deck_" + tag, "VENT", "tween_deck", SKY, (3.2, 0.0, z), (0.3, 0, 0.3), area=0.05,
            starts="OPEN")
# Her peaks' air pipes, a 100 mm pipe each (est., as the ferry's wings'): the aft peak's
# up into the poop, the fore peak's into the fo'c'sle.
AIR_PIPE = 0.008
for peak, over, x in [("aft_peak", "poop", -21.5), ("fore_peak", "forecastle", 21.5)]:
    opening("pipe_" + peak, "VENT", peak, over, (x, 0.0, 0.0), (0.09, 0, 0.09), area=AIR_PIPE, starts="OPEN")
# The side tanks' leaks through their linings, and the air pipe each breathes through up
# to her main deck, a 100 mm pipe.
for tag in ["p", "s"]:
    w = cell_box("side_tank_" + tag)
    for inner in ["engine_room", "hold", "sail_locker", "tween_deck"]:
        b = cell_box(inner)
        z = b[4] if w[4] < b[4] else b[5]
        opening("leak_side_tank_%s_%s" % (tag, inner), "LEAK", "side_tank_" + tag, inner,
                ((b[0] + b[1]) * 0.5, (b[2] + b[3]) * 0.5, z), (b[1] - b[0], b[3] - b[2], 0), area=TANK_LEAK,
                starts="OPEN")
    opening("pipe_side_tank_" + tag, "VENT", "side_tank_" + tag, SKY, (ENGINE_FWD, 0.0, (w[4] + w[5]) * 0.5),
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


# Mass (est.): where her weight sits — her hull to the poop and the fo'c'sle, her houses,
# her three masts with their yards, rigging and sails, her auxiliary engine, her fuel and
# fresh water low in her hold, her outfit and the people aboard, her anchors. Her masts'
# weight stands high: each mast's spars and wire at about two fifths of its height, its
# sails furled on its yards higher still. Her ballast — pig iron over her floors — is what
# the generator settles: as heavy as she must be to float at her waterline, and where
# along and across her it puts her weight over her lift, so she floats there level. Her GM
# comes out about 0.7 m, the research's 0.5–1.0 m for a tall ship (est.): stiff enough
# under sail, and far less than the free surface of water loose across her 'tween deck
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
RIG = {"mizzen": (12e3, 4e3), "main": (22e3, 7e3), "fore": (20e3, 6e3)}  # spars and wire, sails
MASS = [  # (name, kg, centre, (from x, to x))
    ("hull steel", 480e3, (0.0, -1.35, 0.0), (-24, 26)),
    ("poop", 20e3, (-19.0, 1.1, 0.0), (-24, -14)),
    ("forecastle", 10e3, (22.0, 1.1, 0.0), (18, 26)),
    ("deckhouse and charthouse", 18e3, (-10.0, 2.2, 0.0), (-21, -1)),
]
for name, x, _radius, top in MASTS:
    spars, sails = RIG[name]
    MASS.append(("%s mast and rigging" % name, spars, (x, round(top * 0.4, 4), 0.0), (x - 0.2, x + 0.2)))
    MASS.append(("%s sails" % name, sails, (x, round(top * 0.6, 4), 0.0), (x - 0.2, x + 0.2)))
MASS += [
    ("auxiliary engine", 12e3, (-17.8, -4.0, 0.0), (-18.6, -17.0)),
    ("fuel and fresh water", 45e3, (-1.0, -5.0, 0.0), (-12, 10)),
    ("outfit and the people aboard", 60e3, (-2.0, -0.8, 0.0), (-19, 16)),
    ("spare sails and stores", 8e3, (13.0, -3.8, 0.0), (10, 16)),
    ("anchors and windlass", 10e3, (22.0, 2.6, 0.0), (21, 23.5)),
]
BALLAST_Y = KEEL + 0.4
BALLAST_REACH = 10.0  # either side of its centre
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
# roll 0.45 of her beam — her rig's weight aloft swings far out —, pitch 0.25 of her
# length; the steamer's added mass and damping).
MOTION = [("roll_radius", 4.0), ("pitch_radius", 12.5), ("added_mass", 1.0),
          ("heave_damping", 0.5), ("roll_damping", 0.08), ("pitch_damping", 0.5)]
# Her two boats in davits either side abaft her deckhouse, useless on the high side past
# a list of 15° (§5b.2: an old ship's).
LIFEBOATS = [("lifeboat_port", -1, -8.0, 15.0), ("lifeboat_starboard", 1, -8.0, 15.0)]
# What the sinking fails (§5b.1): nothing on her is a FUNNEL fitting — her masts are not
# felled, their art being a mast's, not a funnel's (DeckWorks) —, and she has no
# generator: her oil lamps light her throughout, each cell's until the water reaches it.
# The bending her hull carries (est.: she cannot break), in N·m.
STRENGTH = (300e6, 270e6)
# Where along her and up her shell an iceberg's gash can be at all (est.): clear of her
# stem and her counter, from 0.2 m under her main deck down to 0.2 m over her keel.
HIT_ZONE_X = (-23.5, 25.5)
HIT_ZONE_Y = (KEEL + 0.2, -0.2)
# The must-sink rule's last rung (§5b.1, est.): a 26 m gash down her starboard side from
# her engine room through her hold, 1.5 m under her waterline, 80 mm as one even slit and
# biting 1.5 m in, every hatch and companionway shut. `make ship-check` proves she founders
# on it within the bake's cap.
SURE_HIT = [("start_x", -16), ("length", 26), ("depth_start", 1.5), ("depth_end", 1.5),
            ("width", 0.08), ("bite", 1.5)]

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

lifebuoy(-19.0, -1, 2.2)
lifebuoy(2.5, 1, 0.0)
lifebuoy(22.0, 1, 2.2)

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
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write(head + "\n" + "\n\n".join(subs) + "\n\n" + "\n".join(res) + "\n")
print(len(platforms), "platforms", len(ramps), "ramps", len(blockers), "blockers", len(railings), "railings", len(ladders), "ladders", len(props), "props", len(rooms), "rooms")
print(len(sections), "sections", len(CELLS), "cells", len(walls), "walls", len(openings), "openings", len(MASS),
      "masses: %.1f t, ballast %.1f t at x %.3f z %.3f, KG %.2f m, GM %.2f m" % (weight / 1000, ballast / 1000, ballast_x,
                                                                     ballast_z, gravity_y - KEEL, GM))
