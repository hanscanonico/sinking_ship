"""B deck from her restaurant forward to the gutter of The Shipbuilder's 1912 plan of
her first-class accommodation on the bridge deck: vol. VI (1911-12), "The White Star
Liner Titanic", Fig. 2, p. 222 (plates.tsv: SB6-222). A part of b.py, which says what
the plan is and why it is read.

Read in the page's own pixels, as deck.py says. The plan draws no door swings: a door
stands where a wall breaks for one; where the plan leaves a space blank (the galley and
pantries, not passengers'), the rooms in it are est. from its walls.
"""
PLATE = "SB6-222"
CROP = (150, 480, 3920, 1900)

# Calibrated on the shafts that stack, at the ship x A deck's calibration (a.py) or
# Plate IV's (b_aft.py) gives them: the well of the second-class staircase forward of its
# lift, which the restaurant's after wall steps round, and the casings. Its forward end
# is the gutter: the plan's two pages overlap there by about 240 px, both drawing the wall
# its last suites and its middle bath rooms end on (here px 3877, p. 223's px 200); its
# ship x read with one scale from funnel 3's casing to funnel 2's across the gutter, as
# the binding's curl leaves it.
X = [
    (261, -66.64, "the second-class staircase's well's forward wall; Plate IV's at px 3215 (b_aft.py)"),
    (977, -51.95, "the turbine engine casing's middle; A deck's at px 3777 on Plate III"),
    (2693.5, -17.48, "funnel 3's casing and shafts' middle; A deck's at 5084.5"),
    (3877, 7.08, "the wall at the gutter, p. 223's px 200 (b_fwd.py)"),
]
# No centre line is drawn: her sides' middle, at the page's middle body; across her, her
# sides' outer lines 1331 px apart from px 1400 to 2900 for her 92 ft 6 in extreme (the
# article's own table) — the page is drawn about 5% larger across her than along.
Z = dict(centre=((1400, 1192.25), (3800, 1192.75)), scale=0.021181)

ROOMS = [
    # The a la carte restaurant, carried out to her port side over the Olympic's second-
    # class promenade, round the second-class staircase's enclosure (b_aft.py) in its
    # after wall: three rectangles that are one room.
    ("à la carte restaurant", 188, 533.75, 845, 1035),
    ("à la carte restaurant", 261, 1035, 841, 1338),
    ("à la carte restaurant", 188, 1338, 795, 1600),
    # The Cafe Parisien along her starboard side, outboard of the restaurant, from the
    # restaurant's after wall to the first starboard stateroom.
    ("Café Parisien", 188, 1605, 1440, 1852),
    # The restaurant's galley and pantries, blank on the plan (est. from its walls): the
    # galley forward of the restaurant, round the turbine engine casing; a pantry each
    # side of the reception room's after end.
    ("restaurant galley", 845, 533.75, 1298, 1035),
    ("restaurant galley", 1111, 1035, 1298, 1338),
    ("restaurant pantry", 1298, 533.75, 1448.5, 778),
    ("restaurant pantry", 884, 1338, 1298, 1523),
    # The way into the restaurant from the reception room, along the cafe's wall.
    ("restaurant vestibule", 795, 1338, 884, 1523),
    ("restaurant vestibule", 795, 1523, 1298, 1605),
    # The restaurant's reception room round the after grand staircase (The Shipbuilder:
    # "a reception room has also been provided in connection with the restaurant"),
    # forward of the galley: three rectangles that are one room, open into both
    # corridors at its forward corners.
    ("reception room, B deck", 1298, 778, 1800, 1047),
    ("reception room, B deck", 1298, 1047, 1762.5, 1337),
    ("reception room, B deck", 1298, 1337, 1800, 1602),
    # Over its after end either side, three staterooms each, the after two entered from
    # it (est.), the third from a passage off the corridor.
    ("three-berth first-class stateroom, B deck", 1448.5, 533.75, 1577, 778),
    ("first-class stateroom, B deck", 1577, 533.75, 1708, 778),
    ("first-class stateroom, B deck", 1708, 533.75, 1843, 778),
    ("passage, B deck", 1800, 778, 1843, 990),
    ("three-berth first-class stateroom, B deck", 1440, 1602, 1569, 1852),
    ("first-class stateroom, B deck", 1569, 1602, 1704, 1852),
    ("first-class stateroom, B deck", 1704, 1602, 1836.5, 1852),
    ("passage, B deck", 1800, 1411, 1836.5, 1602),
    # Her two corridors, port and starboard of the casings.
    ("B deck corridor", 1800, 990, 3877, 1049),
    ("B deck corridor", 1800, 1338, 3877, 1411),
    # Between the casings: the cross passage at the expansion joint; the gentlemen's
    # lavatory and the stewards' pantry under it; a cross passage, three bathrooms, two
    # pairs of three-berth staterooms a cross passage apart, and two more bathrooms.
    ("passage, B deck", 2203, 1049, 2256, 1338),
    ("gentlemen's lavatory, B deck", 3035, 1049, 3250, 1250),
    ("stewards' pantry", 3035, 1250, 3250, 1338),
    ("passage, B deck", 3250, 1049, 3290, 1338),
    ("bathroom, B deck", 3290, 1049, 3390, 1145),
    ("bathroom, B deck", 3290, 1145, 3390, 1245),
    ("bathroom, B deck", 3290, 1245, 3390, 1338),
    ("three-berth first-class stateroom, B deck", 3390, 1049, 3560, 1195),
    ("three-berth first-class stateroom, B deck", 3390, 1195, 3560, 1338),
    ("passage, B deck", 3560, 1049, 3600, 1338),
    ("three-berth first-class stateroom, B deck", 3600, 1049, 3780, 1195),
    ("three-berth first-class stateroom, B deck", 3600, 1195, 3780, 1338),
    # Two more bathrooms forward of them, to the gutter's wall, where p. 223's cross
    # passage begins.
    ("bathroom, B deck", 3780, 1049, 3877, 1145),
    ("bathroom, B deck", 3780, 1145, 3877, 1245),
    # Her suite rooms along each side, as the plan heads them: each a stateroom by her
    # side, a berth in its alcove; its wardrobe room inboard of it; and inboard of that,
    # in turn, a single-berth stateroom or the suite's bathroom; a passage down the
    # suite's forward side from the corridor to its rooms.
    # port suites, p. 222
    ('first-class stateroom, B deck', 1843, 533.75, 2029, 784),
    ('single-berth first-class stateroom, B deck', 1843, 845, 1983.5, 990),
    ('passage, B deck', 1983.5, 784, 2029, 990),
    ('first-class stateroom, B deck', 2029, 533.75, 2199, 784),
    ('bathroom, B deck', 2029, 845, 2159.5, 990),
    ('passage, B deck', 2159.5, 784, 2199, 990),
    ('first-class stateroom, B deck', 2256, 533.75, 2441, 784),
    ('single-berth first-class stateroom, B deck', 2256, 845, 2397.5, 990),
    ('passage, B deck', 2397.5, 784, 2441, 990),
    ('first-class stateroom, B deck', 2441, 533.75, 2624, 784),
    ('bathroom, B deck', 2441, 845, 2577, 990),
    ('passage, B deck', 2577, 784, 2624, 990),
    ('first-class stateroom, B deck', 2624, 533.75, 2802, 784),
    ('single-berth first-class stateroom, B deck', 2624, 845, 2755.5, 990),
    ('passage, B deck', 2755.5, 784, 2802, 990),
    ('first-class stateroom, B deck', 2802, 533.75, 2984, 784),
    ('bathroom, B deck', 2802, 845, 2937, 990),
    ('passage, B deck', 2937, 784, 2984, 990),
    ('first-class stateroom, B deck', 2984, 533.75, 3162, 784),
    ('single-berth first-class stateroom, B deck', 2984, 845, 3116, 990),
    ('passage, B deck', 3116, 784, 3162, 990),
    ('first-class stateroom, B deck', 3162, 533.75, 3336, 784),
    ('bathroom, B deck', 3162, 845, 3297, 990),
    ('passage, B deck', 3297, 784, 3336, 990),
    ('first-class stateroom, B deck', 3336, 533.75, 3513, 784),
    ('single-berth first-class stateroom, B deck', 3336, 845, 3475, 990),
    ('passage, B deck', 3475, 784, 3513, 990),
    ('first-class stateroom, B deck', 3513, 533.75, 3699, 784),
    ('bathroom, B deck', 3513, 845, 3652.5, 990),
    ('passage, B deck', 3652.5, 784, 3699, 990),
    ('first-class stateroom, B deck', 3699, 533.75, 3877, 784),
    ('single-berth first-class stateroom, B deck', 3699, 845, 3829, 990),
    ('passage, B deck', 3829, 784, 3877, 990),
    # starboard suites, p. 222
    ('first-class stateroom, B deck', 1836.5, 1605, 2018, 1852),
    ('single-berth first-class stateroom, B deck', 1836.5, 1411, 1981, 1548),
    ('passage, B deck', 1981, 1411, 2018, 1605),
    ('first-class stateroom, B deck', 2018, 1605, 2196.5, 1852),
    ('bathroom, B deck', 2018, 1411, 2154.5, 1548),
    ('passage, B deck', 2154.5, 1411, 2196.5, 1605),
    ('first-class stateroom, B deck', 2253.5, 1605, 2434, 1852),
    ('single-berth first-class stateroom, B deck', 2253.5, 1411, 2391.5, 1548),
    ('passage, B deck', 2391.5, 1411, 2434, 1605),
    ('first-class stateroom, B deck', 2434, 1605, 2615.5, 1852),
    ('bathroom, B deck', 2434, 1411, 2574, 1548),
    ('passage, B deck', 2574, 1411, 2615.5, 1605),
    ('first-class stateroom, B deck', 2615.5, 1605, 2798, 1852),
    ('single-berth first-class stateroom, B deck', 2615.5, 1411, 2752.5, 1548),
    ('passage, B deck', 2752.5, 1411, 2798, 1605),
    ('first-class stateroom, B deck', 2798, 1605, 2979, 1852),
    ('bathroom, B deck', 2798, 1411, 2928.5, 1548),
    ('passage, B deck', 2928.5, 1411, 2979, 1605),
    ('first-class stateroom, B deck', 2979, 1605, 3159, 1852),
    ('single-berth first-class stateroom, B deck', 2979, 1411, 3114.5, 1548),
    ('passage, B deck', 3114.5, 1411, 3159, 1605),
    ('first-class stateroom, B deck', 3159, 1605, 3334, 1852),
    ('bathroom, B deck', 3159, 1411, 3293, 1548),
    ('passage, B deck', 3293, 1411, 3334, 1605),
    ('first-class stateroom, B deck', 3334, 1605, 3514, 1852),
    ('single-berth first-class stateroom, B deck', 3334, 1411, 3471.5, 1548),
    ('passage, B deck', 3471.5, 1411, 3514, 1605),
    ('first-class stateroom, B deck', 3514, 1605, 3698, 1852),
    ('bathroom, B deck', 3514, 1411, 3649.5, 1548),
    ('passage, B deck', 3649.5, 1411, 3698, 1605),
    ('first-class stateroom, B deck', 3698, 1605, 3877, 1852),
    ('single-berth first-class stateroom, B deck', 3698, 1411, 3821, 1548),
    ('passage, B deck', 3821, 1411, 3877, 1605),
]

SOLIDS = [
    # The buffet across the restaurant's forward end, its shelves up to the deckhead.
    ("buffet", 753, 1038, 838, 1335, None),
    # The casings and shafts between her corridors.
    ("turbine engine casing", 841, 1035, 1111, 1338, None),
    ("reciprocating engine casing", 1762.5, 1047, 2156.5, 1338, None),
    ("lockers", 2156.5, 1047, 2203, 1338, None),
    ("stewards' stairway", 2256, 1049, 2352, 1338, None),
    ("funnel 3's casing", 2352, 1049, 3035, 1338, None),
    ("linen locker", 3780, 1245, 3877, 1338, None),
    # The after expansion joint across her suites, either side (BOT: the superstructure's
    # joints, here where the boat deck's and A deck's are).
    ("expansion joint", 2199, 533.75, 2256, 990, None),
    ("expansion joint", 2196.5, 1411, 2253.5, 1852, None),
    ('wardrobe room', 1843, 784, 1983.5, 845, None),
    ('wardrobe room', 2029, 784, 2159.5, 845, None),
    ('wardrobe room', 2256, 784, 2397.5, 845, None),
    ('wardrobe room', 2441, 784, 2577, 845, None),
    ('wardrobe room', 2624, 784, 2755.5, 845, None),
    ('wardrobe room', 2802, 784, 2937, 845, None),
    ('wardrobe room', 2984, 784, 3116, 845, None),
    ('wardrobe room', 3162, 784, 3297, 845, None),
    ('wardrobe room', 3336, 784, 3475, 845, None),
    ('wardrobe room', 3513, 784, 3652.5, 845, None),
    ('wardrobe room', 3699, 784, 3829, 845, None),
    ('wardrobe room', 1836.5, 1548, 1981, 1605, None),
    ('wardrobe room', 2018, 1548, 2154.5, 1605, None),
    ('wardrobe room', 2253.5, 1548, 2391.5, 1605, None),
    ('wardrobe room', 2434, 1548, 2574, 1605, None),
    ('wardrobe room', 2615.5, 1548, 2752.5, 1605, None),
    ('wardrobe room', 2798, 1548, 2928.5, 1605, None),
    ('wardrobe room', 2979, 1548, 3114.5, 1605, None),
    ('wardrobe room', 3159, 1548, 3293, 1605, None),
    ('wardrobe room', 3334, 1548, 3471.5, 1605, None),
    ('wardrobe room', 3514, 1548, 3649.5, 1605, None),
    ('wardrobe room', 3698, 1548, 3821, 1605, None),
]

DOORS = [
    # The cafe into the reception room, and through its sliding doors into the
    # restaurant (est.: the plan draws none).
    (1348, 1603), (330, 1600), (680, 1600),
    # The galley into the restaurant and its pantries; the pantries into the reception
    # room and the restaurant's passage (est.).
    (845, 900), (1298, 650), (1373, 778), (1090, 1523),
    # The staterooms over the reception room's after end, from it (est.).
    (1513, 778), (1642, 778), (1505, 1602), (1636, 1602),
    # The suites' passages from the corridors.
    (2006.25, 990), (2179.25, 990), (2419.25, 990), (2600.5, 990), (2778.75, 990), (2960.5, 990), (3139, 990), (3316.5, 990), (3494, 990), (3675.75, 990), (3853, 990),
    (1999.5, 1411), (2175.5, 1411), (2412.75, 1411), (2594.75, 1411), (2775.25, 1411), (2953.75, 1411), (3136.75, 1411), (3313.5, 1411), (3492.75, 1411), (3673.75, 1411), (3849, 1411),
]

OPEN = [
    # The restaurant's three rectangles, and its way in.
    (261, 1029, 841, 1041), (261, 1332, 795, 1344), (789, 1338, 801, 1458),
    (795, 1517, 884, 1529), (1292, 1523, 1304, 1602),
    # The galley's two; the reception room's three, and into the corridors.
    (1111, 1029, 1298, 1041), (1298, 1041, 1762.5, 1053), (1298, 1331, 1762.5, 1343),
    (1794, 990, 1806, 1047), (1794, 1338, 1806, 1411),
    # The passages to the first suites' rooms, and the cross passages, off the corridors.
    (1800, 984, 1843, 996), (1800, 1405, 1836.5, 1417),
    (2203, 1043, 2256, 1055), (2203, 1332, 2256, 1344),
    (3250, 1043, 3290, 1055), (3250, 1332, 3290, 1344),
    (3560, 1043, 3600, 1055), (3560, 1332, 3600, 1344),
]

STAIRS = [
    # The after grand staircase's flight down to C deck: the plate's straight flights
    # either side of A deck's curved one (a.py) run 70 px (1.4 m) for 9 ft of rise; one
    # runs on aft to a slope a body climbs, starboard of A deck's flight, whose 4 m leave
    # no other lane in the room.
    ("after grand staircase", 1300, 1286, 1470, 1337, "fore", "c", "b"),
]
