#!/usr/bin/env python3
"""Writes the Titanic's layout and structure, data/ships/titanic.tres (SH34).

The layout and structure are generated: change her here, then `make ship SHIP=titanic`.
`make ship-gen-check` (part of `make verify`) fails when the committed .tres is not what
this writes, so a hand edit to the .tres is caught. The sim reads only the .tres (D6).

RMS Titanic at full size, traced only from public-domain sources (R31), each traced
number beside its plate below (PLATES): her length, beam and decks, her sixteen
compartments and the bulkheads A–P between them, their tops measured off the 1911
profile (R32), her doors, her machinery, her boats. Every number not traced is marked
est. with its reasoning. Her hull is lofted here from her dimensions, not as ShipHull
lofts the steamer's, so the dressed art draws it from her sections (SectionHull, SH23;
ShipLayout.dressed).

Ship-local metres: x toward the bow, z to starboard, y up, origin on C deck — the
inquiry's "highest deck which extends continuously from bow to stern" — amidships.
Her decks are laid flat at their amidships heights (the inquiry's table); her sheer
lives in her bulkhead tops, her stepped forecastle and poop, and nowhere else.

`--variant=olympic1913` and `--variant=britannic` write her sisters as test-only hulls
(tests/fixtures/ships/titanic_olympic_1913.tres, titanic_britannic.tres), played by name
as her variants are but never in the menu's fleet: the same hull with their bulkhead data — five bulkheads carried up to B deck and an inner
skin along her boiler and engine rooms; Britannic's a sixteenth bulkhead too.

Usage: tools/gen_titanic.py <out.tres> [--variant=olympic1913|--variant=britannic]
"""
import functools
import math
import re
import struct
import sys

from floor_spots import spots_below_decks
from titanic_plates import deck as plates

out = sys.argv[1]
variant = next((a.split("=", 1)[1] for a in sys.argv[2:] if a.startswith("--variant=")), "")
assert variant in ("", "olympic1913", "britannic"), variant

# --- The plates every traced number below is read from (R31: public domain only).
PLATES = {
    # The Shipbuilder's Olympic and Titanic special number (1911), Plate III, headed "The
    # White Star triple-screw steamers Olympic and Titanic", June 1911: her elevation,
    # boat deck and promenade deck A.
    # Internet Archive the_shipbuilder_special_numbers_images_201909, leaf n316, Public
    # Domain Mark 1.0. Read off the 5510-px scan at 5.785 px a foot, x from her after
    # perpendicular (the rudder post), heights from her drawn 34 ft 7 in waterline. The
    # px given below are in the elevation cut from that scan at x 200–5420, y 820–1460:
    # add 200 for the scan's own column.
    "SB-III": "The Shipbuilder 1911, Plate III (elevation; boat and promenade decks)",
    # The same number's Plate IV (leaf n318): bridge, shelter, saloon and upper decks.
    "SB-IV": "The Shipbuilder 1911, Plate IV (decks B-E)",
    # The same number's text: Table II (dimensions), "Structural design" and
    # "Watertight subdivision".
    "SB-text": "The Shipbuilder 1911, text",
    # The British Wreck Commissioner's inquiry, report (1912), Annex 1 "Description of
    # the ship" and 3 "Description of the damage"; Crown copyright long expired.
    "BOT": "1912 British inquiry, report",
    # The same inquiry's evidence: Edward Wilding of Harland & Wolff, day 19.
    "Wilding": "1912 British inquiry, Wilding's evidence",
    # The Shipbuilder vol. 10 (January-June 1914), "The White Star liner Britannic" and
    # "Shipbuilding centres": her sisters' inner skin and bulkheads. Internet Archive
    # the_shipbuilder_vol10, Public Domain Mark 1.0.
    "SB-1914": "The Shipbuilder 1914 (vol. 10)",
}
FT = 0.3048

def num(v):
    v = round(v, 4)
    if v == int(v):
        return str(int(v))
    return repr(v)

def rect(x, z, w, d):
    return "Rect2(%s, %s, %s, %s)" % (num(x), num(z), num(w), num(d))

def rect_xz(x0, x1, z0, z1):
    return rect(x0, z0, x1 - x0, z1 - z0)

def clamp(v, a, b):
    return min(max(v, a), b)

def lerp(a, b, t):
    return a + (b - a) * t

subs = []
platforms, ramps, blockers, railings, ladders, rooms, props = [], [], [], [], [], [], []
rail_geo = []  # per railing, (platform, from, to)
used = set()
# The same pieces as numbers: (x0, x1, z0, z1, height) per platform; (x0, x1, z0, z1,
# axis, start, end) per ramp; (x0, x1, z0, z1, bottom, top, is a box) per blocker; (x0,
# x1, z0, z1, floor, name) per room; and every doorway as (axis, at, from, to, bottom): a
# gap in a wall along x = at (axis 0) or z = at (axis 2).
plat_geo, ramp_geo, block_geo, room_geo, doorways = [], [], [], [], []

def sub(kind_id, script, fields):
    assert kind_id not in used, kind_id
    used.add(kind_id)
    body = ["[sub_resource type=\"Resource\" id=\"%s\"]" % kind_id, "script = ExtResource(\"%s\")" % script]
    for k, v in fields:
        body.append("%s = %s" % (k, v))
    subs.append("\n".join(body))
    return kind_id

def platform_fields(name, x0, x1, z0, z1, h):
    f = [("name", '&"%s"' % name), ("area", rect_xz(x0, x1, z0, z1))]
    if h != 0.0:
        f.append(("height", num(h)))
    return f

def platform(pid, name, x0, x1, z0, z1, h=0.0):
    plat_geo.append((x0, x1, z0, z1, h))
    platforms.append(sub("Platform_" + pid, "1_plat", platform_fields(name, x0, x1, z0, z1, h)))
    return len(platforms) - 1

def relay(index, name, x0, x1, z0, z1, h):
    """Platform index laid again over (x0..x1, z0..z1) at h, keeping its place and id."""
    plat_geo[index] = (x0, x1, z0, z1, h)
    kind_id = platforms[index]
    at = next(i for i, text in enumerate(subs) if text.startswith('[sub_resource type="Resource" id="%s"]' % kind_id))
    body = ["[sub_resource type=\"Resource\" id=\"%s\"]" % kind_id, "script = ExtResource(\"1_plat\")"]
    body += ["%s = %s" % kv for kv in platform_fields(name, x0, x1, z0, z1, h)]
    subs[at] = "\n".join(body)

# The steepest stair a body climbs: its rise a body's radius on under a step, both read
# from data/rules/brawl.tres (as the trawler's generator reads them).
def rule(key):
    with open("data/rules/brawl.tres") as f:
        return float(re.search(r"^%s = ([\d.]+)$" % key, f.read(), re.M).group(1))

STEEPEST = rule("step_height") / rule("body_radius")

def ramp(rid, x0, x1, z0, z1, axis, start, end):
    """A stair over (x0..x1, z0..z1) rising along x (axis 0) or z (axis 1)."""
    assert abs(end - start) / (x1 - x0 if axis == 0 else z1 - z0) <= STEEPEST, "stair %s too steep to climb" % rid
    ramp_geo.append((x0, x1, z0, z1, axis, start, end))
    f = [("area", rect_xz(x0, x1, z0, z1))]
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

def relay_box(bid, x0, x1, z0, z1, bottom, top):
    """Box bid laid again over (x0..x1, z0..z1) from bottom to top, keeping its place and id."""
    kind_id = "Blocker_" + bid
    block_geo[blockers.index(kind_id)] = (x0, x1, z0, z1, bottom, top, True)
    at = next(i for i, text in enumerate(subs) if text.startswith('[sub_resource type="Resource" id="%s"]' % kind_id))
    f = [("area", rect_xz(x0, x1, z0, z1))]
    if bottom != 0.0:
        f.append(("bottom", num(bottom)))
    f.append(("top", num(top)))
    body = ["[sub_resource type=\"Resource\" id=\"%s\"]" % kind_id, "script = ExtResource(\"3_block\")"]
    subs[at] = "\n".join(body + ["%s = %s" % kv for kv in f])

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
        rail_geo.append((plat, ends[k], ends[k + 1]))

def rehome(index, plat):
    """Railing index laid again on platform plat, keeping its place and id."""
    _old, a, b = rail_geo[index]
    rail_geo[index] = (plat, a, b)
    kind_id = railings[index]
    at = next(i for i, text in enumerate(subs) if text.startswith('[sub_resource type="Resource" id="%s"]' % kind_id))
    f = [("platform", str(plat))] if plat != 0 else []
    f += [("from", "Vector2(%s, %s)" % (num(a[0]), num(a[1]))), ("to", "Vector2(%s, %s)" % (num(b[0]), num(b[1])))]
    body = ["[sub_resource type=\"Resource\" id=\"%s\"]" % kind_id, "script = ExtResource(\"4_rail\")"]
    subs[at] = "\n".join(body + ["%s = %s" % kv for kv in f])

def room(rid, name, x0, x1, z0, z1, floor, crawl_space=False):
    room_geo.append((x0, x1, z0, z1, floor, name))
    f = [("name", '&"%s"' % name), ("area", rect_xz(x0, x1, z0, z1))]
    if floor != 0.0:
        f.append(("floor_height", num(floor)))
    if crawl_space:
        f.append(("crawl_space", "true"))
    rooms.append(sub("Room_" + rid, "6_room", f))

T = 0.1  # half a wall's thickness: walls are 0.2 m, centred on a room's side
DOOR = 1.1
LINTEL = 2.1  # a door's height above its floor

def wall_x(bid, x, z0, z1, bottom, top, doors=()):
    """Wall pieces along x = const from z0 to z1 (centre line), ends overlapping
    corners, with door gaps [(a, b)] in z and a lintel over each."""
    edges = [z0 - T] + [v for d in doors for v in d] + [z1 + T]
    for i in range(0, len(edges), 2):
        box("%s_%d" % (bid, i // 2) if doors else bid, x - T, x + T, edges[i], edges[i + 1], bottom, top)
    for i, d in enumerate(doors):
        if bottom + LINTEL < top:
            box("%s_lintel_%d" % (bid, i), x - T, x + T, d[0], d[1], bottom + LINTEL, top)
        doorways.append((0, x, d[0], d[1], bottom))

def wall_z(bid, z, x0, x1, bottom, top, doors=()):
    edges = [x0 - T] + [v for d in doors for v in d] + [x1 + T]
    for i in range(0, len(edges), 2):
        box("%s_%d" % (bid, i // 2) if doors else bid, edges[i], edges[i + 1], z - T, z + T, bottom, top)
    for i, d in enumerate(doors):
        if bottom + LINTEL < top:
            box("%s_lintel_%d" % (bid, i), d[0], d[1], z - T, z + T, bottom + LINTEL, top)
        doorways.append((2, z, d[0], d[1], bottom))

def door_at(middle):
    return (middle - DOOR / 2, middle + DOOR / 2)

# --- Her heights. The inquiry's table of decks (BOT, "Structural arrangements"): each
# deck's height to the next above, and its height over her 34 ft 7 in load waterline
# amidships — C deck 30 ft 6 in over it, the origin; the double bottom 5 ft 3 in deep,
# 6 ft 3 in under the reciprocating engines (SB-text).
# Every height a floor stands at, or a cell's floor or ceiling, is kept to the nearest
# 1/16 m: a deck and its cell's dry water then meet exactly in single precision, where
# the inquiry's feet would leave a deck a hair under its own dry floor (Surfaces.wet).
def q(v):
    return round(v * 16) / 16

LOAD_WL = -30.5 * FT                       # BOT: C deck 30 ft 6 in over the load waterline
KEEL = q(LOAD_WL - (34 + 7 / 12) * FT)     # BOT: 34 ft 7 in draught at load
BOAT = q((9.5 + 9.0 + 9.0) * FT)           # BOT: boat→A 9 ft 6 in, A→B 9 ft, B→C 9 ft
A_DECK = q(18.0 * FT)
B_DECK = q(9.0 * FT)
D_DECK = q(-10.5 * FT)                     # BOT: D→C 10 ft 6 in
E_DECK = q(-19.5 * FT)                     # BOT: E→D 9 ft
F_DECK = q(-28.0 * FT)                     # BOT: F→E 8 ft 6 in
G_DECK = q(-36.0 * FT)                     # BOT: G→F 8 ft
ORLOP = q(-44.0 * FT)                      # BOT: "spaced about 8 ft apart"
TANK_TOP = q(KEEL + 5.25 * FT)             # SB-text: double bottom 5 ft 3 in deep
ENGINE_TANK_TOP = q(KEEL + 6.25 * FT)      # SB-text: 6 ft 3 in in the reciprocating engine room
# The night's condition (§5b.2's research): a mean draught of 9.83 m — the inquiry has
# her boat deck "about 60.5 ft" over the sea then (BOT), 9.78 m of draught on these decks.
DRAUGHT = 9.83
WATERLINE = q(KEEL + DRAUGHT)
FREEBOARD = -WATERLINE

# --- Her length and her bulkheads, off Plate III (SB-III): x from amidships, the middle
# of her 850 ft between perpendiculars (SB-text, Table II), read at 18.98 px a metre.
# Her after perpendicular is her rudder post (px 233), her forward one her stem at the
# waterline (px 5150): 850.1 ft apart. Her length over all is 882 ft 9 in (SB-text).
X_FP = 129.50                              # SB-III, px 5150
X_AP = -129.58                             # SB-III, px 233
X_FORE = 130.80                            # SB-III, her stem's head
X_AFT = X_FORE - (882 + 9 / 12) * FT       # SB-text: 882 ft 9 in over all
HALF = 92.0 * FT / 2                       # SB-text: 92 ft moulded (92 ft 6 in extreme)
# Each bulkhead (BOT: "referred to as A to P, commencing forward"): where Plate III
# draws it at her tank top, the deck BOT says it is watertight to, and that deck's
# height there over her load waterline in feet — R32: measured off Plate III where
# its dashed deck line crosses the bulkhead, less the 0.9 ft its lines stand above the
# inquiry's amidships heights (D 20 ft 0 in, E 11 ft 0 in). BOT: "A and B, and all
# bulkheads from K (90 ft abaft amidships) to P ... up to the underside of D deck"; the
# rest to E; "A extended to C deck, but it was watertight only to D deck". K reads
# 90.9 ft abaft amidships off the plate.
BULKHEADS = [  # (letter, x, the deck its top is, feet over the load waterline)
    ("A", 115.81, "D", 28.8),
    ("B", 101.85, "D", 26.6),
    ("C", 86.30, "E", 15.7),
    ("D", 70.76, "E", 14.5),
    ("E", 54.01, "E", 13.3),
    ("F", 36.46, "E", 12.4),
    ("G", 19.18, "E", 11.5),
    ("H", 1.69, "E", 11.0),
    ("J", -16.75, "E", 11.2),
    ("K", -27.71, "D", 20.0),
    ("L", -48.63, "D", 19.8),
    ("M", -66.02, "D", 20.2),
    ("N", -85.14, "D", 20.9),
    ("O", -101.69, "D", 21.7),
    ("P", -118.97, "D", 23.5),
]
BX = {b[0]: b[1] for b in BULKHEADS}
TOPS = {b[0]: round(LOAD_WL + b[3] * FT, 4) for b in BULKHEADS}
# Her sisters (SB-1914): Britannic's "sixteen transverse bulkheads, five of which extend
# to a height of over 40 feet above the deepest load-line" — B deck, 41.1 ft over it
# here — and an inner skin "from the watertight bulkhead in front of the forward boiler
# room to the after end of the turbine engine room ... from the tank top to a point well
# above the load water-line", as wide as her 30 in web frames (SB-text). Which five,
# where her sixteenth stands and how high the skin runs are est.: the five forward
# boiler-room bulkheads D–H, the sixteenth halving the electric engine room, the skin to
# F deck. Olympic's 1913 refit gave her the same inner skin (SB-1914: "to alter the
# Baltic and other liners similarly to the Olympic by the introduction of an inner
# skin"); her raised bulkheads are est. as Britannic's five.
if variant:
    for letter in "DEFGH":
        TOPS[letter] = B_DECK
if variant == "britannic":
    BULKHEADS.insert(12, ("MN", -75.58, "D", 20.5))
    BX["MN"] = -75.58
    TOPS["MN"] = round(LOAD_WL + 20.5 * FT, 4)
SKIN = 30 * 0.0254 if variant else 0.0
SKIN_RUN = (BX["M"], BX["D"])
# The cross bunker at the forward end of each boiler room, its after side where Plate
# III dashes it (SB-III; Wilding: "the watertight bulkheads are in coal bunkers").
BUNKERS = {"br6": 67.80, "br5": 51.32, "br4": 33.35, "br3": 16.12, "br2": -2.42, "br1": -20.34}
# Her funnels' feet on the boat deck, raked, and their tops 42.2 m over her load
# waterline (SB-III; 173 ft keel to top, "about 175 ft"): the middles of their bases where
# the elevation draws them on the house tops (px 7848, 6478, 5072 and 3680 on the full
# 11019-px scan), each over its casing in the boat deck's plan (tools/titanic_plates); their
# 24 ft 6 in by 19 ft section as one round as wide as it, 19 ft, inside its casing.
FUNNELS = [54.38, 18.29, -18.76, -55.43]
FUNNEL_TOP = LOAD_WL + 42.2
FUNNEL_RADIUS = 2.9
# Her superstructure's runs (SB-III, SB-text): the forecastle 128 ft at its height; the
# open well decks at C between it, B deck and the poop. (Plate IV's views agree with it to
# within their calibration's 0.6 m, and C deck's view puts the rooms under it within 0.1
# m of it.) The poop's front where C deck's view draws it (c.py, #368), the third-class
# entrance's forward wall under it: -106.63 against the elevation's -106.55 (SB-III); the
# texts' 106 ft would put it 0.7 m forward, into No. 6 hatch's coaming.
FCSL_FROM = X_FORE - 128 * FT
# Plates III and IV's decks, traced room by room (#360): their rooms, walls, doors, stairs
# and casings in ship metres (tools/titanic_plates). The boat deck runs from its after end
# to the bridge's wings, the navigating bridge forward of them; A deck from where it steps
# in aft to its forward end, its front carried on to B deck's, the ladders from its front
# down to the forward well's over B deck's assembling area (est.). B deck, the bridge
# deck, as the Titanic sailed in 1912 (b.py): from where her side steps in aft — her
# rounded after end aft of that, over the after well — to her forward end, 550 ft at her
# side (SB-text: "the bridge deck B 550 ft"); her house under A deck from her restaurant's
# after wall to her house's front, the assembling area forward of it (BOT), her
# second-class promenade aft of it with its houses on it. Its rooms are laid once her side
# is (B_PLAN, below), each held to the strip of her deck it stands on.
BOAT_PLAN = plates.load("boat")
A_PLAN = plates.load("a")
B_OUTLINE = plates.load("b")
C_OUTLINE = plates.load("c")
BOAT_RUN = BOAT_PLAN.decks[0][:2]
B_RUN = B_OUTLINE.decks[0][:2]
A_RUN = (A_PLAN.decks[0][0], max(A_PLAN.decks[0][1], B_RUN[1]))
POOP_TO = next(r[2] for r in C_OUTLINE.rooms if r[0] == "third-class entrance, C deck")

def in_house(room, houses):
    """Whether room's middle stands in one of houses (name, x0, x1, z0, z1)."""
    mx, mz = (room[1] + room[2]) * 0.5, (room[3] + room[4]) * 0.5
    return any(h[1] <= mx <= h[2] and h[3] <= mz <= h[4] for h in houses)

B_HOUSE = (min(r[1] for r in B_OUTLINE.rooms if not in_house(r, B_OUTLINE.houses)), max(r[2] for r in B_OUTLINE.rooms))
# Her expansion joints, through the boat deck and A deck (BOT: "The Boat deck and A
# deck each had two expansion joints"), where Plate III draws them: over boiler room 5
# and over the after end of boiler room 1 (SB-III).
JOINTS = [("aft_joint", -26.6), ("forward_joint", 43.6)]

# --- Her lines (est., tuned to the inquiry and the research): a flat-bottomed midship
# section with a round bilge of BILGE radius; waterlines full over her parallel middle
# body from AFT_BODY to FWD_BODY and closing on her stem and her stern as one less a
# power of the way there — FINE_FWD and FINE_AFT at her load waterline, LOW_FWD and
# LOW_AFT of that at her keel, fuller above it as her flare is. Tuned so that at 34 ft
# 7 in she displaces 53 029 t against the inquiry's 52 310 tons (53 149 t, BOT), 49 089 t
# at the night's draught against the research's 49 075 t, and with the six compartments
# the night opened flooded to the sea she trims 0.19° a 1 000 tons pivoting 179 m from
# her bow, as the research has her (test_titanic_static.gd). Her stem is near plumb,
# raked STEM_RAKE per metre up, rounding into her keel over FOREFOOT; her counter
# springs from her rudder post at KNUCKLE over the load waterline out to her stern.
BILGE = 1.9
FWD_BODY, AFT_BODY = 24.0, -44.0
FINE_FWD, FINE_AFT = 2.0, 1.4
LOW_FWD, LOW_AFT = 0.45, 0.7
STEM_RAKE = 0.03
FOREFOOT = 4.0
KNUCKLE = LOAD_WL + 1.2

def stem_x(y):
    if y >= KEEL + FOREFOOT:
        return X_FP + (y - LOAD_WL) * STEM_RAKE
    t = (KEEL + FOREFOOT - y) / FOREFOOT
    return X_FP + (KEEL + FOREFOOT - LOAD_WL) * STEM_RAKE - FOREFOOT * (1 - math.sqrt(max(1 - t * t, 0.0)))

def stern_x(y):
    if y <= KNUCKLE:
        return X_AP
    t = clamp((y - KNUCKLE) / (D_DECK - KNUCKLE), 0.0, 1.0)
    return X_AP + (X_AFT - X_AP) * math.sqrt(1 - (1 - t) ** 2)

# Her counter (#360, #368, #369): over her load waterline her stern is a broad round
# counter, as Plate IV's C, D and E deck views draw her shell aft — 9 m out from her
# centre line 8 m from her stern's tip at C deck, 11 m at 20 m, where her lines' law
# above left 3 m and 6.5 m, and her traced decks' rooms stand. Each deck's half breadth
# by the distance from her stern's tip there (stern_x), read off its view: her shell's
# outer line, both sides' mean less its plating; C deck's from C deck up, D deck's and E
# deck's at theirs (E deck's view on D deck's scale from its own tip), and between them in
# proportion to her height; from her load waterline up to E deck her side flares out of
# her lines' into E deck's (counter_half()). Where her lines are fuller they stand; under
# her load waterline, where her displacement, her trim and her stability are (the night's
# draught is 0.7 m under it), nothing changes.
COUNTER_PLANS = [  # (height, [(distance from her stern's tip, half breadth)])
    (E_DECK, [(0.0, 0.0), (0.8, 0.85), (1.8, 2.25), (2.9, 3.35), (3.9, 4.3), (5.0, 5.05), (6.0, 5.75),
              (8.1, 6.85), (10.2, 7.7), (12.3, 8.4), (14.4, 9.0), (16.4, 9.5), (18.5, 9.95), (20.6, 10.35),
              (22.7, 10.7), (24.8, 11.0), (26.9, 11.3), (27.9, 11.45), (35.2, 12.2), (43.6, 12.85),
              (50.9, 13.25), (55.1, 13.4), (64.5, 13.5), (67.6, 13.55), (88.0, 14.02)]),
    (D_DECK, [(0.0, 0.0), (0.4, 3.65), (1.5, 5.45), (2.5, 6.55), (3.6, 7.4), (4.6, 7.95), (5.6, 8.4),
              (6.7, 8.75), (7.7, 9.15), (8.8, 9.35), (9.8, 9.75), (10.9, 9.95), (11.9, 10.1),
              (13.0, 10.3), (14.0, 10.5), (15.0, 10.65), (16.1, 10.8), (17.1, 10.95), (18.2, 11.1),
              (19.2, 11.25), (20.3, 11.35), (21.3, 11.45), (22.4, 11.55), (23.4, 11.65), (24.4, 11.75),
              (25.5, 11.85), (26.5, 11.9), (27.6, 12.0), (28.6, 12.1), (30.7, 12.2), (32.8, 12.35),
              (34.9, 12.45), (37.0, 12.6), (39.1, 12.7), (41.2, 12.85), (43.2, 12.95), (45.3, 13.05),
              (47.4, 13.15), (50.6, 13.25), (54.7, 13.45), (58.9, 13.6), (63.1, 13.7), (67.3, 13.8),
              (70.4, 13.9), (88.0, 14.02)]),
    (0.0, [(0.0, 0.0), (0.5, 3.9), (1.5, 5.65), (2.5, 6.65), (3.5, 7.35), (4.5, 7.85), (5.5, 8.3),
           (6.5, 8.65), (7.5, 8.95), (8.6, 9.25), (9.6, 9.5), (10.6, 9.75), (11.6, 9.95), (12.7, 10.15),
           (13.7, 10.35), (14.7, 10.55), (15.7, 10.7), (16.7, 10.85), (17.7, 11.0), (18.7, 11.15),
           (19.7, 11.3), (20.8, 11.4), (21.8, 11.55), (22.8, 11.7), (23.8, 11.8), (24.8, 11.9), (25.8, 12.0),
           (26.8, 12.1), (27.8, 12.2), (28.9, 12.3), (29.9, 12.4), (30.9, 12.5), (33.9, 12.65),
           (36.9, 12.75), (39.0, 12.8), (41.0, 13.05), (44.0, 13.2), (48.0, 13.35), (55.0, 13.5),
           (62.0, 13.7), (70.0, 13.8), (88.0, 14.02)]),
]

def plan_half(table, s):
    """table's half breadth at s, read linearly between its points; past its last, that."""
    for (s0, h0), (s1, h1) in zip(table, table[1:]):
        if s <= s1:
            return h0 + (h1 - h0) * (s - s0) / (s1 - s0)
    return table[-1][1]

def counter_half(x, y, lines):
    """Her counter's half breadth at (x, y), over her load waterline (COUNTER_PLANS), where
    her lines give her lines: up to E deck flaring out of them into E deck's, by a
    smoothstep of her height over her load waterline, so her side leaves her lines with no
    knuckle — her shell's runs, meeting at her poop's front each on the curve half way
    between their sections' sides, cut a knuckle there by a third of a metre; over it,
    never narrower than at the deck under it, so her side never turns in as it climbs —
    the views disagree by a tenth of a metre here and there, and a side turning in ends
    her shell's side there (SectionHull._side()), her sheer read down at it."""
    s = x - stern_x(y)
    below_y, table = COUNTER_PLANS[0]
    below = plan_half(table, s)
    if y <= below_y:
        t = (y - LOAD_WL) / (below_y - LOAD_WL)
        return lines + max(below - lines, 0.0) * t * t * (3.0 - 2.0 * t)
    for height, table in COUNTER_PLANS[1:]:
        here = max(plan_half(table, s), below)
        if y <= height:
            return below + (here - below) * (y - below_y) / (height - below_y)
        below_y, below = height, here
    return below

def breadth(x, y):
    """Her half breadth at (x, y): her lines, and over her load waterline aft her counter."""
    if y < KEEL or x >= stem_x(y) or x <= stern_x(y):
        return 0.0
    rise = y - KEEL
    side = HALF if rise >= BILGE else HALF - BILGE + math.sqrt(max(BILGE * BILGE - (BILGE - rise) ** 2, 0.0))
    up = (y - KEEL) / (LOAD_WL - KEEL)
    fore = after = 1.0
    if x > FWD_BODY:
        power = FINE_FWD * (LOW_FWD + (1 - LOW_FWD) * up) if up <= 1.0 else FINE_FWD * (1.0 + 1.5 * min(up - 1.0, 1.0))
        fore = 1.0 - ((x - FWD_BODY) / (stem_x(y) - FWD_BODY)) ** power
    if x < AFT_BODY:
        power = FINE_AFT * (LOW_AFT + (1 - LOW_AFT) * up) if up <= 1.0 else FINE_AFT * (1.0 + 1.2 * min(up - 1.0, 1.0))
        after = 1.0 - ((AFT_BODY - x) / (AFT_BODY - stern_x(y))) ** power
        if y > LOAD_WL:
            lines = side * fore * after
            return max(lines, min(counter_half(x, y, lines), HALF))
    return side * fore * after

# Her forecastle and poop decks stepped to her sheer: C deck's sheer over amidships
# off Plate III (SB-III), 2.2 m at x 110 and 0.6 m at x −110, on B deck's height. The
# forecastle's step over the wall C deck's plan draws across her under it, between the
# crew's messes and the berths and windlass room forward of them (c.py px 9848; est.:
# the plates draw her sheer, no step), so each room under her forecastle stands under
# one deck and in one of its two cells (forecastle, forecastle_head).
FCSL_STEP = 109.0625
FCSL = (q(B_DECK + 1.56), q(B_DECK + 2.16))  # SB-III: C's sheer at x 91–108 and 108–128
POOP = q(B_DECK + 0.56)                    # SB-III: C's sheer at x −107…−130

def top_at(x):
    """Her shell's top at x: her forecastle, her well decks, her bridge deck, her poop."""
    if x >= FCSL_STEP:
        return FCSL[1]
    if x >= FCSL_FROM:
        return FCSL[0]
    if B_RUN[0] <= x <= B_RUN[1]:
        return B_DECK
    if x > POOP_TO:
        return 0.0
    return POOP

def fit(x0, x1, h, margin):
    """The half breadth a deck at height h may take from x0 to x1: the least of her
    hull's there, less margin, to the nearest 5 cm."""
    least = min(breadth(x, h) for x in (x0 + 0.01, (x0 + x1) * 0.5, x1 - 0.01))
    return math.floor((least - margin) * 20) / 20

def deck_pieces(x0, x1, z0, z1, holes):
    """A deck's rectangles from x0 to x1 and z0 to z1 round its holes, as (x0, x1, z0, z1)."""
    cuts = sorted({x0, x1} | {v for hx0, hx1, _a, _b in holes for v in (hx0, hx1) if x0 < v < x1})
    pieces = []
    for a, b in zip(cuts, cuts[1:]):
        gaps = sorted((hz0, hz1) for hx0, hx1, hz0, hz1 in holes if hx0 < b and hx1 > a and hz1 > z0 and hz0 < z1)
        spans, at = [], z0
        for hz0, hz1 in gaps:
            if hz0 > at:
                spans.append((at, hz0))
            at = max(at, hz1)
        if at < z1:
            spans.append((at, z1))
        if pieces and pieces[-1][1] == a and pieces[-1][2] == spans:
            pieces[-1][1] = b
        else:
            pieces.append([a, b, spans])
    return [(a, b, s0, s1) for a, b, spans in pieces for s0, s1 in spans]

def deck(pid, name, x0, x1, z0, z1, h, holes):
    """A deck from x0 to x1 and z0 to z1 at h, as rectangles round its holes."""
    made = []
    for a, b, s0, s1 in deck_pieces(x0, x1, z0, z1, holes):
        made.append(platform("%s_%d" % (pid, len(made)), name, a, b, s0, s1, h))
    return made

def recut(made, pid, name, x0, x1, z0, z1, h, holes):
    """A deck laid by deck() cut again round more holes: its first pieces laid over the
    platforms it had, the rest after every other, so no other platform moves."""
    pieces = deck_pieces(x0, x1, z0, z1, holes)
    assert len(pieces) >= len(made), pid
    for k, (a, b, s0, s1) in enumerate(pieces[:len(made)]):
        relay(made[k], name, a, b, s0, s1, h)
    return made + [platform("%s_%d" % (pid, k), name, a, b, s0, s1, h)
                                 for k, (a, b, s0, s1) in enumerate(pieces) if k >= len(made)]

def split(made, pid, name, h, holes):
    """A deck laid by deck() cut round more holes piece by piece: each piece one falls in
    laid again as the largest of its parts, the rest after every other, and a railing on it
    moved to the part whose edge it stands on — so no other piece moves, nor any railing."""
    out = list(made)
    for index in made:
        x0, x1, z0, z1, _h = plat_geo[index]
        cut = [o for o in holes if o[0] < x1 and o[1] > x0 and o[2] < z1 and o[3] > z0]
        if not cut:
            continue
        parts = sorted(deck_pieces(x0, x1, z0, z1, cut), key=lambda r: -(r[1] - r[0]) * (r[3] - r[2]))
        relay(index, name, *parts[0], h)
        new = []
        for part in parts[1:]:
            new.append(platform("%s_%d" % (pid, len(out)), name, *part, h))
            out.append(new[-1])
        for k, (plat, a, b) in enumerate(rail_geo):
            if plat == index and edge_platform([index], a, b) is None:
                home = edge_platform(new, a, b)
                assert home is not None, ("a railing left on no deck's edge", pid, a, b)
                rehome(k, home)
    return out

STAIR = 1.4   # a stair's width (est.)

def stair(sid, x_low, x_high, z0, z1, low, high, deck_holes):
    """A stair along x from low at x_low to high at x_high, z0 to z1 wide; the hole it
    leaves in the deck above is added to deck_holes, its railings laid with the deck."""
    lo, hi = min(x_low, x_high), max(x_low, x_high)
    rising = x_high > x_low
    ramp(sid, lo, hi, z0, z1, 0, low if rising else high, high if rising else low)
    deck_holes.append((lo, hi, z0, z1))
    stairs.append((sid, lo, hi, z0, z1, high, x_low))

stairs = []  # (id, x0, x1, z0, z1, upper height, low end's x)

stairs_z = []  # (id, x0, x1, z0, z1, upper height, low end's z)

def stair_z(sid, z_low, z_high, x0, x1, low, high, deck_holes):
    """A stair along z from low at z_low to high at z_high, x0 to x1 wide; the hole it
    leaves in the deck above is added to deck_holes."""
    lo, hi = min(z_low, z_high), max(z_low, z_high)
    rising = z_high > z_low
    ramp(sid, x0, x1, lo, hi, 1, low if rising else high, high if rising else low)
    deck_holes.append((x0, x1, lo, hi))
    stairs_z.append((sid, x0, x1, lo, hi, high, z_low))

def hole_rails_z(plats, sid):
    """Railings round a stair along z's hole on the deck above: its two sides and its low end."""
    for name, x0, x1, lo, hi, _high, z_low in [s for s in stairs_z if s[0] == sid]:
        closed = lo if z_low == lo else hi
        for tag, a, b in [("a", (x0, lo), (x0, hi)), ("f", (x1, lo), (x1, hi)), ("e", (x0, closed), (x1, closed))]:
            on = edge_platform(plats, a, b)
            if on is not None:
                railing("%s_%s" % (name, tag), on, a, b)

def hole_rails(plats, sid):
    """Railings round a stair's hole on the deck above: its two sides and its low end."""
    for name, lo, hi, z0, z1, high, x_low in [s for s in stairs if s[0] == sid]:
        open_end = hi if x_low == lo else lo
        closed = lo if open_end == hi else hi
        for tag, a, b in [("p", (lo, z0), (hi, z0)), ("s", (lo, z1), (hi, z1)), ("e", (closed, z0), (closed, z1))]:
            on = edge_platform(plats, a, b)
            if on is not None:
                railing("%s_%s" % (name, tag), on, a, b)

def edge_platform(plats, a, b):
    for index in plats:
        x0, x1, z0, z1, _h = plat_geo[index]
        if a[0] == b[0] and (a[0] == x0 or a[0] == x1) and z0 <= min(a[1], b[1]) and max(a[1], b[1]) <= z1:
            return index
        if a[1] == b[1] and (a[1] == z0 or a[1] == z1) and x0 <= min(a[0], b[0]) and max(a[0], b[0]) <= x1:
            return index
    return None

# --- The layout (Q11: interiors from the start, in SH3b's format). The boat deck and A
# deck as Plate III draws them, room by room (BOAT_PLAN, A_PLAN), and B deck as the
# Titanic's 1912 plan does (B_PLAN); below them Plate IV's decks C–E give the rooms'
# order along her (SB-IV), their sizes est. (#360 traces them in turn). Rooms run to the
# middles of their walls.
GS = (20.8, 32.9)  # the forward grand staircase below B deck, between funnels 1 and 2 (est.)
HOUSE_TOP = 2.625  # a deckhouse's height on the boat deck (est.)
# Each funnel stands on the roof of the house its casing rises through, as the elevation
# draws it: a funnel come down leaves her casing standing, and nothing over its foot.
FUNNEL_FOOT = BOAT + HOUSE_TOP
# Holes each deck leaves for the stairs down from it.
holes = {"boat": [], "a": [], "b": [], "c": [], "d": [], "e": [], "f": [], "well": [], "aft_well": []}

# The traced decks' stairs, each from the deck it leaves to the deck or the raised roof it
# rises to, the hole it leaves in a deck there. Where the plate's flight is steeper than a
# body climbs (STEEPEST), its deck file runs it on and says so.
PLAN_DECKS = {"boat": BOAT, "a": A_DECK, "b": B_DECK, "c": 0.0, "d": D_DECK, "e": E_DECK}
D_OUTLINE = plates.load("d")

def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")

def foot(flight):
    """A traced flight's low end's middle, (x, z)."""
    _name, x0, x1, z0, z1, rises, _lower, _upper = flight
    return {"fore": (x0, (z0 + z1) * 0.5), "aft": (x1, (z0 + z1) * 0.5),
            "starboard": ((x0 + x1) * 0.5, z0), "port": ((x0 + x1) * 0.5, z1)}[rises]

# D deck's flights down to E deck in No. 2 hold — the firemen's spiral staircases down to
# their tunnel, the open space's forward starboard ladder, the bay's ladder — are not laid
# until E deck is (#371): her estimated squash court fills that hold from G deck up to D,
# where the plates put it in No. 3 hold (#360), and has no E deck for their feet.
def unlaid(plan, flight):
    x, _z = foot(flight)
    return plan is D_OUTLINE and flight[6] == "e" and BX["C"] < x < BX["B"]

# A traced flight's sides held off the walls they run along on the traced decks it joins:
# the plates draw a flight to its room's edge, a wall's middle, and a stair wants no wall
# in a body's way on it or a body's width past its ends (the layout lint). Each side moves
# in, on the decks' grain, past every wall whose box (its ends' overlap past its corners
# too) reaches no further into the flight than SIDE_STRIP — one further in stands across
# it, and is cut under it (under_flights) or is the flight's to clear.
SIDE_STRIP = 0.25
TRACED = {"b": B_OUTLINE, "c": C_OUTLINE, "d": D_OUTLINE}

def clear_sides(flight):
    name, x0, x1, z0, z1, rises, lower, upper = flight
    along_x = rises in ("fore", "aft")
    lo, hi = (z0, z1) if along_x else (x0, x1)
    a, b = (x0, x1) if along_x else (z0, z1)
    lead = 2 * rule("body_radius")
    for deck_name in (lower, upper):
        plan = TRACED.get(deck_name)
        boxes = []
        for axis, at, w0, w1, kind, _doors in plan.walls if plan else []:
            half = T if kind == "steel" else 0.03
            boxes.append((at - half, at + half, w0 - half, w1 + half) if axis == 0
                         else (w0 - half, w1 + half, at - half, at + half))
        # And its solids, each a box or, standing in a room, its sides (plan_layer).
        boxes += [(sx0 - 0.03, sx1 + 0.03, sz0 - 0.03, sz1 + 0.03) for _w, sx0, sx1, sz0, sz1, _t in
                  (plan.solids if plan else [])]
        for wx0, wx1, wz0, wz1 in boxes:
            s0, s1, c0, c1 = (wx0, wx1, wz0, wz1) if along_x else (wz0, wz1, wx0, wx1)
            if s1 <= a - lead + 1e-3 or s0 >= b + lead - 1e-3 or c1 <= lo + 1e-3 or c0 >= hi - 1e-3:
                continue
            if c1 - lo <= SIDE_STRIP:
                lo = max(lo, math.ceil((c1 + 0.002) / plates.GRAIN) * plates.GRAIN)
            elif hi - c0 <= SIDE_STRIP:
                hi = min(hi, math.floor((c0 - 0.002) / plates.GRAIN) * plates.GRAIN)
    return (name, x0, x1, lo, hi, rises, lower, upper) if along_x else (name, lo, hi, z0, z1, rises, lower, upper)

for plan in (BOAT_PLAN, A_PLAN, B_OUTLINE, C_OUTLINE, D_OUTLINE):
    floors = dict(PLAN_DECKS)
    floors.update({name: PLAN_DECKS[plan.name] + h for name, _x0, _x1, _z0, _z1, h in plan.raised})
    for k, flight in enumerate(plan.stairs):
        if unlaid(plan, flight):
            continue
        if plan.name in TRACED:
            flight = clear_sides(flight)
        name, x0, x1, z0, z1, rises, lower, upper = flight
        sid = "%s_%s_%d" % (plan.name, slug(name), k)
        into = holes[upper] if upper in holes else []
        if rises in ("fore", "aft"):
            ends = (x0, x1) if rises == "fore" else (x1, x0)
            stair(sid, ends[0], ends[1], z0, z1, floors[lower], floors[upper], into)
        else:
            ends = (z0, z1) if rises == "starboard" else (z1, z0)
            stair_z(sid, ends[0], ends[1], x0, x1, floors[lower], floors[upper], into)

# Her F, E and G decks in No. 3 hold, one over the other: the post office on G deck
# (BOT: the mail room "on the Orlop deck", the sorting room over it), third-class
# berths on F, crew quarters on E (SB-IV) — each with two stairs up, E deck's the third-
# class ladders up into the open space on D deck (D_PLAN's), and C deck's ladderways on
# up from it into the forecastle (C_PLAN's).
HOLD3 = (BX["D"], BX["C"])
H3_LANDING = 84.6  # each room's forward wall, a landing before bulkhead C beyond it
H3_FLIGHTS = [  # (id, deck above, low, high, x from, x to, lane's z)
    ("g_f", "f", G_DECK, F_DECK, 79.0, 82.4, 5.0),
    ("f_e", "e", F_DECK, E_DECK, 73.0, 76.4, 6.6),
]
for sid, above, low, high, xa, xb, z in H3_FLIGHTS:
    for side, sign in [("p", -1), ("s", 1)]:
        lane = sorted((sign * z, sign * (z + STAIR)))
        stair("%s_%s" % (sid, side), xa, xb, lane[0], lane[1], low, high, holes[above])
# Scotland Road, the crew's working passage down her port side on E deck from boiler
# room 5's forward bulkhead to the engine room's (BOT: "the working passage"; SB-IV); est.
# 3 m wide, 1 m in from her shell. The third-class dining saloons on F deck under it, two
# rooms either side of bulkhead H ("the dining saloons, which occupy the space of two
# watertight compartments on the middle deck amidships ... 100 ft", SB-1914, of
# Britannic's alike), a stair up into the road from each; the road up to D deck by the
# grand staircase's foot beside it (D_PLAN), by the landings off it at the feet of D deck's
# flights (E_LANDINGS, below), and by a stair of its own up into the first-class dining
# saloon's forward port bay (est.), where D deck's plan leaves a run for it.
SR = (BX["K"], BX["E"])
SR_Z = (-13.0, -10.0)
SALOON_Z = 13.0
stair("f_sr_fwd", 11.8, 15.2, -12.6, -12.6 + STAIR, F_DECK, E_DECK, holes["e"])
stair("f_sr_aft", -8.0, -4.6, -12.6, -12.6 + STAIR, F_DECK, E_DECK, holes["e"])
stair("sr_d", 8.0, 11.75, -12.6, -12.6 + STAIR, E_DECK, D_DECK, holes["d"])
# Down off her open decks, two of each, port and starboard: A deck's forward end onto the
# forward well (est.); the forecastle's and the poop's from their wells, where C deck's
# view draws their ladders against their fronts (Plate IV px 9130-9190 and 1630-1700),
# run on to stairs a body climbs. (A deck's after end comes down onto B deck's by its own
# ladders, A_PLAN's; B deck's ends onto her wells by theirs, B_PLAN's.)
SIDE_LANE = (10.2, 10.2 + STAIR)  # outboard of A deck's house
FCSL_LANES = [(-5.5625, -4.1625), (5.3125, 6.7125)]
POOP_LANES = [(-7.3125, -5.9125), (6.1875, 7.5875)]
for k, (side, sign) in enumerate([("p", -1), ("s", 1)]):
    lane = sorted((sign * SIDE_LANE[0], sign * SIDE_LANE[1]))
    stair("a_fwd_" + side, A_RUN[1] + 7.0, A_RUN[1], lane[0], lane[1], 0.0, A_DECK, [])
    stair("forecastle_" + side, FCSL_FROM - 5.8, FCSL_FROM, *FCSL_LANES[k], 0.0, FCSL[0], [])
    stair("poop_" + side, POOP_TO + 5.5, POOP_TO, *POOP_LANES[k], 0.0, POOP, [])

def rail_line(rid, plats, axis, at, a, b, gaps=()):
    """Railings along the line where x (axis 0) or z (axis 2) is at, from a to b along
    the other axis, on whichever of plats has that edge, round gaps [(from, to)]."""
    spans, start = [], a
    for g0, g1 in sorted(gaps):
        if g0 > start:
            spans.append((start, g0))
        start = max(start, g1)
    if start < b:
        spans.append((start, b))
    k = 0
    for s0, s1 in spans:
        for index in plats:
            x0, x1, z0, z1, _h = plat_geo[index]
            lo, hi, edge = (z0, z1, (x0, x1)) if axis == 0 else (x0, x1, (z0, z1))
            if not (abs(edge[0] - at) < 1e-6 or abs(edge[1] - at) < 1e-6):
                continue
            p0, p1 = max(s0, lo), min(s1, hi)
            if p1 - p0 < 0.05:
                continue
            ends = ((at, p0), (at, p1)) if axis == 0 else ((p0, at), (p1, at))
            railing("%s_%d" % (rid, k), index, ends[0], ends[1])
            k += 1

def lanes_of(prefix):
    """The z gaps the stairs called prefix_p and prefix_s leave in a railing."""
    return [(s[3], s[4]) for s in stairs if s[0].startswith(prefix)]

# --- Platforms. The forward well deck first: the open deck at C, her origin's height,
# the lints walk from (D6).
WELL = (B_RUN[1], FCSL_FROM)
CW = fit(WELL[0], WELL[1], 0.0, 0.2)
well = deck("fwd_well", "forward well deck", WELL[0], WELL[1], -CW, CW, 0.0, holes["well"])
AFT_WELL = (POOP_TO, B_RUN[0])
AW = fit(AFT_WELL[0], AFT_WELL[1], 0.0, 0.2)
aft_well = deck("aft_well", "after well deck", AFT_WELL[0], AFT_WELL[1], -AW, AW, 0.0, [])
# The boat deck and A deck in their traced pieces (BOAT_PLAN, A_PLAN), each as wide as her
# hull lets it be where the plate gives it her whole breadth.
BW = fit(BOAT_RUN[0], BOAT_RUN[1], BOAT, 0.05)
AWD = fit(A_RUN[0], A_RUN[1], A_DECK, 0.05)

# Where the plate gives a deck her whole breadth it is laid in strips no longer than
# DECK_STRIP, each as wide as her hull is over it, so her deck's edge stays her side's
# all along — as the forecastle's and the poop's are (tapered). Under each row of her
# boats (STOWED_BOAT, at DAVITS, ROW_GAP or less apart) the strips are one breadth, the
# row's narrowest, from ROW_MARGIN past its end boats — on to the deck's end where less
# than ROW_GAP is left — so each boat stows to its deck's edge, and no step in that edge
# stands by a davit, whose foot over it would read as deck where there is none.
DECK_STRIP = 12.0
DAVITS = [60.5, 50.2, 40.0, 29.7, -38.7, -48.5, -57.6, -67.1]  # SB-III, forward to aft
STOWED_BOAT = (9.0, 3.15, 1.5)  # over its stems, in from the deck's edge, over the deck
ROW_GAP = 2.0
ROW_MARGIN = 1.5

def boat_rows():
    """Her rows of boats, (from, to) along her: each boat's stems, ROW_MARGIN past the ends."""
    rows = []
    for x in sorted(DAVITS):
        a, b = x - STOWED_BOAT[0] / 2, x + STOWED_BOAT[0] / 2
        if rows and a - rows[-1][1] <= ROW_GAP:
            rows[-1][1] = b
        else:
            rows.append([a, b])
    return [(round(a - ROW_MARGIN, 4), round(b + ROW_MARGIN, 4)) for a, b in rows]

def plan_pieces(plan, run, height, rows=()):
    """A traced deck's pieces (x0, x1, z0, z1): in strips her breadth there where the plate
    gives none — under each of rows, the row's narrowest — its first piece over run."""
    pieces = []
    for k, (x0, x1, z0, z1) in enumerate(plan.decks):
        if k == 0:
            x0, x1 = run
        if z0 is not None:
            pieces.append((x0, x1, z0, z1))
            continue
        held = [(x0 if r0 - x0 < ROW_GAP else r0, x1 if x1 - r1 < ROW_GAP else r1)
                for r0, r1 in rows if r0 < x1 and r1 > x0]
        ends = sorted({x0, x1} | {v for row in held for v in row})
        for lo, hi in zip(ends, ends[1:]):
            row = next(((r0, r1) for r0, r1 in held if r0 <= lo + 1e-6 and hi <= r1 + 1e-6), None)
            count = max(1, math.ceil((hi - lo) / DECK_STRIP))
            for i in range(count):
                a, b = round(lerp(lo, hi, i / count), 4), round(lerp(lo, hi, (i + 1) / count), 4)
                half = fit(*(row or (a, b)), height, 0.05)
                pieces.append((a, b, -half, half))
    return pieces

BOAT_PIECES = plan_pieces(BOAT_PLAN, BOAT_RUN, BOAT, boat_rows())
# The boat deck's raised roofs walked on, each a deck of its own over the block it stands on
# (plan_layer), cut round what stands on it.
raised_roofs = []
for k, (name, x0, x1, z0, z1, h) in enumerate(BOAT_PLAN.raised):
    on_it = [(s[1], s[2], s[3], s[4]) for s in BOAT_PLAN.solids
             if (s[5] is None or s[5] > h) and s[1] < x1 and s[2] > x0 and s[3] < z1 and s[4] > z0]
    raised_roofs += deck("raised_roof_%d" % k, name, x0, x1, z0, z1, BOAT + h, on_it)
A_PIECES = plan_pieces(A_PLAN, A_RUN, A_DECK)
boat = [i for k, (x0, x1, z0, z1) in enumerate(BOAT_PIECES)
        for i in deck("boat_%d" % k, "boat deck", x0, x1, z0, z1, BOAT, holes["boat"])]
a_deck = [i for k, (x0, x1, z0, z1) in enumerate(A_PIECES)
          for i in deck("a_%d" % k, "A deck", x0, x1, z0, z1, A_DECK, holes["a"])]
# B deck in its traced pieces, in strips as wide as her hull over each; its rooms held to
# the strips they stand on, each outer wall's outer face on its strip's edge (B_PLAN).
B_PIECES = plan_pieces(B_OUTLINE, B_RUN, B_DECK)
b_deck = [i for k, (x0, x1, z0, z1) in enumerate(B_PIECES)
          for i in deck("b_%d" % k, "B deck", x0, x1, z0, z1, B_DECK, holes["b"])]

def b_side(x0, x1):
    return min(min(-z0, z1) for p0, p1, z0, z1 in B_PIECES if p0 < x1 and p1 > x0) - T

B_PLAN = plates.load("b", side=b_side)
# C deck and D deck as Plate IV draws them (c.py, d.py; #368, #369), in strips as wide as
# her hull is over each — her counter aft, her bow forward — shorter where she narrows, her
# side narrowing STRIP_STEP at most along a strip: each room's outer wall then stands on
# its strip's edge, as B deck's do. C deck under her poop, her bridge deck and her
# forecastle, from her stern, where the plate starts it and her poop's starts (C_TIP), to
# the foremost room's forward wall, her wells between them (well, aft_well); D deck from
# her stern's store to her stem's. Aft of C deck's aftmost room, the steering gear room,
# her counter's tip is deck no room stands on, shut in behind that room's after wall
# (Cell_poop holds it): stopped there, C deck left D deck's stern store open up to her
# poop beside its after step, and its end over that store read as a break in her decks.
STRIP_STEP = 0.3

def hull_strips(x0, x1, height, margin=0.05):
    """Strips (a, b, -half, half) from x0 to x1 at height, each at most DECK_STRIP long and
    as wide as her hull all along it, less margin, her side narrowing at most STRIP_STEP
    along it; their ends on the traced decks' grain."""
    out, a = [], x0
    while a < x1 - 1e-9:
        b = min(a + DECK_STRIP, x1)
        while b - a > 0.25 and abs(breadth(a + 0.01, height) - breadth(b - 0.01, height)) > STRIP_STEP:
            b = max(plates.kept(a + (b - a) * 0.5), a + 0.25)
        half = fit(a, b, height, margin)
        out.append((a, b, -half, half))
        a = b
    return out

def held_to(pieces):
    """The side the rooms over pieces (x0, x1, z0, z1) are held to (deck.py): the half
    breadth of the narrowest piece under them, less a wall's half."""
    def side(x0, x1):
        over = [min(-z0, z1) for p0, p1, z0, z1 in pieces if p0 < x1 and p1 > x0]
        return (min(over) if over else HALF) - T
    return side

C_ENDS = (min(r[1] for r in C_OUTLINE.rooms) - T, max(r[2] for r in C_OUTLINE.rooms) + T)
C_TIP = X_AFT + 0.25  # C deck's after end, her poop's (POOP_STRIPS)
C_PIECES = (hull_strips(C_TIP, C_ENDS[0], 0.0) + hull_strips(C_ENDS[0], POOP_TO, 0.0)
            + hull_strips(B_RUN[0], B_RUN[1], 0.0) + hull_strips(FCSL_FROM, C_ENDS[1], 0.0))
c_deck = [i for k, (x0, x1, z0, z1) in enumerate(C_PIECES)
          for i in deck("c_%d" % k, "C deck", x0, x1, z0, z1, 0.0, holes["c"])]
# Under B deck's tapered after end, over her after well, C deck's after second-class
# entrance's walls stand where the plate draws them, as B deck's after end's steps are est.
B_TAIL = [p for p in B_OUTLINE.decks if p[2] is not None]
C_PLAN = plates.load("c", side=held_to(C_PIECES), ends=(POOP_TO, B_RUN[0], B_RUN[1], FCSL_FROM))
D_ENDS = (min(r[1] for r in D_OUTLINE.rooms) - T, max(r[2] for r in D_OUTLINE.rooms) + T)
D_PIECES = hull_strips(*D_ENDS, D_DECK)
d_deck = [i for k, (x0, x1, z0, z1) in enumerate(D_PIECES)
          for i in deck("d_%d" % k, "D deck", x0, x1, z0, z1, D_DECK, holes["d"])]
# D deck's cells part where a bulkhead's measured top stands over her flat D deck — P,
# O, N and M aft, B and A forward: her sheer lifts their tops over it (BULKHEADS; her
# sisters' raised ones part theirs too, their rooms hers) — and at her bridge deck's
# front (d_deck, d_deck_forward). The plate draws walls over P, O and M within 0.25 m
# and others over a line within D_REACH: each held to its line. A room the plate draws
# over a line is split along it (named_pieces). Each line on the 1/128 m grain, within
# 4 mm of its cells' faces: a room's far side is its corner plus its size in single
# precision, and off the grain it stood a hair off a solid's face on the same line,
# a gap the layout lint read as a door.
D_CUTS = sorted({round(x * 128) / 128 for letter, x, _deck, feet in BULKHEADS
                 if letter != "MN" and LOAD_WL + feet * FT > D_DECK + 1e-6} | {B_RUN[1]})
D_REACH = 0.4
# A room the plate draws over a line is split along it, each part at least a body's lead
# (two of its radii) and a margin deep, or a body stepping through the line would stand in
# neither (WalkGraph's doors): its end pushed out to D_LEAD from the line.
D_LEAD = 0.85
D_PLAN = plates.load("d", side=held_to(D_PIECES), ends=D_CUTS, reach=D_REACH, lead=D_LEAD)
e_road = deck("e_road", "E deck", SR[0] + T, SR[1] - T, SR_Z[0], SR_Z[1], E_DECK, holes["e"])
# E deck's landing at the grand staircase's foot, on forward under D deck's flight down to
# it (D_PLAN) to its head's end.
GS_E = (GS[0], plates.kept(next(s[2] for s in D_OUTLINE.stairs if s[0] == "grand staircase") + 0.4))
e_landing = deck("e_landing", "E deck", GS_E[0], GS_E[1], SR_Z[1], 6.0, E_DECK, holes["e"])
f_saloons = deck("f_saloons", "F deck", BX["J"], BX["G"], -SALOON_Z, SALOON_Z, F_DECK, [])
H3W = {h: fit(HOLD3[0], HOLD3[1], h, 0.3) for h in (E_DECK, F_DECK, G_DECK)}
h3_floor = (HOLD3[0] + 0.3, HOLD3[1] - 0.3)
e_crew = deck("e_crew", "E deck", h3_floor[0], h3_floor[1], -H3W[E_DECK], H3W[E_DECK], E_DECK,
              [h for h in holes["e"] if h[0] > HOLD3[0]])
f_berths = deck("f_berths", "F deck", h3_floor[0], h3_floor[1], -H3W[F_DECK], H3W[F_DECK], F_DECK,
                [h for h in holes["f"] if h[0] > HOLD3[0]])
g_post = deck("g_post", "G deck", h3_floor[0], h3_floor[1], -H3W[G_DECK], H3W[G_DECK], G_DECK, [])
def tapered(pid, name, x0, x1, h, strip, margin):
    """A deck from x0 to x1 at h in strips about strip long, each as wide as her hull
    lets it be: [(platform, x0, x1, half width)]."""
    count = max(1, round(abs(x1 - x0) / strip))
    made = []
    for k in range(count):
        a, b = lerp(x0, x1, k / count), lerp(x0, x1, (k + 1) / count)
        a, b = min(a, b), max(a, b)
        w = fit(a, b, h, margin)
        made.append((platform("%s_%d" % (pid, k), name, round(a, 4), round(b, 4), -w, w, h), round(a, 4), round(b, 4), w))
    return made

def rail_taper(rid, strips, open_ends=()):
    """Railings round a tapered deck: both sides of every strip, the steps where it
    narrows, and its two ends but for open_ends' (end x, [gaps])."""
    ordered = sorted(strips, key=lambda s: s[1])
    for k, (index, a, b, w) in enumerate(ordered):
        railing("%s_p%d" % (rid, k), index, (a, -w), (b, -w))
        railing("%s_s%d" % (rid, k), index, (a, w), (b, w))
        if k + 1 < len(ordered):
            nxt = ordered[k + 1]
            if nxt[3] < w:
                railing("%s_step_p%d" % (rid, k), index, (b, -w), (b, -nxt[3]))
                railing("%s_step_s%d" % (rid, k), index, (b, nxt[3]), (b, w))
            elif nxt[3] > w:
                railing("%s_step_p%d" % (rid, k), nxt[0], (b, -nxt[3]), (b, -w))
                railing("%s_step_s%d" % (rid, k), nxt[0], (b, w), (b, nxt[3]))
    for index, x, w in [(ordered[0][0], ordered[0][1], ordered[0][3]), (ordered[-1][0], ordered[-1][2], ordered[-1][3])]:
        # A strip's ends are rounded (tapered), so an open end is matched to the nearest mm.
        gaps = next((g for end, g in open_ends if abs(end - x) < 1e-3), ())
        rail_line("%s_end_%d" % (rid, int(abs(x))), [index], 0, x, -w, w, gaps)

FC1 = tapered("fcsl", "forecastle", FCSL_FROM, FCSL_STEP, FCSL[0], 4.0, 0.05)
FC_RAMP = (FCSL_STEP, FCSL_STEP + 3.0)
FC2 = tapered("fcsl_head", "forecastle", FC_RAMP[1], 128.0, FCSL[1], 3.0, 0.05)
fc1 = [s[0] for s in FC1]
fc2 = [s[0] for s in FC2]
FC1W = FC1[0][3]
FCRW = min(FC1[-1][3], FC2[0][3])
ramp("forecastle_step", FC_RAMP[0], FC_RAMP[1], -FCRW, FCRW, 0, FCSL[0], FCSL[1])
# The poop deck from over C deck's rooms under it (C_PLAN) to her counter's end, in strips
# as C deck's (hull_strips).
POOP_STRIPS = [(platform("poop_%d" % k, "poop deck", a, b, z0, z1, POOP), a, b, z1)
               for k, (a, b, z0, z1) in enumerate(hull_strips(X_AFT + 0.25, POOP_TO, POOP))]
poop = [s[0] for s in POOP_STRIPS]

# --- Railings: the open decks' edges, round their stairs' feet and heads; three sides of
# every hole a stair leaves in a deck.
def outline_rails(rid, pieces, plats, gaps=()):
    """Railings round the outside of a deck laid in pieces (x0, x1, z0, z1) as plats:
    every stretch of a piece's edge that no other piece carries on past, but for gaps
    [(axis, at, from, to)] — a stair's head, a screen."""
    for k, (x0, x1, z0, z1) in enumerate(pieces):
        for tag, axis, at, a, b, beyond in [("aft", 0, x0, z0, z1, -1), ("fwd", 0, x1, z0, z1, 1),
                                            ("p", 2, z0, x0, x1, -1), ("s", 2, z1, x0, x1, 1)]:
            cut = [(max(g[2], a), min(g[3], b)) for g in gaps
                   if g[0] == axis and abs(g[1] - at) < 1e-6 and g[2] < b and g[3] > a]
            for j, (ox0, ox1, oz0, oz1) in enumerate(pieces):
                near = (ox1 if beyond < 0 else ox0) if axis == 0 else (oz1 if beyond < 0 else oz0)
                if j != k and abs(near - at) < 1e-6:
                    cut.append((oz0, oz1) if axis == 0 else (ox0, ox1))
            rail_line("%s_%d%s" % (rid, k, tag), plats, axis, at, a, b, cut)

# The boat deck's edges, its bridge's front clear of its screen; A deck's, the 1912 steel
# screen with large windows along its forward 192 ft for its sides (BOT: "protected
# against the weather by a steel screen, 192 ft. long, with large windows in it") up to
# the boat deck's underside — so no further forward than the boat deck's full breadth
# runs, where A deck's railing takes over —, a gap at the head of each stair that comes
# up onto an edge of it.
SCREEN_RUN = (A_PLAN.decks[0][1] - 192 * FT, min(A_RUN[1], BOAT_RUN[1]))
screen = [s for s in BOAT_PLAN.solids if s[0] == "the bridge's front screen"][0]
outline_rails("boat", BOAT_PIECES, boat, [(0, BOAT_PIECES[-1][1], screen[3], screen[4])])
heads = [(0, s[1] if s[5] == "aft" else s[2], s[3], s[4]) for s in A_PLAN.stairs if s[7] == "a" and s[5] in ("fore", "aft")]
outline_rails("a", A_PIECES, a_deck, heads + [(0, A_RUN[1], z0, z1) for z0, z1 in lanes_of("a_fwd_")]
              + [(2, sign * half, max(x0, SCREEN_RUN[0]), min(x1, SCREEN_RUN[1]))
                 for x0, x1, _z0, half in A_PIECES if x1 > SCREEN_RUN[0] for sign in (-1, 1)])
# B deck's: her open after end and her assembling area forward, but where her house stands
# to her side (B_HOUSE), a gap at the head of each ladder down to her wells, and none
# under A deck's ladders, whose flights come down past her front from A deck's. A deck's
# after ladders come down onto her where her side steps in, as both plates draw them:
# a gap at each one's foot.
b_heads = [(0, s[2] if s[5] == "fore" else s[1], s[3], s[4]) for s in B_OUTLINE.stairs if s[7] == "b" and s[5] in ("fore", "aft")]
a_feet = [(0, s[1] if s[5] == "fore" else s[2], s[3], s[4]) for s in A_PLAN.stairs if s[6] == "b" and s[5] in ("fore", "aft")]
outline_rails("b", B_PIECES, b_deck, b_heads + a_feet + [(0, B_RUN[1], z0, z1) for z0, z1 in lanes_of("a_fwd_")]
              + [(2, z, max(x0, B_HOUSE[0]), min(x1, B_HOUSE[1])) for x0, x1, z0, z1 in B_PIECES
                 if x0 < B_HOUSE[1] and x1 > B_HOUSE[0] for z in (z0, z1)])
rail_line("well_port", well, 2, -CW, WELL[0], WELL[1])
rail_line("well_starboard", well, 2, CW, WELL[0], WELL[1])
rail_line("aft_well_port", aft_well, 2, -AW, AFT_WELL[0], AFT_WELL[1])
rail_line("aft_well_starboard", aft_well, 2, AW, AFT_WELL[0], AFT_WELL[1])
rail_taper("fcsl", FC1, [(FCSL_FROM, lanes_of("forecastle_")), (FCSL_STEP, [(-FCRW, FCRW)])])
rail_taper("fcsl_head", FC2, [(FC_RAMP[1], [(-FCRW, FCRW)])])
rail_taper("poop", POOP_STRIPS, [(POOP_TO, lanes_of("poop_"))])
# C deck's: along her side under the decks over it where no room of hers stands by it — her
# second-class promenades aft (BOT: "sheltered by bulwarks"), the third-class alcoves under
# the poop's front — and never at its ends on her wells, which it runs on into, nor at its
# own ends, behind its end rooms' walls, nor round her counter's tip, shut in aft of them.
C_SIDE_ROOM = 2.2  # a room's wall this near her side leaves no deck a body walks by it

def c_covered(sign, x0, x1, half):
    """The stretches of C deck's side (sign) over x0..x1 its rooms stand by."""
    return [(max(x0, r[1] - T), min(x1, r[2] + T)) for r in C_PLAN.rooms + C_PLAN.solids
            if r[1] < x1 and r[2] > x0 and (r[4] if sign > 0 else -r[3]) >= half - C_SIDE_ROOM]

c_gaps = [(0, at, -HALF, HALF) for at in (POOP_TO, B_RUN[0], B_RUN[1], FCSL_FROM, C_TIP) + C_ENDS]
for x0, x1, z0, z1 in C_PIECES:
    tip = x1 <= C_ENDS[0] + 1e-6
    for sign, z in [(-1, z0), (1, z1)]:
        c_gaps += [(2, z, x0, x1)] if tip else [(2, z, a, b) for a, b in c_covered(sign, x0, x1, z1)]
        # The step to the next strip, where its rooms stand to her side either side of it.
        for edge in (x0, x1):
            if tip or c_covered(sign, edge - 0.05, edge + 0.05, z1):
                c_gaps.append((0, edge, -HALF, HALF))
# Where her shell stands over C deck's open edge (her poop's sides, B deck's) a body at the
# edge is at her side, not at a railing over the sea: the edge is lined, deck to deck (est.).
C_LINED = [(1, -111.025, -109.5), (-1, -109.0875, -106.625), (1, -109.0875, -106.625),
           (-1, -80.7125, -78.5625), (1, -80.7125, -78.5625)]
for k, (sign, x0, x1) in enumerate(C_LINED):
    z = next(p[3] if sign > 0 else -p[2] for p in C_PIECES if p[0] <= x0 < p[1])
    c_gaps.append((2, sign * z, x0, x1))
    box("c_lining_%d" % k, x0, x1, *sorted((sign * z, sign * (z - 0.1))), 0.0, top_at(x0))
outline_rails("c", C_PIECES, c_deck, c_gaps)
DECKS_AT = {BOAT: boat, A_DECK: a_deck, B_DECK: b_deck, 0.0: c_deck + well, D_DECK: d_deck,
            E_DECK: e_road + e_landing + e_crew, F_DECK: f_berths}
for name, _lo, _hi, _z0, _z1, high, _x_low in list(stairs):
    if high in DECKS_AT and not name.startswith(("boat_aft", "a_aft", "b_aft", "a_fwd")):
        hole_rails(DECKS_AT[high], name)

# --- Boarding ladders (SH5), one down each side of both well decks, where a body shoved
# over her rail comes down: a swimmer climbs back aboard there, ten metres up her side
# from the sea, which no edge is in reach of. Each hangs in the middle of its well from
# the piece of the deck whose side it is on, a body's breadth and more wide (est.).
LADDER = 1.0

def ladder(lid, plats, x, z):
    a, b = (round(x - LADDER / 2, 4), z), (round(x + LADDER / 2, 4), z)
    plat = edge_platform(plats, a, b)
    assert plat is not None, "no piece of the deck holds the ladder " + lid
    f = [("platform", str(plat))] if plat != 0 else []
    f += [("from", "Vector2(%s, %s)" % (num(a[0]), num(a[1]))), ("to", "Vector2(%s, %s)" % (num(b[0]), num(b[1])))]
    ladders.append(sub("Ladder_" + lid, "7_ladder", f))

for tag, plats, middle, side in [("aft_well", aft_well, sum(AFT_WELL) / 2, AW), ("well", well, sum(WELL) / 2, CW)]:
    ladder(tag + "_port", plats, middle, -side)
    ladder(tag + "_starboard", plats, middle, side)

# --- Walls and rooms.
# The boat deck and A deck as Plate III draws them (BOAT_PLAN, A_PLAN): each room to its
# walls' middles, its walls along its edges — steel, 0.2 m, where one faces her open deck,
# panelling PARTITION thick between two rooms, so the plates' passages keep their width
# for a body —, a door where the plate draws one, DOOR wide or as wide as its stretch of
# wall leaves room for (a stretch too short for a body's door is all doorway). What nobody
# enters — casings, shafts, lifts, closets narrower than a body — stands as a block up to
# the deck over it; a raised roof walked on, as a block under a deck of its own (laid with
# the decks), nothing under it a body could crawl into. The boat deck's
# houses are roofed over, each a slab on its walls' tops as the trawler's wheelhouse is
# (no deck of anyone's: nobody climbs there), her funnels rising through their casings.
PARTITION = 0.06
DOOR_LEAST = 1.0   # the layout lint's least door

NO_ROOM = []  # (deck, axis, at, along, room, wall from, wall to): a door its wall has no room for

def plan_layer(prefix, plan, floor, ceiling, breaks=(), parted_at=(), place=None, main=None):
    """A traced deck's rooms, walls, doors and solid blocks, from floor to ceiling: a
    height, or the height of the deck over ship x, ceiling(x), which changes only at
    breaks — a wall along her under two decks is laid in a piece under each. Given
    place, its rooms as her cells hold them: split along parted_at, named for where
    they stand (named_pieces)."""
    over = ceiling if callable(ceiling) else (lambda _x: ceiling)

    def under(lo, hi):
        """lo..hi along her cut where the deck over it changes — but within a wall's end
        past a corner, which takes the deck over the rest: [(from, to, its height)]."""
        cuts = [lo] + [v for v in sorted(breaks) if lo + 2 * T < v < hi - 2 * T] + [hi]
        return [(p, q, over((p + q) * 0.5)) for p, q in zip(cuts, cuts[1:])]

    def door_room(axis, at, a, b, along):
        """The stretch of the wall (axis, at) from a to b a door at along may take: up to the
        nearest wall meeting it either side, clear of that wall's thickness (none past a
        casing, whose face is its line), and up to a line her cells part along (parted_at),
        where a room the plate draws whole is two, a door in one of them."""
        low, high = a, b
        for w in plan.walls:
            if w[0] == axis or not (w[2] - 1e-6 <= at <= w[3] + 1e-6) or not (a - 1e-6 <= w[1] <= b + 1e-6):
                continue
            half = T if w[4] == "steel" else PARTITION / 2
            if w[1] <= along:
                low = max(low, w[1] + half)
            else:
                high = min(high, w[1] - half)
        for c in parted_at if axis != 0 else ():
            if a < c < b:
                if c <= along:
                    low = max(low, c)
                else:
                    high = min(high, c)
        return low + 0.01, high - 0.01

    rooms = plan.rooms if place is None else named_pieces(plan.rooms, parted_at, place, main)
    for k, (name, x0, x1, z0, z1) in enumerate(rooms):
        room("%s_%d_%s" % (prefix, k, slug(name)), name, x0, x1, z0, z1, floor)
    for k, (axis, at, a, b, kind, doors) in enumerate(plan.walls):
        half = T if kind == "steel" else PARTITION / 2
        cuts = []
        for along in sorted(doors):
            low, high = door_room(axis, at, a, b, along)
            if high - low < DOOR_LEAST:
                NO_ROOM.append((prefix, axis, at, along, round(high - low, 3), a, b))
                continue
            width = min(DOOR, high - low)
            mid = min(max(along, low + width / 2), high - width / 2)
            cuts.append((round(mid - width / 2, 4), round(mid + width / 2, 4)))
        edges = [a - half] + [v for c in cuts for v in c] + [b + half]
        bid = "%s_wall_%d" % (prefix, k)
        for i in range(0, len(edges), 2):
            lo, hi = edges[i], edges[i + 1]
            if hi - lo > 0.005:
                tag = "%s_%d" % (bid, i // 2) if cuts else bid
                if axis == 0:
                    box(tag, at - half, at + half, lo, hi, floor, over(at))
                else:
                    parts = under(lo, hi)
                    for j, (p, q, top) in enumerate(parts):
                        box(tag if len(parts) == 1 else "%s_u%d" % (tag, j), p, q, at - half, at + half, floor, top)
        for i, (c0, c1) in enumerate(cuts):
            top = over(at if axis == 0 else (c0 + c1) * 0.5)
            if floor + LINTEL < top and c1 - c0 < b - a:
                if axis == 0:
                    box("%s_lintel_%d" % (bid, i), at - half, at + half, c0, c1, floor + LINTEL, top)
                else:
                    box("%s_lintel_%d" % (bid, i), c0, c1, at - half, at + half, floor + LINTEL, top)
            doorways.append((axis, at, c0, c1, floor))
    for k, (what, x0, x1, z0, z1, top) in enumerate(plan.solids):
        sid, high = "%s_%d_%s" % (prefix, k, slug(what)), over((x0 + x1) * 0.5) if top is None else floor + top
        if top is not None or not any(r[1] < (x0 + x1) / 2 < r[2] and r[3] < (z0 + z1) / 2 < r[4] for r in plan.rooms):
            box(sid, x0, x1, z0, z1, floor, high)
            continue
        # A shaft or a closet standing in a room, up to the deck over it, as its four
        # sides: the art draws a box indoors only as the room's furniture or machinery.
        # Each side runs through the corners, as a wall does past its ends, so no sliver
        # opens between two sides where a room's edge runs along one (B deck's buffet).
        h = PARTITION / 2
        for side, sides in [("aft", (x0 - h, x0 + h, z0 - h, z1 + h)), ("fore", (x1 - h, x1 + h, z0 - h, z1 + h)),
                            ("port", (x0 - h, x1 + h, z0 - h, z0 + h)), ("starboard", (x0 - h, x1 + h, z1 - h, z1 + h))]:
            box("%s_%s" % (sid, side), *sides, floor, high)
    for k, (what, x0, x1, z0, z1, top) in enumerate(plan.raised):
        box("%s_raised_%d" % (prefix, k), x0, x1, z0, z1, floor, floor + top - 2 * T)

plan_layer("boat", BOAT_PLAN, BOAT, BOAT + HOUSE_TOP)
for name, x0, x1, z0, z1 in BOAT_PLAN.houses:
    box(name + "_roof", x0 - T, x1 + T, z0 - T, z1 + T, BOAT + HOUSE_TOP - 2 * T, BOAT + HOUSE_TOP)
plan_layer("a", A_PLAN, A_DECK, BOAT)
# A deck's forward 192 ft (SCREEN_RUN): the steel screen along either side of its
# promenade, from her deck's edge in along each strip of it, to the boat deck over it.
for k, (x0, x1, _z0, half) in enumerate([p for p in A_PIECES if p[1] > SCREEN_RUN[0] and p[3] > 0]):
    for tag, sign in [("p", -1), ("s", 1)]:
        box("a_screen_%d%s" % (k, tag), max(x0, SCREEN_RUN[0]), min(x1, SCREEN_RUN[1]),
            *sorted((sign * half, sign * (half - 2 * T))), A_DECK, BOAT)
for k, x in enumerate(FUNNELS):
    cylinder("funnel_%d" % (k + 1), x, 0.0, FUNNEL_RADIUS, FUNNEL_FOOT, FUNNEL_TOP)
cylinder("foremast", 96.0, 0.0, 0.6, FCSL[0], FCSL[0] + 40.0)       # est., SB-III
# The mainmast, up through A deck's after end and B deck's after second-class entrance,
# where A deck's plan draws its circle (Plate III px 2385). B deck's plan draws its own
# 1.1 m forward of it, calibrated on her after end (b_aft.py), and Plate III's elevation
# its foot at her superstructure's after face, 6 m aft: est. on A deck's.
cylinder("mainmast", plates.kept(A_PLAN.view.x(2385)), 0.0, 0.6, B_DECK, B_DECK + 40.0)

# B deck as the Titanic sailed (B_PLAN): her house under A deck from her restaurant's
# after wall forward, her rooms out to her side; and on her open after end her
# second-class houses, each roofed where A deck is not over it, its walls' tops, and no
# trunk standing up to A deck's height closes it with its own top.
plan_layer("b", B_PLAN, B_DECK, A_DECK)

def b_house_box(house):
    """B deck's house as its cell's box: out to its walls' outer faces, but where it meets
    another of her houses, or her house under A deck (B_HOUSE), on the line between."""
    _name, x0, x1, z0, z1 = house
    def shared(at):
        return abs(at - B_HOUSE[0]) < 1e-6 or any(
            other is not house and (abs(other[1] - at) < 1e-6 or abs(other[2] - at) < 1e-6)
            and other[3] < z1 and other[4] > z0 for other in B_PLAN.houses)
    return (x0 - (0.0 if shared(x0) else T), x1 + (0.0 if shared(x1) else T), z0 - T, z1 + T)

B_TRUNKS = [s[1:5] for s in B_PLAN.solids if s[5] is None and not any(
    r[1] < (s[1] + s[2]) / 2 < r[2] and r[3] < (s[3] + s[4]) / 2 < r[4] for r in B_PLAN.rooms)]
for name, *house in B_PLAN.houses:
    # Over its rooms, to its walls' middles: its walls stand up to A deck's top themselves.
    for k, (a, b, s0, s1) in enumerate(deck_pieces(*house, A_PIECES + B_TRUNKS)):
        box("%s_roof_%d" % (name, k), a, b, s0, s1, A_DECK - 2 * T, A_DECK)
# C deck as Plate IV draws it (C_PLAN, #368): under her poop, her bridge deck and her
# forecastle, each room up to the deck over it (c_over) — the poop's, B deck's, the
# forecastle's, under its step no higher than the step's foot —; on her wells only what
# stands on them at its own height, her hatches, winches and cranes. D deck as Plate IV
# draws it too (D_PLAN, #369), from her stern to her stem under C deck.
C_TAIL = min(p[0] for p in B_TAIL)

def c_over(x):
    """The height of the deck over C deck at ship x, where C deck has rooms."""
    if x <= POOP_TO + 1e-6:
        return POOP
    if C_TAIL - 1e-6 <= x <= B_RUN[1] + 1e-6:
        return B_DECK
    assert x >= FCSL_FROM - 1e-6, "no deck over C deck at x %.3f: a wall on her open wells" % x
    return FCSL[0] if x < FC_RAMP[1] else FCSL[1]

def named_pieces(rooms, cuts, place, main):
    """A traced deck's rooms as her cells hold them, as her structure's lint asks — each
    room in one cell, and each name in one (FloodCell.rooms names a cell's): each split
    along every line of cuts it runs over, where her cells part under a room the plate
    draws whole; and a name the plate gives rooms in more than one place kept in one —
    main, its deck's main place, where it stands there, else where most of its floor is
    — and told apart in every other by where it stands there, place(x)'s words it does
    not already say. A name a deck laid before has is told apart everywhere."""
    pieces = []
    for name, x0, x1, z0, z1 in rooms:
        lines = [x0] + [c for c in cuts if x0 + 1e-6 < c < x1 - 1e-6] + [x1]
        pieces += [(name, a, b, z0, z1) for a, b in zip(lines, lines[1:])]
    taken = {r[5] for r in room_geo}
    floor_area = {}
    for name, x0, x1, z0, z1 in pieces:
        where = place((x0 + x1) * 0.5)
        floor_area[(name, where)] = floor_area.get((name, where), 0.0) + (x1 - x0) * (z1 - z0)
    home = {}
    for (name, where), _area in sorted(floor_area.items(), key=lambda item: -item[1]):
        if name not in taken:
            home.setdefault(name, main if (name, main) in floor_area else where)
    out = []
    for name, x0, x1, z0, z1 in pieces:
        where = place((x0 + x1) * 0.5)
        if home.get(name) != where:
            said = name.split(", ")
            name = ", ".join([name] + [w for w in where if w not in said])
            # (Short enough for the place plate's two lines: FirstPersonHud.place_lines.)
            name = name.replace("D deck, aft", "D deck aft").replace("D deck, forward", "D deck forward")
        out.append((name, x0, x1, z0, z1))
    held = {}
    for name, x0, x1, _z0, _z1 in out:
        held.setdefault(name, set()).add(place((x0 + x1) * 0.5))
    twice = {name: sorted(w) for name, w in held.items() if len(w) > 1}
    assert not twice and not taken & set(held), ("a name in two places", twice, sorted(taken & set(held)))
    return out

def c_place(x):
    """Where on C deck ship x stands, as her cells part it: under her poop; in the house
    round her after entrance's after end on her after well; under her bridge deck, her
    main place; under her forecastle, or under its head forward of its step."""
    if x < POOP_TO:
        return ("poop",)
    if x < B_RUN[0]:
        return ("C deck", "after end")
    if x < FCSL_FROM:
        return ("C deck",)
    return ("forecastle",) if x < FCSL_STEP else ("forecastle head",)

def d_place(x):
    """Where on D deck ship x stands, between the lines her cells part along (D_CUTS):
    from bulkhead M to her bridge deck's front, her main place; aft of it, aft of the
    bulkhead forward of it; forward of it, forward of the bulkhead aft of it, or aft of
    bulkhead B under her forward well."""
    letter = {round(round(b[1] * 128) / 128, 4): b[0] for b in BULKHEADS}
    m = round(BX["M"] * 128) / 128
    if m <= x < B_RUN[1]:
        return ("D deck",)
    after = max([c for c in D_CUTS if c <= x], default=None)
    if x > m and round(after, 4) in letter:
        return ("D deck", "forward of %s" % letter[round(after, 4)])
    return ("D deck", "aft of %s" % letter[round(min(c for c in D_CUTS if c > x), 4)])

plan_layer("c", C_PLAN, 0.0, c_over, (POOP_TO, C_TAIL, B_RUN[1], FCSL_FROM, FC_RAMP[1]),
           parted_at=(POOP_TO, B_RUN[0], B_RUN[1], FCSL_FROM, FCSL_STEP), place=c_place, main=("C deck",))
plan_layer("d", D_PLAN, D_DECK, 0.0, parted_at=D_CUTS, place=d_place, main=("D deck",))
assert not NO_ROOM, "no room for a door: %s" % NO_ROOM

# E deck: Scotland Road and the grand staircase's foot beside it.
wall_z("road_out", SR_Z[0], SR[0], SR[1], E_DECK, D_DECK)
ROAD_DOORS = [door_at(26.9)]  # and the E landings' (below)
wall_x("road_aft", SR[0], SR_Z[0], SR_Z[1], E_DECK, D_DECK)
wall_x("road_fwd", SR[1], SR_Z[0], SR_Z[1], E_DECK, D_DECK)
# One room for each stretch of it between the bulkheads whose tops rise over its floor,
# as her cells are cut there (below): open into each other.
ROAD = [(SR[0], BX["J"], "boiler room 1"), (BX["J"], BX["G"], "boiler rooms 2 and 3"),
        (BX["G"], BX["F"], "boiler room 4"), (BX["F"], SR[1], "boiler room 5")]
for k, (x0, x1, by) in enumerate(ROAD):
    room("road_%d" % (k + 1), "Scotland Road, " + by, x0, x1, SR_Z[0], SR_Z[1], E_DECK)
wall_x("gs_e_aft", GS_E[0], SR_Z[1], 6.0, E_DECK, D_DECK)
wall_x("gs_e_fwd", GS_E[1], SR_Z[1], 6.0, E_DECK, D_DECK)
wall_z("gs_e_s", 6.0, GS_E[0], GS_E[1], E_DECK, D_DECK)
room("gs_e", "grand staircase, E deck", GS_E[0], GS_E[1], SR_Z[1], 6.0, E_DECK)
# Landings on E deck at the feet of D deck's flights down to it where her estimated E deck
# has none (est., until E deck is laid, #371): the stewards' staircase's over boiler room
# 1, from bulkhead K's wall on past its foot by a body's lead and a half (0.6 m past its
# side, the stewards' clear of boiler room 1's fiddley casing forward of it); the stair's
# down from the port first-class entrance over boiler room 4, from the grand staircase's
# landing's forward wall to bulkhead F, its foot aft of F (D_PLAN). Each a room walled up
# to D deck from Scotland Road, a door into it (its walls under the flight cut to its
# underside, under_flights).
def d_flight(name, x_from):
    return next(s for s in D_PLAN.stairs if s[0] == name and s[1] > x_from)

STEWARDS_E = d_flight("stewards' staircase", -60.0)
ENTRANCE_E = d_flight("stair", BX["F"] - 2.0)
E_LANDINGS = []
for rid, name, area in [
        ("e_stewards", "stewards' stair, E deck",
         (BX["K"], plates.kept(STEWARDS_E[2] + 0.6), SR_Z[1], plates.kept(STEWARDS_E[4] + 1.2))),
        ("e_entrance", "first-class stair, E deck", (GS_E[1], BX["F"], SR_Z[1], plates.kept(ENTRANCE_E[4] + 0.6)))]:
    E_LANDINGS.append(area)
    deck(rid, "E deck", *area, E_DECK, [])
    ax0, ax1, az0, az1 = area
    # (Its after wall bulkhead K's (aft_k, below), or the grand staircase's landing's.)
    wall_z(rid + "_s", az1, ax0, ax1, E_DECK, D_DECK)
    wall_x(rid + "_f", ax1, az0, az1, E_DECK, D_DECK)
    room(rid, name, *area, E_DECK)
wall_z("road_in", SR_Z[1], SR[0], SR[1], E_DECK, D_DECK,
       sorted(ROAD_DOORS + [door_at((a[0] + a[1]) * 0.5) for a in E_LANDINGS]))

# F deck: the third-class dining saloons either side of bulkhead H, a watertight door
# between them (BOT: "On both the F and E decks nearly all the bulkheads had watertight
# doors").
wall_x("saloons_aft", BX["J"], -SALOON_Z, SALOON_Z, F_DECK, E_DECK)
wall_x("saloons_middle", BX["H"], -SALOON_Z, SALOON_Z, F_DECK, E_DECK, [door_at(0.0)])
# Bulkhead G's door forward to the baths' corridor (wtd_f_g): the wall to starboard of
# it here, its port piece and lintel with the baths, so no blocker moves.
G_DOOR = door_at(-6.0)
box("saloons_fwd", BX["G"] - T, BX["G"] + T, G_DOOR[1], SALOON_Z + T, F_DECK, E_DECK)
for tag, z in [("p", -SALOON_Z), ("s", SALOON_Z)]:
    wall_z("saloons_" + tag, z, BX["J"], BX["G"], F_DECK, E_DECK)
room("saloon_3_aft", "third-class dining saloon, aft", BX["J"], BX["H"], -SALOON_Z, SALOON_Z, F_DECK)
room("saloon_3_fwd", "third-class dining saloon, forward", BX["H"], BX["G"], -SALOON_Z, SALOON_Z, F_DECK)

# No. 3 hold's decks: a room on each, its door forward onto the landing before bulkhead C.
# Each as wide as the narrowest of the three, G deck's: the water drawn round their cell's
# rooms stands inside her shell from G deck up (InnerWater).
for rid, name, h, top in [("post_office", "post office", G_DECK, F_DECK),
                          ("berths", "third-class berths", F_DECK, E_DECK),
                          ("crew", "crew quarters", E_DECK, D_DECK)]:
    w = H3W[G_DECK]
    room(rid, name, h3_floor[0], H3_LANDING, -w, w, h)
    wall_x(rid + "_aft", h3_floor[0], -w, w, h, top)
    wall_x(rid + "_fwd", H3_LANDING, -w, w, h, top, [door_at(0.0)])
    if rid == "berths":
        # F deck's landing wall has a door at z -6.0 onto the squash court's gallery,
        # through bulkhead C's (wtd_f_c): the wall to starboard of it here, its port
        # piece and lintel with the court, so no blocker moves.
        box(rid + "_landing", h3_floor[1] - T, h3_floor[1] + T, door_at(-6.0)[1], w + T, h, top)
    else:
        wall_x(rid + "_landing", h3_floor[1], -w, w, h, top)
    for tag, z in [("p", -w), ("s", w)]:
        wall_z("%s_%s" % (rid, tag), z, h3_floor[0], h3_floor[1], h, top)

# --- Furniture: the boxes standing on her rooms' floors, after every other blocker so
# none of theirs moves. Each is drawn inside its box (FurnitureDressing): tables 0.75 m
# tall, a jump up; benches 0.45, a step and a half; ranges 0.9; counters and the
# gymnasium's apparatus 1.0, which nobody perches on. Every one keeps clear a lane 1.5 m
# either side of a room's centre line from door to door, 0.8 m before a stair's end and
# 0.5 m beside it, 0.5 m off a wall's face, a body round the seat in the first-class
# dining saloon, and on B, C and F decks, where the ceiling is low over a body on a
# table, 1.0 m in plan from the pendant under the middle of each 12 m square of a room
# (RoomDressing.lights). Placings est., after SB-IV's deck plans. Her laid tables are no
# boxes: each is a round table with a chair at each quarter, every piece a prop of its
# own (LAID, after her lifebuoys) that slides, is pushed about and floats.
TABLE, BENCH, RANGE, COUNTER = 0.75, 0.45, 0.9, 1.0
LAID = []  # (tid, x, floor, z): the middle of a laid table
# The third-class dining saloons either side of bulkhead H: long tables, three in a row,
# three rows either side, short of the pendants over z ±8.67 and the stairs to port.
SALOON_3_ROWS = [(-7.5, -6.6), (-5.3, -4.4), (-3.1, -2.2), (2.2, 3.1), (4.4, 5.3), (6.6, 7.5)]
for rid, runs in [("saloon_3_aft", [(-14.75, -10.75), (-9.55, -5.55), (-4.35, -0.35)]),
                  ("saloon_3_fwd", [(3.19, 7.19), (8.39, 12.39), (13.59, 17.59)])]:
    for k, (x0, x1) in enumerate(runs):
        for j, (z0, z1) in enumerate(SALOON_3_ROWS):
            box("table_%s_%d" % (rid, k * 6 + j), x0, x1, z0, z1, F_DECK, F_DECK + TABLE)
# (The à la carte restaurant's are laid with B deck's other rooms' furniture, the dining
# saloons', the galley's, C and D decks' rooms' with theirs, below.)
# The post office's counter, either side of the way in.
for rid, x0, x1, floor, rows in [("post_office", 73.0, 73.8, G_DECK, [(-6.0, -1.5), (1.5, 6.0)])]:
    for j, (z0, z1) in enumerate(rows):
        box("counter_%s_%d" % (rid, j), x0, x1, z0, z1, floor, floor + COUNTER)
# The gymnasium's rowing machine and electric camel, against its after wall.
box("gym_rowing_machine", 18.0, 18.7, 2.0, 3.5, BOAT, BOAT + COUNTER)
box("gym_electric_camel", 18.0, 18.7, -3.5, -2.0, BOAT, BOAT + COUNTER)

# --- F deck over boiler rooms 4 and 5 (SB-IV), after every other platform, blocker and
# room so none of theirs moves: the Turkish bath and the swimming bath to starboard, a
# working corridor to port from the third-class saloons through bulkhead G's door and
# F's (wtd_f_g, wtd_f_f) to bulkhead E. Each boiler room's fiddley rises through the
# corridor in a casing 3 m square walled to E deck (est.), the deck cut round it. The
# swimming bath's pool is a box a metre high, est. 9.1 m by 4.3 m: no water of the
# sim's (SinkSchedule is the only), a rim nobody perches on.
BR5_Z = fit(BX["F"], BX["E"], F_DECK, 0.3)
FIDDLEY = 1.5  # half a fiddley casing's side (est.), round the fiddley opening's 3 m square
BATHS_Z = 1.5  # the baths' wall, along her centre line's starboard side (est.)
CASINGS = [(cx, cx - FIDDLEY, cx + FIDDLEY) for cx in ((BX["G"] + BUNKERS["br4"]) * 0.5,
                                                       (BX["F"] + BUNKERS["br5"]) * 0.5)]
casing_holes = [(x0, x1, -FIDDLEY, FIDDLEY) for _cx, x0, x1 in CASINGS]
f_br4 = deck("f_br4", "F deck", BX["G"], BX["F"], -SALOON_Z, SALOON_Z, F_DECK, casing_holes[:1])
f_br5 = deck("f_br5", "F deck", BX["F"], BX["E"], -BR5_Z, BR5_Z, F_DECK, casing_holes[1:])
box("saloons_fwd_port", BX["G"] - T, BX["G"] + T, -SALOON_Z - T, G_DOOR[0], F_DECK, E_DECK)
box("saloons_fwd_lintel", BX["G"] - T, BX["G"] + T, G_DOOR[0], G_DOOR[1], F_DECK + LINTEL, E_DECK)
doorways.append((0, BX["G"], G_DOOR[0], G_DOOR[1], F_DECK))
wall_x("baths_f", BX["F"], -SALOON_Z, SALOON_Z, F_DECK, E_DECK, [door_at(-6.0)])
wall_x("baths_e", BX["E"], -BR5_Z, BR5_Z, F_DECK, E_DECK)
for tag, x0, x1, w in [("br4", BX["G"], BX["F"], SALOON_Z), ("br5", BX["F"], BX["E"], BR5_Z)]:
    for side, z in [("p", -w), ("s", w)]:
        wall_z("baths_%s_%s" % (tag, side), z, x0, x1, F_DECK, E_DECK)
wall_z("baths", BATHS_Z, BX["G"], BX["E"], F_DECK, E_DECK, [door_at(21.0), door_at(38.5)])
for k, (_cx, x0, x1) in zip((4, 5), CASINGS):
    wall_x("casing_%d_aft" % k, x0, -FIDDLEY, FIDDLEY, F_DECK, E_DECK)
    wall_x("casing_%d_fwd" % k, x1, -FIDDLEY, FIDDLEY, F_DECK, E_DECK)
    wall_z("casing_%d_p" % k, -FIDDLEY, x0, x1, F_DECK, E_DECK)
room("corridor_br4", "F deck working corridor, boiler room 4", BX["G"], BX["F"], -SALOON_Z, BATHS_Z, F_DECK)
room("corridor_br5", "F deck working corridor, boiler room 5", BX["F"], BX["E"], -BR5_Z, BATHS_Z, F_DECK)
room("turkish_bath", "Turkish bath", BX["G"], BX["F"], BATHS_Z, SALOON_Z, F_DECK)
room("swimming_bath", "swimming bath", BX["F"], BX["E"], BATHS_Z, BR5_Z, F_DECK)
box("pool", 40.0, 49.1, 4.5, 8.8, F_DECK, F_DECK + 1.0)

# --- The squash court in No. 2 hold (SB-IV), after every other platform, blocker and
# room so none of theirs moves: a hall on G deck from bulkhead C forward, two decks high
# to D deck, and its spectators' gallery at its after end on F deck, reached from the
# third-class berths' landing through bulkhead C's door (wtd_f_c), two stairs down from
# it into the court either side. The hall's floor stops at bulkhead C, short of the post
# office's landing: no door in G deck's bulkhead there, and an open deck of its own, its
# two stairs up its own. The gallery's floor runs on from F deck's landing. Sizes est.
COURT_FWD = 101.5            # the hall's forward wall, short of bulkhead B
COURT_Z = fit(BX["C"], COURT_FWD, G_DECK, 0.3)
GALLERY_FWD = 89.5           # the gallery's front, over the court
GALLERY_Z = H3W[G_DECK]      # the gallery's half width, as No. 3 hold's rooms
COURT_STAIR = 3.4            # a flight G to F deck, as No. 3 hold's
g_court = deck("g_court", "G deck", BX["C"], COURT_FWD, -COURT_Z, COURT_Z, G_DECK, [])
f_gallery = deck("f_gallery", "F deck", h3_floor[1], GALLERY_FWD, -GALLERY_Z, GALLERY_Z, F_DECK, [])
court_lanes = []
for side, sign in [("p", -1), ("s", 1)]:
    lane = sorted((sign * (COURT_Z - T - STAIR), sign * (COURT_Z - T)))
    court_lanes.append(tuple(lane))
    stair("court_" + side, GALLERY_FWD + COURT_STAIR, GALLERY_FWD, lane[0], lane[1], G_DECK, F_DECK, [])
rail_line("gallery_front", f_gallery, 0, GALLERY_FWD, court_lanes[0][1], court_lanes[1][0])
# F deck's landing wall: the port piece and lintel of its door (above).
LANDING_DOOR = door_at(-6.0)
w = H3W[G_DECK]
box("berths_landing_port", h3_floor[1] - T, h3_floor[1] + T, -w - T, LANDING_DOOR[0], F_DECK, E_DECK)
box("berths_landing_lintel", h3_floor[1] - T, h3_floor[1] + T, LANDING_DOOR[0], LANDING_DOOR[1],
    F_DECK + LINTEL, E_DECK)
doorways.append((0, h3_floor[1], LANDING_DOOR[0], LANDING_DOOR[1], F_DECK))
# Bulkhead C: closed on G deck, its door on F deck.
wall_x("court_c", BX["C"], -COURT_Z, COURT_Z, G_DECK, F_DECK)
wall_x("gallery_c", BX["C"], -GALLERY_Z, GALLERY_Z, F_DECK, D_DECK, [LANDING_DOOR])
wall_x("court_fwd", COURT_FWD, -COURT_Z, COURT_Z, G_DECK, D_DECK)
for side, sign in [("p", -1), ("s", 1)]:
    # The hall's sides: under the gallery to F deck, past it to D; the gallery's own,
    # and the step between them at its front.
    wall_z("court_%s_aft" % side, sign * COURT_Z, BX["C"], GALLERY_FWD, G_DECK, F_DECK)
    wall_z("court_%s" % side, sign * COURT_Z, GALLERY_FWD + T, COURT_FWD, G_DECK, D_DECK)
    wall_z("gallery_%s" % side, sign * GALLERY_Z, BX["C"], GALLERY_FWD, F_DECK, D_DECK)
    wall_x("gallery_%s_step" % side, GALLERY_FWD, *sorted((sign * COURT_Z, sign * GALLERY_Z)), F_DECK, D_DECK)
room("squash_court", "squash court", BX["C"], COURT_FWD, -COURT_Z, COURT_Z, G_DECK)
# The gallery's room wall to wall, bulkhead C's door opening into it. F deck's landing,
# between the berths' forward wall and their landing wall, a room of its own, so the way
# from the gallery to the berths runs door to door.
room("squash_gallery", "squash court gallery", BX["C"], GALLERY_FWD, -GALLERY_Z, GALLERY_Z, F_DECK)
room("f_landing", "F deck landing corridor", H3_LANDING, h3_floor[1], -w, w, F_DECK)

# --- Boiler rooms 2 to 5 at the tank top (SB-III, SB-IV), after every other platform,
# ramp, blocker and room so none of theirs moves: each room's plates from its after
# bulkhead to its cross bunker, walled to F deck at both and along her sides inside the
# deck over them, the boilers boxes on them with a firing aisle fore and aft; nobody's
# floor behind the bunker's face. Est.: the real ship had five double-ended boilers a
# room (four in boiler room 5) — here four abreast, three in the narrower boiler room 5,
# each 6.1 m long and 4.8 m across, 1.2 m apart where the room's breadth allows; each
# box carried up with the uptakes over its boiler to a quarter metre under F deck,
# too near it for anybody to stand on it, and boiler room 5's aft of the fiddley's
# casing over its middle. No door through a bulkhead (there was none at the plates but the
# vertical watertight doors, which are the structure's): two flights up to F deck a
# room, so each room's plates have two ways up of their own — one beside the boilers
# along her starboard side, and a second to port in boiler rooms 4 and 5; in 2 and 3,
# where Scotland Road's stairs up from F deck stand over the port side, the second
# rises between the boilers along her centre line. F deck is cut over each flight, out
# to her side wall where it would leave only a sliver under it; else the flight keeps
# half a metre and more off that wall, where a room's dressing stops short of a stair.
BOILER = (6.1, 4.8)    # est.: a boiler's length and its breadth across her
UPTAKE_CLEAR = 0.25    # a boiler's box's top under F deck
STOKEHOLD_RUN = 11.875  # a flight's run up from the tank top to F deck (est.), 39°
FLIGHT_LEAD = 0.8       # a body's width clear before each end of a flight

def abreast(count, gap, middle):
    """count boilers side by side across her, gap apart, middle apart either side of
    her centre line (None: gap), centred on it, as (z0, z1)."""
    gaps = [gap] * (count - 1)
    if middle is not None:
        gaps[(count - 1) // 2] = middle
    z = -(count * BOILER[1] + sum(gaps)) * 0.5
    found = []
    for k in range(count):
        found.append((z, z + BOILER[1]))
        z += BOILER[1] + (gaps[k] if k < count - 1 else 0.0)
    return found

# (k, its after bulkhead, its boilers across her, their middle's offset aft of the
# stokehold's, the F deck over it)
STOKEHOLDS = [
    (2, "J", abreast(4, 0.6, 2.0), 0.0, "f_saloons"),  # est.: an aisle down the middle for the stair
    (3, "H", abreast(4, 0.6, 2.0), 0.0, "f_saloons"),
    (4, "G", abreast(4, 0.7, None), 0.0, "f_br4"),     # est.: 0.7 m apart, her bilge narrower
    (5, "F", abreast(3, 1.2, None), 2.0, "f_br5"),     # est.: clear of the casing
]
f_decks = {"f_saloons": (f_saloons, BX["J"], BX["G"], SALOON_Z, []),
           "f_br4": (f_br4, BX["G"], BX["F"], SALOON_Z, casing_holes[:1]),
           "f_br5": (f_br5, BX["F"], BX["E"], BR5_Z, casing_holes[1:])}
stokehold_flights = []
STOKEHOLD_Z = {}  # each stokehold's plates' half width
for k, aft, rows, back, over in STOKEHOLDS:
    x0, bunker = BX[aft], BUNKERS["br%d" % k]
    plates = (x0 + T, bunker - T)
    deck_w = f_decks[over][3]
    w = min(fit(plates[0], plates[1], TANK_TOP, 0.3), deck_w - T)
    STOKEHOLD_Z[k] = w
    platform("stokehold_%d" % k, "tank top", plates[0], plates[1], -w, w, TANK_TOP)
    side = w - T
    if deck_w - side > 2 * T + 1e-9:
        side = min(side, deck_w - T - 0.55)
    lanes = [("s", (side - STAIR, side))]
    lanes.append(("m", (-STAIR * 0.5, STAIR * 0.5)) if k < 4 else ("p", (-side, STAIR - side)))
    # Its foot on a sixteenth of a metre, as its run, so its head meets the deck cut
    # round it exactly in single precision.
    low = math.ceil((plates[0] + FLIGHT_LEAD) * 16) / 16
    for tag, (z0, z1) in lanes:
        sid = "stokehold_%d_%s" % (k, tag)
        stair(sid, low, low + STOKEHOLD_RUN, z0, z1, TANK_TOP, F_DECK, [])
        if deck_w - abs(z1 if tag == "s" else z0) <= 2 * T + 1e-9:
            z0, z1 = (z0, deck_w) if tag == "s" else (-deck_w, z1)
        f_decks[over][4].append((low, low + STOKEHOLD_RUN, z0, z1))
        stokehold_flights.append((sid, over))
    # The boiler farthest from the flights first: an engine room's steam pipes run beside
    # its first machine's sides under the deck, where a body climbing a flight beside it
    # would put its head (EngineRoom).
    rows = sorted(rows, key=lambda r: -min(max(lane[0] - r[1], r[0] - lane[1]) for _tag, lane in lanes))
    middle = (plates[0] + plates[1]) * 0.5 - back
    for j, (z0, z1) in enumerate(rows):
        box("boiler_%d_%d" % (k, j), middle - BOILER[0] * 0.5, middle + BOILER[0] * 0.5, z0, z1,
            TANK_TOP, F_DECK - UPTAKE_CLEAR)
    wall_x("stokehold_%d_aft" % k, x0, -w, w, TANK_TOP, F_DECK)
    wall_x("stokehold_%d_bunker" % k, bunker, -w, w, TANK_TOP, F_DECK)
    for tag, z in [("p", -w), ("s", w)]:
        wall_z("stokehold_%d_%s" % (k, tag), z, x0, bunker, TANK_TOP, F_DECK)
    room("boiler_room_%d" % k, "boiler room %d" % k, x0, bunker, -w, w, TANK_TOP)
for over, (made, x0, x1, half, holes) in f_decks.items():
    f_decks[over] = recut(made, over, "F deck", x0, x1, -half, half, F_DECK, holes)
for sid, over in stokehold_flights:
    hole_rails(f_decks[over], sid)

# The firemen's passage, from the foot of the spiral stairs in No. 2 hold aft through
# No. 3 to boiler room 6 (Wilding: "the spiral stair"; BOT: its side "3 1/2 ft from the
# outer skin of the ship", in No. 2 hold): est. 2 m wide and 8 ft high, its starboard
# side 3 ft 6 in inside her shell at its middle height in No. 2 hold.
PASSAGE_TOP = q(TANK_TOP + 8.0 * FT)
PASSAGE_Z = (round(breadth(94.0, (TANK_TOP + PASSAGE_TOP) * 0.5) - 3.5 * FT - 2.0, 4),
             round(breadth(94.0, (TANK_TOP + PASSAGE_TOP) * 0.5) - 3.5 * FT, 4))

# --- Every cell a place a body can be (#148), the bow: boiler room 6, its bunker and the
# firemen's passage forward of it, Nos. 3, 2 and 1 holds deck by deck, the forepeak and its
# tank, the forecastle over them, and the double bottoms under them all — after every other
# platform, ramp, blocker and room so none of theirs moves; a wall given a door is laid
# again in its place, its other pieces after every other (relay_box). Her cells, her hull
# and her openings stand as they were but for the ways into her old voids, every one
# sealed to the water (with her openings, below), so she floods as she did. Every floor
# stands 0.3 m inside her shell (fit), every room inside her lines from its floor up, and
# every stair is climbable (STEEPEST), its ends on sixteenths of a metre so they meet their
# decks in single precision (joins, below). Sizes and places est.
SPACE_FLIGHT = 3.0      # a flight's run up 8 ft, the firemen's passage's height (est.), 39°
NARROW_STAIR = 0.9      # a stair in a narrow space or down a manhole: a body's width and a hand
# The ways through her watertight bulkheads the spaces take where no deck over them leaves a
# way up (est.): each a door bolted shut, as the manholes are — (name, bulkhead, floor, z).
SEALED_DOORS = []

def sealed_door(name, letter, floor, z):
    SEALED_DOORS.append((name, BX[letter], floor, z))
    return door_at(z)

def door_in(bid, x, z0, z1, bottom, top, middle):
    """The wall bid, one box across her at x from z0 to z1 (wall_x's), given a door round
    middle as wall_x gives one: its first piece laid over the box it was, the rest after
    every other."""
    d0, d1 = door_at(middle)
    relay_box(bid, x - T, x + T, z0 - T, d0, bottom, top)
    box(bid + "_1", x - T, x + T, d1, z1 + T, bottom, top)
    if bottom + LINTEL < top:
        box(bid + "_lintel_0", x - T, x + T, d0, d1, bottom + LINTEL, top)
    doorways.append((0, x, d0, d1, bottom))

def walled(bid, x0, x1, z0, z1, bottom, top, sides="psaf", doors=None):
    """Walls from bottom to top along the sides of (x0..x1, z0..z1) that sides names — p
    along z0, s along z1, a across x0, f across x1 — each with its doors [(from, to)]."""
    doors = doors or {}
    for side in sides:
        if side in "ps":
            wall_z("%s_%s" % (bid, side), z0 if side == "p" else z1, x0, x1, bottom, top, doors.get(side, ()))
        else:
            wall_x("%s_%s" % (bid, side), x0 if side == "a" else x1, z0, z1, bottom, top, doors.get(side, ()))

# Boiler room 6 (SB-III): the stokeholds' pattern (above) — two boilers abreast in her
# narrowing bilge, their firing aisles fore and aft — with an F deck of its own over it and
# its bunker, which it had none of: a working corridor from bulkhead E's door to bulkhead
# D's (wtd_f_e, wtd_f_d), on along F deck through boiler rooms 5 and 4 to the third-class
# saloons aft, and into No. 3 hold's berths forward. Its plates run on into its bunker's
# floor, and that into the firemen's passage's: the stokers' way to their quarters (Wilding).
BR6 = (BX["E"], BUNKERS["br6"])
F6_Z = fit(BX["E"], h3_floor[0], F_DECK, 0.3)
BR6_Z = min(fit(BR6[0] + T, BR6[1], TANK_TOP, 0.3), F6_Z - T)
BUNKER6_Z = min(fit(BR6[1], BX["D"], TANK_TOP, 0.3), BR6_Z)
f6_holes, br6_holes = [], []
side = BR6_Z - T
low6 = math.ceil((BR6[0] + T + FLIGHT_LEAD) * 16) / 16
for tag, (z0, z1) in [("s", (side - STAIR, side)), ("p", (-side, STAIR - side))]:
    stair("stokehold_6_" + tag, low6, low6 + STOKEHOLD_RUN, z0, z1, TANK_TOP, F_DECK, f6_holes)
cx6 = (BR6[0] + BR6[1]) * 0.5
f6_holes.append((cx6 - FIDDLEY, cx6 + FIDDLEY, -FIDDLEY, FIDDLEY))
middle6 = (BR6[0] + T + BR6[1]) * 0.5
for j, (z0, z1) in enumerate(abreast(2, 0.6, 2.0)):
    box("boiler_6_%d" % j, middle6 - BOILER[0] * 0.5, middle6 + BOILER[0] * 0.5, z0, z1, TANK_TOP,
        F_DECK - UPTAKE_CLEAR)
# Its after wall through bulkhead E's vertical door (wtd_e) into bunker 5, its bunker wall
# whole, the bunker door shut in it (bunker_door_6; the coal face round it, LinerBoiler).
walled("stokehold_6", BR6[0], BR6[1], -BR6_Z, BR6_Z, TANK_TOP, F_DECK, "asp", {"a": [door_at(0.0)]})
wall_x("stokehold_6_bunker", BR6[1], -BR6_Z, BR6_Z, TANK_TOP, F_DECK)
room("boiler_room_6", "boiler room 6", BR6[0], BR6[1], -BR6_Z, BR6_Z, TANK_TOP)
# Bunker 6, through bulkhead D's vertical door (wtd_d) from the firemen's passage — each
# bunker is entered through the vertical door in the bulkhead it stands against (Wilding:
# "the watertight bulkheads are in coal bunkers"), its bunker door from its stokehold shut
# — its forward wall No. 3 hold's after one too, up to F deck.
PASSAGE_MID = (PASSAGE_Z[0] + PASSAGE_Z[1]) * 0.5
walled("bunker_6", BR6[1], BX["D"], -BUNKER6_Z, BUNKER6_Z, TANK_TOP, F_DECK, "psf", {"f": [door_at(PASSAGE_MID)]})
room("bunker_6", "coal bunker 6", BR6[1], BX["D"], -BUNKER6_Z, BUNKER6_Z, TANK_TOP)
# F deck over them: bulkhead E's wall given its door (baths_e), bulkhead D's its own, the
# berths' after wall given theirs (berths_aft); the fiddley's casing walled up to D deck.
door_in("baths_e", BX["E"], -BR5_Z, BR5_Z, F_DECK, E_DECK, -6.0)
walled("f_br6", BX["E"], BX["D"], -F6_Z, F6_Z, F_DECK, D_DECK, "psf", {"f": [door_at(-6.0)]})
door_in("berths_aft", h3_floor[0], -H3W[G_DECK], H3W[G_DECK], F_DECK, E_DECK, -6.0)
walled("casing_6", cx6 - FIDDLEY, cx6 + FIDDLEY, -FIDDLEY, FIDDLEY, F_DECK, D_DECK)
room("f_br6", "F deck working corridor, boiler room 6", BX["E"], BX["D"], -F6_Z, F6_Z, F_DECK)

# The firemen's passage (above, its cell), from bunker 6 forward under Nos. 3 and 2 holds to
# the spiral stairs at its forward end (Wilding), here a stair up forward out of it onto
# No. 2 hold's orlop deck, its foot facing a body coming along it (the passage's stair
# opening stands for it). Its floor ends there, where her bilge closes in on its starboard
# side (est.).
PASSAGE_END = 96.25
pt3_holes, pt2_holes, h3_holes, h2_holes = [], [], [], []
stair("space_spiral", PASSAGE_END - T - FLIGHT_LEAD - 0.1 - SPACE_FLIGHT, PASSAGE_END - T - FLIGHT_LEAD - 0.1,
      PASSAGE_MID - STAIR * 0.5, PASSAGE_MID + STAIR * 0.5, TANK_TOP, PASSAGE_TOP, pt2_holes)
walled("passage", BX["D"], PASSAGE_END, PASSAGE_Z[0], PASSAGE_Z[1], TANK_TOP, PASSAGE_TOP, "psf")
room("passage", "firemen's passage", BX["D"], PASSAGE_END, PASSAGE_Z[0], PASSAGE_Z[1], TANK_TOP)

# Nos. 3 and 2 holds: at the tank top either side of the passage, each part's floor open
# to the hold over it (open_hold_*), as wide as her bilge lets it be — No. 2 hold's
# starboard part too narrow for anybody, its cell left nobody's; over the passage's top an
# orlop deck across each hold (est.), No. 2's reached through bulkhead C from No. 3's;
# No. 3's two flights up into the post office on G deck (stair_hold_3 stands for them).
H3T = fit(BX["D"], BX["C"], TANK_TOP, 0.3)
H2T = fit(BX["C"], BX["B"], TANK_TOP, 0.3)
H3P = fit(BX["D"], BX["C"], PASSAGE_TOP, 0.3)
H2P = fit(BX["C"], BX["B"], PASSAGE_TOP, 0.3)
inboard = (PASSAGE_Z[0] - T - STAIR, PASSAGE_Z[0] - T)
starboard = (PASSAGE_Z[1] + T + 0.11, PASSAGE_Z[1] + T + 0.11 + NARROW_STAIR)
for sid, foot, head, lane, holes_above in [
        ("space_h3_a", 75.0, 72.0, inboard, pt3_holes), ("space_h3_b", 82.0, 85.0, inboard, pt3_holes),
        ("space_h3_c", 74.75, 71.75, starboard, pt3_holes), ("space_h3_d", 82.3125, 85.3125, starboard, pt3_holes),
        ("space_h2_a", 90.25, 87.25, inboard, pt2_holes), ("space_h2_b", 97.75, 100.75, inboard, pt2_holes)]:
    stair(sid, foot, head, lane[0], lane[1], TANK_TOP, PASSAGE_TOP, holes_above)
g3_holes = []
for sid, (z0, z1) in [("space_h3_g_1", (-4.2, -2.8)), ("space_h3_g_2", (-2.8, -1.4))]:
    stair(sid, 83.0, 77.375, z0, z1, PASSAGE_TOP, G_DECK, g3_holes)
g_post = recut(g_post, "g_post", "G deck", h3_floor[0], h3_floor[1], -H3W[G_DECK], H3W[G_DECK], G_DECK, g3_holes)

# The double bottoms (#148): crawl spaces on her bottom plating under the tank top, 5 ft 3
# in (SB-text), each entered through two manholes in the tank top over it, a stair down each.
DB6_Z = fit(BX["E"], BX["D"], KEEL, 0.3)
DB3_Z = fit(BX["D"], BX["C"], KEEL, 0.3)
DB2_Z = fit(BX["C"], BX["B"], KEEL, 0.3)
H1_SPLIT = 110.0  # where No. 1 hold's floors narrow (est.)
DB1_Z = fit(BX["B"], H1_SPLIT, KEEL, 0.3)
h1_holes = []
for sid, foot, head, (z0, z1), holes_above in [
        ("space_db6_a", 57.0, 55.0, (-2.0, -1.1), br6_holes), ("space_db6_b", 64.75, 66.75, (1.1, 2.0), br6_holes),
        ("space_db3_a", 78.0, 76.0, (-3.0, -2.1), h3_holes), ("space_db3_b", 79.8125, 81.8125, (-3.0, -2.1), h3_holes),
        ("space_db2_a", 94.0, 92.0, (-0.45, 0.45), h2_holes),
        ("space_db2_b", 95.8125, 97.8125, (-0.45, 0.45), h2_holes),
        ("space_db1_a", 105.0, 103.0, (0.1, 1.0), h1_holes), ("space_db1_b", 106.8125, 108.8125, (0.1, 1.0), h1_holes)]:
    stair(sid, foot, head, z0, z1, KEEL, TANK_TOP, holes_above)
for rid, name, x0, x1, w in [("db_br6", "boiler room 6 double bottom", BX["E"], BX["D"], DB6_Z),
                             ("db_hold_3", "No. 3 hold double bottom", BX["D"], BX["C"], DB3_Z),
                             ("db_hold_2", "No. 2 hold double bottom", BX["C"], BX["B"], DB2_Z),
                             ("db_hold_1", "No. 1 hold double bottom", BX["B"], H1_SPLIT, DB1_Z)]:
    deck(rid, "double bottom", x0, x1, -w, w, KEEL, [])
    walled(rid, x0, x1, -w, w, KEEL, TANK_TOP, "ps")
    room(rid, name, x0, x1, -w, w, KEEL, crawl_space=TANK_TOP - KEEL < rule("body_height"))
for letter, at, w in [("e", BX["E"], DB6_Z), ("d", BX["D"], DB6_Z), ("c", BX["C"], DB3_Z), ("b", BX["B"], DB2_Z)]:
    wall_x("db_" + letter, at, -w, w, KEEL, TANK_TOP)
# No. 1 hold's on forward of its manholes to bulkhead A, as narrow as her forefoot leaves it,
# through a door in their wall.
DB1F_Z = fit(H1_SPLIT, BX["A"], KEEL, 0.3)
wall_x("db_1", H1_SPLIT, -DB1_Z, DB1_Z, KEEL, TANK_TOP, [door_at(0.0)])
deck("db_hold_1_fwd", "double bottom", H1_SPLIT, BX["A"], -DB1F_Z, DB1F_Z, KEEL, [])
walled("db_hold_1_fwd", H1_SPLIT, BX["A"], -DB1F_Z, DB1F_Z, KEEL, TANK_TOP, "psf")
room("db_hold_1_fwd", "No. 1 hold double bottom, forward", H1_SPLIT, BX["A"], -DB1F_Z, DB1F_Z, KEEL,
     crawl_space=TANK_TOP - KEEL < rule("body_height"))

# The plates, the bunker's floor and the passage's, touching end to end through the walls;
# the holds' tank top either side of the passage, and their orlop decks over it.
br6_plates = deck("stokehold_6", "tank top", BR6[0], BR6[1], -BR6_Z, BR6_Z, TANK_TOP, br6_holes)
deck("bunker_6", "tank top", BR6[1], BX["D"], -BUNKER6_Z, BUNKER6_Z, TANK_TOP, [])
deck("passage", "tank top", BX["D"], PASSAGE_END, PASSAGE_Z[0], PASSAGE_Z[1], TANK_TOP, [])
h3_tank = deck("hold_3_port", "tank top", BX["D"], BX["C"], -H3T, PASSAGE_Z[0], TANK_TOP, h3_holes)
deck("hold_3_starboard", "tank top", BX["D"], BX["C"], PASSAGE_Z[1], H3T, TANK_TOP, [])
h2_tank = deck("hold_2_port", "tank top", BX["C"], BX["B"], -H2T, PASSAGE_Z[0], TANK_TOP, h2_holes)
pt3 = deck("pt_hold_3", "orlop deck", BX["D"], BX["C"], -H3P, H3P, PASSAGE_TOP, pt3_holes)
pt2 = deck("pt_hold_2", "orlop deck", BX["C"], BX["B"], -H2P, H2P, PASSAGE_TOP, pt2_holes)
f6 = deck("f_br6", "F deck", BX["E"], h3_floor[0], -F6_Z, F6_Z, F_DECK, f6_holes)
walled("hold_3_port", BX["D"], BX["C"], -H3T, PASSAGE_Z[0], TANK_TOP, PASSAGE_TOP, "p")
walled("hold_3_starboard", BX["D"], BX["C"], PASSAGE_Z[1], H3T, TANK_TOP, PASSAGE_TOP, "s")
walled("hold_2_port", BX["C"], BX["B"], -H2T, PASSAGE_Z[0], TANK_TOP, PASSAGE_TOP, "p")
wall_x("tank_c", BX["C"], -H3T, PASSAGE_Z[0], TANK_TOP, PASSAGE_TOP)
wall_x("tank_c_s", BX["C"], PASSAGE_Z[1], H3T, TANK_TOP, PASSAGE_TOP)
wall_x("tank_b", BX["B"], -H2T, PASSAGE_Z[0], TANK_TOP, PASSAGE_TOP)
walled("pt_hold_3", BX["D"], BX["C"], -H3P, H3P, PASSAGE_TOP, G_DECK, "psf",
       {"f": [sealed_door("sealed_c_orlop", "C", PASSAGE_TOP, -1.0)]})
walled("pt_hold_2", BX["C"], BX["B"], -H2P, H2P, PASSAGE_TOP, G_DECK, "psf")
room("hold_3_port", "No. 3 hold, port", BX["D"], BX["C"], -H3T, PASSAGE_Z[0], TANK_TOP)
room("hold_3_starboard", "No. 3 hold, starboard", BX["D"], BX["C"], PASSAGE_Z[1], H3T, TANK_TOP)
room("hold_2_port", "No. 2 hold, port", BX["C"], BX["B"], -H2T, PASSAGE_Z[0], TANK_TOP)
# Each orlop's room roofed by G deck from end to end: No. 3's, bulkhead to bulkhead, under
# a strip of G deck laid between bulkhead D's wall and the post office's floor (so its
# hold's framing stops under G deck there too); No. 2's under the squash court.
deck("g_strip_d", "G deck", BX["D"] + T, h3_floor[0], -H3P, H3P, G_DECK, [])
room("hold_3_orlop", "No. 3 hold", BX["D"], BX["C"], -H3P, H3P, PASSAGE_TOP)
room("hold_2_orlop", "No. 2 hold", BX["C"], COURT_FWD, -H2P, H2P, PASSAGE_TOP)

# No. 1 hold, deck over deck from its tank top to D deck: an orlop deck and G deck in it
# (est.), two flights up each — side by side up to G deck, and up into the firemen's
# quarters on D deck (D_PLAN) either side of No. 1 hatch's cover, outboard of it, their
# walls under them cut to their undersides (under_flights) — and out from them by the
# crew's stairs up to the forecastle and its door onto the forward well (door_forecastle).
# Each deck narrows forward of H1_SPLIT with her bow. The forepeak's tank and its stores
# forward of bulkhead A, each through a door in it from the hold's deck at its floor.
H1T = (fit(BX["B"], H1_SPLIT, TANK_TOP, 0.3), fit(H1_SPLIT, BX["A"], TANK_TOP, 0.3))
H1O = (fit(BX["B"], H1_SPLIT, ORLOP, 0.3), fit(H1_SPLIT, BX["A"], ORLOP, 0.3))
H1G = (fit(BX["B"], H1_SPLIT, G_DECK, 0.3), fit(H1_SPLIT, BX["A"], G_DECK, 0.3))
h1o_holes, h1g_holes, h1d_holes = [], [], []
for sid, foot, head, (z0, z1), low, high, holes_above in [
        ("space_h1_or_1", 108.625, 103.0, (-2.1, -1.1), TANK_TOP, ORLOP, h1o_holes),
        ("space_h1_or_2", 108.625, 103.0, (-1.1, -0.1), TANK_TOP, ORLOP, h1o_holes),
        ("space_h1_g_1", 105.5, 108.5, (0.5, 1.55), ORLOP, G_DECK, h1g_holes),
        ("space_h1_g_2", 105.5, 108.5, (1.55, 2.6), ORLOP, G_DECK, h1g_holes),
        ("space_h1_d", 104.0, 113.375, (-3.75, -2.7), G_DECK, D_DECK, h1d_holes),
        ("space_h1_d_2", 104.0, 113.375, (2.7, 3.75), G_DECK, D_DECK, h1d_holes)]:
    stair(sid, foot, head, z0, z1, low, high, holes_above)
# Each flight's opening in D deck screened along its inboard side forward of No. 1 hatch's
# cover (est.), so the joint between the quarters' pieces it runs under is two doors, each
# a step onto the deck either side of the opening, not one whose middle is over it. So
# are the open space's after ladderways' openings down to E deck, a screen along each
# one's inboard side (est.): the joint between the open space's after piece and the next
# it runs under is two doors either side of it.
box("space_h1_d_screen", 108.0, 112.9, -2.6, -2.5, D_DECK, 0.0)
box("space_h1_d_2_screen", 108.0, 112.9, 2.5, 2.6, D_DECK, 0.0)
for k, flight in enumerate(f for f in D_PLAN.stairs if f[0] == "third-class ladder" and f[2] < BX["C"]):
    _n, lx0, lx1, lz0, lz1, *_rest = clear_sides(flight)
    inboard = (lz1, lz1 + 0.1) if lz1 < 0.0 else (lz0 - 0.1, lz0)
    box("ladderway_screen_%d" % k, lx0, lx1, *inboard, D_DECK, 0.0)
FP_TANK = (119.5, fit(BX["A"], 119.5, TANK_TOP, 0.3))
FP_STORES = (122.0, fit(BX["A"], 122.0, ORLOP, 0.3))
h1_decks = {}
for level, h, widths, holes, top in [("tank", TANK_TOP, H1T, h1_holes, ORLOP), ("orlop", ORLOP, H1O, h1o_holes, G_DECK),
                                     ("g", G_DECK, H1G, h1g_holes, D_DECK)]:
    name = {"tank": "tank top", "orlop": "orlop deck", "g": "G deck"}[level]
    made = deck("hold_1_" + level, name, BX["B"], H1_SPLIT, -widths[0], widths[0], h, holes)
    made += deck("hold_1_%s_fwd" % level, name, H1_SPLIT, BX["A"], -widths[1], widths[1], h, holes)
    h1_decks[level] = made
    walled("hold_1_" + level, BX["B"], H1_SPLIT, -widths[0], widths[0], h, top, "ps")
    walled("hold_1_%s_fwd" % level, H1_SPLIT, BX["A"], -widths[1], widths[1], h, top, "ps")
    for tag, sign in [("p", -1), ("s", 1)]:
        wall_x("hold_1_%s_step_%s" % (level, tag), H1_SPLIT, *sorted((sign * widths[1], sign * widths[0])), h, top)
deck("forepeak_tank", "tank top", BX["A"], FP_TANK[0], -FP_TANK[1], FP_TANK[1], TANK_TOP, [])
deck("forepeak_stores", "orlop deck", BX["A"], FP_STORES[0], -FP_STORES[1], FP_STORES[1], ORLOP, [])
wall_x("tank_a", BX["A"], -H1T[1], H1T[1], TANK_TOP, ORLOP, [sealed_door("sealed_a_tank", "A", TANK_TOP, 0.0)])
wall_x("orlop_a", BX["A"], -H1O[1], H1O[1], ORLOP, G_DECK, [sealed_door("sealed_a_orlop", "A", ORLOP, 0.0)])
wall_x("g_b", BX["B"], -H1G[0], H1G[0], G_DECK, D_DECK)
wall_x("g_a", BX["A"], -H1G[1], H1G[1], G_DECK, D_DECK)
walled("forepeak_tank", BX["A"], FP_TANK[0], -FP_TANK[1], FP_TANK[1], TANK_TOP, ORLOP, "psf")
# The forepeak's stores from its orlop up to D deck over them (D_PLAN, its store in her eyes).
walled("forepeak_stores", BX["A"], FP_STORES[0], -FP_STORES[1], FP_STORES[1], ORLOP, D_DECK, "psf")
# G deck over it a passage between its flights, no hold: under the 'tween deck a hold's
# dressing stows (CargoHold), its flights up would climb through cargo.
for rid, name, x1, widths, h in [("hold_1", "No. 1 hold", H1_SPLIT, H1T, TANK_TOP),
                                 ("hold_1_orlop", "No. 1 hold, orlop", H1_SPLIT, H1O, ORLOP),
                                 ("hold_1_g", "G deck passage, No. 1 hold", H1_SPLIT, H1G, G_DECK)]:
    room(rid, name, BX["B"], x1, -widths[0], widths[0], h)
    room(rid + "_fwd", name + ", forward", x1, BX["A"], -widths[1], widths[1], h)
room("forepeak_tank", "forepeak tank", BX["A"], FP_TANK[0], -FP_TANK[1], FP_TANK[1], TANK_TOP)
room("forepeak_stores", "forepeak stores", BX["A"], FP_STORES[0], -FP_STORES[1], FP_STORES[1], ORLOP)

# Three sides of every new stair's hole railed, as the layout's other stairs' are.
for decks, sids in [(f6, ["stokehold_6_s", "stokehold_6_p"]), (br6_plates, ["space_db6_a", "space_db6_b"]),
                    (h3_tank, ["space_db3_a", "space_db3_b"]), (h2_tank, ["space_db2_a", "space_db2_b"]),
                    (h1_decks["tank"], ["space_db1_a", "space_db1_b"]),
                    (pt3, ["space_h3_a", "space_h3_b", "space_h3_c", "space_h3_d"]),
                    (pt2, ["space_h2_a", "space_h2_b", "space_spiral"]), (g_post, ["space_h3_g_1", "space_h3_g_2"]),
                    (h1_decks["orlop"], ["space_h1_or_1", "space_h1_or_2"]),
                    (h1_decks["g"], ["space_h1_g_1", "space_h1_g_2"])]:
    for sid in sids:
        hole_rails(decks, sid)

# --- Every cell a place a body can be (#148), the stern: boiler room 1 and its bunker,
# the reciprocating engine room, the turbine engine room and the electric engine room, the
# two after holds deck by deck, and the double bottoms under them all, as the bow's
# (above). Their way up is a working passage along E deck from the engine room aft through
# the E deck doors in bulkheads L to O (wtd_e_l…o), a stair up from it into the D deck
# corridor over the engine room and another into the second-class dining saloon over the
# turbine room; boiler room 1's is the bow's, an F deck corridor of its own forward to the
# third-class saloons (wtd_f_j), and a stair from it up into Scotland Road. The after holds
# are reached through their watertight orlop deck by hatches bolted shut, as the manholes
# are (below, where her openings are).
def bulkhead_wall(bid, x, bands, doors=()):
    """Walls across her at x, one for each (bottom, top, half width) of bands, the doors
    [(z, floor)] in the band whose bottom is that floor."""
    for k, (bottom, top, w) in enumerate(bands):
        gaps = [door_at(z) for z, floor in doors if floor == bottom]
        wall_x("%s_%d" % (bid, k), x, -w, w, bottom, top, gaps)

# Boiler room 1 (SB-III; S8d′3): too short from bulkhead K to its bunker for a flight up
# to F deck along her, its two flights rise athwartships by its after wall, port and
# starboard, their heads either side of her centre line; its boilers abreast forward of
# them (est. three, BR1's single-ended five as three boxes), a firing aisle before its
# bunker's door.
BR1 = (BX["K"], BUNKERS["br1"])
BR1_Z = min(fit(BR1[0], BX["J"], F_DECK, 0.3), SALOON_Z)  # as wide as the saloons' F deck it meets
BR1_PLATES = min(fit(BR1[0], BR1[1], TANK_TOP, 0.3), BR1_Z)
BUNKER1_Z = min(fit(BR1[1], BX["J"], TANK_TOP, 0.3), STOKEHOLD_Z[2])  # boiler room 2's after wall's
f1_holes, bunker1_holes = [], []
BR1_FLIGHT = (-27.5, -26.1)
BR1_RUN = 11.5  # a flight's run across her up to F deck, 40°: as long as her side leaves room for
for tag, sign in [("p", -1), ("s", 1)]:
    head = sign * 0.5
    stair_z("space_br1_" + tag, head + sign * BR1_RUN, head, *BR1_FLIGHT, TANK_TOP, F_DECK, f1_holes)
for j, (z0, z1) in enumerate([(-7.0, -3.0), (-2.0, 2.0), (3.0, 7.0)]):
    box("boiler_1_%d" % j, -25.2, -22.5, z0, z1, TANK_TOP, F_DECK - UPTAKE_CLEAR)
cx1 = (BR1[0] + BR1[1]) * 0.5
f1_holes.append((cx1 - FIDDLEY, cx1 + FIDDLEY, -FIDDLEY, FIDDLEY))
walled("stokehold_1", BR1[0], BR1[1], -BR1_PLATES, BR1_PLATES, TANK_TOP, F_DECK, "ps")
wall_x("stokehold_1_bunker", BR1[1], -BR1_PLATES, BR1_PLATES, TANK_TOP, F_DECK)
room("boiler_room_1", "boiler room 1", BR1[0], BR1[1], -BR1_PLATES, BR1_PLATES, TANK_TOP)
# Its bunker, through bulkhead J's vertical door (wtd_j) from boiler room 2, whose after
# wall it is; down two manholes in its floor side by side, the double bottom under both.
door_in("stokehold_2_aft", BX["J"], -STOKEHOLD_Z[2], STOKEHOLD_Z[2], TANK_TOP, F_DECK, 0.0)
walled("bunker_1", BR1[1], BX["J"], -BUNKER1_Z, BUNKER1_Z, TANK_TOP, F_DECK, "ps")
room("bunker_1", "coal bunker 1", BR1[1], BX["J"], -BUNKER1_Z, BUNKER1_Z, TANK_TOP)
# F deck over them, on through bulkhead J's door to the third-class saloons; a stair up
# from it into Scotland Road (stair_boiler_room_1_road stands for it); the fiddley's casing.
road_holes = []
stair("space_br1_road", -21.75, -18.5, -12.4, -11.0, F_DECK, E_DECK, road_holes)  # forward of sr_d
door_in("saloons_aft", BX["J"], -SALOON_Z, SALOON_Z, F_DECK, E_DECK, -6.0)
walled("f_br1", BR1[0], BX["J"], -BR1_Z, BR1_Z, F_DECK, E_DECK, "ps")
walled("casing_1", cx1 - FIDDLEY, cx1 + FIDDLEY, -FIDDLEY, FIDDLEY, F_DECK, E_DECK)
room("f_br1", "F deck working corridor, boiler room 1", BR1[0], BX["J"], -BR1_Z, BR1_Z, F_DECK)

# The engine room (S8d′1): its two engines (BOT: "two sets of four-cylinder reciprocating
# engines") as boxes either side of her centre line, est. 14 m long, an aisle down the
# middle and along each side, up to a quarter metre under the E deck over it, too near it
# for anybody to stand on one (as the boilers' boxes, above); its two flights up along its
# sides to E deck (the casing opening stands for them).
ENG = (BX["L"], BX["K"])
ENG_Z = fit(*ENG, ENGINE_TANK_TOP, 0.3)
e_holes, eng_holes = [], []
for tag, (z0, z1) in [("p", (-11.4, -10.0)), ("s", (10.0, 11.4))]:
    stair("space_engine_" + tag, -46.25, -32.0, z0, z1, ENGINE_TANK_TOP, E_DECK, e_holes)
for j, (z0, z1) in enumerate([(-9.0, -1.5), (1.5, 9.0)]):
    box("engine_%d" % j, -45.0, -31.0, z0, z1, ENGINE_TANK_TOP, E_DECK - UPTAKE_CLEAR)
room("engine_room", "engine room", *ENG, -ENG_Z, ENG_Z, ENGINE_TANK_TOP)
# The turbine engine room (S8d′2): its low-pressure turbine (BOT) on her centre line,
# est. 10 m long and 4 m across, up to under E deck as the engines are; two flights up
# along its sides to E deck.
TURB = (BX["M"], BX["L"])
TURB_Z = fit(*TURB, TANK_TOP, 0.3)
turb_holes = []
for tag, (z0, z1) in [("p", (-8.4, -7.0)), ("s", (7.0, 8.4))]:
    stair("space_turbine_" + tag, -64.5, -50.125, z0, z1, TANK_TOP, E_DECK, e_holes)
box("turbine", -62.0, -52.0, -2.0, 2.0, TANK_TOP, E_DECK - UPTAKE_CLEAR)
room("turbine_room", "turbine engine room", *TURB, -TURB_Z, TURB_Z, TANK_TOP)
# The electric engine room (BOT: "a separate watertight compartment ... at the level of
# the inner bottom"): its four generating sets as two boxes either side of her centre
# line (est.), up to under the G deck over them (est., its stores); two flights up to G
# deck (stair_electric_room stands for them), two on up to E deck.
ELEC = (BX["N"], BX["M"])
ELEC_Z = fit(*ELEC, TANK_TOP, 0.3)
ELEC_G = fit(*ELEC, G_DECK, 0.3)
elec_holes, elec_g_holes = [], []
# (The port flight up to E deck stands clear of D deck's after second-class stairway's
# flight down onto E deck, over it at z -2.875..-1.0625.)
for tag, sign, up in [("p", -1, (-4.4, -3.2)), ("s", 1, (2.0, 3.2))]:
    stair("space_electric_g_" + tag, -83.5, -75.0, *sorted((sign * 5.0, sign * 6.2)), TANK_TOP, G_DECK, elec_g_holes)
    stair("space_electric_e_" + tag, -70.0, -76.0, *up, G_DECK, E_DECK, e_holes)
for j, (z0, z1) in enumerate([(-4.0, -1.0), (1.0, 4.0)]):
    box("generators_%d" % j, -81.5, -69.5, z0, z1, TANK_TOP, G_DECK - UPTAKE_CLEAR)
room("electric_room", "electric engine room", *ELEC, -ELEC_Z, ELEC_Z, TANK_TOP)
room("electric_room_g", "G deck stores, electric room", *ELEC, -ELEC_G, ELEC_G, G_DECK)

# The after holds, deck by deck as No. 1 hold (above): two flights side by side from the
# tank top up through the watertight orlop deck, two up to G deck (their orlops' stair
# openings stand for them), two up to E deck. The after one narrows aft of AFT_HOLD with
# her run (est.), its decks on to bulkhead P, and on through it, each through a door at its
# floor as the forepeak's are, to the after peak's tank and its stores over it, up to D
# deck (D_PLAN).
AFT_HOLD = -110.0
AHF = (BX["O"], BX["N"])
AHA = (AFT_HOLD, BX["O"])
AHE = (BX["P"], AFT_HOLD)
AH_Z = {}
for hold, span in [("ahf", AHF), ("aha", AHA), ("ahe", AHE)]:
    AH_Z[hold] = {h: fit(*span, h, 0.3) for h in (TANK_TOP, ORLOP, G_DECK, E_DECK)}
ah_holes = {(hold, h): [] for hold in AH_Z for h in (TANK_TOP, ORLOP, G_DECK, E_DECK)}
for sid, foot, head, (z0, z1), low, high, hold in [
        ("space_ahf_or_1", -99.0, -93.375, (2.0, 3.0), TANK_TOP, ORLOP, "ahf"),
        ("space_ahf_or_2", -99.0, -93.375, (3.0, 4.0), TANK_TOP, ORLOP, "ahf"),
        ("space_ahf_g_1", -88.0, -91.0, (-3.0, -2.0), ORLOP, G_DECK, "ahf"),
        ("space_ahf_g_2", -88.0, -91.0, (-2.0, -1.0), ORLOP, G_DECK, "ahf"),
        ("space_ahf_e_1", -98.0, -92.0, (1.0, 2.0), G_DECK, E_DECK, "ahf"),
        ("space_ahf_e_2", -98.0, -92.0, (2.0, 3.0), G_DECK, E_DECK, "ahf"),
        ("space_aha_or_1", -109.0, -103.375, (-2.0, -1.0), TANK_TOP, ORLOP, "aha"),
        ("space_aha_or_2", -109.0, -103.375, (-1.0, 0.0), TANK_TOP, ORLOP, "aha"),
        ("space_aha_g_1", -104.0, -107.0, (0.5, 1.5), ORLOP, G_DECK, "aha"),
        ("space_aha_g_2", -104.0, -107.0, (1.5, 2.5), ORLOP, G_DECK, "aha"),
        ("space_aha_e_1", -109.0, -103.0, (-2.5, -1.5), G_DECK, E_DECK, "aha"),
        ("space_aha_e_2", -109.0, -103.0, (-1.5, -0.5), G_DECK, E_DECK, "aha")]:
    stair(sid, foot, head, z0, z1, low, high, e_holes if high == E_DECK else ah_holes[(hold, high)])
for hold, span, name, end in [("ahf", AHF, "after hold, forward", ""), ("aha", AHA, "after hold, aft", ""),
                               ("ahe", AHE, "after hold, aft", ", after end")]:
    widths = AH_Z[hold]
    for h, top, level in [(TANK_TOP, ORLOP, ""), (ORLOP, G_DECK, ", orlop"), (G_DECK, E_DECK, ", G deck")]:
        walled("%s_%d" % (hold, int(-h * 16)), *span, -widths[h], widths[h], h, top, "ps")
        room("%s_%d" % (hold, int(-h * 16)), name + level + end, *span, -widths[h], widths[h], h)
        if hold == "ahe":
            for tag, sign in [("p", -1), ("s", 1)]:
                step = sorted((sign * widths[h], sign * AH_Z["aha"][h]))
                wall_x("ahe_%d_step_%s" % (int(-h * 16), tag), AFT_HOLD, *step, h, min(top, E_DECK))
AFTER_PEAK = -122.0  # the after peak's spaces' after end, where her counter closes in (est.)
AP_TANK = fit(BX["P"] - 3.0, BX["P"], TANK_TOP, 0.3)
AP_STORES = fit(BX["P"] - 3.0, BX["P"], G_DECK, 0.45)  # inside her section there, coarser than her lines
for rid, name, h, w, top in [("after_peak_tank", "after peak tank", TANK_TOP, AP_TANK, G_DECK),
                             ("after_peak_stores", "after peak stores", G_DECK, AP_STORES, D_DECK)]:
    deck(rid, "tank top" if h == TANK_TOP else "G deck", AFTER_PEAK, BX["P"], -w, w, h, [])
    walled(rid, AFTER_PEAK, BX["P"], -w, w, h, top, "psa")
    room(rid, name, AFTER_PEAK, BX["P"], -w, w, h)
sealed_door("sealed_p_tank", "P", TANK_TOP, 0.0)
sealed_door("sealed_p_g", "P", G_DECK, 0.0)

# The double bottoms aft, crawl spaces as the bow's — but the engine room's, a foot deeper
# under its engines (SB-text), where a body stands — each down two manholes.
DB_AFT = [("db_br1", "boiler room 1 double bottom", BR1[0], BX["J"], TANK_TOP),
          ("db_engine", "engine room double bottom", *ENG, ENGINE_TANK_TOP),
          ("db_turbine", "turbine room double bottom", *TURB, TANK_TOP),
          ("db_electric", "electric room double bottom", *ELEC, TANK_TOP),
          ("db_ahf", "after hold, forward, double bottom", *AHF, TANK_TOP),
          ("db_aha", "after hold, aft, double bottom", *AHA, TANK_TOP)]
DB_AFT_Z = {rid: fit(x0, x1, KEEL, 0.3) for rid, _n, x0, x1, _t in DB_AFT}
# Bunker 1's two run across her, its floor too short along her for one.
for tag, sign in [("a", -1), ("b", 1)]:
    stair_z("space_dbbr1_" + tag, sign * 3.0, sign * 1.0, -19.4, -18.5, KEEL, TANK_TOP, bunker1_holes)
manholes_aft = [
    ("space_dbengine_a", -31.0, -28.75, (-5.0, -4.1), ENGINE_TANK_TOP, eng_holes),
    ("space_dbengine_b", -31.0, -28.75, (4.1, 5.0), ENGINE_TANK_TOP, eng_holes),
    ("space_dbturbine_a", -61.75, -64.0, (3.5, 4.4), TANK_TOP, turb_holes),
    ("space_dbturbine_b", -52.75, -50.5, (-4.4, -3.5), TANK_TOP, turb_holes),
    ("space_dbelectric_a", -81.75, -84.0, (-0.45, 0.45), TANK_TOP, elec_holes),
    ("space_dbelectric_b", -69.25, -67.0, (-0.45, 0.45), TANK_TOP, elec_holes),
    ("space_dbahf_a", -96.25, -98.5, (-2.0, -1.1), TANK_TOP, ah_holes[("ahf", TANK_TOP)]),
    ("space_dbahf_b", -94.25, -92.0, (-2.0, -1.1), TANK_TOP, ah_holes[("ahf", TANK_TOP)]),
    ("space_dbaha_a", -108.75, -106.5, (0.5, 1.4), TANK_TOP, ah_holes[("aha", TANK_TOP)]),
    ("space_dbaha_b", -105.0, -102.75, (0.5, 1.4), TANK_TOP, ah_holes[("aha", TANK_TOP)])]
for sid, foot, head, (z0, z1), top, holes_above in manholes_aft:
    stair(sid, foot, head, z0, z1, KEEL, top, holes_above)
for rid, name, x0, x1, top in DB_AFT:
    w = DB_AFT_Z[rid]
    deck(rid, "double bottom", x0, x1, -w, w, KEEL, [])
    walled(rid, x0, x1, -w, w, KEEL, top, "ps")
    room(rid, name, x0, x1, -w, w, KEEL, crawl_space=top - KEEL < rule("body_height"))
for letter, at, bands in [
        ("j", BX["J"], [(KEEL, TANK_TOP, DB_AFT_Z["db_br1"])]),
        ("k", BX["K"], [(KEEL, ENGINE_TANK_TOP, DB_AFT_Z["db_br1"])]),
        ("l", BX["L"], [(KEEL, ENGINE_TANK_TOP, DB_AFT_Z["db_engine"])]),
        ("m", BX["M"], [(KEEL, TANK_TOP, DB_AFT_Z["db_turbine"])]),
        ("n", BX["N"], [(KEEL, TANK_TOP, DB_AFT_Z["db_electric"])]),
        ("o", BX["O"], [(KEEL, TANK_TOP, DB_AFT_Z["db_ahf"])]),
        ("aft_hold", AFT_HOLD, [(KEEL, TANK_TOP, DB_AFT_Z["db_aha"])])]:
    bulkhead_wall("db_" + letter, at, bands)

# The working passage along E deck aft, a room for each compartment it runs through, over
# the engine and turbine rooms' casings (their openings stand for the shafts the machinery
# fills under it), and on aft over her after holds to bulkhead P, where D deck's
# third-class stairway comes down (D_PLAN); its two stairs up to D deck, the first into the
# galley, the second into the second-class pantry (stair_engine_room_tween and
# stair_turbine_room_tween stand for them).
E_AFT = [("e_engine", "E deck working passage, engine room", *ENG),
         ("e_turbine", "E deck working passage, turbine room", *TURB),
         ("e_electric", "E deck working passage, electric room", *ELEC),
         ("e_ahf", "E deck working passage, after hold, forward", *AHF),
         ("e_aha", "E deck working passage, after hold, aft", *AHA),
         ("e_ahe", "E deck working passage, after hold, after end", *AHE)]
# Each as wide as her hull lets it be, and no wider than D deck over it (as the boiler
# rooms are held to the F deck over them).
def roofed(x0, x1):
    """D deck's half breadth over x0..x1, its narrowest strip there, less a wall's half."""
    return min(min(-z0, z1) for p0, p1, z0, z1 in D_PIECES if p0 < x1 and p1 > x0) - T

E_AFT_Z = {rid: min(fit(x0, x1, E_DECK, 0.3), roofed(x0, x1)) for rid, _n, x0, x1 in E_AFT}
d_aft_holes = []
stair("space_e_d_engine", -47.6, -44.35, -NARROW_STAIR * 0.5, NARROW_STAIR * 0.5, E_DECK, D_DECK, d_aft_holes)
stair("space_e_d_turbine", -61.75, -58.5, -1.45, -0.05, E_DECK, D_DECK, d_aft_holes)
e_aft = []
for rid, name, x0, x1 in E_AFT:
    w = E_AFT_Z[rid]
    # The engine room's short of bulkhead K, as boiler room 1's F deck is (above).
    e_aft += deck(rid, "E deck", x0, x1 - 2 * T if rid == "e_engine" else x1, -w, w, E_DECK, e_holes)
    walled(rid, x0, x1, -w, w, E_DECK, D_DECK, "ps")
    room(rid, name, x0, x1, -w, w, E_DECK)
bulkhead_wall("aft_p", BX["P"], [(TANK_TOP, ORLOP, AH_Z["ahe"][TANK_TOP]), (ORLOP, G_DECK, AH_Z["ahe"][ORLOP]),
                                 (G_DECK, E_DECK, max(AH_Z["ahe"][G_DECK], AP_STORES)),
                                 (E_DECK, D_DECK, max(E_AFT_Z["e_ahe"], AP_STORES))], [(0.0, TANK_TOP), (0.0, G_DECK)])

# Her compartments' floors aft, touching end to end through her bulkheads' walls: boiler
# room 1's plates and its bunker's, the engine room's plates, the turbine and electric
# rooms', the after holds' tank tops, orlops and G decks.
br1_plates = deck("stokehold_1", "tank top", BR1[0], BR1[1], -BR1_PLATES, BR1_PLATES, TANK_TOP, [])
bunker1_floor = deck("bunker_1", "tank top", BR1[1], BX["J"] + T, -BUNKER1_Z, BUNKER1_Z, TANK_TOP, bunker1_holes)
# F deck from its flights' after side: ended at bulkhead K over the engine room's floor it
# would read as a break in her decks (ShipFittings.breaks), a weather door in its face.
f1 = deck("f_br1", "F deck", BR1_FLIGHT[0], BX["J"], -BR1_Z, BR1_Z, F_DECK, f1_holes)
eng_plates = deck("engine_room", "engine room floor", *ENG, -ENG_Z, ENG_Z, ENGINE_TANK_TOP, eng_holes)
turb_plates = deck("turbine_room", "tank top", *TURB, -TURB_Z, TURB_Z, TANK_TOP, turb_holes)
elec_plates = deck("electric_room", "tank top", *ELEC, -ELEC_Z, ELEC_Z, TANK_TOP, elec_holes)
elec_g = deck("electric_room_g", "G deck", *ELEC, -ELEC_G, ELEC_G, G_DECK, elec_g_holes)
ah_decks = {}
for hold, span in [("ahf", AHF), ("aha", AHA), ("ahe", AHE)]:
    for h, name in [(TANK_TOP, "tank top"), (ORLOP, "orlop deck"), (G_DECK, "G deck")]:
        ah_decks[(hold, h)] = deck("%s_%d" % (hold, int(-h * 16)), name, *span, -AH_Z[hold][h], AH_Z[hold][h], h,
                                   ah_holes[(hold, h)])
walled("engine_room", *ENG, -ENG_Z, ENG_Z, ENGINE_TANK_TOP, E_DECK, "ps")
walled("turbine_room", *TURB, -TURB_Z, TURB_Z, TANK_TOP, E_DECK, "ps")
walled("electric_room", *ELEC, -ELEC_Z, ELEC_Z, TANK_TOP, G_DECK, "ps")
walled("electric_room_g", *ELEC, -ELEC_G, ELEC_G, G_DECK, E_DECK, "ps")
# Her bulkheads aft across each deck, as wide as the wider room either side; the E deck
# doors through L to O.
for letter, at, bands in [
        ("k", BX["K"], [(TANK_TOP, F_DECK, BR1_Z), (F_DECK, E_DECK, BR1_Z), (E_DECK, D_DECK, E_AFT_Z["e_engine"])]),
        ("l", BX["L"], [(TANK_TOP, E_DECK, ENG_Z), (E_DECK, D_DECK, E_AFT_Z["e_engine"])]),
        ("m", BX["M"], [(TANK_TOP, E_DECK, TURB_Z), (E_DECK, D_DECK, E_AFT_Z["e_turbine"])]),
        ("n", BX["N"], [(TANK_TOP, G_DECK, ELEC_Z), (G_DECK, E_DECK, ELEC_G), (E_DECK, D_DECK, E_AFT_Z["e_electric"])]),
        ("o", BX["O"], [(TANK_TOP, ORLOP, AH_Z["ahf"][TANK_TOP]), (ORLOP, G_DECK, AH_Z["ahf"][ORLOP]),
                        (G_DECK, E_DECK, AH_Z["ahf"][G_DECK]), (E_DECK, D_DECK, E_AFT_Z["e_ahf"])]),
        ("aft_hold", AFT_HOLD, [(E_DECK, D_DECK, max(E_AFT_Z["e_aha"], E_AFT_Z["e_ahe"]))])]:
    # Bulkhead O's door a half metre inboard of the others, the after hold's passage there
    # narrower than they: as wide, the same door (wtd_e_o).
    bulkhead_wall("aft_" + letter, at, bands, [(-5.5 if letter == "o" else -6.0, E_DECK)] if letter in "lmno" else [])
# D deck cut for the passage's two stairs up and No. 1 hold's, and Scotland Road for
# boiler room 1's.
d_deck = split(d_deck, "d_late", "D deck", D_DECK, d_aft_holes + h1d_holes)
e_road = split(e_road, "e_road", "E deck", E_DECK, road_holes)

for decks, sids in [(f1, []),
                    (eng_plates, ["space_dbengine_a", "space_dbengine_b"]),
                    (turb_plates, ["space_dbturbine_a", "space_dbturbine_b"]),
                    (elec_plates, ["space_dbelectric_a", "space_dbelectric_b"]),
                    (elec_g, ["space_electric_g_p", "space_electric_g_s"]),
                    (ah_decks[("ahf", TANK_TOP)], ["space_dbahf_a", "space_dbahf_b"]),
                    (ah_decks[("aha", TANK_TOP)], ["space_dbaha_a", "space_dbaha_b"]),
                    (ah_decks[("ahf", ORLOP)], ["space_ahf_or_1", "space_ahf_or_2"]),
                    (ah_decks[("aha", ORLOP)], ["space_aha_or_1", "space_aha_or_2"]),
                    (ah_decks[("ahf", G_DECK)], ["space_ahf_g_1", "space_ahf_g_2"]),
                    (ah_decks[("aha", G_DECK)], ["space_aha_g_1", "space_aha_g_2"]),
                    (e_aft, ["space_engine_p", "space_engine_s", "space_turbine_p", "space_turbine_s",
                             "space_electric_e_p", "space_electric_e_s", "space_ahf_e_1", "space_ahf_e_2",
                             "space_aha_e_1", "space_aha_e_2"]),
                    (d_deck, ["space_e_d_engine", "space_e_d_turbine", "space_h1_d", "space_h1_d_2"]), (e_road, ["space_br1_road"])]:
    for sid in sids:
        hole_rails(decks, sid)
for sid in ("space_br1_p", "space_br1_s"):
    hole_rails_z(f1, sid)
for sid in ("space_dbbr1_a", "space_dbbr1_b"):
    hole_rails_z(bunker1_floor, sid)

# --- Every cell a place a body can be (#148), amidships: the cross bunkers of boiler rooms
# 2 to 5, each through the vertical door in the bulkhead forward of it from the next room,
# its floor run on from the plates to that room's; and the
# double bottoms under those rooms, crawl spaces down two manholes in their bunkers' floors,
# across her as bunker 1's are.
MID_ROOMS = {2: (BX["J"], BX["H"]), 3: (BX["H"], BX["G"]), 4: (BX["G"], BX["F"]), 5: (BX["F"], BX["E"])}
DB_MID_Z = {k: fit(*MID_ROOMS[k], KEEL, 0.3) for k in MID_ROOMS}
DB_MID_Z[1] = DB_AFT_Z["db_br1"]
for k in (2, 3, 4, 5):
    bunker, fwd = BUNKERS["br%d" % k], MID_ROOMS[k][1]
    w = STOKEHOLD_Z[k]
    wb = min(fit(bunker, fwd, TANK_TOP, 0.3), w, STOKEHOLD_Z.get(k + 1, BR6_Z))
    # Through the vertical door in the bulkhead forward of it (wtd_h, wtd_g, wtd_f), from the
    # next room; boiler room 6's own (above).
    if k < 5:
        door_in("stokehold_%d_aft" % (k + 1), fwd, -STOKEHOLD_Z[k + 1], STOKEHOLD_Z[k + 1], TANK_TOP, F_DECK, 0.0)
    walled("bunker_%d" % k, bunker, fwd, -wb, wb, TANK_TOP, F_DECK, "ps")
    room("bunker_%d" % k, "coal bunker %d" % k, bunker, fwd, -wb, wb, TANK_TOP)
    holes_k = []
    for tag, sign in [("a", -1), ("b", 1)]:
        stair_z("space_dbbr%d_%s" % (k, tag), sign * 6.0, sign * 4.0, bunker + 0.9, bunker + 1.8, KEEL, TANK_TOP,
                holes_k)
    # On to boiler room 6's plates, which start at bulkhead E; the others' a wall's half on.
    floor_k = deck("bunker_%d" % k, "tank top", bunker - T, fwd + (T if k < 5 else 0.0), -wb, wb, TANK_TOP, holes_k)
    for tag in ("a", "b"):
        hole_rails_z(floor_k, "space_dbbr%d_%s" % (k, tag))
    aft = MID_ROOMS[k][0]
    wd = DB_MID_Z[k]
    deck("db_br%d" % k, "double bottom", aft, fwd, -wd, wd, KEEL, [])
    walled("db_br%d" % k, aft, fwd, -wd, wd, KEEL, TANK_TOP, "ps")
    room("db_br%d" % k, "boiler room %d double bottom" % k, aft, fwd, -wd, wd, KEEL,
         crawl_space=TANK_TOP - KEEL < rule("body_height"))
    # Its after end's watertight floor as wide as the wider double bottom either side
    # (boiler room 1's, bulkhead J's, above).
    if k > 2:
        w_ends = max(wd, DB_MID_Z[k - 1])
        wall_x("db_%s" % next(b[0] for b in BULKHEADS if b[1] == aft).lower(), aft, -w_ends, w_ends, KEEL, TANK_TOP)
# Bulkhead E's in the double bottom out to boiler room 5's, wider than boiler room 6's.
for tag, sign in [("p", -1), ("s", 1)]:
    box("db_e_" + tag, BX["E"] - T, BX["E"] + T, *sorted((sign * (DB6_Z + T), sign * (DB_MID_Z[5] + T))), KEEL,
        TANK_TOP)

# Every wall a flight comes down over cut to the flight's underside there, and every lintel
# it comes down through, the deck it lands on drawn whole by the plates under it (est.):
# C deck's crew's stairs over D deck's firemen's landing's after wall (d.py, #369), C
# deck's third-class stairway through D deck's matron's doors, No. 1 hold's flight over
# its G deck's step, the E landings' walls. A wall under a flight along it is cut in steps
# CUT_STEP long, each to the flight's underside over it.
CUT_STEP = 0.5
SLIVER = 0.1
BODY_HEIGHT = rule("body_height")

def under_flights():
    def height(ramp, v):
        rx0, rx1, rz0, rz1, axis, start, end = ramp
        a, b = (rx0, rx1) if axis == 0 else (rz0, rz1)
        return start + (end - start) * (min(max(v, a), b) - a) / (b - a)

    def conflict():
        for i, (bx0, bx1, bz0, bz1, foot, top, is_box) in enumerate(block_geo):
            if not is_box or min(bx1 - bx0, bz1 - bz0) > 0.3:
                continue
            for ramp in ramp_geo:
                rx0, rx1, rz0, rz1, axis, start, end = ramp
                ox0, ox1, oz0, oz1 = max(bx0, rx0), min(bx1, rx1), max(bz0, rz0), min(bz1, rz1)
                if ox1 - ox0 < 1e-3 or oz1 - oz0 < 1e-3:
                    continue
                lo, hi = (ox0, ox1) if axis == 0 else (oz0, oz1)
                under = min(height(ramp, lo), height(ramp, hi))
                over = max(height(ramp, lo), height(ramp, hi))
                # A wall standing on the deck the flight comes down to, or a lintel over a
                # door it comes down through: up through it from under it — or a lintel over
                # it where a body on it puts its head.
                if (foot < under - 0.01 and top > under + 1e-3) or (
                        "_lintel_" in blockers[i] and under - 0.01 <= foot < over + BODY_HEIGHT):
                    return i, ramp, (ox0, ox1, oz0, oz1)
        return None

    found = conflict()
    while found:
        i, ramp, (ox0, ox1, oz0, oz1) = found
        bx0, bx1, bz0, bz1, foot, top, _is_box = block_geo[i]
        bid = blockers[i][len("Blocker_"):]
        along_x = bx1 - bx0 >= bz1 - bz0
        lo, hi, o0, o1 = (bx0, bx1, ox0, ox1) if along_x else (bz0, bz1, oz0, oz1)
        parts = [(lo, o0, top), (o1, hi, top)]
        lintel = "_lintel_" in blockers[i] and foot >= min(height(ramp, ox0 if ramp[4] == 0 else oz0),
                                                         height(ramp, ox1 if ramp[4] == 0 else oz1)) - 0.01
        steps = 0 if lintel else max(1, math.ceil((o1 - o0) / CUT_STEP - 1e-9)) if along_x == (ramp[4] == 0) else 1
        for k in range(steps):
            a, b = lerp(o0, o1, k / steps), lerp(o0, o1, (k + 1) / steps)
            if along_x == (ramp[4] == 0):
                under = min(height(ramp, a), height(ramp, b))
            else:
                under = min(height(ramp, ox0 if ramp[4] == 0 else oz0), height(ramp, ox1 if ramp[4] == 0 else oz1))
            parts.append((a, b, round(under - 0.01, 4)))
        # (What is left over C deck of a wall by a flight under SLIVER long is no wall: under
        # it, a gap at a wall's foot would read as a door.)
        parts = [(a, b, t) for a, b, t in parts
                 if b - a > (SLIVER if foot >= 0.0 else 0.005) and t - foot > 0.05]
        # Each piece a hair past the next where they meet, so no gap opens between them
        # where single precision rounds their ends (the layout lint's doors).
        parts.sort()
        parts = [(a, b + (0.0005 if any(abs(b - c) < 1e-9 for c, _d, _t in parts) else 0.0), t)
                 for a, b, t in parts]
        for k, (a, b, t) in enumerate(parts):
            area = (a, b, bz0, bz1) if along_x else (bx0, bx1, a, b)
            if k == 0:
                relay_box(bid, *area, foot, t)
            else:
                box("%s_u%d" % (bid, sum(1 for name in blockers if name.startswith("Blocker_%s_u" % bid))),
                    *area, foot, t)
        if not parts:
            relay_box(bid, bx0, bx1, bz0, bz1, foot, foot + 0.05)
        found = conflict()

under_flights()

def free_stretches(lo, hi, cuts, least):
    """The stretches of lo…hi no cut [(from, to)] falls in, each at least least long."""
    spans, at = [], lo
    for c0, c1 in sorted(cuts):
        if c0 > at:
            spans.append((at, c0))
        at = max(at, c1)
    if at < hi:
        spans.append((at, hi))
    return [(a, b) for a, b in spans if b - a >= least]

def clear_of(x0, x1, z0, z1, foot, top, lane):
    """Whether a box x0…x1, z0…z1 from foot to top keeps lane clear of every blocker
    standing there, every room on that floor and every stair at it."""
    for b in block_geo:
        if b[4] < top and b[5] > foot and b[0] < x1 + lane and b[1] > x0 - lane and b[2] < z1 + lane and b[3] > z0 - lane:
            return False
    for r in room_geo:
        if abs(r[4] - foot) < 0.01 and r[0] < x1 + lane and r[1] > x0 - lane and r[2] < z1 + lane and r[3] > z0 - lane:
            return False
    for r in ramp_geo:
        if (min(r[5], r[6]) - 0.01 <= foot <= max(r[5], r[6]) + 0.01
                and r[0] < x1 + lane and r[1] > x0 - lane and r[2] < z1 + lane and r[3] > z0 - lane):
            return False
    return True

# --- The boat deck's gear (SB-III, est.), after every other platform, blocker and room so
# none of theirs moves, each drawn as its shape says (DeckFurniture). Along the officers'
# house and the staircase house outside, seat lockers — the lifejacket boxes her
# passengers sat on —, a step and a half up, in each stretch of wall clear of its doors by
# a metre and of her winches and stairs.
SEAT_LOCKER = (0.5, 0.45)  # out from its house's wall, and tall
SEAT_LOCKER_LONGEST = 3.5
for house in ("officers_house", "staircase_house"):
    _name, hx0, hx1, hz0, hz1 = next(h for h in BOAT_PLAN.houses if h[0] == house)
    for tag, sign, line in [("p", -1, hz0), ("s", 1, hz1)]:
        face = line + sign * T
        z0, z1 = sorted((face, face + sign * SEAT_LOCKER[0]))
        cuts = [(d[2] - 1.0, d[3] + 1.0) for d in doorways
                if d[0] == 2 and abs(d[1] - line) < 1e-6 and abs(d[4] - BOAT) < 1e-6]
        for k, (a, b) in enumerate(free_stretches(hx0 + 0.5, hx1 - 0.5, cuts, 2.0)):
            length = min(SEAT_LOCKER_LONGEST, b - a - 0.2)
            x0 = round((a + b - length) / 2, 4)
            if clear_of(x0, x0 + length, z0, z1, BOAT, BOAT + SEAT_LOCKER[1], 0.3):
                box("seat_locker_%s_%d_%s" % (house, k, tag), x0, round(x0 + length, 4), z0, z1, BOAT,
                    BOAT + SEAT_LOCKER[1])

# --- Her open decks' gear (SB-III, est.), after every other platform, blocker and room so
# none of theirs moves, each drawn as its shape and where it stands say (DeckFurniture).
# Her boats stowed on chocks under their davits, as she carried them (BOT), one at each
# boat station along her boat deck's edges (DAVITS, her LIFEBOAT fittings below): a box
# from the deck's edge in — the edge of the strip of it laid under the boat, which the
# art stows it by —, as long as the boat over its stems and as tall as its gunwale over
# its chocks. Bodies are held off a boat as off a house, and none jumps up onto one.
for k, x in enumerate(DAVITS):
    edge = next(z1 for x0, x1, z0, z1 in BOAT_PIECES if x0 <= x <= x1 and z0 == -z1)
    for number, sign in [(2 * k + 1, 1), (2 * k + 2, -1)]:
        box("stowed_boat_%d" % number, x - STOWED_BOAT[0] / 2, x + STOWED_BOAT[0] / 2,
            *sorted((sign * edge, sign * (edge - STOWED_BOAT[1]))), BOAT, BOAT + STOWED_BOAT[2])
# Her ventilators, each a trunk this round up to its cowl or its cap and this tall over its
# deck (DeckFurniture.VENTS): big cowls abreast her funnels and on her forecastle, smaller
# ones on her well decks and her poop, each with a lane a body wide round it. On the boat
# deck a cowl stands abreast its funnel where her houses and raised roofs leave it room
# (est.), nearer first; none where the plate's houses stand.
VENTS = {0.45: 3.4, 0.3: 2.5, 0.25: 0.8}
VENT_LANE = 0.8
DECK_VENTS = []
for k, x in enumerate(FUNNELS[1:], 2):
    for sign in (-1, 1):
        for z in (5.6, 8.6):
            if clear_of(x - 0.45, x + 0.45, sign * z - 0.45, sign * z + 0.45, BOAT, BOAT + VENTS[0.45], VENT_LANE):
                DECK_VENTS.append(("funnel_%d" % k, x, sign * z, 0.45, BOAT))
                break
DECK_VENTS += [(name, x, sign * z, r, deck) for name, x, z, r, deck in [
    ("forecastle", 93.0, 6.0, 0.45, FCSL[0]), ("forward_well", 88.0, 7.0, 0.3, 0.0),
    ("after_well", -100.5, 5.5, 0.3, 0.0), ("poop", -112.0, 5.0, 0.3, POOP)] for sign in (-1, 1)]
for name, x, z, r, foot in DECK_VENTS:
    side = "" if z == 0.0 else ("_s" if z > 0.0 else "_p")
    cylinder("vent_%s%s" % (name, side), x, z, r, foot, foot + VENTS[r])
# Benches, teak seats with low backs, BENCH long, deep and tall, each backed onto what
# stands behind it: along A deck's house on both its promenades between its doors, a bench
# every BENCH_PITCH.
BENCH = (1.8, 0.55, 0.45)
BENCH_PITCH = 9.0

def door_near(axis, at, a, b, floor, clear):
    """Whether a doorway of the wall along axis at lies within clear of a…b on floor."""
    return any(d[0] == axis and abs(d[1] - at) < 1e-6 and abs(d[4] - floor) < 1e-6
               and d[2] - clear < b and a < d[3] + clear for d in doorways)

# A deck's house, between its promenades: from its aftermost room to its foremost, as far
# out as its rooms reach either side.
A_HOUSE = (min(r[1] for r in A_PLAN.rooms), max(r[2] for r in A_PLAN.rooms),
           max(max(-r[3], r[4]) for r in A_PLAN.rooms))

def house_face(x0, x1, sign):
    """The face of A deck's house on side sign along x0…x1, a room's wall or a block's
    side, from one blocker standing there over a bench's height; None for none."""
    faces = [b[3] if sign > 0 else -b[2] for b in block_geo
             if b[6] and b[4] <= A_DECK + 1e-6 and b[5] >= A_DECK + BENCH[2] and b[0] <= x0 and x1 <= b[1]
             and 0.0 < (b[3] if sign > 0 else -b[2]) <= A_HOUSE[2] + T + 1e-6]
    return max(faces) if faces else None

STAIR_CLEAR = 0.8  # a bench's end from a stair's
A_BENCHES = []
for k in range(int((A_HOUSE[1] - A_HOUSE[0]) // BENCH_PITCH)):
    x0 = A_HOUSE[0] + 1.0 + k * BENCH_PITCH
    x1 = x0 + BENCH[0]
    if x1 > A_HOUSE[1] - 1.0:
        break
    for tag, sign in [("p", -1), ("s", 1)]:
        face = house_face(x0, x1, sign)
        if face is None or door_near(2, sign * (face - T), x0, x1, A_DECK, 1.0):
            continue
        z0, z1 = sorted((sign * face, sign * (face + BENCH[1])))
        if not clear_of(x0, x1, z0, z1, A_DECK, A_DECK + BENCH[2], 0.1) or any(
                r[0] - STAIR_CLEAR < x1 and x0 < r[1] + STAIR_CLEAR and r[2] < z1 and z0 < r[3] for r in ramp_geo
                if max(r[5], r[6]) >= A_DECK - 0.01 and min(r[5], r[6]) <= A_DECK + 0.01):
            continue
        A_BENCHES.append(("bench_a_%d_%s" % (k, tag), x0, x1, z0, z1))
for bid, x0, x1, z0, z1 in A_BENCHES:
    box(bid, x0, x1, z0, z1, A_DECK, A_DECK + BENCH[2])

# Sixteen seats across her decks (SH21 takes more): six on the boat deck and one on her
# bridge, two on A deck's promenade, one on B deck's second-class promenade aft, one on
# each well deck, the forecastle and the poop, one in the first-class dining saloon, facing
# forward to the grand staircase's foot.
spawns = [
    (60.0, BOAT, 9.5), (60.0, BOAT, -9.5), (5.0, BOAT, 9.5), (5.0, BOAT, -9.5), (-40.0, BOAT, 9.5),
    (-40.0, BOAT, -9.5), (69.0, BOAT, 0.0), (-77.0, BOAT, 0.0),
    (45.0, A_DECK, 11.5), (-20.0, A_DECK, -11.5), (-80.0, B_DECK, 11.5),
    (82.0, 0.0, 8.0), (-100.0, 0.0, -6.0), (100.0, FCSL[0], 0.0), (-115.0, POOP, 0.0),
    (-6.0, D_DECK, 1.0),
]
# --- Her public rooms' furniture (SB-IV, est.), after every other platform, blocker and
# room so none of theirs moves, each drawn as its shape and its room say
# (FurnitureDressing): club chairs round the first-class smoking room's card tables; a
# settee on each stretch of the lounge's side walls, a table and two armchairs before it;
# writing desks along the reading and writing room's forward wall, each with its chair,
# and a settee either side of its after door; wicker tables and chairs in the verandah
# café and the reception room; and settees on the after entrance's forward wall. Every
# piece keeps clear the lanes 1.5 m either side of a room's centre lines between its
# doors, a doorway by DOOR_CLEAR, a stair by STAIR_CLEAR before its ends and 0.5 m beside
# it, a wall by 0.5 m but for a seat's back against it, a pendant by 1.0 m in plan (a
# table) and every seat's start (room_piece_problems()).
ARMCHAIR = 0.8  # FurnitureDressing.ARMCHAIR: square, its seat SEAT_TOP over its floor
SETTEE = (2.0, 0.8)  # FurnitureDressing.SETTEE: long and deep
SEAT_TOP = 0.45
CHAIR_GAP = 0.15  # between a table and a chair at it
DESK = (1.2, 0.65, 0.76)  # a writing desk: long, deep and tall
DOOR_CLEAR = 1.5
ROOM_PIECES = []  # (bid, x0, x1, z0, z1, floor, top)

def piece(bid, x0, x1, z0, z1, floor, top):
    ROOM_PIECES.append((bid, x0, x1, z0, z1, floor, top))

def armchair(bid, x, z, floor):
    h = ARMCHAIR / 2
    piece("armchair_" + bid, x - h, x + h, z - h, z + h, floor, floor + SEAT_TOP)

def settee(bid, x, z, floor, along_x=True):
    hx, hz = (SETTEE[0] / 2, SETTEE[1] / 2) if along_x else (SETTEE[1] / 2, SETTEE[0] / 2)
    piece("settee_" + bid, x - hx, x + hx, z - hz, z + hz, floor, floor + SEAT_TOP)

def table_group(gid, x, z, floor, half, top, sides=("px", "mx", "pz", "mz")):
    """A table half each way round (x, z), top over its floor, with an armchair
    CHAIR_GAP off each of its sides named (px its +x side, mz its -z side…)."""
    piece("table_" + gid, x - half, x + half, z - half, z + half, floor, floor + top)
    off = half + CHAIR_GAP + ARMCHAIR / 2
    for s in sides:
        sign = 1.0 if s[0] == "p" else -1.0
        armchair("%s_%s" % (gid, s), x + (sign * off if s[1] == "x" else 0.0), z + (sign * off if s[1] == "z" else 0.0),
                 floor)

# A deck's rooms are furnished below, where each piece is tried and kept only if it keeps
# every rule (A_FURNITURE).

# Her crew's rooms and working spaces (SB-IV, est.): mess tables in the seamen's quarters
# under the forecastle and in the crew quarters on E deck — a bench along each long side
# of each inside its box (LinerDining.mess_table) — between their pendants and clear of
# the lanes from their doors; and her stores stacked along the side walls of her E deck
# working passages, stowed crates two high (FurnitureDressing.stores), STORES_OFF off
# the wall, clear of its handrail, wherever a stack keeps to the rules above.
MESS = (4.0, 1.2, 0.75)  # a mess table: long, deep with its benches, tall
for k, (x0, z0, floor) in enumerate([(74.5, 1.7, E_DECK), (74.5, -2.9, E_DECK)]):
    piece("table_mess_%d" % (k + 2), x0, x0 + MESS[0], z0, z0 + MESS[1], floor, floor + MESS[2])
STORES = (1.4, 0.7, 1.19)  # a stack of stores: long, deep and tall, 0.7 m crates two high,
# no taller than furniture (ShipSpace.FURNITURE_HEIGHT), past which a box is machinery
STORES_OFF = 0.15
STORES_PITCH = 3.2


# What the art hangs over a room's floor and the ways a body takes into it, as the art
# reads them (test_public_room_furniture, art-lint): a pendant under the middle of each
# LAMP_SPACING square of a room (RoomDressing.lights), and in a café a basket under the
# middle of each BASKET_PITCH square of it a metre in from its sides, but one by a
# pendant (LinerPublic); and a body's breadth into a room through each gap in its sides
# that leads somewhere (ShipRoom.doors), a body's breadth past either end. A table stands
# PENDANT_CLEAR off a pendant, and BASKET_CLEAR off a basket — a body standing on it
# would stand in it: its radius and a basket's spread (LinerPublic.BASKET_SPREAD) — and
# no piece in a way in.
LAMP_SPACING = 12.0
BASKET_PITCH = 3.0
PENDANT_CLEAR = 1.0
BASKET_CLEAR = 0.7
BODY = (0.4, 1.7, 0.35)  # a body's radius, height and step (BrawlRules)


def squares(lo, hi, side, whole):
    """The middles of the squares of side the stretch lo..hi is cut into: as many as it
    holds whole (ceil) or to the nearest (round), at least one."""
    count = max(1, math.ceil((hi - lo) / side - 1e-9) if whole else math.floor((hi - lo) / side + 0.5))
    return [lo + (hi - lo) * (k + 0.5) / count for k in range(count)]


def hung_over(room):
    """Where the art hangs a pendant or a basket over room's floor, ship plane, and how
    far off it a table stands: (x, z, clear)."""
    x0, x1, z0, z1, _floor, name = room
    lamps = [(x, z) for x in squares(x0, x1, LAMP_SPACING, True) for z in squares(z0, z1, LAMP_SPACING, True)]
    baskets = []
    if "café" in name:
        baskets = [(x, z) for x in squares(x0 + 1.0, x1 - 1.0, BASKET_PITCH, False)
                   for z in squares(z0 + 1.0, z1 - 1.0, BASKET_PITCH, False)
                   if all(math.hypot(x - lx, z - lz) >= 1.0 for lx, lz in lamps)]
    return [(x, z, PENDANT_CLEAR) for x, z in lamps] + [(x, z, BASKET_CLEAR) for x, z in baskets]


_WAYS = {}

def ways_in(room):
    """The strips (x0, x1, z0, z1) a body takes into room through each gap in its sides."""
    key = (room, len(block_geo))
    if key not in _WAYS:
        _WAYS[key] = _ways_in(room)
    return _WAYS[key]


def _ways_in(room):
    x0, x1, z0, z1, floor, _name = room
    breadth = 2 * BODY[0]
    found = []
    for axis, at, lo, hi, out in [(2, z0, x0, x1, -1), (0, x1, z0, z1, 1), (2, z1, x0, x1, 1), (0, x0, z0, z1, -1)]:
        cuts = []
        for b in block_geo:
            if not (floor + BODY[2] < b[5] and floor + BODY[1] > b[4]):
                continue
            a0, a1, s0, s1 = (b[2], b[3], b[0], b[1]) if axis == 0 else (b[0], b[1], b[2], b[3])
            if s0 <= at <= s1 and a0 <= hi and a1 >= lo:
                cuts.append((max(a0, lo), min(a1, hi)))
        reached = lo
        for c0, c1 in sorted(cuts) + [(hi, hi)]:
            if c0 > reached:
                mid, beyond = (reached + c0) / 2, at + out * breadth
                ox, oz = (beyond, mid) if axis == 0 else (mid, beyond)
                if not any(b[6] and b[0] <= ox <= b[1] and b[2] <= oz <= b[3] and b[4] <= floor + BODY[2]
                           and b[5] >= floor + 0.6 for b in block_geo):
                    inside = sorted((at, at - out * breadth))
                    found.append((inside[0], inside[1], reached - breadth, c0 + breadth) if axis == 0
                                 else (reached - breadth, c0 + breadth, inside[0], inside[1]))
            reached = max(reached, c1)
    return found


_ABOUT = {}

def blocks_about(floor):
    """The blockers standing anywhere from floor to a deck's height over it."""
    key = (floor, len(block_geo))
    if key not in _ABOUT:
        _ABOUT[key] = [b[:6] for b in block_geo if b[4] < floor + 3.5 and b[5] > floor]
    return _ABOUT[key]


def piece_problems(candidate):
    """Every way a room's piece breaks the rules above: out of its room, by a doorway or
    a stair, in a way in, a table under what hangs, on another blocker or another piece,
    or by a seat's start."""
    bid, x0, x1, z0, z1, floor, top = candidate
    found = []
    rooms_there = [r for r in room_geo if abs(r[4] - floor) < 1e-6 and r[0] <= x0 and x1 <= r[1]
                   and r[2] <= z0 and z1 <= r[3]]
    if not rooms_there:
        found.append("%s stands in no room" % bid)
    for room in rooms_there:
        for wx0, wx1, wz0, wz1 in ways_in(room):
            if x0 < wx1 + 1e-3 and wx0 < x1 + 1e-3 and z0 < wz1 + 1e-3 and wz0 < z1 + 1e-3:
                found.append("%s in a way into %s at %s" % (bid, room[5], (wx0, wx1, wz0, wz1)))
        if bid.startswith("table_"):
            for hx, hz, clear in hung_over(room):
                if math.hypot(max(x0 - hx, 0.0, hx - x1), max(z0 - hz, 0.0, hz - z1)) < clear:
                    found.append("%s under what %s hangs at (%s, %s)" % (bid, room[5], hx, hz))
    for axis, at, d0, d1, bottom in doorways:
        if abs(bottom - floor) > 1e-6:
            continue
        mx, mz = ((at, (d0 + d1) / 2) if axis == 0 else ((d0 + d1) / 2, at))
        dx = max(x0 - mx, 0.0, mx - x1)
        dz = max(z0 - mz, 0.0, mz - z1)
        if math.hypot(dx, dz) < DOOR_CLEAR:
            found.append("%s by a doorway at (%s, %s)" % (bid, mx, mz))
    for r in ramp_geo:
        if min(r[5], r[6]) - 0.01 <= floor <= max(r[5], r[6]) + 0.01:
            ex, ez = (STAIR_CLEAR, 0.5) if r[4] == 0 else (0.5, STAIR_CLEAR)
            if r[0] - ex < x1 and x0 < r[1] + ex and r[2] - ez < z1 and z0 < r[3] + ez:
                found.append("%s by a stair at %s" % (bid, r[:4]))
    others = blocks_about(floor) + [p[1:] for p in ROOM_PIECES if p[0] != bid]
    for b in others:
        if b[4] < top - 1e-6 and b[5] > floor + 1e-6 and b[0] < x1 - 1e-6 and x0 + 1e-6 < b[1] \
                and b[2] < z1 - 1e-6 and z0 + 1e-6 < b[3]:
            found.append("%s on a blocker at %s" % (bid, b[:4]))
    for x, y, z in spawns:
        if abs(y - floor) < 1e-6 and x0 - 0.4 < x < x1 + 0.4 and z0 - 0.4 < z < z1 + 0.4:
            found.append("%s by a seat's start at %s" % (bid, (x, y, z)))
    return found


for rx0, rx1, rz0, rz1, floor, name in list(room_geo):
    if not name.startswith("E deck working passage"):
        continue
    where = name.split(", ")[-1].replace(" ", "_")
    for tag, s in [("p", -1), ("s", 1)]:
        face = (rz1 if s > 0 else rz0) - s * T
        z0, z1 = sorted((face - s * STORES_OFF, face - s * (STORES_OFF + STORES[1])))
        k = 0
        x = rx0 + T + 0.6
        while x + STORES[0] <= rx1 - T - 0.6:
            stack = ("stores_%s_%d%s" % (where, k, tag), x, x + STORES[0], z0, z1, floor, floor + STORES[2])
            if not piece_problems(stack):
                ROOM_PIECES.append(stack)
                k += 1
            x += STORES_PITCH

# A deck's public rooms as Plate III draws them (A_PLAN), each group of pieces tried where
# a room of its kind leaves it room and kept only if all of it keeps every rule above:
# card tables, a club chair at each side, over the smoking room; a settee against each
# stretch of the lounge's outer walls with a table and two armchairs before it, and
# tables among them; writing desks with their chairs along the reading and writing
# room's forward walls — every table there is drawn a desk — and settees along its after
# ones; wicker tables, a chair either side, in the
# verandah cafés; settees on the after staircase's forward wall either side of its
# middle. Each room's laid on the grid, of those shifted a quarter pitch at a time each
# way, that keeps the most of them. Their places est. after the plate.
def try_pieces(make):
    """The pieces make() lays, kept only if none of them breaks a rule."""
    before = len(ROOM_PIECES)
    make()
    if any(piece_problems(c) for c in ROOM_PIECES[before:]):
        del ROOM_PIECES[before:]

SHIFTS = (0.25, 0.5, 0.75, 1.0)

def lattice(lo, hi, step, shift):
    """Points step apart over lo..hi, the first shift of a step past lo."""
    points, at = [], lo + step * shift
    while at < hi - 1e-9:
        points.append(at)
        at += step
    return points

def best_laid(arrangements):
    """Of arrangements — each a list of makers, one a group — the one under which the most
    pieces keep every rule, laid: the first of the best on a tie."""
    best = []
    for makers in arrangements:
        before = len(ROOM_PIECES)
        for make in makers:
            try_pieces(make)
        laid = ROOM_PIECES[before:]
        del ROOM_PIECES[before:]
        if len(laid) > len(best):
            best = laid
    ROOM_PIECES.extend(best)

def scattered(tag, x0, x1, z0, z1, pitch, make):
    """Every grid of pitch over the box, shifted a quarter pitch at a time each way: make(gid,
    x, z) at each of its points."""
    return [[functools.partial(make, "%s_%d" % (tag, i), x, z)
             for i, (x, z) in enumerate([(x, z) for x in lattice(x0, x1, pitch, sx) for z in lattice(z0, z1, pitch, sz)])]
            for sx in SHIFTS for sz in SHIFTS]

def a_rooms(name):
    return [r for r in A_PLAN.rooms if r[0] == name]

def card_table(gid, x, z):
    table_group(gid, x, z, A_DECK, 0.45, 0.75)

def side_table(gid, x, z):
    table_group(gid, x, z, A_DECK, 0.35, 0.7, ("px", "mx"))

def wicker_table(gid, x, z):
    table_group(gid, x, z, A_DECK, 0.35, 0.7, ("pz", "mz"))

def lounge_settee(gid, x, wall, inward):
    settee(gid, x, wall + inward * (PARTITION + SETTEE[1] / 2 + 0.1), A_DECK)
    side_table(gid, x, wall + inward * (PARTITION + SETTEE[1] + CHAIR_GAP + 0.45))

def writing_desk(gid, x1, z):
    piece("desk_" + gid, x1 - T - DESK[1], x1 - T, z - DESK[0] / 2, z + DESK[0] / 2, A_DECK, A_DECK + DESK[2])
    armchair(gid, x1 - T - DESK[1] - CHAIR_GAP - ARMCHAIR / 2, z, A_DECK)

for k, (_n, x0, x1, z0, z1) in enumerate(a_rooms("first-class smoking room")):
    best_laid(scattered("smoking_%d" % k, x0, x1, z0, z1, 3.6, card_table))
for k, (_n, x0, x1, z0, z1) in enumerate(a_rooms("first-class lounge")):
    best_laid([[functools.partial(lounge_settee, "lounge_%d%s%d" % (k, side, i), x, wall, inward)
                for side, wall, inward in [("p", z0, 1), ("s", z1, -1)] for i, x in enumerate(lattice(x0, x1, 4.5, sx))]
               for sx in SHIFTS])
    best_laid(scattered("lounge_%d" % k, x0, x1, z0, z1, 3.6, side_table))
for k, (_n, x0, x1, z0, z1) in enumerate(a_rooms("reading and writing room")):
    best_laid([[functools.partial(writing_desk, "reading_%d_%d" % (k, i), x1, z)
                for i, z in enumerate(lattice(z0, z1, 1.8, sz))] for sz in SHIFTS])
    best_laid([[functools.partial(settee, "reading_%d_%d" % (k, i), x0 + T + SETTEE[1] / 2, z, A_DECK, False)
                for i, z in enumerate(lattice(z0, z1, 2.8, sz))] for sz in SHIFTS])
for k, (_n, x0, x1, z0, z1) in enumerate(a_rooms("verandah café and palm court")):
    best_laid(scattered("cafe_%d" % k, x0, x1, z0, z1, 2.6, wicker_table))
for _n, x0, x1, z0, z1 in a_rooms("after grand staircase, A deck"):
    for side, z in [("p", -4.0), ("s", 4.0)]:
        try_pieces(lambda: settee("entrance_%s" % side, x1 - T - SETTEE[1] / 2, z, A_DECK, along_x=False))
# B deck's public rooms as the Titanic's 1912 plan draws them (B_PLAN), as A deck's: card
# tables over the second-class smoking room; wicker tables, a chair either side, in the
# Café Parisien ("small groups of chairs surrounding convenient tables"); tables with an
# armchair either end in the restaurant's reception room. The restaurant's tables are laid
# tables, as the dining saloons' (LAID, below).
def b_rooms(name):
    return [r for r in B_PLAN.rooms if r[0] == name]

for k, (_n, x0, x1, z0, z1) in enumerate(b_rooms("second-class smoking room")):
    best_laid(scattered("smoking_b_%d" % k, x0, x1, z0, z1, 3.6,
                        lambda gid, x, z: table_group(gid, x, z, B_DECK, 0.45, 0.75)))
for k, (_n, x0, x1, z0, z1) in enumerate(b_rooms("Café Parisien")):
    best_laid(scattered("cafe_b_%d" % k, x0, x1, z0, z1, 2.6,
                        lambda gid, x, z: table_group(gid, x, z, B_DECK, 0.35, 0.7, ("pz", "mz"))))
for k, (_n, x0, x1, z0, z1) in enumerate(b_rooms("reception room, B deck")):
    best_laid(scattered("reception_b_%d" % k, x0, x1, z0, z1, 2.6,
                        lambda gid, x, z: table_group(gid, x, z, B_DECK, 0.35, 0.7, ("px", "mx"))))
# C and D decks' public rooms as Plate IV draws them (C_PLAN, D_PLAN), as A and B decks':
# tables with a chair either side in the third-class smoking room and general room and the
# second-class library; wicker tables, an armchair either end, in the first-class reception
# room. (The crew's messes under the forecastle are too small for a mess table clear of
# their pendants.) The dining saloons' are laid tables (LAID, below).
def c_rooms(name):
    return [r for r in C_PLAN.rooms if r[0] == name]

def d_rooms(name):
    return [r for r in D_PLAN.rooms if r[0] == name]


WALL_CLEAR = 0.85
for name, tag, floor, pitch, make in [
        ("third-class smoking room", "smoking_c", 0.0, 2.6,
         lambda gid, x, z: table_group(gid, x, z, 0.0, 0.4, 0.75, ("pz", "mz"))),
        ("third-class general room", "general_c", 0.0, 3.0,
         lambda gid, x, z: table_group(gid, x, z, 0.0, 0.4, 0.75, ("pz", "mz"))),
        ("second-class library", "library_c", 0.0, 3.0,
         lambda gid, x, z: table_group(gid, x, z, 0.0, 0.4, 0.75, ("pz", "mz"))),
        ("reception room", "reception_d", D_DECK, 2.6,
         lambda gid, x, z: table_group(gid, x, z, D_DECK, 0.35, 0.7, ("px", "mx")))]:
    for k, (_n, x0, x1, z0, z1) in enumerate((d_rooms if floor < 0 else c_rooms)(name)):
        # Each table a body could stand on clear of what hangs on the walls at its ends.
        best_laid([[m for m in grid if x0 + WALL_CLEAR <= m.args[1] <= x1 - WALL_CLEAR]
                   for grid in scattered("%s_%d" % (tag, k), x0, x1, z0, z1, pitch, make)])

_problems = [problem for candidate in ROOM_PIECES for problem in piece_problems(candidate)]
assert not _problems, "\n".join(_problems)
for bid, x0, x1, z0, z1, floor, top in ROOM_PIECES:
    box(bid, x0, x1, z0, z1, floor, top)

# --- The F deck rooms over boiler rooms 4 and 5 roofed under E deck, after every other
# blocker so none of theirs moves: a slab on their walls' tops over each room, as the
# houses' roofs are (no deck of anyone's: nothing over them is a place), inboard of
# Scotland Road and round the grand staircase's own floor, capping the casings walled up
# to it — without it the rooms, and the stokeholds up their fiddleys, stood open to the
# void over them, and to the sea drawn in it once she sank by the head.
for tag, x0, x1, side, holes in [("br4", BX["G"], BX["F"], SALOON_Z, [(GS_E[0], GS_E[1], SR_Z[1], 6.0)] + E_LANDINGS),
                                 ("br5", BX["F"], BX["E"], BR5_Z, E_LANDINGS)]:
    for rid, z0, z1 in [("corridor", SR_Z[1], BATHS_Z), ("baths", BATHS_Z, side)]:
        for k, (a, b, s0, s1) in enumerate(deck_pieces(x0, x1, z0, z1, holes)):
            box("%s_%s_roof_%d" % (rid, tag, k), a, b, s0, s1, E_DECK - 2 * T, E_DECK)

# The seats a match on her takes (§SH34): four to sixteen; more is SH21.
SEATS = (4, 16)

def arr(script, ids):
    return "Array[ExtResource(\"%s\")]([%s])" % (script, ", ".join('SubResource("%s")' % i for i in ids))

# --- The structure (§5b.2): her hull, her cells, her watertight walls, her openings and
# her mass. `make ship-check` floats her on it at the night's condition and sinks her
# on her sure hit. Numbers marked est. are starting values, tuned as the physics reads
# them.

# The enclosed outline's top: her shell's (top_at), the B deck under A over B deck's
# house — her plating "carried right up to the Boat deck" (BOT) —, and the houses over
# it: A deck's between its promenades, and the boat deck's on it as Plate III draws them
# (BOAT_PLAN), side by side. (x0, x1, z0, z1, foot, top), each a cell of its own: out
# to its walls' outer faces, but where two houses share a wall, whose middle their cells
# meet on — cells never overlap.
def house_cell(house):
    _name, x0, x1, z0, z1 = house
    def shared(axis, at):
        return any(other is not house and (abs((o_x0 if axis == 0 else o_z0) - at) < 1e-6
                                            or abs((o_x1 if axis == 0 else o_z1) - at) < 1e-6)
                   and ((o_z0 < z1 and o_z1 > z0) if axis == 0 else (o_x0 < x1 and o_x1 > x0))
                   for other in BOAT_PLAN.houses for _o, o_x0, o_x1, o_z0, o_z1 in [other])
    return (x0 - (0.0 if shared(0, x0) else T), x1 + (0.0 if shared(0, x1) else T),
            z0 - (0.0 if shared(2, z0) else T), z1 + (0.0 if shared(2, z1) else T), BOAT, BOAT + HOUSE_TOP)

A_HOUSE_TOP = (A_HOUSE[0], A_HOUSE[1], -(A_HOUSE[2] + T), A_HOUSE[2] + T, A_DECK, BOAT)

def c_aft_houses():
    """C deck's after second-class entrance's after end, on her after well under B deck's
    tapered end (C_PLAN): a house for each step of its rooms' outline, from C deck to B,
    out to its walls' outer faces and on to the next step, the last to B deck's house."""
    pieces = [p[1:5] for p in C_PLAN.rooms + [s for s in C_PLAN.solids if s[5] is None]
              if C_TAIL - 1e-6 <= p[1] and p[2] <= B_RUN[0] + 1e-6]
    cuts = sorted({v for p in pieces for v in p[:2]} | {B_RUN[0]})
    steps = []
    for a, b in zip(cuts, cuts[1:]):
        half = max(max(-p[2], p[3]) for p in pieces if p[0] < b - 1e-6 and p[1] > a + 1e-6)
        if steps and abs(steps[-1][2] - half) < 1e-6:
            steps[-1][1] = b
        else:
            steps.append([a, b, half])
    steps[0][0] -= T
    return [(a, b, -(half + T), half + T, 0.0, B_DECK) for a, b, half in steps]

C_AFT_HOUSES = c_aft_houses()
# And B deck's second-class houses on her after promenade (B_PLAN), up to A deck; under
# her tapered after end, over the after well, C deck's after entrance up to it.
HOUSES = ([A_HOUSE_TOP] + [house_cell(house) for house in BOAT_PLAN.houses]
          + [b_house_box(house) + (B_DECK, A_DECK) for house in B_PLAN.houses] + C_AFT_HOUSES)
HOUSE_CELLS = (["a_deck"] + [house[0] for house in BOAT_PLAN.houses] + [house[0] for house in B_PLAN.houses]
               + ["c_deck_aft" + ("" if k == 0 else "_%d" % (k + 1)) for k in range(len(C_AFT_HOUSES))])

def shell_top(x):
    return A_DECK if B_HOUSE[0] <= x <= B_HOUSE[1] else top_at(x)

def stacked(x, foot):
    """The outline over x of the houses standing at foot there, starboard first, each up
    its side, over the houses on its roof and down its other side."""
    points = []
    for _x0, _x1, z0, z1, h_foot, roof in sorted([h for h in HOUSES if abs(h[4] - foot) < 1e-6 and h[0] < x < h[1]],
                                                key=lambda h: -h[3]):
        points += [(z1, h_foot), (z1, roof)] + stacked(x, roof) + [(z0, roof), (z0, h_foot)]
    return points

def bottom(x):
    """Her lowest point at x: her keel, or her forefoot or her counter over it."""
    if breadth(x, KEEL + 1e-6) > 0.0 or breadth(x, KEEL + 0.05) > 0.0:
        return KEEL
    low, high = KEEL, shell_top(x)
    for _ in range(48):
        middle = (low + high) * 0.5
        if breadth(x, middle) > 0.0:
            high = middle
        else:
            low = middle
    return high

SIDE_POINTS = 24

def section_outline(x):
    """Everything enclosed at x, counter-clockwise in (z, y): from her keel up her
    starboard side, over her houses, down her port side."""
    low, top = bottom(x), shell_top(x)
    side = []
    for i in range(SIDE_POINTS + 1):
        y = top - (top - low) * math.sin(math.pi * 0.5 * i / SIDE_POINTS)
        side.append((breadth(x, min(max(y, low + 1e-6), top)), y))
    side.reverse()
    points = [(0.0, low)] + side
    # Over the houses standing on her shell's top here, if she has any: A deck's over B
    # deck's house and the boat deck's on it; on her after promenade, B deck's.
    points += stacked(x, top)
    points += [(-z, y) for z, y in reversed(side)]
    outline = []
    for z, y in points:
        point = (round(z, 4) + 0.0, round(y, 4) + 0.0)
        if not outline or point != outline[-1]:
            outline.append(point)
    if outline[-1] == outline[0]:
        outline.pop()
    return simplified(outline, OUTLINE_TOLERANCE)

OUTLINE_TOLERANCE = 0.02

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

# Forty sections (§SH34), lofted between her ends, her bulkheads and the ends of her
# superstructure, none standing for more than the longest stretch that makes forty of
# them.
SECTION_COUNT = 40
FRAME_BREAKS = sorted({round(v, 4) for v in [X_AFT, X_FORE, FCSL_FROM, FCSL_STEP, POOP_TO, B_RUN[0], B_RUN[1],
                                             B_HOUSE[0], B_HOUSE[1]] + [b[1] for b in BULKHEADS]})

def section_spans(longest):
    return sum(math.ceil((b - a) / longest - 1e-9) for a, b in zip(FRAME_BREAKS, FRAME_BREAKS[1:]))

SECTION_MAX = next(m / 100 for m in range(4000, 100, -1) if section_spans(m / 100) >= SECTION_COUNT)
# Every house's ends among them too, however near another break, so each is lofted to
# its ends: a house no section's middle stood in would be a cell with no room in her,
# and a section's outline holds a house all along it — one running past the house's end
# would enclose a slice of air no cell holds, buoyant however deep she went.
SECTION_BREAKS = sorted(set(FRAME_BREAKS) | {round(x, 4) for x0, x1, *_r in HOUSES for x in (x0, x1)})
# Each section from one break to the next, its ends shared with its neighbours', so they
# tile her: a point on a bulkhead's line is in one of them, the one forward of it
# (HullSection's span takes its after end, not its forward one). Each end stands one or two
# tenths of a millimetre aft of its break, the shift that sets every section's middle on
# the fourth decimal (the authoring scene's grain, ShipSceneBake) — so the break itself
# is inside the section forward of it. Middles and lengths rounded apart left a tenth of a
# millimetre between two at bulkhead P, where a doorway's middle was in neither and read
# as the sea outside her (CellMap).
SECTION_ENDS = []  # each section's after end, in ten-thousandths of a metre, then her stem's
for a, b in zip(SECTION_BREAKS, SECTION_BREAKS[1:]):
    count = math.ceil((b - a) / SECTION_MAX - 1e-9)
    SECTION_ENDS += [round((a + (b - a) * k / count) * 10000) for k in range(count)]
SECTION_ENDS.append(round(SECTION_BREAKS[-1] * 10000))
SECTION_NUDGES = [1]  # how far aft of its break each end stands, in the same units
for lo, hi in zip(SECTION_ENDS, SECTION_ENDS[1:]):
    SECTION_NUDGES.append(1 if (lo - SECTION_NUDGES[-1] + hi - 1) % 2 == 0 else 2)
sections = []  # (x, length, outline)
for (lo, hi), (s0, s1) in zip(zip(SECTION_ENDS, SECTION_ENDS[1:]),
                              zip(SECTION_NUDGES, SECTION_NUDGES[1:])):
    x = ((lo - s0) + (hi - s1)) // 2 / 10000
    sections.append((x, (hi - s1 - lo + s0) / 10000, section_outline(x)))
assert len(sections) >= SECTION_COUNT, len(sections)

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

# Every deck of hers stands inside her hull, at its corners.
for x0, x1, z0, z1, h in plat_geo:
    for x in (x0 + 0.01, x1 - 0.01):
        assert breadth(x, h) >= max(-z0, z1) - 1e-9 or h >= shell_top(x) - 1e-9, ("platform outside her", x, h)

def f32(v):
    return struct.unpack("f", struct.pack("f", v))[0]

def joins():
    """Every stair's two ends meet a deck at its height, as Surfaces.joins finds them:
    each end's edge, its corners and its middle, inside a platform's Rect2 in single
    precision, where a rectangle's far side is its corner plus its size (as the trawler's
    generator checks hers)."""
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

# Every stair of the spaces made in her old voids (#148) stands inside her lines, 0.1 m
# clear of her shell, all along it.
for name, x0, x1, z0, z1, high, x_low in stairs:
    if not name.startswith(("space_", "stokehold_6")):
        continue
    low = next(min(r[5], r[6]) for r in ramp_geo if r[:4] == (x0, x1, z0, z1))
    for k in range(21):
        x = lerp(x0, x1, k / 20)
        y = lerp(low, high, (x - x_low) / (x1 - x0) if x_low == x0 else (x_low - x) / (x1 - x0))
        assert y >= shell_top(x) or breadth(x, y) >= max(-z0, z1) + 0.1, ("stair through her shell", name, x, y)

# --- Cells (§5b.2): (name, x0, x1, y0, y1, z0, z1, kind, permeability or None for its
# kind's). Her sixteen compartments deck by deck where their decks part her water: the
# double bottom under each (SB-text: watertight floors under every bulkhead), the hold
# or the boiler or engine room up to the first deck over it, the 'tween decks up to the
# deck its bulkheads reach, D deck to C; over C, the forecastle, the bridge deck, the
# poop, B deck under A, A deck's house and the boat deck's. Wilding's permeabilities
# (Wilding; the research's: his 1915 figures): holds 0.75, machinery 0.80, bunkers 0.50,
# accommodation 0.95 — her kinds' own but the holds' and the machinery's, stated here.
HOLD, MACHINERY = 0.75, 0.80
KINDS = ["ACCOMMODATION", "MACHINERY", "CARGO", "STORES", "VOID", "BUNKER", "OPEN_WELL"]
COMPARTMENTS = [  # (name, aft x, fore x) aft to fore, as her bulkheads part her
    ("after_peak", X_AFT, BX["P"]), ("after_hold_aft", BX["P"], BX["O"]), ("after_hold_fwd", BX["O"], BX["N"]),
    ("electric_room", BX["N"], BX["M"]), ("turbine_room", BX["M"], BX["L"]), ("engine_room", BX["L"], BX["K"]),
    ("boiler_room_1", BX["K"], BX["J"]), ("boiler_room_2", BX["J"], BX["H"]), ("boiler_room_3", BX["H"], BX["G"]),
    ("boiler_room_4", BX["G"], BX["F"]), ("boiler_room_5", BX["F"], BX["E"]), ("boiler_room_6", BX["E"], BX["D"]),
    ("hold_3", BX["D"], BX["C"]), ("hold_2", BX["C"], BX["B"]), ("hold_1", BX["B"], BX["A"]),
    ("forepeak", BX["A"], X_FORE),
]
COMP = {c[0]: (c[1], c[2]) for c in COMPARTMENTS}
CELLS = []

def cell(name, x0, x1, y0, y1, z0, z1, kind, perm=None):
    CELLS.append([name, round(x0, 4), round(x1, 4), round(y0, 4), round(y1, 4), round(z0, 4), round(z1, 4), kind, perm])

for name, x0, x1 in COMPARTMENTS[1:-1]:
    top = ENGINE_TANK_TOP if name == "engine_room" else TANK_TOP
    cell("db_" + name, x0, x1, KEEL, top, -HALF, HALF, "VOID")
x0, x1 = COMP["forepeak"]
cell("forepeak_tank", x0, x1, KEEL, ORLOP, -HALF, HALF, "VOID")
cell("forepeak", x0, x1, ORLOP, D_DECK, -HALF, HALF, "STORES")
cell("forepeak_d", x0, x1, D_DECK, 0.0, -HALF, HALF, "ACCOMMODATION")
x0, x1 = COMP["hold_1"]
cell("hold_1", x0, x1, TANK_TOP, G_DECK, -HALF, HALF, "CARGO", HOLD)
cell("hold_1_tween", x0, x1, G_DECK, D_DECK, -HALF, HALF, "ACCOMMODATION")
cell("hold_1_d", x0, x1, D_DECK, 0.0, -HALF, HALF, "ACCOMMODATION")
for hold in ("hold_2", "hold_3"):
    x0, x1 = COMP[hold]
    cell(hold + "_port", x0, x1, TANK_TOP, PASSAGE_TOP, -HALF, PASSAGE_Z[0], "CARGO", HOLD)
    cell(hold + "_starboard", x0, x1, TANK_TOP, PASSAGE_TOP, PASSAGE_Z[1], HALF, "CARGO", HOLD)
    cell(hold, x0, x1, PASSAGE_TOP, G_DECK, -HALF, HALF, "CARGO", HOLD)
    cell(hold + "_tween", x0, x1, G_DECK, D_DECK, -HALF, HALF, "ACCOMMODATION")
cell("firemens_passage", BX["D"], BX["B"], TANK_TOP, PASSAGE_TOP, PASSAGE_Z[0], PASSAGE_Z[1], "ACCOMMODATION")
for k in range(6, 0, -1):
    name = "boiler_room_%d" % k
    x0, x1 = COMP[name]
    # Boiler room 5's forward bunker was empty that night (BOT: "At the time of the
    # collision this bunker had no coal in it").
    cell("bunker_%d" % k, BUNKERS["br%d" % k], x1, TANK_TOP, F_DECK, -HALF, HALF, "BUNKER", 0.95 if k == 5 else None)
    cell(name, x0, BUNKERS["br%d" % k], TANK_TOP, F_DECK, -HALF, HALF, "MACHINERY", MACHINERY)
    if k == 6:
        cell(name + "_tween", x0, x1, F_DECK, D_DECK, -HALF, HALF, "ACCOMMODATION")
    else:
        cell(name + "_f", x0, x1, F_DECK, E_DECK, -HALF, HALF, "ACCOMMODATION")
        cell(name + "_e", x0, x1, E_DECK, D_DECK, SR_Z[1], HALF, "ACCOMMODATION")
cell("scotland_road", SR[0], SR[1], E_DECK, D_DECK, -HALF, SR_Z[1], "ACCOMMODATION")
for name, floor in [("engine_room", ENGINE_TANK_TOP), ("turbine_room", TANK_TOP)]:
    x0, x1 = COMP[name]
    cell(name, x0, x1, floor, F_DECK, -HALF, HALF, "MACHINERY", MACHINERY)
    cell(name + "_tween", x0, x1, F_DECK, D_DECK, -HALF, HALF, "ACCOMMODATION")
x0, x1 = COMP["electric_room"]
cell("electric_room", x0, x1, TANK_TOP, G_DECK, -HALF, HALF, "MACHINERY", MACHINERY)
cell("electric_room_tween", x0, x1, G_DECK, D_DECK, -HALF, HALF, "ACCOMMODATION")
cell("electric_room_d", x0, x1, D_DECK, 0.0, -HALF, HALF, "ACCOMMODATION")
for name in ("after_hold_fwd", "after_hold_aft"):
    x0, x1 = COMP[name]
    cell(name, x0, x1, TANK_TOP, ORLOP, -HALF, HALF, "CARGO", HOLD)
    cell(name + "_orlop", x0, x1, ORLOP, G_DECK, -HALF, HALF, "STORES")
    cell(name + "_tween", x0, x1, G_DECK, D_DECK, -HALF, HALF, "ACCOMMODATION")
    cell(name + "_d", x0, x1, D_DECK, 0.0, -HALF, HALF, "ACCOMMODATION")
x0, x1 = COMP["after_peak"]
cell("after_peak_tank", x0, x1, KEEL, G_DECK, -HALF, HALF, "VOID")
cell("after_peak_tween", x0, x1, G_DECK, D_DECK, -HALF, HALF, "STORES")
cell("after_peak_d", x0, x1, D_DECK, 0.0, -HALF, HALF, "ACCOMMODATION")
# D deck under the bridge deck, and forward of it under the well and No. 1 hatch: one
# space, two cells, so the water drawn round each one's rooms stands inside her shell.
cell("d_deck", BX["M"], B_RUN[1], D_DECK, 0.0, -HALF, HALF, "ACCOMMODATION")
cell("d_deck_forward", B_RUN[1], BX["B"], D_DECK, 0.0, -HALF, HALF, "ACCOMMODATION")
cell("forecastle", FCSL_FROM, FCSL_STEP, 0.0, FCSL[0], -HALF, HALF, "ACCOMMODATION")
cell("forecastle_head", FCSL_STEP, X_FORE, 0.0, FCSL[1], -HALF, HALF, "ACCOMMODATION")
cell("c_deck", B_RUN[0], B_RUN[1], 0.0, B_DECK, -HALF, HALF, "ACCOMMODATION")
cell("poop", X_AFT, POOP_TO, 0.0, POOP, -HALF, HALF, "ACCOMMODATION")
cell("b_deck", B_HOUSE[0], B_HOUSE[1], B_DECK, A_DECK, -HALF, HALF, "ACCOMMODATION")
for name, (x0, x1, z0, z1, foot, roof) in zip(HOUSE_CELLS, HOUSES):
    cell(name, x0, x1, foot, roof, z0, z1, "ACCOMMODATION")

# Each cell drawn in to her shell's widest within it: her water's surface across a cell
# is the box's, so a box as wide as her midships in her fine ends and over her bilge
# would give her flooded bow a free surface several times what her lines leave it, and
# with it a list she never had (R23). The box still holds every bit of her hull in it.
def widest(x0, x1, y0, y1):
    reach = 0.0
    for x, length, outline in sections:
        if min(x1, x + length * 0.5) - max(x0, x - length * 0.5) <= 0:
            continue
        part = clip(clip(outline, 1, y1, True), 1, y0, False)
        reach = max([reach] + [abs(z) for z, _y in part])
    return math.ceil(reach * 16 - 1e-9) / 16

for c in CELLS:
    reach = widest(c[1], c[2], c[3], c[4])
    c[5], c[6] = round(max(c[5], -reach), 4), round(min(c[6], reach), 4)
    assert c[5] < c[6], ("a cell outside her", c[0])

# Her sisters' inner skin (SB-1914): along her boiler and engine rooms each cell from
# her tank top to F deck (est.) narrowed to inside it, a wing outside it either side of
# each compartment, nobody's. The skin stands its width inside her shell where her
# compartment is narrowest, half way up it.
SKINNED = [c for c in COMPARTMENTS if SKIN and SKIN_RUN[0] <= c[1] and c[2] <= SKIN_RUN[1]]
SKIN_Z = {name: round(min(breadth(x, (TANK_TOP + F_DECK) * 0.5) for x in (x0 + 0.01, (x0 + x1) * 0.5, x1 - 0.01))
                      - SKIN, 4) for name, x0, x1 in SKINNED}
for name, x0, x1 in SKINNED:
    for c in list(CELLS):
        if x0 <= c[1] and c[2] <= x1 and c[3] >= TANK_TOP - 0.31 and c[4] <= F_DECK + 1e-6:
            c[5], c[6] = -SKIN_Z[name], SKIN_Z[name]
    floor = ENGINE_TANK_TOP if name == "engine_room" else TANK_TOP
    cell(name + "_wing_p", x0, x1, floor, F_DECK, -HALF, -SKIN_Z[name], "VOID")
    cell(name + "_wing_s", x0, x1, floor, F_DECK, SKIN_Z[name], HALF, "VOID")

# Watertight walls (§5b.2): her bulkheads A–P, across her from her keel to their
# measured tops (R32), each at its own x. A head across a wall is the water's over the
# foot of each panel of it (SinkFailures): est., each is built for the head from her
# keel to its top, starts to leak at 1.25× it and gives way at 1.5× (as the steamer's);
# the hit weakens one it ends beside (the scenario's weakened_to).
WALL_LEAK = 0.002

def built_for(top):
    return top - KEEL

# A cell a watertight wall stands in is cut there: her bulkheads part every cell they
# reach into — Scotland Road where her measured sheer lifts a bulkhead's top over her
# flat E deck; her sisters' bulkheads raised to B deck through D deck and C. The
# firemen's passage is a watertight tunnel through bulkheads B and C, one space.
for letter, x, *_rest in BULKHEADS:
    top = TOPS[letter]
    for c in list(CELLS):
        if c[0] == "firemens_passage":
            continue
        if c[1] < x - 1e-6 and c[2] > x + 1e-6 and c[3] < top - 1e-6:
            fore = list(c)
            c[2] = x
            fore[1] = x
            CELLS.insert(CELLS.index(c) + 1, fore)
names_seen = {}
for c in CELLS:
    names_seen[c[0]] = names_seen.get(c[0], 0) + 1
counts = {}
for c in CELLS:
    if names_seen[c[0]] > 1:
        counts[c[0]] = counts.get(c[0], 0) + 1
        c[0] = "%s_%d" % (c[0], counts[c[0]])
CELLS = [tuple(c) for c in CELLS]

def cell_at(x, y, z):
    for c in CELLS:
        if c[1] < x < c[2] and c[3] < y < c[4] and c[5] < z < c[6]:
            return c[0]
    return None

def cell_box(name):
    return next(c for c in CELLS if c[0] == name)[1:7]

# Each room in one cell, wholly, its name in that cell alone (test_ship_structure_lint):
# her traced decks' rooms are split and named so where her cells part under them
# (named_pieces). Her sisters' cells part where their raised bulkheads do too; their
# rooms are hers.
if not variant:
    in_cells = {}
    for x0, x1, z0, z1, floor, name in room_geo:
        middle = ((x0 + x1) * 0.5, floor + 0.01, (z0 + z1) * 0.5)
        holding = [c for c in CELLS if all(c[1 + 2 * a] + 1e-3 <= middle[a] <= c[2 + 2 * a] - 1e-3 for a in range(3))]
        assert len(holding) == 1, ("a room in %d cells" % len(holding), name, x0, x1, floor)
        c = holding[0]
        assert (c[1] - 0.01 <= x0 and x1 <= c[2] + 0.01 and c[5] - 0.01 <= z0 and z1 <= c[6] + 0.01
                and c[3] - 0.01 <= floor <= c[4] + 0.01), ("a room past its cell", name, (x0, x1, z0, z1), c[0])
        in_cells.setdefault(name, set()).add(c[0])
    twice = {name: sorted(cs) for name, cs in in_cells.items() if len(cs) > 1}
    assert not twice, ("a name in two cells", twice)

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

def covered(x, top, out):
    """How far out from her centre line, to one side, decks at top or over it stand over
    x without a break: as far as a wall there can reach and still have a deck over it."""
    spans = sorted((min(z0, z1), max(z0, z1)) for x0, x1, z0, z1, h in plat_geo if h >= top and x0 <= x <= x1)
    reach = 0.0
    for z0, z1 in spans:
        lo, hi = (z0, z1) if out > 0 else (-z1, -z0)
        if lo <= reach + 1e-6:
            reach = max(reach, hi)
    return reach

walls = []  # (name, axis, at, span, bottom, top, collapse, cells)
for letter, x, *_rest in BULKHEADS:
    top = TOPS[letter]
    hull_half = max(breadth(x, y) for y in (top, (top + KEEL) * 0.5, KEEL + BILGE))
    half = round(min(hull_half, covered(x, top, 1), covered(x, top, -1)), 4)
    walls.append(("bulkhead_" + letter.lower(), "ACROSS", x, (-half, half), KEEL, top, 1.5 * built_for(top),
                  parted(0, x, KEEL, top, -half, half)))
# Her sisters' inner skin, a wall along her either side of each compartment it runs
# through, to F deck (est.), built as her bulkheads are.
for name, x0, x1 in SKINNED:
    floor = ENGINE_TANK_TOP if name == "engine_room" else TANK_TOP
    for tag, z in [("p", -SKIN_Z[name]), ("s", SKIN_Z[name])]:
        walls.append(("skin_%s_%s" % (name, tag), "ALONG", z, (x0, x1), floor, F_DECK,
                      1.5 * built_for(F_DECK), parted(2, z, floor, F_DECK, x0, x1)))

# Openings: (name, kind, joins, centre, size, fields). size is the rectangle's extent
# along x, y and z, zero across the axis it is flat on.
SEA, SKY = "sea", "sky"
openings = []

def opening(name, kind, a, b, centre, size, **fields):
    openings.append((name, kind, [a or SKY, b or SKY], tuple(round(v, 4) for v in centre),
                     tuple(round(v, 4) for v in size), fields))

def piece(name, x):
    """Cell name, or the piece of it standing at x where a bulkhead cut it (a sister's)."""
    for c in CELLS:
        if (c[0] == name or c[0].rpartition("_")[0] == name and c[0].rpartition("_")[2].isdigit()) and c[1] < x < c[2]:
            return c[0]
    return name

def through(name, kind, x, z, sx, sz, below, above=None, **fields):
    """An opening in the deck over cell below, into the cell over it there or the sky."""
    below = piece(below, x)
    y = cell_box(below)[3]
    above = above or cell_at(x, y + 0.01, z)
    opening(name, kind, below, above, (x, y, z), (sx, 0, sz), **fields)

def across(name, kind, x, y, z, sy, sz, **fields):
    """An opening in the plane x between the cells either side of it."""
    a, b = cell_at(x - 0.01, y, z), cell_at(x + 0.01, y, z)
    opening(name, kind, a, b, (x, y, z), (0, sy, sz), **fields)

def floor_of(x, z, y):
    return cell_box(cell_at(x, y, z))[2]

# Her twelve vertical watertight doors (BOT): "twelve vertical sliding watertight doors
# which completed the watertightness of bulkheads D to O inclusive", at the floor of the
# boiler and engine rooms, "capable of being simultaneously closed from the bridge", in
# "between 25 and 30 seconds" (BOT) — the firemen's passage's into boiler room 6 at D,
# two at K (est.: bulkhead K's pair, either side of the engine room's centre line).
# Est.: each jams open one time in twenty; shut, it weeps 0.005 m² round its seals once
# the water stands at its bulkhead's top over its sill and gives way at 1.5× that.
VERTICAL_DOORS = [("D", PASSAGE_Z[0] + 1.0), ("E", 0.0), ("F", 0.0), ("G", 0.0), ("H", 0.0), ("J", 0.0),
                  ("K", -4.0), ("K", 4.0), ("L", 0.0), ("M", 0.0), ("N", 0.0), ("O", 0.0)]
for k, (letter, z) in enumerate(VERTICAL_DOORS):
    x = BX[letter]
    sill = max(floor_of(x - 0.05, z, -16.0), floor_of(x + 0.05, z, -16.0))
    tag = letter.lower() + ("_" + ("p" if z < 0 else "s") if letter == "K" else "")
    across("wtd_" + tag, "WATERTIGHT_DOOR", x, sill + LINTEL * 0.5, z, LINTEL, DOOR, starts="OPEN",
           shuts_at_hit=True, shut_time=30.0, flip_chance=0.05, leak_head=TOPS[letter] - sill,
           collapse_head=1.5 * (TOPS[letter] - sill), leak_area=0.005)
# The horizontal sliding doors on F and E decks (BOT: "On both the F and E decks nearly
# all the bulkheads had watertight doors ... workable by hand"), open as she steamed and
# never shut by the ship (Boxhall's evidence, in BOT: "The watertight doors on F deck at
# the fore and after ends of No. 3 compartment were not closed then"): on F deck in the
# bulkheads from C to J, E deck's in those from K to O (est.: one each, 6 m to port); the one in bulkhead H between the third-class saloons is the layout's.
# Her sisters' shut from the bridge with their vertical doors (est.: the bulkheads they
# carried up through those decks after 1912, SB-1914, would hold nothing with a door left
# open in them), weeping and giving way as those do.
def deck_door(letter, deck):
    if not variant:
        return dict(starts="OPEN")
    return dict(starts="OPEN", shuts_at_hit=True, shut_time=30.0, flip_chance=0.05, leak_head=TOPS[letter] - deck,
                collapse_head=1.5 * (TOPS[letter] - deck), leak_area=0.005)
for letter in "CDEFGJ":
    across("wtd_f_" + letter.lower(), "WATERTIGHT_DOOR", BX[letter], F_DECK + LINTEL * 0.5, -6.0, LINTEL, DOOR,
           **deck_door(letter, F_DECK))
for letter in "KLMNO":
    across("wtd_e_" + letter.lower(), "WATERTIGHT_DOOR", BX[letter], E_DECK + LINTEL * 0.5, -6.0, LINTEL, DOOR,
           **deck_door(letter, E_DECK))
# Each boiler room's forward cross bunker: its door to the stokehold at the plates,
# shut — boiler room 5's "was closed when water was seen to be entering the ship" and
# later burst, "weaker than the bunker bulkhead" (BOT) — est. 1 m square, 2 ft over the
# plates on her starboard side, weeping 0.005 m² under 1.5 m of water and giving way
# under 3 m; the bunker's plating and its coal scuttles leak (est.).
for k in range(6, 0, -1):
    x = BUNKERS["br%d" % k]
    across("bunker_door_%d" % k, "DOOR", x, TANK_TOP + 0.6 + 0.5, 3.0, 1.0, 1.0, starts="SHUT",
           leak_head=1.5, collapse_head=3.0, leak_area=0.005)
    b = cell_box("bunker_%d" % k)
    opening("leak_bunker_%d" % k, "LEAK", "boiler_room_%d" % k, "bunker_%d" % k,
            (x, (b[2] + b[3]) * 0.5, -6.0), (0, b[3] - b[2], 2.0), area=0.01, starts="OPEN")
    through("scuttle_bunker_%d" % k, "LEAK", (b[0] + b[1]) * 0.5, 8.0, 1.0, 1.0, "bunker_%d" % k, area=0.05,
            starts="OPEN")

# The doors through her bulkheads into the spaces made in her old voids (#148), as the
# steamer's and the trawler's scuttles: bolted shut, a body going through one opening it
# as a doorway's door is opened — shut to the water, each never weeps nor gives way, so
# the spaces either side of it flood as they did before they were places.
for name, x, floor, z in SEALED_DOORS:
    across(name, "WATERTIGHT_DOOR", x, floor + LINTEL * 0.5, z, LINTEL, DOOR, starts="SHUT")

# Doorways: open, as Q15 built them; one in a watertight wall a hand-worked watertight
# door. Doorways joining the same two places at one sill on one face are one opening.
bulkhead_x = {round(b[1], 4) for b in BULKHEADS}
merged = {}
for axis, at, d0, d1, foot in doorways:
    middle = (d0 + d1) * 0.5
    probes = [at - T - 0.01, at + T + 0.01]
    y = foot + 1.0
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
    key = (a, b, axis, round(face, 4), round(foot, 4))
    # A doorway through a watertight door the ship has already (the F and E deck doors
    # 6 m to port) is that door, not a second one nobody shuts.
    if any(o[1] == "WATERTIGHT_DOOR" and set(o[2]) == {a, b or SKY} and o[4][axis] == 0
           and abs(o[3][axis] - face) < 1e-4 and abs(o[3][1] - LINTEL * 0.5 - foot) < 1e-4 for o in openings):
        continue
    # Nor is the one through the forecastle's front onto the forward well: the forecastle's
    # door there (door_forecastle, below) is that door.
    if (a, b, axis) == ("forecastle", None, 0) and abs(face - FCSL_FROM) < 1e-4:
        continue
    if key in merged:
        merged[key][1] += (d1 - d0) * LINTEL
        continue
    centre = (face, foot + LINTEL * 0.5, middle) if axis == 0 else (middle, foot + LINTEL * 0.5, face)
    size = (0, LINTEL, d1 - d0) if axis == 0 else (d1 - d0, LINTEL, 0)
    merged[key] = [centre, (d1 - d0) * LINTEL, size]
for (a, b, axis, face, foot), (centre, area, size) in merged.items():
    # On D deck and over it her bulkheads have ended ("up to the underside of D deck"): a
    # doorway there on a bulkhead's line is her rooms' door, no watertight one.
    if axis == 0 and face in bulkhead_x and b is not None and foot < D_DECK - 1e-6:
        letter = next(bulkhead[0] for bulkhead in BULKHEADS if round(bulkhead[1], 4) == face)
        opening("wtd_%s_%s" % (a, b), "WATERTIGHT_DOOR", a, b, centre, size, **deck_door(letter, foot))
        continue
    tag = "door_%s_%s" % (a, b or SKY)
    single = abs(area - size[1] * (size[0] + size[2])) < 1e-6
    opening("%s_%d" % (tag, sum(1 for o in openings if o[0].startswith(tag))), "DOOR", a, b, centre, size,
            area=0.0 if single else area, starts="OPEN")
# The forecastle's doors onto the forward well, shut and dogged (est., as the steamer's
# deck breaks'): weeping 0.01 m² under 1 m of water over their sill, gone under 2 m.
opening("door_forecastle", "DOOR", "forecastle", SKY, (FCSL_FROM, 0.06 + 0.75, 6.0), (0, 1.5, 0.75),
        starts="SHUT", leak_head=1.0, collapse_head=2.0, leak_area=0.01)
# A traced deck's open join between two rooms of two cells, open as they are: on B deck,
# the second-class staircase's well forward of its lift, in her house under A deck; on C
# deck, her after second-class entrance's hall at B deck's after end.
for plan, floor, over in ((BOAT_PLAN, BOAT, BOAT + HOUSE_TOP), (A_PLAN, A_DECK, BOAT), (B_PLAN, B_DECK, A_DECK),
                          (C_PLAN, 0.0, c_over), (D_PLAN, D_DECK, 0.0)):
    for ox0, ox1, oz0, oz1 in plan.open:
        axis = 0 if (ox1 - ox0) < (oz1 - oz0) else 2
        at, a, b = ((ox0 + ox1) * 0.5, oz0, oz1) if axis == 0 else ((oz0 + oz1) * 0.5, ox0, ox1)
        sides = [cell_at(p, floor + 1.0, (a + b) * 0.5) if axis == 0 else cell_at((a + b) * 0.5, floor + 1.0, p)
                 for p in (at - T - 0.01, at + T + 0.01)]
        if sides[0] != sides[1] and None not in sides:
            roof_y = over((ox0 + ox1) * 0.5) if callable(over) else over
            middle = ((floor + roof_y) * 0.5, (a + b) * 0.5)
            centre = (at,) + middle if axis == 0 else (middle[1], middle[0], at)
            size = (0, roof_y - floor, b - a) if axis == 0 else (b - a, roof_y - floor, 0)
            opening("open_%s_%s" % tuple(sides), "OPEN", sides[0], sides[1], centre, size, starts="OPEN")
opening("open_d_deck", "OPEN", piece("d_deck", B_RUN[1] - 0.01), "d_deck_forward", (B_RUN[1], D_DECK * 0.5, 0.0),
        (0, -D_DECK, 2 * fit(B_RUN[1] - 0.5, B_RUN[1] + 0.5, D_DECK, 0.0)), starts="OPEN")
opening("open_forecastle", "OPEN", "forecastle", "forecastle_head", (FCSL_STEP, FCSL[0] * 0.5, 0.0),
        (0, FCSL[0], 2 * min(fit(FCSL_STEP - 0.5, FCSL_STEP, FCSL[0] * 0.5, 0.0), cell_box("forecastle_head")[5])),
        starts="OPEN")

# Over each watertight wall that stops short of the deck, the gap water spills over.
for letter, x, *_rest in BULKHEADS:
    top = TOPS[letter]
    for a in [c for c in CELLS if abs(c[2] - x) < 1e-6 and c[4] > top + 1e-6]:
        for b in [c for c in CELLS if abs(c[1] - x) < 1e-6 and c[4] > top + 1e-6]:
            z0, z1 = max(a[5], b[5]), min(a[6], b[6])
            y0, y1 = max(top, a[3], b[3]), min(a[4], b[4])
            if z1 > z0 + 1e-6 and y1 > y0 + 1e-6:
                opening("over_%s_to_%s" % (a[0], b[0]), "OVER_WALL", a[0], b[0], (x, (y0 + y1) * 0.5, (z0 + z1) * 0.5),
                        (0, y1 - y0, z1 - z0))

# Up through her decks (BOT: "All the decks had large openings or hatchways in each
# compartment, so that water could rise freely through them"), est. sizes: the holds'
# hatchways 4 m square through G deck, 2 m above; each boiler room's fiddley and casing
# 3 m square over its stokehold, a stair 2 m square through each deck over it; the
# engine rooms' casings over their engines; the stairs her layout cuts, each where it is.
AIR_PIPE = 0.008  # a tank's 100 mm air pipe (est., as the steamer's)
for c in CELLS:
    if c[0].startswith("db_") or c[0].endswith("_tank"):
        through("pipe_" + c[0], "VENT", (c[1] + c[2]) * 0.5, max(-5.0, c[5] * 0.5), 0.09, 0.09, c[0], area=AIR_PIPE,
                starts="OPEN")
WIDE = 4.0
for name, x, z, size, kind in [
    ("forepeak", 120.0, 0.0, 1.0, "STAIRWELL"), ("forepeak_d", 118.0, 0.0, 1.0, "STAIRWELL"),
    ("hold_1", 108.8, 0.0, WIDE, "STAIRWELL"), ("hold_1_tween", 108.8, 0.0, 2.0, "STAIRWELL"),
    ("hold_1_d", 105.0, 0.0, 2.0, "STAIRWELL"),
    ("hold_2", 94.0, 0.0, WIDE, "STAIRWELL"), ("hold_2_tween", 94.0, 0.0, 2.0, "STAIRWELL"),
    ("hold_3", 72.6, -6.0, 2.0, "STAIRWELL"),
    ("boiler_room_6_tween", 62.0, 4.0, 2.0, "STAIRWELL"),
    ("engine_room_tween", -38.0, 4.0, 2.0, "STAIRWELL"), ("turbine_room_tween", -57.0, 4.0, 2.0, "STAIRWELL"),
    ("electric_room", -78.0, 0.0, 2.0, "STAIRWELL"), ("electric_room_tween", -78.0, 0.0, 2.0, "STAIRWELL"),
    ("electric_room_d", -78.0, 4.0, 2.0, "STAIRWELL"),
    ("after_hold_fwd_orlop", -93.0, 0.0, 3.0, "STAIRWELL"), ("after_hold_fwd_tween", -93.0, 0.0, 2.0, "STAIRWELL"),
    ("after_hold_fwd_d", -88.0, 0.0, 2.0, "STAIRWELL"),
    ("after_hold_aft_orlop", -110.0, 0.0, 3.0, "STAIRWELL"), ("after_hold_aft_tween", -110.0, 0.0, 2.0, "STAIRWELL"),
    ("after_hold_aft_d", -112.0, 0.0, 2.0, "STAIRWELL"),
    ("after_peak_tween", -122.0, 0.0, 1.0, "STAIRWELL"), ("after_peak_d", -125.0, 0.0, 1.0, "STAIRWELL"),
]:
    through("stair_" + name, kind, x, z, size, size, name, starts="OPEN")
# The after holds under her watertight orlop deck (BOT): their hatches battened, est.
# weeping 0.05 m² under 1 m of water and giving way under 3 m; the after well's two cargo
# hatches likewise, under 0.3 m and 1 m, as the steamer's.
for name, x in [("after_hold_fwd", -93.0), ("after_hold_aft", -110.0)]:
    through("hatch_" + name, "HATCH", x, 0.0, 3.0, 3.0, name, starts="SHUT", leak_head=1.0, collapse_head=3.0,
            leak_area=0.05)
# Her wells' hatches as C deck's plan draws them (C_PLAN): Nos. 6 and 5 aft, the bunker
# hatch and No. 2 forward, each over the D deck space under it.
for what, below in [("No. 6 hatch", "after_hold_aft_d"), ("No. 5 hatch", "after_hold_fwd_d"),
                    ("bunker hatch", "d_deck_forward"), ("No. 2 hatch", "d_deck_forward")]:
    _w, x0, x1, z0, z1, _h = next(p for p in C_PLAN.solids if p[0] == what)
    through("hatch_" + slug(what), "HATCH", (x0 + x1) * 0.5, (z0 + z1) * 0.5, x1 - x0, z1 - z0, below, SKY,
            starts="SHUT", leak_head=0.3, collapse_head=1.0, leak_area=0.05)
# The doors through the bulkheads across C deck's second-class promenades aft (BOT: "two
# doors at the after-end into the after-well"), from the well under B deck's end: each the
# gap between two of a bulkhead's pieces (C_PLAN), opening on B deck's end.
for side in (-1, 1):
    pieces = sorted((p[3], p[4]) for p in C_PLAN.solids if p[0] == "bulkhead" and p[3] * side > 0)
    for k, ((_a0, a1), (b0, _b1)) in enumerate(zip(pieces, pieces[1:])):
        opening("door_c_deck_sky_%s%d" % ("ps"[side > 0], k), "DOOR", piece("c_deck", B_RUN[0] + 0.01), SKY,
                (B_RUN[0], LINTEL * 0.5, (a1 + b0) * 0.5), (0, LINTEL, b0 - a1), starts="OPEN")
for k in range(6, 0, -1):
    name = "boiler_room_%d" % k
    b = cell_box(name)
    through("fiddley_" + name, "STAIRWELL", (b[0] + b[1]) * 0.5, 0.0, 3.0, 3.0, name, starts="OPEN")
    if k < 6:
        f = cell_box(name + "_f")
        through("stair_" + name + "_f", "STAIRWELL", (f[0] + f[1]) * 0.5 + 2.0, 2.0, 2.0, 2.0, name + "_f",
                starts="OPEN")
        through("stair_" + name + "_e", "STAIRWELL", (f[0] + f[1]) * 0.5 - 2.0, 4.0, 2.0, 2.0, name + "_e",
                starts="OPEN")
        through("stair_%s_road" % name, "STAIRWELL", (f[0] + f[1]) * 0.5 + 3.0, -11.5, 1.0, 1.0, name + "_f",
                starts="OPEN")
for name in ("engine_room", "turbine_room"):
    b = cell_box(name)
    through("casing_" + name, "STAIRWELL", (b[0] + b[1]) * 0.5, 0.0, (b[1] - b[0]) * 0.5, 6.0, name, starts="OPEN")
for name, x0, x1, z0, z1, high, _x_low in stairs:
    if name.startswith(("boat_aft", "a_aft", "b_aft", "a_fwd", "forecastle_", "poop_")):
        continue
    # The boiler rooms' flights to F deck: the fiddley/casing openings already stand for
    # these shafts. The stairs of the spaces made in her old voids (#148): the hatchways,
    # the holds' open tops and the passage's stair opening stand for theirs, and the
    # manholes into her double bottoms are their own (below).
    if name.startswith(("stokehold_", "space_")):
        continue
    xm, zm = (x0 + x1) * 0.5, (z0 + z1) * 0.5
    below = cell_at(xm, high - 0.01, zm)
    above = cell_at(xm, high + 0.01, zm)
    if below != above and below is not None:
        # Over the part of the flight both cells hold: one coming down past a house's end
        # into the next cell's (B deck's second-class staircase's well) opens only there.
        for c in [below] + ([above] if above is not None else []):
            bx0, bx1, _y0, _y1, bz0, bz1 = cell_box(c)
            x0, x1, z0, z1 = max(x0, bx0), min(x1, bx1), max(z0, bz0), min(z1, bz1)
        xm, zm = (x0 + x1) * 0.5, (z0 + z1) * 0.5
        opening("stair_%s" % name, "STAIRWELL", below, above, (xm, high, zm), (x1 - x0, 0, z1 - z0), starts="OPEN")
# The manholes down into her double bottoms (#148), each over its stair in the tank top,
# and the hatches down through the after holds' watertight orlop deck, each over its
# stair: bolted shut as the doors through her bulkheads into her spaces are (above).
for name, x0, x1, z0, z1, high, _x_low in stairs + stairs_z:
    kind = ("manhole_" if name.startswith("space_db")
            else "hatch_" if name.startswith(("space_ahf_or", "space_aha_or")) else "")
    if kind:
        xm, zm = (x0 + x1) * 0.5, (z0 + z1) * 0.5
        opening(kind + name[len("space_"):], "HATCH", cell_at(xm, high - 0.01, zm), cell_at(xm, high + 0.01, zm),
                (xm, high, zm), (x1 - x0, 0, z1 - z0), starts="SHUT")
# The firemen's passage: its plating leaks into the holds round it (est. 0.01 m² each
# side), and the spiral stairs at its forward end climb out of it (Wilding) — est. a
# metre square into No. 2 hold over it.
for hold in ("hold_2", "hold_3"):
    hb = cell_box(hold)
    xm = (hb[0] + hb[1]) * 0.5
    for side, z in [("port", PASSAGE_Z[0]), ("starboard", PASSAGE_Z[1])]:
        opening("leak_passage_%s_%s" % (hold, side), "LEAK", "firemens_passage", "%s_%s" % (hold, side),
                (xm, (TANK_TOP + PASSAGE_TOP) * 0.5, z), (hb[1] - hb[0] - 1.0, PASSAGE_TOP - TANK_TOP - 0.2, 0),
                area=0.01, starts="OPEN")
    for side in ("port", "starboard"):
        sb = cell_box("%s_%s" % (hold, side))
        opening("open_%s_%s" % (hold, side), "OPEN", "%s_%s" % (hold, side), hold,
                ((sb[0] + sb[1]) * 0.5, PASSAGE_TOP, (sb[4] + sb[5]) * 0.5), (sb[1] - sb[0], 0, sb[5] - sb[4]),
                starts="OPEN")
opening("stair_firemens_passage", "STAIRWELL", "firemens_passage", "hold_2",
        (BX["B"] - 1.0, PASSAGE_TOP, (PASSAGE_Z[0] + PASSAGE_Z[1]) * 0.5), (1.0, 0, 1.0), starts="OPEN")
# Her sisters' inner skin: each wing leaks into the room inside it (est. 0.002 m², as
# the trawler's linings) and breathes through an air pipe into the deck over it.
for c in [c for c in CELLS if "_wing_" in c[0]]:
    inner = cell_at((c[1] + c[2]) * 0.5, (c[3] + c[4]) * 0.5, 0.0)
    z = c[5] if c[5] > 0 else c[6]
    opening("leak_" + c[0], "LEAK", c[0], inner, ((c[1] + c[2]) * 0.5, (c[3] + c[4]) * 0.5, z),
            (c[2] - c[1], c[4] - c[3], 0), area=0.002, starts="OPEN")
    through("pipe_" + c[0], "VENT", (c[1] + c[2]) * 0.5, (c[5] + c[6]) * 0.5, 0.09, 0.09, c[0], area=AIR_PIPE,
            starts="OPEN")

# Her portholes, a row along each side of each cell her shell bounds over her
# waterline, at its lowest deck with ports — F in her 'tween decks, E along Scotland
# Road and the cabins over the boiler rooms, D under C — a row for each 30 m of it: est.
# a 0.32 m port every 3 m, shut, left open one time in twenty; shut, a port's gasket
# weeps 0.0005 m² under 4 m of water and its glass breaks under 8 m (as the steamer's).
PORTHOLE_RADIUS = 0.16
PORT_SPACING = 3.0
ROW = 1.45

def section_shell(x, y, side):
    """Her shell's z at height y on one side, as the section standing for x draws it."""
    _x, _length, outline = min(sections, key=lambda s: abs(x - s[0]) - s[1] * 0.5)
    best = 0.0
    for i, p in enumerate(outline):
        q = outline[(i + 1) % len(outline)]
        if (p[1] - y) * (q[1] - y) <= 0 and p[1] != q[1]:
            z = p[0] + (y - p[1]) / (q[1] - p[1]) * (q[0] - p[0])
            best = max(best, z * side)
    return best
for c in CELLS:
    name = c[0]
    if name.endswith("_tween") or (name.startswith("boiler_room") and name.endswith("_f")) or name == "forepeak":
        row = F_DECK + ROW
    elif name.endswith("_e") or name.startswith("scotland_road"):
        row = E_DECK + ROW
    elif name.endswith("_d") or name.startswith("d_deck"):
        row = D_DECK + ROW
    else:
        continue
    pieces = max(1, math.ceil((c[2] - c[1]) / 30.0 - 1e-9))
    reach = min(widest(c[1], c[2], c[3], c[4]), HALF)
    for side, sign in [("p", -1), ("s", 1)]:
        if (sign < 0 and c[5] > -reach + 1e-6) or (sign > 0 and c[6] < reach - 1e-6):
            continue
        for k in range(pieces):
            a, b = lerp(c[1], c[2], k / pieces) + 0.5, lerp(c[1], c[2], (k + 1) / pieces) - 0.5
            xm = (a + b) * 0.5
            skin = min(section_shell(xm, row, sign), HALF)
            if skin <= 0.5:
                continue
            ports = max(1, round((b - a) / PORT_SPACING))
            tag = "port_%s_%s%s" % (name, side, "" if pieces == 1 else str(k + 1))
            opening(tag, "PORTHOLE", name, SEA, (xm, row, sign * skin), (b - a, PORTHOLE_RADIUS * 2, 0),
                    area=round(ports * math.pi * PORTHOLE_RADIUS ** 2, 4), starts="SHUT", flip_chance=0.05,
                    leak_head=4.0, collapse_head=8.0, leak_area=round(ports * 0.0005, 4))

# Glass in every wall of her houses that faces the sky over her shell's top, where the
# art sets it (ShipFittings._windows, with its numbers, placed as the steamer's generator
# places them): the boat deck's houses, A deck's between its promenades, the bridge
# deck's after face and the poop's onto the after well — none where a stair outside
# climbs past it; under her shell's top her portholes stand instead. Each joins the cell
# holding its room to the sky. Shut, a window breaks under 2 m of water (est., as the
# steamer's). `make art-lint` matches each pane the art draws to one of these.
WINDOW_HEIGHT, WINDOW_SPACING, WINDOW_MARGIN = 1.45, 1.3, 0.4
WINDOW, NARROW_WINDOW, WINDOW_FRAME = (0.55, 0.6), (0.38, 0.6), 0.06
WALL_MAX, FULL_WALL, INSIDE, OPEN_ROOM_HEIGHT, PROBE, SLIVER = 0.3, 1.9, 0.02, 2.5, 0.15, 0.01
SALOON_AREA = 15.0  # a room on her top deck smaller than this is a helm (RoomDressing)
FURNITURE_HEIGHT = 1.2  # a box on a floor no taller is furniture, not machinery (ShipSpace)
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

def machinery_in(house):
    x0, x1, z0, z1, floor, _name = house
    return any(is_box and min(bx1 - bx0, bz1 - bz0) > WALL_MAX and abs(foot - floor) < 0.05
               and top - foot > FURNITURE_HEIGHT
               and x0 <= (bx0 + bx1) * 0.5 <= x1 and z0 <= (bz0 + bz1) * 0.5 <= z1
               for bx0, bx1, bz0, bz1, foot, top, is_box in block_geo)

def in_a_block(x, y, z):
    """Whether ship point (x, y, z) stands inside a box blocker no thinner than a wall."""
    return any(is_box and bx0 < x < bx1 and bz0 < z < bz1 and foot < y < top and min(bx1 - bx0, bz1 - bz0) > WALL_MAX
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
                # Under her shell's top, onto a cell of hers — its own too, where a house
                # stands in from its cell's side (A deck's, one box over its stepped walls) —
                # or into a block (a casing): no sky beyond it.
                if height < shell_top(bx) or cell_at(bx, height, bz) is not None or in_a_block(bx, height, bz):
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

# Mass (est. throughout, but her displacement and her stability, which are the night's):
# where her weight sits. Her water ballast is what the generator settles: as heavy as
# she must be to float at the night's draught, and where along and across her it puts
# her weight over her lift, so she floats there level — the research's 0.2° by the
# stern is within the gate of level. Her steel's height is settled too, so that her GM
# is the night's 0.80 m (the research's); the height it takes is printed.
with open("data/physics/sea.tres") as sea_file:
    SEA_DENSITY = float(re.search(r"^sea_density = (\S+)$", sea_file.read(), re.M).group(1))
GM = 0.80
displaced = along = across_z = upward = inertia = 0.0
for x, length, outline in sections:
    under = clip(outline, 1, WATERLINE, True)
    if len(under) >= 3:
        area, z, y = area_and_centre(under)
        displaced += area * length
        along += area * length * x
        across_z += area * length * z
        upward += area * length * y
        line = [p[0] for p in under if abs(p[1] - WATERLINE) < 1e-6]
        if len(line) >= 2:
            inertia += length * (max(line) ** 3 - min(line) ** 3) / 3.0
weight = displaced * SEA_DENSITY
km = upward / displaced + inertia / displaced
MASS = [  # (name, kg, centre, (from x, to x)); centre y None for her steel's, settled
    ("hull steel", 26000e3, (-2.0, None, 0.0), (X_AP, X_FP)),
    ("boilers and their water", 4500e3, (25.0, TANK_TOP + 4.8, 0.0), (BX["K"], BX["D"])),
    ("engines, turbine and condensers", 3200e3, (-45.0, ENGINE_TANK_TOP + 4.5, 0.0), (BX["M"], BX["K"])),
    ("shafting, propellers and rudder", 600e3, (-110.0, KEEL + 3.0, 0.0), (X_AP, BX["M"])),
    ("electric plant", 300e3, (-75.6, TANK_TOP + 2.0, 0.0), (BX["N"], BX["M"])),
    ("accommodation and outfit", 6500e3, (-5.0, 2.5, 0.0), (-125.0, 125.0)),
    ("coal", 3500e3, (25.0, TANK_TOP + 4.0, 0.0), (BX["K"], BX["D"])),
    ("fresh water and stores", 1500e3, (-20.0, G_DECK, 0.0), (-110.0, 100.0)),
    ("cargo and mail", 600e3, (40.0, ORLOP, 0.0), (-119.0, 116.0)),
    ("passengers, crew and baggage", 250e3, (0.0, 3.0, 0.0), (-120.0, 120.0)),
]
BALLAST_Y = KEEL + 0.8
BALLAST_REACH = 15.0  # either side of its centre
ballast = weight - sum(m[1] for m in MASS)
ballast_x = (weight * along / displaced - sum(m[1] * m[2][0] for m in MASS)) / ballast
ballast_z = (weight * across_z / displaced - sum(m[1] * m[2][2] for m in MASS)) / ballast
assert ballast > 0, "she is heavier than she floats"
assert cell_at(ballast_x, BALLAST_Y, ballast_z), "her solved ballast must lie in one of her cells"
steel = MASS[0]
rest_moment = sum(m[1] * m[2][1] for m in MASS[1:]) + ballast * BALLAST_Y
steel_y = (weight * (km - GM) - rest_moment) / steel[1]
MASS[0] = (steel[0], steel[1], (steel[2][0], round(steel_y, 4), steel[2][2]), steel[3])
MASS.append(("water ballast", round(ballast, 1), (round(ballast_x, 4), BALLAST_Y, round(ballast_z, 4)),
             (round(ballast_x - BALLAST_REACH, 4), round(ballast_x + BALLAST_REACH, 4))))
# How her mass turns, the water moving with her, and how her motions die away (est.:
# roll 0.4 of her beam, pitch 0.25 of her length; the steamer's added mass and damping).
MOTION = [("roll_radius", round(0.4 * 2 * HALF, 2)), ("pitch_radius", round(0.25 * (X_FORE - X_AFT), 1)),
          ("added_mass", 1.0), ("heave_damping", 0.5), ("roll_damping", 0.08), ("pitch_damping", 0.5)]
# Her twenty boats (BOT): fourteen lifeboats and two emergency cutters on davits, eight
# a side in two groups where Plate III draws them (SB-III), odd numbers to starboard;
# collapsibles C and D under the forward davits, A and B on the officers' house's roof.
# Est.: each useless on the high side past 15° of list — old davits. Her davits' stations
# (DAVITS) are her boats' on chocks', with the boat deck's gear.
LIFEBOATS = []
for k, x in enumerate(DAVITS):
    LIFEBOATS += [("boat_%d" % (2 * k + 1), 1, x, 15.0), ("boat_%d" % (2 * k + 2), -1, x, 15.0)]
LIFEBOATS += [("collapsible_a", 1, 62.0, 15.0), ("collapsible_b", -1, 62.0, 15.0),
              ("collapsible_c", 1, DAVITS[0], 15.0), ("collapsible_d", -1, DAVITS[0], 15.0)]
# What the sinking fails (§5b.1, est.): her four funnels on the boat deck, stayed to 28°
# of list and 15° of trim, each down in 3 s; her four main generating sets aft in their
# own compartment by the turbine room (BOT: "a separate watertight compartment about 63
# ft. long ... at the level of the inner bottom"), drowned by 1 m of water over their
# feet, stopped past 22.5° of list (SOLAS, rolling) or 15° of trim and running again 3°
# back within both; her two 30 kW emergency sets (BOT: "on a platform in the turbine
# engine room casing on saloon deck level"), steam-fed from her boiler rooms, est. a
# minute of steam in their pipes once the mains stop — her lights went as she broke, the
# night's did within a couple of minutes of it (the research's gate) —, lighting her passages, stairways and boat deck (BOT: "500 incandescent lamps
# ... at the end of passages, and near stairways, also on the Boat deck").
FUNNELS_FIT = [dict(name="funnel_%d" % (k + 1), base=(x, FUNNEL_FOOT, 0.0), height=FUNNEL_TOP - FUNNEL_FOOT,
                    radius=FUNNEL_RADIUS, list=28.0, trim=15.0, fall=3.0) for k, x in enumerate(FUNNELS)]
GENERATOR = dict(name="generators", base=(-75.6, TANK_TOP, 0.0), drowns=1.0, list=22.5, trim=15.0, recovers=3.0,
                 minutes=1.0, emergency=["staircase_house", "officers_house", "a_deck", "b_deck", "c_deck", "d_deck"])
GENERATOR["cell"] = cell_at(GENERATOR["base"][0], GENERATOR["base"][1] + 0.01, GENERATOR["base"][2])
# A cell a sister's bulkhead cut is lit in every piece of it.
GENERATOR["emergency"] = [c[0] for name in GENERATOR["emergency"] for c in CELLS
                          if c[0] == name or c[0].rpartition("_")[0] == name and c[0].rpartition("_")[2].isdigit()]
# Her pumps (BOT): five ballast and bilge pumps of 250 tons an hour and three bilge pumps
# of 150 — three of the first in three boiler rooms (est. 5, 3 and 1), two ballast and
# two bilge pumps in the reciprocating engine room, a bilge pump in the turbine room.
BIG, SMALL = 250e3 / SEA_DENSITY / 3600, 150e3 / SEA_DENSITY / 3600
PUMPS = []
for name, x, rate in [("pump_br5", 44.0, BIG), ("pump_br3", 9.0, BIG), ("pump_br1", -24.0, BIG),
                      ("ballast_pump_p", -40.0, BIG), ("ballast_pump_s", -36.0, BIG),
                      ("bilge_pump_p", -44.0, SMALL), ("bilge_pump_s", -32.0, SMALL),
                      ("bilge_pump_turbine", -57.0, SMALL)]:
    PUMPS.append((name, cell_at(x, TANK_TOP + 0.5, 0.0), round(rate, 5)))
# The bending her hull carries (§5b.1, the research after the Marine Forensics Panel):
# 4.6 GN·m hogging where she failed, at boiler rooms 1–2 (± 15 %); sagging est. at the
# steamer's ratio. She can break where she failed, over boiler room 2 where her flooded
# bow bends her most (x −7.5 m, 138 m from her stem), keeping est. 0.93 of it — 4.28
# GN·m, inside the research's ± 15 % — and at her two expansion joints, which keep its
# whole (est.: nothing in the plates or the research weakens them further).
STRENGTH = (4.6e9, 4.6e9 * 110 / 120)
WEAK_SPOTS = sorted([(name, x, 1.0) for name, x in JOINTS] + [("boiler_rooms_1_2", -7.5, 0.93)],
                    key=lambda spot: spot[1])
# Where along her and up her shell an iceberg's gash can be at all (est.): clear of her
# stem and her rudder post, from 0.2 m over her keel to 0.2 m under C deck.
HIT_ZONE_X = (X_AP + 4.0, X_FP - 2.0)
HIT_ZONE_Y = (KEEL + 0.2, -0.2)
# The must-sink rule's last rung (§5b.1, est.): an 85 m gash down her starboard side from
# boiler room 4 to No. 1 hold, 5 m under her waterline, 25 mm as one even slit (2.1 m²)
# and biting 1.5 m in, every door and porthole shut. `make ship-check` proves she
# founders on it within the bake's cap.
SURE_HIT = [("start_x", 30), ("length", 85), ("depth_start", 5), ("depth_end", 5), ("width", 0.025),
            ("bite", 1.5)]

def vec3(v):
    return "Vector3(%s, %s, %s)" % tuple(num(c) for c in v)

def names(items):
    return "Array[StringName]([%s])" % ", ".join('&"%s"' % i for i in items)

section_ids = []
for i, (x, length, outline) in enumerate(sections):
    flat = ", ".join("%s, %s" % (num(z), num(y)) for z, y in outline)
    section_ids.append(sub("Section_%d" % i, "10_section", [
        ("x", num(x)), ("length", num(length)), ("outline", "PackedVector2Array(%s)" % flat)]))
AIR_LEAK = 1e-6  # 10⁻³ m² per 1 000 m³ (est.), as every ship's
# A box her sections fill but for their outlines' simplifying (OUTLINE_TOLERANCE) and
# their ends' rounding is whole: a cell under 1 pokes out of her (CellMap), each point of
# it asked whether her hull holds it, and that by the luck of the fourth decimal.
SHAPE_WHOLE = 0.9999
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
    fill = inside / box_volume
    f.append(("shape", num(1.0 if fill >= SHAPE_WHOLE else fill)))
    if inner:
        f.append(("rooms", names(inner)))
    f.append(("leak_area", ("%.8f" % float("%.3g" % (inside * AIR_LEAK))).rstrip("0")))
    cell_ids.append(sub("Cell_" + name, "11_cell", f))
wall_ids = []
for name, axis, at, span, bottom_y, top, collapse, parts in walls:
    f = [("name", '&"%s"' % name)]
    if axis == "ALONG":
        f.append(("axis", "1"))
    f += [("at", num(at)), ("span", "Vector2(%s, %s)" % (num(span[0]), num(span[1]))),
          ("bottom", num(bottom_y)), ("top", num(top)), ("collapse_head", num(collapse)),
          ("leak_head", num(collapse / 1.5 * 1.25)), ("leak_area", num(WALL_LEAK)), ("cells", names(parts))]
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
    mass_ids.append(sub("Mass_" + name.replace(" ", "_").replace(",", ""), "14_mass", [
        ("name", '&"%s"' % name), ("mass", num(kg)), ("centre", vec3(centre)),
        ("along", "Vector2(%s, %s)" % (num(reach[0]), num(reach[1])))]))
fitting_ids = []
for name, side, x, limit in LIFEBOATS:
    f = [("name", '&"%s"' % name)]
    if side != 1:
        f.append(("side", str(side)))
    f += [("x", num(x)), ("list_limit_deg", num(limit))]
    fitting_ids.append(sub("Fitting_" + name, "16_fitting", f))
for funnel in FUNNELS_FIT:
    fitting_ids.append(sub("Fitting_" + funnel["name"], "16_fitting", [
        ("kind", "1"), ("name", '&"%s"' % funnel["name"]), ("x", num(funnel["base"][0])),
        ("list_limit_deg", num(funnel["list"])), ("trim_limit_deg", num(funnel["trim"])),
        ("base", vec3(funnel["base"])), ("height", num(funnel["height"])),
        ("radius", num(funnel["radius"])), ("fall_time", num(funnel["fall"]))]))
fitting_ids.append(sub("Fitting_" + GENERATOR["name"], "16_fitting", [
    ("kind", "2"), ("name", '&"%s"' % GENERATOR["name"]), ("x", num(GENERATOR["base"][0])),
    ("list_limit_deg", num(GENERATOR["list"])), ("trim_limit_deg", num(GENERATOR["trim"])),
    ("base", vec3(GENERATOR["base"])), ("drowns_at", num(GENERATOR["drowns"])),
    ("recovers_deg", num(GENERATOR["recovers"])),
    ("emergency_minutes", num(GENERATOR["minutes"])),
    ("emergency_cells", names(GENERATOR["emergency"])), ("cell", '&"%s"' % GENERATOR["cell"])]))
for name, cell_name, rate in PUMPS:
    fitting_ids.append(sub("Fitting_" + name, "16_fitting", [
        ("kind", "3"), ("name", '&"%s"' % name), ("cell", '&"%s"' % cell_name), ("rate", num(rate))]))
spots = [sub("Weak_" + name, "18_weak", [("name", '&"%s"' % name), ("x", num(x)), ("share", num(share))])
         for name, x, share in WEAK_SPOTS]
sub("Structure", "9_structure", [
    ("waterline_y", num(WATERLINE)), ("keel_y", num(KEEL)),
    ("sections", arr("10_section", section_ids)), ("cells", arr("11_cell", cell_ids)),
    ("walls", arr("12_wall", wall_ids)), ("openings", arr("13_opening", opening_ids)),
    ("mass", arr("14_mass", mass_ids))] + [(k, num(v)) for k, v in MOTION] + [
    ("fittings", arr("16_fitting", fitting_ids)),
    ("strength", 'SubResource("%s")' % sub("Strength", "17_strength", [
        ("hog", num(STRENGTH[0])), ("sag", num(STRENGTH[1])), ("weak", arr("18_weak", spots))])),
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
    posts = max(1, math.ceil(math.hypot(b[0] - a[0], b[1] - a[1]) / POST - 1e-9))  # as Godot's float32 spans count
    t = (math.floor((posts - 1) * 0.5) + 0.5) / posts
    at = (a[0] + (b[0] - a[0]) * t, h, a[1] + (b[1] - a[1]) * t)
    # Never behind a boat stowed at the deck's edge (STOWED_BOAT), where no hand reaches it.
    assert all(abs(at[0] - d) > STOWED_BOAT[0] / 2 + 0.5 for d in DAVITS) or abs(h - BOAT) > 1e-6, \
        "a lifebuoy at %s hangs behind a boat" % (at,)
    f = [("kind", '&"lifebuoy"'), ("railing", str(k)), ("pos", "Vector3(%s, %s, %s)" % tuple(num(c) for c in at))]
    f += [(field, num(v)) for field, v in LIFEBUOY]
    props.append(sub("Lifebuoy_%d" % sum(1 for p in props if p.startswith("Lifebuoy_")), "8_prop", f))

# On the boat deck's open stretches, clear of her boats: amidships either side, and to
# starboard forward of her boats, abreast the wheelhouse, where her side is the deck's.
lifebuoy(-30.5, -1, 8.375)
lifebuoy(-25.5, 1, 8.375)
lifebuoy(6.0, -1, 8.375)
lifebuoy(66.5, 1, 8.375)

# Her laid tables (LAID), each a round table and a chair at each quarter facing it, the
# chair CHAIR_GAP clear of the table so that nothing stands in anything as she sails —
# props of their own (data/props/dining_table.tres, dining_chair.tres): each slides as the
# deck tilts past its grip, gives way to a body walking into it and floats on her water.
# A table's mass and grip are a dining table's of oak; a chair's a bentwood chair's.
DINING_TABLE = [("radius", 0.55), ("height", 0.75), ("mass", 45), ("grip_angle_deg", 22), ("friction", 7)]
DINING_CHAIR = [("radius", 0.25), ("height", 0.9), ("mass", 6), ("grip_angle_deg", 20), ("friction", 6.5)]
CHAIR_GAP = 0.02
LAID_REACH = 0.55 + CHAIR_GAP + 2 * 0.25  # from a table's middle to its chairs' backs

def laid_problems(tid, x, floor, z):
    """Every way a laid table and its chairs, a square LAID_REACH about its middle, break
    the rules the room's pieces keep: out of its room, by a doorway or a stair, on a
    blocker, or by a seat's start."""
    return piece_problems(("laid_" + tid, x - LAID_REACH, x + LAID_REACH, z - LAID_REACH, z + LAID_REACH,
                           floor, floor + 0.9))

def furniture(kind, name, at, fields, facing=0.0):
    f = [("kind", '&"%s"' % kind), ("pos", "Vector3(%s, %s, %s)" % tuple(num(c) for c in at))]
    f += [(field, num(v)) for field, v in fields]
    if facing:
        f.append(("facing_deg", num(facing)))
    props.append(sub(name, "8_prop", f))

# The à la carte restaurant's (B_PLAN) and the dining saloons' (D_PLAN), 3 m apart over
# each of their rectangles, on the grid of those shifted a quarter pitch at a time each way
# under which the most keep every rule.
for tag, floor, rects in [("restaurant", B_DECK, b_rooms("à la carte restaurant")),
                          ("saloon_1", D_DECK, d_rooms("first-class dining saloon")),
                          ("saloon_2", D_DECK, d_rooms("second-class dining saloon"))]:
    for k, (_n, x0, x1, z0, z1) in enumerate(rects):
        best = []
        for sx in SHIFTS:
            for sz in SHIFTS:
                grid = [(x, z) for x in lattice(x0, x1, 3.0, sx) for z in lattice(z0, z1, 3.0, sz)]
                laid = [("%s_%d_%d" % (tag, k, i), x, floor, z) for i, (x, z) in enumerate(grid)]
                laid = [t for t in laid if not laid_problems(*t)]
                if len(laid) > len(best):
                    best = laid
        LAID.extend(best)

_laid = [problem for laid in LAID for problem in laid_problems(*laid)]
assert not _laid, "\n".join(_laid)
for tid, x, floor, z in LAID:
    furniture("dining_table", "Table_" + tid, (x, floor, z), DINING_TABLE)
    off = 0.55 + CHAIR_GAP + 0.25
    for tag, dx, dz, facing in [("px", off, 0.0, 180), ("mx", -off, 0.0, 0), ("pz", 0.0, off, -90),
                                ("mz", 0.0, -off, 90)]:
        furniture("dining_chair", "Chair_%s_%s" % (tid, tag), (x + dx, floor, z + dz), DINING_CHAIR, facing)

# Her bonus spots (#312): one in each room below her main deck — a room whose floor
# stands under zero — where a bonus can come aboard, at the free point of its floor
# nearest its middle (tools/floor_spots.py), naming the room by its index among hers.
bonus_spots = []
for k, at in spots_below_decks(room_geo, plat_geo, ramp_geo, block_geo):
    f = [("point", "Vector3(%s, %s, %s)" % tuple(num(c) for c in at)), ("room", str(k))]
    bonus_spots.append(sub(rooms[k].replace("Room_", "BonusSpot_", 1), "19_spot", f))

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
[ext_resource type="Script" path="res://core/ship_bonus_spot.gd" id="19_spot"]
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
       "bonus_spots = " + arr("19_spot", bonus_spots),
       "dressed = false",
       # Her hull black to B deck, her superstructure's side white over it (est., the photographs).
       "white_above = %r" % B_DECK,
       'structure = SubResource("Structure")']
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write(head + "\n" + "\n\n".join(subs) + "\n\n" + "\n".join(res) + "\n")
print(len(platforms), "platforms", len(ramps), "ramps", len(blockers), "blockers", len(railings), "railings", len(ladders), "ladders", len(props), "props", len(rooms), "rooms", len(bonus_spots), "bonus spots")
print(len(sections), "sections", len(CELLS), "cells", len(walls), "walls", len(openings), "openings", len(MASS),
      "masses: %.1f t, ballast %.1f t at x %.3f z %.3f; steel %.2f m over her keel for GM %.2f m"
      % (weight / 1000, ballast / 1000, ballast_x, ballast_z, steel_y - KEEL, GM))
