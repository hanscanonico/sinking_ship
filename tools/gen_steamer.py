#!/usr/bin/env python3
"""Writes the steamer's layout and structure, data/ships/steamer.tres.

The layout and structure are generated: change the ship here, then `make ship`.
`make ship-check` (part of `make verify`) fails when the committed .tres is not what
this writes, so a hand edit to the .tres is caught. The sim reads only the .tres (D6).

Ship-local metres: x toward the bow, z to starboard, y up, origin on the main deck
amidships. The numbers that shape the rooms are the constants and calls below:
DOOR (a doorway's width), LOWER (the lower deck's height), LINTEL (a door's height),
T (half a wall's thickness), and each wall_*_doors call's door gaps.

Usage: tools/gen_steamer.py <out.tres>
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
# platform; (x0, x1, z0, z1, axis, start, end) per ramp; (x0, x1, z0, z1, bottom, top,
# whether a box) per blocker's plan; (x0, x1, z0, z1, floor, name) per room; and every
# doorway as (axis, at, from, to, bottom): a gap in a wall along x = at (axis 0) or
# z = at (axis 2).
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

def ramp(rid, x, z, w, d, axis, start, end):
    ramp_geo.append((x, x + w, z, z + d, axis, start, end))
    f = [("area", rect(x, z, w, d))]
    if axis == 1:
        f.append(("axis", "1"))
    if start != 0.0:
        f.append(("start_height", num(start)))
    if end != 0.0:
        f.append(("end_height", num(end)))
    ramps.append(sub("Ramp_" + rid, "2_ramp", f))

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

# A railing breaks span by span (SH10): a run longer than RAIL_SECTION is laid as
# touching spans of about that length, half-metre ends, none longer — a crate or
# three vaults open a stretch of a side, never all of it.
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
# A cargo crate (SH10): a 0.45 m circle, 0.8 m tall — a hop up, as onto the hatch —
# of 200 kg against a brawler's 80, holding on the deck to 8°: past the early list,
# short of a lurch's swing.
CRATE = [("radius", 0.45), ("height", 0.8), ("mass", 200), ("grip_angle_deg", 8), ("friction", 2.5)]
DOOR = 1.1
LOWER = -2.6
LINTEL = 2.1  # a door's height above its floor

def wall_x(bid, x, z0, z1, bottom, top):
    """A wall along x = const from z0 to z1 (centre line), ends overlapping corners."""
    box(bid, x - T, x + T, z0 - T, z1 + T, bottom, top)

def wall_z(bid, z, x0, x1, bottom, top):
    box(bid, x0 - T, x1 + T, z - T, z + T, bottom, top)

def wall_x_doors(bid, x, z0, z1, doors, bottom, top):
    """Wall pieces along x = const with door gaps [(a, b)] in z; a lintel over each."""
    edges = [z0 - T] + [v for d in doors for v in d] + [z1 + T]
    for i in range(0, len(edges), 2):
        box("%s_%d" % (bid, i // 2), x - T, x + T, edges[i], edges[i + 1], bottom, top)
    for i, d in enumerate(doors):
        box("%s_lintel_%d" % (bid, i), x - T, x + T, d[0], d[1], bottom + LINTEL, top)
        doorways.append((0, x, d[0], d[1], bottom))

def wall_z_doors(bid, z, x0, x1, doors, bottom, top):
    edges = [x0 - T] + [v for d in doors for v in d] + [x1 + T]
    for i in range(0, len(edges), 2):
        box("%s_%d" % (bid, i // 2), edges[i], edges[i + 1], z - T, z + T, bottom, top)
    for i, d in enumerate(doors):
        box("%s_lintel_%d" % (bid, i), d[0], d[1], z - T, z + T, bottom + LINTEL, top)
        doorways.append((2, z, d[0], d[1], bottom))

# --- Platforms. The first five are SH3's, in SH3's order; the main deck is now
# rectangles round three stair openings, every one of them named "main deck".
MAIN = platform("main_deck", "main deck", -14, 12, -5, -1.6)  # the port strip
POOP = platform("poop_deck", "poop deck", -20, -14, -4.5, 4.5, 1.2)
FCSL = platform("forecastle", "forecastle", 12, 20, -4, 4, 1.8)
BOAT = platform("boat_deck", "boat deck", -7, 3, -3.4, 3.4, 2.5)
BRIDGE = platform("bridge", "bridge", -4, -1, -1.5, 1.5, 4.7)
# The three stair openings it leaves, (x0, x1, z0, z1): the aft companionway, the
# inner stair, the forward companionway.
STAIR_HOLES = [(-12.85, -10.25, -0.55, 0.55), (-1.25, -0.15, -1.6, 1.0), (9, 12, 0.9, 2.0)]
SS = platform("main_deck_starboard", "main deck", -14, 12, 2.0, 5)
MA = platform("main_deck_aft", "main deck", -14, -12.85, -1.6, 2.0)
MB1 = platform("main_deck_aft_port", "main deck", -12.85, -10.25, -1.6, -0.55)
MB2 = platform("main_deck_aft_starboard", "main deck", -12.85, -10.25, 0.55, 2.0)
MC = platform("main_deck_waist", "main deck", -10.25, -1.25, -1.6, 2.0)
MD = platform("main_deck_hall", "main deck", -1.25, -0.15, 1.0, 2.0)
ME = platform("main_deck_forward", "main deck", -0.15, 9.0, -1.6, 2.0)
MF = platform("main_deck_bow", "main deck", 9.0, 12, -1.6, 0.9)
L1 = platform("lower_deck", "lower deck", -13, 4, -4.8, 4.8, LOWER)
L2 = platform("hold", "lower deck", 4, 15, -3.8, 3.8, LOWER)

# --- Ramps: SH3's six, then the three stairs (39°, 1.1 m wide).
ramp("poop_port", -14, -4.5, 3, 1.4, 0, 1.2, 0)
ramp("poop_starboard", -14, 3.1, 3, 1.4, 0, 1.2, 0)
ramp("boat_port", 3, -3.4, 6, 1.5, 0, 2.5, 0)
ramp("boat_starboard", 3, 1.9, 6, 1.5, 0, 2.5, 0)
ramp("forecastle", 9, -0.8, 3, 1.6, 0, 0, 1.8)
# The bridge's two ways up (Q6): from SH26 nothing times the bridge's fall, so it is a
# perch like any other and needs two routes — two stairs, one to port and one to
# starboard, side by side down its forward face, each as steep and as wide as the one
# stair it had; a steep ladder on the starboard side of the wheelhouse would stand at
# the boat deck's open edge.
ramp("bridge", -1, -1.5, 3, 1.4, 0, 4.7, 2.5)
ramp("bridge_starboard", -1, 0.1, 3, 1.4, 0, 4.7, 2.5)
ramp("aft_companionway", -12.85, -0.55, 3.2, 1.1, 0, 0, LOWER)
ramp("inner_stair", -1.25, -1.6, 1.1, 3.2, 1, 0, LOWER)
ramp("forward_companionway", 9.0, 0.9, 3.2, 1.1, 0, 0, LOWER)

# --- Blockers: SH3's funnel (now through the deckhouse), mast and hatch.
cylinder("funnel", -6, 0, 0.9, 0, 7.5)
cylinder("mast", 16, 0, 0.2, 1.8, 11)
HATCH = (4, 8, -1, 1)  # x0, x1, z0, z1: the hold's hatch, its cover 0.8 m over the deck
box("hatch", *HATCH, 0, 0.8)
# The forecastle's after face: the hold runs on beneath it.
box("forecastle_break", 12, 12.2, -4, 4, 0, 1.8)

# Hull below the main deck.
wall_x("hull_aft", -13, -4.8, 4.8, LOWER, 0)
wall_z("hull_port", -4.8, -13, 4, LOWER, 0)
wall_z("hull_starboard", 4.8, -13, 4, LOWER, 0)
wall_z("hold_port", -3.8, 4, 12 - T, LOWER, 0)
wall_z("hold_starboard", 3.8, 4, 12 - T, LOWER, 0)
box("hold_port_forward", 12, 15 + T, -3.8 - T, -3.8 + T, LOWER, 1.8)
box("hold_starboard_forward", 12, 15 + T, 3.8 - T, 3.8 + T, LOWER, 1.8)
wall_x("hold_forward", 15, -3.8, 3.8, LOWER, 1.8)
# Bulkheads, a doorway in each.
centre_door = [(-DOOR / 2, DOOR / 2)]
wall_x_doors("bulkhead_hold", 4, -4.8, 4.8, centre_door, LOWER, 0)
wall_x_doors("bulkhead_engine", -3, -4.8, 4.8, centre_door, LOWER, 0)
# The engine block splits the engine room into two lanes.
box("engine", 0, 2.5, -1.2, 1.2, LOWER, -0.8)
# Passenger cabins off the corridor (z -0.7..0.7), three a side.
cabin_doors = [(-9.6, -8.5), (-7.6, -6.5), (-4.9, -3.8)]
wall_z_doors("corridor_port", -0.7, -13, -3, cabin_doors, LOWER, 0)
wall_z_doors("corridor_starboard", 0.7, -13, -3, cabin_doors, LOWER, 0)
for x, tag in [(-8.4, "aft"), (-5.7, "forward")]:
    wall_x("cabins_port_" + tag, x, -4.8, -0.7, LOWER, 0)
    wall_x("cabins_starboard_" + tag, x, 0.7, 4.8, LOWER, 0)

# The deckhouse (x -7..3, z -3.4..3.4): saloon forward, a hall and four cabins aft.
DH = 0.0
DTOP = 2.5
wall_x("deckhouse_aft", -6.9, -3.3, 3.3, DH, DTOP)
wall_x_doors("deckhouse_forward", 2.9, -3.3, 3.3, centre_door, DH, DTOP)
side_doors = [(-1.4, -0.3), (1.0, 2.1)]
wall_z_doors("deckhouse_port", -3.3, -6.9, 2.9, side_doors, DH, DTOP)
wall_z_doors("deckhouse_starboard", 3.3, -6.9, 2.9, side_doors, DH, DTOP)
wall_x_doors("saloon_aft", 0, -3.3, 3.3, [(1.6, 2.7)], DH, DTOP)
hall_doors = [(-3.0, -1.9), (-1.35, -0.25), (0.25, 1.35), (1.9, 3.0)]
wall_x_doors("hall_aft", -3.4, -3.3, 3.3, hall_doors, DH, DTOP)
for z, tag in [(-1.65, "port"), (0.0, "middle"), (1.65, "starboard")]:
    wall_z("deckhouse_cabins_" + tag, z, -6.9, -3.4, DH, DTOP)

# The wheelhouse under the bridge, doors port and starboard.
WH = 2.5
WTOP = 4.7
wall_x("wheelhouse_aft", -3.9, -1.4, 1.4, WH, WTOP)
wall_x("wheelhouse_forward", -1.1, -1.4, 1.4, WH, WTOP)
wall_z_doors("wheelhouse_port", -1.4, -3.9, -1.1, [(-3.05, -1.95)], WH, WTOP)
wall_z_doors("wheelhouse_starboard", 1.4, -3.9, -1.1, [(-3.05, -1.95)], WH, WTOP)

# --- Railings: SH3's along the main deck's sides and ends, the poop and the
# forecastle, then three sides of each stair opening.
railing("main_port_aft", MAIN, (-14, -5), (3.5, -5))
railing("main_port_fwd", MAIN, (5.5, -5), (12, -5))
railing("main_starboard_aft", SS, (-14, 5), (3.5, 5))
railing("main_starboard_fwd", SS, (5.5, 5), (12, 5))
railing("main_aft_port", MAIN, (-14, -5), (-14, -4.5))
railing("main_aft_starboard", SS, (-14, 4.5), (-14, 5))
railing("main_fwd_port", MAIN, (12, -5), (12, -4))
railing("main_fwd_starboard", SS, (12, 4), (12, 5))
railing("poop_aft", POOP, (-20, -4.5), (-20, 4.5))
railing("poop_port", POOP, (-20, -4.5), (-14, -4.5))
railing("poop_starboard", POOP, (-20, 4.5), (-14, 4.5))
railing("forecastle_fwd", FCSL, (20, -4), (20, 4))
railing("forecastle_port", FCSL, (12, -4), (20, -4))
railing("forecastle_starboard", FCSL, (12, 4), (20, 4))
railing("aft_companionway_port", MB1, (-12.85, -0.55), (-10.25, -0.55))
railing("aft_companionway_starboard", MB2, (-12.85, 0.55), (-10.25, 0.55))
railing("aft_companionway_forward", MC, (-10.25, -0.55), (-10.25, 0.55))
railing("inner_stair_aft", MC, (-1.25, -1.6), (-1.25, 1.0))
railing("inner_stair_forward", ME, (-0.15, -1.6), (-0.15, 1.0))
railing("inner_stair_starboard", MD, (-1.25, 1.0), (-0.15, 1.0))
railing("forward_companionway_port", MF, (9, 0.9), (12, 0.9))
railing("forward_companionway_starboard", SS, (9, 2.0), (12, 2.0))

# --- Boarding ladders (SH5), one down each side amidships, beside the railing
# gaps where bodies go over: the main deck stands 3.4 m out of the sea, far past a
# swimmer's reach, so without them nobody who goes over the side before the bow is
# down (about 1:25) has anywhere to climb out. A climb up one takes ~2.2 s.
ladder("port", MAIN, (1.0, -5), (2.2, -5))
ladder("starboard", SS, (1.0, 5), (2.2, 5))

# --- The hatch's cargo (SH10): two crates on its lid, and two stowed on deck forward
# of it to port, clear of the boat deck's stairs, the forecastle's and the lanes
# round the hatch — the forward cargo a lurch to port sends into the port rail.
crate("hatch_aft", 5.2, 0.8, -0.45)
crate("hatch_forward", 6.8, 0.8, 0.45)
crate("forward_inboard", 10.0, 0, -2.4)
crate("forward_outboard", 11.0, 0, -3.6)

# --- Rooms, to the middle of their walls.
room("forward_hold", "forward hold", 4, 15, -3.8, 3.8, LOWER)
room("engine_room", "engine room", -3, 4, -4.8, 4.8, LOWER)
room("cabin_corridor", "cabin corridor", -13, -3, -0.7, 0.7, LOWER)
for side, z0, z1 in [("port", -4.8, -0.7), ("starboard", 0.7, 4.8)]:
    for tag, x0, x1 in [("aft", -13, -8.4), ("middle", -8.4, -5.7), ("forward", -5.7, -3)]:
        room("cabin_%s_%s" % (side, tag), "%s %s cabin" % (tag, side), x0, x1, z0, z1, LOWER)
room("saloon", "saloon", 0, 2.9, -3.3, 3.3, DH)
room("deckhouse_hall", "deckhouse hall", -3.4, 0, -3.3, 3.3, DH)
for i, (z0, z1) in enumerate([(-3.3, -1.65), (-1.65, 0), (0, 1.65), (1.65, 3.3)]):
    room("deckhouse_cabin_%d" % (i + 1), "deckhouse cabin %d" % (i + 1), -6.9, -3.4, z0, z1, DH)
room("wheelhouse", "wheelhouse", -3.9, -1.1, -1.4, 1.4, WH)

spawns = [
    (8, LOWER, -2), (-2, LOWER, -3.5), (-7, LOWER, 2.8),
    (1.5, 0, -1.5), (-2.5, 0, 2.2),
    (-17.5, 1.2, -2.5), (-5, 0, -4.3), (6.5, 0, 4.2),
]

def arr(script, ids):
    return "Array[ExtResource(\"%s\")]([%s])" % (script, ", ".join('SubResource("%s")' % i for i in ids))

# --- The structure (§5b.2): the physics' view of the same hull — its sections, its
# cells, its watertight walls, its openings and its mass, which the sinking physics
# reads; `make ship-check` floats her on it, level, at her waterline, and sinks her on
# her sure hit. Numbers marked est. are starting values, tuned as the physics reads them.
FREEBOARD = 3.4
WATERLINE = -FREEBOARD
POOP_DECK = plat_geo[POOP][4]
FCSL_DECK = plat_geo[FCSL][4]

def smoothstep(a, b, v):
    t = min(max((v - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)

def lerp(a, b, t):
    return a + (b - a) * t

SLIVER = 0.01
PLANK = 0.06  # ShipArt.PLANK

def envelope(x):
    """The decks' outline across the ship at x, as ShipSpace.envelope: [port z,
    starboard z, port height, starboard height], or None where no deck stands."""
    shape = None
    for x0, x1, z0, z1, h in plat_geo:
        if x <= x0 or x >= x1:
            continue
        if shape is None:
            shape = [z0, z1, h, h]
            continue
        if z0 < shape[0] - SLIVER or (abs(z0 - shape[0]) <= SLIVER and h > shape[2]):
            shape[0], shape[2] = z0, h
        if z1 > shape[1] + SLIVER or (abs(z1 - shape[1]) <= SLIVER and h > shape[3]):
            shape[1], shape[3] = z1, h
    return shape

class Hull:
    """The hull as ShipHull lofts and draws it round the decks
    (scenes/art/ship_hull.gd), with the art's own numbers: its half breadth at
    (x, y), its keel, its stem and its counter, and its drawn faces cut across at
    any x — what the sections are, so they are the drawn hull's. `make art-lint`
    holds the two together."""
    DRAFT = 2.0
    KEEL_CLEARANCE = 0.4
    CONTENT_CLEARANCE = 0.12
    CONTENT_FALL = (1.2, 0.4)
    BILGE = 4.0
    FLARE = 2.2
    FAIR = 0.15
    TAPER = 2.0
    STEM_LEAD, STEM_HEAD, ENTRANCE, FOREFOOT = 0.6, 1.2, 7.5, 2.5
    TURTLE, FALL_AWAY = 1.2, 1.3
    COUNTER_LEAD, KNUCKLE, COUNTER_LIFT = 0.5, 0.7, 0.15
    STERNPOST, RUN, COUNTER_BLEND = 1.6, 5.5, 0.5
    SECTION_POINTS, TOP_RINGS, RING_POINTS, STATION_SPACING = 14, 4, 8, 0.4

    def __init__(self):
        self.span = (min(p[0] for p in plat_geo), max(p[1] for p in plat_geo))
        self.fore = envelope(self.span[1] - SLIVER)
        self.aft = envelope(self.span[0] + SLIVER)
        fore_edge = max(-self.fore[0], self.fore[1])
        aft_edge = max(-self.aft[0], self.aft[1])
        self.fore_deck = max(self.fore[2], self.fore[3])
        self.aft_deck = max(self.aft[2], self.aft[3])
        fall = self.FALL_AWAY * self.TURTLE
        self.bow_lead = min(self.STEM_LEAD * fore_edge,
                            max(self.fore_deck - WATERLINE - self.STEM_HEAD, 0.0) / fall)
        self.counter_lead = min(self.COUNTER_LEAD * aft_edge,
                                max(self.aft_deck - WATERLINE - self.KNUCKLE, 0.0) / fall)
        self.inside = []
        for x0, x1, z0, z1, h in plat_geo:
            self.hold((x0, x1, z0, z1), h - PLANK)
        for x0, x1, z0, z1, _axis, start, end in ramp_geo:
            self.hold((x0, x1, z0, z1), min(start, end))
        for x0, x1, z0, z1, bottom, _top, _box in block_geo:
            self.hold((x0, x1, z0, z1), bottom)
        self.keel = WATERLINE - self.DRAFT
        for _plan, foot in self.inside:
            self.keel = min(self.keel, foot - self.KEEL_CLEARANCE)
        self.runs = self.lofting_runs()

    def hold(self, plan, foot):
        middle = (plan[0] + plan[1]) * 0.5
        shape = envelope(min(max(middle, self.span[0] + SLIVER), self.span[1] - SLIVER))
        if shape is None or foot >= min(shape[2], shape[3]) - PLANK - SLIVER:
            return
        self.inside.append((plan, foot))

    def lofting_runs(self):
        stations = sorted(x for p in plat_geo for x in p[:2])
        runs = []
        last = self.span[0]
        for x in stations:
            if x <= last + SLIVER:
                continue
            shape = envelope((last + x) * 0.5)
            if shape is None:
                last = x
                continue
            if runs and runs[-1][1] == last and runs[-1][2] == shape:
                runs[-1][1] = x
                last = x
                continue
            runs.append([last, x, shape])
            last = x
        return runs

    def shape_at(self, x):
        if x >= self.span[1] - SLIVER:
            return self.fore
        if x <= self.span[0] + SLIVER:
            return self.aft
        return envelope(x)

    def breadth(self, x, y, side, shape=None):
        shape = shape or self.shape_at(x)
        edge = -shape[0] if side == 0 else shape[1]
        deck = shape[2] if side == 0 else shape[3]
        full = edge
        if y < deck:
            body = min(self.body(x, side), edge)
            depth = min(max((deck - y) / max(deck - self.keel, SLIVER), 0.0), 1.0)
            full = lerp(edge, body, smoothstep(0.0, self.FLARE, deck - y))
            full *= (1.0 - depth ** self.BILGE) ** (1.0 / self.BILGE)
        width = full * self.fore_taper(x, y) * self.aft_taper(x, y)
        if self.within(x, y):
            width = max(width, self.needed(x, y, side))
        return min(max(width, 0.0), edge)

    def body(self, x, side):
        reach = float("inf")
        for x0, x1, shape in self.runs:
            away = max(x0 - x, x - x1, 0.0)
            reach = min(reach, (-shape[0] if side == 0 else shape[1]) + self.FAIR * away)
        return reach

    def needed(self, x, y, side):
        need = 0.0
        for (x0, x1, z0, z1), foot in self.inside:
            spare = self.CONTENT_CLEARANCE - self.CONTENT_FALL[0] * max(x0 - x, x - x1, 0.0)
            reach = (-z0 + spare, z1 + spare)
            if max(reach) > 0.0:
                need = max(need, reach[side] - self.CONTENT_FALL[1] * max(foot - y, 0.0))
        return need

    def stem_x(self, y):
        head = WATERLINE + self.STEM_HEAD
        if y >= head:
            rise = min((y - head) / max(self.fore_deck - head, SLIVER), 1.0)
            return self.span[1] + SLIVER + self.bow_lead * (1.0 - rise ** self.TURTLE)
        plumb = self.span[1] + SLIVER + self.bow_lead
        if y >= WATERLINE:
            return plumb
        depth = min(max((WATERLINE - y) / (WATERLINE - self.keel), 0.0), 1.0)
        return plumb - self.FOREFOOT * (1.0 - (1.0 - depth * depth) ** 0.5)

    def fore_taper(self, x, y):
        stem = self.stem_x(y)
        lead = max(stem - self.span[1], SLIVER)
        low = min(max((self.fore_deck - y) / (self.fore_deck - WATERLINE), 0.0), 1.0)
        share = (stem - x) / lerp(lead, max(self.ENTRANCE, lead), low * low)
        if share <= 0.0:
            return 0.0
        return 1.0 - (1.0 - min(share, 1.0)) ** self.TAPER

    def stern_x(self, y):
        knuckle = WATERLINE + self.KNUCKLE
        if y >= knuckle:
            rise = min((y - knuckle) / max(self.aft_deck - knuckle, SLIVER), 1.0)
            return self.span[0] - SLIVER - self.counter_lead * (1.0 - rise ** self.TURTLE)
        post = self.span[0] + self.STERNPOST
        meet = WATERLINE + self.COUNTER_LIFT
        if y <= meet:
            return post
        tip = self.span[0] - SLIVER - self.counter_lead
        depth = (knuckle - y) / (knuckle - meet)
        return post - (post - tip) * (1.0 - depth * depth) ** 0.5

    def aft_taper(self, x, y):
        stern = self.stern_x(y)
        meet = WATERLINE + self.COUNTER_LIFT
        round_up = smoothstep(meet - self.COUNTER_BLEND, meet + self.COUNTER_BLEND, y)
        length = lerp(self.RUN, max(self.span[0] - stern, SLIVER), round_up)
        share = (x - stern) / length
        if share <= 0.0:
            return 0.0
        rest = 1.0 - min(share, 1.0)
        return lerp(1.0 - rest ** self.TAPER, (1.0 - rest * rest) ** 0.5, round_up)

    def within(self, x, y):
        return self.stern_x(y) < x < self.stem_x(y)

    def bottom(self, x, shape):
        low, high = self.keel, max(shape[2], shape[3])
        if self.within(x, low):
            return low
        if not self.within(x, high):
            return high
        for _ in range(24):
            middle = (low + high) * 0.5
            if self.within(x, middle):
                high = middle
            else:
                low = middle
        return high

    def section(self, x, shape):
        """The drawn section at a station x of a run under shape (ShipHull._section):
        (z, y) from the port sheer down round the keel and up to the starboard sheer."""
        bottom = self.bottom(x, shape)
        count = self.SECTION_POINTS - 1
        sides = []
        for side in (0, 1):
            line = max(shape[2] if side == 0 else shape[3], bottom)
            out = -1.0 if side == 0 else 1.0
            points = []
            for i in range(count):
                y = max(line - (line - self.keel) * math.sin(math.pi * 0.5 * i / count), bottom)
                points.append((out * self.breadth(x, y, side, shape), y))
            sides.append(points)
        return sides[0] + [(0.0, bottom)] + sides[1][::-1]

    def drawn_section(self, x):
        """The drawn loft cut across at x, inside the decks' run: between the two
        stations either side (ShipHull._stations), each pair of points' quad is drawn
        as two triangles over its diagonal, so the cut runs through the stations'
        points and those diagonals, a share of the way across."""
        for x0, x1, shape in self.runs:
            if not x0 < x < x1:
                continue
            count = max(1, math.ceil((x1 - x0) / self.STATION_SPACING))
            stations = [lerp(x0, x1, k / count) for k in range(count + 1)]
            post = self.span[0] + self.STERNPOST
            stations += [p for p in (post - SLIVER, post + SLIVER) if x0 + SLIVER < p < x1 - SLIVER]
            stations.sort()
            aft = max(p for p in stations if p <= x)
            fore = min(p for p in stations if p > x)
            a, b = self.section(aft, shape), self.section(fore, shape)
            t = (x - aft) / (fore - aft)
            points = []
            for j in range(len(a)):
                points.append(tuple(lerp(a[j][k], b[j][k], t) for k in (0, 1)))
                if j + 1 < len(a):
                    points.append(tuple(lerp(a[j][k], b[j + 1][k], t) for k in (0, 1)))
            return points

    def drawn_end(self, x, side):
        """One side of the drawn hull past an end of the decks cut across at x, top
        to bottom: the end's rings (ShipHull._end) — the waterlines out from the
        deck's end to the stem or the counter at its section's heights — each pair of
        rings drawn in triangles over the quads' diagonals."""
        fore = x > self.span[1]
        end = self.span[1] if fore else self.span[0]
        shape = self.fore if fore else self.aft
        deck = shape[2] if side == 0 else shape[3]
        bottom = self.bottom(end, shape)
        count = self.SECTION_POINTS - 1
        heights = []
        for i in range(count):
            y = deck - (deck - self.keel) * math.sin(math.pi * 0.5 * i / count)
            if i == 1:
                heights += [lerp(deck, y, extra / (self.TOP_RINGS + 1))
                            for extra in range(1, self.TOP_RINGS + 1)]
            if y <= bottom:
                break
            heights.append(y)
        heights.append(bottom)
        out = -1.0 if side == 0 else 1.0
        rings = []
        for y in heights:
            reach = max(self.stem_x(y) - end if fore else end - self.stern_x(y), 0.0)
            ring = []
            for j in range(self.RING_POINTS + 1):
                px = end + (1 if fore else -1) * reach * math.sin(math.pi * 0.5 * j / self.RING_POINTS)
                ring.append((px, y, out * self.breadth(px, y, side, shape)))
            rings.append(ring)
        cut = {}
        for i in range(len(rings) - 1):
            for j in range(self.RING_POINTS):
                a, b, c, d = rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j]
                for triangle in ((a, b, c), (a, c, d)):
                    for p, q in zip(triangle, triangle[1:] + triangle[:1]):
                        if (p[0] - x) * (q[0] - x) < 0:
                            t = (x - p[0]) / (q[0] - p[0])
                            y, z = lerp(p[1], q[1], t), lerp(p[2], q[2], t)
                            cut[round(y, 9)] = z
        return [(cut[y], y) for y in sorted(cut, reverse=True)]

hull = Hull()
KEEL = hull.keel
X_AFT = hull.span[0] - SLIVER - hull.counter_lead
X_FORE = hull.span[1] + SLIVER + hull.bow_lead

# The deckhouses on the main deck, enclosed: (x0, x1, half breadth, foot, top), each
# out to its walls' outer faces, the wheelhouse standing on the deckhouse.
HOUSES = [(-6.9 - T, 2.9 + T, 3.3 + T, DH, DTOP), (-3.9 - T, -1.1 + T, 1.4 + T, WH, WTOP)]
# Sections stand for no more than SECTION_MAX of hull, between the ends, the decks'
# breaks and every cell's end, so no cell splits a section: 28 on the steamer.
SECTION_MAX = 2.3
SECTION_BREAKS = [X_AFT, -20, -14, -13, -7, -4, -3.4, -3, -1, 0, 3, 4, 12, 15, 20, X_FORE]

def section_outline(x):
    """The outline of everything enclosed at x, counter-clockwise in (z, y): the drawn
    hull from the keel up the starboard side, over the deckhouses, down the port
    side."""
    if hull.span[0] < x < hull.span[1]:
        drawn = hull.drawn_section(x)
        middle = len(drawn) // 2
        port, starboard = drawn[:middle], drawn[middle + 1:]
        points = [drawn[middle]] + starboard
        houses_up, houses_down = [], []
        for x0, x1, half, foot, top in HOUSES:
            if x0 < x < x1:
                houses_up += [(half, foot), (half, top)]
                houses_down = [(-half, top), (-half, foot)] + houses_down
        points += houses_up + houses_down + port
    else:
        points = hull.drawn_end(x, 1)[::-1] + hull.drawn_end(x, 0)
    outline = []
    for z, y in points:
        point = (round(z, 4) + 0.0, round(y, 4) + 0.0)
        if not outline or point != outline[-1]:
            outline.append(point)
    if outline[-1] == outline[0]:
        outline.pop()
    return simplified(outline, OUTLINE_TOLERANCE)

# The physics cuts every section by the sea at every step of a bake (§5b.1), so each
# outline keeps only the drawn hull's points it needs to stay within this of the rest
# (est.): its corners, and enough of the bilge's curve.
OUTLINE_TOLERANCE = 0.01

def simplified(outline, tolerance):
    """Douglas–Peucker on a closed outline: split at its first point and the point
    farthest from it, each half keeping the point farthest from its chord while that is
    more than tolerance off it."""
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

# Cells: (name, x0, x1, y0, y1, z0, z1, kind, permeability or None for its kind's).
# Each compartment's lower-deck floor has a bilge under it; the hold has a side void
# either side, out from its walls, and a top under the forecastle — an air trap.
BEAM = max(max(-p[2], p[3]) for p in plat_geo)
HOLD_SIDE = 3.8
CELLS = [
    ("aft_peak", X_AFT, -13, KEEL, 0, -BEAM, BEAM, "VOID", None),
    ("poop_space", X_AFT, -14, 0, POOP_DECK, -4.5, 4.5, "STORES", None),
    ("aft_bilge_p", -13, -3, KEEL, LOWER, -BEAM, 0, "VOID", None),
    ("aft_bilge_s", -13, -3, KEEL, LOWER, 0, BEAM, "VOID", None),
    ("aft_cabins", -13, -3, LOWER, 0, -BEAM, BEAM, "ACCOMMODATION", None),
    ("engine_bilge_p", -3, 4, KEEL, LOWER, -BEAM, 0, "VOID", None),
    ("engine_bilge_s", -3, 4, KEEL, LOWER, 0, BEAM, "VOID", None),
    ("engine_room", -3, 4, LOWER, 0, -BEAM, BEAM, "MACHINERY", None),
    ("hold_bilge", 4, 15, KEEL, LOWER, -HOLD_SIDE, HOLD_SIDE, "VOID", None),
    ("hold", 4, 15, LOWER, 0, -HOLD_SIDE, HOLD_SIDE, "CARGO", 0.95),  # empty: 0.95
    ("hold_wing_p", 4, 15, KEEL, 0, -BEAM, -HOLD_SIDE, "VOID", None),
    ("hold_wing_s", 4, 15, KEEL, 0, HOLD_SIDE, BEAM, "VOID", None),
    ("hold_fwd_top", 12, 15, 0, FCSL_DECK, -HOLD_SIDE, HOLD_SIDE, "CARGO", 0.95),
    ("forepeak", 15, X_FORE, KEEL, FCSL_DECK, -4, 4, "VOID", None),
    ("deckhouse_cabins", -6.9 - T, -3.4, DH, DTOP, -3.3 - T, 3.3 + T, "ACCOMMODATION", None),
    ("deckhouse_hall", -3.4, 0, DH, DTOP, -3.3 - T, 3.3 + T, "ACCOMMODATION", None),
    ("saloon", 0, 2.9 + T, DH, DTOP, -3.3 - T, 3.3 + T, "ACCOMMODATION", None),
    ("wheelhouse", -3.9 - T, -1.1 + T, WH, WTOP, -1.4 - T, 1.4 + T, "ACCOMMODATION", None),
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

# Watertight walls across the hull: (name, x, top, collapse head). The hold's after
# wall stops at its door's head, 0.5 m short of the deck, so water spills over it;
# its walkable blocker still reaches the deck. Heads est.: 1.5× the head each is
# built for.
BULKHEADS = [
    ("bulkhead_aft", -13, 0.0, 4.0),
    ("bulkhead_engine", -3, 0.0, 4.0),
    ("bulkhead_hold", 4, LOWER + LINTEL, 4.0),
    ("collision", 15, FCSL_DECK, 8.0),
]
# The hold's side walls, along it: (name, z, top, collapse head est.) — leaky.
HOLD_WALLS = [("hold_side_p", -HOLD_SIDE, 0.0, 2.0), ("hold_side_s", HOLD_SIDE, 0.0, 2.0)]
# Her centre girder, along her keel under the after and engine rooms' floors from the
# after bulkhead to the hold's, 2.5 m high (est.): it parts each bilge's bottom into a
# port and a starboard half, so a gash floods the half on its side — the weight on one
# side, its loose water half as wide (the plan's lengthwise wall in a wide cell, R23) —
# until the water tops it and spills across. Limber holes through it leak est.
# 0.005 m² a bilge.
GIRDER = ("centre_girder", 0.0, KEEL + 2.5, 4.0)
LIMBER_HOLES = 0.005

def parted(axis, at, y0, y1, along0, along1):
    """The cells with a face on the plane where axis (0 x, 2 z) is at, overlapping
    the wall from y0 to y1 and from along0 to along1 along its other axis."""
    found = []
    other = 2 if axis == 0 else 0
    for c in CELLS:
        lo, hi = (c[1], c[2]) if axis == 0 else (c[5], c[6])
        olo, ohi = (c[5], c[6]) if other == 2 else (c[1], c[2])
        touches = abs(lo - at) < 1e-6 or abs(hi - at) < 1e-6
        if touches and c[3] < y1 and c[4] > y0 and olo < along1 and ohi > along0:
            found.append(c[0])
    return found

walls = []  # (name, axis, at, span, bottom, top, collapse, cells)
for name, x, top, collapse in BULKHEADS:
    half = max(abs(z) for z, _y in section_outline(x))  # across the hull there
    span = (-half, half)
    walls.append((name, "ACROSS", x, span, KEEL, top, collapse, parted(0, x, KEEL, top, *span)))
for name, z, top, collapse in HOLD_WALLS:
    span = (4, 15)
    walls.append((name, "ALONG", z, span, KEEL, top, collapse, parted(2, z, KEEL, top, *span)))
name, z, top, collapse = GIRDER
walls.append((name, "ALONG", z, (-13, 4), KEEL, top, collapse, parted(2, z, KEEL, top, -13, 4)))

# Openings: (name, kind, joins, centre, size, fields). size is the rectangle's extent
# along x, y and z, zero across the axis it is flat on.
SEA, SKY = "sea", "sky"
openings = []

def opening(name, kind, a, b, centre, size, **fields):
    openings.append((name, kind, [a or SKY, b or SKY], centre, size, fields))

# Doorways: open, as Q15 built them; in a watertight wall, a watertight door, shut by
# the ship at the hit over 20 s and jammed open one time in ten (est.). Its heads:
# leaking at the 2.6 m the wall is built for, giving way at its collapse head (est.).
across_walls = {x: (name, top, collapse) for name, x, top, collapse in BULKHEADS}
for axis, at, d0, d1, foot in doorways:
    middle = (d0 + d1) * 0.5
    sides = [(at + off, foot + 1.0, middle) if axis == 0 else (middle, foot + 1.0, at + off)
             for off in (-T - 0.01, T + 0.01)]
    a, b = cell_at(*sides[0]), cell_at(*sides[1])
    if a == b:
        continue
    if a is None:
        a, b = b, None
    face = at
    if b is None:
        inside = cell_box(a)
        lo, hi = (inside[0], inside[1]) if axis == 0 else (inside[4], inside[5])
        face = lo if abs(lo - at) < abs(hi - at) else hi
    centre = (face, foot + LINTEL * 0.5, middle) if axis == 0 else (middle, foot + LINTEL * 0.5, face)
    size = (0, LINTEL, d1 - d0) if axis == 0 else (d1 - d0, LINTEL, 0)
    tag = "%s_%s" % (a or SKY, b or SKY)
    if axis == 0 and at in across_walls:
        wall = across_walls[at]
        opening("wtd_" + wall[0].replace("bulkhead_", ""), "WATERTIGHT_DOOR", a, b, centre, size, starts="OPEN",
                shuts_at_hit=True, shut_time=20.0, flip_chance=0.1, leak_head=2.6,
                collapse_head=wall[2])
    else:
        opening("door_%s_%d" % (tag, sum(1 for o in openings if o[0].startswith("door_" + tag))),
                "DOOR", a, b, centre, size, starts="OPEN")

# Over each watertight wall that stops short of the deck, the gap water spills over.
for name, x, top, _collapse in BULKHEADS:
    for a in [c for c in CELLS if abs(c[2] - x) < 1e-6 and c[4] > top]:
        for b in [c for c in CELLS if abs(c[1] - x) < 1e-6 and c[4] > top]:
            z0, z1 = max(a[5], b[5]), min(a[6], b[6])
            y1 = min(a[4], b[4])
            if z1 > z0 and y1 > top:
                opening("over_%s_to_%s" % (name, b[0]), "OVER_WALL", a[0], b[0],
                        (x, (top + y1) * 0.5, (z0 + z1) * 0.5), (0, y1 - top, z1 - z0))

# Holes in the main deck: the stairs (water on deck runs down them) and the hold's
# hatch, battened (est.: it gives way under 1 m of water); the hold open to the
# space under the forecastle over it.
for x0, x1, z0, z1 in STAIR_HOLES:
    below, above = cell_at((x0 + x1) * 0.5, -0.01, (z0 + z1) * 0.5), cell_at((x0 + x1) * 0.5, 0.01, (z0 + z1) * 0.5)
    opening("stair_%s_%s" % (below, above or SKY), "STAIRWELL", below, above,
            ((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5), (x1 - x0, 0, z1 - z0), starts="OPEN")
opening("hatch_hold", "HATCH", "hold", SKY, ((HATCH[0] + HATCH[1]) * 0.5, 0, (HATCH[2] + HATCH[3]) * 0.5),
        (HATCH[1] - HATCH[0], 0, HATCH[3] - HATCH[2]), starts="SHUT", collapse_head=1.0)
# The deck breaks' fittings, where the art sets them (ShipFittings._fit_break, with its
# numbers): the forecastle's after face has a weathertight door either side of its
# stair into the space under it, shut (est.: gives way under 2 m of water, as a fire
# door); the poop's forward face, too low for a door, louvred vents either side of a
# lifebelt, always open.
BREAK_DOOR, VENT_HALF = (0.72, 1.5), (0.24, 0.17)
for tag, z in [("p", -2.425), ("s", 3.0)]:
    opening("door_hold_fwd_top_" + tag, "DOOR", "hold_fwd_top", SKY,
            (12, 0.06 + BREAK_DOOR[1] * 0.5, z), (0, BREAK_DOOR[1], BREAK_DOOR[0]),
            starts="SHUT", collapse_head=2.0)
for tag, z in [("p", -1.647), ("s", 1.647)]:
    opening("vent_poop_space_" + tag, "VENT", "poop_space", SKY, (-14, 0.6, z),
            (0, VENT_HALF[1] * 2, VENT_HALF[0] * 2), starts="OPEN")
top_box = cell_box("hold_fwd_top")
opening("open_hold_fwd_top", "OPEN", "hold", "hold_fwd_top",
        ((top_box[0] + top_box[1]) * 0.5, 0, 0), (top_box[1] - top_box[0], 0, top_box[5] - top_box[4]),
        starts="OPEN")

# The lower-deck floors are not watertight: est. 0.6 m² of gaps between each and its
# bilge. The hold's side walls leak est. 0.02 m² into it.
for room_cell, bilges in [("aft_cabins", ["aft_bilge_p", "aft_bilge_s"]),
                          ("engine_room", ["engine_bilge_p", "engine_bilge_s"]), ("hold", ["hold_bilge"])]:
    for bilge in bilges:
        b = cell_box(bilge)
        tag = "_" + bilge[-1] if len(bilges) > 1 else ""
        opening("floor_" + room_cell + tag, "FLOOR_GAPS", bilge, room_cell,
                ((b[0] + b[1]) * 0.5, LOWER, (b[4] + b[5]) * 0.5), (b[1] - b[0], 0, b[5] - b[4]),
                area=round(0.6 / len(bilges), 4), starts="OPEN")
    if len(bilges) > 1:
        b = cell_box(bilges[0])
        girder_top = GIRDER[2]
        opening("limber_" + room_cell, "LEAK", bilges[0], bilges[1],
                ((b[0] + b[1]) * 0.5, (b[2] + girder_top) * 0.5, 0.0), (b[1] - b[0], girder_top - b[2], 0),
                area=LIMBER_HOLES, starts="OPEN")
        opening("over_girder_" + room_cell, "OVER_WALL", bilges[0], bilges[1],
                ((b[0] + b[1]) * 0.5, (girder_top + b[3]) * 0.5, 0.0), (b[1] - b[0], b[3] - girder_top, 0),
                starts="OPEN")
for wing, z in [("hold_wing_p", -HOLD_SIDE), ("hold_wing_s", HOLD_SIDE)]:
    b = cell_box("hold")
    opening("leak_" + wing, "LEAK", wing, "hold", ((b[0] + b[1]) * 0.5, (b[2] + b[3]) * 0.5, z),
            (b[1] - b[0], b[3] - b[2], 0), area=0.02, starts="OPEN")

# Glass in every outside wall, where the art sets it (ShipFittings._windows, with its
# numbers): a porthole under the deck line the hull reaches — shut, left open one time
# in four (est.), or behind a deadlight in a hold — and a window above. `make
# art-lint` matches each pane it draws to one of these.
WINDOW_HEIGHT, WINDOW_SPACING, WINDOW_MARGIN = 1.45, 1.3, 0.4
WINDOW, NARROW_WINDOW, WINDOW_FRAME = (0.55, 0.6), (0.38, 0.6), 0.06
PORTHOLE_RADIUS = 0.16
WALL_MAX, FULL_WALL, INSIDE, OPEN_ROOM_HEIGHT, PROBE = 0.3, 1.9, 0.02, 2.5, 0.15
HOLD_AREA, SALOON_AREA = 40.0, 15.0
OUTWARD = [(0, -1), (1, 0), (0, 1), (-1, 0)]  # per side of a room, (x, z) out of it

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

def on_side(room, side, distance, depth):
    line = [room[2], room[1], room[3], room[0]][side]
    x, z = (distance, line) if side % 2 == 0 else (line, distance)
    return x - OUTWARD[side][0] * depth, z - OUTWARD[side][1] * depth

def wall_runs(room):
    """The full walls on room's floor along its sides, as ShipSpace.wall_runs: per run
    (side, from, to, half thickness)."""
    x0, x1, z0, z1, floor, _name = room
    runs = []
    for side in range(4):
        along_x = side % 2 == 0
        line = [z0, x1, z1, x0][side]
        low, high = (x0, x1) if along_x else (z0, z1)
        pieces, half = [], 0.0
        for bx0, bx1, bz0, bz1, bottom, top, is_box in block_geo:
            if not is_box or min(bx1 - bx0, bz1 - bz0) > WALL_MAX:
                continue
            if abs(bottom - floor) >= 0.05 or top - bottom <= FULL_WALL:
                continue
            if not (bx0 - INSIDE < x1 and bx1 + INSIDE > x0 and bz0 - INSIDE < z1 and bz1 + INSIDE > z0):
                continue
            across = (bz0, bz1) if along_x else (bx0, bx1)
            if across[1] - across[0] > WALL_MAX or not across[0] - SLIVER <= line <= across[1] + SLIVER:
                continue
            half = (across[1] - across[0]) * 0.5
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

def clear_of_stairs(room, run, height):
    side, a, b, half = run
    found, start = [], None
    count = max(1, math.ceil((b - a) / 0.05))
    for i in range(count + 1):
        along = lerp(a, b, i / count)
        x, z = on_side(room, side, along, -(half + 0.1))
        clear = i < count and not under_a_ramp(x, z, height + 0.5)
        if clear and start is None:
            start = along
        elif not clear and start is not None:
            found.append((start, along))
            start = None
    return found

def machinery_in(room):
    x0, x1, z0, z1, floor, _name = room
    return any(is_box and min(bx1 - bx0, bz1 - bz0) > WALL_MAX and abs(bottom - floor) < 0.05
               and x0 <= (bx0 + bx1) * 0.5 <= x1 and z0 <= (bz0 + bz1) * 0.5 <= z1
               for bx0, bx1, bz0, bz1, bottom, _top, is_box in block_geo)

top_floor = max(r[4] for r in room_geo)
SIDE_TAGS = ["p", "f", "s", "a"]
for room in room_geo:
    x0, x1, z0, z1, floor, room_name = room
    area = (x1 - x0) * (z1 - z0)
    helm = not machinery_in(room) and floor >= top_floor and area < SALOON_AREA
    deadlights = not machinery_in(room) and floor < 0 and area >= HOLD_AREA
    height = floor + WINDOW_HEIGHT
    for run in wall_runs(room):
        side, a, b, half = run
        stretches = clear_of_stairs(room, run, height) if helm else [(a, b)]
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
            bx, bz = on_side(room, side, spot, -(half + PROBE))
            if not outdoors(bx, height, bz) or under_a_ramp(bx, bz, height):
                continue
            shape = envelope(bx)
            in_hull = shape is not None and height < min(shape[2], shape[3])
            if in_hull and side % 2 == 1:
                continue
            x, z = on_side(room, side, spot, 0)
            away = OUTWARD[side]
            if in_hull:
                skin = hull.breadth(x, height, 0 if side == 0 else 1)
                cell = cell_at(x, height, away[1] * (skin - 0.05))
                tag = "port_%s_%s" % (cell, SIDE_TAGS[side])
                number = sum(1 for o in openings if o[0].startswith(tag)) + 1
                opening("%s%d" % (tag, number), "PORTHOLE", cell, SEA, (x, height, away[1] * skin),
                        (PORTHOLE_RADIUS * 2, PORTHOLE_RADIUS * 2, 0),
                        area=round(math.pi * PORTHOLE_RADIUS ** 2, 4), starts="SHUT",
                        flip_chance=0.0 if deadlights else 0.25, collapse_head=15.0)
                continue
            cell = cell_at(x - away[0] * (half + 0.01), height, z - away[1] * (half + 0.01))
            box_of = cell_box(cell)
            if side % 2 == 0:
                centre = (x, height, box_of[4] if away[1] < 0 else box_of[5])
                rect = (size[0], size[1], 0)
            else:
                centre = (box_of[0] if away[0] < 0 else box_of[1], height, z)
                rect = (0, size[1], size[0])
            tag = "window_%s_%s" % (cell, SIDE_TAGS[side])
            number = sum(1 for o in openings if o[0].startswith(tag)) + 1
            opening("%s%d" % (tag, number), "WINDOW", cell, SKY, centre, rect, starts="SHUT",
                    collapse_head=2.0)

# Mass (est.): where her weight sits. The ballast is what the generator settles: as
# heavy as she must be to float at her waterline, and where along and across her it
# puts her weight over her lift, so she floats there level — the drawn hull is not
# quite the same either side, where it stands clear of what is inside it.
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
    ("hull steel", 260e3, (-0.5, -1.8, 0.0), (-20, 20)),
    ("engine and boiler", 55e3, (1.2, -2.0, 0.0), (0, 2.5)),
    ("coal", 35e3, (-1.0, -4.0, 0.0), (-3, 1)),
    ("deckhouse", 38e3, (-2.0, 1.6, 0.0), (-7, 3)),
    ("wheelhouse and bridge", 8e3, (-2.5, 3.6, 0.0), (-4, -1)),
    ("funnel", 6e3, (-6.0, 3.8, 0.0), (-6.9, -5.1)),
    ("mast and rigging", 3e3, (16.0, 6.0, 0.0), (15.8, 16.2)),
    ("lifeboats and davits", 5e3, (-2.0, 3.0, 0.0), (-5, 1)),
    ("cabin fittings", 20e3, (-7.0, -1.5, 0.0), (-13, -3)),
    ("deckhouse fittings", 8e3, (-2.0, 1.0, 0.0), (-7, 3)),
    ("stores and water", 20e3, (-16.0, -2.5, 0.0), (-19, -13)),
    ("ground tackle", 8e3, (17.0, 0.5, 0.0), (15, 20)),
]
BALLAST_Y = KEEL + 0.4
BALLAST_REACH = 8.0  # either side of its centre
weight = displaced * SEA_DENSITY
ballast = weight - sum(m[1] for m in MASS)
ballast_x = (weight * along / displaced - sum(m[1] * m[2][0] for m in MASS)) / ballast
ballast_z = (weight * across / displaced - sum(m[1] * m[2][2] for m in MASS)) / ballast
assert ballast > 0, "she is heavier than she floats"
assert cell_at(ballast_x, BALLAST_Y, ballast_z), "her solved ballast must lie in one of her cells"
MASS.append(("ballast", round(ballast, 1), (round(ballast_x, 4), BALLAST_Y, round(ballast_z, 4)),
             (round(ballast_x - BALLAST_REACH, 4), round(ballast_x + BALLAST_REACH, 4))))
# How her mass turns, the water moving with her, and how her motions die away (est.).
MOTION = [("roll_radius", 3.8), ("pitch_radius", 10.0), ("added_mass", 1.0),
          ("heave_damping", 0.5), ("roll_damping", 0.08), ("pitch_damping", 0.5)]
# Her lifeboats (§5b.2): one a side on the deckhouse roof's davits, where the art hangs
# them, each useless on the high side past a list of 15° — old davits (est.).
LIFEBOATS = [("lifeboat_port", -1, -2.0, 15.0), ("lifeboat_starboard", 1, -2.0, 15.0)]
# Where along her and up her shell an iceberg's gash can be at all (est.): clear of her
# stem and her counter, from 0.2 m under the main deck down to 0.2 m over her keel.
HIT_ZONE_X = (-19.5, 19.5)
HIT_ZONE_Y = (KEEL + 0.2, -0.2)
# The must-sink rule's last rung (§5b.1, est.): a 25 m gash down her starboard side
# from her after peak to the hold, 1.2 m under her waterline, 150 mm as one even slit
# and biting 1.5 m in, every door and porthole shut — the plan's 20 m from the cabins
# leaves her afloat with the deck just clear, held up by her two peaks. `make
# ship-check` proves she founders on it within the bake's cap.
SURE_HIT = [("start_x", -19), ("length", 25), ("depth_start", 1.2), ("depth_end", 1.2),
            ("width", 0.15), ("bite", 1.5)]

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
    f.append(("leak_area", num(inside * AIR_LEAK)))
    cell_ids.append(sub("Cell_" + name, "11_cell", f))
wall_ids = []
for name, axis, at, span, bottom, top, collapse, parts in walls:
    f = [("name", '&"%s"' % name)]
    if axis == "ALONG":
        f.append(("axis", "1"))
    f += [("at", num(at)), ("span", "Vector2(%s, %s)" % (num(span[0]), num(span[1]))),
          ("bottom", num(bottom)), ("top", num(top)), ("collapse_head", num(collapse)),
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
    for key in ["flip_chance"]:
        if fields.get(key):
            f.append((key, num(fields[key])))
    if fields.get("shuts_at_hit"):
        f.append(("shuts_at_hit", "true"))
    for key in ["shut_time", "leak_head", "collapse_head"]:
        if fields.get(key):
            f.append((key, num(fields[key])))
    opening_ids.append(sub("Opening_" + name, "13_opening", f))
mass_ids = []
for name, kg, centre, along in MASS:
    mass_ids.append(sub("Mass_" + name.replace(" ", "_"), "14_mass", [
        ("name", '&"%s"' % name), ("mass", num(kg)), ("centre", vec3(centre)),
        ("along", "Vector2(%s, %s)" % (num(along[0]), num(along[1])))]))
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
       "props = " + arr("8_prop", props),
       "rooms = " + arr("6_room", rooms),
       'structure = SubResource("Structure")']
with open(out, "w") as f:
    f.write(head + "\n" + "\n\n".join(subs) + "\n\n" + "\n".join(res) + "\n")
print(len(platforms), "platforms", len(ramps), "ramps", len(blockers), "blockers", len(railings), "railings", len(ladders), "ladders", len(props), "props", len(rooms), "rooms")
print(len(sections), "sections", len(CELLS), "cells", len(walls), "walls", len(openings), "openings", len(MASS),
      "masses: %.1f t, ballast %.1f t at x %.3f z %.3f" % (weight / 1000, ballast / 1000, ballast_x, ballast_z))
