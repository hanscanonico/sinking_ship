#!/usr/bin/env python3
"""Writes the Titanic's layout and structure, data/ships/titanic.tres (SH34).

The layout and structure are generated: change her here, then `make ship SHIP=titanic`.
`make ship-check` (part of `make verify`) fails when the committed .tres is not what
this writes, so a hand edit to the .tres is caught. The sim reads only the .tres (D6).

RMS Titanic at full size, traced only from public-domain sources (R31), each traced
number beside its plate below (PLATES): her length, beam and decks, her sixteen
compartments and the bulkheads A–P between them, their tops measured off the 1911
profile (R32), her doors, her machinery, her boats. Every number not traced is marked
est. with its reasoning. She has no dressed art (SH23): her hull is lofted here from
her dimensions, and the greybox draws her from her data (ShipLayout.dressed).

Ship-local metres: x toward the bow, z to starboard, y up, origin on C deck — the
inquiry's "highest deck which extends continuously from bow to stern" — amidships.
Her decks are laid flat at their amidships heights (the inquiry's table); her sheer
lives in her bulkhead tops, her stepped forecastle and poop, and nowhere else.

`--variant=olympic1913` and `--variant=britannic` write her sisters as test-only hulls
(tests/fixtures/ships/olympic_1913.tres, britannic.tres), never in the menu's fleet: the
same hull with their bulkhead data — five bulkheads carried up to B deck and an inner
skin along her boiler and engine rooms; Britannic's a sixteenth bulkhead too.

Usage: tools/gen_titanic.py <out.tres> [--variant=olympic1913|--variant=britannic]
"""
import math
import re
import sys

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
    # perpendicular (the rudder post), heights from her drawn 34 ft 7 in waterline.
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
used = set()
# The same pieces as numbers: (x0, x1, z0, z1, height) per platform; (x0, x1, z0, z1,
# floor, name) per room; and every doorway as (axis, at, from, to, bottom): a gap in a
# wall along x = at (axis 0) or z = at (axis 2).
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

def ramp(rid, x0, x1, z0, z1, axis, start, end):
    """A stair over (x0..x1, z0..z1) rising along x (axis 0) or z (axis 1)."""
    f = [("area", rect_xz(x0, x1, z0, z1))]
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

def room(rid, name, x0, x1, z0, z1, floor):
    room_geo.append((x0, x1, z0, z1, floor, name))
    f = [("name", '&"%s"' % name), ("area", rect_xz(x0, x1, z0, z1))]
    if floor != 0.0:
        f.append(("floor_height", num(floor)))
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
# waterline (SB-III; 173 ft keel to top, "about 175 ft"), their 24 ft 6 in by 19 ft
# section as one round 3.3 m (est.).
FUNNELS = [50.2, 13.9, -22.4, -57.9]
FUNNEL_TOP = LOAD_WL + 42.2
FUNNEL_RADIUS = 3.3
# Her superstructure's runs (SB-III, SB-text): the bridge deck B 550 ft amidships, the
# forecastle 128 ft and the poop 106 ft at its height, the promenade deck A and the
# boat deck about 500 ft (BOT); the open well decks at C between them.
B_RUN = (-94.0, -94.0 + 550 * FT)
FCSL_FROM = X_FORE - 128 * FT
POOP_TO = X_AFT + 106 * FT
A_RUN = (-77.0, B_RUN[1])
BOAT_RUN = (-73.0, 74.0)
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

def breadth(x, y):
    """Her half breadth at (x, y)."""
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
    return side * fore * after

# Her forecastle and poop decks stepped to her sheer: C deck's sheer over amidships
# off Plate III (SB-III), 2.2 m at x 110 and 0.6 m at x −110, on B deck's height.
FCSL_STEP = 108.0
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

def deck(pid, name, x0, x1, z0, z1, h, holes):
    """A deck from x0 to x1 and z0 to z1 at h, as rectangles round its holes."""
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
    made = []
    for a, b, spans in pieces:
        for s0, s1 in spans:
            made.append(platform("%s_%d" % (pid, len(made)), name, a, b, s0, s1, h))
    return made

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

# --- The layout (Q11: interiors from the start, in SH3b's format). Plate III's boat and
# promenade decks and Plate IV's decks B–E give the rooms' order along her (SB-III,
# SB-IV); their sizes are est. Rooms run to the middles of their walls.
GS = (20.8, 32.9)  # the forward grand staircase, between funnels 1 and 2 (SB-III)
HOUSE_TOP = 2.625  # a deckhouse's height on the boat deck (est.)
# Holes each deck leaves for the stairs down from it.
holes = {"boat": [], "a": [], "b": [], "c": [], "d": [], "e": [], "f": [], "well": [], "aft_well": []}

# The grand staircase, boat deck to E deck: flights along x in its middle, the flights
# down from each landing alternating port and starboard of her centre line.
GS_RUN = (24.0, 28.0)
LANES = [(-3.0, -3.0 + STAIR), (1.6, 1.6 + STAIR)]
FLIGHTS = [("gs_boat_a", "boat", A_DECK, BOAT), ("gs_a_b", "a", B_DECK, A_DECK), ("gs_b_c", "b", 0.0, B_DECK),
           ("gs_c_d", "c", D_DECK, 0.0), ("gs_d_e", "d", E_DECK, D_DECK)]
for i, (sid, above, low, high) in enumerate(FLIGHTS):
    lane = LANES[i % 2]
    stair(sid, GS_RUN[0], GS_RUN[1], lane[0], lane[1], low, high, holes[above])
# Her F, E and G decks in No. 3 hold, one over the other: the post office on G deck
# (BOT: the mail room "on the Orlop deck", the sorting room over it), third-class
# berths on F, crew quarters on E (SB-IV) — each with two stairs up, the last two onto
# the forward well deck through the third-class open space on D deck.
HOLD3 = (BX["D"], BX["C"])
H3_LANDING = 84.6  # each room's forward wall, a landing before bulkhead C beyond it
H3_FLIGHTS = [  # (id, deck above, low, high, x from, x to, lane's z)
    ("g_f", "f", G_DECK, F_DECK, 79.0, 82.4, 5.0),
    ("f_e", "e", F_DECK, E_DECK, 73.0, 76.4, 6.6),
    ("e_d", "d", E_DECK, D_DECK, 76.0, 79.8, 5.0),
    ("d_well", "well", D_DECK, 0.0, 80.0, 84.2, 3.0),
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
# Britannic's alike), a stair up into the road from each; the road's own stair up to D
# deck aft, into the galley.
SR = (BX["K"], BX["E"])
SR_Z = (-13.0, -10.0)
SALOON_Z = 13.0
stair("f_sr_fwd", 10.0, 13.4, -12.6, -12.6 + STAIR, F_DECK, E_DECK, holes["e"])
stair("f_sr_aft", -8.0, -4.6, -12.6, -12.6 + STAIR, F_DECK, E_DECK, holes["e"])
stair("sr_d", -26.0, -22.2, -12.6, -12.6 + STAIR, E_DECK, D_DECK, holes["d"])
# The second-class staircase aft, D deck up to C, in the second-class dining saloon.
stair("second_class", -56.0, -52.0, 0.0, STAIR, D_DECK, 0.0, holes["c"])
# Down off her open decks, two of each, port and starboard (est.): the boat deck's aft
# end onto A deck, A deck's aft end onto B deck's open after end, B deck's onto the after
# well; A deck's forward end onto the forward well; the forecastle's and the poop's
# from their wells.
SIDE_LANE = (10.2, 10.2 + STAIR)  # outboard of A deck's house
WELL_LANE = (7.6, 7.6 + STAIR)    # inside the after well's narrower beam
for side, sign in [("p", -1), ("s", 1)]:
    lane = sorted((sign * SIDE_LANE[0], sign * SIDE_LANE[1]))
    stair("boat_aft_" + side, BOAT_RUN[0] - 4.0, BOAT_RUN[0], lane[0], lane[1], A_DECK, BOAT, [])
    stair("a_aft_" + side, A_RUN[0] - 4.0, A_RUN[0], lane[0], lane[1], B_DECK, A_DECK, [])
    stair("a_fwd_" + side, A_RUN[1] + 7.0, A_RUN[1], lane[0], lane[1], 0.0, A_DECK, [])
    lane = sorted((sign * WELL_LANE[0], sign * WELL_LANE[1]))
    stair("b_aft_" + side, B_RUN[0] - 4.0, B_RUN[0], lane[0], lane[1], 0.0, B_DECK, [])
    lane = sorted((sign * 2.0, sign * (2.0 + STAIR)))
    stair("forecastle_" + side, FCSL_FROM - 5.8, FCSL_FROM, lane[0], lane[1], 0.0, FCSL[0], [])
    stair("poop_" + side, POOP_TO + 5.5, POOP_TO, lane[0], lane[1], 0.0, POOP, [])

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
BW = fit(BOAT_RUN[0], BOAT_RUN[1], BOAT, 0.05)
boat = deck("boat", "boat deck", BOAT_RUN[0], BOAT_RUN[1], -BW, BW, BOAT, holes["boat"])
AWD = fit(A_RUN[0], A_RUN[1], A_DECK, 0.05)
a_deck = deck("a", "A deck", A_RUN[0], A_RUN[1], -AWD, AWD, A_DECK, holes["a"])
BWD = fit(B_RUN[0], B_RUN[1], B_DECK, 0.05)
b_deck = deck("b", "B deck", B_RUN[0], B_RUN[1], -BWD, BWD, B_DECK, holes["b"])
CWD = fit(B_RUN[0], B_RUN[1], 0.0, 0.05)
c_deck = deck("c", "C deck", B_RUN[0], B_RUN[1], -CWD, CWD, 0.0, holes["c"])
# D deck, her length from the turbine room's after bulkhead to No. 2 hold, narrowing
# forward with her hull.
d_deck = []
for x0, x1 in [(-64.5, 60.0), (60.0, 85.0), (85.0, 100.5)]:
    w = fit(x0, x1, D_DECK, 0.2)
    d_deck += deck("d_%d" % len(d_deck), "D deck", x0, x1, -w, w, D_DECK,
                   [h for h in holes["d"] if x0 <= h[0] < x1])
e_road = deck("e_road", "E deck", SR[0] + T, SR[1] - T, SR_Z[0], SR_Z[1], E_DECK, holes["e"])
e_landing = deck("e_landing", "E deck", GS[0], GS[1], SR_Z[1], 6.0, E_DECK, holes["e"])
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
    ends = dict(open_ends)
    for index, x, w in [(ordered[0][0], ordered[0][1], ordered[0][3]), (ordered[-1][0], ordered[-1][2], ordered[-1][3])]:
        rail_line("%s_end_%d" % (rid, int(abs(x))), [index], 0, x, -w, w, ends.get(x, ()))

FC1 = tapered("fcsl", "forecastle", FCSL_FROM, FCSL_STEP, FCSL[0], 4.0, 0.05)
FC_RAMP = (FCSL_STEP, FCSL_STEP + 3.0)
FC2 = tapered("fcsl_head", "forecastle", FC_RAMP[1], 128.0, FCSL[1], 3.0, 0.05)
fc1 = [s[0] for s in FC1]
fc2 = [s[0] for s in FC2]
FC1W = FC1[0][3]
FCRW = min(FC1[-1][3], FC2[0][3])
ramp("forecastle_step", FC_RAMP[0], FC_RAMP[1], -FCRW, FCRW, 0, FCSL[0], FCSL[1])
POOP_STRIPS = tapered("poop", "poop deck", POOP_TO, -134.0, POOP, 4.0, 0.05)
poop = [s[0] for s in POOP_STRIPS]
GENERAL = (BX["P"], POOP_TO)
GW = fit(GENERAL[0], GENERAL[1], 0.0, 0.2)
c_general = deck("c_general", "C deck", GENERAL[0], GENERAL[1], -GW, GW, 0.0, [])

# --- Railings: the open decks' edges, round their stairs' feet and heads; three sides of
# every hole a stair leaves in a deck.
rail_line("boat_port", boat, 2, -BW, BOAT_RUN[0], BOAT_RUN[1])
rail_line("boat_starboard", boat, 2, BW, BOAT_RUN[0], BOAT_RUN[1])
rail_line("boat_fwd", boat, 0, BOAT_RUN[1], -BW, BW)
rail_line("boat_aft", boat, 0, BOAT_RUN[0], -BW, BW, lanes_of("boat_aft_"))
rail_line("a_port", a_deck, 2, -AWD, A_RUN[0], A_RUN[1])
rail_line("a_starboard", a_deck, 2, AWD, A_RUN[0], A_RUN[1])
rail_line("a_fwd", a_deck, 0, A_RUN[1], -AWD, AWD, lanes_of("a_fwd_"))
rail_line("a_aft", a_deck, 0, A_RUN[0], -AWD, AWD, lanes_of("a_aft_") + [(-9.0, 9.0)])
rail_line("b_port", b_deck, 2, -BWD, B_RUN[0], A_RUN[0])
rail_line("b_starboard", b_deck, 2, BWD, B_RUN[0], A_RUN[0])
rail_line("b_aft", b_deck, 0, B_RUN[0], -BWD, BWD, lanes_of("b_aft_"))
rail_line("well_port", well, 2, -CW, WELL[0], WELL[1])
rail_line("well_starboard", well, 2, CW, WELL[0], WELL[1])
rail_line("aft_well_port", aft_well, 2, -AW, AFT_WELL[0], AFT_WELL[1])
rail_line("aft_well_starboard", aft_well, 2, AW, AFT_WELL[0], AFT_WELL[1])
rail_taper("fcsl", FC1, [(FCSL_FROM, lanes_of("forecastle_")), (FCSL_STEP, [(-FCRW, FCRW)])])
rail_taper("fcsl_head", FC2, [(FC_RAMP[1], [(-FCRW, FCRW)])])
rail_taper("poop", POOP_STRIPS, [(POOP_TO, lanes_of("poop_"))])
DECKS_AT = {BOAT: boat, A_DECK: a_deck, B_DECK: b_deck, 0.0: c_deck + well, D_DECK: d_deck,
            E_DECK: e_road + e_landing + e_crew, F_DECK: f_berths}
for name, _lo, _hi, _z0, _z1, high, _x_low in list(stairs):
    if high in DECKS_AT and not name.startswith(("boat_aft", "a_aft", "b_aft", "a_fwd")):
        hole_rails(DECKS_AT[high], name)

# --- Walls and rooms.
# The boat deck's houses (SB-III): the officers' house and the wheelhouse forward, round
# funnel 1; the grand staircase's entrance and the gymnasium between funnels 1 and 2.
OFFICERS = (40.0, 70.0, 6.0)
wall_x("officers_aft", OFFICERS[0], -OFFICERS[2], OFFICERS[2], BOAT, BOAT + HOUSE_TOP)
wall_x("wheelhouse_fwd", OFFICERS[1], -OFFICERS[2], OFFICERS[2], BOAT, BOAT + HOUSE_TOP)
wall_x("wheelhouse_aft", 63.0, -OFFICERS[2], OFFICERS[2], BOAT, BOAT + HOUSE_TOP, [door_at(0.0)])
for tag, z in [("p", -OFFICERS[2]), ("s", OFFICERS[2])]:
    wall_z("officers_" + tag, z, OFFICERS[0], OFFICERS[1], BOAT, BOAT + HOUSE_TOP,
           [door_at(44.0), door_at(58.0), door_at(66.5)])
room("officers", "officers' quarters", OFFICERS[0], 63.0, -OFFICERS[2], OFFICERS[2], BOAT)
room("wheelhouse", "wheelhouse", 63.0, OFFICERS[1], -OFFICERS[2], OFFICERS[2], BOAT)
GYM = (17.4, GS[0])
wall_x("gym_aft", GYM[0], -6.0, 6.0, BOAT, BOAT + HOUSE_TOP)
wall_x("gs_boat_aft", GS[0], -6.0, 6.0, BOAT, BOAT + HOUSE_TOP, [door_at(0.0)])
wall_x("gs_boat_fwd", GS[1], -6.0, 6.0, BOAT, BOAT + HOUSE_TOP)
for tag, z in [("p", -6.0), ("s", 6.0)]:
    wall_z("gs_house_" + tag, z, GYM[0], GS[1], BOAT, BOAT + HOUSE_TOP, [door_at(19.1), door_at(30.0)])
room("gym", "gymnasium", GYM[0], GYM[1], -6.0, 6.0, BOAT)
room("gs_boat", "grand staircase, boat deck", GS[0], GS[1], -6.0, 6.0, BOAT)
for k, x in enumerate(FUNNELS):
    cylinder("funnel_%d" % (k + 1), x, 0.0, FUNNEL_RADIUS, BOAT, FUNNEL_TOP)
cylinder("foremast", 96.0, 0.0, 0.6, FCSL[0], FCSL[0] + 40.0)       # est., SB-III
cylinder("mainmast", -92.5, 0.0, 0.6, B_DECK, B_DECK + 40.0)         # est., SB-III

# A deck's house between its promenades (SB-III): from aft the verandah café, the
# first-class smoking room, the after entrance, funnel 3's casing, the lounge, the
# reading and writing room, funnel 2's casing, the grand staircase and the cabins
# forward round funnel 1, 9 m either side of her centre line (est.).
A_HOUSE = (A_RUN[0], 68.4, 9.0)
A_ROOMS = [("verandah", "verandah café", A_RUN[0], -69.1), ("smoking", "first-class smoking room", -69.1, -45.8),
           ("aft_entrance", "after entrance", -45.8, -38.9), (None, "funnel 3's casing", -38.9, -16.4),
           ("lounge", "first-class lounge", -16.4, -0.8), ("reading", "reading and writing room", -0.8, 7.8),
           (None, "funnel 2's casing", 7.8, GS[0]), ("gs_a", "grand staircase, A deck", GS[0], GS[1]),
           (None, "cabins", GS[1], A_HOUSE[1])]
for k, (rid, name, x0, x1) in enumerate(A_ROOMS):
    if rid is None:
        box("a_block_%d" % k, x0 + T, x1 - T, -A_HOUSE[2] + T, A_HOUSE[2] - T, A_DECK, BOAT)
        continue
    room(rid, name, x0, x1, -A_HOUSE[2], A_HOUSE[2], A_DECK)
    for tag, z in [("p", -A_HOUSE[2]), ("s", A_HOUSE[2])]:
        wall_z("%s_%s" % (rid, tag), z, x0, x1, A_DECK, BOAT, [door_at((x0 + x1) * 0.5)])
wall_x("verandah_aft", A_RUN[0], -A_HOUSE[2], A_HOUSE[2], A_DECK, BOAT)
wall_x("smoking_aft", -69.1, -A_HOUSE[2], A_HOUSE[2], A_DECK, BOAT, [door_at(0.0)])
wall_x("aft_entrance_aft", -45.8, -A_HOUSE[2], A_HOUSE[2], A_DECK, BOAT, [door_at(0.0)])
wall_x("reading_aft", -0.8, -A_HOUSE[2], A_HOUSE[2], A_DECK, BOAT, [door_at(0.0)])

# B deck under A (SB-IV): the à la carte restaurant aft, a corridor forward through the
# cabins to the grand staircase; aft of it B deck's open end, its second-class
# promenade; her front across B deck's forward end.
CORRIDOR = 1.5
RESTAURANT = (A_RUN[0], -60.0, 10.0)
wall_x("b_aft_face", A_RUN[0], -BWD, BWD, B_DECK, A_DECK, [door_at(-5.0), door_at(5.0)])
wall_x("b_fwd_face", B_RUN[1], -BWD, BWD, B_DECK, A_DECK)
wall_x("restaurant_fwd", RESTAURANT[1], -RESTAURANT[2], RESTAURANT[2], B_DECK, A_DECK, [door_at(0.0)])
for tag, z in [("p", -RESTAURANT[2]), ("s", RESTAURANT[2])]:
    wall_z("restaurant_" + tag, z, RESTAURANT[0], RESTAURANT[1], B_DECK, A_DECK)
room("restaurant", "à la carte restaurant", RESTAURANT[0], RESTAURANT[1], -RESTAURANT[2], RESTAURANT[2], B_DECK)
for tag, z in [("p", -CORRIDOR), ("s", CORRIDOR)]:
    wall_z("b_corridor_" + tag, z, RESTAURANT[1], GS[0], B_DECK, A_DECK)
room("b_corridor", "B deck corridor", RESTAURANT[1], GS[0], -CORRIDOR, CORRIDOR, B_DECK)
wall_x("gs_b_aft", GS[0], -6.0, 6.0, B_DECK, A_DECK, [door_at(0.0)])
wall_x("gs_b_fwd", GS[1], -6.0, 6.0, B_DECK, A_DECK)
for tag, z in [("p", -6.0), ("s", 6.0)]:
    wall_z("gs_b_" + tag, z, GS[0], GS[1], B_DECK, A_DECK)
room("gs_b", "grand staircase, B deck", GS[0], GS[1], -6.0, 6.0, B_DECK)

# C deck under B: the grand staircase and the purser's office, a corridor aft to the
# bridge deck's after face and the after well (SB-IV); her bridge deck's fronts at C;
# under the poop, the third-class general room (SB-IV, "3rd class general room").
PURSER = (GS[1], 37.9)
wall_x("c_aft_face", B_RUN[0], -CWD, CWD, 0.0, B_DECK, [door_at(0.0)])
wall_x("c_fwd_face", B_RUN[1], -CWD, CWD, 0.0, B_DECK)
for tag, z in [("p", -CORRIDOR), ("s", CORRIDOR)]:
    wall_z("c_corridor_" + tag, z, B_RUN[0], GS[0], 0.0, B_DECK)
room("c_corridor", "C deck corridor", B_RUN[0], GS[0], -CORRIDOR, CORRIDOR, 0.0)
wall_x("gs_c_aft", GS[0], -6.0, 6.0, 0.0, B_DECK, [door_at(0.0)])
wall_x("gs_c_fwd", GS[1], -6.0, 6.0, 0.0, B_DECK, [door_at(0.0)])
wall_x("purser_fwd", PURSER[1], -6.0, 6.0, 0.0, B_DECK)
for tag, z in [("p", -6.0), ("s", 6.0)]:
    wall_z("gs_c_" + tag, z, GS[0], PURSER[1], 0.0, B_DECK)
room("gs_c", "grand staircase, C deck", GS[0], GS[1], -6.0, 6.0, 0.0)
room("purser", "purser's office", PURSER[0], PURSER[1], -6.0, 6.0, 0.0)
wall_x("forecastle_face", FCSL_FROM, -CW, CW, 0.0, FCSL[0])
wall_x("poop_face", POOP_TO, -AW, AW, 0.0, POOP, [door_at(0.0)])
wall_x("general_aft", GENERAL[0], -GW, GW, 0.0, POOP)
for tag, z in [("p", -GW), ("s", GW)]:
    wall_z("general_" + tag, z, GENERAL[0], POOP_TO, 0.0, POOP)
room("general", "third-class general room", GENERAL[0], POOP_TO, -GW, GW, 0.0)

# D deck (SB-IV): from aft the second-class dining saloon, a corridor, the galley, the
# first-class dining saloon and the reception room at the grand staircase's foot, a
# corridor forward through the cabins to the third-class open space under the well.
D_ROOMS = [("saloon_2", "second-class dining saloon", -64.0, -49.0, -12.5, 12.5),
           ("d_corridor", "D deck corridor", -49.0, -30.0, -CORRIDOR, CORRIDOR),
           ("galley", "galley", -30.0, -13.9, -13.0, 6.0),
           ("saloon_1", "first-class dining saloon", -13.9, GS[0], -13.0, 13.0),
           ("reception", "reception room", GS[0], GS[1], -13.0, 13.0),
           ("d_corridor_fwd", "D deck corridor, forward", GS[1], B_RUN[1], -CORRIDOR, CORRIDOR),
           ("open_space", "third-class open space", B_RUN[1], 99.0, -8.0, 8.0)]
for k, (rid, name, x0, x1, z0, z1) in enumerate(D_ROOMS):
    room(rid, name, x0, x1, z0, z1, D_DECK)
    wall_z(rid + "_p", z0, x0, x1, D_DECK, 0.0)
    wall_z(rid + "_s", z1, x0, x1, D_DECK, 0.0)
    if k == 0:
        wall_x(rid + "_aft", x0, z0, z1, D_DECK, 0.0)
    nz0, nz1 = (D_ROOMS[k + 1][4], D_ROOMS[k + 1][5]) if k + 1 < len(D_ROOMS) else (z0, z1)
    wall_x(rid + "_fwd", x1, min(z0, nz0), max(z1, nz1), D_DECK, 0.0,
           [] if k + 1 == len(D_ROOMS) else [door_at(0.0)])

# E deck: Scotland Road and the grand staircase's foot beside it.
wall_z("road_out", SR_Z[0], SR[0], SR[1], E_DECK, D_DECK)
wall_z("road_in", SR_Z[1], SR[0], SR[1], E_DECK, D_DECK, [door_at(26.9)])
wall_x("road_aft", SR[0], SR_Z[0], SR_Z[1], E_DECK, D_DECK)
wall_x("road_fwd", SR[1], SR_Z[0], SR_Z[1], E_DECK, D_DECK)
# One room for each stretch of it between the bulkheads whose tops rise over its floor,
# as her cells are cut there (below): open into each other.
ROAD = [(SR[0], BX["J"], "boiler room 1"), (BX["J"], BX["G"], "boiler rooms 2 and 3"),
        (BX["G"], BX["F"], "boiler room 4"), (BX["F"], SR[1], "boiler room 5")]
for k, (x0, x1, by) in enumerate(ROAD):
    room("road_%d" % (k + 1), "Scotland Road, " + by, x0, x1, SR_Z[0], SR_Z[1], E_DECK)
wall_x("gs_e_aft", GS[0], SR_Z[1], 6.0, E_DECK, D_DECK)
wall_x("gs_e_fwd", GS[1], SR_Z[1], 6.0, E_DECK, D_DECK)
wall_z("gs_e_s", 6.0, GS[0], GS[1], E_DECK, D_DECK)
room("gs_e", "grand staircase, E deck", GS[0], GS[1], SR_Z[1], 6.0, E_DECK)

# F deck: the third-class dining saloons either side of bulkhead H, a watertight door
# between them (BOT: "On both the F and E decks nearly all the bulkheads had watertight
# doors").
wall_x("saloons_aft", BX["J"], -SALOON_Z, SALOON_Z, F_DECK, E_DECK)
wall_x("saloons_middle", BX["H"], -SALOON_Z, SALOON_Z, F_DECK, E_DECK, [door_at(0.0)])
wall_x("saloons_fwd", BX["G"], -SALOON_Z, SALOON_Z, F_DECK, E_DECK)
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
    wall_x(rid + "_landing", h3_floor[1], -w, w, h, top)
    for tag, z in [("p", -w), ("s", w)]:
        wall_z("%s_%s" % (rid, tag), z, h3_floor[0], h3_floor[1], h, top)

# The forward well's cargo hatch to starboard, its cover a hop up (est., SB-III's No. 2
# hatch).
WELL_HATCH = (76.0, 79.0, 3.0, 7.0)
box("well_hatch", *WELL_HATCH, 0.0, 0.8)

# Sixteen seats across her decks (SH21 takes more): six on the boat deck and one on her
# bridge, two on A deck's promenade, one on B deck's open end, one on each well deck,
# the forecastle and the poop, one in the first-class dining saloon, facing forward to the
# grand staircase's foot.
spawns = [
    (60.0, BOAT, 9.5), (60.0, BOAT, -9.5), (5.0, BOAT, 9.5), (5.0, BOAT, -9.5), (-40.0, BOAT, 9.5),
    (-40.0, BOAT, -9.5), (72.0, BOAT, 0.0), (-68.0, BOAT, 0.0),
    (45.0, A_DECK, 11.5), (-20.0, A_DECK, -11.5), (-85.0, B_DECK, 5.0),
    (82.0, 0.0, 8.0), (-100.0, 0.0, -6.0), (100.0, FCSL[0], 0.0), (-115.0, POOP, 0.0),
    (-6.0, D_DECK, 1.0),
]
# The seats a match on her takes (§SH34): four to sixteen; more is SH21.
SEATS = (4, 16)

def arr(script, ids):
    return "Array[ExtResource(\"%s\")]([%s])" % (script, ", ".join('SubResource("%s")' % i for i in ids))

# --- The structure (§5b.2): her hull, her cells, her watertight walls, her openings and
# her mass. `make ship-check` floats her on it at the night's condition and sinks her
# on her sure hit. Numbers marked est. are starting values, tuned as the physics reads
# them.

# The enclosed outline's top: her shell's (top_at), the B deck under A over A deck's
# run — her plating "carried right up to the Boat deck" (BOT) —, and the houses over
# it: A deck's between its promenades, the boat deck's two. (x0, x1, half, foot, top).
A_HOUSE_TOP = (A_RUN[0], A_HOUSE[1], A_HOUSE[2] + T, A_DECK, BOAT)
HOUSES = [A_HOUSE_TOP, (OFFICERS[0] - T, OFFICERS[1] + T, 6.0 + T, BOAT, BOAT + HOUSE_TOP),
          (GYM[0] - T, GS[1] + T, 6.0 + T, BOAT, BOAT + HOUSE_TOP)]

def shell_top(x):
    return A_DECK if A_RUN[0] <= x <= A_RUN[1] else top_at(x)

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
    up, down = [], []
    for x0, x1, half, foot, roof in HOUSES:
        if x0 < x < x1:
            up += [(half, foot), (half, roof)]
            down = [(-half, roof), (-half, foot)] + down
    points += up + down + [(-z, y) for z, y in reversed(side)]
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
# superstructure and houses, none standing for more than the longest stretch that
# makes forty of them.
SECTION_COUNT = 40
SECTION_BREAKS = sorted({round(v, 4) for v in [X_AFT, X_FORE, FCSL_FROM, FCSL_STEP, POOP_TO, B_RUN[0], B_RUN[1],
                                               A_RUN[0], A_HOUSE[1]] + [x for x0, x1, *_r in HOUSES[1:] for x in (x0, x1)]
                         + [b[1] for b in BULKHEADS]})

def section_spans(longest):
    return sum(math.ceil((b - a) / longest - 1e-9) for a, b in zip(SECTION_BREAKS, SECTION_BREAKS[1:]))

SECTION_MAX = next(m / 100 for m in range(4000, 100, -1) if section_spans(m / 100) >= SECTION_COUNT)
sections = []  # (x, length, outline)
for a, b in zip(SECTION_BREAKS, SECTION_BREAKS[1:]):
    count = math.ceil((b - a) / SECTION_MAX - 1e-9)
    for k in range(count):
        length = (b - a) / count
        x = round(a + length * (k + 0.5), 4)
        sections.append((x, round(length, 4), section_outline(x)))
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
# The firemen's passage, from the foot of the spiral stairs in No. 2 hold aft through
# No. 3 to boiler room 6 (Wilding: "the spiral stair"; BOT: its side "3 1/2 ft from the
# outer skin of the ship", in No. 2 hold): est. 2 m wide and 8 ft high, its starboard
# side 3 ft 6 in inside her shell at its middle height in No. 2 hold.
PASSAGE_TOP = q(TANK_TOP + 8.0 * FT)
PASSAGE_Z = (round(breadth(94.0, (TANK_TOP + PASSAGE_TOP) * 0.5) - 3.5 * FT - 2.0, 4),
             round(breadth(94.0, (TANK_TOP + PASSAGE_TOP) * 0.5) - 3.5 * FT, 4))
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
cell("b_deck", A_RUN[0], B_RUN[1], B_DECK, A_DECK, -HALF, HALF, "ACCOMMODATION")
for name, (x0, x1, half, foot, roof) in zip(["a_deck", "officers_house", "staircase_house"], HOUSES):
    cell(name, x0, x1, foot, roof, -half, half, "ACCOMMODATION")

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
for letter in "CDEFGJ":
    across("wtd_f_" + letter.lower(), "WATERTIGHT_DOOR", BX[letter], F_DECK + LINTEL * 0.5, -6.0, LINTEL, DOOR,
           starts="OPEN")
for letter in "KLMNO":
    across("wtd_e_" + letter.lower(), "WATERTIGHT_DOOR", BX[letter], E_DECK + LINTEL * 0.5, -6.0, LINTEL, DOOR,
           starts="OPEN")
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
    if key in merged:
        merged[key][1] += (d1 - d0) * LINTEL
        continue
    centre = (face, foot + LINTEL * 0.5, middle) if axis == 0 else (middle, foot + LINTEL * 0.5, face)
    size = (0, LINTEL, d1 - d0) if axis == 0 else (d1 - d0, LINTEL, 0)
    merged[key] = [centre, (d1 - d0) * LINTEL, size]
for (a, b, axis, face, foot), (centre, area, size) in merged.items():
    if axis == 0 and face in bulkhead_x and b is not None:
        opening("wtd_%s_%s" % (a, b), "WATERTIGHT_DOOR", a, b, centre, size, starts="OPEN")
        continue
    tag = "door_%s_%s" % (a, b or SKY)
    single = abs(area - size[1] * (size[0] + size[2])) < 1e-6
    opening("%s_%d" % (tag, sum(1 for o in openings if o[0].startswith(tag))), "DOOR", a, b, centre, size,
            area=0.0 if single else area, starts="OPEN")
# The forecastle's doors onto the forward well, shut and dogged (est., as the steamer's
# deck breaks'): weeping 0.01 m² under 1 m of water over their sill, gone under 2 m.
opening("door_forecastle", "DOOR", "forecastle", SKY, (FCSL_FROM, 0.06 + 0.75, 6.0), (0, 1.5, 0.75),
        starts="SHUT", leak_head=1.0, collapse_head=2.0, leak_area=0.01)
opening("open_d_deck", "OPEN", piece("d_deck", B_RUN[1] - 0.01), "d_deck_forward", (B_RUN[1], D_DECK * 0.5, 0.0),
        (0, -D_DECK, 2 * fit(B_RUN[1] - 0.5, B_RUN[1] + 0.5, D_DECK, 0.0)), starts="OPEN")
opening("open_forecastle", "OPEN", "forecastle", "forecastle_head", (FCSL_STEP, FCSL[0] * 0.5, 0.0),
        (0, FCSL[0], 2 * fit(FCSL_STEP - 0.5, FCSL_STEP, FCSL[0] * 0.5, 0.0)), starts="OPEN")

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
        through("pipe_" + c[0], "VENT", (c[1] + c[2]) * 0.5, -5.0, 0.09, 0.09, c[0], area=AIR_PIPE, starts="OPEN")
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
for name, x in [("after_hold_fwd_d", -98.0), ("after_hold_aft_d", -103.8)]:
    through("hatch_" + name, "HATCH", x, 0.0, 2.5, 3.0, name, SKY, starts="SHUT", leak_head=0.3,
            collapse_head=1.0, leak_area=0.05)
x0, x1, z0, z1 = WELL_HATCH
through("hatch_well", "HATCH", (x0 + x1) * 0.5, (z0 + z1) * 0.5, x1 - x0, z1 - z0, "d_deck_forward", SKY, starts="SHUT",
        leak_head=0.3, collapse_head=1.0, leak_area=0.05)
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
    xm, zm = (x0 + x1) * 0.5, (z0 + z1) * 0.5
    below = cell_at(xm, high - 0.01, zm)
    above = cell_at(xm, high + 0.01, zm)
    if below != above and below is not None:
        opening("stair_%s" % name, "STAIRWELL", below, above, (xm, high, zm), (x1 - x0, 0, z1 - z0), starts="OPEN")
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
    for side, sign in [("p", -1), ("s", 1)]:
        if (sign < 0 and c[5] > -HALF + 1e-6) or (sign > 0 and c[6] < HALF - 1e-6):
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
# Est.: each useless on the high side past 15° of list — old davits.
DAVITS = [60.5, 50.2, 40.0, 29.7, -38.7, -48.5, -57.6, -67.1]  # SB-III, forward to aft
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
# engine room casing on saloon deck level"), steam-fed, est. 15 minutes once the mains
# stop, lighting her passages, stairways and boat deck (BOT: "500 incandescent lamps
# ... at the end of passages, and near stairways, also on the Boat deck").
FUNNELS_FIT = [dict(name="funnel_%d" % (k + 1), base=(x, BOAT, 0.0), height=FUNNEL_TOP - BOAT,
                    radius=FUNNEL_RADIUS, list=28.0, trim=15.0, fall=3.0) for k, x in enumerate(FUNNELS)]
GENERATOR = dict(name="generators", base=(-75.6, TANK_TOP, 0.0), drowns=1.0, list=22.5, trim=15.0, recovers=3.0,
                 minutes=15.0, emergency=["staircase_house", "officers_house", "a_deck", "b_deck", "c_deck", "d_deck"])
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
# steamer's ratio. She can break at her two expansion joints, which keep its whole.
STRENGTH = (4.6e9, 4.6e9 * 110 / 120)
WEAK_SPOTS = [(name, x, 1.0) for name, x in JOINTS]
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
      "masses: %.1f t, ballast %.1f t at x %.3f z %.3f; steel %.2f m over her keel for GM %.2f m"
      % (weight / 1000, ballast / 1000, ballast_x, ballast_z, steel_y - KEEL, GM))
