"""A deck, the promenade deck, as Plate III draws it: The Shipbuilder, June 1911, leaf
n316 (plates.tsv).

Read in the plate's own pixels, as deck.py says. Where the plate and a body disagree,
the comment beside the piece says what was changed and why.
"""
PLATE = "III"
CROP = (2050, 4290, 8560, 5460)

# A deck's plan sits 12-31 px aft of the boat deck's above it on the plate, growing
# forward (0.4% shorter). Calibrated on the shafts both draw, at the ship x the boat
# deck's calibration gives them (boat.py), so her stairs and casings stack.
X = [
    (3088, -70.11, "the second-class lift's middle; the boat deck's at px 3104"),
    (5084.5, -17.48, "funnel 3's casing and shafts' middle; the boat deck's at 5101.5"),
    (6437, 18.38, "funnel 2's; the boat deck's at 6462.5"),
    (7790, 54.18, "funnel 1's; the boat deck's at 7821.5"),
]
# The centre line, as drawn at the deck's two ends; across her, the deck's edges 1102 px
# apart at px 6000 (ship x 6) for her 92 ft moulded.
Z = dict(centre=((2300, 4879), (8450, 4859)), scale=0.02545)

# The deck itself, each piece (x0, y0, x1, y1), its y None for her whole breadth: her
# length to its forward end, and its after end stepping in over B deck's three times —
# its last step cut where the old B deck ends, at x -94, until B deck is traced (#360).
DECKS = [
    (2660, None, 8492, None),
    (2584, 4511, 2660, 5247),
    (2442, 4593, 2584, 5165),
    (2182, 4757, 2442, 5001),
]

ROOMS = [
    # Aft: the verandah cafés and palm courts, port and starboard, either side of the
    # second-class staircase's landing and the bar.
    ("verandah café and palm court", 2905, 4497, 3255, 4756),
    ("verandah café and palm court", 2905, 4996, 3255, 5226),
    # The second-class landing: the boat deck's flight comes down into it to port of the
    # lift, B deck's goes down from it to starboard. The bar starts 47 px forward of the
    # plate's 3126 so B deck's flight has its run (see STAIRS).
    ("second-class entrance", 2948, 4760, 3173, 4996),
    ("bar", 3173, 4756, 3310, 4996),
    # The first-class smoking room round the house in its middle (turbine engine casing,
    # its lavatory), as five rectangles that are one room.
    ("first-class smoking room", 3255, 4497, 3676, 4756),
    ("first-class smoking room", 3310, 4756, 3676, 4996),
    ("first-class smoking room", 3255, 4996, 3676, 5226),
    ("first-class smoking room", 3676, 4497, 4015, 4753),
    ("first-class smoking room", 3676, 4989, 4015, 5226),
    ("smoking room lavatory", 3878, 4801, 4015, 4989),
    # The after first-class entrance and its staircase down to B deck.
    ("first-class entrance", 4015, 4489, 4398, 5226),
    # Between it and the lounge: the passage along the casings to port, the lounge
    # pantry and bar to starboard, the cloak room and the darkroom out on the
    # promenades.
    ("passage", 4398, 4680, 5170, 4753),
    ("lounge pantry and bar", 4675, 4753, 4813, 4987),
    ("lounge pantry and bar", 4675, 4987, 5090, 5108),
    ("lounge pantry and bar", 5090, 4987, 5170, 5108),
    ("cloak room", 5023, 4535, 5168, 4680),
    ("darkroom", 5023, 5108, 5170, 5195),
    # The first-class lounge, its bays est. as straight sides, and forward of funnel 3's
    # casing.
    ("first-class lounge", 5170, 4497, 5860, 4753),
    ("first-class lounge", 5353, 4753, 5860, 4987),
    ("first-class lounge", 5170, 4987, 5860, 5215),
    # The reading and writing room to port of funnel 2's casing, the corridor to
    # starboard of it.
    ("reading and writing room", 5860, 4524, 6340, 4744),
    ("reading and writing room", 5860, 4744, 6169, 4980),
    ("corridor", 5860, 4980, 6705, 5049),
    # The forward first-class entrance: its hall round the grand staircase, its
    # vestibules on the promenades, and the lifts' landing forward of the lifts.
    ("first-class entrance", 6788, 4524, 7083, 5200),
    ("first-class entrance", 6705, 4608, 6788, 5109),
    ("vestibule", 6705, 4524, 6788, 4608),
    ("vestibule", 6705, 5109, 6788, 5200),
    ("first-class entrance", 7167, 4740, 7285, 4971),
    # The forward staterooms (BOT: "At the forward end it contained 34 state-rooms"),
    # an outer room and an inner one either side of each short passage off the
    # corridors. Port, aft to forward:
    ("corridor", 7083, 4687, 8364, 4740),
    ("first-class stateroom, three berths", 7095, 4487, 7194, 4640),
    ("passage", 7194, 4523, 7226, 4687),
    ("first-class stateroom", 7226, 4487, 7357, 4595),
    ("first-class stateroom", 7226, 4595, 7357, 4687),
    ("passage", 7357, 4487, 7395, 4687),
    ("first-class stateroom", 7395, 4487, 7539, 4595),
    ("first-class stateroom", 7395, 4595, 7539, 4687),
    ("passage", 7539, 4522, 7573, 4687),
    ("first-class stateroom", 7573, 4487, 7693, 4595),
    ("first-class stateroom", 7573, 4595, 7693, 4687),
    ("first-class stateroom", 7693, 4487, 7814, 4595),
    ("first-class stateroom", 7693, 4595, 7814, 4687),
    ("passage", 7814, 4527, 7853, 4687),
    ("first-class stateroom", 7853, 4487, 7976, 4595),
    ("first-class stateroom", 7853, 4595, 7976, 4687),
    ("first-class stateroom", 7976, 4487, 8095, 4595),
    ("first-class stateroom", 7976, 4595, 8095, 4687),
    ("passage", 8095, 4529, 8131, 4687),
    ("first-class stateroom", 8131, 4487, 8251, 4595),
    ("first-class stateroom", 8131, 4595, 8251, 4687),
    ("first-class stateroom, three berths", 8251, 4487, 8364, 4687),
    # Starboard, aft to forward.
    ("corridor", 7083, 4971, 8364, 5028),
    ("first-class stateroom, three berths", 7095, 5078, 7194, 5222),
    ("passage", 7194, 5028, 7226, 5195),
    ("first-class stateroom", 7226, 5028, 7356, 5123),
    ("first-class stateroom", 7226, 5123, 7356, 5222),
    ("passage", 7356, 5028, 7395, 5222),
    ("first-class stateroom", 7395, 5028, 7538, 5122),
    ("first-class stateroom", 7395, 5122, 7538, 5222),
    ("passage", 7538, 5028, 7572, 5188),
    ("first-class stateroom", 7572, 5028, 7695, 5122),
    ("first-class stateroom", 7572, 5122, 7695, 5222),
    ("first-class stateroom", 7695, 5028, 7814, 5122),
    ("first-class stateroom", 7695, 5122, 7814, 5222),
    ("passage", 7814, 5028, 7856, 5183),
    ("first-class stateroom", 7856, 5028, 7973, 5122),
    ("first-class stateroom", 7856, 5122, 7973, 5222),
    ("first-class stateroom", 7973, 5028, 8094, 5122),
    ("first-class stateroom", 7973, 5122, 8094, 5222),
    ("passage", 8094, 5028, 8128, 5181),
    ("first-class stateroom", 8128, 5028, 8251, 5124),
    ("first-class stateroom", 8128, 5124, 8251, 5222),
    ("first-class stateroom, three berths", 8251, 5028, 8364, 5222),
    # Amidships of them: three bathrooms, the stewardesses' room and the ladies'
    # lavatory aft of funnel 1's casing; the gentlemen's lavatory and the servery
    # forward of it; two bathrooms and a pantry; two staterooms at her front; and the
    # cross passages between.
    ("bathroom", 7285, 4742, 7361, 4818),
    ("bathroom", 7285, 4818, 7361, 4898),
    ("bathroom", 7285, 4898, 7361, 4971),
    ("passage", 7361, 4740, 7399, 4971),
    ("stewardesses' room", 7399, 4740, 7518, 4820),
    ("ladies' lavatory", 7399, 4820, 7518, 4882),
    ("ladies' lavatory", 7399, 4882, 7449, 4971),
    ("gentlemen's lavatory", 8061, 4742, 8161, 4833),
    ("servery", 8061, 4921, 8161, 4971),
    ("passage", 8161, 4740, 8202, 4971),
    ("bathroom", 8202, 4740, 8283, 4810),
    ("bathroom", 8202, 4810, 8283, 4898),
    ("pantry", 8202, 4898, 8283, 4971),
    ("first-class stateroom", 8283, 4740, 8364, 4858),
    ("first-class stateroom", 8283, 4858, 8364, 4971),
]

SOLIDS = [
    # Aft: the two lamp rooms (LR), the fans, and the second-class lift.
    ("lamp room", 2801, 4703, 2905, 4750, None),
    ("lamp room", 2803, 4996, 2905, 5052, None),
    ("fans", 2801, 4753, 2948, 4996, None),
    ("second-class lift", 3049, 4841, 3126, 4905, None),
    # The house in the smoking room: the turbine engine casing and its shafts.
    ("turbine engine casing", 3676, 4753, 3878, 4989, None),
    ("shafts", 3878, 4753, 4015, 4801, None),
    # The after entrance's lavatories either side of its staircase.
    ("lavatories", 4015, 4787, 4049, 4953, None),
    ("lavatories", 4355, 4753, 4398, 4984, None),
    # The reciprocating engine casing, and funnel 3's casing between its shafts.
    ("reciprocating engine casing", 4398, 4753, 4675, 5108, None),
    ("fans and trunks", 4813, 4753, 4875, 4987, None),
    ("funnel 3's casing", 4875, 4753, 5262, 4987, None),
    ("fans and trunks", 5262, 4753, 5353, 4987, None),
    # Funnel 2's casing between its shafts.
    ("fans and trunks", 6169, 4744, 6253, 4980, None),
    ("funnel 2's casing", 6253, 4744, 6640, 4980, None),
    ("fans and trunks", 6640, 4744, 6705, 4980, None),
    # The three first-class lifts.
    ("first-class lifts", 7083, 4747, 7167, 4971, None),
    # Funnel 1's casing between its shafts, and the closets and W.C.s beside it.
    ("W.C.s", 7449, 4882, 7518, 4971, None),
    ("fans and trunks", 7518, 4740, 7611, 4971, None),
    ("funnel 1's casing", 7611, 4740, 7989, 4971, None),
    ("fans and trunks", 7989, 4740, 8061, 4971, None),
    ("W.C.s", 8061, 4833, 8119, 4921, None),
    ("closet", 8119, 4833, 8161, 4921, None),
    # The electric cranes on the after deck.
    ("electric crane", 2752, 4405, 2808, 4461, 2.5),
    ("electric crane", 2752, 5275, 2808, 5331, 2.5),
]

DOORS = [
    # The verandahs from the after promenade, and through their revolving doors into
    # the smoking room (the plate's crossed circles).
    (2905, 4600), (2905, 5110), (3255, 4700), (3255, 5040),
    # The bar into the smoking room; the smoking room's lavatory.
    (3310, 4870), (3955, 4989),
    # The after entrance from the promenades and into the smoking room.
    (4060, 4489), (4060, 5226), (4350, 4489), (4350, 5226), (4015, 4620), (4015, 5110),
    # The passage from the after entrance and into the lounge; the cloak room; the
    # pantry into the lounge and onto the starboard promenade; the darkroom.
    (4398, 4716), (5170, 4716), (5023, 4600), (5170, 5050), (4800, 5108), (5100, 5195),
    # The lounge onto its promenades; the reading room and the corridor into the lounge
    # and the forward entrance.
    (5500, 4497), (5500, 5215), (5860, 4630), (5860, 5014), (6705, 5014), (6340, 4630),
    # The forward entrance's vestibules from the promenades and into its hall.
    (6705, 4566), (6705, 5155), (6746, 4608), (6746, 5109),
    # The corridors' ends out onto the promenade forward.
    (8364, 4713), (8364, 4999),
]

OPEN = [
    # The smoking room's five rectangles.
    (3670, 4497, 3682, 4753), (3670, 4989, 3682, 5226),
    (3310, 4750, 3676, 4762), (3310, 4990, 3676, 5002),
    # The lounge pantry and bar's three.
    (4675, 4981, 4813, 4993), (5084, 4987, 5096, 5108),
    # The lounge's three, and the reading room's two.
    (5353, 4747, 5860, 4759), (5353, 4981, 5860, 4993), (5860, 4738, 6169, 4750),
    # The forward entrance's hall: its two rectangles, then into its lifts' landing and
    # the corridors; the
    # corridors into their passages and the cross passages.
    (6782, 4608, 6794, 5109),
    (7077, 4687, 7089, 4740), (7077, 4971, 7089, 5028),
    (7167, 4734, 7285, 4746), (7167, 4965, 7285, 4977),
    (7194, 4681, 7226, 4693), (7357, 4681, 7395, 4693), (7539, 4681, 7573, 4693),
    (7814, 4681, 7853, 4693), (8095, 4681, 8131, 4693),
    (7194, 5022, 7226, 5034), (7356, 5022, 7395, 5034), (7538, 5022, 7572, 5034),
    (7814, 5022, 7856, 5034), (8094, 5022, 8128, 5034),
    (7361, 4734, 7399, 4746), (7361, 4965, 7399, 4977),
    (8161, 4734, 8202, 4746), (8161, 4965, 8202, 4977),
]

STAIRS = [
    # Down off its after end's first step to B deck's open end, port and starboard: the
    # plate's ladders, as stairs.
    ("ladder", 2323, 4600, 2442, 4640, "fore", "b", "a"),
    ("ladder", 2323, 5118, 2442, 5158, "fore", "b", "a"),
    # The second-class flight down to B deck, starboard of the lift, from the landing
    # aft. The plate draws 82 px of treads (2.2 m) for 9 ft of rise; a body climbs no
    # steeper than tools/gen_titanic.py's STEEPEST, so it runs on 43 px into what the
    # plate gives the bar.
    ("second-class staircase", 3048, 4910, 3173, 4990, "aft", "b", "a"),
    # The after first-class staircase down to B deck, rising aft to its landing.
    ("after grand staircase", 4150, 4790, 4290, 4950, "aft", "b", "a"),
    # The forward grand staircase's flight down to B deck: the starboard half of the
    # plate's flight, the boat deck's coming down to port of it (boat.py).
    ("grand staircase", 6882, 4866, 7011, 4980, "fore", "b", "a"),
]
