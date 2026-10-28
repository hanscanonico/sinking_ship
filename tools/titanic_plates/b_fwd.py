"""B deck from the gutter of The Shipbuilder's 1912 plan of her first-class accommodation
on the bridge deck to her house's front: vol. VI (1911-12), "The White Star Liner
Titanic", Fig. 2, p. 223 (plates.tsv: SB6-223). A part of b.py, which says what the plan
is and why it is read.

Read in the page's own pixels, as deck.py says. The plan draws no door swings: a door
stands where a wall breaks for one, else where deck.py puts a cabin's.
"""
PLATE = "SB6-223"
CROP = (180, 500, 3600, 1900)

# Calibrated on the shafts that stack, at the ship x A deck's calibration (a.py) gives
# them: funnel 2's casing, the first-class lifts and funnel 1's casing; and at its after
# end the wall at the gutter p. 222 draws too (b_mid.py).
X = [
    (200, 7.08, "the wall at the gutter, p. 222's px 3877 (b_mid.py)"),
    (744.5, 18.38, "funnel 2's casing and shafts' middle; A deck's at px 6437 on Plate III"),
    (1653.5, 36.58, "the first-class lifts' middle; A deck's at px 7125"),
    (2521, 54.18, "funnel 1's; A deck's at 7789.5"),
]
# Her sides' middle; her sides' outer lines 1340.5 px apart from px 100 to 1150 for her
# 92 ft 6 in extreme.
Z = dict(centre=((250, 1196.75), (2500, 1197.0)), scale=0.021032)

ROOMS = [
    # The cross passage at the gutter, from corridor to corridor; the stewardess's room and the ladies' lavatory aft of funnel 2's casing.
    ('passage', 200, 1056, 240, 1344),
    ("stewardesses' room", 240, 1056, 397, 1151),
    ("ladies' lavatory", 240, 1151, 397, 1344),
    # Her two corridors along the casing.
    ('B deck corridor', 200, 990, 1098, 1056),
    ('B deck corridor', 200, 1344, 1098, 1413),
    # The port suite at the gutter: its stateroom, wardrobe room and bathroom, its passage forward of them; its forward wall the plate's double one at px 355-371, the parlour suite's after wall.
    ('first-class stateroom', 192, 545, 367, 782),
    ('bathroom', 192, 848, 329, 990),
    ('passage', 329, 782, 367, 990),
    # The starboard suite at the gutter: its stateroom, wardrobe room and bathroom, its passage forward of them; its forward wall the plate's double one at px 355-371, the parlour suite's after wall.
    ('first-class stateroom', 192, 1613, 367, 1851),
    ('bathroom', 192, 1413, 329, 1556),
    ('passage', 329, 1413, 367, 1613),
    # The port parlour suite and its private promenade.
    ('private promenade', 367, 545, 1100, 729),
    ('parlour suite stateroom', 367, 729, 545, 990),
    ('bathroom', 545, 849, 686, 990),
    ('parlour suite stateroom', 686, 729, 859, 990),
    ('parlour suite sitting room', 859, 729, 1100, 990),
    # The starboard parlour suite and its private promenade.
    ('private promenade', 367, 1667, 1100, 1851),
    ('parlour suite stateroom', 367, 1413, 545, 1667),
    ('bathroom', 545, 1413, 686, 1549),
    ('parlour suite stateroom', 686, 1413, 859, 1667),
    ('parlour suite sitting room', 859, 1413, 1100, 1667),
    # The forward first-class entrance ("Entrance"): its hall round the grand staircase, and outboard of it either side a space through two openings into it.
    ('grand staircase, B deck', 1100, 790, 1600, 1613),
    ('first-class entrance, B deck', 1100, 545, 1600, 790),
    ('first-class entrance, B deck', 1100, 1613, 1600, 1851),
    # Her corridors forward of the entrance, each wider abreast of its first cabins; the landing forward of the lifts between them.
    ('B deck corridor', 1600, 990, 3390, 1053),
    ('B deck corridor', 1600, 935, 1850, 990),
    ('B deck corridor', 1600, 1352, 3390, 1410),
    ('B deck corridor', 1600, 1410, 1850, 1469),
    ('B deck corridor', 1707, 1053, 1876, 1352),
    # Amidships: bathrooms, the ladies' lavatory, funnel 1's casing, the gentlemen's lavatory, bathrooms and two staterooms, cross passages between them.
    ('bathroom', 1876, 1053, 1976, 1155),
    ('bathroom', 1876, 1155, 1976, 1250),
    ('bathroom', 1876, 1250, 1976, 1352),
    ('passage', 1976, 1053, 2010, 1352),
    ("ladies' lavatory", 2010, 1053, 2175, 1352),
    ("gentlemen's lavatory", 2867, 1053, 3050, 1250),
    ("stewards' pantry", 2940, 1250, 3050, 1352),
    ('passage', 3050, 1053, 3090, 1352),
    ('bathroom', 3090, 1053, 3190, 1150),
    ('bathroom', 3090, 1150, 3190, 1250),
    ('bathroom', 3090, 1250, 3190, 1352),
    ('passage', 3190, 1053, 3225, 1352),
    ('first-class stateroom', 3225, 1053, 3390, 1204),
    ('first-class stateroom', 3225, 1204, 3390, 1352),
    # The port cabins forward of the entrance.
    ('three-berth first-class stateroom', 1600, 545, 1745, 742),
    ('three-berth first-class stateroom', 1600, 742, 1745, 935),
    ('three-berth first-class stateroom', 1785, 545, 1925, 742),
    ('three-berth first-class stateroom', 1785, 742, 1925, 935),
    ('passage', 1745, 545, 1785, 935),
    ('three-berth first-class stateroom', 1976, 545, 2190, 742),
    ('single-berth first-class stateroom', 1976, 742, 2190, 865),
    ('single-berth first-class stateroom', 1976, 865, 2190, 990),
    ('passage', 2190, 545, 2230, 990),
    ('three-berth first-class stateroom', 2230, 545, 2424.5, 742),
    ('single-berth first-class stateroom', 2230, 742, 2424.5, 865),
    ('single-berth first-class stateroom', 2230, 865, 2424.5, 990),
    ('three-berth first-class stateroom', 2424.5, 545, 2598, 742),
    ('single-berth first-class stateroom', 2424.5, 742, 2598, 865),
    ('single-berth first-class stateroom', 2424.5, 865, 2598, 990),
    ('passage', 2598, 545, 2643, 990),
    ('three-berth first-class stateroom', 2643, 545, 2822, 742),
    ('single-berth first-class stateroom', 2643, 742, 2822, 865),
    ('single-berth first-class stateroom', 2643, 865, 2822, 990),
    ('three-berth first-class stateroom', 2822, 545, 3002, 742),
    ('single-berth first-class stateroom', 2822, 742, 3002, 865),
    ('single-berth first-class stateroom', 2822, 865, 3002, 990),
    ('passage', 3002, 545, 3035, 990),
    ('single-berth first-class stateroom', 3035, 754, 3220, 873),
    ('single-berth first-class stateroom', 3035, 873, 3220, 990),
    ('passage', 3220, 754, 3265, 990),
    ('first-class stateroom', 3265, 754, 3390, 878),
    ('single-berth first-class stateroom', 3265, 878, 3390, 990),
    # The starboard cabins forward of the entrance.
    ('three-berth first-class stateroom', 1600, 1660, 1745, 1851),
    ('three-berth first-class stateroom', 1600, 1469, 1745, 1660),
    ('three-berth first-class stateroom', 1785, 1660, 1925, 1851),
    ('three-berth first-class stateroom', 1785, 1469, 1925, 1660),
    ('passage', 1745, 1469, 1785, 1851),
    ('three-berth first-class stateroom', 1976, 1660, 2190, 1851),
    ('single-berth first-class stateroom', 1976, 1540, 2190, 1660),
    ('single-berth first-class stateroom', 1976, 1410, 2190, 1540),
    ('passage', 2190, 1410, 2230, 1851),
    ('three-berth first-class stateroom', 2230, 1660, 2424.5, 1851),
    ('single-berth first-class stateroom', 2230, 1540, 2424.5, 1660),
    ('single-berth first-class stateroom', 2230, 1410, 2424.5, 1540),
    ('three-berth first-class stateroom', 2424.5, 1660, 2598, 1851),
    ('single-berth first-class stateroom', 2424.5, 1540, 2598, 1660),
    ('single-berth first-class stateroom', 2424.5, 1410, 2598, 1540),
    ('passage', 2598, 1410, 2643, 1851),
    ('three-berth first-class stateroom', 2643, 1660, 2822, 1851),
    ('single-berth first-class stateroom', 2643, 1540, 2822, 1660),
    ('single-berth first-class stateroom', 2643, 1410, 2822, 1540),
    ('three-berth first-class stateroom', 2822, 1660, 3002, 1851),
    ('single-berth first-class stateroom', 2822, 1540, 3002, 1660),
    ('single-berth first-class stateroom', 2822, 1410, 3002, 1540),
    ('passage', 3002, 1410, 3035, 1851),
    ('single-berth first-class stateroom', 3035, 1533, 3220, 1652),
    ('single-berth first-class stateroom', 3035, 1410, 3220, 1533),
    ('passage', 3220, 1410, 3265, 1652),
    ('first-class stateroom', 3265, 1536, 3390, 1652),
    ('single-berth first-class stateroom', 3265, 1410, 3390, 1536),
]

SOLIDS = [
    # Funnel 2's casing between its fans and trunks.
    ("funnel 2's casing", 397, 1056, 1098, 1344, None),
    ('wardrobe room', 192, 782, 329, 848, None),
    ('wardrobe room', 192, 1556, 329, 1613, None),
    ('wardrobe rooms', 545, 729, 686, 849, None),
    ('wardrobe rooms', 545, 1549, 686, 1667, None),
    # The three passenger lifts ("passenger elevators").
    ('first-class lifts', 1600, 1053, 1707, 1352, None),
    ("funnel 1's casing", 2175, 1053, 2867, 1352, None),
    ('W.C.s', 2867, 1250, 2940, 1352, None),
    ('wardrobe room', 1850, 935, 1925, 990, None),
    ('expansion joint', 1925, 545, 1976, 990, None),
    ('wardrobe room', 1850, 1410, 1925, 1469, None),
    ('expansion joint', 1925, 1410, 1976, 1851, None),
]

DOORS = [
    (348, 990),
    (348, 1413),
    (1040, 729),
    (859, 859.5),
    (615, 990),
    (980, 990),
    (1040, 1667),
    (859, 1540),
    (615, 1413),
    (980, 1413),
    (1242, 790),
    (1470, 790),
    (1242, 1613),
    (1463, 1613),
    (3390, 1021.5),
    (3390, 1381),
]

OPEN = [
    (2190, 984, 2230, 996),
    (2598, 984, 2643, 996),
    (3002, 984, 3035, 996),
    (3220, 984, 3265, 996),
    (1745, 929, 1785, 941),
    (2190, 1404, 2230, 1416),
    (2598, 1404, 2643, 1416),
    (3002, 1404, 3035, 1416),
    (3220, 1404, 3265, 1416),
    (1745, 1463, 1785, 1475),
    (1092, 990, 1104, 1056),
    (1092, 1344, 1104, 1413),
    (1594, 935, 1606, 1056),
    (1594, 1344, 1606, 1469),
    (1600, 984, 1850, 996),
    (1600, 1407, 1850, 1419),
    (1707, 1050, 1876, 1062),
    (1707, 1338, 1876, 1350),
    (200, 1050, 240, 1062),
    (200, 1338, 240, 1350),
    (1976, 1047, 2010, 1059),
    (1976, 1346, 2010, 1358),
    (3050, 1047, 3090, 1059),
    (3050, 1346, 3090, 1358),
    (3190, 1047, 3225, 1059),
    (3190, 1346, 3225, 1358),
]

STAIRS = [
    # The grand staircase's flight down to C deck: the port half of the plate's flights, A deck's
    # coming down to starboard of it (a.py), as long as a body climbs.
    ("grand staircase", 1330, 1056, 1500, 1192, "fore", "c", "b"),
]
