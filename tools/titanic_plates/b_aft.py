"""B deck from her after end to her restaurant, and her whole deck's outline, as Plate IV
draws them ("Bridge Dk B"): The Shipbuilder, June 1911, leaf n318 (plates.tsv). A part of
b.py.

Read in the plate's own pixels, as deck.py says. The plate draws the Olympic's B deck;
aft of her restaurant the Titanic's was the same (b.py).
"""
PLATE = "IV"
CROP = (2040, 400, 8720, 1600)

# Calibrated on the shafts that stack, at the ship x A deck's calibration gives them
# (a.py), as A deck was on the boat deck's: her mainmast and her second-class lift aft,
# her funnels' casings forward. Aft of the lift the plate draws about 3% longer than
# forward of it, as A deck's does not: piecewise, as the creased scans need.
X = [
    (2393, -88.64, "the mainmast's middle; A deck's at px 2385 on Plate III"),
    (3082, -70.11, "the second-class lift's middle; A deck's at px 3088"),
    (5102, -17.48, "funnel 3's casing and shafts' middle; A deck's at 5084.5"),
    (6449, 18.38, "funnel 2's; A deck's at 6437"),
    (7814, 54.18, "funnel 1's; A deck's at 7790"),
]
# The centre line as drawn, fitted to it from px 2000 to 8650 (it bows 4 px over the
# scan); across her, her sides 1088 px apart at px 6000 (ship x 6) for her 92 ft moulded.
Z = dict(centre=((2000, 1024.8), (8650, 974.0)), scale=0.025773)

# The deck itself, each piece (x0, y0, x1, y1), its y None for her whole breadth: from
# where her side steps in aft to her forward end, the assembling area forward of her
# house (BOT); and aft of the step, her after end tapering to its middle, est. as two
# steps on the plate's diagonals, each about her centre line.
DECKS = [
    (2271, None, 8618, None),
    (2185, 810, 2271, 1236),
    (2100, 865, 2185, 1183),
]

ROOMS = [
    # The after second-class entrance, on her open after end: the stairway down to C,
    # D, E, F and G decks (BOT: "another second class stairway"), her mainmast through it.
    ("second-class entrance, B deck, aft", 2120, 912, 2425, 1140),
    # The second-class smoking room (the plate's "2nd class smoke room"), its bar and
    # lavatory at its after corners, and between them its after part. The bar's and the
    # lavatory's after walls under A deck's step over them (a.py), 25 px (0.7 m) forward
    # of the plate's px 2424 (est.): A deck's ladders down onto this promenade come down
    # where the plate puts them.
    ("second-class smoking room", 2580, 656, 2931, 1385),
    ("second-class smoking room", 2505, 846, 2580, 1194),
    ("second-class smoking room bar", 2449, 728, 2580, 846),
    ("second-class smoking room lavatory", 2449, 1194, 2584, 1314),
    # The second-class entrance forward of it, round its staircase and lift; its forward
    # wall where the Titanic's plan draws the restaurant's after wall (b_mid.py), 16 px
    # (0.4 m) forward of this plate's px 3142 (est.). Its vestibules on the promenades,
    # est. as its corners: their doors open into it. Forward of the lift, open to it, the
    # staircase's well in the restaurant's after wall, where A deck's flight comes down
    # (a.py): under her house's deck, in its cell, so a room of its own.
    ("second-class entrance, B deck", 2931, 695, 3158, 1338),
    ("second-class staircase, B deck", 3158, 892, 3215, 1139),
]

SOLIDS = [
    # The well of the after stairway between its flights.
    ("stairwell", 2200, 986, 2265, 1056, None),
    # No. 4 hatch's trunk up through the smoking room's after corners, carried aft to the
    # bar's and the lavatory's after walls (est.: the plate's start 30 px forward of
    # them, where its bar and lavatory end 25 px aft of these), so the house's corners
    # are square, no open deck in them.
    ("No. 4 hatch trunk", 2449, 651, 2580, 728, None),
    ("No. 4 hatch trunk", 2449, 1314, 2584, 1390, None),
    # The ventilators along the smoking room's forward wall.
    ("ventilators", 2865, 896, 2931, 1145, None),
    # The second-class lift, its starboard side under A deck's flight's port side (a.py),
    # 7 px inboard of the plate's (est.).
    ("second-class lift", 3035, 973, 3122, 1047, None),
]

# Her houses on her open after end, each roofed by A deck over it (where A deck is not,
# a roof of its own) and a cell of its own: (name, x0, y0, x1, y1), on its outer walls'
# middles: her shell's outline over her promenade there (the smoking room's, and the
# narrower entrance's forward of it to the restaurant's after wall, its well beyond it
# in the house forward of it).
HOUSES = [
    ("after_entrance_house", 2120, 912, 2425, 1140),
    ("smoking_room_house", 2449, 656, 2931, 1385),
    ("second_class_entrance_house", 2931, 695, 3158, 1338),
]

DOORS = [
    # The after entrance from either promenade.
    (2280, 912), (2280, 1140),
    # The smoking room from aft, into its bar and its lavatory, and into the entrance.
    (2505, 990), (2540, 846), (2540, 1194), (2931, 870), (2931, 1180),
    # The entrance from either promenade.
    (3010, 695), (3010, 1338),
]

OPEN = [
    # The smoking room's two rectangles; the entrance's and its well.
    (2574, 846, 2586, 1194), (3152, 892, 3164, 1139),
]

STAIRS = [
    # The after second-class stairway down to C deck: its port flight, 61 px of treads
    # (1.6 m) for 9 ft of rise, run on forward to a slope a body climbs, from the treads'
    # forward end, where her side steps in: no further aft, where the after well is under
    # B deck. Its inboard 25 px est. floor, clear of the C deck corridor's wall under it
    # (est., until C deck is traced); the starboard flight is floor.
    ("second-class stairway", 2271, 917, 2404, 958, "aft", "c", "b"),
    # The forward second-class staircase down to C deck, port of the lift: its 83 px of
    # treads run on aft over the entrance's floor, its inboard 15 px floor as the after
    # stairway's; the starboard flight is floor.
    ("second-class staircase", 2988, 904, 3118, 954, "aft", "c", "b"),
    # Down off her after end to the after third-class promenade on C deck (BOT: "two
    # ladders"): the plate's ladders on the diagonals, as stairs a body climbs along her
    # from the after step's edge, outboard of the narrower step's walls under it.
    ("ladder", 2050, 811, 2185, 855, "fore", "c", "b"),
    ("ladder", 2050, 1193, 2185, 1237, "fore", "c", "b"),
    # Down off the assembling area forward to the forward third-class promenade (BOT: "a
    # ladderway"), where the plate draws it, run on to a slope a body climbs.
    ("ladder", 8618, 830, 8750, 870, "aft", "c", "b"),
]
