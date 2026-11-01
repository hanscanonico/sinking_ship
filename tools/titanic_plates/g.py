"""G deck, the lower deck, as Plate V draws it ("Lower Dk G"): The Shipbuilder, June 1911,
leaf n320 (plates.tsv).

Read in the plate's own pixels, as deck.py says. Where the plate and a body disagree,
the comment beside the piece says what was changed and why. The plate's doors are swings
drawn over unbroken wall lines: a door stands at its swing. A room's side against her
hull is on the hull's double line's middle at the room's middle.

The plate draws the Olympic. G deck was the lowest deck any passengers or crew lived on
(BOT, "Decks and Accommodation", G deck): from forward, 15 leading firemen and 30
greasers; third class in 26 rooms for 106 in the next compartment; the first-class
baggage room, the post office, the racquet court and seven third-class rooms for 34 in
the next; the 'tween-deck bunkers round the boiler casings; the engineers' stores and
workshop alongside the reciprocating engine room; ship's stores abreast of the turbine
engine room and their main body in the compartment abaft it; and 186 third class in 60
rooms in the two compartments after that. Where the plate draws the Olympic's third-class
OPEN BERTHS — between bulkheads B and C, and to port between C and D — BOT gives the
Titanic's rooms, so those rooms are laid est. (BOT, "Decks and Accommodation", G deck),
patterned on the rooms the plate draws on F deck over them, clipped to G's sides; her
sides, No. 2 hatch's trunk, the court, the stairs' landings and the bulkheads stay as the
plate draws them. The Shipbuilder vol. VI (1912) says only that "on the remaining decks
the number of staterooms has been increased", and draws no plan of G deck.

The 'tween-deck bunkers round the boiler casings hold coal, so they are SOLIDS: nobody
walks in them, and her cells take them in slice 8.
"""
PLATE = "V"
CROP = (440, 1745, 10400, 2925)

# Calibrated piecewise on the watertight bulkheads the view draws, each at
# tools/gen_titanic.py's BULKHEADS, and on her ends: the view's after end on her rudder
# post (X_AP, her stern below KNUCKLE), its forward end on her stem at this height (X_FP
# raked, gen_titanic.py's stem_x). Each bulkhead's plate x is its ink's middle down the
# view. Two read off BULKHEADS here:
# - M: Plate III's elevation steps M forward between the orlop and F deck (its line at
#   px 3322 there, -64.87 m, against -65.96 above and -65.76 below), and this view, the
#   orlop's and the tank top's all draw M there, 55% of the way from N to L. Calibrated
#   on BULKHEADS' -66.02, the stores between N and M would come out 7% short and the
#   turbine room's 5% long; so M is calibrated on the elevation's step instead.
# - B is not a control: this view (and F deck's) draws it 2.3 m aft of BULKHEADS'
#   101.85, at 99.5 by C and A, near the elevation's second line at 100.10 between the
#   lower orlop and F deck. Calibrated on 101.85, B-C would be 16% short.
# A straight line through the bulkheads (38.16 px a metre) leaves them -0.55 m (P), -0.03
# (O), -0.07 (N), +0.21 (M's step; +1.36 against BULKHEADS' M), +0.51 (L), +0.32 (K), +0.17
# (J), -0.02 (H), -0.06 (G), -0.08 (F), -0.14 (E), -0.25 (D), -0.18 (C) and +0.18 (A) off;
# B -2.37. Piecewise, every control reads exactly, each compartment at 37.6-38.9 px a
# metre but P-O's, 39.3 (the plate draws it 0.5 m long). Her stem at G deck sits 39 px
# short of A's scale: forward of A the view is 7% short, as E deck's bow is on Plate IV
# (#360).
X = [
    (470, -129.58, "her rudder post, the view's after end (X_AP)"),
    (874.0, -118.97, "bulkhead P"),
    (1553.5, -101.69, "bulkhead O"),
    (2183.6, -85.14, "bulkhead N"),
    (2967.9, -64.87, "bulkhead M, as Plate III's elevation steps it between the orlop and F deck"),
    (3598.8, -48.63, "bulkhead L"),
    (4390.1, -27.71, "bulkhead K"),
    (4802.5, -16.75, "bulkhead J"),
    (5499.0, 1.69, "bulkhead H"),
    (6165.1, 19.18, "bulkhead G"),
    (6824.0, 36.46, "bulkhead F"),
    (7491.2, 54.01, "bulkhead E"),
    (8126.4, 70.76, "bulkhead D"),
    (8722.1, 86.30, "bulkhead C"),
    (9862.0, 115.81, "bulkhead A"),
    (10350, 129.45, "her stem at G deck (X_FP raked)"),
]
# The centre line, fitted to its dashes as drawn from px 600 to 10100 (75 dashes, 1.9 px
# rms, every 1000 px stretch within 4 px of the line); across her, her sides' double
# lines' middles 1073.1 px apart from px 3800 to 6700 for her 92 ft moulded. Her sides'
# middle stands 7-10 px (0.2-0.26 m) to starboard of the drawn centre line amidships, 0-6
# px toward her ends: rooms at her side read from the centre line as drawn.
Z = dict(centre=((600, 2342.4), (10100, 2298.3)), scale=0.02613)

# The deck itself: her whole length and breadth, rudder post to stem.
DECKS = [(470, None, 10350, None)]

ROOMS = [
    # Aft of bulkhead P: the store in her run, in two steps to her sides, and two six-berth
    # rooms either side of a wall on her centre line, entered through P. The store has no
    # door on the plate; one from the port six-berth room (est.), as D deck's stern store.
    ("store, G deck", 600, 2286.5, 723.5, 2411),
    ("store, G deck", 520, 2322, 600, 2377),
    ("six-berth third-class room, G deck", 723.5, 2239.5, 874, 2343),
    ("six-berth third-class room, G deck", 723.5, 2343, 874, 2457),
    # Third class between P and O (BOT: "The next two compartments were appropriated to
    # 186 third class passengers in 60 rooms"): two passages off P either side of a W.C.
    # and a two-berth room, into a cross passage the main third-class stairway comes down
    # to (from F deck, f.py); rooms either side of short passages to her sides, and a
    # block either side of No. 6 hatch.
    ("four-berth third-class room, G deck", 874, 2191, 1017, 2277),
    ("passage, G deck", 874, 2277, 993, 2316.5),
    ("two-berth third-class room, G deck", 922, 2316.5, 993, 2371),
    ("passage, G deck", 874, 2371, 993, 2408.5),
    ("four-berth third-class room, G deck", 874, 2408.5, 1021.5, 2506),
    ("passage, G deck", 993, 2277, 1272.5, 2408.5),
    ("passage, G deck", 1017, 2159, 1047.5, 2277),
    ("passage, G deck", 1021.5, 2408.5, 1050.5, 2536),
    ("four-berth third-class room, G deck", 1047.5, 2140, 1132, 2277),
    ("six-berth third-class room, G deck", 1132, 2112, 1217.5, 2277),
    ("four-berth third-class room, G deck", 1050.5, 2408.5, 1134, 2553),
    ("six-berth third-class room, G deck", 1134, 2408.5, 1223, 2580.5),
    ("passage, G deck", 1217.5, 2093, 1256, 2198.5),
    ("passage, G deck", 1217.5, 2198.5, 1272.5, 2277),
    ("passage, G deck", 1223, 2408.5, 1272.5, 2483),
    ("passage, G deck", 1223, 2483, 1259.5, 2599),
    ("four-berth third-class room, G deck", 1256, 2074, 1340, 2198.5),
    ("four-berth third-class room, G deck", 1340, 2052, 1423, 2198.5),
    ("passage, G deck", 1423, 2037.5, 1452, 2198.5),
    ("four-berth third-class room, G deck", 1452, 2020.5, 1553.5, 2158),
    ("two-berth third-class room, G deck", 1452, 2158, 1553.5, 2203),
    ("passage, G deck", 1272.5, 2198.5, 1519, 2232.5),
    ("two-berth third-class room, G deck", 1272.5, 2232.5, 1358.5, 2300),
    ("four-berth third-class room, G deck", 1272.5, 2300, 1358.5, 2388),
    ("two-berth third-class room, G deck", 1272.5, 2388, 1358.5, 2446),
    ("four-berth third-class room, G deck", 1474.9, 2232.5, 1553.5, 2339.5),
    ("four-berth third-class room, G deck", 1474.9, 2339.5, 1553.5, 2446),
    ("passage, G deck", 1272.5, 2446, 1519, 2483),
    ("four-berth third-class room, G deck", 1259.5, 2483, 1345, 2616.5),
    ("four-berth third-class room, G deck", 1345, 2483, 1427.5, 2640),
    ("passage, G deck", 1427.5, 2483, 1457.5, 2655),
    ("two-berth third-class room, G deck", 1457.5, 2479, 1553.5, 2534),
    ("four-berth third-class room, G deck", 1457.5, 2534, 1553.5, 2671),
    # Third class between O and N: a column of four-berth rooms along O (its end rooms an
    # L each, cut in two), the passages either side of No. 5 hatch with two-berth and
    # three-berth rooms off them, the after second-class stairway's foot (BOT: "another
    # second class stairway, which gave access to C, D, E, F and G decks") between them,
    # and a column of rooms along N off the passage beside it.
    ("four-berth third-class room, G deck", 1553.5, 1993.5, 1657, 2155),
    ("four-berth third-class room, G deck", 1657, 1976, 1691, 2081.5),
    ("four-berth third-class room, G deck", 1553.5, 2155, 1657, 2262.5),
    ("four-berth third-class room, G deck", 1553.5, 2262.5, 1657, 2340),
    ("four-berth third-class room, G deck", 1553.5, 2340, 1657, 2443),
    ("four-berth third-class room, G deck", 1553.5, 2443, 1657, 2534.5),
    ("four-berth third-class room, G deck", 1553.5, 2534.5, 1657, 2694.5),
    ("four-berth third-class room, G deck", 1657, 2626, 1695, 2713),
    ("passage, G deck", 1657, 2081.5, 1693, 2626),
    ("three-berth third-class room, G deck", 1691, 1954, 1827, 2081.5),
    ("two-berth third-class room, G deck", 1691, 2081.5, 1757.5, 2145),
    ("two-berth third-class room, G deck", 1757.5, 2081.5, 1827, 2145),
    ("two-berth third-class room, G deck", 1691, 2145, 1757.5, 2196),
    ("two-berth third-class room, G deck", 1757.5, 2145, 1827, 2196),
    ("two-berth third-class room, G deck", 1695, 2486, 1770, 2566),
    ("two-berth third-class room, G deck", 1770, 2486, 1833.5, 2566),
    ("two-berth third-class room, G deck", 1695, 2566, 1770, 2626),
    ("two-berth third-class room, G deck", 1770, 2566, 1833.5, 2626),
    ("three-berth third-class room, G deck", 1695, 2626, 1833.5, 2732.5),
    ("passage, G deck", 1827, 1935, 1860.5, 2196),
    ("passage, G deck", 1693, 2196, 1933, 2235.5),
    ("passage, G deck", 1933, 2173.5, 2043, 2235.5),
    ("passage, G deck", 1831, 2235.5, 1864, 2447),
    ("second-class entrance, G deck", 1864, 2235.5, 2043, 2293.5),
    ("passage, G deck", 1693, 2447, 2043, 2486),
    ("passage, G deck", 1833.5, 2486, 1867.5, 2750.5),
    # A two-berth room in an L round the foot of the third-class stair from F deck (the
    # passage under it).
    ("two-berth third-class room, G deck", 1860.5, 1924, 1933, 2045),
    ("two-berth third-class room, G deck", 1933, 1914, 1963.5, 1992.5),
    ("two-berth third-class room, G deck", 1963.5, 1903, 2043, 1992.5),
    ("passage, G deck", 1933, 1992.5, 2043, 2043.5),
    ("two-berth third-class room, G deck", 1860.5, 2045, 1933, 2120),
    ("two-berth third-class room, G deck", 1860.5, 2120, 1933, 2196),
    ("four-berth third-class room, G deck", 1933, 2043.5, 2043, 2173.5),
    ("two-berth third-class room, G deck", 1864, 2293.5, 1950, 2371),
    ("two-berth third-class room, G deck", 1950, 2293.5, 2043, 2371),
    ("two-berth third-class room, G deck", 1864, 2371, 1950, 2447),
    ("two-berth third-class room, G deck", 1950, 2371, 2043, 2447),
    ("two-berth third-class room, G deck", 1867.5, 2486, 1937, 2571),
    ("two-berth third-class room, G deck", 1867.5, 2571, 1937, 2644.5),
    ("four-berth third-class room, G deck", 1937, 2486, 2043, 2644.5),
    ("four-berth third-class room, G deck", 1867.5, 2644.5, 1962.5, 2762),
    ("four-berth third-class room, G deck", 1962.5, 2644.5, 2043, 2776),
    ("passage, G deck", 2043, 1893.5, 2083, 2785),
    ("two-berth third-class room, G deck", 2083, 1884, 2183.6, 1995),
    ("two-berth third-class room, G deck", 2083, 1995, 2183.6, 2060.5),
    ("four-berth third-class room, G deck", 2083, 2060.5, 2183.6, 2157),
    ("two-berth third-class room, G deck", 2083, 2157, 2183.6, 2234),
    ("four-berth third-class room, G deck", 2083, 2234, 2183.6, 2335.5),
    ("four-berth third-class room, G deck", 2083, 2335.5, 2183.6, 2448),
    ("four-berth third-class room, G deck", 2083, 2448, 2183.6, 2550),
    ("two-berth third-class room, G deck", 2083, 2550, 2183.6, 2614.5),
    ("two-berth third-class room, G deck", 2083, 2614.5, 2183.6, 2672.5),
    ("four-berth third-class room, G deck", 2083, 2672.5, 2183.6, 2794),
    # Between N and M, the main body of the stores (BOT: "In the next watertight
    # compartment abaft the turbine room were the main body of the stores"), as the plate
    # labels them, round a passage from No. 4 hatch's trunks and along M; the stair down to
    # the orlop's stores in the passage by the ice cream room.
    ("passage, G deck", 2186, 2059.5, 2292, 2135),
    ("passage, G deck", 2186, 2135, 2893.5, 2223),
    ("passage, G deck", 2186, 2223, 2259, 2633),
    ("passage, G deck", 2259, 2516.5, 2321, 2633),
    ("fruit store", 2292, 1917, 2429, 2135),
    ("milk and butter store", 2429, 1902.5, 2571.5, 2135),
    ("ice store", 2571.5, 1888, 2722.5, 2041),
    ("egg store", 2571.5, 2041, 2689, 2135),
    ("ice cream store", 2722.5, 1875.5, 2893.5, 1950),
    ("passage, G deck", 2722.5, 1950, 2893.5, 2040.5),
    ("ice making machine room", 2689, 2040.5, 2893.5, 2140.5),
    ("passage, G deck", 2893.5, 1820, 2967.9, 2262),
    ("passage, G deck", 2892, 2262, 2967.9, 2745),
    ("bacon, ham and cheese store", 2259, 2223, 2433, 2357.5),
    ("fruit and flowers store", 2433, 2223, 2601, 2357.5),
    ("mutton store", 2259, 2357.5, 2433, 2516.5),
    ("fish store", 2433, 2357.5, 2601, 2516.5),
    ("vegetable store", 2656.5, 2223, 2892, 2372.5),
    ("vegetable store", 2656.5, 2372.5, 2779.5, 2464.5),
    ("egg and potato store", 2779.5, 2372.5, 2892, 2563.5),
    ("bacon store", 2779.5, 2563.5, 2892, 2645),
    ("poultry and game store", 2609, 2464.5, 2779.5, 2645),
    ("thawing room", 2321, 2516.5, 2609, 2645),
    ("W.B. beef store", 2298.5, 2645, 2548.5, 2789),
    ("E.B. beef store", 2548.5, 2645, 2779.5, 2792),
    ("meat and poultry store", 2779.5, 2645, 2892, 2745),
    ("meat and poultry store", 2779.5, 2745, 2967.9, 2811),
    # Between M and L, abreast of the turbine engine casing, some of the ship's stores
    # (BOT: "Abreast of the turbine engine room were some of the ship's stores"): the
    # flour store to port, and to starboard a passage to the fish, milk and ice stores and
    # the grocery bulk store; each entered through M, where the plate draws their doors.
    ("flour store", 2967.9, 1811, 3416.5, 1947),
    ("passage, G deck", 2967.9, 2694, 3281.5, 2744),
    ("fish store", 2967.9, 2744, 3107.5, 2827),
    ("milk store", 3107.5, 2744, 3195, 2827),
    ("ice store", 3195, 2744, 3281.5, 2827),
    ("grocery bulk store", 3281.5, 2694, 3425.5, 2868),
    # Between L and K, alongside the reciprocating engine room (BOT: "Alongside the
    # reciprocating engine room were the engineers' stores and workshop"): to port the
    # brine tank room, the paint store and the engineers' store round a passage past the
    # engine oil tanks, to starboard the workshop and the engineers' store, a passage along
    # L between them. F deck's engineers' stair and ladder come down into the passages
    # (f.py): the plate draws no door through L or K here.
    ("brine tank room", 3598.8, 1803, 3790.5, 1919.5),
    ("paint store", 3833, 1801, 4009, 1876.5),
    ("passage, G deck", 3598.8, 1919.5, 4164.5, 2003.5),
    ("passage, G deck", 3790.5, 1802, 3833, 1919.5),
    ("passage, G deck", 3833, 1876.5, 4009, 1919.5),
    ("passage, G deck", 4009, 1800, 4164.5, 1919.5),
    ("engineers' store", 4164.5, 1798, 4390.1, 2003.5),
    ("passage, G deck", 3598.8, 2003.5, 3643.5, 2659.5),
    ("workshop", 3598.8, 2659.5, 4169, 2871),
    ("engineers' store", 4169, 2659.5, 4390.1, 2871),
    # Between D and C: the racquet court, the post office over the mail room and the
    # first-class baggage room (BOT: "the first class baggage room, the post office
    # accommodation, a racquet court"). The court's stair from F deck (f.py) comes down
    # in a pocket abaft D, cut out of boiler room 6's bunker; through D (the plate draws D
    # stopping there) a lobby, and a room off it beyond a door. The plate draws no door
    # into the court: one from the lobby (est.). The pocket's after wall stands 6 px aft of
    # the plate's and the lobby's door wall 6 px forward of it, so each is a body's width
    # (deck.py's WAY_LEAST) without moving D's line, which the court shares.
    ("passage, G deck", 8083, 2143.5, 8126.4, 2299),
    ("passage, G deck", 8126.4, 2143.5, 8169.5, 2194.5),
    ("room, G deck", 8169.5, 2143.5, 8236.5, 2194.5),
    ("squash court", 8126.4, 2194.5, 8475.5, 2435.5),
    # The baggage room steps forward abaft the court: its wall there read 5 px lower than
    # the plate's (2135) so it is one line with the rooms' beside it.
    ("first-class baggage room", 8416, 1898.7, 8722.1, 2140),
    ("first-class baggage room", 8475.5, 2140, 8722.1, 2194.5),
    ("first-class baggage room", 8618.5, 2194.5, 8722.1, 2435.5),
    ("first-class baggage room", 8475.5, 2435.5, 8722.1, 2570.5),
    ("first-class baggage room", 8445.8, 2570.5, 8722.1, 2718.2),
    ("post office", 8126.4, 2435.5, 8475.5, 2570.5),
    ("post office", 8126.4, 2570.5, 8340, 2769.5),
    ("registered letters room", 8340, 2570.5, 8445.8, 2715.5),
    # To port, where the plate draws the Olympic's "3rd CL. OPEN BERTHS", seven
    # third-class rooms for 34 (est., BOT, "Decks and Accommodation", G deck), patterned on
    # F deck's rooms over them (two eight-berth rooms, the double stair and the linen
    # room): rooms off a landing under F's stair and the passages from it. Rooms, not
    # passages, line the baggage room's wall, so deck.py gives the baggage room no door
    # into them.
    ("eight-berth third-class room, G deck", 8126.4, 1847, 8226.6, 2014),
    ("four-berth third-class room, G deck", 8226.6, 1856, 8301, 1970),
    ("eight-berth third-class room, G deck", 8301, 1866.5, 8416, 1970),
    ("passage, G deck", 8226.6, 1970, 8345, 2014),
    ("passage, G deck", 8180, 2014, 8301, 2091),
    ("passage, G deck", 8301, 2014, 8345, 2143.5),
    ("two-berth third-class room, G deck", 8126.4, 2014, 8180, 2143.5),
    ("two-berth third-class room, G deck", 8180, 2091, 8301, 2143.5),
    ("six-berth third-class room, G deck", 8345, 1970, 8416, 2143.5),
    ("four-berth third-class room, G deck", 8236.5, 2143.5, 8475.5, 2194.5),
    # Between C and B, where the plate draws the Olympic's "THIRD CLASS OPEN BERTHS" round
    # No. 2 hatch's trunk, third class in 26 rooms for 106 (est., BOT, "Decks and
    # Accommodation", G deck), patterned on F deck's rooms over them, clipped to G's sides.
    # F deck's single ladder comes down to their starboard passage (BOT: "continued to F
    # deck as a double ladder and to G deck as a single ladder"), where the plate draws its
    # foot. Port: a block either side of a short passage to her side, a cross passage. The
    # cross passage starts clear of C, a room against C instead, so deck.py gives the
    # baggage room beyond C no door into it.
    ("eight-berth third-class room, G deck", 8722.1, 1942, 8913, 2032),
    ("eight-berth third-class room, G deck", 8722.1, 2032, 8846, 2193.5),
    ("two-berth third-class room, G deck", 8846, 2032, 8913, 2143),
    ("passage, G deck", 8913, 1964, 8957, 2143),
    ("four-berth third-class room, G deck", 8957, 1975, 9038.5, 2089),
    ("two-berth third-class room, G deck", 8957, 2089, 9038.5, 2143),
    ("two-berth third-class room, G deck", 9038.5, 1990.5, 9105, 2070),
    ("two-berth third-class room, G deck", 9038.5, 2070, 9105, 2143),
    ("passage, G deck", 9105, 2002.5, 9149.3, 2143),
    ("passage, G deck", 8846, 2143, 9149.3, 2193.5),
    # Amidships: a block of six forward of the hatch's trunk, between passages.
    ("passage, G deck", 8924.5, 2193.5, 8968, 2434.5),
    ("four-berth third-class room, G deck", 8968, 2193.5, 9043, 2274),
    ("four-berth third-class room, G deck", 9043, 2193.5, 9118, 2274),
    ("four-berth third-class room, G deck", 8968, 2274, 9043, 2354),
    ("four-berth third-class room, G deck", 9043, 2274, 9118, 2354),
    ("four-berth third-class room, G deck", 8968, 2354, 9043, 2434.5),
    ("four-berth third-class room, G deck", 9043, 2354, 9118, 2434.5),
    ("passage, G deck", 9118, 2193.5, 9149.3, 2611),
    # A column of rooms along bulkhead B.
    ("two-berth third-class room, G deck", 9149.3, 2016.5, 9232.2, 2072),
    ("two-berth third-class room, G deck", 9149.3, 2072, 9232.2, 2128),
    ("two-berth third-class room, G deck", 9149.3, 2128, 9232.2, 2184.3),
    ("four-berth third-class room, G deck", 9149.3, 2184.3, 9232.2, 2268),
    ("four-berth third-class room, G deck", 9149.3, 2268, 9232.2, 2347.3),
    ("four-berth third-class room, G deck", 9149.3, 2347.3, 9232.2, 2430.6),
    ("two-berth third-class room, G deck", 9149.3, 2430.6, 9232.2, 2490),
    ("four-berth third-class room, G deck", 9149.3, 2490, 9232.2, 2598.5),
    # Starboard: a cross passage, the ladder's landing, two six-berth rooms, an
    # eight-berth room along her side, a short passage to her side and two rooms beyond.
    ("passage, G deck", 8722.1, 2434.5, 9118, 2478.5),
    ("passage, G deck", 8958.5, 2478.5, 9065, 2530.5),
    ("six-berth third-class room, G deck", 8722.1, 2478.5, 8808, 2594),
    ("six-berth third-class room, G deck", 8808, 2478.5, 8886, 2594),
    ("eight-berth third-class room, G deck", 8722.1, 2594, 8914.5, 2676),
    ("passage, G deck", 8886, 2478.5, 8958.5, 2594),
    ("passage, G deck", 8914.5, 2594, 8958.5, 2653),
    ("six-berth third-class room, G deck", 8958.5, 2530.5, 9065, 2637.5),
    ("four-berth third-class room, G deck", 9065, 2478.5, 9118, 2621.5),
    # Between B and A, the firemen's (BOT: "The forward end of this deck had accommodation
    # for 15 leading firemen and 30 greasers"): abaft them, the landing at the firemen's
    # spiral staircases between their W.C.s to port and their wash place to starboard; the
    # leading firemen to port and the greasers to starboard of No. 1 hatch and a stepped
    # wall, each in steps to her side. The W.C.s' wall stands 5.5 px to port of the plate's
    # so the leading firemen's door from the landing has a body's width of wall (0.9 m).
    ("firemen's W.C.s", 9232.2, 2043, 9381, 2180),
    ("passage, G deck", 9232.2, 2180, 9381, 2425),
    ("firemen's wash place", 9232.2, 2425, 9381, 2570.5),
    ("leading firemen's quarters", 9381, 2081.5, 9580, 2215.5),
    ("leading firemen's quarters", 9580, 2121, 9720, 2270.5),
    ("leading firemen's quarters", 9720, 2153.5, 9862, 2270.5),
    ("greasers' quarters", 9381, 2382.5, 9528, 2534),
    ("greasers' quarters", 9528, 2215.5, 9580, 2509),
    ("greasers' quarters", 9580, 2270.5, 9720, 2485),
    ("greasers' quarters", 9720, 2270.5, 9862, 2448.5),
]

SOLIDS = [
    # Aft: a W.C. between the passages off P; trunks by O; the hatches' trunks up through
    # the third-class rooms (No. 6 and No. 5, the after well's).
    ("W.C.", 874, 2316.5, 922, 2371, None),
    ("trunk", 1519, 2203, 1553.5, 2232.5, None),
    ("trunk", 1519, 2446, 1553.5, 2479, None),
    ("trunk", 1553.5, 2232.5, 1592.5, 2262.5, None),
    ("No. 6 hatch", 1358.5, 2232.5, 1474.9, 2446, None),
    ("No. 5 hatch", 1691, 2235.5, 1831, 2447, None),
    # The stores: No. 4 hatch's trunks either side, the vents between the stores.
    ("No. 4 hatch", 2186, 1987, 2286.5, 2059.5, None),
    ("No. 4 hatch", 2186, 2633, 2293, 2705.5, None),
    # The strips between those trunks and her sides, which the plate leaves empty and
    # closed off.
    ("void", 2186, 1873, 2292, 1987, None),
    ("void", 2186, 2705.5, 2298.5, 2808, None),
    ("vents", 2601, 2223, 2656.5, 2464.5, None),
    # The turbine engine casing, a trunk along L, and the discharge recesses (the plate's
    # "DISCH'GE RECESS") either side of it forward.
    ("turbine engine casing", 2967.9, 1947, 3566, 2694, None),
    ("trunk", 3566, 1949, 3598.8, 2692, None),
    ("discharge recess", 3416.5, 1804, 3598.8, 1949, None),
    ("discharge recess", 3425.5, 2692, 3598.8, 2871, None),
    # The reciprocating engine casing, and the engine oil tanks by the passage to port.
    ("engine oil tank", 3810, 1919.5, 3867, 1998, None),
    ("engine oil tank", 3925, 1919.5, 3977, 1997, None),
    ("engine oil tank", 4000, 1919.5, 4053, 1997, None),
    ("reciprocating engine casing", 3643.5, 2003.5, 4390.1, 2659.5, None),
    # From K to D, the boiler rooms' casings and round them the 'tween deck bunkers (BOT:
    # "From this point to the after end of the boiler room the space was used for the
    # 'tween deck bunkers"): coal, nobody's room. Boiler room 1 between K and J, 2 between
    # J and H, 3 H-G, 4 G-F, 5 F-E (its casing stepping out to starboard aft), 6 E-D.
    ("boiler room 1's casing", 4457, 1894, 4665, 2752.5, None),
    ("bunker", 4390.1, 1797.9, 4457, 2870.8, None),
    ("bunker", 4665, 1797.2, 4802.5, 2870.5, None),
    ("bunker", 4457, 1797.8, 4665, 1894, None),
    ("bunker", 4457, 2752.5, 4665, 2870.5, None),
    ("boiler room 2's casing", 4912.5, 1889.5, 5340.5, 2758, None),
    ("bunker", 4802.5, 1796.8, 4912.5, 2870.2, None),
    ("bunker", 5340.5, 1792.5, 5499, 2866, None),
    ("bunker", 4912.5, 1794.8, 5340.5, 1889.5, None),
    ("bunker", 4912.5, 2758, 5340.5, 2868, None),
    ("boiler room 3's casing", 5608, 1881.5, 6037, 2763, None),
    ("bunker", 5499, 1790.8, 5608, 2866, None),
    ("bunker", 6037, 1787.8, 6165.1, 2862.5, None),
    ("bunker", 5608, 1788.5, 6037, 1881.5, None),
    ("bunker", 5608, 2763, 6037, 2865, None),
    ("boiler room 4's casing", 6273.5, 1889.5, 6701, 2749, None),
    ("bunker", 6165.1, 1787.8, 6273.5, 2861.9, None),
    ("bunker", 6701, 1786.8, 6824, 2856, None),
    ("bunker", 6273.5, 1787.5, 6701, 1889.5, None),
    ("bunker", 6273.5, 2749, 6701, 2860.5, None),
    ("boiler room 5's casing", 6951.5, 1991, 7386.5, 2637.3, None),
    ("boiler room 5's casing", 7040, 2637.3, 7386.5, 2847, None),
    ("bunker", 6824, 1787.2, 6951.5, 2856, None),
    ("bunker", 7386.5, 1799, 7491.2, 2837.2, None),
    ("bunker", 6951.5, 1790.1, 7386.5, 1991, None),
    ("bunker", 6951.5, 2637.3, 7040, 2853.5, None),
    ("boiler room 6's casing", 7579.1, 2093, 8021.5, 2540, None),
    ("bunker", 7491.2, 1804, 7579.1, 2831.5, None),
    ("bunker", 8021.5, 1835, 8083, 2790, None),
    ("bunker", 8083, 1840, 8126.4, 2143.5, None),
    ("bunker", 8083, 2299, 8126.4, 2784, None),
    ("bunker", 7579.1, 1817.2, 8021.5, 2093, None),
    ("bunker", 7579.1, 2540, 8021.5, 2813.5, None),
    # Between D and C: the bunker hatch's trunk, and a trunk in the post office.
    ("bunker hatch", 8475.5, 2194.5, 8618.5, 2435.5, None),
    ("trunk", 8126.4, 2493.5, 8174.5, 2533, None),
    # Between C and B: No. 2 hatch's trunk, as the plate draws it.
    ("No. 2 hatch", 8722.1, 2193.5, 8924.5, 2434.5, None),
    # Between B and A: the firemen's two W.C.s, two closets in their wash place, No. 1
    # hatch's trunk.
    ("W.C.", 9232.2, 2122, 9305, 2160, None),
    ("W.C.", 9232.2, 2160, 9305, 2180, None),
    ("closet", 9232.2, 2425, 9305, 2456, None),
    ("closet", 9232.2, 2456, 9305, 2490, None),
    ("No. 1 hatch", 9381, 2215.5, 9528, 2382.5, None),
    # Forward of A, the collision bulkhead: the chain locker, and the store in her eyes
    # round it, in steps to her stem. The plate draws no way into the store on G deck.
    ("chain locker", 9862, 2215, 10011.5, 2387, None),
    ("store", 9862, 2189.5, 10011.5, 2215, None),
    ("store", 9862, 2387, 10011.5, 2410.5, None),
    ("store", 10011.5, 2227, 10180, 2366, None),
    ("store", 10180, 2268.5, 10350, 2320.5, None),
]

DOORS = [
    # Aft: the store from the port six-berth room (est.); the six-berth rooms through P,
    # off the passages either side of the W.C.
    (723.5, 2300), (874, 2300), (874, 2388),
    # Between P and O, as their swings stand.
    (1017, 2252), (1021.5, 2457), (993, 2344), (1047.5, 2262), (1217.5, 2235), (1050.5, 2422), (1223, 2430),
    (1256, 2150), (1423, 2150), (1452, 2103), (1452, 2182), (1272.5, 2266), (1272.5, 2344), (1272.5, 2417),
    (1490, 2232.5), (1500, 2446), (1259.5, 2520), (1427.5, 2520), (1457.5, 2505), (1457.5, 2575),
    # Between O and N.
    (1657, 2110), (1657, 2195), (1657, 2300), (1657, 2395), (1657, 2490), (1657, 2590),
    (1827, 2050), (1691, 2110), (1827, 2110), (1691, 2170), (1827, 2170),
    (1695, 2525), (1833.5, 2525), (1695, 2600), (1833.5, 2600), (1833.5, 2680),
    (1860.5, 2010), (1860.5, 2085), (1860.5, 2155), (2043, 2128), (2025, 2235.5),
    (1864, 2335), (2043, 2335), (1864, 2410), (2043, 2410),
    (1867.5, 2525), (1867.5, 2600), (2043, 2575), (1867.5, 2690), (2043, 2700),
    (2083, 1962), (2083, 2022), (2083, 2110), (2083, 2195), (2083, 2290),
    (2083, 2390), (2083, 2510), (2083, 2590), (2083, 2650), (2083, 2710),
    # The stores, off their passages; the flour store and the starboard passage through M.
    (2355, 2135), (2487, 2135), (2610, 2135), (2722.5, 1995), (2893.5, 1900), (2780, 2040.5),
    (2330, 2223), (2525, 2223), (2770, 2223), (2350, 2516.5), (2520, 2516.5),
    (2892, 2470), (2892, 2605), (2892, 2700), (2321, 2560), (2609, 2560), (2375, 2645), (2570, 2645),
    (2930, 2262), (2967.9, 1930), (2967.9, 2719),
    (3040, 2744), (3150, 2744), (3240, 2744), (3281.5, 2720),
    # Alongside the reciprocating engine room: the brine tank room, the paint store, the
    # engineers' stores.
    (3700, 1919.5), (3920, 1876.5), (4164.5, 1880), (4169, 2815),
    # The court's: D's opening (a watertight door through D), the room off the lobby, the
    # court (est.); the post office into the baggage room, the registered letters room.
    (8126.4, 2169), (8169.5, 2169), (8148, 2194.5), (8475.5, 2468), (8340, 2620),
    # The firemen's: their W.C.s and wash place off the landing, and its doors into the
    # leading firemen's and the greasers' quarters.
    (9345, 2180), (9355, 2425), (9381, 2198), (9381, 2404),
    # The rooms (est.) along bulkhead B, each off the passages abaft it: given here, so
    # deck.py gives none of them a door through B onto the firemen's landing.
    (9149.3, 2044), (9149.3, 2100), (9149.3, 2160), (9149.3, 2226), (9149.3, 2308), (9149.3, 2389),
    (9149.3, 2460), (9149.3, 2545),
    # The room (est.) under the ladder's landing, from the passage abaft it, clear of the
    # ladder.
    (8958.5, 2562),
]

OPEN = [
    # Between P and O: the passages off P into the cross passage, the side passages into it.
    (597, 2337, 603, 2362),
    (990, 2280, 996, 2313), (990, 2374, 996, 2405), (1020, 2274, 1044, 2280), (1024, 2405, 1047, 2411),
    (1220, 2274, 1269, 2280), (1220, 2195, 1253, 2201), (1269, 2201, 1275, 2229), (1226, 2405, 1269, 2411),
    (1269, 2449, 1275, 2480), (1226, 2480, 1256, 2486), (1426, 2195, 1449, 2201), (1430, 2480, 1454, 2486),
    # Between O and N: the L rooms' two pieces; the passages into each other, the
    # stairway's foot and the passage along N.
    (1654, 2003, 1660, 2078), (1654, 2629, 1660, 2682), (1930, 1932, 1936, 1990),
    (1690, 2199, 1696, 2232), (1690, 2450, 1696, 2483), (1830, 2193, 1857, 2199), (1834, 2232, 1861, 2238),
    (1930, 2199, 1936, 2232), (2040, 2176, 2046, 2232), (1861, 2238, 1867, 2290), (1834, 2444, 1861, 2450),
    (1836, 2483, 1864, 2489), (2040, 2450, 2046, 2483), (2040, 1995, 2046, 2040),
    # The stores' passages into each other, and the stair's passage into the one along M.
    (2189, 2132, 2289, 2138), (2189, 2220, 2256, 2226), (2256, 2519, 2262, 2630),
    (2890, 1953, 2896, 2038), (2890, 2138, 2896, 2220),
    (2659, 2369, 2776, 2375), (2782, 2742, 2889, 2748),
    # Alongside the reciprocating engine room: the passages into each other, and the
    # workshop's end open into the passage along L.
    (3793, 1916, 3830, 1923), (3836, 1916, 4006, 1923), (4012, 1916, 4161, 1923),
    (3830, 1879, 3836, 1916), (4006, 1879, 4012, 1916),
    (3601, 2000, 3640, 2007), (3601, 2656, 3640, 2663),
    # The baggage room's five pieces; the post office's two.
    (8478, 2137, 8719, 2143), (8621, 2191, 8719, 2197), (8621, 2432, 8719, 2438), (8478, 2567, 8719, 2573),
    (8129, 2567, 8337, 2573),
    # The seven rooms' (est.) passages into each other.
    (8229, 2011, 8298, 2017), (8304, 2011, 8342, 2017),
    # The 26 rooms' (est.) passages: the short passages into the cross passages, the
    # passages either side of the block, the ladder's landing, the passages to starboard.
    (8916, 2140, 8954, 2146), (9108, 2140, 9146, 2146), (8927, 2190, 8965, 2196), (9121, 2190, 9146, 2196),
    (8927, 2431, 8965, 2437), (9115, 2437, 9121, 2475), (8961, 2475, 9062, 2481), (8889, 2475, 8955, 2481),
    (8917, 2591, 8955, 2597),
    # The firemen's quarters' steps.
    (9577, 2128, 9583, 2212), (9717, 2160, 9723, 2267), (9525, 2385, 9531, 2505), (9577, 2273, 9583, 2485),
    (9717, 2273, 9723, 2448),
]

STAIRS = [
    # The flights from G deck down to the orlop; those coming down to G deck are F deck's
    # (f.py).
    # The stores' stair down to the orlop's (BOT: "on the former deck, abaft the turbine
    # engine room, were some store rooms"), where the plate draws it and the orlop's view
    # under it: 110 px of treads (2.84 m) for 2.44 m, run on 5 px aft to a margin under
    # STEEPEST (2.97 m); its head aft est., in the passage's open end by the ice store's
    # and the ice making machine room's doors. F deck's plate draws its flight down to G
    # over the same treads: the lay offsets the two.
    ("stair", 2779, 1955.5, 2894, 1990.5, "aft", "orlop", "g"),
    # The post office's stair down to the mail room (BOT: the post office "over the mail
    # room on the orlop"): of the plate's two flights side by side, the starboard one (est.;
    # the port one is F deck's flight down to the post office, under the treads F draws).
    # The plate draws 92 px of treads (2.4 m): it runs on 21 px aft, to 2.95 m; its head
    # forward est.
    ("stair", 8247, 2495, 8360, 2533, "fore", "orlop", "g"),
    # The firemen's spiral staircases down to the orlop and on to their tunnel (BOT: "a
    # vertical spiral staircase leading to the forward end of a tunnel, immediately above
    # the tank top"): as D deck's (d.py), each a straight flight as wide as the plate's
    # spiral (46 px), from its place forward over the landing to the run STEEPEST allows
    # (114 px, 2.95 m for 2.44 m), its head by the doors into the quarters. F deck's
    # flights down to G stand on the same spirals: the lay keeps them clear of each other.
    ("firemen's spiral staircase", 9266, 2203, 9380, 2249, "fore", "orlop", "g"),
    ("firemen's spiral staircase", 9266, 2361, 9380, 2407, "fore", "orlop", "g"),
    # The hold ladders down to the orlop's after cargo hold (P-O) and refrigerated cargo
    # holds (O-N), est.: the plates draw no access to these holds but their hatches, and
    # the tank top under them is her shaft tunnels, no floor (tanktop.py). Each runs 3.0 m
    # for 2.44 m, 0.9 m wide, at its hold's hatch where G has room for a ladder's head.
    # - The after hold's: along the cross passage's starboard side, beside the foot of F
    #   deck's main third-class stairway, its head forward by that foot. The passages
    #   along No. 6 hatch's trunk each have a stub's mouth halfway along them, so a ladder
    #   there would shut the rooms beyond it off. Its foot lands in the hold forward of
    #   the trunk on P's face.
    # - The refrigerated holds': along No. 5 hatch's trunk on its port side, its head aft
    #   by the passage along O, its foot in the port hold clear of the hatch's coaming
    #   (orlop.py), whose doors open into the starboard hold. The passage round the trunk
    #   to starboard keeps the way past it.
    ("hold ladder", 1089, 2372, 1207, 2406.5, "fore", "orlop", "g"),
    ("hold ladder", 1701.5, 2194, 1815.5, 2228, "aft", "orlop", "g"),
]

# Lines moved off the plate so a door fits (deck.py's NUDGES, DOOR_MOVES; DOOR_LEAST 1 m), her
# side held at G deck's floor taking what her low plan's line has over it (#396):
NUDGES = [
    # The court meets F deck's upper half of it, which reads 0.19 m to port and 0.06 m forward
    # of this view's.
    (2, -2.875, -3.0625, 70.9, 83.7),
    (2, 3.375, 3.1875, 70.9, 83.7),
    (0, 79.875, 79.9375, -3.1, 3.4),
    (0, 71.875, 72.0, -4.3, -3.0),  # the court's door off its lobby
    (2, -0.5625, -0.5, -119.1, -115.9),  # P's doors, where the plate draws them
    (2, 0.75, 0.5, -119.1, -115.9),
    (2, 7.5625, 7.25, -98.0, -94.5),  # the three-berth room's door, its side taken by hers
    (2, 4.875, 4.75, 97.6, 99.4),  # the four-berth room's along B
    (2, -3.125, -3.375, 99.6, 103.3),  # the leading firemen's door
    (2, 8.0625, 7.9375, -93.2, -91.0),  # the four-berth room's, off its passage's end
    (2, 5.9375, 5.75, 92.5, 95.1),  # the six-berth room's, F deck's ladder's foot beside it
]
DOOR_MOVES = [
    ((-122.9375, -1.0625), None),  # the store in her run her side leaves solid (MADE_SOLID)
    ((-115.3125, -2.3125), (-117.5, -1.6875)),  # the rooms abaft the passage's mouths, her side
    ((-115.25, 3.0625), (-117.5, 1.875)),  # leaving them no stretch at the plate's swing
    ((-108.8125, -1.9375), (-107.75, -2.625)),  # the two-berth rooms off O's cross passage
    ((-108.8125, 2.0), (-107.75, 2.6875)),
    ((-104.25, -4.0625), (-102.875, -3.75)),  # the two-berth room's, past its passage's end
    ((-94.3125, 9.0), (-94.4375, 7.8125)),  # the three-berth room's, inside her side
    ((-93.4375, 9.25), (-93.3125, 8.8125)),  # the four-berth room's, off her side's wall
    ((-115.9375, 0.0625), (-116.8125, 0.5)),  # the two-berth room's, between P's doors' passages
    ((97.375, 6.3125), (97.5625, 5.375)),  # the four-berth room's along B, inside her side
]
# The store in her run: the plate draws it no door, and her side leaves it no room for one.
MADE_SOLID = [(-124.5, 0.0)]
# F deck's ladder's foot, in the passage beside its own:
OPENED = [(92.4275, 92.4475, 4.5625, 5.75)]
# Her boiler rooms under F deck stay her estimated ones until #379 lays them, K to D (their
# casings and bunkers), and her forepeak's stores forward of A: these solids wait for it.
AWAITS = [(-27.71, 70.75), (115.81, 140.0)]
# The tip of her run, which her side at G deck leaves no room for: no floor of hers reaches it.
GONE = [(-127.0, 0.0)]
