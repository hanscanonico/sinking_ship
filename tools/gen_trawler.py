#!/usr/bin/env python3
"""Writes the trawler's layout and structure, data/ships/trawler.tres (SH30).

The layout and structure are generated: change her here, then `make ship SHIP=trawler`.
`make ship-check` (part of `make verify`) fails when the committed .tres is not what
this writes, so a hand edit to the .tres is caught. The sim reads only the .tres (D6).

A 30 m trawler for quick, crowded matches (§5b.2): three compartments under her deck —
the engine room aft, the fish hold, the crew space forward under the fo'c'sle — split by
two watertight walls with one watertight door, and her working deck between its
bulwarks a cell of its own, open to the sky, its freeing ports at its foot. She has no
dressed art to cut her sections from, as the steamer's are (tools/gen_steamer.py): her
hull is lofted here from a few numbers, and the greybox draws her from her data
(ShipLayout.dressed). Every number is est. until a playtest or the census says
otherwise.

Ship-local metres: x toward the bow, z to starboard, y up, origin on the main deck
amidships.

Usage: tools/gen_trawler.py <out.tres>
"""
import math
import re
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
# platform; (x0, x1, z0, z1, floor, name) per room; and every doorway as (axis, at,
# from, to, bottom): a gap in a wall along x = at (axis 0) or z = at (axis 2).
plat_geo, room_geo, doorways = [], [], []

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

def ramp(rid, x, z, w, d, start, end):
    """A stair along x from start (at x) to end (at x + w), d wide."""
    f = [("area", rect(x, z, w, d))]
    if start != 0.0:
        f.append(("start_height", num(start)))
    if end != 0.0:
        f.append(("end_height", num(end)))
    ramps.append(sub("Ramp_" + rid, "2_ramp", f))

def box(bid, x0, x1, z0, z1, bottom, top):
    f = [("area", rect_xz(x0, x1, z0, z1))]
    if bottom != 0.0:
        f.append(("bottom", num(bottom)))
    f.append(("top", num(top)))
    blockers.append(sub("Blocker_" + bid, "3_block", f))

def cylinder(bid, cx, cz, r, bottom, top):
    f = [("shape", "1"), ("centre", "Vector2(%s, %s)" % (num(cx), num(cz))), ("radius", num(r))]
    if bottom != 0.0:
        f.append(("bottom", num(bottom)))
    f.append(("top", num(top)))
    blockers.append(sub("Blocker_" + bid, "3_block", f))

# A railing breaks span by span (SH10), as the steamer's: a run longer than
# RAIL_SECTION is laid as touching spans of about that length.
RAIL_SECTION = 3.5

def railing(rid, plat, a, b):
    length = abs(b[0] - a[0]) + abs(b[1] - a[1])  # every railing runs along x or z
    count = -(-length // RAIL_SECTION)
    step = round(length / count * 2) / 2
    ends = [a]
    for k in range(1, int(count)):
        t = step * k / length
        ends.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    ends.append(b)
    for k in range(len(ends) - 1):
        f = []
        if plat != 0:
            f.append(("platform", str(plat)))
        f.append(("from", "Vector2(%s, %s)" % (num(ends[k][0]), num(ends[k][1]))))
        f.append(("to", "Vector2(%s, %s)" % (num(ends[k + 1][0]), num(ends[k + 1][1]))))
        railings.append(sub("Railing_" + rid + ("_%d" % k if len(ends) > 2 else ""), "4_rail", f))

def ladder(lid, plat, a, b):
    f = []
    if plat != 0:
        f.append(("platform", str(plat)))
    f.append(("from", "Vector2(%s, %s)" % (num(a[0]), num(a[1]))))
    f.append(("to", "Vector2(%s, %s)" % (num(b[0]), num(b[1]))))
    ladders.append(sub("Ladder_" + lid, "7_ladder", f))

# A fish box: the steamer's cargo crate (SH10), the same circle, height, mass and grip.
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

# Her heights (est.): the lower deck — the engine room's plates and the fish hold's
# floor — 2.2 m under the main deck, a stair's 39° rise; the fo'c'sle deck and the
# deckhouse's roof 2.3 m over it, room to stand under; the wheelhouse's top; and the
# working deck's bulwarks, 1 m high. 3.75 m is her half beam; the lower deck's sides —
# the engine room's and the fish hold's linings, the hold's insulated — stand 2.8 m and
# 2.4 m out.
LOWER = -2.2
UPPER = 2.3
WHEEL_TOP = 4.4
BULWARK = 1.0
BEAM = 3.75
LINING = 2.8
HOLD_LINING = 2.4
# Every door onto an open deck is weathertight, over a sill a step high (est.): water on
# deck stands that deep before it runs in.
SILL = 0.3

# --- Platforms. The working deck first: the main deck the lints walk from (D6).
WORK = platform("working_deck", "working deck", -3, 7, -BEAM, BEAM)
AFT = platform("aft_deck", "aft deck", -14.4, -10, -3.3, 3.3)
# The galley's floor, round the two stairs down to the engine room, port and starboard.
ENGINE_STAIRS = [(-7.0, -4.3, -2.7, -1.6), (-7.0, -4.3, 1.6, 2.7)]
GA = platform("galley_aft", "main deck", -10, -7.0, -3.55, 3.55)
GF = platform("galley_forward", "main deck", -4.3, -3, -3.55, 3.55)
GP = platform("galley_port", "main deck", -7.0, -4.3, -3.55, -2.7)
GMID = platform("galley_middle", "main deck", -7.0, -4.3, -1.6, 1.6)
GS = platform("galley_starboard", "main deck", -7.0, -4.3, 2.7, 3.55)
MESS = platform("crew_mess", "main deck", 7, 11, -2.9, 2.9)
F1 = platform("forecastle", "forecastle", 7, 11, -2.9, 2.9, UPPER)
F2 = platform("forecastle_head", "forecastle", 11, 12.5, -2.1, 2.1, UPPER)
# The deckhouse's roof, round the wheelhouse's stair: its floor is the roof. ROOF_AFT
# is a whole number of eighths, so its rectangle ends where the stair starts to the bit.
WHEEL_STAIR = (-7.0, -4.2, -0.55, 0.55)
ROOF_AFT = -10.125
RA = platform("roof_aft", "deckhouse roof", ROOF_AFT, -7.0, -3.65, 3.65, UPPER)
RF = platform("roof_forward", "deckhouse roof", -4.2, -2.9, -3.65, 3.65, UPPER)
RP = platform("roof_port", "deckhouse roof", -7.0, -4.2, -3.65, -0.55, UPPER)
RS = platform("roof_starboard", "deckhouse roof", -7.0, -4.2, 0.55, 3.65, UPPER)
ENGINE_FLOOR = platform("engine_floor", "lower deck", -10.5, -3, -LINING, LINING, LOWER)
HOLD_FLOOR = platform("hold_floor", "lower deck", -3, 7, -HOLD_LINING, HOLD_LINING, LOWER)

# --- Ramps: two up each perch (Q6) — the fo'c'sle from the working deck, the
# deckhouse's roof from the aft deck —, two down from the galley to the engine room,
# and the wheelhouse's own stair up from the galley. Each rises 39°, 1.1 m wide.
ramp("forecastle_port", 4.2, -2.9, 2.8, 1.1, 0, UPPER)
ramp("forecastle_starboard", 4.2, 1.8, 2.8, 1.1, 0, UPPER)
ramp("roof_port", -12.9, -3.0, 2.8, 1.1, 0, UPPER)
ramp("roof_starboard", -12.9, 1.9, 2.8, 1.1, 0, UPPER)
for tag, (x0, x1, z0, z1) in zip(["port", "starboard"], ENGINE_STAIRS):
    ramp("engine_" + tag, x0, z0, x1 - x0, z1 - z0, LOWER, 0)
ramp("wheelhouse_stair", WHEEL_STAIR[0], WHEEL_STAIR[2], WHEEL_STAIR[1] - WHEEL_STAIR[0],
     WHEEL_STAIR[3] - WHEEL_STAIR[2], UPPER, 0)

# --- Blockers. Below the deck: the lower deck's sides and ends, the after watertight
# wall with its door, the forward one, and the engine between two lanes.
wall_x("engine_aft", -10.5, -LINING, LINING, LOWER, 0)
wall_z("engine_port", -LINING, -10.5, -3, LOWER, 0)
wall_z("engine_starboard", LINING, -10.5, -3, LOWER, 0)
wall_z("hold_port", -HOLD_LINING, -3, 7, LOWER, 0)
wall_z("hold_starboard", HOLD_LINING, -3, 7, LOWER, 0)
wall_x_doors("bulkhead_aft", -3, -LINING, LINING, [(-DOOR / 2, DOOR / 2)], LOWER, 0)
wall_x("bulkhead_fwd", 7, -HOLD_LINING, HOLD_LINING, LOWER, 0)
box("engine", -10.0, -7.8, -0.9, 0.9, LOWER, LOWER + 1.5)
# The deckhouse, the full beam of her deck: the galley, a door forward onto the working
# deck and one aft onto the aft deck.
wall_x_doors("deckhouse_aft", -10, -3.55, 3.55, [(-DOOR / 2, DOOR / 2)], 0, UPPER, SILL)
wall_x_doors("deckhouse_forward", -3, -3.55, 3.55, [(0.65, 0.65 + DOOR)], 0, UPPER, SILL)
wall_z("deckhouse_port", -3.55, -10, -3, 0, UPPER)
wall_z("deckhouse_starboard", 3.55, -10, -3, 0, UPPER)
# The wheelhouse on its roof, a door either side, roofed over.
wall_x("wheelhouse_aft", -8, -1.8, 1.8, UPPER, WHEEL_TOP)
wall_x("wheelhouse_forward", -4, -1.8, 1.8, UPPER, WHEEL_TOP)
wall_z_doors("wheelhouse_port", -1.8, -8, -4, [(-6.55, -6.55 + DOOR)], UPPER, WHEEL_TOP, SILL)
wall_z_doors("wheelhouse_starboard", 1.8, -8, -4, [(-6.55, -6.55 + DOOR)], UPPER, WHEEL_TOP, SILL)
box("wheelhouse_roof", -8 - T, -4 + T, -1.8 - T, 1.8 + T, WHEEL_TOP - T, WHEEL_TOP)
# The fo'c'sle: its after face across her deck from bulwark to bulwark, the crew mess's
# door in it; the mess's sides and its forward wall.
wall_x_doors("forecastle_aft", 7, -BEAM + T, BEAM - T, [(-1.55, -1.55 + DOOR)], 0, UPPER, SILL)
wall_z("mess_port", -2.9, 7, 11, 0, UPPER)
wall_z("mess_starboard", 2.9, 7, 11, 0, UPPER)
wall_x("mess_forward", 11, -2.9, 2.9, 0, UPPER)
# On deck: the fish hatch's coaming and cover, a hop up; the engine room's skylight
# on the aft deck; the exhaust stack behind the wheelhouse and the mast on the fo'c'sle.
FISH_HATCH = (1.0, 3.0, -0.9, 0.9)
box("fish_hatch", *FISH_HATCH, 0, 0.6)
SKYLIGHT = (-13.6, -12.6, -0.25, 0.25)
box("skylight", SKYLIGHT[0], SKYLIGHT[1], -0.5, 0.5, 0, 0.5)
cylinder("stack", -9.3, 0, 0.3, UPPER, 6.0)
cylinder("mast", 9.8, 0, 0.15, UPPER, 9.5)

# --- Railings: the working deck's bulwarks, the aft deck's rails, the fo'c'sle's and
# the roof's edges — open where a stair lands, and along the fo'c'sle's after edge,
# a drop onto the working deck as the steamer's — and three sides of every stair hole.
railing("working_port", WORK, (-3, -BEAM), (7, -BEAM))
railing("working_starboard", WORK, (-3, BEAM), (7, BEAM))
railing("aft_port", AFT, (-14.4, -3.3), (-10, -3.3))
railing("aft_starboard", AFT, (-14.4, 3.3), (-10, 3.3))
railing("transom", AFT, (-14.4, -3.3), (-14.4, 3.3))
railing("forecastle_port", F1, (7, -2.9), (11, -2.9))
railing("forecastle_starboard", F1, (7, 2.9), (11, 2.9))
railing("forecastle_step_port", F1, (11, -2.9), (11, -2.1))
railing("forecastle_step_starboard", F1, (11, 2.1), (11, 2.9))
railing("forecastle_head_port", F2, (11, -2.1), (12.5, -2.1))
railing("forecastle_head_starboard", F2, (11, 2.1), (12.5, 2.1))
railing("forecastle_head_fwd", F2, (12.5, -2.1), (12.5, 2.1))
for tag, z in [("port", -3.65), ("starboard", 3.65)]:
    railing("roof_aft_" + tag, RA, (ROOF_AFT, z), (-7.0, z))
    railing("roof_middle_" + tag, RP if z < 0 else RS, (-7.0, z), (-4.2, z))
    railing("roof_forward_" + tag, RF, (-4.2, z), (-2.9, z))
railing("roof_fwd", RF, (-2.9, -3.65), (-2.9, 3.65))
railing("roof_aft_end_port", RA, (ROOF_AFT, -3.65), (ROOF_AFT, -3.0))
railing("roof_aft_end_middle", RA, (ROOF_AFT, -1.9), (ROOF_AFT, 1.9))
railing("roof_aft_end_starboard", RA, (ROOF_AFT, 3.0), (ROOF_AFT, 3.65))
for tag, (x0, x1, z0, z1), side in [("port", ENGINE_STAIRS[0], GP), ("starboard", ENGINE_STAIRS[1], GS)]:
    railing("engine_stair_%s_aft" % tag, GA, (x0, z0), (x0, z1))
    railing("engine_stair_%s_outboard" % tag, side, (x0, z0 if side == GP else z1),
            (x1, z0 if side == GP else z1))
    railing("engine_stair_%s_inboard" % tag, GMID, (x0, z1 if side == GP else z0),
            (x1, z1 if side == GP else z0))
railing("wheelhouse_stair_port", RP, (WHEEL_STAIR[0], WHEEL_STAIR[2]), (WHEEL_STAIR[1], WHEEL_STAIR[2]))
railing("wheelhouse_stair_starboard", RS, (WHEEL_STAIR[0], WHEEL_STAIR[3]), (WHEEL_STAIR[1], WHEEL_STAIR[3]))
railing("wheelhouse_stair_fwd", RF, (WHEEL_STAIR[1], WHEEL_STAIR[2]), (WHEEL_STAIR[1], WHEEL_STAIR[3]))

# --- Boarding ladders, one down each side of the working deck: her deck stands 1.2 m
# out of the sea, but over the bulwark a swimmer needs one (SH5).
ladder("port", WORK, (1.0, -BEAM), (2.0, -BEAM))
ladder("starboard", WORK, (1.0, BEAM), (2.0, BEAM))

# --- Two fish boxes on the working deck, against her bulwarks.
crate("deck_port", -1.6, 0, -3.0)
crate("deck_starboard", 0.2, 0, 3.0)

# --- Rooms, to the middle of their walls.
room("engine_room", "engine room", -10.5, -3, -LINING, LINING, LOWER)
room("fish_hold", "fish hold", -3, 7, -HOLD_LINING, HOLD_LINING, LOWER)
room("galley", "galley", -10, -3, -3.55, 3.55, 0)
room("wheelhouse", "wheelhouse", -8, -4, -1.8, 1.8, UPPER)
room("crew_mess", "crew mess", 7, 11, -2.9, 2.9, 0)

# Eight seats: six on the working deck, one on the fo'c'sle, one on the aft deck.
spawns = [
    (-2.0, 0, -1.5), (-2.0, 0, 1.5), (0.0, 0, 0.0), (2.0, 0, -2.4), (2.0, 0, 2.4), (5.0, 0, 0.0),
    (9.0, UPPER, -1.0), (-11.5, 0, 0.0),
]
# The seats a match on her takes (est.): the steamer's 4–8 — SH21's bounds start here.
SEATS = (4, 8)

def arr(script, ids):
    return "Array[ExtResource(\"%s\")]([%s])" % (script, ", ".join('SubResource("%s")' % i for i in ids))

# --- The structure (§5b.2), est. throughout: her hull, lofted here from her
# dimensions; her cells, walls, openings and mass. `make ship-check` floats her on it,
# level, at her waterline, and sinks her on her sure hit.
FREEBOARD = 1.2
WATERLINE = -FREEBOARD
KEEL = -4.2  # 3.0 m of draught
X_AFT, X_FORE = -15.0, 15.0  # her transom at the deck, her stem's head
# Her lines (est.): a full, round-bilged midship section — a superellipse of power
# BILGE from her deck down to her keel — its waterlines closing on the stem past
# FORE_SHOULDER (at her deck, at her keel: bluff above, finer below), as one minus the
# square of the way there, and on the transom past AFT_SHOULDER, to TRANSOM_SHARE of her
# breadth (over the transom's lower edge, at her keel). A raked stem STEM_RAKE aft per
# metre down from its head to STEM_KNEE, rounding into her keel at X_FOOT; a transom
# whose lower edge stands at Y_TRANSOM, the run under it sweeping up from her keel at
# X_POST.
BILGE = 2.0
FORE_SHOULDER = (9.0, 1.0)
AFT_SHOULDER = -7.0
TRANSOM_SHARE = (0.9, 0.2)
STEM_RAKE = 0.47
STEM_KNEE = -2.5
X_FOOT = 11.5
X_POST = -12.5
Y_TRANSOM = -0.9

def clamp(v, a, b):
    return min(max(v, a), b)

def lerp(a, b, t):
    return a + (b - a) * t

def stem_x(y):
    line = X_FORE - (UPPER - y) * STEM_RAKE
    if y >= STEM_KNEE:
        return line
    knee = X_FORE - (UPPER - STEM_KNEE) * STEM_RAKE
    share = (STEM_KNEE - y) / (STEM_KNEE - KEEL)
    return X_FOOT + (knee - X_FOOT) * math.sqrt(max(1.0 - share * share, 0.0))

def bottom(x):
    """Her lowest point at x: her keel, the run swept up to her transom, or her stem."""
    if x > X_FOOT:
        low, high = KEEL, UPPER
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
    """Her shell's top at x: the fo'c'sle, the working deck's bulwarks, or her deck."""
    if x > 7:
        return UPPER
    if x > -3:
        return BULWARK
    return 0.0

# The houses on her deck, enclosed: (x0, x1, half breadth, foot, top) — to their walls'
# outer faces across her, to their cells' ends along her.
HOUSES = [(-10 - T, -3, 3.55 + T, 0.0, UPPER), (-8 - T, -4 + T, 1.8 + T, UPPER, WHEEL_TOP)]
SIDE_POINTS = 14
# Sections stand for no more than SECTION_MAX of hull, between her ends and every
# cell's, so no cell splits a section: 20 of them.
SECTION_MAX = 1.7
SECTION_BREAKS = [X_AFT, -10 - T, -8 - T, -4 + T, -3, 7, X_FORE]
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

# Every deck in her hull stands inside it, at its corners: one under her deck clear of
# her shell, the walls along its edges with it; one on her deck no wider than her.
CLEARANCE = 0.05
for x0, x1, z0, z1, h in plat_geo:
    for x in (x0 + 0.01, x1 - 0.01):
        if h <= sheer(x):
            room_for = max(-z0, z1) + (CLEARANCE + T if h < 0 else 0.0)
            assert breadth(x, h) >= room_for - 1e-9, ("platform outside her", x, h)

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
# kind's). Three compartments from her keel to her deck — the fo'c'sle's reaching up to
# its deck, its crew mess at the main deck's height over the stores below it —, the
# engine room and the fish hold each between two wing spaces outboard of their linings,
# nobody's (the plan's lengthwise wall in a wide cell, R23: a gash biting less deep than
# a wing is wide floods that side alone, and she lists); the deckhouse and the
# wheelhouse on her deck; and the working deck between its bulwarks, an open well: it
# holds water once the sea comes over its edge or in at its freeing ports, and lets it
# out at them (the Gaul's deck).
CELLS = [
    ("engine_wing_p", X_AFT, -3, KEEL, 0, -BEAM, -LINING, "VOID", None),
    ("engine_room", X_AFT, -3, KEEL, 0, -LINING, LINING, "MACHINERY", None),
    ("engine_wing_s", X_AFT, -3, KEEL, 0, LINING, BEAM, "VOID", None),
    ("hold_wing_p", -3, 7, KEEL, 0, -BEAM, -HOLD_LINING, "VOID", None),
    ("fish_hold", -3, 7, KEEL, 0, -HOLD_LINING, HOLD_LINING, "CARGO", 0.9),  # empty of fish: 0.90
    ("hold_wing_s", -3, 7, KEEL, 0, HOLD_LINING, BEAM, "VOID", None),
    ("fore", 7, X_FORE, KEEL, UPPER, -BEAM, BEAM, "ACCOMMODATION", None),
    ("deckhouse", -10 - T, -3, 0, UPPER, -3.55 - T, 3.55 + T, "ACCOMMODATION", None),
    ("wheelhouse", -8 - T, -4 + T, UPPER, WHEEL_TOP, -1.8 - T, 1.8 + T, "ACCOMMODATION", None),
    ("working_deck", -3, 7, 0, BULWARK, -BEAM, BEAM, "OPEN_WELL", None),
]
KINDS = ["ACCOMMODATION", "MACHINERY", "CARGO", "STORES", "VOID", "BUNKER", "OPEN_WELL"]
# Where the sea comes over the working deck in a seaway (green water, ShippedWater): the
# tops of her bulwarks, uncut, along both sides of the well — the deckhouse and the
# fo'c'sle close its ends, standing over them. Each edge its two ends.
SHIPPING_EDGES = {
    "working_deck": [((-3, BULWARK, side * BEAM), (7, BULWARK, side * BEAM)) for side in (-1, 1)],
}
# Air leaks out through rivets, seams and vents: 10⁻³ m² per 1 000 m³ (est.).
AIR_LEAK = 1e-6

def cell_at(x, y, z):
    for c in CELLS:
        if c[1] < x < c[2] and c[3] < y < c[4] and c[5] < z < c[6]:
            return c[0]
    return None

def cell_box(name):
    return next(c for c in CELLS if c[0] == name)[1:7]

# Her two watertight walls across her, to her deck: (name, x, top, collapse head est.);
# and the linings along her, leaky (est.): (name, z, from x, to x, top, collapse head),
# each from the deck's end over it.
BULKHEADS = [("bulkhead_aft", -3, 0.0, 5.0), ("bulkhead_fwd", 7, 0.0, 5.0)]
LININGS = [("engine_lining_p", -LINING, -14.4, -3, 0.0, 2.0), ("engine_lining_s", LINING, -14.4, -3, 0.0, 2.0),
           ("hold_lining_p", -HOLD_LINING, -3, 7, 0.0, 2.0), ("hold_lining_s", HOLD_LINING, -3, 7, 0.0, 2.0)]
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
    half = round(breadth(x, top), 4)
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
# seven (est.), giving way under 4 m of water. A doorway into a house over the working
# deck opens onto the well up to its bulwarks and onto the sky above them: one opening
# for each.
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
                    shuts_at_hit=True, shut_time=10.0, flip_chance=0.15, collapse_head=4.0)
            continue
        tag = "door_%s_%s" % (a, b or SKY)
        opening("%s_%d" % (tag, sum(1 for o in openings if o[0].startswith(tag))), "DOOR", a, b,
                centre, size, starts="OPEN")

# Holes in her decks: the stairs — water on a floor runs down them — and the fish
# hatch, battened, left open one time in three (est.), giving way under 1 m of water.
for tag, (x0, x1, z0, z1) in zip(["p", "s"], ENGINE_STAIRS):
    opening("stair_engine_room_deckhouse_" + tag, "STAIRWELL", "engine_room", "deckhouse",
            ((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5), (x1 - x0, 0, z1 - z0), starts="OPEN")
x0, x1, z0, z1 = WHEEL_STAIR
opening("stair_deckhouse_wheelhouse", "STAIRWELL", "deckhouse", "wheelhouse",
        ((x0 + x1) * 0.5, UPPER, (z0 + z1) * 0.5), (x1 - x0, 0, z1 - z0), starts="OPEN")
x0, x1, z0, z1 = FISH_HATCH
opening("fish_hatch", "HATCH", "fish_hold", "working_deck", ((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5),
        (x1 - x0, 0, z1 - z0), starts="SHUT", flip_chance=0.3, collapse_head=1.0)
# The engine room's skylight, under its casing on the aft deck: always open (0.5 m²).
x0, x1, z0, z1 = SKYLIGHT
opening("skylight", "VENT", "engine_room", SKY, ((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5),
        (x1 - x0, 0, z1 - z0), starts="OPEN")
# The working deck's freeing ports, three a side at its bulwarks' foot, 0.6 m² in all
# (est.); and its top, open to the sky over the bulwarks.
FREEING_PORT = (0.5, 0.2)
FREEING_PORTS_X = [-1.5, 2.5, 5.5]
for tag, z in [("p", -BEAM), ("s", BEAM)]:
    for k, x in enumerate(FREEING_PORTS_X):
        opening("freeing_port_%s%d" % (tag, k + 1), "FREEING_PORT", "working_deck", SEA,
                (x, FREEING_PORT[1] * 0.5, z), (FREEING_PORT[0], FREEING_PORT[1], 0), starts="OPEN")
# The wings' leaks through their linings, and the air pipe each breathes through to her
# deck, a 100 mm pipe (est., as the steamer's peaks'): the hold's into the well over it,
# the engine room's onto the aft deck.
AIR_PIPE = 0.008
for wing, inner, pipe_x in [("engine_wing_p", "engine_room", -12.0), ("engine_wing_s", "engine_room", -12.0),
                            ("hold_wing_p", "fish_hold", 2.0), ("hold_wing_s", "fish_hold", 2.0)]:
    b = cell_box(inner)
    w = cell_box(wing)
    z = b[4] if w[4] < b[4] else b[5]
    opening("leak_" + wing, "LEAK", wing, inner, ((b[0] + b[1]) * 0.5, (b[2] + b[3]) * 0.5, z),
            (b[1] - b[0], b[3] - b[2], 0), area=WING_LEAK, starts="OPEN")
    over = cell_at(pipe_x, w[3] + 0.01, (w[4] + w[5]) * 0.5)
    opening("pipe_" + wing, "VENT", wing, over, (pipe_x, w[3], (w[4] + w[5]) * 0.5), (0.09, 0, 0.09),
            area=AIR_PIPE, starts="OPEN")
well = cell_box("working_deck")
opening("open_working_deck", "OPEN", "working_deck", SKY,
        ((well[0] + well[1]) * 0.5, well[3], (well[4] + well[5]) * 0.5),
        (well[1] - well[0], 0, well[5] - well[4]), starts="OPEN")
# A porthole either side of the crew mess, in the fo'c'sle's shell: shut, left open one
# time in four (est.).
PORTHOLE_RADIUS = 0.16
PORTHOLE_AT = (9.0, 1.2)
for tag, side in [("p", -1), ("s", 1)]:
    skin = round(breadth(*PORTHOLE_AT), 4)
    opening("port_fore_%s1" % tag, "PORTHOLE", "fore", SEA, (PORTHOLE_AT[0], PORTHOLE_AT[1], side * skin),
            (PORTHOLE_RADIUS * 2, PORTHOLE_RADIUS * 2, 0), area=round(math.pi * PORTHOLE_RADIUS ** 2, 4),
            starts="SHUT", flip_chance=0.25, collapse_head=15.0)

# Mass (est.): where her weight sits — about 385 t, her GM about 0.6 m, the plan's, within
# the research's 0.5–1.0 m for a 30 m trawler. Her ballast is what the generator settles:
# as heavy as she must be to float at her waterline, and where along and across her it
# puts her weight over her lift, so she floats there level.
with open("data/physics/sea.tres") as sea_file:
    SEA_DENSITY = float(re.search(r"^sea_density = (\S+)$", sea_file.read(), re.M).group(1))
displaced = along = across = 0.0
for x, length, outline in sections:
    under = clip(outline, 1, WATERLINE, True)
    if len(under) >= 3:
        area, z, _y = area_and_centre(under)
        displaced += area * length
        along += area * length * x
        across += area * length * z
MASS = [  # (name, kg, centre, (from x, to x))
    ("hull steel", 180e3, (-0.5, -0.65, 0.0), (-15, 15)),
    ("engine and gearbox", 35e3, (-8.9, -1.6, 0.0), (-10, -7.8)),
    ("fuel", 25e3, (-6.5, -3.4, 0.0), (-10, -3)),
    ("deckhouse and wheelhouse", 25e3, (-6.5, 1.8, 0.0), (-10, -3)),
    ("winch and fishing gear", 30e3, (-1.0, 1.8, 0.0), (-3, 1)),
    ("mast and rigging", 4e3, (9.8, 5.5, 0.0), (9.5, 10.1)),
    ("fish hold insulation and ice", 15e3, (2.0, -1.8, 0.0), (-3, 7)),
    ("stores and water", 10e3, (9.0, -1.0, 0.0), (7, 11)),
]
BALLAST_Y = KEEL + 0.3
BALLAST_REACH = 4.0  # either side of its centre
weight = displaced * SEA_DENSITY
ballast = weight - sum(m[1] for m in MASS)
ballast_x = (weight * along / displaced - sum(m[1] * m[2][0] for m in MASS)) / ballast
ballast_z = (weight * across / displaced - sum(m[1] * m[2][2] for m in MASS)) / ballast
assert ballast > 0, "she is heavier than she floats"
assert cell_at(ballast_x, BALLAST_Y, ballast_z), "her solved ballast must lie in one of her cells"
MASS.append(("ballast", round(ballast, 1), (round(ballast_x, 4), BALLAST_Y, round(ballast_z, 4)),
             (round(ballast_x - BALLAST_REACH, 4), round(ballast_x + BALLAST_REACH, 4))))
# How her mass turns, the water moving with her, and how her motions die away (est.:
# roll 0.4 of her beam, pitch 0.25 of her length; the steamer's added mass and damping).
MOTION = [("roll_radius", 3.0), ("pitch_radius", 7.5), ("added_mass", 1.0),
          ("heave_damping", 0.5), ("roll_damping", 0.08), ("pitch_damping", 0.5)]
# A liferaft either side on the deckhouse's roof, useless on the high side past a list
# of 20° — modern rules (§5b.2).
LIFEBOATS = [("liferaft_port", -1, -6.0, 20.0), ("liferaft_starboard", 1, -6.0, 20.0)]
# Where along her and up her shell an iceberg's gash can be at all (est.): clear of her
# stem and her transom, from 0.2 m under her deck down to 0.2 m over her keel.
HIT_ZONE_X = (-14.5, 14.5)
HIT_ZONE_Y = (KEEL + 0.2, -0.2)
# The must-sink rule's last rung (§5b.1, est.): a 16 m gash down her starboard side
# from the engine room into the fish hold, 1 m under her waterline, 60 mm as one even
# slit and biting 1 m in, every door and porthole shut. `make ship-check` proves she
# founders on it within the bake's cap.
SURE_HIT = [("start_x", -10), ("length", 16), ("depth_start", 1), ("depth_end", 1),
            ("width", 0.06), ("bite", 1)]

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
    if name in SHIPPING_EDGES:
        ends = [num(c) for edge in SHIPPING_EDGES[name] for end in edge for c in end]
        f.append(("shipping_edges", "PackedVector3Array(%s)" % ", ".join(ends)))
    cell_ids.append(sub("Cell_" + name, "11_cell", f))
wall_ids = []
for name, axis, at, span, bottom_y, top, collapse, parts in walls:
    f = [("name", '&"%s"' % name)]
    if axis == "ALONG":
        f.append(("axis", "1"))
    f += [("at", num(at)), ("span", "Vector2(%s, %s)" % (num(span[0]), num(span[1]))),
          ("bottom", num(bottom_y)), ("top", num(top)), ("collapse_head", num(collapse)),
          ("cells", names(parts))]
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
    for key in ["shut_time", "collapse_head"]:
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
"""
res = ["[resource]", 'script = ExtResource("5_layout")', "freeboard = " + num(FREEBOARD),
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
      "masses: %.1f t, ballast %.1f t at x %.3f z %.3f" % (weight / 1000, ballast / 1000, ballast_x, ballast_z))
