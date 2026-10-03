#!/usr/bin/env python3
"""Writes the steamer's layout, data/ships/steamer.tres.

The layout is generated: change the ship here, then `make ship`. `make ship-check`
(part of `make verify`) fails when the committed .tres is not what this writes, so a
hand edit to the .tres is caught. The sim reads only the .tres (D6).

Ship-local metres: x toward the bow, z to starboard, y up, origin on the main deck
amidships. The numbers that shape the rooms are the constants and calls below:
DOOR (a doorway's width), LOWER (the lower deck's height), LINTEL (a door's height),
T (half a wall's thickness), and each wall_*_doors call's door gaps.

Usage: tools/gen_steamer.py <out.tres>
"""
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

def sub(kind_id, script, fields):
    assert kind_id not in used, kind_id
    used.add(kind_id)
    body = ["[sub_resource type=\"Resource\" id=\"%s\"]" % kind_id, "script = ExtResource(\"%s\")" % script]
    for k, v in fields:
        body.append("%s = %s" % (k, v))
    subs.append("\n".join(body))
    return kind_id

def platform(pid, name, x0, x1, z0, z1, h=0.0):
    f = [("name", '&"%s"' % name), ("area", rect_xz(x0, x1, z0, z1))]
    if h != 0.0:
        f.append(("height", num(h)))
    platforms.append(sub("Platform_" + pid, "1_plat", f))
    return len(platforms) - 1

def ramp(rid, area, axis, start, end):
    f = [("area", area)]
    if axis == 1:
        f.append(("axis", "1"))
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

def wall_z_doors(bid, z, x0, x1, doors, bottom, top):
    edges = [x0 - T] + [v for d in doors for v in d] + [x1 + T]
    for i in range(0, len(edges), 2):
        box("%s_%d" % (bid, i // 2), edges[i], edges[i + 1], z - T, z + T, bottom, top)
    for i, d in enumerate(doors):
        box("%s_lintel_%d" % (bid, i), d[0], d[1], z - T, z + T, bottom + LINTEL, top)

# --- Platforms. The first five are SH3's, in SH3's order; the main deck is now
# rectangles round three stair openings, every one of them named "main deck".
MAIN = platform("main_deck", "main deck", -14, 12, -5, -1.6)  # the port strip
POOP = platform("poop_deck", "poop deck", -20, -14, -4.5, 4.5, 1.2)
FCSL = platform("forecastle", "forecastle", 12, 20, -4, 4, 1.8)
BOAT = platform("boat_deck", "boat deck", -7, 3, -3.4, 3.4, 2.5)
BRIDGE = platform("bridge", "bridge", -4, -1, -1.5, 1.5, 4.7)
# Openings: aft companionway x -12.85..-10.25 z -0.55..0.55; inner stair
# x -1.25..-0.15 z -1.6..1.0; forward companionway x 9..12 z 0.9..2.0.
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
ramp("poop_port", rect(-14, -4.5, 3, 1.4), 0, 1.2, 0)
ramp("poop_starboard", rect(-14, 3.1, 3, 1.4), 0, 1.2, 0)
ramp("boat_port", rect(3, -3.4, 6, 1.5), 0, 2.5, 0)
ramp("boat_starboard", rect(3, 1.9, 6, 1.5), 0, 2.5, 0)
ramp("forecastle", rect(9, -0.8, 3, 1.6), 0, 0, 1.8)
ramp("bridge", rect(-1, -0.7, 3, 1.4), 0, 4.7, 2.5)
ramp("aft_companionway", rect(-12.85, -0.55, 3.2, 1.1), 0, 0, LOWER)
ramp("inner_stair", rect(-1.25, -1.6, 1.1, 3.2), 1, 0, LOWER)
ramp("forward_companionway", rect(9.0, 0.9, 3.2, 1.1), 0, 0, LOWER)

# --- Blockers: SH3's funnel (now through the deckhouse), mast and hatch.
cylinder("funnel", -6, 0, 0.9, 0, 7.5)
cylinder("mast", 16, 0, 0.2, 1.8, 11)
box("hatch", 4, 8, -1, 1, 0, 0.8)
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

head = """[gd_resource type="Resource" script_class="ShipLayout" format=3]

[ext_resource type="Script" path="res://core/ship_platform.gd" id="1_plat"]
[ext_resource type="Script" path="res://core/ship_ramp.gd" id="2_ramp"]
[ext_resource type="Script" path="res://core/ship_blocker.gd" id="3_block"]
[ext_resource type="Script" path="res://core/ship_railing.gd" id="4_rail"]
[ext_resource type="Script" path="res://core/ship_layout.gd" id="5_layout"]
[ext_resource type="Script" path="res://core/ship_room.gd" id="6_room"]
[ext_resource type="Script" path="res://core/ship_ladder.gd" id="7_ladder"]
[ext_resource type="Script" path="res://core/ship_prop.gd" id="8_prop"]
"""
res = ["[resource]", 'script = ExtResource("5_layout")', "freeboard = 3.4",
       "platforms = " + arr("1_plat", platforms),
       "ramps = " + arr("2_ramp", ramps),
       "blockers = " + arr("3_block", blockers),
       "railings = " + arr("4_rail", railings),
       "ladders = " + arr("7_ladder", ladders),
       "spawns = Array[Vector3]([%s])" % ", ".join("Vector3(%s, %s, %s)" % tuple(num(c) for c in s) for s in spawns),
       "props = " + arr("8_prop", props),
       "rooms = " + arr("6_room", rooms)]
with open(out, "w") as f:
    f.write(head + "\n" + "\n\n".join(subs) + "\n\n" + "\n".join(res) + "\n")
print(len(platforms), "platforms", len(ramps), "ramps", len(blockers), "blockers", len(railings), "railings", len(ladders), "ladders", len(props), "props", len(rooms), "rooms")
