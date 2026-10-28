"""The orlop deck, as Plate V draws it ("Orlop Dk."): The Shipbuilder, June 1911, leaf n320
(plates.tsv).

Read in the plate's own pixels, as deck.py says. Where the plate and a body disagree,
the comment beside the piece says what was changed and why. The plate's doors are swings
drawn over unbroken wall lines: a door stands at its swing. A room's side against her
hull is on the hull's double line's middle at the room's middle; a long room against her
narrowing ends steps to it.

The plate draws the Olympic. BOT says of the decks below G only that the orlop and the
lower orlop were partial decks, the lower one "extending only through the forepeak and
No. 1 hold" (lower_orlop.py), and that "on the former deck, abaft the turbine engine
room, were some store rooms containing stores for ship's use" (BOT, "Decks and
Accommodation", Below G deck). The Shipbuilder vol. VI (1912) draws only B deck anew, and
its "increased" staterooms stand on decks with staterooms; the orlop has none. So the
deck is as the plate draws it, every name its label.

The orlop is no deck from M to D: the turbine and reciprocating engine rooms and boiler
rooms 1-6 rise through it, open from the tank top (tanktop.py) to G deck, but for the
CO2 evaporator room and the brine pump room on their flat in the reciprocating engine
room's after port corner, and the cross bunkers either side of each boiler room's
bulkheads, coal from the tank top up (SOLIDS). Its floor (DECKS) is her stern to M, that
flat, and D to her stem.

The plate draws no way into her holds but their hatches, from the decks above, and none
into the switchboard platform, the CO2 evaporator room or the specie room but from spaces
nobody walks. So, est. and each said beside it: a hold ladder down from each hold the
stores' and the post office's stairs don't reach to the hold or deck under it, along her
where today's generator lays its flights between them; a ladder down from the CO2
evaporator room to the engine room's floor; and three doors. The flights down into the
holds from above are the decks above's (G deck's, or the hatches' from the well decks),
and none is traced yet: the lay lays them, as today's generator does from G deck.
"""
PLATE = "V"
CROP = (440, 3020, 10340, 4160)

# Calibrated piecewise on the watertight bulkheads the view draws, each at
# tools/gen_titanic.py's BULKHEADS, and on her ends: the view's after end on her rudder
# post (X_AP, her stern below KNUCKLE), its forward end on her stem at this height (X_FP
# raked, gen_titanic.py's stem_x). Each bulkhead's plate x is its ink's middle at her
# centre line; O and N are drawn double, read at their two lines' middle. Two read as G
# deck's do (g.py):
# - M at Plate III's elevation's step between the orlop and F deck, -64.87: a straight
#   line through the others reads it at -64.70 here, 1.32 m forward of BULKHEADS' -66.02.
# - B is a control here: this view draws it at BULKHEADS' 101.85 (the straight line reads
#   101.97), not at F's and G's 99.5. The firemen's spiral trunk stands aft of it, its
#   after wall at 100.18: the elevation's second line at 100.10 is that trunk's.
# A straight line through O to A (38.08 px a metre) leaves them -0.07 m (O), -0.29 (N),
# +0.17 (M's step), +0.35 (L), +0.19 (K), +0.12 (J), -0.06 (H), -0.19 (G), -0.08 (F), -0.20
# (E), -0.26 (D), -0.21 (C), +0.12 (B) and +0.39 (A) off; P -0.56. Piecewise every control
# reads exactly, each compartment at 37.6-39.0 px a metre but P-O's, 39.2. The cross
# bunkers' after faces then read within 0.17 m of gen_titanic.py's BUNKERS. Her stem sits
# 54 px short of A's scale (forward of A the view is 10% short), her rudder post 15 px.
X = [
    (467, -129.58, "her rudder post, the view's after end (X_AP)"),
    (853.2, -118.97, "bulkhead P"),
    (1530.0, -101.69, "bulkhead O, its double line's middle"),
    (2152.0, -85.14, "bulkhead N, its double line's middle"),
    (2941.5, -64.87, "bulkhead M, as Plate III's elevation steps it between the orlop and F deck"),
    (3566.9, -48.63, "bulkhead L"),
    (4357.5, -27.71, "bulkhead K"),
    (4772.2, -16.75, "bulkhead J"),
    (5467.4, 1.69, "bulkhead H"),
    (6128.6, 19.18, "bulkhead G"),
    (6790.8, 36.46, "bulkhead F"),
    (7454.6, 54.01, "bulkhead E"),
    (8090.4, 70.76, "bulkhead D"),
    (8684.1, 86.30, "bulkhead C"),
    (9288.9, 101.85, "bulkhead B"),
    (9830.6, 115.81, "bulkhead A"),
    (10303, 129.38, "her stem at the orlop (X_FP raked)"),
]
# The centre line, fitted to its dashes as drawn from px 600 to 10200 (1132 columns, 1.4
# px rms, every 1000 px stretch within 4 px of the line); across her, her sides' double
# lines' middles 1065.7 px apart from px 3900 to 6000 for her 92 ft moulded. Her sides'
# middle stands within 1 px of the drawn centre line amidships.
Z = dict(centre=((600, 3609.1), (10200, 3574.4)), scale=0.02631)

# The deck itself: her stern to M; the flat under the CO2 evaporator and brine pump rooms,
# from her port side to their inboard wall; and D to her stem.
DECKS = [
    (467, None, 2941.5, None),
    (3566.9, 3065, 3974, 3256),
    (8090.4, None, 10303, None),
]

ROOMS = [
    # Between P and O, the after hold (the plate's "CARGO"), No. 6 hatch over it (dashed:
    # G deck's), in four steps to her narrowing sides, from the line 56 px forward of P.
    ("cargo hold", 909.5, 3464.5, 1060, 3767),
    ("cargo hold", 1060, 3420.5, 1215, 3808.5),
    ("cargo hold", 1215, 3377.5, 1372, 3850),
    ("cargo hold", 1372, 3334.5, 1530, 3888.5),
    # Between O and N, the refrigerated cargo holds, port and starboard of a wall on her
    # centre line, inside their insulation: the plate draws their lining 55-90 px inside
    # her sides and her bulkheads, the air trunks between (its boxes along her sides), and
    # that space is nobody's. Each in three pieces round No. 5 hatch's trunk on the centre
    # line ("No. 5 HATCH (OVER)": over the tunnels, so the orlop deck closes it below). The
    # trunk's foot opens into both holds through the doors the plate draws in its coaming.
    ("refrigerated cargo hold", 1588, 3376.5, 1664, 3613),
    ("refrigerated cargo hold", 1664, 3352, 1839, 3499.5),
    ("refrigerated cargo hold", 1839, 3310, 2097, 3613),
    ("refrigerated cargo hold", 1588, 3613, 1664, 3858.5),
    ("refrigerated cargo hold", 1664, 3726.5, 1839, 3880),
    ("refrigerated cargo hold", 1839, 3613, 2097, 3917.5),
    ("refrigerated cargo hold, No. 5 hatch", 1664, 3499.5, 1839, 3726.5),
    # Between N and M, the stores (BOT: "abaft the turbine engine room, were some store
    # rooms containing stores for ship's use"), as the plate labels them. To port, the
    # bulk store, an L along N with two trunks in it, No. 4 hatch's port trunk over it
    # (dashed: G deck's); forward of it the grocery, the fruit and vegetable store (an
    # insulated room, drawn double) and the wine and spirit store along her side, a
    # passage between them and the stewards' working stores, the mineral water store
    # and the air space over the dynamos, and the champagne store at the passage's end.
    # The plate draws the centre line through the bulk store, the empties and the mineral
    # water store, no wall.
    ("bulk store", 2152, 3164.5, 2368, 3388),
    ("bulk store", 2152, 3388, 2348, 3442),
    ("bulk store", 2152, 3442, 2299, 3772),
    ("grocery store", 2368, 3134.5, 2581.5, 3388),
    ("fruit and vegetable store", 2581.5, 3116.5, 2693, 3388),
    ("wine and spirit store", 2693, 3103.5, 2941.5, 3212),
    ("champagne store", 2693, 3283, 2840, 3388),
    ("passage, orlop deck", 2348, 3388, 2840, 3442),
    ("stewards' working stores", 2299, 3442, 2446, 3553),
    ("empties store", 2299, 3553, 2446, 3772),
    ("mineral water store", 2446, 3442, 2576, 3772),
    # The lobby by M where G deck's stores' stair comes down (g.py), between the wine and
    # spirit store and the champagne store, west of the stair's foot to the fruit store
    # (the plate's alcove there, open to the wine store, est. the lobby's) and on to the
    # passage. The plate's passage turns up to it at 45 degrees between the champagne
    # store's cut corner and the switchboard platform's: here the lobby steps down to the
    # passage's line, and the champagne store keeps its corner. The plate's box at M by
    # the lobby's foot (54 by 43 px, a door swing at its west side) is the lobby's: no
    # door through M is drawn.
    ("passage, orlop deck", 2693, 3212, 2941.5, 3283),
    ("passage, orlop deck", 2840, 3283, 2941.5, 3442),
    # The switchboard platform, over the electric engine room's dynamos beside their air
    # space, its diagonal head read on the passage's line.
    ("switchboard platform", 2789, 3442, 2941.5, 3898.5),
    # Starboard: the space under No. 4 hatch's starboard trunk (dashed: G deck's) off the
    # bulk store, and through it the refrigerated cargo hold, its insulated walls drawn
    # double, an L under the switchboard platform to M.
    ("passage, orlop deck", 2152, 3772, 2269.5, 4034.5),
    ("refrigerated cargo hold", 2269.5, 3772, 2789, 4066),
    ("refrigerated cargo hold", 2789, 3898.5, 2941.5, 4089.5),
    # Between L and K, in the reciprocating engine room's after port corner on a flat at
    # the orlop: the CO2 evaporator room ("CO2 EVAPORAT. ROOM") and the brine pump room.
    # The plate draws no way into either: a door between them, est.; the evaporator
    # room's ladder down to the engine room, est. (STAIRS).
    ("CO2 evaporator room", 3566.9, 3065, 3873, 3256),
    ("brine pump room", 3873, 3065, 3974, 3256),
    # Between D and C (No. 3 hold): the first- and second-class baggage room to port and
    # the mail room to starboard of a wall on her centre line (BOT: the bunker hatch "gave
    # access to the space allotted to the first and second class baggage hold, the mails,
    # specie and parcel room, and to the lower hold"), round the bunker hatch's trunk and
    # the specie room forward of it; G deck's post office stair comes down into the mail
    # room (g.py). Each in two steps to her sides.
    ("first and second class baggage room", 8090.4, 3155, 8444, 3580.5),
    ("first and second class baggage room", 8444, 3206, 8684.1, 3462),
    ("first and second class baggage room", 8579, 3462, 8684.1, 3580.5),
    ("mail room", 8090.4, 3580.5, 8444, 4001),
    ("mail room", 8444, 3693, 8684.1, 3945.5),
    ("specie room", 8579, 3580.5, 8684.1, 3693),
    # Between C and B (No. 2 hold): the plate's "CARGO OR MOTOR CARS" round No. 2 hatch,
    # in three steps to her sides, and the trunk of the firemen's spiral staircases against
    # B (BOT: "a vertical spiral staircase leading to the forward end of a tunnel,
    # immediately above the tank top"), its ends 17 px out to No. 2 hatch's lines so the
    # hold closes round both. G deck's spiral flights come down into it (g.py); the plate
    # draws no door into it.
    ("cargo or motor car hold", 8684.1, 3249, 8886, 3459),
    ("cargo or motor car hold", 8886, 3288, 9087, 3459),
    ("cargo or motor car hold", 9087, 3328.5, 9288.9, 3459),
    ("cargo or motor car hold", 8886, 3459, 9224, 3693),
    ("cargo or motor car hold", 8684.1, 3693, 8886, 3901.5),
    ("cargo or motor car hold", 8886, 3693, 9087, 3859.5),
    ("cargo or motor car hold", 9087, 3693, 9288.9, 3816.5),
    ("firemen's spiral trunk", 9224, 3459, 9288.9, 3693),
    # Between B and A (No. 1 hold): the plate's "CARGO" round No. 1 hatch, in steps to her
    # sides.
    ("cargo hold", 9288.9, 3370, 9490, 3492),
    ("cargo hold", 9288.9, 3492, 9346, 3658),
    ("cargo hold", 9288.9, 3658, 9490, 3772.5),
    ("cargo hold", 9490, 3412.5, 9685, 3728),
    ("cargo hold", 9685, 3448.5, 9830.6, 3690),
]

SOLIDS = [
    # Aft of P, the after peak tank (the plate's "PEAK TANK", a line across it at 655),
    # and the narrow space between P and the line 56 px forward of it (unlabelled, two
    # slanting lines in it): a trunk.
    ("peak tank", 467, 3589, 655, 3645, None),
    ("peak tank", 655, 3532, 853.2, 3701, None),
    ("trunk", 853.2, 3494.5, 909.5, 3738, None),
    # Between N and M: a trunk on N's face and a square one by the centre line in the bulk
    # store, unlabelled; the air space over the electric engine room's dynamos, open from
    # them below.
    ("trunk", 2152, 3484, 2190, 3515, None),
    ("trunk", 2178, 3603, 2234, 3672, None),
    ("air space over the dynamos", 2576, 3442, 2789, 3772, None),
    # From K to D, the cross bunkers either side of each boiler room's bulkheads, from her
    # side to her side, coal from the tank top up past the orlop's height (the plate's
    # "BUNKER", "COAL"): boiler room 1's forward one, 2's after and forward ones, and so
    # on to 6's forward one against D. Their faces' recesses by her sides (22 px) are read
    # straight; the steam pipe passages through them, dashed, are below this height.
    ("coal bunker", 4630, 3060.2, 4772.2, 4127.5, None),
    ("coal bunker", 4772.2, 3060.8, 4879, 4127.8, None),
    ("coal bunker", 5316, 3060.5, 5467.4, 4124, None),
    ("coal bunker", 5467.4, 3060.2, 5570, 4122.5, None),
    ("coal bunker", 6016, 3058.5, 6128.6, 4117.8, None),
    ("coal bunker", 6128.6, 3058, 6234, 4116.5, None),
    ("coal bunker", 6668, 3058.8, 6790.8, 4111, None),
    ("coal bunker", 6790.8, 3061.5, 6918, 4110.8, None),
    ("coal bunker", 7348, 3071.5, 7454.6, 4093.2, None),
    ("coal bunker", 7454.6, 3076.2, 7542, 4089, None),
    ("coal bunker", 7982, 3121.2, 8090.4, 4040, None),
    # Between D and C: the bunker hatch's trunk down to the lower hold (its coaming's
    # doors into the baggage room, the mail room and the specie room, where the plate
    # draws them, are the trunk's); the boxes marked S along her sides, est. vent trunks,
    # each held inside its room's side; two trunks on D's face in the mail room.
    ("bunker hatch", 8444, 3462, 8579, 3693, None),
    ("trunk", 8229, 3155, 8260, 3204, None),
    ("trunk", 8405, 3168, 8438, 3227, None),
    ("trunk", 8546, 3206, 8580, 3246, None),
    ("trunk", 8228, 3959, 8264, 4001, None),
    ("trunk", 8406, 3920, 8440, 3985, None),
    ("trunk", 8546, 3896, 8576, 3945.5, None),
    ("trunk", 8090.4, 3748, 8131, 3798, None),
    ("trunk", 8090.4, 3798, 8151, 3844, None),
    # No. 2 hatch against C, and No. 1 hatch, open down to the holds under them.
    ("No. 2 hatch", 8684.1, 3459, 8886, 3693, None),
    ("No. 1 hatch", 9346, 3492, 9490, 3658, None),
    # Forward of A, the collision bulkhead: the chain locker, and the store in her eyes,
    # in two steps to her stem. The plate draws no way into the store on the orlop.
    ("chain locker", 9830.6, 3478.5, 9975, 3657, None),
    ("store", 9975, 3513.5, 10150, 3622, None),
    ("store", 10150, 3549, 10303, 3584.5, None),
]

DOORS = [
    # No. 5 hatch's trunk into the refrigerated holds, port and starboard.
    (1718, 3499.5), (1750, 3726.5),
    # The bulk store from the passage and into the space under No. 4 hatch, and on through
    # the refrigerated cargo hold's after wall.
    (2348, 3415), (2200, 3772), (2269.5, 3868),
    # The stores off the passage, and the empties from the bulk store.
    (2535, 3388), (2635, 3388), (2380, 3442), (2552, 3442), (2299, 3750),
    # The wine and spirit store from the lobby; the champagne store, whose swing stands
    # on its cut corner, on its side into the lobby.
    (2892, 3212), (2840, 3330),
    # The switchboard platform from the lobby, est.: the plate draws it shut off from the
    # stores, reached from the dynamos below.
    (2908, 3442),
    # The brine pump room from the CO2 evaporator room, est.
    (3873, 3200),
    # The baggage room from the mail room; the specie room into the mail room, est. (the
    # plate draws its door into the bunker hatch's trunk).
    (8273, 3580.5), (8631, 3693),
]

OPEN = [
    # The after hold's four steps.
    (1057, 3470, 1063, 3760), (1212, 3425, 1218, 3800), (1369, 3380, 1375, 3845),
    # The refrigerated holds' pieces either side of No. 5 hatch.
    (1661, 3380, 1667, 3495), (1836, 3355, 1842, 3495), (1661, 3730, 1667, 3855), (1836, 3730, 1842, 3875),
    # The bulk store's three; the refrigerated cargo hold's two; the lobby's two and the
    # passage into it.
    (2155, 3385, 2345, 3391), (2155, 3439, 2296, 3445), (2786, 3901, 2792, 4085),
    (2843, 3280, 2938, 3286), (2837, 3391, 2843, 3439),
    # The baggage room's three, the mail room's two.
    (8441, 3210, 8447, 3459), (8582, 3459, 8681, 3465), (8441, 3696, 8447, 3940),
    # No. 2 hold's seven.
    (8883, 3290, 8889, 3456), (9084, 3330, 9090, 3456), (8889, 3456, 9084, 3462), (9090, 3456, 9221, 3462),
    (8889, 3690, 9084, 3696), (9090, 3690, 9221, 3696), (8883, 3696, 8889, 3857), (9084, 3696, 9090, 3814),
    # No. 1 hold's five.
    (9291, 3489, 9343, 3495), (9291, 3655, 9343, 3661), (9487, 3415, 9493, 3489), (9487, 3661, 9493, 3725),
    (9682, 3451, 9688, 3687),
]

STAIRS = [
    # The flights from the orlop down; those coming down onto it are G deck's (g.py).
    # The firemen's spiral staircases down to their tunnel at the tank top (BOT), past the
    # lower orlop's height in their trunk (lower_orlop.py): a spiral has no run a body
    # climbs, so each is a straight flight as wide as the plate's spiral (40 px), at its
    # place across her, from the trunk's after wall aft to the run STEEPEST allows for her
    # orlop's 4.75 m over her tank top (224 px, 5.76 m): it runs 5.6 m aft of the trunk,
    # through No. 2 hold, where the plate draws only the trunk. G deck's flights land in
    # the trunk at its after end. The lay picks one shaft for D deck's, E's, F's, G's and
    # these, which the plates draw a little apart (g.py's notes).
    ("firemen's spiral staircase", 9000, 3488, 9224, 3528, "fore", "tanktop", "orlop"),
    ("firemen's spiral staircase", 9000, 3613, 9224, 3653, "fore", "tanktop", "orlop"),
    # The hold ladders, est. (see above), each at the run STEEPEST allows. The after hold's
    # and the port refrigerated hold's down to the tank top, along her where today's
    # generator lays the after holds' flights, but out to port, over the space the tank
    # top's view leaves between her side and the port shaft tunnel (5.62 m and 5.63 m for
    # 4.75 m); No. 2 hold's along her port side (5.76 m); No. 1 hold's down to the lower
    # orlop (2.65 m for the 2.2 m Plate III's elevation draws between them there, est.).
    ("hold ladder", 1244, 3416.5, 1464, 3454.5, "fore", "tanktop", "orlop"),
    ("hold ladder", 1631, 3377, 1842.5, 3415, "fore", "tanktop", "orlop"),
    ("hold ladder", 8900, 3400, 9124, 3440, "fore", "tanktop", "orlop"),
    ("hold ladder", 9520, 3440, 9623, 3480, "aft", "lower_orlop", "orlop"),
    # The CO2 evaporator room's ladder down to the reciprocating engine room's floor, est.:
    # 5.42 m for its 4.5 m, along the room's inboard side.
    ("ladder", 3600, 3205, 3805, 3245, "aft", "tanktop", "orlop"),
]
