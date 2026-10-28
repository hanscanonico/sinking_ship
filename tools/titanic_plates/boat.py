"""The boat deck as Plate III draws it: The Shipbuilder, June 1911, leaf n316 (plates.tsv).

Read in the plate's own pixels, as deck.py says. Where the plate and a body disagree —
a ladder steeper than a body climbs, a door narrower than one — the change is made by
the generator, which says so; the pixels here are the plate's.
"""
PLATE = "III"
CROP = (2700, 3000, 8560, 4180)

# Plate III's plans share its elevation's scale — 0.026348 m a pixel, her perpendiculars
# at px 866 and 10699 (tools/gen_titanic.py's X_AP and X_FP) — and sit 19 px aft of it:
# funnels 1-3's casings' middles (px 7829, 6470, 5041) against the elevation's funnel
# bases (7848, 6478, 5072), and the bridge's front (8510 against the elevation's 8529).
# So ship x = (px - 5765) * 0.026348, given here at the deck's two ends.
X = [
    (2748, -79.49, "the deck's after end, on the line through funnels 1-3"),
    (8510, 72.33, "the bridge's front, on the same line"),
]
# The centre line, as drawn at the deck's two ends; across her, her breadth in the
# parallel middle body: the deck's edges 1097.5 px apart at px 6400 (ship x 16.9) for
# her 92 ft moulded.
Z = dict(centre=((2760, 3587.5), (8400, 3575)), scale=0.02555)

# The deck itself, each piece (x0, y0, x1, y1), its y None for her whole breadth: the boat
# deck from its after end to the bridge's wings, and the navigating bridge forward of
# them, narrowing to its front screen round her curve (est. as two steps).
DECKS = [
    (2748, None, 8325, None),
    (8325, 3307, 8420, 3855),
    (8420, 3416, 8510, 3746),
]

ROOMS = [
    # The second-class entrance, aft: its landing round the lift and the two flights
    # down to A deck either side of it.
    ("second-class entrance, boat deck", 2960, 3478, 3226, 3694),
    # The tank rooms either side of the reciprocating engine casing, opening outboard.
    ("tank room, port", 4380, 3323, 4698, 3472),
    ("tank room, starboard", 4380, 3707, 4699, 3847),
    # The officers' mess and its pantry, starboard of funnel 3's casing; the deck chair
    # store to port.
    ("mess pantry", 4891, 3707, 4987, 3785),
    ("officers' mess", 4987, 3707, 5188, 3861),
    ("deck chair store", 5048, 3397, 5188, 3472),
    # The gymnasium, starboard of funnel 2's casing.
    ("gymnasium", 6204, 3714, 6729, 3902),
    # The first-class entrance over the forward grand staircase: its hall, open aft
    # between its two vestibules, which open onto the promenades.
    ("grand staircase, boat deck", 6815, 3258, 7110, 3900),
    ("grand staircase, boat deck", 6740, 3329, 6815, 3833),
    ("vestibule, boat deck", 6740, 3258, 6815, 3329),
    ("vestibule, boat deck", 6740, 3833, 6815, 3900),
    # The officers' house. To port: the Marconi operators' bedroom, the Marconi room round
    # the silent room, the officers' cabins and the chart room, along the port corridor.
    ("Marconi operators' bedroom", 7109, 3322, 7200, 3466),
    ("Marconi room", 7200, 3322, 7270, 3466),
    ("Marconi passage", 7270, 3427, 7388, 3466),
    ("silent room", 7270, 3322, 7355, 3427),
    ("officers' passage", 7388, 3322, 7426, 3697),
    ("sixth officer's cabin", 7426, 3322, 7512, 3427),
    ("extra second officer's cabin", 7512, 3322, 7593, 3427),
    ("officers' passage", 7593, 3322, 7641, 3428),
    ("first officer's cabin", 7641, 3322, 7772, 3428),
    ("chief officer's cabin", 7772, 3322, 7906, 3428),
    ("pilot's cabin", 7906, 3322, 7985, 3428),
    ("chart room", 7985, 3322, 8100, 3469),
    ("officers' corridor", 7426, 3428, 7985, 3469),
    # Amidships: the lifts' machinery over the first-class lifts, the officers' pantry and
    # smoking room, their lavatories and baths off the cross passage.
    ("lift machinery room", 7109, 3466, 7246, 3697),
    ("officers' pantry", 7246, 3466, 7388, 3536),
    ("officers' smoking room", 7246, 3536, 7388, 3697),
    ("officers' lavatory", 7426, 3499, 7543, 3556),
    ("officers' bathroom", 7426, 3556, 7498, 3628),
    ("lavatory", 7498, 3556, 7543, 3628),
    ("officers' store", 7426, 3628, 7478, 3697),
    ("lavatory", 7478, 3628, 7543, 3697),
    # To starboard: the officers' corridor, the stewards', the officers' cabins and the
    # captain's rooms, and the navigating room beside the wheelhouse.
    ("officers' corridor", 7109, 3697, 7843, 3738),
    ("stewards' cabin", 7109, 3738, 7181, 3845),
    ("fifth officer's cabin", 7181, 3738, 7293, 3845),
    ("fourth officer's cabin", 7293, 3738, 7388, 3845),
    ("officers' passage", 7388, 3738, 7426, 3845),
    ("third officer's cabin", 7426, 3738, 7529, 3845),
    ("second officer's cabin", 7529, 3738, 7636, 3845),
    ("officers' passage", 7636, 3738, 7670, 3845),
    ("captain's lavatory", 7670, 3738, 7765, 3845),
    ("captain's bathroom", 7765, 3738, 7843, 3845),
    ("captain's sitting room", 7843, 3697, 8003, 3845),
    ("navigating room", 8003, 3697, 8100, 3845),
    # The wheelhouse, its front the curve's apex.
    ("wheelhouse", 8100, 3425, 8292, 3740),
]

SOLIDS = [
    # The second-class entrance's double after wall, and its lift.
    ("the entrance's after wall", 2922, 3470, 2960, 3702, None),
    ("second-class lift", 3062, 3558, 3146, 3619, None),
    # Over the smoking room's raised roof, a house of fans, the galley's store, the fan
    # room and the turbine engine casing, funnel 4 rising out of it.
    ("fan room, galley store and turbine engine casing", 3515, 3476, 4067, 3712, None),
    # The dome over the after first-class entrance, and the reciprocating engine casing.
    ("dome over the after first-class entrance", 4137, 3474, 4377, 3710, 1.5),
    ("reciprocating engine casing", 4380, 3472, 4699, 3707, None),
    # Funnel 3's casing between its fan and trunk shafts.
    ("fans and trunks", 4834, 3472, 4891, 3736, None),
    ("funnel 3's casing", 4891, 3472, 5284, 3707, None),
    ("fans and trunks", 5284, 3472, 5369, 3707, None),
    # The lounge's dome's roof and the compass platform over the lounge's raised roof.
    ("raised roof over the lounge's dome", 5450, 3509, 5700, 3659, 2.0),
    ("compass platform", 5700, 3494, 5864, 3666, 2.6),
    # Funnel 2's casing between its fans and trunks.
    ("fans and trunks", 6194, 3471, 6277, 3703, None),
    ("funnel 2's casing", 6277, 3471, 6664, 3703, None),
    ("fans and trunks", 6664, 3471, 6731, 3703, None),
    # In the officers' house: a locker, a W.C., the fans and trunks and funnel 1's casing.
    ("locker", 7355, 3322, 7388, 3427, None),
    ("W.C.", 7426, 3466, 7489, 3499, None),
    ("fans and trunks", 7543, 3469, 7636, 3697, None),
    ("funnel 1's casing", 7636, 3469, 8022, 3697, None),
    ("fans and trunks", 8022, 3469, 8100, 3697, None),
    # The bridge's front screen with its windows.
    ("the bridge's front screen", 8490, 3430, 8510, 3745, 1.2),
    # The boats' electric winches, on the open deck: aft of the tank rooms' house, and
    # forward of the first-class entrance's outboard of the officers' house.
    ("electric winch", 4320, 3400, 4349, 3438, 1.0),
    ("electric winch", 4320, 3732, 4349, 3774, 1.0),
    ("electric winch", 7140, 3215, 7175, 3286, 1.0),
    ("electric winch", 7140, 3878, 7175, 3957, 1.0),
]

# Her houses on the boat deck, each roofed over at its walls' tops and a cell of its
# own: (name, x0, y0, x1, y1), on its outer walls' middles.
HOUSES = [
    ("second_class_house", 2922, 3470, 3229, 3702),
    ("tank_room_port", 4380, 3323, 4698, 3472),
    ("tank_room_starboard", 4380, 3707, 4699, 3847),
    ("mess_house", 4891, 3707, 5188, 3861),
    ("deck_chair_store", 5048, 3397, 5188, 3472),
    ("gymnasium_house", 6204, 3714, 6729, 3902),
    ("staircase_house", 6740, 3258, 7110, 3900),
    ("officers_house", 7109, 3322, 8100, 3845),
    ("wheelhouse", 8100, 3425, 8292, 3740),
]

RAISED = [
    # The raised roofs over the first-class smoking room and lounge on A deck below,
    # walked on and reached by ladders; their height over the boat deck est. off the
    # elevation (about 45 px there).
    ("raised roof over the smoking room", 3273, 3261, 4034, 3917, 1.2),
    ("raised roof over the lounge", 5186, 3251, 6194, 3909, 1.2),
    ("raised roof over the lounge", 6194, 3251, 6386, 3471, 1.2),
]

DOORS = [
    # The second-class entrance, from either promenade.
    (2985, 3478), (2985, 3694),
    # The tank rooms, from the engineers' promenade outboard.
    (4486, 3323), (4479, 3847),
    # The mess, its pantry and the deck chair store.
    (4940, 3785), (4987, 3740), (5100, 3861), (5048, 3430),
    # The gymnasium into the starboard vestibule, and from the promenade aft.
    (6729, 3866), (6260, 3902),
    # The vestibules from the promenades and into the hall.
    (6740, 3293), (6740, 3866), (6778, 3329), (6778, 3833),
    # The officers' house's doors out, port and starboard.
    (7407, 3322), (7617, 3322), (7653, 3845), (7407, 3845),
    # Its rooms off its corridors and passages.
    (7200, 3440), (7388, 3447), (7330, 3427),
    (7495, 3427), (7560, 3427), (7755, 3428), (7880, 3428), (7950, 3428),
    (7985, 3450), (8100, 3445),
    (7225, 3697), (7388, 3500), (7360, 3697),
    (7426, 3527), (7426, 3590), (7520, 3556), (7426, 3660), (7510, 3697),
    (7145, 3738), (7236, 3738), (7340, 3738), (7475, 3738), (7580, 3738), (7717, 3738),
    (7765, 3790), (7843, 3718), (8003, 3770), (8100, 3720),
    # The wheelhouse's doors onto the bridge's wings.
    (8150, 3425), (8150, 3740),
]

OPEN = [
    # The first-class entrance's hall and its after strip between the vestibules.
    (6809, 3329, 6821, 3833),
    # The Marconi room's two rectangles.
    (7264, 3427, 7276, 3466),
    # The cross passage into both corridors, and its side passages into theirs.
    (7420, 3428, 7432, 3469),
    (7388, 3691, 7426, 3703),
    (7593, 3422, 7641, 3434),
    (7388, 3732, 7426, 3744),
    (7636, 3732, 7670, 3744),
]

STAIRS = [
    # The second-class flight down to A deck, port of the lift, from the landing forward
    # of it. The plate draws flights either side, 78 px of treads (2.1 m) for 9 ft 6 in of
    # rise; a body climbs no steeper than tools/gen_titanic.py's STEEPEST, so one runs on
    # 52 px aft over the landing and its foot comes down on A deck's (a.py), and the
    # starboard one is floor.
    ("second-class staircase", 3010, 3486, 3140, 3556, "fore", "a", "boat"),
    # The forward grand staircase's flight down to A deck, rising aft to its landing: the
    # port half of the plate's flight, A deck's going on down to starboard of it (a.py).
    ("grand staircase", 6880, 3480, 7030, 3575, "aft", "a", "boat"),
    # Up onto the raised roofs: the plate's ladders, as stairs a body climbs, 1.5 m long.
    ("ladder", 3216, 3368, 3273, 3407, "fore", "boat", "raised roof over the smoking room"),
    ("ladder", 3216, 3754, 3273, 3793, "fore", "boat", "raised roof over the smoking room"),
    ("ladder", 4034, 3368, 4091, 3407, "aft", "boat", "raised roof over the smoking room"),
    ("ladder", 4034, 3754, 4091, 3793, "aft", "boat", "raised roof over the smoking room"),
    ("ladder", 6386, 3397, 6443, 3436, "aft", "boat", "raised roof over the lounge"),
    ("ladder", 5206, 3193, 5245, 3251, "starboard", "boat", "raised roof over the lounge"),
    ("ladder", 5206, 3909, 5245, 3967, "port", "boat", "raised roof over the lounge"),
    # At her forward end, a ladder each side up from A deck (BOT: "at the forward end of
    # the Boat deck there was on each side a ladder leading up from A deck"). The plate
    # draws 67 px of it; as a stair a body climbs it runs on 63 px aft, and stands 15 px
    # outboard of the plate's, clear of A deck's house under it.
    ("ladder", 8110, 3150, 8240, 3190, "fore", "a", "boat"),
    ("ladder", 8110, 3970, 8240, 4010, "fore", "a", "boat"),
]
