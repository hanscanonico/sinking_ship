#!/usr/bin/env python3
"""Writes the steamer's layout and structure, data/ships/steamer.tres.

The layout and structure are generated: change the ship here, then `make ship`.
`make ship-gen-check` (part of `make verify`) fails when the committed .tres is not what
this writes, so a hand edit to the .tres is caught. The sim reads only the .tres (D6).

Ship-local metres: x toward the bow, z to starboard, y up, origin on the main deck
amidships. The numbers that shape the rooms are the constants and calls below:
DOOR (a doorway's width), LOWER (the lower deck's height), TANK_TOP (the stokehold's
floor's), LINING (the stokehold's sides), LINTEL (a door's height), T (half a wall's
thickness), and each wall_*_doors call's door gaps.

`--weak` writes her test-only weak hull instead (SH33): the same ship with her strength
divided down by WEAK_DIVISOR and the weak spots WEAK_SPOTS, where she can break —
tests/fixtures/ships/steamer_weak.tres, playable as `make run SHIP=steamer_weak` and never
in the menu's fleet.

Usage: tools/gen_steamer.py <out.tres> [--weak]
"""
import math
import re
import struct
import sys

out = sys.argv[1]
weak = "--weak" in sys.argv[2:]

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
# whether a box) per blocker's plan; (x0, x1, z0, z1, floor, name) per room; and every
# doorway as (axis, at, from, to, bottom): a gap in a wall along x = at (axis 0) or
# z = at (axis 2).
plat_geo, ramp_geo, block_geo, room_geo, doorways = [], [], [], [], []
# What is fitted inside her lines (#148), as (x0, x1, z0, z1, heights it stands at), and
# which blockers are.
fitted_geo, fitted_blocks = [], set()

def sub(kind_id, script, fields):
    assert kind_id not in used, kind_id
    used.add(kind_id)
    body = ["[sub_resource type=\"Resource\" id=\"%s\"]" % kind_id, "script = ExtResource(\"%s\")" % script]
    for k, v in fields:
        body.append("%s = %s" % (k, v))
    subs.append("\n".join(body))
    return kind_id

def platform(pid, name, x0, x1, z0, z1, h=0.0, fitted=False):
    plat_geo.append((x0, x1, z0, z1, h))
    f = [("name", '&"%s"' % name), ("area", rect_xz(x0, x1, z0, z1))]
    if h != 0.0:
        f.append(("height", num(h)))
    if fitted:
        f.append(("fitted", "true"))
        fitted_geo.append((x0, x1, z0, z1, [h - PLANK]))
    platforms.append(sub("Platform_" + pid, "1_plat", f))
    return len(platforms) - 1

def ramp(rid, x, z, w, d, axis, start, end, fitted=False):
    ramp_geo.append((x, x + w, z, z + d, axis, start, end))
    f = [("area", rect(x, z, w, d))]
    if axis == 1:
        f.append(("axis", "1"))
    if start != 0.0:
        f.append(("start_height", num(start)))
    if end != 0.0:
        f.append(("end_height", num(end)))
    if fitted:
        f.append(("fitted", "true"))
        fitted_geo.append((x, x + w, z, z + d, [min(start, end)]))
    ramps.append(sub("Ramp_" + rid, "2_ramp", f))

# A deck with holes in it (#148) is laid in pieces round them: its first piece where
# the deck stood in the platforms' order, the rest after all her decks
# (pieces_after()), so no other platform's index moves.
later = []

def holed(pid, name, x0, x1, z0, z1, h, holes, cuts=(), fitted=False, across=False, after=False,
          largest=False):
    """The deck x0…x1 by z0…z1 at h less holes [(x0, x1, z0, z1)]: cut across x at
    cuts, then each part in bands along z between the holes' sides, each band round the
    holes in it — so a deck's edges that railings stand along stay whole; or, across,
    in bands across her between the holes' ends, each round the holes in it. Returns the
    first piece's index — with largest, its largest, which stands in for the whole deck it
    was before its holes: its stairs come down onto it; a fitted deck lays the rest at
    once. After lays every piece after the rest, the rest of a deck already laid."""
    pieces = []
    xs = [x0] + [c for c in cuts if x0 < c < x1] + [x1]
    assert not any(o[0] < c < o[1] for o in holes for c in xs), "a hole across a cut in %s" % pid
    if across:
        xs = sorted({x0, x1} | {v for o in holes for v in o[:2] if x0 < v < x1})
    for a, b in zip(xs, xs[1:]):
        inside = [o for o in holes if a <= o[0] and o[1] <= b] if not across else []
        if across:
            cutting = sorted(o for o in holes if o[0] <= a and b <= o[1])
            edges = [z0] + [v for o in cutting for v in o[2:]] + [z1]
            for e, f in zip(edges[::2], edges[1::2]):
                if f - e > 1e-6:
                    pieces.append((a, b, e, f))
            continue
        zs = sorted({z0, z1} | {v for o in inside for v in o[2:] if z0 < v < z1})
        for c, d in zip(zs, zs[1:]):
            across_band = sorted(o for o in inside if o[2] <= c and d <= o[3])
            edges = [a] + [v for o in across_band for v in o[:2]] + [b]
            for e, f in zip(edges[::2], edges[1::2]):
                if f - e > 1e-6:
                    pieces.append((e, f, c, d))
    if largest:
        pieces.sort(key=lambda p: -(p[1] - p[0]) * (p[3] - p[2]))
    first = None if after else platform(pid, name, *pieces[0], h, fitted)
    for k, piece in enumerate(pieces if after else pieces[1:]):
        if fitted:
            platform("%s_%d" % (pid, k + 1), name, *piece, h, True)
        else:
            later.append(("%s_%d" % (pid, k + 1), name, piece, h))
    return first

def pieces_after():
    for pid, name, piece, h in later:
        platform(pid, name, *piece, h)

def box(bid, x0, x1, z0, z1, bottom, top, fitted=False):
    block_geo.append((x0, x1, z0, z1, bottom, top, True))
    if fitted:
        fitted_blocks.add(len(block_geo) - 1)
    f = [("area", rect_xz(x0, x1, z0, z1))]
    if bottom != 0.0:
        f.append(("bottom", num(bottom)))
    f.append(("top", num(top)))
    if fitted:
        f.append(("fitted", "true"))
        fitted_geo.append((x0, x1, z0, z1, [bottom, top]))
    blockers.append(sub("Blocker_" + bid, "3_block", f))

def cylinder(bid, cx, cz, r, bottom, top):
    block_geo.append((cx - r, cx + r, cz - r, cz + r, bottom, top, False))
    f = [("shape", "1"), ("centre", "Vector2(%s, %s)" % (num(cx), num(cz))), ("radius", num(r))]
    if bottom != 0.0:
        f.append(("bottom", num(bottom)))
    f.append(("top", num(top)))
    blockers.append(sub("Blocker_" + bid, "3_block", f))

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

def crate(cid, x, y, z):
    f = [("pos", "Vector3(%s, %s, %s)" % (num(x), num(y), num(z)))]
    f += [(k, num(v)) for k, v in CRATE]
    props.append(sub("Prop_" + cid, "8_prop", f))

def room(rid, name, x0, x1, z0, z1, floor, crawl_space=False):
    room_geo.append((x0, x1, z0, z1, floor, name))
    f = [("name", '&"%s"' % name), ("area", rect_xz(x0, x1, z0, z1))]
    if floor != 0.0:
        f.append(("floor_height", num(floor)))
    if crawl_space:
        f.append(("crawl_space", "true"))
    rooms.append(sub("Room_" + rid, "6_room", f))

T = 0.1  # half a wall's thickness: walls are 0.2 m, centred on a room's side
# A cargo crate (SH10): a 0.45 m circle, 0.8 m tall — a hop up, as onto the hatch —
# of 200 kg against a brawler's 80, holding on the deck to 8°: past the early list,
# short of a lurch's swing.
CRATE = [("radius", 0.45), ("height", 0.8), ("mass", 200), ("grip_angle_deg", 8), ("friction", 2.5)]
DOOR = 1.1
LOWER = -2.6
# The stokehold (#74): her engine room runs down from the lower deck to a floor on her
# tank top, 1 m under her waterline, so a gash along her middle opens a room a player
# can stand in; under it a double bottom as deep, deep enough that a gash low along her
# floods one half of it, the weight on one side, as her bilges do. Its sides are a
# lining of plating LINING out from her middle line, inside her shell, that stands to
# the main deck. Galleries at the lower
# deck's height ring it: along its after and forward bulkheads, and along its sides,
# STOKEHOLD_HOLE the opening they leave over its floor, (x0, x1, half breadth).
TANK_TOP = -4.4
LINING = 3.8
# Its after end leaves a body room to pass the inner stair's foot on the gallery; its
# ends lie where a single-precision Rect2 holds them exactly.
STOKEHOLD_HOLE = (0.75, 3.0, 2.6)
LINTEL = 2.1  # a door's height above its floor

# --- Her old voids made places (#148): every cell of hers a place a body can stand or
# crawl in, each space fitted inside her lines (after her hull below), lit, and with two
# ways up. The ways in are cut through her decks here, before her hull is lofted, so the
# holes shape nothing: each a hatch over a steep stair, (x0, x1, z0, z1) of the deck it
# cuts, its stair's top at the end named in its comment. Stairs into them are 39° where
# there is room and 45° (a ship's ladder's pitch) where there is not; each hatch's hole
# is the stair's run under a deck too low to stand under.
# The double bottom's four manholes in the stokehold's tank top, two a side of her
# girder, each over a stair up out of it to its forward (x1) end: two under the after
# gallery, two under the side galleries beside the stairs.
MANHOLES = [(-2.0, -0.9, -3.3, -2.2), (-2.0, -0.9, 2.2, 3.3), (1.5, 2.6, -3.7, -2.6), (1.5, 2.6, 2.6, 3.7)]
# The lower hold's two hatches in the hold's floor, clear of the forward companionway's
# foot and the spawn to port: its after one to starboard (the stair's top at x0), its
# forward one to port (at x1).
LOWER_HOLD_HATCHES = [(4.9, 7.1, 1.5, 2.6), (11.1, 13.3, -2.6, -1.5)]
# Her girder parts the bilges under the aft cabins down her middle, under the cabin
# corridor, so each half is entered through the floors of the cabins over it: from the
# after cabin, a stair along her to its top at x0; from the forward cabin, a stair
# across her to its top at the shell's side (45°: the girder and the hull's wall leave
# no more run).
BILGE_HATCHES = [(-12.1, -9.9, -3.2, -2.1), (-5.5, -4.4, -3.65, -1.85),
                 (-12.1, -9.9, 2.1, 3.2), (-5.5, -4.4, 1.85, 3.65)]
# The hold's wing passages run along her shell under the main deck, a hatch at either
# end, each stair's top at the passage's end (aft x0, forward x1). WING_SHELL is the
# passage's outboard side, the middle of the lining on her frames: her shell leaves room
# for a body beside the hold's wall only that high and that far forward.
WING = (4.0, 6.8)
WING_SHELL = 4.82
WING_HATCHES = [(4.0, 5.2), (5.6, 6.8)]
# The steering gear's two stairs up through the poop, to their tops at x1, and the
# forepeak's through the forecastle, to their tops at x0 — each deck cut only between its
# railings' span ends, so no railing moves.
POOP_HATCHES = [(-17.0, -14.9, -1.2, -0.1), (-17.0, -14.9, 0.1, 1.2)]
FCSL_HATCHES = [(15.2, 17.0, -2.6, -1.5), (15.2, 17.0, 1.5, 2.6)]

def wall_x(bid, x, z0, z1, bottom, top, fitted=False):
    """A wall along x = const from z0 to z1 (centre line), ends overlapping corners."""
    box(bid, x - T, x + T, z0 - T, z1 + T, bottom, top, fitted)

def wall_z(bid, z, x0, x1, bottom, top, fitted=False):
    box(bid, x0 - T, x1 + T, z - T, z + T, bottom, top, fitted)

def wall_x_doors(bid, x, z0, z1, doors, bottom, top, fitted=False):
    """Wall pieces along x = const with door gaps [(a, b)] in z; a lintel over each."""
    edges = [z0 - T] + [v for d in doors for v in d] + [z1 + T]
    for i in range(0, len(edges), 2):
        box("%s_%d" % (bid, i // 2), x - T, x + T, edges[i], edges[i + 1], bottom, top, fitted)
    for i, d in enumerate(doors):
        box("%s_lintel_%d" % (bid, i), x - T, x + T, d[0], d[1], bottom + LINTEL, top, fitted)
        doorways.append((0, x, d[0], d[1], bottom))

def wall_z_doors(bid, z, x0, x1, doors, bottom, top, fitted=False):
    edges = [x0 - T] + [v for d in doors for v in d] + [x1 + T]
    for i in range(0, len(edges), 2):
        box("%s_%d" % (bid, i // 2), edges[i], edges[i + 1], z - T, z + T, bottom, top, fitted)
    for i, d in enumerate(doors):
        box("%s_lintel_%d" % (bid, i), d[0], d[1], z - T, z + T, bottom + LINTEL, top, fitted)
        doorways.append((2, z, d[0], d[1], bottom))

# --- Platforms. The first five are SH3's, in SH3's order; the main deck is now
# rectangles round three stair openings, every one of them named "main deck".
# Their inboard sides a hair outboard of the hold's walls (3.9 out): the main deck's
# strips inboard of them end at 1.6 out in single precision too (Surfaces.joins), where
# the inner stair comes up.
WING_INBOARD = 3.90625
WING_MAIN = [(a, b, -WING_SHELL + 0.05, -WING_INBOARD) for a, b in WING_HATCHES]
WING_SS = [(a, b, WING_INBOARD, WING_SHELL - 0.05) for a, b in WING_HATCHES]
# The port strip inboard of her wing passages' hatches, and outboard of it the rest of
# it, round them.
MAIN = platform("main_deck", "main deck", -14, 12, -WING_INBOARD, -1.6, 0.0)
POOP = holed("poop_deck", "poop deck", -20, -14, -4.5, 4.5, 1.2, POOP_HATCHES, (-17,))
FCSL = holed("forecastle", "forecastle", 12, 20, -4, 4, 1.8, FCSL_HATCHES, (14.5, 17))
BOAT = platform("boat_deck", "boat deck", -7, 3, -3.4, 3.4, 2.5)
BRIDGE = platform("bridge", "bridge", -4, -1, -1.5, 1.5, 4.7)
# The three stair openings it leaves, (x0, x1, z0, z1): the aft companionway, the
# inner stair, the forward companionway.
STAIR_HOLES = [(-12.85, -10.25, -0.55, 0.55), (-1.25, -0.15, -1.6, 1.0), (9, 12, 0.9, 2.0)]
SS = platform("main_deck_starboard", "main deck", -14, 12, 2.0, WING_INBOARD, 0.0)
holed("main_deck_outboard", "main deck", -14, 12, -5, -WING_INBOARD, 0.0, WING_MAIN, (3.7, 8.5), after=True)
holed("main_deck_starboard_outboard", "main deck", -14, 12, WING_INBOARD, 5, 0.0, WING_SS, (3.7, 8.5),
      after=True)
MA = platform("main_deck_aft", "main deck", -14, -12.85, -1.6, 2.0)
MB1 = platform("main_deck_aft_port", "main deck", -12.85, -10.25, -1.6, -0.55)
MB2 = platform("main_deck_aft_starboard", "main deck", -12.85, -10.25, 0.55, 2.0)
MC = platform("main_deck_waist", "main deck", -10.25, -1.25, -1.6, 2.0)
MD = platform("main_deck_hall", "main deck", -1.25, -0.15, 1.0, 2.0)
ME = platform("main_deck_forward", "main deck", -0.15, 9.0, -1.6, 2.0)
MF = platform("main_deck_bow", "main deck", 9.0, 12, -1.6, 0.9)
L1 = holed("lower_deck", "lower deck", -13, -3, -4.8, 4.8, LOWER, BILGE_HATCHES, across=True, largest=True)
L2 = holed("hold", "lower deck", 4, 15, -3.8, 3.8, LOWER, LOWER_HOLD_HATCHES, largest=True)
# The engine room's galleries round the opening over the stokehold, and its floor.
HX0, HX1, HZ = STOKEHOLD_HOLE
GA = platform("gallery_aft", "lower deck", -3, HX0, -LINING, LINING, LOWER)
GF = platform("gallery_forward", "lower deck", HX1, 4, -LINING, LINING, LOWER)
GP = platform("gallery_port", "lower deck", HX0, HX1, -LINING, -HZ, LOWER)
GS = platform("gallery_starboard", "lower deck", HX0, HX1, HZ, LINING, LOWER)
SH = holed("stokehold", "stokehold", -3, 4, -LINING, LINING, TANK_TOP, MANHOLES, largest=True)
pieces_after()

# --- Ramps: SH3's six, then the three stairs (39°, 1.1 m wide).
ramp("poop_port", -14, -4.5, 3, 1.4, 0, 1.2, 0)
ramp("poop_starboard", -14, 3.1, 3, 1.4, 0, 1.2, 0)
ramp("boat_port", 3, -3.4, 6, 1.5, 0, 2.5, 0)
ramp("boat_starboard", 3, 1.9, 6, 1.5, 0, 2.5, 0)
ramp("forecastle", 9, -0.8, 3, 1.6, 0, 0, 1.8)
# The forecastle's second way up (Q6): from SH27 a sinking by the stern leaves her bow
# highest, so the forecastle is a perch like the bridge — a second stair to starboard,
# as steep and as wide, outboard of the forward companionway's rail, clear of the
# cargo stowed to port.
ramp("forecastle_starboard", 9, 2.3, 3, 1.6, 0, 0, 1.8)
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
# The stokehold's two stairs (#74), as steep as the rest, one up to each end's gallery
# along a lane beside the engine: the after one to port, the forward one to starboard.
STOKEHOLD_RUN = 2.35  # its foot two body radii clear of the forward bulkhead
ramp("stokehold_aft", HX0, -2.5, STOKEHOLD_RUN, 1.1, 0, LOWER, TANK_TOP)
ramp("stokehold_forward", HX1 - STOKEHOLD_RUN, 1.4, STOKEHOLD_RUN, 1.1, 0, TANK_TOP, LOWER)

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
# The engine block on the stokehold floor splits it into two lanes, a body's way past
# it beside each stair; it stands up through the opening over it.
box("engine", 1.0, 2.75, -0.5, 0.5, TANK_TOP, -1.2)
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

# --- The stokehold's own blockers (#74), after every other's so none moves: its
# bulkheads down to its floor under the galleries, and its lining either side, standing
# to the main deck, the hull's walls outboard of it.
wall_x("stokehold_aft", -3, -LINING, LINING, TANK_TOP, LOWER)
wall_x("stokehold_forward", 4, -LINING, LINING, TANK_TOP, LOWER)
# Its lining in two lifts, so its galleries have full walls on their floor too.
wall_z("stokehold_port", -LINING, -3 + T, 4 - T, TANK_TOP, LOWER)
wall_z("stokehold_starboard", LINING, -3 + T, 4 - T, TANK_TOP, LOWER)
wall_z("gallery_port", -LINING, -3 + T, 4 - T, LOWER, 0)
wall_z("gallery_starboard", LINING, -3 + T, 4 - T, LOWER, 0)
# A stanchion at each corner of the opening over the stokehold, at the railings' joins:
# each gallery's side onto the opening is then a doorway onto the gallery beside it and
# an edge over the drop, so a body walks round the galleries one to the next.
for tag, x in [("aft", HX0), ("forward", HX1)]:
    for side, z in [("port", -HZ), ("starboard", HZ)]:
        box("stanchion_%s_%s" % (tag, side), x - 0.05, x + 0.05, z - 0.05, z + 0.05, LOWER, LOWER + 1.0)
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
# Round the opening over the stokehold, but for its stairs' heads and where the engine
# stands too near the galleries' edges for a body to fall between.
ENGINE_END = 0.6
railing("stokehold_aft_port", GA, (HX0, -1.4), (HX0, -ENGINE_END))
railing("stokehold_aft_starboard", GA, (HX0, ENGINE_END), (HX0, HZ))
railing("stokehold_forward_port", GF, (HX1, -HZ), (HX1, -ENGINE_END))
railing("stokehold_forward_starboard", GF, (HX1, ENGINE_END), (HX1, 1.4))
railing("stokehold_port", GP, (HX0, -HZ), (HX1, -HZ))
railing("stokehold_starboard", GS, (HX0, HZ), (HX1, HZ))

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
# The engine room's galleries, each a room of its own a body walks straight across,
# and the stokehold under them (#74).
room("engine_room", "engine room", -3, HX0, -LINING, LINING, LOWER)
room("cabin_corridor", "cabin corridor", -13, -3, -0.7, 0.7, LOWER)
for side, z0, z1 in [("port", -4.8, -0.7), ("starboard", 0.7, 4.8)]:
    for tag, x0, x1 in [("aft", -13, -8.4), ("middle", -8.4, -5.7), ("forward", -5.7, -3)]:
        room("cabin_%s_%s" % (side, tag), "%s %s cabin" % (tag, side), x0, x1, z0, z1, LOWER)
room("saloon", "saloon", 0, 2.9, -3.3, 3.3, DH)
room("deckhouse_hall", "deckhouse hall", -3.4, 0, -3.3, 3.3, DH)
for i, (z0, z1) in enumerate([(-3.3, -1.65), (-1.65, 0), (0, 1.65), (1.65, 3.3)]):
    room("deckhouse_cabin_%d" % (i + 1), "deckhouse cabin %d" % (i + 1), -6.9, -3.4, z0, z1, DH)
room("wheelhouse", "wheelhouse", -3.9, -1.1, -1.4, 1.4, WH)
# The stokehold and the rest of its galleries, after every other room so none moves.
room("stokehold", "stokehold", -3, 4, -LINING, LINING, TANK_TOP)
room("engine_room_forward", "engine room", HX1, 4, -LINING, LINING, LOWER)
room("engine_room_port", "engine room", HX0, HX1, -LINING, -HZ, LOWER)
room("engine_room_starboard", "engine room", HX0, HX1, HZ, LINING, LOWER)

spawns = [
    (8, LOWER, -2), (-2, LOWER, -3.2), (-7, LOWER, 2.8),
    (1.5, 0, -1.5), (-2.5, 0, 2.2),
    (-17.5, 1.2, -2.5), (-5, 0, -4.3), (7.4, 0, 4.2),
]
# The seats a match on her takes: the menu's 4–8 since SH8, hers from SH30; one plays
# alone, no bots.
SEATS = (1, 8)

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

def envelope(x, plats=None):
    """The decks' outline across the ship at x, as ShipSpace.envelope: [port z,
    starboard z, port height, starboard height], or None where no deck stands."""
    shape = None
    for x0, x1, z0, z1, h in plat_geo if plats is None else plats:
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
    holds the two together. It is lofted round the pieces laid before it: what is
    fitted inside her lines after it (#148) shapes none of them."""
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
        self.plats = list(plat_geo)
        self.span = (min(p[0] for p in self.plats), max(p[1] for p in self.plats))
        self.fore = envelope(self.span[1] - SLIVER, self.plats)
        self.aft = envelope(self.span[0] + SLIVER, self.plats)
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
        for x0, x1, z0, z1, h in self.plats:
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
        shape = envelope(min(max(middle, self.span[0] + SLIVER), self.span[1] - SLIVER), self.plats)
        if shape is None or foot >= min(shape[2], shape[3]) - PLANK - SLIVER:
            return
        self.inside.append((plan, foot))

    def lofting_runs(self):
        stations = sorted(x for p in self.plats for x in p[:2])
        runs = []
        last = self.span[0]
        for x in stations:
            if x <= last + SLIVER:
                continue
            shape = envelope((last + x) * 0.5, self.plats)
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
        return envelope(x, self.plats)

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

# --- Her old voids made places (#148), fitted inside her lines: each piece stands where
# her hull already leaves room for it, clear of her shell by FIT (fits() below holds
# them to it), and shapes none of it. Floors go as low as her shell's width lets a body
# stand or crawl, so wherever a gash opens her it opens a place someone can be.
FIT = 0.02
# Her lowest floors, on her plating over the keel (est.): the double bottom's under her
# tank top leaves 0.91 m — a crawl space, and more than a jump, so no deck meets another
# a hop over it — and the bilges' under the lower deck 2.71 m. Every new floor stands
# where single precision holds its height at or over it (a position's float rounds a
# height like -5.3 under it, and the floor is missed there): -5.3125 is exact.
BILGE_FLOOR = KEEL + 0.0875
GIRDER_TOP = KEEL + 2.5
# A hatch into one is a scuttle, battened and dogged watertight, a body going down it
# opening it as a doorway's door is opened: shut to the water, it never weeps nor gives
# way, so the space under it floods as it did before it was a place (#148).
# The double bottom under the stokehold, a crawl space either side of her girder, which
# stands to the tank top there; its sides and ends under the stokehold's.
for side, z0, z1 in [("port", -LINING, 0), ("starboard", 0, LINING)]:
    platform("double_bottom_" + side, "double bottom", -3, 4, z0, z1, BILGE_FLOOR, True)
wall_x("double_bottom_aft", -3, -LINING, LINING, BILGE_FLOOR, TANK_TOP, True)
wall_x("double_bottom_forward", 4, -LINING, LINING, BILGE_FLOOR, TANK_TOP, True)
box("girder_stokehold", -3 + T, 4 - T, -T, T, BILGE_FLOOR, TANK_TOP, True)
wall_z("double_bottom_port", -LINING, -3 + T, 4 - T, BILGE_FLOOR, TANK_TOP, True)
wall_z("double_bottom_starboard", LINING, -3 + T, 4 - T, BILGE_FLOOR, TANK_TOP, True)
for k, (x0, x1, z0, z1) in enumerate(MANHOLES):
    ramp("manhole_%d" % (k + 1), x0, z0, x1 - x0, z1 - z0, 0, BILGE_FLOOR, TANK_TOP, True)
# The lower hold under the hold, its sides in from the turn of her bilge.
LOWER_HOLD_SIDE = 2.7
platform("lower_hold", "lower hold", 4, 15, -LOWER_HOLD_SIDE, LOWER_HOLD_SIDE, BILGE_FLOOR, True)
wall_x("lower_hold_forward", 15, -LOWER_HOLD_SIDE, LOWER_HOLD_SIDE, BILGE_FLOOR, LOWER, True)
for side, z in [("port", -LOWER_HOLD_SIDE), ("starboard", LOWER_HOLD_SIDE)]:
    wall_z("lower_hold_" + side, z, 4 + T, 15 - T, BILGE_FLOOR, LOWER, True)
x0, x1, z0, z1 = LOWER_HOLD_HATCHES[0]
ramp("lower_hold_aft", x0, z0, 3.3, z1 - z0, 0, LOWER, BILGE_FLOOR, True)
x0, x1, z0, z1 = LOWER_HOLD_HATCHES[1]
ramp("lower_hold_forward", x1 - 3.3, z0, 3.3, z1 - z0, 0, BILGE_FLOOR, LOWER, True)
# The bilges under the aft cabins: the shaft tunnel to port, stores to starboard, either
# side of her girder.
BILGE_SIDE = 3.8
platform("shaft_tunnel", "shaft tunnel", -13, -3, -BILGE_SIDE, 0, BILGE_FLOOR, True)
platform("bilge_stores", "stores", -13, -3, 0, BILGE_SIDE, BILGE_FLOOR, True)
wall_x("bilge_aft", -13, -BILGE_SIDE, BILGE_SIDE, BILGE_FLOOR, LOWER, True)
# Its girder runs from bulkhead to bulkhead, its top under the lower deck but for its
# last 0.3 m under the engine room's, a metre high there — still too high to climb — so
# nothing standing on it reaches the fire buckets over that bulkhead's far side.
box("girder", -13 - T, -3 - T - 0.25, -T, T, BILGE_FLOOR, GIRDER_TOP, True)
box("girder_forward", -3 - T - 0.3, -3 + T, -T, T, BILGE_FLOOR, BILGE_FLOOR + 1.0, True)
for side, z in [("port", -BILGE_SIDE), ("starboard", BILGE_SIDE)]:
    wall_z("bilge_" + side, z, -13 + T, -3 - T, BILGE_FLOOR, LOWER, True)
# Her propeller shaft runs aft down the shaft tunnel beside her girder on its plummer
# blocks, as high as a body's hip: a body goes round it (est.).
SHAFT = (-0.55, -0.1, 0.85)  # z0, z1, its top over the floor
box("shaft", -13 + T, -3 - T, SHAFT[0], SHAFT[1], BILGE_FLOOR, BILGE_FLOOR + SHAFT[2], True)
for k, (x0, x1, z0, z1) in enumerate(BILGE_HATCHES):
    if x1 - x0 > z1 - z0:  # along her, from the after cabin
        ramp("bilge_%d" % (k + 1), x0, z0, 3.3, z1 - z0, 0, LOWER, BILGE_FLOOR, True)
    elif z0 < 0:  # across her, from the forward cabin, its foot by her girder
        ramp("bilge_%d" % (k + 1), x0, z0, x1 - x0, 2.7, 1, LOWER, BILGE_FLOOR, True)
    else:
        ramp("bilge_%d" % (k + 1), x0, z1 - 2.7, x1 - x0, 2.7, 1, BILGE_FLOOR, LOWER, True)
# The hold's wing passages, a crawl under the main deck along her shell, the hold's wall
# inboard and a lining on her frames outboard (est. 10 cm).
WING_FLOOR = -1.0
for side, sign in [("port", -1), ("starboard", 1)]:
    inner, shell = sign * 3.9, sign * (WING_SHELL - 0.05)
    platform("wing_" + side, "side passage", WING[0], WING[1], *sorted((sign * 3.8, sign * WING_SHELL)),
             WING_FLOOR, True)
    box("wing_%s_shell" % side, WING[0], WING[1] + T, *sorted((sign * (WING_SHELL - 0.05), sign * (WING_SHELL + 0.05))),
        WING_FLOOR, 0.0, True)
    box("wing_%s_end" % side, WING[1] - T, WING[1] + T, *sorted((inner, shell)), WING_FLOOR, 0.0, True)
    a, b = WING_HATCHES[0]
    ramp("wing_%s_aft" % side, a, min(inner, shell), b - a, abs(shell - inner), 0, 0.0, WING_FLOOR, True)
    a, b = WING_HATCHES[1]
    ramp("wing_%s_forward" % side, a, min(inner, shell), b - a, abs(shell - inner), 0, WING_FLOOR, 0.0, True)
# The aft peak: her steering gear on a flat under the poop, stores under it down to
# where her counter's bottom lets a floor stand, and lower stores where her run narrows
# under those, each down from the one over it by two stairs. Her poop stands over the
# steering gear, so its break is walled down to the main deck, under its edge: fitted,
# as everything here, so it shapes nothing of her lines.
STEERING_FLOOR, AFT_STORES_FLOOR, LOWER_STORES_FLOOR = -1.0, -3.1, -5.2
STEERING_HATCHES = [(-18.6, -16.35, -2.7, -1.6), (-18.6, -16.35, 1.6, 2.7)]
# Its forward wall's line half a wall abaft the poop's break, so the wall stands under
# the poop flush with its edge, no ledge of it proud of the deck.
STEERING_FORWARD = -14 - T
STEERING = holed("steering_gear", "steering gear", -19.8, STEERING_FORWARD, -4.2, 4.2, STEERING_FLOOR,
                 STEERING_HATCHES, fitted=True)
wall_x("steering_gear_aft", -19.8, -4.2, 4.2, STEERING_FLOOR, POOP_DECK, True)
wall_x("steering_gear_forward", STEERING_FORWARD, -4.2, 4.2, STEERING_FLOOR, 0.0, True)
for side, z in [("port", -4.2), ("starboard", 4.2)]:
    wall_z("steering_gear_" + side, z, -19.8, STEERING_FORWARD, STEERING_FLOOR, POOP_DECK, True)
box("poop_break", STEERING_FORWARD - T, STEERING_FORWARD + T, -4.5 + FIT, 4.5 - FIT, 0.0, POOP_DECK, True)
# The steering engine on her centreline against the flat's after wall, its quadrant on
# her rudder's head over it; too tall to climb (est.).
box("steering_engine", -19.8 + T, -18.9, -0.8, 0.8, STEERING_FLOOR, STEERING_FLOOR + 1.25, True)
for k, (x0, x1, z0, z1) in enumerate(POOP_HATCHES):
    ramp("poop_%d" % (k + 1), x1 - 2.6, z0, 2.6, z1 - z0, 0, STEERING_FLOOR, POOP_DECK, True)
STORES_HATCH = (-16.4, -14.25, -1.1, 1.1)
# Its floor stops at the face of the bulkhead before it, half a metre under the lower
# deck beyond: the two never meet, a hop up (bots never jump).
AFT_STORES = holed("aft_stores", "aft stores", -18.9, -13 - T, -3.0, 3.0, AFT_STORES_FLOOR, [STORES_HATCH],
                   fitted=True)
wall_x("aft_stores_aft", -18.9, -3.0, 3.0, AFT_STORES_FLOOR, STEERING_FLOOR, True)
for side, z in [("port", -3.0), ("starboard", 3.0)]:
    wall_z("aft_stores_" + side, z, -18.9, -14, AFT_STORES_FLOOR, STEERING_FLOOR, True)
    wall_z("aft_stores_%s_forward" % side, z, -14, -13, AFT_STORES_FLOOR, 0.0, True)
for k, (x0, x1, z0, z1) in enumerate(STEERING_HATCHES):
    ramp("steering_%d" % (k + 1), x0, z0, 2.65, z1 - z0, 0, STEERING_FLOOR, AFT_STORES_FLOOR, True)
platform("lower_aft_stores", "lower aft stores", -16.5, -13, -1.2, 1.2, LOWER_STORES_FLOOR, True)
wall_x("lower_aft_stores_aft", -16.5, -1.2, 1.2, LOWER_STORES_FLOOR, AFT_STORES_FLOOR, True)
for side, z in [("port", -1.2), ("starboard", 1.2)]:
    wall_z("lower_aft_stores_" + side, z, -16.5, -13, LOWER_STORES_FLOOR, AFT_STORES_FLOOR, True)
for k, (z0, z1) in enumerate([(-1.1, 0), (0, 1.1)]):
    ramp("aft_stores_%d" % (k + 1), STORES_HATCH[0], z0, 2.5, z1 - z0, 0, AFT_STORES_FLOOR, LOWER_STORES_FLOOR,
         True)
# The forepeak: the bosun's store under the forecastle, the chain locker under it down
# to where her forefoot narrows.
BOSUN_FLOOR, LOCKER_FLOOR = -1.5, -4.5
LOCKER_HATCH = (17.15, 18.9, -1.1, 1.1)
BOSUN = holed("bosuns_store", "bosun's store", 15, 19.9, -2.7, 2.7, BOSUN_FLOOR, [LOCKER_HATCH], fitted=True)
wall_x("bosuns_store_forward", 19.9, -2.7, 2.7, BOSUN_FLOOR, FCSL_DECK, True)
for side, z in [("port", -2.7), ("starboard", 2.7)]:
    wall_z("bosuns_store_" + side, z, 15 + T, 19.9, BOSUN_FLOOR, FCSL_DECK, True)
for k, (x0, x1, z0, z1) in enumerate(FCSL_HATCHES):
    ramp("forecastle_hatch_%d" % (k + 1), x0, z0, 3.3, z1 - z0, 0, FCSL_DECK, BOSUN_FLOOR, True)
LOCKER_SIDE = 1.8
# Its floor stops at the face of the bulkhead abaft it, the lower hold's floor beyond a
# hop under it.
platform("chain_locker", "chain locker", 15 + T, 19, -LOCKER_SIDE, LOCKER_SIDE, LOCKER_FLOOR, True)
wall_x("chain_locker_forward", 19, -LOCKER_SIDE, LOCKER_SIDE, LOCKER_FLOOR, BOSUN_FLOOR, True)
for side, z in [("port", -LOCKER_SIDE), ("starboard", LOCKER_SIDE)]:
    wall_z("chain_locker_" + side, z, 15 + T, 19, LOCKER_FLOOR, BOSUN_FLOOR, True)
# Either side of its stairs a bin the cable is stowed in, up to the bosun's store's
# floor, which its spurling pipe pays it out through to the windlass (est.).
for side, z0, z1 in [("port", -LOCKER_SIDE + T, -1.25), ("starboard", 1.25, LOCKER_SIDE - T)]:
    box("chain_bin_" + side, 16.0, 18.6, z0, z1, LOCKER_FLOOR, BOSUN_FLOOR, True)
for k, (z0, z1) in enumerate([(-1.1, 0), (0, 1.1)]):
    ramp("chain_locker_%d" % (k + 1), LOCKER_HATCH[1] - 3.0, z0, 3.0, z1 - z0, 0, LOCKER_FLOOR, BOSUN_FLOOR, True)

# Three sides of every hatch railed, as the stair openings are: the fourth, its stair's
# head, open.
def hatch_rails(rid, plat, hole, head):
    x0, x1, z0, z1 = hole
    sides = {"x0": ((x0, z0), (x0, z1)), "x1": ((x1, z0), (x1, z1)),
             "z0": ((x0, z0), (x1, z0)), "z1": ((x0, z1), (x1, z1))}
    for tag, (a, b) in sides.items():
        if tag != head:
            railing("%s_%s" % (rid, tag), plat, a, b)

for k, hole in enumerate(WING_MAIN + WING_SS):
    hatch_rails("wing_hatch_%d" % (k + 1), MAIN if hole[2] < 0 else SS, hole, "x0" if k % 2 == 0 else "x1")
for k, hole in enumerate(LOWER_HOLD_HATCHES):
    hatch_rails("lower_hold_hatch_%d" % (k + 1), L2, hole, ["x0", "x1"][k])
for k, hole in enumerate(BILGE_HATCHES):
    hatch_rails("bilge_hatch_%d" % (k + 1), L1, hole, ["x0", "z0", "x0", "z1"][k])
for k, hole in enumerate(POOP_HATCHES):
    hatch_rails("poop_hatch_%d" % (k + 1), POOP, hole, "x1")
for k, hole in enumerate(FCSL_HATCHES):
    hatch_rails("forecastle_hatch_%d" % (k + 1), FCSL, hole, "x0")
for k, hole in enumerate(STEERING_HATCHES):
    hatch_rails("steering_hatch_%d" % (k + 1), STEERING, hole, "x0")
hatch_rails("aft_stores_hatch", AFT_STORES, STORES_HATCH, "x0")
hatch_rails("chain_locker_hatch", BOSUN, LOCKER_HATCH, "x1")

# The rooms, after every other.
for side, z0, z1 in [("port", -LINING, 0), ("starboard", 0, LINING)]:
    room("double_bottom_" + side, "%s double bottom" % side, -3, 4, z0, z1, BILGE_FLOOR, crawl_space=True)
room("lower_hold", "lower hold", 4, 15, -LOWER_HOLD_SIDE, LOWER_HOLD_SIDE, BILGE_FLOOR)
room("shaft_tunnel", "shaft tunnel", -13, -3, -BILGE_SIDE, 0, BILGE_FLOOR)
room("bilge_stores", "stores", -13, -3, 0, BILGE_SIDE, BILGE_FLOOR)
for side, sign in [("port", -1), ("starboard", 1)]:
    room("side_passage_" + side, "%s side passage" % side, WING[0], WING[1],
         *sorted((sign * 3.8, sign * WING_SHELL)), WING_FLOOR, crawl_space=True)
room("steering_gear", "steering gear", -19.8, STEERING_FORWARD, -4.2, 4.2, STEERING_FLOOR)
room("aft_stores", "aft stores", -18.9, -13, -3.0, 3.0, AFT_STORES_FLOOR)
room("lower_aft_stores", "lower aft stores", -16.5, -13, -1.2, 1.2, LOWER_STORES_FLOOR)
room("bosuns_store", "bosun's store", 15, 19.9, -2.7, 2.7, BOSUN_FLOOR)
room("chain_locker", "chain locker", 15, 19, -LOCKER_SIDE, LOCKER_SIDE, LOCKER_FLOOR)

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

def fits():
    """Every fitted piece stands inside her lines, FIT clear of her shell, at the heights
    it stands at below her main deck; and none moves her decks' outline, which her lines
    are lofted from."""
    for x0, x1, z0, z1, heights in fitted_geo:
        for y in heights:
            for k in range(21):
                x = lerp(x0, x1, k / 20) + 0.0037  # off a deck's break, where none stands
                if y >= -PLANK - SLIVER:
                    continue
                assert hull.within(x, y), "fitted piece %s past her ends at %s" % ((x0, x1, z0, z1), (x, y))
                for side, reach in [(0, -z0), (1, z1)]:
                    assert hull.breadth(x, y, side) >= reach + FIT, \
                        "fitted piece %s through her shell at %s" % ((x0, x1, z0, z1), (x, y))
    for k in range(int((hull.span[1] - hull.span[0]) / 0.05)):
        x = hull.span[0] + 0.013 + k * 0.05  # off every deck's break
        assert envelope(x) == envelope(x, hull.plats), "the fitted pieces move her decks' outline at x %s" % x

fits()

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
# Each compartment's lower-deck floor has a bilge under it — the engine room's, the
# stokehold's floor, a double bottom (#74), out to her shell with no wing void; the hold
# has a side void either side, out from its walls, and a top under the forecastle — an
# air trap.
BEAM = max(max(-p[2], p[3]) for p in plat_geo)
HOLD_SIDE = 3.8
CELLS = [
    ("aft_peak", X_AFT, -13, KEEL, 0, -BEAM, BEAM, "VOID", None),
    ("poop_space", X_AFT, -14, 0, POOP_DECK, -4.5, 4.5, "STORES", None),
    ("aft_bilge_p", -13, -3, KEEL, LOWER, -BEAM, 0, "VOID", None),
    ("aft_bilge_s", -13, -3, KEEL, LOWER, 0, BEAM, "VOID", None),
    ("aft_cabins", -13, -3, LOWER, 0, -BEAM, BEAM, "ACCOMMODATION", None),
    ("engine_bilge_p", -3, 4, KEEL, TANK_TOP, -BEAM, 0, "VOID", None),
    ("engine_bilge_s", -3, 4, KEEL, TANK_TOP, 0, BEAM, "VOID", None),
    ("engine_room", -3, 4, TANK_TOP, 0, -BEAM, BEAM, "MACHINERY", None),
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
# its walkable blocker still reaches the deck. A head across a wall is the water's over
# the foot of each panel of it (SinkFailures): est., each is built for the head from her
# keel to its top, starts to leak at 1.25× that head and gives way at 1.5× it; a wall
# the hit ended beside, at half of both (the scenario's weakened_to).
def built_for(top):
    return top - KEEL

BULKHEADS = [
    ("bulkhead_aft", -13, 0.0, 1.5 * built_for(0.0)),
    ("bulkhead_engine", -3, 0.0, 1.5 * built_for(0.0)),
    ("bulkhead_hold", 4, LOWER + LINTEL, 1.5 * built_for(LOWER + LINTEL)),
    ("collision", 15, FCSL_DECK, 1.5 * built_for(FCSL_DECK)),
]
# The hold's side walls, along it: (name, z, top, collapse head est.) — lighter than a
# bulkhead, and leaky: a side void flooded to the sea bursts its wall only once she has
# settled well down (est.: 1.1× the head from her keel to the deck).
HOLD_WALLS = [("hold_side_p", -HOLD_SIDE, 0.0, 1.1 * built_for(0.0)),
              ("hold_side_s", HOLD_SIDE, 0.0, 1.1 * built_for(0.0))]
# What a wall leaks through once it leaks, in m² (est.: its rivets and seams).
WALL_LEAK = 0.002
# Her centre girder, along her keel under the after and engine rooms' floors from the
# after bulkhead to the hold's, 2.5 m high (est.): it parts each bilge's bottom into a
# port and a starboard half, so a gash floods the half on its side — the weight on one
# side, its loose water half as wide (the plan's lengthwise wall in a wide cell, R23) —
# until the water tops it and spills across. Limber holes through it leak est.
# 0.005 m² a bilge. Under the stokehold (#74) it stands only to her tank top, as strong,
# parting her double bottom's halves whole.
GIRDER = ("centre_girder", 0.0, KEEL + 2.5, 1.5 * built_for(KEEL + 2.5))
GIRDER_STOKEHOLD = "centre_girder_stokehold"
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
walls.append((name, "ALONG", z, (-13, -3), KEEL, top, collapse, parted(2, z, KEEL, top, -13, -3)))
walls.append((GIRDER_STOKEHOLD, "ALONG", z, (-3, 4), KEEL, TANK_TOP, collapse,
              parted(2, z, KEEL, TANK_TOP, -3, 4)))

# Openings: (name, kind, joins, centre, size, fields). size is the rectangle's extent
# along x, y and z, zero across the axis it is flat on.
SEA, SKY = "sea", "sky"
openings = []

def opening(name, kind, a, b, centre, size, **fields):
    openings.append((name, kind, [a or SKY, b or SKY], centre, size, fields))

# Doorways: open, as Q15 built them; in a watertight wall, a watertight door, shut by
# the ship at the hit over 20 s and jammed open one time in ten (est.). Its heads over
# its sill: leaking at the 2.6 m of the compartment it closes, by est. 0.005 m² round
# its seals, and giving way at 4.0 m (est.) — only one the hit weakened (× 0.5) bursts
# before the water tops the hold's wall.
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
                collapse_head=4.0, leak_area=0.005)
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
# hatch, battened (est.: its tarpaulin's seams weep 0.05 m² under 0.3 m of water and it
# gives way under 1 m); the hold open to the space under the forecastle over it.
for x0, x1, z0, z1 in STAIR_HOLES:
    below, above = cell_at((x0 + x1) * 0.5, -0.01, (z0 + z1) * 0.5), cell_at((x0 + x1) * 0.5, 0.01, (z0 + z1) * 0.5)
    opening("stair_%s_%s" % (below, above or SKY), "STAIRWELL", below, above,
            ((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5), (x1 - x0, 0, z1 - z0), starts="OPEN")
opening("hatch_hold", "HATCH", "hold", SKY, ((HATCH[0] + HATCH[1]) * 0.5, 0, (HATCH[2] + HATCH[3]) * 0.5),
        (HATCH[1] - HATCH[0], 0, HATCH[3] - HATCH[2]), starts="SHUT", leak_head=0.3,
        collapse_head=1.0, leak_area=0.05)
# The deck breaks' fittings, where the art sets them (ShipFittings._fit_break, with its
# numbers): the forecastle's after face has a weathertight door either side of its
# stair into the space under it, shut and dogged — so either way it weeps 0.01 m² at
# 1 m of water over its sill and gives way under 2 m, as a fire door does (FLOODSTAND;
# est.); the poop's forward face, too low for a door, louvred vents either side of a
# lifebelt, always open.
BREAK_DOOR, VENT_HALF = (0.72, 1.5), (0.24, 0.17)
for tag, z in [("p", -2.425), ("s", 3.0)]:
    opening("door_hold_fwd_top_" + tag, "DOOR", "hold_fwd_top", SKY,
            (12, 0.06 + BREAK_DOOR[1] * 0.5, z), (0, BREAK_DOOR[1], BREAK_DOOR[0]),
            starts="SHUT", leak_head=1.0, collapse_head=2.0, leak_area=0.01)
for tag, z in [("p", -1.647), ("s", 1.647)]:
    opening("vent_poop_space_" + tag, "VENT", "poop_space", SKY, (-14, 0.6, z),
            (0, VENT_HALF[1] * 2, VENT_HALF[0] * 2), starts="OPEN")
# The peaks are tanks, and a tank breathes through an air pipe to the deck over it (est.
# a 100 mm pipe): a gash floods a peak to the sea's level rather than leaving its air
# trapped under the deck (SH29) — the forepeak's pipe on the forecastle, the after
# peak's up into the poop space, which its vents let out.
AIR_PIPE = 0.008
peak = cell_box("forepeak")
opening("pipe_forepeak", "VENT", "forepeak", SKY, (18.0, peak[3], 0.0), (0.09, 0, 0.09),
        area=AIR_PIPE, starts="OPEN")
peak = cell_box("aft_peak")
opening("pipe_aft_peak", "VENT", "aft_peak", "poop_space", (-16.0, peak[3], 0.0), (0.09, 0, 0.09),
        area=AIR_PIPE, starts="OPEN")
top_box = cell_box("hold_fwd_top")
opening("open_hold_fwd_top", "OPEN", "hold", "hold_fwd_top",
        ((top_box[0] + top_box[1]) * 0.5, 0, 0), (top_box[1] - top_box[0], 0, top_box[5] - top_box[4]),
        starts="OPEN")
# The ways into her old voids (#148), chosen to move her flooding as little as they can:
# each a watertight scuttle in the deck over its space — the double bottom's manholes in
# her tank top too — so the space stays dry from above and keeps its air. No doorway
# pierces a wall along her.
def hatch(name, under, over, hole, deck):
    x0, x1, z0, z1 = hole
    opening(name, "HATCH", under, over, ((x0 + x1) * 0.5, deck, (z0 + z1) * 0.5), (x1 - x0, 0, z1 - z0),
            starts="SHUT")

for k, hole in enumerate(MANHOLES):
    hatch("manhole_%d" % (k + 1), "engine_bilge_p" if hole[2] < 0 else "engine_bilge_s", "engine_room", hole,
          TANK_TOP)
for k, hole in enumerate(LOWER_HOLD_HATCHES):
    hatch("hatch_hold_bilge_%d" % (k + 1), "hold_bilge", "hold", hole, LOWER)
for k, hole in enumerate(BILGE_HATCHES):
    bilge = "aft_bilge_p" if hole[2] < 0 else "aft_bilge_s"
    hatch("hatch_%s_%d" % (bilge, k % 2 + 1), bilge, "aft_cabins", hole, LOWER)
for k, hole in enumerate(WING_MAIN + WING_SS):
    wing = "hold_wing_p" if hole[2] < 0 else "hold_wing_s"
    hatch("hatch_%s_%d" % (wing, k % 2 + 1), wing, SKY, hole, 0.0)
# The steering gear stands up into the space under the poop with no deck between them,
# so the two are one space there; its hatches are in the poop.
opening("open_aft_peak", "OPEN", "aft_peak", "poop_space", (-16.9, 0, 0), (5.8, 0, 8.4), starts="OPEN")
for k, hole in enumerate(POOP_HATCHES):
    hatch("hatch_poop_space_%d" % (k + 1), "poop_space", SKY, hole, POOP_DECK)
for k, hole in enumerate(FCSL_HATCHES):
    hatch("hatch_forepeak_%d" % (k + 1), "forepeak", SKY, hole, FCSL_DECK)

# The lower-deck floors are not watertight: est. 0.05 m² of gaps between each and its
# bilge — a plated floor over the bilge, tight but for its limbers and sounding
# pipes, so a bilge keeps its air as the room over it floods (a capsized hull floats
# on it, §5b.4). The hold's side walls leak est. 0.02 m² into it.
# The stokehold's floor is its tank top, as gappy over the double bottom (#74); the
# girder stands to the tank top there, parting the double bottom's halves whole, so
# only its limber holes join them.
FLOOR_GAPS = 0.05
for room_cell, bilges in [("aft_cabins", ["aft_bilge_p", "aft_bilge_s"]),
                          ("engine_room", ["engine_bilge_p", "engine_bilge_s"]), ("hold", ["hold_bilge"])]:
    for bilge in bilges:
        b = cell_box(bilge)
        tag = "_" + bilge[-1] if len(bilges) > 1 else ""
        opening("floor_" + room_cell + tag, "FLOOR_GAPS", bilge, room_cell,
                ((b[0] + b[1]) * 0.5, b[3], (b[4] + b[5]) * 0.5), (b[1] - b[0], 0, b[5] - b[4]),
                area=round(FLOOR_GAPS / len(bilges), 4), starts="OPEN")
    if len(bilges) > 1:
        b = cell_box(bilges[0])
        girder_top = min(GIRDER[2], b[3])
        opening("limber_" + room_cell, "LEAK", bilges[0], bilges[1],
                ((b[0] + b[1]) * 0.5, (b[2] + girder_top) * 0.5, 0.0), (b[1] - b[0], girder_top - b[2], 0),
                area=LIMBER_HOLES, starts="OPEN")
        if girder_top < b[3]:
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
# art-lint` matches each pane it draws to one of these. Shut, a porthole's gasket weeps
# 0.0005 m² under 4 m of water and its glass breaks under 8 m (est.: 6 mm of annealed
# glass across its 0.32 m, a clamped plate); a window breaks under 2 m (est.). No
# porthole stands within PORT_FREEBOARD of her waterline: the stokehold's lining has none.
WINDOW_HEIGHT, WINDOW_SPACING, WINDOW_MARGIN = 1.45, 1.3, 0.4
PORT_FREEBOARD = 1.0
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

def wall_runs(room, glazed=False):
    """The full walls on room's floor along its sides, as ShipSpace.wall_runs: per run
    (side, from, to, half thickness); glazed, only those glass can go in — no fitted
    lining, which stands inside her shell (#148)."""
    x0, x1, z0, z1, floor, _name = room
    runs = []
    for side in range(4):
        along_x = side % 2 == 0
        line = [z0, x1, z1, x0][side]
        low, high = (x0, x1) if along_x else (z0, z1)
        pieces, half = [], 0.0
        for index, (bx0, bx1, bz0, bz1, bottom, top, is_box) in enumerate(block_geo):
            if not is_box or min(bx1 - bx0, bz1 - bz0) > WALL_MAX:
                continue
            if glazed and index in fitted_blocks:
                continue
            if abs(bottom - floor) >= 0.05:
                continue
            # Over FULL_WALL tall, or up to the deck over it (ShipSpace._full_wall_of).
            mid = (min(max((bx0 + bx1) * 0.5, x0), x1), min(max((bz0 + bz1) * 0.5, z0), z1))
            if top - bottom <= FULL_WALL and top < ceiling(floor, *mid) - SLIVER:
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
    for run in wall_runs(room, glazed=True):
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
            if in_hull and (side % 2 == 1 or height < WATERLINE + PORT_FREEBOARD):
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
                        flip_chance=0.0 if deadlights else 0.25, leak_head=4.0, collapse_head=8.0,
                        leak_area=0.0005)
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
    ("engine and boiler", 55e3, (1.2, -2.0 + TANK_TOP - LOWER, 0.0), (0, 2.5)),
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
# Its centre 1.8 m over her keel (est.): her GM about 1.2 m, the plan's (§5b.2).
BALLAST_Y = KEEL + 1.8
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
# What the sinking fails (§5b.1, est.): her funnel, standing 5 m over the boat deck from
# the deckhouse roof, held by stays to 28° of list and 15° of trim, down in 1.2 s, and
# crushing the wheelhouse roof — the bridge — if it lands on it; her generator in the
# engine room's starboard lane, drowned by 1 m of water over its foot, stopped past 25°
# of list or 12° of trim (SOLAS-based) and running again 3° back within both, its
# emergency power lighting the saloon, the hall and the wheelhouse for 30 minutes; a
# bilge pump either side of her engine bilge's girder, 0.025 m³/s each while it runs.
FUNNEL = dict(name="funnel", base=(-6.0, 2.5, 0.0), height=5.0, radius=0.9, list=28.0, trim=15.0,
              fall=1.2, crushes=["bridge"])
GENERATOR = dict(name="generator", cell="engine_room", base=(1.25, LOWER, 2.6), drowns=1.0,
                 list=25.0, trim=12.0, recovers=3.0, minutes=30.0,
                 emergency=["saloon", "deckhouse_hall", "wheelhouse"])
PUMPS = [("bilge_pump_p", "engine_bilge_p", 0.025), ("bilge_pump_s", "engine_bilge_s", 0.025)]
# The bending her hull carries (est.: her flooding loads stay far below it), in N·m.
STRENGTH = (120e6, 110e6)
# Her test-only weak hull (SH33, --weak): her strength divided by this, and the places
# along her she can break — (name, x, the share of that strength the spot keeps) — the
# aft one an expansion joint over the cabins, the midships one the engine room's casing
# amidships, over the stokehold (#74). Est., measured on her match hits: chosen so some
# break her in two and a few in three, every piece gone (the pinned seeds breaks_in_two
# and breaks_in_three). Against this weak strength her own weight sags her amidships by
# about 0.18 and a hit flooding her engine room by about 0.23, so the midships spot,
# keeping 0.2, parts under the second alone; a hit aft hogs her at the aft joint past
# its 0.2, and the piece fore of that break bends at most about 0.17 amidships, too
# little to part it there. The midships spot stands no further forward: a piece fore of a
# break at x 2 or more floats on her hold and forepeak, so she would not be gone.
WEAK_DIVISOR = 8.0
WEAK_SPOTS = [("aft_joint", -8.0, 0.2), ("midships_joint", 0.0, 0.2)]
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
    # Three figures of it: num()'s four places would round a small cell's leak to none.
    f.append(("leak_area", ("%.8f" % float("%.3g" % (inside * AIR_LEAK))).rstrip("0")))
    cell_ids.append(sub("Cell_" + name, "11_cell", f))
wall_ids = []
for name, axis, at, span, bottom, top, collapse, parts in walls:
    f = [("name", '&"%s"' % name)]
    if axis == "ALONG":
        f.append(("axis", "1"))
    f += [("at", num(at)), ("span", "Vector2(%s, %s)" % (num(span[0]), num(span[1]))),
          ("bottom", num(bottom)), ("top", num(top)), ("collapse_head", num(collapse))]
    if name not in (GIRDER[0], GIRDER_STOKEHOLD):
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
    for key in ["flip_chance"]:
        if fields.get(key):
            f.append((key, num(fields[key])))
    if fields.get("shuts_at_hit"):
        f.append(("shuts_at_hit", "true"))
    for key in ["shut_time", "leak_head", "collapse_head", "leak_area"]:
        if fields.get(key):
            f.append((key, num(fields[key])))
    if fields.get("opens_toward"):
        f.append(("opens_toward", '&"%s"' % fields["opens_toward"]))
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
fitting_ids.append(sub("Fitting_" + FUNNEL["name"], "16_fitting", [
    ("kind", "1"), ("name", '&"%s"' % FUNNEL["name"]), ("x", num(FUNNEL["base"][0])),
    ("list_limit_deg", num(FUNNEL["list"])), ("trim_limit_deg", num(FUNNEL["trim"])),
    ("base", vec3(FUNNEL["base"])), ("height", num(FUNNEL["height"])),
    ("radius", num(FUNNEL["radius"])), ("fall_time", num(FUNNEL["fall"])),
    ("crushes", names(FUNNEL["crushes"]))]))
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
def strength_fields():
    """Her strength's fields: as she is, or her weak hull's (--weak)."""
    if not weak:
        return [("hog", num(STRENGTH[0])), ("sag", num(STRENGTH[1]))]
    spots = [sub("Weak_" + name, "18_weak", [("name", '&"%s"' % name), ("x", num(x)),
                                           ("share", num(share))])
             for name, x, share in WEAK_SPOTS]
    return [("hog", num(STRENGTH[0] / WEAK_DIVISOR)), ("sag", num(STRENGTH[1] / WEAK_DIVISOR)),
            ("weak", arr("18_weak", spots))]

sub("Structure", "9_structure", [
    ("waterline_y", num(WATERLINE)), ("keel_y", num(KEEL)),
    ("sections", arr("10_section", section_ids)), ("cells", arr("11_cell", cell_ids)),
    ("walls", arr("12_wall", wall_ids)), ("openings", arr("13_opening", opening_ids)),
    ("mass", arr("14_mass", mass_ids))] + [(k, num(v)) for k, v in MOTION] + [
    ("fittings", arr("16_fitting", fitting_ids)),
    ("strength", 'SubResource("%s")' % sub("Strength", "17_strength", strength_fields())),
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

lifebuoy(-5.0, -1, 0.0)
lifebuoy(7.0, 1, 0.0)
lifebuoy(18.5, -1, 1.8)

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
if weak:
    head += '[ext_resource type="Script" path="res://core/sinking/weak_spot.gd" id="18_weak"]\n'
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
       'structure = SubResource("Structure")']
with open(out, "w") as f:
    f.write(head + "\n" + "\n\n".join(subs) + "\n\n" + "\n".join(res) + "\n")
print(len(platforms), "platforms", len(ramps), "ramps", len(blockers), "blockers", len(railings), "railings", len(ladders), "ladders", len(props), "props", len(rooms), "rooms")
print(len(sections), "sections", len(CELLS), "cells", len(walls), "walls", len(openings), "openings", len(MASS),
      "masses: %.1f t, ballast %.1f t at x %.3f z %.3f" % (weight / 1000, ballast / 1000, ballast_x, ballast_z))
