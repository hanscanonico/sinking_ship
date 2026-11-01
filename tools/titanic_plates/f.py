"""F deck, the middle deck, as Plate V draws it ("Middle Dk F"): The Shipbuilder, June
1911, leaf n320 (plates.tsv).

Read in the plate's own pixels, as deck.py says. Where the plate and a body disagree,
the comment beside the piece says what was changed and why. The plate's doors are swings
drawn over unbroken wall lines: a door stands at its swing. A room's side against her
hull is on the hull's double line's middle at the room's middle, read to a 7 px lattice
so that rooms side by side along her curving side keep walls of their own.

The plate draws the Olympic. F deck held, from forward (BOT, "Decks and Accommodation"):
the third watch of 53 firemen; third class in the next three watertight compartments,
over 147 ft; the swimming bath and the linen rooms; stewards to port and the Turkish
bath to starboard; the two third-class dining saloons; the third-class stewards, galley
and pantries; the engineers alongside the reciprocating engine casing; 64 second-class
staterooms in the next three compartments; third class aft. The plate draws all of it.
For the Titanic, The Shipbuilder (vol. VI (1911-12), "The White Star Liner Titanic", p.
224) says only that "on the remaining decks the number of staterooms has been
increased", and draws no deck below B, so this is the plate's.

The plate draws no watertight door through any bulkhead on this deck (E deck's plate
draws them as crosses on the line), and every bulkhead line whole but D's (H's runs on
under the working passage's ladderway, drawn over it). D's two openings, by the forward
well's ladderways and into the racquet court's stairway, are the doors through a
bulkhead here (see DOORS). The flights down from E deck are E deck's file's (e.py); this
file's STAIRS are the flights from F deck down to G, each over the foot G deck's plate
draws (g.py).
"""
PLATE = "V"
CROP = (440, 460, 10400, 1620)

# Calibrated piecewise on the watertight bulkheads the view draws, at the generator's
# BULKHEADS (tools/gen_titanic.py), each read where its line crosses her centre line
# (the mean of its port and starboard readings: the scan is turned 0.47 degrees), and on
# her ends at this height: her stern, F deck being under her counter's knuckle, on her
# rudder post's line (X_AP), and her stem (gen_titanic.py's stem_x). The view is
# 0.0255-0.0262 m a pixel but between H and E: it draws G-F 1.8 m longer than the orlop
# view does, and H-G and F-E shorter, so G reads 1.32 m and F 1.41 m off where their
# neighbours would put them (Plate III's elevation steps G aft to 18.32 between F and E
# decks, and draws M at -66.03 and B at 99.28 there). Her stern reads 0.08 m from where
# O-N's scale carries it, her stem 0.36 m from C-A's. No bulkhead P is drawn here, its
# place falling in the stern rooms' passages; B is drawn at px 9245, 99.65 m by C and A,
# 2.20 m aft of BULKHEADS' 101.85, as on G deck (g.py), so it is no control.
X = [
    (465, -129.58, "her stern at F deck, the double lines' meeting: X_AP"),
    (1539.25, -101.69, "bulkhead O"),
    (2176.75, -85.14, "bulkhead N"),
    (2916.25, -66.02, "bulkhead M"),
    (3598.25, -48.63, "bulkhead L"),
    (4381.5, -27.71, "bulkhead K"),
    (4798.75, -16.75, "bulkhead J"),
    (5496.75, 1.69, "bulkhead H"),
    (6131.0, 19.18, "bulkhead G"),
    (6860.75, 36.46, "bulkhead F"),
    (7491.0, 54.01, "bulkhead E"),
    (8134.75, 70.76, "bulkhead D"),
    (8733.25, 86.30, "bulkhead C"),
    (9863.0, 115.81, "bulkhead A"),
    (10374, 129.52, "her stem at F deck, the double lines' meeting: stem_x"),
]
# The centre line as drawn, the straight line nearest it from stern to stem: the scan
# bows it 7 px either way (0.18 m), as it does her sides' midline. Across her, her
# sides' double lines' middles 1077.0 px apart from px 3800 to 6400, her parallel middle
# body, for her 92 ft moulded.
Z = dict(centre=((600, 1062.9), (10300, 983.4)), scale=0.026038)

# The deck itself: her whole length and breadth, stern to stem.
DECKS = [(465, None, 10374, None)]

ROOMS = [
    # Aft of bulkhead O, third class (BOT: "The after compartments contained third class
    # accommodation"). Her stern: a store in her run (the plate's STORE), in two steps
    # between her sides.
    ("store, F deck", 540, 1001, 620, 1120),
    ("store, F deck", 620, 959, 708.5, 1162),
    # Two four-berth rooms across her stern, a door each into the centre passages,
    # parted on her centre line (est.: the plate draws no wall between them); forward of
    # them a pair of two-berth rooms on the centre line between the two centre passages,
    # their doors in a vestibule between them (the plate's crossed swings).
    ("four-berth third-class room, F deck", 708.5, 917, 787.5, 1062),
    ("four-berth third-class room, F deck", 708.5, 1062, 787.5, 1204),
    ("passage, F deck", 787.5, 1002, 968, 1034.5),
    ("two-berth third-class room, F deck", 787.5, 1038.5, 856.5, 1078.5),
    ("vestibule, F deck", 856.5, 1038.5, 911.5, 1078.5),
    ("two-berth third-class room, F deck", 911.5, 1034.5, 968, 1078.5),
    ("passage, F deck", 787.5, 1078.5, 968, 1121.5),
    # Port, aft to forward: rooms either side of short passages from her side to the
    # centre passage, the entrance and a passage forward to bulkhead O.
    ("two-berth third-class room, F deck", 787.5, 882, 860.5, 1002),
    ("passage, F deck", 860.5, 854, 891.5, 1002),
    ("four-berth third-class room, F deck", 891.5, 826, 968, 1002),
    ("two-berth third-class room, F deck", 968, 798, 1029.5, 945),
    ("two-berth third-class room, F deck", 968, 945, 1029.5, 1002),
    ("passage, F deck", 1029.5, 777, 1061.5, 989),
    ("four-berth third-class room, F deck", 1061.5, 756, 1136.5, 935),
    ("two-berth third-class room, F deck", 1061.5, 935, 1136.5, 989),
    ("four-berth third-class room, F deck", 1136.5, 735, 1207.5, 907),
    ("four-berth third-class room, F deck", 1136.5, 907, 1207.5, 989),
    ("passage, F deck", 1207.5, 721, 1246, 909.5),
    ("six-berth third-class room, F deck", 1246, 700, 1330, 909.5),
    ("four-berth third-class room, F deck", 1330, 686, 1410, 846.5),
    ("two-berth third-class room, F deck", 1330, 846.5, 1410, 909.5),
    ("passage, F deck", 1410, 672, 1441, 909.5),
    ("four-berth third-class room, F deck", 1441, 658, 1539.25, 787),
    ("two-berth third-class room, F deck", 1441, 787, 1539.25, 853),
    ("two-berth third-class room, F deck", 1441, 853, 1539.25, 921.5),
    ("passage, F deck", 1257.5, 909.5, 1441, 951.5),
    ("passage, F deck", 1441, 921.5, 1539.25, 951.5),
    ("passage, F deck", 1207.5, 909.5, 1257.5, 1209.5),
    # Starboard, aft to forward.
    ("two-berth third-class room, F deck", 787.5, 1121.5, 865.5, 1239),
    ("passage, F deck", 865.5, 1121.5, 894.5, 1260),
    ("four-berth third-class room, F deck", 894.5, 1121.5, 968, 1281),
    ("three-berth third-class room, F deck", 968, 1170, 1036, 1309),
    ("passage, F deck", 1036, 1170, 1065, 1330),
    ("four-berth third-class room, F deck", 1065, 1170, 1137.5, 1344),
    ("five-berth third-class room, F deck", 1137.5, 1170, 1212.5, 1372),
    ("passage, F deck", 1212.5, 1209.5, 1249, 1386),
    ("six-berth third-class room, F deck", 1249, 1209.5, 1335.5, 1407),
    ("two-berth third-class room, F deck", 1335.5, 1209.5, 1411.5, 1269.5),
    ("four-berth third-class room, F deck", 1335.5, 1269.5, 1411.5, 1421),
    ("passage, F deck", 1411.5, 1209.5, 1455.5, 1435),
    ("two-berth third-class room, F deck", 1455.5, 1197, 1539.25, 1259),
    ("two-berth third-class room, F deck", 1455.5, 1259, 1539.25, 1326),
    ("four-berth third-class room, F deck", 1455.5, 1326, 1539.25, 1449),
    ("passage, F deck", 1257.5, 1166, 1455.5, 1209.5),
    ("passage, F deck", 1455.5, 1166, 1539.25, 1197),
    # The main third-class stairway's landing (BOT: "the main third class entrance for
    # the after-end of the vessel, leading directly down to G deck ... From E to F it
    # was 8 ft. wide"), from the centre passages forward to the block round No. 6 hatch.
    ("third-class entrance, F deck", 968, 1002, 1029.5, 1170),
    ("third-class entrance, F deck", 1029.5, 989, 1207.5, 1170),
    # The block round No. 6 hatch's trunk: three rooms aft of it, two forward.
    ("two-berth third-class room, F deck", 1257.5, 951.5, 1343.5, 1010.5),
    ("four-berth third-class room, F deck", 1257.5, 1010.5, 1343.5, 1105),
    ("two-berth third-class room, F deck", 1257.5, 1105, 1343.5, 1166),
    ("four-berth third-class room, F deck", 1462.5, 951.5, 1539.25, 1053.5),
    ("four-berth third-class room, F deck", 1462.5, 1053.5, 1539.25, 1166),
    # Between bulkheads O and N, second class (BOT: "The next three compartments were
    # allotted to 64 second class staterooms ... Passengers between N and O bulkheads on
    # D, E, F and G decks could pass by the after second class stairway to B deck").
    # Port, aft to forward: rooms off short passages to her side, two of them round the
    # closets the plate draws as their recesses (0.8 m, narrower than a body); the
    # third-class stairway from E deck down to G deck in its own enclosure, no door onto
    # F deck's rooms.
    ("two-berth second-class stateroom, F deck", 1568.5, 637, 1639, 791),
    ("four-berth second-class stateroom, F deck", 1539.25, 791, 1639, 899.5),
    ("bathroom, F deck", 1539.25, 899.5, 1639, 978.5),
    ("passage, F deck", 1639, 623, 1674.5, 978.5),
    ("four-berth second-class stateroom, F deck", 1706, 609, 1811, 786.5),
    ("four-berth second-class stateroom, F deck", 1674.5, 786.5, 1811, 894),
    ("passage, F deck", 1811, 635.5, 1846.5, 868.5),
    ("two-berth second-class stateroom, F deck", 1846.5, 588, 1937, 687),
    ("two-berth second-class stateroom, F deck", 1937, 574, 2028, 687),
    ("third-class stairway, F deck", 1846.5, 687, 2028, 868.5),
    ("passage, F deck", 2028, 604, 2066.5, 868.5),
    ("four-berth second-class stateroom, F deck", 2066.5, 560, 2176.75, 689.5),
    ("two-berth second-class stateroom, F deck", 2066.5, 689.5, 2176.75, 783),
    ("bathroom, F deck", 2066.5, 783, 2176.75, 868.5),
    # The corridors either side of No. 5 hatch's trunk and the after second-class
    # stairway (BOT: "another second class stairway, which gave access to C, D, E, F and
    # G decks"), round its well; the ladies' lavatory aft of the hatch, the gentlemen's
    # forward of the stairway, each round its W.C.s.
    ("corridor, F deck", 1678, 894, 1811, 944),
    ("corridor, F deck", 1811, 868.5, 2176.75, 926.5),
    ("ladies' lavatory, F deck", 1539.25, 978.5, 1678, 1129),
    ("second-class entrance, F deck, aft", 1811, 926.5, 2066.5, 1169),
    ("gentlemen's lavatory, F deck", 2066.5, 926.5, 2176.75, 1169),
    ("corridor, F deck", 1678, 1153.5, 1811, 1221.5),
    ("corridor, F deck", 1811, 1169, 2066.5, 1227),
    # Starboard, aft to forward; the plate's steward's room (ASS. 2ND STEWD.).
    ("bathroom, F deck", 1539.25, 1129, 1643, 1219),
    ("four-berth second-class stateroom, F deck", 1539.25, 1219, 1643, 1315.5),
    ("four-berth second-class stateroom, F deck", 1539.25, 1315.5, 1576, 1420.5),
    ("two-berth second-class stateroom, F deck", 1576, 1315.5, 1643, 1470),
    ("passage, F deck", 1643, 1129, 1678, 1444),
    ("four-berth second-class stateroom, F deck", 1678, 1221.5, 1783.5, 1309.5),
    ("four-berth second-class stateroom, F deck", 1678, 1309.5, 1783.5, 1491),
    ("passage, F deck", 1783.5, 1221.5, 1817.5, 1454.5),
    ("four-berth second-class stateroom, F deck", 1817.5, 1227, 1927.5, 1339),
    ("four-berth second-class stateroom, F deck", 1817.5, 1339, 1927.5, 1512),
    ("two-berth second-class stateroom, F deck", 1927.5, 1227, 2035.5, 1304),
    ("assistant second steward's room", 1927.5, 1304, 2035.5, 1381),
    ("four-berth second-class stateroom, F deck", 1927.5, 1381, 2035.5, 1519),
    ("passage, F deck", 2035.5, 1227, 2066.5, 1486.5),
    ("bathroom, F deck", 2066.5, 1169, 2176.75, 1252),
    ("four-berth second-class stateroom, F deck", 2066.5, 1252, 2176.75, 1382.5),
    ("four-berth second-class stateroom, F deck", 2066.5, 1382.5, 2176.75, 1533),
    # Between N and M, second class (BOT: "Passengers between M and N bulkheads on both
    # E and F decks could pass directly up to the forward second class stairway"). Port,
    # aft to forward: rooms off short passages to her side; forward of them a stair down
    # to G deck's stores and up to E deck, its two flights side by side.
    ("four-berth second-class stateroom, F deck", 2176.75, 553, 2270.5, 675.5),
    ("four-berth second-class stateroom, F deck", 2176.75, 755, 2270.5, 869),
    ("passage, F deck", 2270.5, 590, 2314, 869),
    ("four-berth second-class stateroom, F deck", 2314, 546, 2420.5, 669),
    ("two-berth second-class stateroom, F deck", 2314, 669, 2420.5, 753.5),
    ("four-berth second-class stateroom, F deck", 2314, 753.5, 2420.5, 868.5),
    ("four-berth second-class stateroom, F deck", 2420.5, 539, 2517.5, 669),
    ("two-berth second-class stateroom, F deck", 2420.5, 669, 2517.5, 753.5),
    ("four-berth second-class stateroom, F deck", 2420.5, 753.5, 2517.5, 868.5),
    ("passage, F deck", 2517.5, 564.5, 2559, 869),
    ("four-berth second-class stateroom, F deck", 2559, 532, 2658.5, 666.5),
    ("two-berth second-class stateroom, F deck", 2559, 666.5, 2658.5, 752),
    ("four-berth second-class stateroom, F deck", 2559, 752, 2658.5, 868),
    ("passage, F deck", 2658.5, 555, 2702, 869),
    ("two-berth second-class stateroom, F deck", 2702, 525, 2801, 629),
    ("two-berth second-class stateroom, F deck", 2801, 518, 2916.25, 629),
    ("passage, F deck", 2764.5, 629, 2916.25, 718),
    ("passage, F deck", 2702, 718, 2916.25, 750.5),
    ("four-berth second-class stateroom, F deck", 2702, 750.5, 2800, 867.5),
    ("four-berth second-class stateroom, F deck", 2800, 750.5, 2916.25, 867.5),
    ("corridor, F deck", 2176.75, 869, 2916.25, 927),
    # The middle, aft to forward: linen lockers, two bathrooms and the ladies' lavatory
    # off a cross passage; the gentlemen's lavatory by its W.C.s, a room the plate marks
    # 3L CL. (its label blotted) and a store (S); three bathrooms and the ventilators
    # (V) off a passage between the corridors; and the forward second-class entrance
    # round the forward second-class staircase and lift (BOT: "a stairway and elevator
    # leading directly down to F deck"), its stair box open aft.
    ("bathroom, F deck", 2176.75, 945, 2243.5, 1030),
    ("bathroom, F deck", 2243.5, 945, 2310, 1030),
    ("passage, F deck", 2176.75, 1030, 2310, 1061),
    ("ladies' lavatory, F deck", 2176.75, 1061, 2249.5, 1167),
    ("passage, F deck", 2310, 927, 2344.5, 1167),
    ("room marked 3L CL", 2344.5, 1083, 2428, 1167),
    ("gentlemen's lavatory, F deck", 2412, 927, 2484.5, 1083),
    ("store, F deck", 2428, 1083, 2484.5, 1167),
    ("passage, F deck", 2484.5, 927, 2516.5, 1167),
    ("bathroom, F deck", 2516.5, 927, 2599.5, 1007.5),
    ("bathroom, F deck", 2516.5, 1007.5, 2599.5, 1085.5),
    ("bathroom, F deck", 2516.5, 1085.5, 2599.5, 1167),
    ("second-class entrance, F deck", 2638.5, 927, 2740, 1167),
    ("second-class entrance, F deck", 2740, 927, 2916.25, 1161),
    ("corridor, F deck", 2282.5, 1167, 2740, 1222),
    # Starboard, aft to forward.
    ("two-berth second-class stateroom, F deck", 2176.75, 1167, 2282.5, 1252),
    ("two-berth second-class stateroom, F deck", 2176.75, 1252, 2282.5, 1337.5),
    ("four-berth second-class stateroom, F deck", 2176.75, 1416.5, 2282.5, 1540),
    ("passage, F deck", 2282.5, 1222, 2321, 1504.5),
    ("four-berth second-class stateroom, F deck", 2321, 1222, 2430.5, 1337),
    ("two-berth second-class stateroom, F deck", 2321, 1337, 2430.5, 1436.5),
    ("four-berth second-class stateroom, F deck", 2321, 1436.5, 2430.5, 1547),
    ("two-berth second-class stateroom, F deck", 2430.5, 1222, 2486.5, 1337),
    ("four-berth second-class stateroom, F deck", 2486.5, 1222, 2565.5, 1337),
    ("four-berth second-class stateroom, F deck", 2430.5, 1337, 2565.5, 1445),
    ("four-berth second-class stateroom, F deck", 2461.5, 1445, 2565.5, 1554),
    ("four-berth second-class stateroom, F deck", 2430.5, 1445, 2461.5, 1554),
    ("passage, F deck", 2565.5, 1222, 2604.5, 1523),
    ("two-berth second-class stateroom, F deck", 2604.5, 1222, 2668.5, 1336),
    ("two-berth second-class stateroom, F deck", 2668.5, 1222, 2740, 1336),
    ("four-berth second-class stateroom, F deck", 2604.5, 1336, 2740, 1437),
    ("four-berth second-class stateroom, F deck", 2604.5, 1437, 2638, 1561),
    ("four-berth second-class stateroom, F deck", 2638, 1437, 2740, 1568),
    ("passage, F deck", 2740, 1161, 2781, 1529.5),
    ("two-berth second-class stateroom, F deck", 2781, 1161, 2916.25, 1252.5),
    ("two-berth second-class stateroom, F deck", 2781, 1252.5, 2916.25, 1334.5),
    ("four-berth second-class stateroom, F deck", 2781, 1334.5, 2916.25, 1436.5),
    ("four-berth second-class stateroom, F deck", 2781, 1436.5, 2888.5, 1568),
    # Between M and L, second class, round the turbine engine casing (BOT: "the second
    # class passengers on E deck in the compartment abreast the turbine casing on the
    # starboard side, and also those on F deck on both sides below could pass through M
    # watertight bulkhead to the forward second class main stairway"). Port, aft to
    # forward: rooms off short passages to her side, a closet (L) at each one's end; the
    # gentlemen's lavatory (GENT LAV), its W.C.s and a store (S), two bathrooms and the
    # linen room off a cross passage; the corridor along the casing.
    ("four-berth second-class stateroom, F deck", 2916.25, 518, 3017.5, 668.5),
    ("passage, F deck", 3017.5, 555.5, 3056, 746.5),
    ("four-berth second-class stateroom, F deck", 3056, 511, 3159.5, 638.5),
    ("four-berth second-class stateroom, F deck", 3056, 638.5, 3159.5, 746.5),
    ("four-berth second-class stateroom, F deck", 3159.5, 511, 3263.5, 638.5),
    ("four-berth second-class stateroom, F deck", 3159.5, 638.5, 3263.5, 746.5),
    ("passage, F deck", 3263.5, 551, 3298.5, 746.5),
    ("four-berth second-class stateroom, F deck", 3298.5, 511, 3408.5, 636),
    ("four-berth second-class stateroom, F deck", 3298.5, 636, 3408.5, 746.5),
    ("passage, F deck", 3408.5, 551, 3448, 746.5),
    ("gentlemen's lavatory, F deck", 3448, 504, 3522, 642),
    ("store, F deck", 3522, 586.5, 3598.25, 642),
    ("passage, F deck", 3448, 642, 3598.25, 678.5),
    ("bathroom, F deck", 3448, 678.5, 3523.5, 743),
    ("bathroom, F deck", 3523.5, 678.5, 3598.25, 743),
    ("linen room", 3448, 743, 3598.25, 797),
    ("corridor, F deck", 2916.25, 758, 3017.5, 797),
    ("corridor, F deck", 3017.5, 746.5, 3448, 797),
    # The passage round the casing's after end, along M, the linen lockers against the
    # casing (the plate's L I N E N ... down a row of boxes); the starboard corridor.
    ("passage, F deck", 2916.25, 797, 2984, 1297),
    ("corridor, F deck", 2916.25, 1297, 3444.5, 1345),
    # Starboard, aft to forward: E deck's ladder comes down along M (e.py) into the
    # passage by the first pair; each pair's inner room reaches her side past the outer
    # one's end (an L cut in two), but for the second pair's, 0.7 m wide once the
    # passage beside it is widened for a body: a closet; the bathrooms, linen room and
    # ladies' lavatory as to port.
    ("passage, F deck", 2916.25, 1345, 2989.5, 1525.5),
    ("four-berth second-class stateroom, F deck", 2989.5, 1345, 3132, 1460.5),
    ("four-berth second-class stateroom, F deck", 3100, 1460.5, 3132, 1575),
    ("four-berth second-class stateroom, F deck", 2989.5, 1460.5, 3100, 1575),
    ("four-berth second-class stateroom, F deck", 3132, 1345, 3269.5, 1458.5),
    ("four-berth second-class stateroom, F deck", 3160.5, 1458.5, 3269.5, 1575),
    ("passage, F deck", 3269.5, 1345, 3315.5, 1546.5),
    ("four-berth second-class stateroom, F deck", 3315.5, 1345, 3414, 1459),
    ("four-berth second-class stateroom, F deck", 3315.5, 1459, 3414, 1582),
    ("passage, F deck", 3414, 1345, 3444.5, 1582),
    ("linen room", 3444.5, 1297, 3598.25, 1343.5),
    ("bathroom, F deck", 3444.5, 1343.5, 3524.5, 1419.5),
    ("bathroom, F deck", 3524.5, 1343.5, 3598.25, 1419.5),
    ("passage, F deck", 3444.5, 1419.5, 3598.25, 1458.5),
    ("ladies' lavatory, F deck", 3444.5, 1458.5, 3525.5, 1582),
    # Between L and K, the engineers (BOT: "The engineers' accommodation was in the next
    # compartment directly alongside the casing of the reciprocating engine room"), each
    # room named by its plate label (3RD ENG, JUNR 2ND ENG, 2 ASS 4TH E, ...). Port, aft
    # to forward: their lavatory (ENG LAV), an L round its W.C.s, its part before them a
    # lobby (so deck.py gives it no door of its own: the passage beyond bulkhead L is
    # M-L's); the walled stair box down to G deck (see STAIRS), the junior second
    # engineer's room over it in an L; pairs of rooms off short passages to her side,
    # each pair's inner room an L reaching her side past the outer one, where that leg
    # is as wide as a body (the narrower legs are closets); a room whose label is
    # blotted (2 S...); the corridor along the casing.
    ("engineers' lavatory lobby", 3598.25, 622.5, 3691, 678),
    ("engineers' lavatory", 3598.25, 678, 3721, 743),
    ("junior second engineer's room", 3691, 504, 3789.5, 598),
    ("junior second engineer's room", 3691, 598, 3765, 642),
    ("passage, F deck", 3765, 598, 3789.5, 678),
    ("engineers' stairway", 3691, 642, 3765, 678),
    ("passage, F deck", 3721, 678, 3789.5, 739.5),
    ("third engineer's room", 3789.5, 504, 3866.5, 638),
    ("bathroom, F deck", 3789.5, 638, 3866.5, 704),
    ("assistant electrical engineers' room", 3866.5, 622, 3993.5, 704),
    ("fourth engineers' room", 3894.5, 504, 3993.5, 622),
    ("passage, F deck", 3993.5, 504, 4034, 704),
    ("assistant fourth engineers' room", 4034, 504, 4105.5, 623),
    ("assistant engineers' room", 4034, 623, 4139, 700),
    ("assistant engineers' room", 4105.5, 504, 4139, 623),
    ("fifth engineers' room", 4163.5, 497, 4238, 622.5),
    ("sixth engineers' room", 4139, 622.5, 4238, 700),
    ("passage, F deck", 4238, 497, 4282.5, 704),
    ("engineers' room", 4282.5, 497, 4343, 636.5),
    ("assistant electrical engineers' room", 4282.5, 636.5, 4381.5, 739.5),
    ("assistant electrical engineers' room", 4343, 497, 4381.5, 636.5),
    ("corridor, F deck", 3789.5, 704, 4282.5, 739.5),
    # The ladder's space aft of the casing, along L (see STAIRS), and the corridor to
    # starboard. Starboard, aft to forward: a bathroom, W.C.s and the engineers'
    # lavatory; pairs of rooms off short passages as to port (2 ENG; 3 WRITERS and the
    # third engineer; 2 ASS 2ND ENG and the senior second engineer; 2 ASS 3RD ENG), the
    # first pair's inner room's label blotted; the chief engineer's lavatory and room.
    ("passage, F deck", 3598.25, 1205, 3638, 1353.5),
    ("corridor, F deck", 3598.25, 1353.5, 4286, 1391.5),
    ("bathroom, F deck", 3598.25, 1391.5, 3658, 1472.5),
    ("engineers' lavatory", 3658, 1391.5, 3726.5, 1582),
    ("engineers' room", 3726.5, 1391.5, 3831, 1474),
    ("engineers' room", 3726.5, 1474, 3756.5, 1582),
    ("two-berth engineers' room", 3756.5, 1474, 3831, 1582),
    ("passage, F deck", 3831, 1391.5, 3872.5, 1582),
    ("writers' room", 3872.5, 1391.5, 3971.5, 1471.5),
    ("third engineer's room", 3872.5, 1471.5, 3943.5, 1582),
    ("assistant second engineers' room", 3971.5, 1391.5, 4113.5, 1471.5),
    ("assistant second engineers' room", 3971.5, 1471.5, 4003, 1582),
    ("senior second engineer's room", 4003, 1471.5, 4113.5, 1582),
    ("passage, F deck", 4113.5, 1391.5, 4140, 1582),
    ("assistant third engineers' room", 4140, 1391.5, 4262, 1471.5),
    ("passage, F deck", 4262, 1391.5, 4286, 1471.5),
    ("chief engineer's lavatory", 4286, 1353.5, 4381.5, 1471.5),
    ("chief engineer's room", 4176, 1471.5, 4381.5, 1582),
    # Between K and J, the third-class galley and its service (BOT: "The third class
    # stewards' accommodation, together with the third class galley and pantries, filled
    # the watertight compartment"): to port the 34 third-class stewards (34 3RD CLASS
    # STEWARDS), an L round boiler room 1's casing's corner, the 8 bakers and 6
    # butchers; the landing by the casing where E deck's ladder comes down (e.py) and
    # the passage round the casing; to starboard the bakery, the bread room, the
    # butcher's shop, the potato washing place and the galley.
    ("third-class stewards' quarters", 4381.5, 497, 4554.5, 922),
    ("third-class stewards' quarters", 4554.5, 689.5, 4622.5, 799),
    ("bakers' quarters", 4554.5, 497, 4684, 689.5),
    ("butchers' quarters", 4684, 497, 4798.75, 689.5),
    ("passage, F deck", 4622.5, 689.5, 4798.75, 799),
    ("passage, F deck", 4725, 799, 4798.75, 1280.5),
    ("bakery", 4381.5, 1163.5, 4456, 1368),
    ("bakery", 4456, 1163.5, 4551, 1275.5),
    ("bread room", 4456, 1275.5, 4526.5, 1368),
    ("butcher's shop", 4381.5, 1368, 4526.5, 1471.5),
    ("potato washing place", 4381.5, 1471.5, 4550.5, 1582),
    ("passage, F deck", 4526.5, 1275.5, 4798.75, 1322.5),
    ("passage, F deck", 4526.5, 1322.5, 4550.5, 1471.5),
    ("third-class galley", 4550.5, 1322.5, 4798.75, 1582),
    # Between J and H, and between H and G, the third-class dining saloons (BOT: "The
    # next two watertight compartments each contained a third class dining room"), each
    # round its boiler casing and the stokeholds' fans forward of it, as rectangles that
    # are one room; between J and H the third-class pantries in its after corners, each
    # round an ash ejector's trunk (the plate's A.E.) and, to starboard, a cupboard (C).
    # The saloons meet at H under the working passage's ladderway (BOT: "direct access
    # was obtained to the third class dining rooms on the deck below by means of a
    # ladderway 20 ft. wide"), which the plate draws as four ladders side by side over
    # H's line: E deck's flight (e.py). H stays whole between the saloons, with no door
    # through it.
    ("third-class pantry", 4798.75, 497, 4967.5, 638.5),
    ("third-class pantry", 4798.75, 638.5, 4933, 797.5),
    ("third-class dining saloon", 4967.5, 497, 5197, 797.5),
    ("third-class dining saloon", 4933, 638.5, 4967.5, 797.5),
    ("third-class dining saloon", 5197, 490, 5496.75, 901.5),
    ("third-class dining saloon", 5334, 901.5, 5496.75, 1175.5),
    ("third-class dining saloon", 5197, 1175.5, 5496.75, 1568),
    ("third-class dining saloon", 5001, 1275.5, 5197, 1575),
    ("third-class pantry", 4798.75, 1275.5, 5001, 1421.5),
    ("third-class pantry", 4909, 1421.5, 5001, 1575),
    ("third-class dining saloon", 5496.75, 654.5, 5602, 1449.5),
    ("third-class dining saloon", 5602, 490, 6131, 787),
    ("third-class dining saloon", 5602, 787, 5742.5, 896),
    ("third-class dining saloon", 5602, 1167, 5742.5, 1263.5),
    ("third-class dining saloon", 5602, 1263.5, 6131, 1561),
    ("third-class dining saloon", 5496.75, 1449.5, 5561, 1568),
    # Between G and F (BOT: "stewards' accommodation on the port side, and the Turkish
    # baths on the starboard side"). Port: 15 cooks and others (15 COOKS &c) and 42
    # third-class stewards (42 3RD C STEWARDS) off the landing at their ladderway up to
    # E deck (e.py): a landing, not a passage, so deck.py gives the saloon beyond G no
    # door into it; the Turkish bath attendants' room (T.B. ATTEND), a passage past an
    # ash ejector's trunk and a closet (L) to the Turkish bath's pantry and lobby; the
    # two electric bath rooms (ELEC B. RM) off the lobby, where a stair comes down from
    # E deck (e.py) by the fans.
    ("cooks' quarters", 6131, 490, 6268.5, 745),
    ("landing, F deck", 6131, 745, 6339, 787),
    ("third-class stewards' quarters", 6268.5, 490, 6573, 745),
    ("third-class stewards' quarters", 6339, 745, 6573, 787),
    ("Turkish bath attendants' room", 6573, 483, 6683, 598),
    ("pantry, F deck", 6756, 490, 6860.75, 598),
    ("pantry, F deck", 6790, 598, 6860.75, 636),
    ("passage, F deck", 6573, 598, 6790, 636),
    ("electric bath room", 6573, 636, 6728.5, 755),
    ("electric bath room", 6573, 755, 6728.5, 880.5),
    ("Turkish bath lobby", 6728.5, 636, 6860.75, 880.5),
    ("Turkish bath lobby", 6693.5, 880.5, 6860.75, 1167),
    ("Turkish bath lobby", 6671, 1167, 6860.75, 1219),
    # Starboard, the Turkish bath (The Shipbuilder: its hot, temperate and cooling
    # rooms, steam room and shampooing rooms, as the plate labels them): the hot room,
    # insulated inside its double wall, and the steam room off the temperate room; the
    # cooling room, an L under the fans, into the lobby and onto the lobby along F where
    # the shampooing rooms open, an ash ejector's trunk, a closet (L) and a W.C.
    ("Turkish bath, hot room", 6131, 1361.5, 6275.5, 1484.5),
    ("Turkish bath, steam room", 6131, 1484.5, 6275.5, 1554),
    ("Turkish bath, temperate room", 6308, 1263.5, 6448.5, 1361.5),
    ("Turkish bath, temperate room", 6275.5, 1361.5, 6448.5, 1554),
    ("Turkish bath, cooling room", 6448.5, 1263.5, 6671, 1554),
    ("Turkish bath, cooling room", 6550.5, 1167, 6671, 1263.5),
    ("Turkish bath, shampooing room", 6671, 1219, 6765.5, 1359.5),
    ("Turkish bath, shampooing room", 6765.5, 1219, 6860.75, 1359.5),
    ("Turkish bath lobby", 6671, 1359.5, 6860.75, 1554),
    # Between F and E (BOT: "In the next watertight compartment were the swimming bath
    # and linen rooms"). Port: two linen rooms (LINEN), the soiled linen room and the
    # linen drying room, where E deck's ladder comes down (e.py), off a passage along F;
    # round boiler room 5's casing the two drying rooms (DRY RM) either side of the
    # fans.
    ("linen room", 6860.75, 490, 6962, 766),
    ("linen room", 6962, 490, 7062, 766),
    ("soiled linen room", 7062, 490, 7175.5, 808.5),
    ("linen drying room", 7175.5, 490, 7491, 808.5),
    ("passage, F deck", 6860.75, 766, 7062, 808.5),
    ("passage, F deck", 6860.75, 808.5, 6936.5, 1547),
    ("drying room", 6936.5, 808.5, 7084, 888.5),
    ("drying room", 6936.5, 1158.5, 7084, 1230),
    # Starboard, the swimming bath (The Shipbuilder: "32 ft. long by 13 ft. wide"; the
    # plate's pool, 380 px, reads 10.6 m at this compartment's scale, 9.9 m at the
    # view's usual one), its showers and its row of dressing boxes along the casing, an
    # ash ejector's trunk standing in its after corner.
    ("swimming bath", 6936.5, 1285, 7491, 1540),
    # Between E and D, third class (BOT: "Aft of this [the firemen] in three watertight
    # compartments there was third class accommodation extending to 147 ft."): the first
    # of them, rooms in rows across her either side of the boiler casing, off a passage
    # along her each side and short passages to her sides, a closet (L) at each one's
    # inner end. Port, aft to forward.
    ("four-berth third-class room, F deck", 7491, 685.5, 7595.5, 766),
    ("six-berth third-class room, F deck", 7491, 804, 7595.5, 893),
    ("six-berth third-class room, F deck", 7595.5, 497, 7667, 685.5),
    ("two-berth third-class room, F deck", 7595.5, 685.5, 7667, 766),
    ("four-berth third-class room, F deck", 7595.5, 804, 7667, 893),
    ("passage, F deck", 7667, 497, 7702, 766),
    ("passage, F deck", 7667, 804, 7702, 867.5),
    ("four-berth third-class room, F deck", 7702, 497, 7773.5, 683),
    ("six-berth third-class room, F deck", 7773.5, 504, 7846, 683),
    ("four-berth third-class room, F deck", 7702, 683, 7773.5, 766),
    ("four-berth third-class room, F deck", 7773.5, 683, 7846, 766),
    ("four-berth third-class room, F deck", 7702, 804, 7775.5, 893),
    ("four-berth third-class room, F deck", 7775.5, 804, 7846, 893),
    ("passage, F deck", 7846, 504, 7876.5, 766),
    ("passage, F deck", 7846, 804, 7876.5, 867),
    ("ten-berth third-class room, F deck", 7876.5, 504, 8020, 681),
    ("four-berth third-class room, F deck", 7876.5, 681, 7949.5, 766),
    ("four-berth third-class room, F deck", 7949.5, 681, 8020, 766),
    ("four-berth third-class room, F deck", 7876.5, 804, 7950, 893),
    ("four-berth third-class room, F deck", 7950, 804, 8020, 893),
    ("passage, F deck", 7491, 766, 8020, 804),
    ("passage, F deck", 8020, 511, 8053.5, 696.5),
    ("two-berth third-class room, F deck", 8053.5, 511, 8134.75, 611),
    ("two-berth third-class room, F deck", 8053.5, 611, 8134.75, 696.5),
    # By D: a lobby from the port passages to the port opening in D (see DOORS) and down
    # along D past the fans to the starboard passage; the stairway down to the racquet
    # court in its pocket against D, walled off from the lobby and entered from forward
    # of D through its starboard opening.
    ("passage, F deck", 8020, 696.5, 8134.75, 882),
    ("passage, F deck", 8020, 882, 8094.5, 1222),
    ("squash stairway", 8094.5, 882, 8134.75, 1202.5),
    # Starboard, aft to forward.
    ("passage, F deck", 7491, 1148.5, 7523, 1367.5),
    ("four-berth third-class room, F deck", 7523, 1127.5, 7597.5, 1222),
    ("four-berth third-class room, F deck", 7597.5, 1127.5, 7668, 1222),
    ("passage, F deck", 7668, 1155.5, 7705, 1222),
    ("four-berth third-class room, F deck", 7705, 1127.5, 7777.5, 1222),
    ("four-berth third-class room, F deck", 7777.5, 1127.5, 7848, 1222),
    ("passage, F deck", 7848, 1154, 7880, 1222),
    ("four-berth third-class room, F deck", 7880, 1127.5, 7949, 1222),
    ("four-berth third-class room, F deck", 7949, 1127.5, 8020, 1222),
    ("passage, F deck", 7523, 1222, 8094.5, 1267.5),
    ("four-berth third-class room, F deck", 7523, 1267.5, 7597.5, 1367.5),
    ("six-berth third-class room, F deck", 7491, 1367.5, 7597.5, 1519),
    ("four-berth third-class room, F deck", 7597.5, 1267.5, 7670, 1367.5),
    ("six-berth third-class room, F deck", 7597.5, 1367.5, 7670, 1526),
    ("passage, F deck", 7670, 1267.5, 7706, 1519),
    ("four-berth third-class room, F deck", 7706, 1267.5, 7780, 1361),
    ("four-berth third-class room, F deck", 7780, 1267.5, 7852, 1361),
    ("four-berth third-class room, F deck", 7706, 1361, 7780, 1519),
    ("six-berth third-class room, F deck", 7780, 1361, 7852, 1512),
    ("passage, F deck", 7852, 1267.5, 7882.5, 1512),
    ("four-berth third-class room, F deck", 7882.5, 1267.5, 7950, 1358),
    ("four-berth third-class room, F deck", 7950, 1267.5, 8020, 1358),
    ("ten-berth third-class room, F deck", 7882.5, 1358, 8020, 1505),
    ("passage, F deck", 8020, 1267.5, 8059.5, 1498),
    ("two-berth third-class room, F deck", 8059.5, 1262, 8134.75, 1353),
    ("four-berth third-class room, F deck", 8059.5, 1353, 8134.75, 1491),
    # Between D and C, third class (the second of BOT's three compartments of third
    # class), round the upper half of the racquet court (its floor on G deck) and the
    # bunker hatch. Port, aft to forward: two eight-berth rooms; the landing inside the
    # opening in D and the double stair's room, the lobby forward of it and the linen
    # rooms; the passage along the court; the eight-berth room over the stair down to G
    # deck's baggage room; rooms by C off a passage from her side.
    ("eight-berth third-class room, F deck", 8134.75, 518, 8234.5, 696.5),
    ("eight-berth third-class room, F deck", 8234.5, 532, 8389, 668),
    ("passage, F deck", 8389, 546, 8420.5, 668),
    ("passage, F deck", 8134.75, 696.5, 8206.5, 780.5),
    ("passage, F deck", 8206.5, 696.5, 8310.5, 780.5),
    ("passage, F deck", 8310.5, 668, 8420.5, 833),
    ("linen room", 8134.75, 780.5, 8218, 833),
    ("linen room", 8218, 780.5, 8310.5, 833),
    ("passage, F deck", 8134.75, 833, 8420.5, 882),
    ("eight-berth third-class room, F deck", 8420.5, 553, 8517.5, 740),
    ("passage, F deck", 8420.5, 740, 8517.5, 882),
    ("six-berth third-class room, F deck", 8517.5, 567, 8624.5, 718.5),
    ("four-berth third-class room, F deck", 8517.5, 718.5, 8624.5, 784.5),
    ("passage, F deck", 8517.5, 784.5, 8624.5, 882),
    ("passage, F deck", 8624.5, 574, 8656.5, 882),
    ("four-berth third-class room, F deck", 8656.5, 581, 8733.25, 714),
    ("two-berth third-class room, F deck", 8656.5, 714, 8733.25, 775),
    ("two-berth third-class room, F deck", 8656.5, 775, 8733.25, 827.5),
    ("third-class room, F deck", 8656.5, 827.5, 8733.25, 878),
    # Amidships by C: two-berth rooms either side of the centre line, off the passage
    # along the bunker hatch, which runs on down to the starboard passage.
    ("two-berth third-class room, F deck", 8656.5, 878, 8733.25, 956),
    ("two-berth third-class room, F deck", 8656.5, 992.5, 8733.25, 1041),
    ("two-berth third-class room, F deck", 8656.5, 1041, 8733.25, 1125.5),
    ("passage, F deck", 8624.5, 882, 8656.5, 1125.5),
    # Starboard: the passage along the court with the flights down to G deck's post
    # office and up to E deck; a store (unlabelled, est.); three six-berth rooms; rooms
    # by C (no berths marked: est. third-class rooms); a passage along her; the mail
    # clerks' room (2 MAIL CLERKS) and the rooms forward of it, off short passages to
    # her side.
    ("passage, F deck", 8134.75, 1125.5, 8420.5, 1163.5),
    ("passage, F deck", 8134.75, 1163.5, 8309.5, 1224.5),
    ("passage, F deck", 8134.75, 1224.5, 8175, 1353),
    ("store, F deck", 8175, 1224.5, 8280, 1266),
    ("six-berth third-class room, F deck", 8309.5, 1163.5, 8420.5, 1266),
    ("six-berth third-class room, F deck", 8420.5, 1125.5, 8517.5, 1266),
    ("six-berth third-class room, F deck", 8517.5, 1150.5, 8590, 1266),
    ("passage, F deck", 8590, 1125.5, 8656.5, 1294),
    ("third-class room, F deck", 8656.5, 1125.5, 8733.25, 1194.5),
    ("third-class room, F deck", 8656.5, 1194.5, 8733.25, 1291.5),
    ("third-class room, F deck", 8656.5, 1291.5, 8733.25, 1414),
    ("passage, F deck", 8175, 1266, 8590, 1294),
    ("two-berth third-class room, F deck", 8175, 1294, 8280, 1353),
    ("mail clerks' room", 8134.75, 1353, 8280, 1484),
    ("four-berth third-class room, F deck", 8280, 1294, 8392.5, 1369),
    ("four-berth third-class room, F deck", 8280, 1369, 8392.5, 1456),
    ("passage, F deck", 8392.5, 1294, 8422.5, 1449),
    ("six-berth third-class room, F deck", 8422.5, 1294, 8520, 1449),
    ("six-berth third-class room, F deck", 8520, 1294, 8631, 1435),
    ("passage, F deck", 8631, 1294, 8656.5, 1421),
    # Between C and B, third class (the third of BOT's three compartments), round No. 2
    # hatch's trunk: rooms off passages along her either side of the hatch and in rows
    # across her, a passage across her along B. Port, aft to forward.
    ("eight-berth third-class room, F deck", 8733.25, 602, 8926.5, 714),
    ("six-berth third-class room, F deck", 8733.25, 714, 8856.5, 825),
    ("four-berth third-class room, F deck", 8856.5, 714, 8926.5, 825),
    ("passage, F deck", 8926.5, 623, 8965.5, 825),
    ("passage, F deck", 8733.25, 825, 8965.5, 875),
    ("four-berth third-class room, F deck", 8965.5, 637, 9049.5, 773.5),
    ("two-berth third-class room, F deck", 8965.5, 773.5, 9049.5, 833),
    ("six-berth third-class room, F deck", 9049.5, 651, 9129.5, 833),
    ("passage, F deck", 8965.5, 833, 9129.5, 875),
    ("passage, F deck", 9129.5, 665, 9161, 1268.5),
    # Amidships, forward of the hatch: two columns of rooms either side of the centre
    # line.
    ("passage, F deck", 8932, 875, 8969, 1118),
    ("four-berth third-class room, F deck", 8969, 875, 9052.5, 954.5),
    ("four-berth third-class room, F deck", 9052.5, 875, 9129.5, 954.5),
    ("two-berth third-class room, F deck", 8969, 954.5, 9052.5, 1034.5),
    ("two-berth third-class room, F deck", 9052.5, 954.5, 9129.5, 1034.5),
    ("four-berth third-class room, F deck", 8969, 1034.5, 9052.5, 1118),
    ("four-berth third-class room, F deck", 9052.5, 1034.5, 9129.5, 1118),
    # Starboard: the passage along the hatch; two six-berth rooms and an eight-berth;
    # the third-class ladderway's room (BOT: the forward well's starboard ladderway "led
    # to E deck and continued to F deck as a double ladder and to G deck as a single
    # ladder"), a two-berth room beside it; the passages to her side.
    ("passage, F deck", 8733.25, 1118, 9129.5, 1153.5),
    ("six-berth third-class room, F deck", 8733.25, 1153.5, 8818.5, 1281.5),
    ("six-berth third-class room, F deck", 8818.5, 1153.5, 8896.5, 1281.5),
    ("eight-berth third-class room, F deck", 8733.25, 1281.5, 8933, 1386),
    ("passage, F deck", 8896.5, 1153.5, 8967.5, 1281.5),
    ("passage, F deck", 8933, 1281.5, 8967.5, 1358),
    ("third-class ladderway, F deck", 8967.5, 1153.5, 9074.5, 1272.5),
    ("two-berth third-class room, F deck", 8967.5, 1272.5, 9074.5, 1344),
    ("passage, F deck", 9074.5, 1153.5, 9129.5, 1323),
    # Along B, a column of rooms off the passage across her.
    ("four-berth third-class room, F deck", 9161, 679, 9244.5, 811.5),
    ("two-berth third-class room, F deck", 9161, 811.5, 9244.5, 868),
    ("four-berth third-class room, F deck", 9161, 868, 9244.5, 954),
    ("two-berth third-class room, F deck", 9161, 954, 9244.5, 1031.5),
    ("four-berth third-class room, F deck", 9161, 1031.5, 9244.5, 1114.5),
    ("two-berth third-class room, F deck", 9161, 1114.5, 9244.5, 1174.5),
    ("four-berth third-class room, F deck", 9161, 1174.5, 9244.5, 1302),
    # Forward of B, the firemen (BOT: "At the forward end of it was the accommodation
    # for 53 firemen constituting the third watch"; the plate's 53 FIREMEN): abaft them
    # their W.C.s to port and starboard (Dº, ditto) and the landing at the heads of
    # their two spiral staircases down to their tunnel (as D deck's); their quarters
    # round No. 1 hatch, in three steps to her sides forward; the room the plate marks 4
    # GREASERS.
    ("firemen's W.C.s", 9244.5, 700, 9368.5, 868),
    ("passage, F deck", 9244.5, 868, 9392.5, 1114.5),
    ("firemen's W.C.s", 9244.5, 1114.5, 9366.5, 1274),
    ("firemen's quarters", 9392.5, 735, 9536.5, 909),
    ("greasers' quarters", 9392.5, 1068, 9505.5, 1239),
    ("firemen's quarters", 9536.5, 770, 9650, 1197),
    ("firemen's quarters", 9650, 805, 9768, 1169),
    ("firemen's quarters", 9768, 833, 9863, 1141),
]

SOLIDS = [
    # Aft: a closet narrower than a body (0.77 m) at the landing's corner; No. 6 hatch's
    # trunk (the after well's, as D deck's).
    ("closet", 968, 1121.5, 997.5, 1170, None),
    ("No. 6 hatch", 1343.5, 951.5, 1462.5, 1166, None),
    # Between O and N: closets narrower than a body — the two rooms' recesses by her
    # side, the passages' ends at her side, two in the corners of the bathrooms — No. 5
    # hatch's trunk, the lavatories' W.C.s and the after second-class stairway's well.
    ("closet", 1539.25, 644, 1568.5, 791, None),
    ("closet", 1674.5, 616, 1706, 786.5, None),
    ("closet", 1811, 595, 1846.5, 635.5, None),
    ("closet", 2028, 567, 2066.5, 604, None),
    ("closet", 2066.5, 819, 2084.5, 868.5, None),
    ("closet", 1539.25, 1420.5, 1576, 1463, None),
    ("closet", 1643, 1444, 1678, 1477, None),
    ("closet", 1783.5, 1454.5, 1817.5, 1498, None),
    ("closet", 2035.5, 1486.5, 2066.5, 1526, None),
    ("closet", 2071.5, 1213, 2097.5, 1252, None),
    ("No. 5 hatch", 1678, 944, 1811, 1153.5, None),
    ("W.C.s", 1601.5, 1012.5, 1678, 1091, None),
    ("W.C.s", 2100, 926.5, 2176.75, 1030, None),
    ("stairwell", 1920, 1014.5, 1985.5, 1079, None),
    # Between N and M: No. 4 hatch's trunks either side (as D deck's), closets at the
    # passages' ends, a store aft of the stair's flights (walled round), the linen
    # lockers, the lavatories' W.C.s, the ventilators, and the second-class lift.
    ("No. 4 hatch", 2176.75, 675.5, 2270.5, 755, None),
    ("No. 4 hatch", 2176.75, 1337.5, 2282.5, 1416.5, None),
    ("closet", 2270.5, 546, 2314, 590, None),
    ("closet", 2517.5, 532, 2559, 564.5, None),
    ("closet", 2658.5, 525, 2702, 555, None),
    ("store", 2702, 629, 2764.5, 718, None),
    ("closet", 2282.5, 1504.5, 2321, 1547, None),
    ("closet", 2565.5, 1523, 2604.5, 1561, None),
    ("closet", 2740, 1529.5, 2781, 1568, None),
    ("closet", 2888.5, 1436.5, 2916.25, 1568, None),
    ("linen lockers", 2176.75, 927, 2310, 945, None),
    ("W.C.s", 2249.5, 1061, 2310, 1167, None),
    ("W.C.s", 2344.5, 927, 2412, 1083, None),
    ("ventilators", 2599.5, 927, 2638.5, 1167, None),
    ("second-class lift", 2740, 1010, 2828.5, 1080.5, None),
    # Between M and L: three lockers by M with no door drawn (est. lockers); closets at
    # the passages' ends; the lavatories' W.C.s; the turbine engine casing (BOT: "the
    # turbine engine hatch") and the linen lockers against its after side; the leg of an
    # L-shaped room narrower than a body.
    ("lockers", 2916.25, 668.5, 3017.5, 758, None),
    ("closet", 3017.5, 511, 3056, 555.5, None),
    ("closet", 3263.5, 511, 3298.5, 551, None),
    ("closet", 3408.5, 504, 3448, 551, None),
    ("W.C.s", 3522, 504, 3598.25, 586.5, None),
    ("turbine engine casing", 2984, 797, 3598.25, 1297, None),
    ("linen lockers", 2964, 838, 2984, 1268, None),
    ("closet", 2916.25, 1525.5, 2989.5, 1575, None),
    ("closet", 3269.5, 1546.5, 3315.5, 1582, None),
    ("W.C.s", 3525.5, 1458.5, 3598.25, 1582, None),
    ("closet", 3132, 1458.5, 3160.5, 1575, None),
    # Between L and K: the engineers' W.C.s; the reciprocating engine casing (BOT: "the
    # reciprocating engine hatch"), stepped forward at its after starboard corner round
    # the ladder's space. The plate draws a door from the port corridor into the casing
    # (BOT: "they had also a direct route by the gratings in the engine room casing to
    # the Boat deck"): not laid, as the casing is solid. The legs of four L-shaped
    # rooms, 0.6-0.75 m wide, narrower than a body.
    ("W.C.s", 3598.25, 504, 3691, 622.5, None),
    ("reciprocating engine casing", 3598.25, 743, 4381.5, 1205, None),
    ("reciprocating engine casing", 3638, 1205, 4381.5, 1353.5, None),
    ("W.C.s", 3598.25, 1472.5, 3658, 1582, None),
    ("closet", 3866.5, 504, 3894.5, 622, None),
    ("closet", 4139, 497, 4163.5, 622.5, None),
    ("closet", 3943.5, 1471.5, 3971.5, 1582, None),
    ("closet", 4140, 1471.5, 4176, 1582, None),
    # Between K and J: a trunk by her side in the stewards' quarters; boiler room 1's
    # casing; the electric fans for the stokeholds (BOT: "On this deck in way of the
    # boiler rooms were placed the electrically-driven fans"), whose door the plate
    # draws from the stewards' quarters (not laid: the fans are a block); a box in the
    # bakery's corner (est. an oven).
    ("trunk", 4517, 497, 4554.5, 543, None),
    ("boiler casing", 4551, 799, 4725, 1275.5, None),
    ("fans", 4381.5, 922, 4551, 1163.5, None),
    ("oven", 4397, 1322.5, 4448, 1358.5, None),
    # Between J and G: the ash ejectors' trunks (A.E.), the boiler casings of boiler
    # rooms 2 and 3 to the bulkheads aft and forward of them (with the plate's lamp
    # rooms, LR, drawn dashed in their corners), the fans for the stokeholds forward of
    # each, and the starboard pantry's cupboard.
    ("ash ejector", 4864, 497, 4899.5, 607.5, None),
    ("boiler casing", 4798.75, 797.5, 5197, 1275.5, None),
    ("fans", 5197, 901.5, 5334, 1175.5, None),
    ("cupboard", 4798.75, 1356, 4869.5, 1421.5, None),
    ("ash ejector", 4798.75, 1421.5, 4909, 1575, None),
    ("ash ejector", 5496.75, 490, 5602, 654.5, None),
    ("fans", 5602, 896, 5742.5, 1167, None),
    ("boiler casing", 5742.5, 787, 6131, 1263.5, None),
    ("ash ejector", 5561, 1449.5, 5602, 1568, None),
    # Between G and F: a trunk in the cooks' corner; the ash ejectors' trunks, a closet
    # (L) and the linen locker (L I N E N) by the lobby; boiler room 4's casing from G
    # (its lamp rooms, LR, in its corners, one opening into the stewards' quarters); the
    # fans; the hot air tanks; closets in the steam room's and the cooling room's
    # corners; the W.C. and a closet off the lobby along F.
    ("trunk", 6233.5, 490, 6268.5, 519, None),
    ("ash ejector", 6683, 490, 6719, 598, None),
    ("closet", 6719, 490, 6756, 598, None),
    ("linen locker", 6728.5, 801.5, 6773.5, 880.5, None),
    ("boiler casing", 6131, 787, 6550.5, 1263.5, None),
    ("boiler casing", 6550.5, 787, 6573, 880.5, None),
    ("fans", 6550.5, 880.5, 6693.5, 1167, None),
    ("hot air tanks", 6131, 1263.5, 6308, 1361.5, None),
    ("closet", 6240, 1513.5, 6275.5, 1554, None),
    ("closet", 6448.5, 1263.5, 6511, 1306.5, None),
    ("ash ejector", 6671, 1402, 6739, 1554, None),
    ("closet", 6816, 1420, 6860.75, 1463.5, None),
    ("W.C.", 6816, 1463.5, 6860.75, 1554, None),
    # Between F and E: an ash ejector's trunk (A.E.) in the linen room's corner and one
    # by the swimming bath; the lockers (L) along F and in the drying room; boiler room
    # 5's casing and the fans; the swimming bath's two showers (its arches) and its
    # thirteen dressing boxes (DRESSING BOXES), each 0.86 m wide, narrower than a body
    # and a door; the pool, a box on the bath's floor as tools/gen_titanic.py lays it
    # (est. 1 m).
    ("ash ejector", 6932.5, 490, 6962, 627, None),
    ("lockers", 7175.5, 779.5, 7313, 808.5, None),
    ("closets", 6860.75, 875.5, 6888.5, 987, None),
    ("boiler casing", 7084, 808.5, 7491, 1230, None),
    ("fans", 6936.5, 888.5, 7084, 1158.5, None),
    ("showers", 6936.5, 1230, 7045, 1285, None),
    ("dressing boxes", 7045, 1230, 7491, 1285, None),
    ("pool", 7045, 1353, 7425, 1505.5, 1.0),
    ("ash ejector", 6936.5, 1422.5, 6973.5, 1528, None),
    # Between E and D: the ash ejector's space in the port after corner (the plate's A
    # E, no door drawn); the closets at the passages' inner ends; boiler room 6's casing
    # and the fans forward of it; the closet under the squash stairway's pocket.
    ("ash ejector", 7491, 497, 7595.5, 685.5, None),
    ("closet", 7667, 867.5, 7702, 893, None),
    ("closet", 7846, 867, 7876.5, 893, None),
    ("boiler casing", 7491, 893, 7846, 1127.5, None),
    ("fans", 7846, 893, 8020, 1127.5, None),
    ("closet", 7491, 1127.5, 7523, 1148.5, None),
    ("closet", 7668, 1127.5, 7705, 1155.5, None),
    ("closet", 7848, 1127.5, 7880, 1154, None),
    ("closet", 8094.5, 1202.5, 8134.75, 1262, None),
    # Between D and C: the strip between the second eight-berth room and the double
    # stair, narrower than a body (0.75 m); the racquet court's upper half, open to G
    # deck (BOT: "a racquet court" on G deck; The Shipbuilder: its spectators' gallery
    # at the after end on F), nobody's floor on F deck; the bunker hatch's trunk.
    ("recess", 8234.5, 668, 8310.5, 696.5, None),
    ("squash court", 8134.75, 882, 8488.5, 1125.5, None),
    ("bunker hatch", 8488.5, 882, 8624.5, 1125.5, None),
    # Spaces narrower than a body: a recess by the hatch over the third six-berth room,
    # a closet beside the store, one in the column of rooms along C.
    ("recess", 8517.5, 1125.5, 8590, 1150.5, None),
    ("closet", 8280, 1224.5, 8309.5, 1266, None),
    ("closet", 8656.5, 956, 8733.25, 992.5, None),
    # Between C and B: No. 2 hatch's trunk; a closet at the passage's starboard end.
    ("No. 2 hatch", 8733.25, 875, 8932, 1118, None),
    ("closet", 9129.5, 1268.5, 9161, 1316, None),
    # Forward of B: the W.C.s' cubicles and closets; No. 1 hatch's trunk; the strip
    # between the greasers' room and the hatch, narrower than a body (0.8 m). Forward of
    # A, the chain locker and the store in her eyes, no door drawn on F deck (est.
    # solids).
    ("W.C.s", 9320.5, 707, 9368.5, 813.5, None),
    ("closet", 9368.5, 714, 9392.5, 868, None),
    ("closet", 9366.5, 1114.5, 9392.5, 1253, None),
    ("No. 1 hatch", 9392.5, 909, 9536.5, 1068, None),
    ("recess", 9505.5, 1068, 9536.5, 1218, None),
    ("chain locker", 9863, 868, 10007, 1106, None),
    ("store", 10007, 910, 10200, 1057, None),
    ("store", 10200, 952, 10331, 1008, None),
]

DOORS = [
    # Aft: the store from the port four-berth room (the plate draws it none, est.); the
    # stern rooms into the centre passages; the two-berth pair into their vestibule.
    (708.5, 990), (787.5, 1015), (787.5, 1100), (856.5, 1058), (911.5, 1058),
    # Port, as their swings stand.
    (860.5, 980), (891.5, 962), (1029.5, 915), (1029.5, 980), (1061.5, 910), (1061.5, 965),
    (1207.5, 860), (1207.5, 955), (1246, 865), (1410, 795), (1410, 868),
    (1441, 758), (1441, 812), (1441, 875),
    # Starboard.
    (865.5, 1138), (894.5, 1152), (1036, 1190), (1065, 1217), (1212.5, 1215),
    (1411.5, 1237), (1411.5, 1305), (1455.5, 1220), (1455.5, 1287), (1455.5, 1367),
    # The block round No. 6 hatch.
    (1257.5, 985), (1257.5, 1060), (1257.5, 1130), (1470, 951.5), (1470, 1166),
    # Between O and N, port: the rooms off their passages, as their swings stand; the
    # bathrooms' (est.).
    (1639, 745), (1639, 860), (1639, 940), (1811, 735), (1811, 840), (1846.5, 655), (2028, 650),
    (2066.5, 655), (2066.5, 745), (2066.5, 800),
    # The stairway's hall from both corridors (est.: the plate draws its walls
    # unbroken), the gentlemen's lavatory from it (the swing in its corner), the ladies'
    # from the passage.
    (1850, 926.5), (1850, 1169), (2066.5, 1150), (1660, 1129),
    # Starboard.
    (1643, 1170), (1643, 1265), (1643, 1365), (1783.5, 1255), (1783.5, 1365), (1817.5, 1256),
    (1817.5, 1360), (2035.5, 1345), (2035.5, 1420), (2066.5, 1195), (2066.5, 1340), (2066.5, 1420),
    # Between N and M: the rooms off their passages, as their swings stand; the middle's
    # bathrooms, lavatories and store (est. where the plate draws no swing).
    (2270.5, 645), (2270.5, 825), (2314, 640), (2314, 725), (2314, 825), (2517.5, 640),
    (2517.5, 725), (2517.5, 830), (2658.5, 625), (2658.5, 715), (2658.5, 830), (2702, 600),
    (2890, 629), (2702, 810), (2815, 750.5),
    (2210, 1030), (2310, 990), (2200, 1061), (2448, 927), (2484.5, 1150), (2500, 1167),
    (2516.5, 967), (2516.5, 1046), (2516.5, 1126),
    (2282.5, 1210), (2282.5, 1295), (2282.5, 1470), (2321, 1270), (2321, 1380), (2321, 1480),
    (2450, 1222), (2565.5, 1275), (2565.5, 1395), (2565.5, 1490), (2604.5, 1300), (2740, 1255),
    (2740, 1385), (2740, 1480), (2781, 1190), (2781, 1290), (2781, 1385), (2781, 1480),
    # Between M and L: the rooms off their passages, as their swings stand; the
    # lavatories.
    (3017.5, 640), (3056, 590), (3056, 675), (3263.5, 590), (3263.5, 695), (3298.5, 590),
    (3298.5, 695), (3465, 642),
    (2989.5, 1397), (2989.5, 1500), (3269.5, 1400), (3269.5, 1493), (3315.5, 1410), (3315.5, 1500),
    (3462, 1458.5),
    # Between L and K, as the swings stand: the lavatory; the rooms off their passages;
    # starboard, the lavatory, the second engineers' and third engineers' pairs, the
    # chief engineer's lavatory (est.) and room. The rest from their passages (deck.py).
    (3721, 708), (3765, 620), (3765, 660), (3789.5, 600), (3993.5, 565), (3993.5, 648), (4034, 556),
    (4034, 640),
    (4238, 545), (4238, 676), (4282.5, 600), (4282.5, 667),
    (3700, 1391.5), (4113.5, 1440), (4113.5, 1548), (4140, 1445), (4286, 1440), (4272, 1471.5),
    # Between K and J: the stewards' quarters onto the landing (est.: the plate's label
    # runs over the wall); the bakers' and butchers' as their swings stand; the bakery,
    # the bread room, the butcher's shop and the potato washing place onto the passage;
    # the galley's two.
    (4622.5, 720), (4655, 689.5), (4785, 689.5), (4540, 1275.5), (4526.5, 1345), (4526.5, 1445),
    (4538, 1471.5), (4605, 1322.5), (4740, 1322.5),
    # Between J and G: the pantries into the saloon (est.: the plate draws no swing).
    # The plate draws H unbroken between the saloons, under the ladderway, so no door
    # through it (tools/gen_titanic.py lays one there today).
    (4933, 675), (5001, 1350),
    # Between G and F: the cooks' and the stewards' off their landing; the stewards'
    # into the passage (est.: the plate's label runs over the wall); the attendants';
    # the electric bath rooms; the pantry; the Turkish bath's rooms (est. where the
    # plate draws none: the temperate room into the cooling room, the steam room through
    # the hot room, the shampooing rooms onto the lobby along F).
    (6248, 745), (6339, 766), (6573, 618), (6640, 598), (6728.5, 690), (6728.5, 790), (6835, 636),
    (6671, 1195), (6671, 1390), (6448.5, 1420), (6275.5, 1420), (6200, 1484.5), (6718, 1359.5),
    (6813, 1359.5),
    # Between F and E, as their swings stand: the linen rooms and the soiled linen room
    # onto their passage; the drying room from the soiled linen room; the drying rooms
    # and the swimming bath from the passage along F.
    (6900, 766), (6990, 766), (7062, 790), (7175.5, 760), (6936.5, 850), (6936.5, 1195),
    (6936.5, 1390),
    # Between E and D, as their swings stand: port, then starboard, the rooms off their
    # passages. The two openings the plate draws in bulkhead D, its line broken: to port
    # from the lobby to the landing forward of it, to starboard from the passage along
    # the racquet court into the squash stairway's pocket (BOT: "On both the F and E
    # decks nearly all the bulkheads had watertight doors").
    (7565, 766), (7525, 804), (7667, 630), (7667, 735), (7667, 845), (7702, 625), (7702, 735),
    (7702, 845),
    (7846, 630), (7846, 735), (7846, 845), (7876.5, 715), (7876.5, 840), (8020, 635), (8020, 720),
    (8020, 835),
    (8095, 696.5), (8095, 611),
    (8134.75, 737), (8134.75, 1186),
    (7523, 1175), (7668, 1180), (7705, 1175), (7846, 1180), (7880, 1165), (8020, 1170),
    (7505, 1367.5), (7670, 1320), (7670, 1405), (7706, 1310), (7706, 1400), (7852, 1320),
    (7852, 1405),
    (7882.5, 1300), (8020, 1305), (8020, 1405), (8059.5, 1320), (8059.5, 1385),
    # Between D and C, as their swings stand (est. where none is drawn: the linen rooms,
    # the store, the rooms by C's lower end).
    (8222, 696.5), (8389, 625), (8420.5, 600), (8175, 780.5), (8264, 780.5), (8450, 740),
    (8624.5, 700), (8624.5, 750),
    (8664, 690), (8664, 745), (8664, 800), (8664, 850), (8664, 925), (8664, 1015), (8664, 1080),
    (8270, 1266), (8400, 1266), (8492, 1266), (8590, 1200), (8664, 1163), (8664, 1239),
    (8664, 1321),
    (8175, 1320), (8160, 1353), (8392.5, 1330), (8392.5, 1385), (8422.5, 1335), (8631, 1325),
    # Between C and B, as their swings stand (est. where none is drawn: the two-berth
    # rooms amidships and by the ladderway).
    (8926.5, 690), (8830, 825), (8926.5, 770), (8965.5, 735), (8965.5, 805), (9129.5, 785),
    (8969, 915), (9129.5, 915), (8969, 1000), (9129.5, 1000), (8969, 1080), (9129.5, 1080),
    (8790, 1153.5), (8896.5, 1225), (8933, 1300), (8967.5, 1300),
    (9161, 760), (9161, 840), (9161, 905), (9161, 1000), (9161, 1065), (9161, 1150), (9161, 1240),
    # Forward of B: the W.C.s from the landing; the firemen's quarters and the greasers'
    # room from it (est.: the plate draws the firemen's swing at the landing's port
    # end).
    (9325, 868), (9340, 1114.5), (9392.5, 885), (9392.5, 1090),
]

OPEN = [
    # Aft: the store's two steps; the centre passages into the landing, the side
    # passages into them.
    (614, 1010, 626, 1110),
    (962, 1008, 974, 1028), (962, 1085, 974, 1115), (862, 1072.5, 906, 1084.5),
    (866, 996, 886, 1008), (871, 1115.5, 889, 1127.5),
    # The landing's two rectangles; the passages from her sides into it.
    (1023.5, 1010, 1035.5, 1160), (1035, 983, 1056, 995), (1041, 1164, 1060, 1176),
    # The landing into the passage along the block's after side, and that passage into
    # the passages either side of the block, from her sides and along them.
    (1201.5, 995, 1213.5, 1160), (1213, 903.5, 1240, 915.5), (1251.5, 915, 1263.5, 946),
    (1251.5, 1172, 1263.5, 1204), (1218, 1203.5, 1243, 1215.5),
    (1415, 903.5, 1436, 915.5), (1435, 927, 1447, 946),
    (1417, 1203.5, 1450, 1215.5), (1449.5, 1171, 1461.5, 1192),
    # Between O and N: the passages into the corridors, the corridors' two pieces each,
    # the four-berth room round its recess.
    (1672, 900, 1684, 938), (1805, 900, 1817, 920), (1815, 862.5, 1842, 874.5),
    (2032, 862.5, 2062, 874.5),
    (1672, 1160, 1684, 1215), (1805, 1175, 1817, 1215), (1787, 1215.5, 1808, 1227.5),
    (2039, 1221, 2063, 1233), (1545, 1309.5, 1570, 1321.5),
    # Between N and M: the passages into the corridors; the cross passages; the entrance
    # into both corridors and into its stair box; the stair's room into its cross
    # passage; each inner room into its leg.
    (2275, 863, 2309, 875), (2522, 863, 2554, 875), (2663, 863, 2697, 875),
    (2315, 921, 2339, 933), (2315, 1161, 2339, 1173), (2304, 1036, 2316, 1055),
    (2489, 921, 2511, 933),
    (2287, 1216, 2316, 1228), (2570, 1216, 2600, 1228), (2734, 1173, 2746, 1216),
    (2645, 921, 2734, 933), (2645, 1161, 2734, 1173), (2734, 935, 2746, 1155),
    (2770, 712, 2910, 724), (2696, 723, 2708, 746), (2610, 1431, 2632, 1443),
    (2435, 1439, 2457, 1451),
    # Between M and L: the passages into the corridors; the corridors round the casing's
    # after end; the passages into the cross passages; each inner room into its leg.
    (3022, 740.5, 3051, 752.5), (3268, 740.5, 3294, 752.5), (3412, 740.5, 3444, 752.5),
    (3011.5, 762, 3023.5, 793),
    (3442, 646, 3454, 675), (2920, 791, 2980, 803), (2920, 1291, 2980, 1303),
    (2920, 1339, 2985, 1351),
    (3274, 1339, 3311, 1351), (3417, 1339, 3441, 1351), (3438.5, 1423, 3450.5, 1455),
    (3104, 1454.5, 3128, 1466.5),     # Between L and K: the lavatory's two rectangles; the passages into each other and
    # into the corridor; each L room into its leg; the ladder's space into the starboard
    # corridor, and the passages off it.
    (3604, 672, 3685, 684), (3769, 672, 3785, 684), (3791, 708, 3803, 735),
    (3998, 698, 4030, 710), (4109, 617, 4135, 629),
        (4242, 698, 4278, 710), (4347, 630.5, 4377, 642.5),
    (3602, 1347.5, 3634, 1359.5), (3835, 1385.5, 3868, 1397.5), (4117, 1385.5, 4136, 1397.5),
    (4265, 1385.5, 4282, 1397.5), (3730, 1468, 3752, 1480),     (3975, 1465.5, 3999, 1477.5),     # Between K and J: the stewards' quarters' two rectangles, the bakery's two; the
    # passages round the casing into each other.
    (4548.5, 693, 4560.5, 795), (4450, 1167, 4462, 1272), (4729, 793, 4795, 805),
    (4729, 1272, 4795, 1284),
    (4529, 1316.5, 4548, 1328.5),
    # Between J and G: each saloon's rectangles.
    (4961.5, 645, 4973.5, 794), (5191, 520, 5203, 794), (5338, 895.5, 5492, 907.5),
    (5338, 1169.5, 5492, 1181.5),
    (5191, 1279, 5203, 1560), (5596, 658, 5608, 783), (5596, 800, 5608, 885),
    (5606, 781, 5738, 793),
    (5596, 1171, 5608, 1260), (5596, 1267, 5608, 1445), (5606, 1257.5, 5738, 1269.5),
    (5501, 1443.5, 5557, 1455.5),
    (4913, 1415.5, 4997, 1427.5), (4804, 632.5, 4929, 644.5),
    # Between G and F: the pantry's two rectangles; the passage into the lobby; the
    # lobby's three rectangles; the cooling room's and the temperate room's two.
    (6794, 592, 6856, 604), (6733, 630, 6786, 642), (6343, 739, 6569, 751),
    (6778, 874.5, 6856, 886.5), (6698, 1161, 6856, 1173),
    (6555, 1257.5, 6667, 1269.5), (6312, 1355.5, 6444, 1367.5),
    # Between F and E: the passages into each other.
    (6865, 802.5, 6930, 814.5),
    # Between E and D: the side passages into the passages along her; the lobby's two
    # rectangles; the starboard passages into the passage along her.
    (7671, 760, 7698, 772), (7671, 798, 7698, 810), (7850, 760, 7872, 772), (7850, 798, 7872, 810),
    (8014, 770, 8026, 800), (8024, 690.5, 8049, 702.5), (8024, 876, 8090, 888),
    (8026, 1216, 8090, 1228), (7517, 1226, 7529, 1263),
    (7672, 1216, 7701, 1228), (7852, 1216, 7876, 1228),
    (7674, 1261.5, 7702, 1273.5), (7856, 1261.5, 7878, 1273.5), (8024, 1261.5, 8055, 1273.5),
    # Between D and C: the passages into each other round the stair's room; the passages
    # along the court and down by the bunker hatch into the starboard passage along her;
    # the short passages to her side into it.
    (8393, 662, 8416, 674), (8420, 745, 8432, 829), (8304.5, 700, 8316.5, 776),
    (8200.5, 700, 8212.5, 776), (8140, 827, 8414, 839),
    (8420, 838, 8432, 878), (8511.5, 788, 8523.5, 878), (8618.5, 788, 8630.5, 878),
    (8628, 876, 8652, 888),
    (8418, 734, 8426, 746), (8169, 1270, 8181, 1290),
    (8140, 1157.5, 8303, 1169.5), (8140, 1218.5, 8171, 1230.5), (8628, 1119.5, 8652, 1131.5),
    (8396, 1292, 8419, 1304), (8634, 1288, 8653, 1300), (8584, 1270, 8596, 1290),
    # Between C and B: the passages into each other round the hatch and the rooms; the
    # firemen's quarters' steps.
    (8930.5, 819, 8961.5, 831), (8965, 837, 8977, 871), (9123.5, 837, 9135.5, 871),
    (8936, 869, 8965, 881),
    (8936, 1112, 8965, 1124), (8900.5, 1147.5, 8963.5, 1159.5), (8980, 1147.5, 9065, 1159.5),
    (9078, 1147.5, 9126, 1159.5), (9123.5, 1122, 9135.5, 1150), (8937, 1275.5, 8963.5, 1287.5),
    (9068.5, 1160, 9080.5, 1268),
    (9530.5, 780, 9542.5, 905), (9644, 810, 9656, 1160), (9762, 840, 9774, 1130),
]

STAIRS = [
    # The main third-class stairway down to G deck: the port part of the plate's well
    # (its rail at px 1081.5), where G deck's plate draws its flight (px 1080-1175
    # there), the rest left to the flight coming down from E deck. The plate draws 73 px
    # of treads (1.9 m) for 2.44 m; a body climbs no steeper than STEEPEST, so it runs
    # on forward into the landing to 116 px (3.0 m), its foot at G deck's landing. Its
    # head aft est.
    ("third-class stairway", 1051.5, 1035.5, 1167.5, 1081.5, "aft", "g", "f"),
    # Between O and N. The third-class stairway's flight down to G deck in its
    # enclosure: the port one of the two the plate draws, as G deck's plate draws its
    # own; the starboard one is the flight E deck's plate draws coming down (px
    # 2080-2175 on Plate IV). The plate's 90 px of treads run on aft into the landing to
    # 111 px (2.9 m), the head aft est.
    ("third-class stairway", 1916, 709.5, 2028, 757.5, "aft", "g", "f"),
    # The after second-class stairway's flight down to G deck: the port one, as the
    # flights above alternate (D deck's port, d.py) and G deck's plate draws its own;
    # its 81 px of treads run on aft over the landing to 111 px (2.9 m), rising aft as D
    # deck's does.
    ("second-class stairway", 1895, 955.5, 2009, 1005.5, "aft", "g", "f"),
    # Between N and M: the stair down to G deck's stores, the inboard of the two flights
    # the plate draws side by side (the outboard one is E deck's, which E's plate draws
    # over it), over G deck's flight down to the orlop (g.py): 114.5 px (2.96 m) as the
    # plate draws them, rising forward to the space before bulkhead M (est.), its foot
    # by G's ice cream store.
    ("stair", 2772, 666.5, 2887, 701.5, "fore", "g", "f"),
    # Between L and K, the engineers' two ways down to G deck, their feet where G deck's
    # plate draws them (g.py): the stair in its walled box on the port side (BOT: the
    # engineers' stores and workshop alongside the reciprocating engine room), the
    # plate's 82 px of treads (2.2 m) run on forward to 109 px (2.9 m) over the passage
    # to the junior second engineer's and third engineer's doors, its head forward est.;
    # and the ladder along L to starboard, as a stair, 111 px (2.9 m) athwart her from G
    # deck's ladder's foot to its head by the corridor. E deck's ladder down to F stands
    # in the same box as the port stair (e.py): the lay keeps them clear of each other.
    ("stair", 3681, 643, 3790, 678, "fore", "g", "f"),
    ("ladder", 3598.25, 1240, 3638, 1351, "starboard", "g", "f"),
    # Between D and C, the flights down to G deck, their feet on G deck's (g.py):
    # - the double stair by the opening in D: of its two flights side by side, the port
    #   one to G (est.: G deck's plate draws no stair there; BOT's ladderways from the
    #   forward well's promenade come down to F and G here), the starboard one E deck's;
    #   its 104 px of treads run on 5 px aft and 6 px forward to 115 px (3.0 m), its
    #   head aft est.;
    # - the stair down to G deck's first-class baggage room, the inboard flight of the
    #   plate's two, run on 6.5 px aft to 110 px; its head aft est.;
    # - the stair down to the post office, the forward flight of the two along the court
    #   (the aft one E deck's, est.): the plate draws its treads at px 8315-8395, G
    #   deck's its foot at 8277-8369 (g.py), so it runs 115 px (3.0 m) from 8254 to its
    #   foot at 8369 by G's flight on down to the mail room; its head aft est.;
    # - the racquet court's stair down to the court's door on G deck, in its pocket aft
    #   of D (E to D's squash stairway), 100 px of treads run on to 115 px (3.0 m); its
    #   head to starboard, by the opening in D the pocket is entered through.
    ("stair", 8198, 700, 8313, 738.5, "aft", "g", "f"),
    ("stair", 8414, 784.5, 8524, 825, "aft", "g", "f"),
    ("stair", 8254, 1125.5, 8369, 1163.5, "aft", "g", "f"),
    ("racquet court stair", 8094.5, 890, 8134.75, 1005, "starboard", "g", "f"),
    # Between C and B, the ladderway's flight down to G deck: the port row of the
    # plate's two (G deck's plate draws its foot there, g.py), as a stair; its 106 px of
    # treads run on 4 px aft to 110 px (2.86 m), its head aft est. The starboard row is
    # E deck's.
    ("third-class ladder", 8964.5, 1179, 9074.5, 1226, "aft", "g", "f"),
    # Forward of B, the firemen's spiral staircases down to G deck and on to their
    # tunnel (BOT: "a vertical spiral staircase leading to the forward end of a
    # tunnel"), as D deck's: each a straight flight as wide as the plate's spiral (47-50
    # px), from its place forward over the landing to 110 px (2.86 m for 2.44 m), its
    # head forward, by the doors into the quarters. The plate draws the spirals' middles
    # at z -1.96 and +1.93 m.
    ("firemen's spiral staircase", 9277.5, 893, 9387.5, 940.5, "fore", "g", "f"),
    ("firemen's spiral staircase", 9277.5, 1042, 9387.5, 1090, "fore", "g", "f"),
]

# Lines moved off the plate so a door fits (deck.py's NUDGES, DOOR_MOVES; DOOR_LEAST 1 m):
NUDGES = [
    (0, -21.375, -21.875, -8.875, -6.0),  # the stewards' wall at the head of E's ladder, not under its treads
    # The cross passages and vestibule the plate draws over where P's line stands (it draws
    # no P here), aft of it, so no way through parts in two under a door's width.
    (0, -119.5, -120.0625, -5.4, -1.7),
    (0, -118.3125, -118.96875, -5.4, -1.7),
    (0, -119.375, -120.0625, 1.8, 5.2),
    (0, -118.25, -118.96875, 1.8, 5.8),
    (0, -119.4375, -120.0625, -0.4, 0.6),
    (0, -118.0, -118.96875, -0.4, 0.6),
    (2, 5.25, 5.5, 69.6, 70.8),  # bulkhead D's starboard door, where the plate draws it
    (2, 10.125, 10.1875, 31.9, 33.6),  # the Turkish bath's lobby's way into its cooling room
    (0, -95.5, -96.0, 4.5, 11.6),  # a side passage clear of two corridors' join
    (0, -94.3125, -94.75, 4.5, 11.6),  # likewise
    (2, -3.1875, -3.0625, -94.7, -85.2),  # the corridor's neck by the after entrance
    (2, -10.375, -10.25, -43.3, -41.4),  # the third engineer's door
    (2, 0.4375, 0.625, -121.3, -116.4),  # the vestibule by P's line, and the rooms off it
    (2, 1.5625, 1.75, -121.3, -116.4),  # the passage beside it, a door's width still
    (2, -6.9375, -7.1875, -88.0, -85.0),  # the bathroom's door
    (2, -9.25, -9.1875, -46.2, -43.2),  # the engineers' stairway's door
    (0, -46.125, -47.125, -10.3, -9.2),  # the engineers' stairway's enclosure, for its run to G deck
    (2, 9.625, 9.25, 74.5, 77.3),  # the four-berth room's door
    (2, -7.3125, -7.1875, 86.2, 92.6),  # the eight-berth room's door
    (2, 7.4375, 7.25, 86.2, 92.6),  # the eight-berth room's door
    (0, 78.375, 78.4375, -11.0, -3.0),  # the room's door off the passage's end
    (0, -24.125, -24.3125, 6.4, 11.5),  # the bakery's door
    (0, 55.0, 55.125, 3.6, 9.5),  # the six-berth room's door
    (0, 56.75, 57.25, -8.3, -6.4),  # room for boiler room 6's flight up (est.) and a body's lead
]
DOOR_MOVES = [
    ((102.125, 3.1875), (100.75, 3.1875)),  # the firemen's W.C.s' door aft of bulkhead B's line
    ((73.0, -7.9375), (72.0, -7.9375)),  # the eight-berth room's, clear of the passages' join
    (None, (-43.25, -10.8125)),  # the third engineer's, which the plate draws no swing for (est.)
    ((92.4375, 7.9375), None),  # the two-berth room her side leaves narrower than a body
    ((-38.0625, -10.0625), (-40.875, -8.6875)),  # the electricians', past their stair's head
    ((55.9375, -6.25), (54.625, -6.3125)),  # the four-berth room's, past boiler room 6's stair
    (None, (1.6875, -6.4375)),  # the saloons', either side of the ladderway's feet at H (est.)
    (None, (1.6875, 7.5)),
]
# Each saloon's bay aft of the casing keeps its own way in, a pier in the wide join:
SHUT = [(4.5625, -6.0)]
OPENED = [
    (4.5525, 4.5725, -9.5625, -6.125),
    (4.5525, 4.5725, -5.875, -3.25),
    (72.9275, 72.9475, -5.75, -4.375),  # the linen room's two pieces
]
# The passage two flights fill side by side; the engineers' stairway its stair fills; the
# passage along L's ladder fills.
NOT_ROOMS = [(74.0, -7.0), (-45.3, -9.7), (-48.0, 6.0)]
# The store her stem takes: no floor of hers reaches it (F_STEM).
GONE = [(126.0, 0.0), (122.0, 0.0)]
# The racquet court's upper half, open to its floor on G deck (COURT_F, gen_titanic.py).
GONE += [(75.0, 0.0)]
# Two closets whose faces only touch the rooms over them: walled, or those rooms read open.
WALLED_SOLIDS = [(-101.3, -8.0), (-97.6, -8.0)]
# A body's lead clear of the passage's forward wall at their heads (the layout lint):
STAIR_MOVES = [
    (("firemen's spiral staircase", 100.5, -2.5625), (99.75, 102.625, -2.5625, -1.3125)),
    # Short of bulkhead M's lockers a body's lead past its head, its width kept:
    (("stair", -69.75, -9.875), (-69.875, -66.875, -9.875, -8.9375)),
    # Aft of E deck's ladder's foot, in its enclosure run aft (NUDGES), its head short of the
    # foot the plate stacks it under:
    (("stair", -46.4375, -10.25), (-47.0625, -44.1875, -10.25, -9.375)),
    # On G deck's landing the passage is too short along her for a flight and a lead each end
    # (its aft wall bulkhead B's line): athwart her, aft of her way on down (one shaft, the
    # generator's), its foot to starboard. The port one's the generator leaves out.
    (("firemen's spiral staircase", 100.5, 1.3125), (100.1875, 101.1875, -0.5, 2.375, "port")),
    # A body's lead clear of G deck's wall at their feet (the layout lint):
    (("second-class stairway", -92.4375, -2.5), (-92.6875, -89.75, -2.5, -1.1875)),
    # Rising forward, its foot in G deck's passage clear of her side's rooms, inside G deck's
    # rooms' wall (g.py): the plate draws no way it rises.
    (("third-class ladder", 92.3125, 4.8125), (92.3125, 95.125, 4.6875, 5.6875, "fore")),
]
