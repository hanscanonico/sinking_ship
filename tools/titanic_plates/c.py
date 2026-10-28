"""C deck, the shelter deck, as Plate IV draws it ("Shelter Dk C"): The Shipbuilder, June
1911, leaf n318 (plates.tsv).

Read in the plate's own pixels, as deck.py says. Where the plate and a body disagree,
the comment beside the piece says what was changed and why.

The plate draws the Olympic. "On the remaining decks the number of staterooms has been
increased" (The Shipbuilder, vol. VI (1911-12), "The White Star Liner Titanic", p. 224),
but no public-domain 1912 source draws the Titanic's C deck, so this is the plate's.
"""
PLATE = "IV"
CROP = (360, 1700, 10660, 2900)

# Calibrated on the shafts that stack, at the ship x A deck's calibration gives them
# (a.py): her second-class lift aft, her funnels' casings and the first-class lifts
# forward; and her stern, which no deck above draws, at the generator's X_AFT. Forward of
# funnel 1 her stem reads 129.81, her stem at C deck 129.78. Aft of the lift the view is
# read on her stern alone, as B deck's after end is on Plate III's elevation (b_aft.py):
# the plate draws about 3% larger there than forward of the lift, as B deck's view does,
# so the after second-class entrance's after wall reads -94.48 (B deck's -94.40, the
# elevation's) and the poop's front -106.63 (the elevation's -106.55). The mainmast's ring
# on her centre line (px 2405) then reads -87.0, 1.6 m forward of A deck's: no control,
# as on B deck (b_aft.py). Pegged on it, as this view first was, the poop's front stood
# 0.8 m aft of the elevation's and the after entrance's after wall 1.4 m.
X = [
    (380, -138.26, "her stern, its shell's outer line on the centre line: X_AFT"),
    (3073.25, -70.11, "the second-class lift's middle; A deck's at px 3088, B deck's 3082"),
    (5091.5, -17.48, "funnel 3's casing and shafts' middle; A deck's at 5084.5"),
    (6436.75, 18.38, "funnel 2's; A deck's at 6437"),
    (7127.75, 36.58, "the first-class lifts' middle; A deck's at 7125"),
    (7787.75, 54.18, "funnel 1's; A deck's at 7790"),
]
# The centre line as drawn, fitted to it from her stern to her stem (it bows 3 px over
# the scan); across her, her shell's outer lines 1085 px apart at px 6000 (ship x 6.7) for
# her 92 ft moulded.
Z = dict(centre=((500, 2334.4), (10500, 2274.6)), scale=0.025845)

# The deck itself: her whole length and breadth, the highest deck from stem to stern.
DECKS = [
    (380, None, 10624, None),
]

ROOMS = [
    # Under the poop, her steering gear room (BOT: "the steam steering gear and the
    # machinery for working the after capstan gear"), its sides her shell, est. as steps
    # inside her curve; the stores in its forward corners open into it.
    ("steering gear room", 790, 2031, 1025, 2627.5),
    ("steering gear room", 790, 1957, 936, 2031),
    ("steering gear room", 790, 2627.5, 936, 2695),
    # Its after step 5 px aft of the plate's, so the capstan gear stands clear of it.
    ("steering gear room", 585, 2017, 790, 2639),
    ("steering gear room", 460, 2098, 585, 2560),
    ("store", 936, 1928, 1025, 2031),
    # The plate's "St", its after wall on the port store's line (10 px aft of the
    # plate's) so the steering gear room's forward end is one wall.
    ("store", 936, 2627.5, 1025, 2722),
    # The third-class smoking room (the plate's "3rd cl. smoke room") and general room,
    # either side of a wall on her centre line, round the third-class entrance's after
    # end; their sides her shell, in steps.
    ("third-class smoking room", 1025, 1913, 1160, 2334),
    ("third-class smoking room", 1160, 1894, 1300, 2334),
    ("third-class smoking room", 1300, 1877, 1354, 2334),
    ("third-class smoking room", 1354, 1877, 1438, 2160),
    ("third-class general room", 1025, 2334, 1160, 2737),
    ("third-class general room", 1160, 2334, 1300, 2754),
    ("third-class general room", 1300, 2334, 1354, 2772),
    ("third-class general room", 1354, 2491, 1452, 2772),
    ("bar", 1438, 1860, 1530, 1972),
    # The main third-class entrance (BOT: "leading directly down to G deck").
    ("third-class entrance, C deck", 1354, 2160, 1630, 2491),
    # The after second-class entrance under B deck's after end, round its stairway: the
    # hall, its after part between the plate's diagonal corners (est. as a step, as wide
    # as the stores aft of it, so her after well's house round it is one), its bay into
    # the library, and the well its flight down to D deck runs on into; the stores in its
    # after corners (the plate's "Ok" and "St").
    ("second-class entrance, C deck, aft", 2264, 2036.75, 2424, 2606.25),
    ("second-class entrance, C deck, aft", 2198, 2160, 2264, 2485),
    ("second-class entrance, C deck, aft", 2424, 2207, 2461, 2441),
    ("second-class entrance, C deck, aft", 2110, 2324, 2198, 2436),
    ("store", 2110, 2160, 2198, 2212),
    ("store", 2110, 2436, 2198, 2485),
    # The second-class library, in the middle of the promenade (BOT), No. 4 hatch's
    # trunks in its after corners and its after wall stepping round the entrance's bay.
    ("second-class library", 2566, 1971, 2925, 2669.75),
    ("second-class library", 2461, 2036.75, 2566, 2606.25),
    ("second-class library", 2424, 2036.75, 2461, 2207),
    ("second-class library", 2430, 2441, 2461, 2606.25),
    # The forward second-class entrance, round its staircase and lift: the hall, its
    # forward corners, the lane port of the lift B deck's flight comes down in
    # (b_aft.py), the lane starboard of it its flight down to D deck runs in, and the
    # well forward of the lift.
    ("second-class entrance, C deck", 2925, 1971, 3029, 2669.75),
    ("second-class entrance, C deck", 3029, 1971, 3130, 2202.5),
    ("second-class entrance, C deck", 3029, 2432.5, 3136.75, 2669.75),
    ("second-class entrance, C deck", 3029, 2202.5, 3117, 2280.25),
    ("second-class entrance, C deck", 3029, 2357.25, 3206.75, 2432.5),
    ("second-class entrance, C deck", 3117, 2202.5, 3206.75, 2357.25),
    # The house (BOT: "a house 450 ft. long and extending for the full breadth of the
    # ship. It contained 148 staterooms for first class, besides service rooms of various
    # kinds"): a corridor down each side between a row of rooms at her side and a row
    # inboard of it, the casings between the inboard rows. Each stateroom is named for
    # the berths the plate numbers in it. Her side's rooms end on the middle of her
    # shell's double line, laid as straight runs that step in where she narrows forward,
    # each run more than SNAP from the next: within 0.18 m of the plate's.
    #
    # Its after end. Port, at her side: three staterooms, then two bathrooms round their
    # W.C.s, a diagonal between them (est. as a cut across at its middle), each opening
    # into the stateroom beside it.
    ("C deck corridor", 3280, 1985.5, 4052, 2041),
    ("two-berth first-class stateroom", 3280, 1783, 3403, 1985.5),
    ("two-berth first-class stateroom", 3403, 1782.5, 3530, 1985.5),
    ("two-berth first-class stateroom", 3530, 1781.5, 3659, 1985.5),
    ("bathroom", 3683, 1780.5, 3762, 1880),
    ("bathroom", 3659, 1880, 3731, 1985.5),
    ("two-berth first-class stateroom", 3762, 1780, 3890, 1985.5),
    ("two-berth first-class stateroom", 3890, 1779.5, 4021, 1985.5),
    # Inboard of the corridor: two staterooms, a cross passage from corridor to corridor
    # past the lavatories, the servery, the passage into the gentlemen's lavatory and
    # its W.C.s, two bathrooms, three staterooms and one more.
    ("two-berth first-class stateroom", 3280, 2041, 3378, 2178),
    ("one-berth first-class stateroom", 3280, 2178, 3378, 2298),
    ("passage", 3378, 2041, 3416, 2584),
    ("servery", 3416, 2041, 3482, 2155),
    ("passage", 3482, 2041, 3519, 2195),
    # Its W.C.s' after side 15 px forward of the plate's, so it is a rectangle.
    ("gentlemen's lavatory", 3416, 2155, 3482, 2318),
    ("bathroom", 3519, 2041, 3589, 2128),
    ("bathroom", 3519, 2128, 3589, 2195),
    ("three-berth first-class stateroom", 3589, 2041, 3718, 2193),
    ("three-berth first-class stateroom", 3718, 2041, 3841, 2193),
    ("three-berth first-class stateroom", 3841, 2041, 3968, 2193),
    ("one-berth first-class stateroom", 3968, 2041, 4052, 2193),
    # Starboard of the cross passage: the restaurant manager's, the assistant doctor's
    # and the doctor's rooms (the plate's "Rest. man.", "Ass. Dr's", "Dr's"; the first
    # called his quarters, as "restaurant" would dress it as the restaurant); the
    # ladies' lavatory, its W.C.s and its servery; two bathrooms, the stewardesses' room
    # and three staterooms.
    ("restaurant manager's quarters", 3280, 2298, 3378, 2401),
    ("assistant doctor's room", 3280, 2401, 3378, 2488),
    ("doctor's room", 3280, 2488, 3378, 2584),
    # The lavatory's side on the passage 6 px longer than the plate's, for a body's door.
    ("ladies' lavatory", 3416, 2318, 3490, 2472),
    ("servery", 3416, 2472, 3490, 2584),
    ("passage", 3490, 2428, 3525, 2584),
    ("bathroom", 3525, 2428, 3595, 2497),
    ("bathroom", 3525, 2497, 3595, 2584),
    ("stewardesses' room", 3595, 2428, 3683, 2584),
    ("three-berth first-class stateroom", 3683, 2428, 3803, 2584),
    ("three-berth first-class stateroom", 3803, 2428, 3924, 2584),
    ("three-berth first-class stateroom", 3924, 2428, 4052, 2584),
    ("C deck corridor", 3280, 2584, 4052, 2639),
    # Starboard, at her side: the passage into the surgery, the surgery, two staterooms
    # and two bathrooms round their W.C.s, as to port.
    ("passage", 3280, 2641.5, 3340, 2692),
    ("surgery", 3280, 2692, 3414, 2846.5),
    ("two-berth first-class stateroom", 3414, 2640.5, 3540, 2846),
    ("two-berth first-class stateroom", 3540, 2640, 3669, 2845),
    ("bathroom", 3669, 2639, 3737, 2737),
    ("bathroom", 3700, 2737, 3774, 2844.5),
    ("two-berth first-class stateroom", 3774, 2637, 3904, 2843.5),
    ("two-berth first-class stateroom", 3904, 2636, 4031, 2843),
    # The after first-class entrance (BOT: "giving access as far down as C deck"): its
    # hall across the house between the corridors, the plate's flights up to B deck in its
    # middle, and its bay forward to the light and air trunk.
    ("after grand staircase, C deck", 4052, 1985.5, 4292, 2634),
    ("after grand staircase, C deck", 4292, 2188.5, 4357, 2424.5),
    # Behind the hall, a passage round the second light and air trunk, a door into it
    # from the hall at each end: B deck's flight down from the hall above, run on aft to
    # the slope a body climbs (b_mid.py), comes down into it through the starboard one.
    ("passage", 3965, 2193, 4052, 2428),
    # Forward of it to the boiler casing. Port, at her side: staterooms and bathrooms.
    ("two-berth first-class stateroom", 4021, 1778.5, 4151, 1985.5),
    ("bathroom", 4151, 1778, 4223, 1877),
    ("bathroom", 4185, 1877, 4256, 1985.5),
    ("two-berth first-class stateroom", 4256, 1777, 4376, 1985.5),
    ("two-berth first-class stateroom", 4376, 1776.5, 4499, 1985.5),
    ("bathroom", 4530, 1775.5, 4604, 1877),
    ("bathroom", 4499, 1877, 4570, 1985.5),
    ("two-berth first-class stateroom", 4604, 1775, 4736, 1985.5),
    ("two-berth first-class stateroom", 4736, 1774.5, 4863, 1985.5),
    ("C deck corridor", 4292, 1983, 6700, 2037),
    # Inboard: the barber's shop off the hall, staterooms, and the passage down to the
    # maids' and valets' pantry; the pantry round the stewards' staircase (BOT: "a
    # stewards' stairway, which communicated with all the decks below as far as E
    # deck"), between the reciprocating engine casing and its fans; to starboard the
    # maids' and valets' saloon, off the hall.
    ("barber's shop", 4292, 2039, 4465, 2188.5),
    ("three-berth first-class stateroom", 4465, 2039, 4589, 2188.5),
    ("three-berth first-class stateroom", 4589, 2039, 4710, 2188.5),
    ("passage", 4710, 2039, 4752, 2188.5),
    ("three-berth first-class stateroom", 4752, 2039, 4871, 2188.5),
    ("maids' and valets' pantry", 4684, 2188.5, 4825, 2424.5),
    ("maids' and valets' saloon", 4292, 2424.5, 4882, 2576),
    ("C deck corridor", 4292, 2572, 6700, 2625),
    # Starboard, at her side.
    ("two-berth first-class stateroom", 4031, 2634.5, 4157, 2842),
    ("bathroom", 4189, 2633.5, 4266, 2737),
    ("bathroom", 4157, 2737, 4238, 2841.5),
    ("two-berth first-class stateroom", 4266, 2632.5, 4388, 2841),
    ("two-berth first-class stateroom", 4388, 2631.5, 4509, 2840),
    ("bathroom", 4509, 2630.5, 4581, 2737),
    ("bathroom", 4540, 2737, 4616, 2839.5),
    ("two-berth first-class stateroom", 4616, 2629.5, 4741, 2838.5),
    ("two-berth first-class stateroom", 4741, 2628.5, 4875, 2838),
    # From the boiler casing aft of funnel 3 to the lounge aft of funnel 2. Port, at her
    # side, a pattern that repeats: two staterooms either side of a private lobby, its
    # bathroom and W.C. at her side, two wardrobe rooms on the corridor (the plate's
    # "W.R.", one label across the two). The lobby is an L round the W.C.'s door, its
    # notch narrower than a body: the W.C. takes it.
    ("two-berth first-class stateroom", 4863, 1773.5, 4990, 1982.5),
    ("bathroom", 4990, 1773, 5054, 1876),
    ("passage", 4990, 1876, 5097, 1910),
    ("wardrobe room", 4990, 1910, 5041, 1982.5),
    ("wardrobe room", 5041, 1910, 5097, 1982.5),
    ("two-berth first-class stateroom", 5097, 1772, 5221, 1982.5),
    ("two-berth first-class stateroom", 5221, 1771.5, 5350, 1982),
    ("two-berth first-class stateroom", 5350, 1770.5, 5476, 1982),
    ("passage", 5476, 1873, 5588, 1909),
    ("bathroom", 5511, 1770, 5588, 1873),
    ("wardrobe room", 5476, 1909, 5531, 1981.5),
    ("wardrobe room", 5531, 1909, 5588, 1981.5),
    ("two-berth first-class stateroom", 5588, 1769, 5712, 1981.5),
    ("two-berth first-class stateroom", 5712, 1768.5, 5840, 1981.5),
    ("two-berth first-class stateroom", 5840, 1767.5, 5968, 1981.5),
    ("bathroom", 5968, 1767, 6038, 1871),
    ("passage", 5968, 1871, 6077, 1905),
    ("wardrobe room", 5968, 1905, 6024, 1981),
    ("wardrobe room", 6024, 1905, 6077, 1981),
    ("two-berth first-class stateroom", 6077, 1766.5, 6203, 1981),
    # Inboard of the corridor, aft of the cross passage: staterooms to port; funnel 3's
    # boiler casing between its fans and trunks; the gentlemen's lavatory round its
    # W.C.s, and the two pantries (the plate's "Serv. pant's") off the cross passage; to
    # starboard the Marconi operators' saloon (the plate's "Marc. oper. saloon") and
    # staterooms.
    ("three-berth first-class stateroom", 4871, 2038, 4990, 2188),
    ("three-berth first-class stateroom", 4990, 2037, 5108, 2188),
    ("three-berth first-class stateroom", 5108, 2037, 5233, 2188),
    ("three-berth first-class stateroom", 5233, 2037, 5356, 2188),
    ("three-berth first-class stateroom", 5356, 2037, 5482, 2188),
    ("gentlemen's lavatory", 5430, 2188, 5482, 2325),
    ("gentlemen's lavatory", 5357, 2325, 5482, 2421),
    ("pantry", 5357, 2421, 5420, 2573),
    ("pantry", 5420, 2421, 5482, 2573),
    ("Marconi operators' saloon", 4882, 2424.5, 5005, 2574),
    ("three-berth first-class stateroom", 5005, 2423, 5122, 2574),
    ("three-berth first-class stateroom", 5122, 2422, 5241, 2573),
    ("three-berth first-class stateroom", 5241, 2421, 5357, 2573),
    # The cross passage from corridor to corridor.
    ("passage", 5482, 2037, 5516, 2573),
    # Forward of it, three blocks across the house between the corridors, a cross
    # passage between each two. The first: staterooms, a stack of bathrooms on the cross
    # passage aft, and the linen room.
    ("two-berth first-class stateroom", 5516, 2036, 5619, 2187),
    ("two-berth first-class stateroom", 5619, 2036, 5722, 2187),
    ("bathroom", 5516, 2187, 5591, 2268),
    ("bathroom", 5516, 2268, 5591, 2346),
    ("bathroom", 5516, 2346, 5591, 2420),
    ("bathroom", 5516, 2420, 5591, 2503),
    ("linen room", 5516, 2503, 5591, 2572),
    ("two-berth first-class stateroom", 5591, 2187, 5722, 2302.5),
    ("two-berth first-class stateroom", 5591, 2302.5, 5722, 2419),
    ("three-berth first-class stateroom", 5591, 2419, 5722, 2572),
    ("passage", 5722, 2036, 5768, 2572),
    # The second: staterooms, and its bathrooms on the cross passage forward.
    ("two-berth first-class stateroom", 5768, 2035, 5867, 2186),
    ("two-berth first-class stateroom", 5867, 2035, 5970, 2186),
    ("two-berth first-class stateroom", 5768, 2186, 5887, 2302.5),
    ("two-berth first-class stateroom", 5768, 2302.5, 5887, 2418.5),
    ("bathroom", 5887, 2186, 5970, 2263.5),
    ("bathroom", 5887, 2263.5, 5970, 2345),
    ("bathroom", 5887, 2345, 5970, 2418.5),
    ("two-berth first-class stateroom", 5768, 2418.5, 5870, 2571),
    ("two-berth first-class stateroom", 5870, 2418.5, 5970, 2571),
    ("passage", 5970, 2035, 6011, 2571),
    # The third, its alcove off the cross passage: the mess stewards' room (the plate's
    # "Mess stew."), a stateroom, a lavatory (the plate's "L", est.) and a bathroom; the
    # ladies' lavatory round its W.C.s; and two staterooms.
    ("passage", 6011, 2155, 6100, 2186),
    ("mess stewards' room", 6011, 2035, 6100, 2155),
    ("three-berth first-class stateroom", 6100, 2034.5, 6215, 2186),
    ("lavatory", 6011, 2186, 6063, 2253),
    ("bathroom", 6063, 2186, 6171, 2253),
    ("ladies' lavatory", 6011, 2253, 6091, 2418),
    ("two-berth first-class stateroom", 6011, 2418, 6106, 2569.5),
    ("two-berth first-class stateroom", 6106, 2418, 6205, 2569.5),
    # Starboard, at her side, the pattern of the port side, mirrored.
    ("two-berth first-class stateroom", 4875, 2628.5, 4999, 2837),
    ("wardrobe room", 4999, 2628, 5052, 2709),
    ("wardrobe room", 5052, 2628, 5106, 2709),
    ("passage", 4999, 2709, 5106, 2749),
    ("bathroom", 4999, 2749, 5064, 2836.5),
    ("two-berth first-class stateroom", 5106, 2627.5, 5228, 2835.5),
    ("two-berth first-class stateroom", 5228, 2627, 5362, 2835),
    ("two-berth first-class stateroom", 5362, 2626.5, 5487, 2834),
    ("wardrobe room", 5487, 2626, 5537, 2703),
    ("wardrobe room", 5537, 2626, 5594, 2703),
    ("passage", 5487, 2703, 5594, 2745),
    ("bathroom", 5523, 2745, 5594, 2833.5),
    ("two-berth first-class stateroom", 5594, 2625.5, 5721, 2833),
    ("two-berth first-class stateroom", 5721, 2625, 5846, 2832),
    ("two-berth first-class stateroom", 5846, 2624.5, 5978, 2831.5),
    ("wardrobe room", 5978, 2624, 6026, 2702),
    ("wardrobe room", 6026, 2624, 6083, 2702),
    ("passage", 5978, 2702, 6083, 2745),
    ("bathroom", 5978, 2745, 6044, 2830.5),
    ("two-berth first-class stateroom", 6083, 2623.5, 6206, 2830),
    # Round funnel 2's boiler casing to the forward entrance. Port, at her side: a
    # stateroom, a private lobby's bathroom, W.C. and wardrobe rooms, a stateroom and its
    # sitting room.
    ("two-berth first-class stateroom", 6203, 1765.5, 6318, 1981),
    ("bathroom", 6318, 1765, 6387, 1866),
    ("passage", 6318, 1866, 6425, 1903),
    ("wardrobe room", 6318, 1903, 6371, 1980.5),
    ("wardrobe room", 6371, 1903, 6425, 1980.5),
    ("two-berth first-class stateroom", 6425, 1764, 6562, 1980.5),
    ("sitting room", 6562, 1763.5, 6700, 1980.5),
    # Inboard: staterooms either side of the casing.
    ("three-berth first-class stateroom", 6215, 2034, 6335, 2185.5),
    ("three-berth first-class stateroom", 6335, 2034, 6458, 2185),
    ("three-berth first-class stateroom", 6458, 2034, 6578, 2185),
    ("three-berth first-class stateroom", 6578, 2034, 6700, 2185),
    ("three-berth first-class stateroom", 6205, 2418, 6329, 2568.5),
    ("three-berth first-class stateroom", 6329, 2418, 6460, 2568),
    ("two-berth first-class stateroom", 6460, 2417.5, 6579, 2567.5),
    ("three-berth first-class stateroom", 6579, 2417, 6700, 2567),
    # Starboard, at her side, as to port.
    ("two-berth first-class stateroom", 6206, 2622.5, 6328, 2829),
    ("wardrobe room", 6328, 2622, 6377, 2699),
    ("wardrobe room", 6377, 2622, 6431, 2699),
    ("passage", 6328, 2699, 6431, 2741),
    ("bathroom", 6328, 2741, 6393, 2828.5),
    ("two-berth first-class stateroom", 6431, 2621, 6565, 2828),
    ("sitting room", 6565, 2619.5, 6700, 2827),
    # The forward first-class entrance, across her: its hall round the grand staircase
    # and the lifts, aft of them and forward of them; the cloak room to port and the
    # enquiry office to starboard on it (their fronts the plate's dashed counters, laid
    # as walls with a door at their middles, est.), the purser's office beside the
    # enquiry office (BOT: "the purser's office and the enquiry office, where
    # passengers' telegrams were received"). Its corners hold staterooms, each
    # with its bath and W.C., and a passage either side out to her side (BOT: "Exit doors
    # through the ship's side were fitted abreast of this entrance"), a locker at its end
    # (the plate's "L"). The inner stateroom of each corner pair reaches her side past
    # the outer one's slanted end: an L, cut in two.
    ("grand staircase, C deck", 6700, 1928, 7045, 2670.5),
    ("grand staircase, C deck", 7045, 2025, 7300, 2564),
    ("cloak room", 6700, 1762.5, 6903, 1928),
    ("three-berth first-class stateroom", 6903, 1761.5, 7006, 1928),
    ("passage", 7006, 1798, 7045, 1928),
    ("three-berth first-class stateroom", 7045, 1760.5, 7153, 1928),
    ("bathroom", 7045, 1928, 7153, 2025),
    ("three-berth first-class stateroom", 7153, 1760, 7200, 1928),
    ("three-berth first-class stateroom", 7153, 1928, 7300, 2025),
    ("three-berth first-class stateroom", 7200, 1759.5, 7300, 1928),
    ("enquiry office", 6700, 2670.5, 6903, 2826),
    ("purser's office", 6903, 2669, 7013, 2825),
    ("passage", 7013, 2669, 7050, 2792),
    ("three-berth first-class stateroom", 7050, 2666, 7156, 2824),
    ("bathroom", 7050, 2564, 7156, 2666),
    ("three-berth first-class stateroom", 7156, 2564, 7300, 2666),
    ("three-berth first-class stateroom", 7156, 2666, 7206, 2823.5),
    ("three-berth first-class stateroom", 7206, 2666, 7300, 2823.5),
    # Forward of it, behind its forward wall, the cross passage from her side to her
    # side the forward corridors open into, a locker at each end.
    ("passage", 7300, 1790, 7331, 2800),
    # Forward of the entrance to the house's front. At either side, four times over: a
    # stateroom over its bath and W.C. (the plate's "B. & W.C."), and a pair, its outer
    # room's after end slanting and its inner room reaching her side past it, an L cut
    # in two; between each four and the next a short passage out from the corridor, a
    # locker at its end (the plate's "L"). Port:
    ("three-berth first-class stateroom", 7331, 1759, 7433, 1924),
    ("bathroom", 7331, 1924, 7433, 2019),
    ("three-berth first-class stateroom", 7433, 1758.5, 7475, 1923),
    ("three-berth first-class stateroom", 7433, 1923, 7564, 2019),
    ("three-berth first-class stateroom", 7475, 1758, 7564, 1923),
    ("passage", 7564, 1793, 7602, 2019),
    ("three-berth first-class stateroom", 7602, 1757, 7708, 1922),
    ("bathroom", 7602, 1922, 7708, 2018),
    ("three-berth first-class stateroom", 7708, 1765, 7750, 1920),
    ("three-berth first-class stateroom", 7708, 1920, 7848, 2018),
    ("three-berth first-class stateroom", 7750, 1764.5, 7848, 1920),
    ("passage", 7848, 1796, 7884, 2018),
    ("three-berth first-class stateroom", 7884, 1763.5, 7991, 1920),
    ("bathroom", 7884, 1920, 7991, 2017),
    ("three-berth first-class stateroom", 7991, 1772.5, 8033, 1919),
    ("three-berth first-class stateroom", 7991, 1919, 8126, 2016),
    ("three-berth first-class stateroom", 8033, 1772, 8126, 1919),
    ("passage", 8126, 1815, 8168, 2016),
    ("three-berth first-class stateroom", 8168, 1771, 8272, 1919),
    ("bathroom", 8168, 1919, 8272, 2015),
    ("three-berth first-class stateroom", 8272, 1781.5, 8312, 1917),
    ("three-berth first-class stateroom", 8272, 1917, 8402, 2014),
    ("three-berth first-class stateroom", 8312, 1781.5, 8402, 1917),
    ("C deck corridor", 7331, 2016, 8402, 2072),
    # Starboard, the same mirrored.
    ("bathroom", 7331, 2558, 7436, 2662),
    ("three-berth first-class stateroom", 7331, 2662, 7436, 2822.5),
    ("three-berth first-class stateroom", 7436, 2558, 7568, 2664),
    ("three-berth first-class stateroom", 7436, 2664, 7477, 2822),
    ("three-berth first-class stateroom", 7477, 2664, 7568, 2821.5),
    ("passage", 7568, 2558, 7604, 2795),
    ("bathroom", 7604, 2558, 7712, 2660),
    ("three-berth first-class stateroom", 7604, 2660, 7712, 2821),
    ("three-berth first-class stateroom", 7712, 2558, 7849, 2660),
    ("three-berth first-class stateroom", 7712, 2660, 7753, 2820.5),
    ("three-berth first-class stateroom", 7753, 2660, 7849, 2820),
    ("passage", 7849, 2558, 7885, 2790),
    ("bathroom", 7885, 2558, 7990, 2658),
    ("three-berth first-class stateroom", 7885, 2658, 7990, 2819),
    ("three-berth first-class stateroom", 7990, 2558, 8129, 2659),
    ("three-berth first-class stateroom", 7990, 2659, 8031, 2810.5),
    ("three-berth first-class stateroom", 8031, 2659, 8129, 2810),
    ("passage", 8129, 2558, 8167, 2769),
    ("bathroom", 8167, 2558, 8271, 2657),
    ("three-berth first-class stateroom", 8167, 2657, 8271, 2801.5),
    ("three-berth first-class stateroom", 8271, 2558, 8402, 2657),
    ("three-berth first-class stateroom", 8271, 2657, 8310, 2801),
    ("three-berth first-class stateroom", 8310, 2657, 8402, 2800.5),
    ("C deck corridor", 7331, 2505, 8402, 2558),
    # Between the corridors: on the cross passage aft, two bathrooms, a store (the
    # plate's "S S", est.) and a pantry; a passage either side into the ladies'
    # lavatory round its W.C.s, the purser's room off the port one; the one-berth
    # staterooms either side of funnel 1's boiler casing; forward of it the gentlemen's
    # lavatory, the plate drawing it no way in (a door est. through the bathroom forward
    # of it, which opens on the cross passage), three bathrooms and a lavatory (the
    # plate's "L", est.); the cross passage between the corridors, and three staterooms.
    ("bathroom", 7331, 2072, 7402, 2171),
    ("store", 7331, 2171, 7402, 2295),
    ("pantry", 7331, 2295, 7402, 2404),
    ("bathroom", 7331, 2404, 7402, 2505),
    ("passage", 7402, 2072, 7438, 2175),
    ("purser's room", 7438, 2072, 7527, 2175),
    ("ladies' lavatory", 7402, 2175, 7518, 2226),
    ("ladies' lavatory", 7402, 2226, 7445, 2359),
    ("ladies' lavatory", 7402, 2359, 7518, 2403),
    ("passage", 7402, 2403, 7441, 2505),
    ("one-berth first-class stateroom", 7527, 2072, 7657, 2171),
    ("one-berth first-class stateroom", 7657, 2072, 7781, 2171),
    ("one-berth first-class stateroom", 7781, 2072, 7903, 2171),
    ("one-berth first-class stateroom", 7903, 2072, 8022, 2170),
    ("one-berth first-class stateroom", 8022, 2072, 8143, 2170),
    ("one-berth first-class stateroom", 8143, 2071, 8268, 2170),
    ("one-berth first-class stateroom", 7441, 2403, 7549, 2505),
    ("one-berth first-class stateroom", 7549, 2403, 7676, 2505),
    ("one-berth first-class stateroom", 7676, 2403, 7795, 2505),
    ("one-berth first-class stateroom", 7795, 2403, 7916, 2505),
    ("one-berth first-class stateroom", 7916, 2403, 8040, 2505),
    ("one-berth first-class stateroom", 8040, 2405, 8162, 2505),
    ("gentlemen's lavatory", 8057, 2170, 8193, 2290),
    ("gentlemen's lavatory", 8126, 2290, 8193, 2405),
    ("bathroom", 8193, 2170, 8268, 2278),
    ("bathroom", 8193, 2278, 8268, 2352),
    ("bathroom", 8193, 2352, 8268, 2423),
    ("lavatory", 8162, 2423, 8233, 2505),
    ("passage", 8268, 2071, 8310, 2505),
    ("two-berth first-class stateroom", 8310, 2071, 8402, 2216),
    ("two-berth first-class stateroom", 8310, 2216, 8402, 2360),
    ("two-berth first-class stateroom", 8310, 2360, 8402, 2502),
    # Along the house's front: the cross passage from her side to her side the corridors
    # run into, a locker at each end (the plate's "E" and "L"), and eight staterooms
    # looking forward over the well.
    ("passage", 8402, 1830, 8446, 2754),
    ("two-berth first-class stateroom", 8446, 1791, 8583, 1918),
    ("two-berth first-class stateroom", 8446, 1918, 8583, 2037),
    ("two-berth first-class stateroom", 8446, 2037, 8583, 2165),
    ("two-berth first-class stateroom", 8446, 2165, 8583, 2288.5),
    ("two-berth first-class stateroom", 8446, 2288.5, 8583, 2404.5),
    ("two-berth first-class stateroom", 8446, 2404.5, 8583, 2534),
    ("two-berth first-class stateroom", 8446, 2534, 8583, 2656),
    ("two-berth first-class stateroom", 8446, 2656, 8583, 2788),
    # Under the forecastle (BOT: "the machinery required for working the anchors and
    # cables ... the crew's galley and the seamen's and firemen's mess room
    # accommodation"). Its rooms at her side are est. as steps inside her curve, each to
    # her side at its forward end. Port, aft to forward: the lamp room (BOT: "On the port
    # side, at the extreme after-end and opening on to the deck, was the lamp room"); the
    # third-class ladderway (the plate's "3rd C"; BOT: "At the after-end of the
    # forecastle, at each side of the ship, were the entrances to the third class spaces
    # below"), its two ladders down side by side; the crew's galley round the port crew's
    # stair; the seamen's mess; the deck men's berths (the plate's "2 Dk. Men").
    ("lamp room", 9201, 1842, 9300, 2008),
    ("third-class ladderway", 9201, 2008, 9370, 2108),
    ("crew's galley", 9300, 1852.5, 9420, 2008),
    ("crew's galley", 9420, 1869, 9542, 2008),
    ("crew's galley", 9370, 2008, 9447, 2132),
    ("crew's galley", 9447, 2008, 9542, 2070),
    ("crew's stair", 9447, 2070, 9618, 2132),
    ("seamen's mess", 9542, 1880, 9618, 2070),
    ("seamen's mess", 9618, 1902, 9750, 2091),
    ("seamen's mess", 9618, 2091, 9666, 2132),
    ("seamen's mess", 9750, 1923, 9848, 2091),
    ("store", 9666, 2091, 9822, 2132),
    ("deck men's berths", 9848, 1948, 9946, 2091),
    # The alleys either side of the block amidships, double doors at their after ends,
    # and the cross passage between them forward of it.
    ("passage", 9259, 2108, 9370, 2191),
    ("passage", 9370, 2132, 9790, 2191),
    ("passage", 9259, 2369, 9373, 2465),
    ("passage", 9373, 2369, 9790, 2434),
    ("passage", 9790, 2132, 9845, 2434),
    # The block amidships: the hospitals (the plate's "Hos."), the galley store, the
    # crew's ladder, the surgery, the carpenter's shop (the plate's "Carp.
    # shop"), between the fan room and No. 1 hatch's trunk.
    ("hospital", 9225, 2191, 9311, 2283),
    ("hospital", 9225, 2283, 9311, 2369),
    ("galley store", 9311, 2191, 9383, 2270),
    ("crew's ladder", 9415, 2191, 9464, 2334),
    ("surgery", 9311, 2308, 9415, 2334),
    ("surgery", 9311, 2334, 9464, 2369),
    ("carpenter's shop", 9567, 2191, 9655, 2369),
    # Starboard, aft to forward: the third-class ladderway; the
    # firemen's mess round the starboard crew's stair; the greasers' mess; the
    # lamp trimmer's and storekeeper's berths (the plate's "Lamp Tr. & S.K.").
    ("third-class ladderway", 9202, 2465, 9373, 2556),
    ("firemen's mess", 9202, 2556, 9373, 2715),
    ("firemen's mess", 9373, 2556, 9466, 2703),
    ("firemen's mess", 9466, 2556, 9604, 2682),
    ("firemen's mess", 9604, 2556, 9750, 2656),
    ("firemen's mess", 9373, 2434, 9466, 2556),
    ("firemen's mess", 9466, 2494, 9604, 2556),
    ("firemen's mess", 9604, 2434, 9750, 2556),
    ("crew's stair", 9466, 2434, 9604, 2494),
    ("greasers' mess", 9750, 2434, 9845, 2634.5),
    ("lamp trimmer's and storekeeper's berths", 9845, 2464, 9950, 2606),
    # Forward of them, the windlass room across her (BOT: "the machinery required for
    # working the anchors and cables and for the warping of the ship"), in steps to her
    # stem; through the wall across her forward of its engines (Plate III's elevation
    # draws a bulkhead there from below up to C deck, its px 10322, 119.6 m), a door est.
    # beside the warping engine. Bulkhead A (BOT: "A extended to C deck, but it was
    # watertight only to D deck") the plate draws only as short webs from her sides, at
    # px 10128 (116.6 m; BULKHEADS has it at 115.81): not laid. The plate leaves the
    # room's ends open by her side, which the steps inside her curve close.
    ("windlass machinery room", 9845, 2091, 9946, 2464),
    ("windlass machinery room", 9946, 1976.5, 10042, 2578),
    ("windlass machinery room", 10042, 2027.5, 10181, 2525.5),
    ("windlass machinery room", 10181, 2057, 10246, 2495.5),
    ("windlass machinery room", 10246, 2092.5, 10320, 2459),
    ("windlass machinery room", 10320, 2135, 10400, 2415),
    ("windlass machinery room", 10400, 2169, 10480, 2380.5),
]

SOLIDS = [
    # The trunk on the plate's centre line at the steering gear room's forward bulkhead.
    ("trunk", 1025, 2302, 1057, 2334, None),
    ("trunk", 1025, 2334, 1057, 2364, None),
    # The steering engines (the plate's "Steering engines"; BOT: "The engines were in
    # duplicate") and the after capstan gear (the plate's "Capstan gear"), est. 1.5 m
    # and 1.2 m high.
    ("steering engine", 877, 2145, 954, 2322, 1.5),
    ("steering engine", 879, 2348, 959, 2518, 1.5),
    ("capstan gear", 834, 2060, 975, 2101, 1.2),
    ("capstan gear", 838, 2562, 980, 2596, 1.2),
    ("capstan gear", 593, 2138, 641, 2352, 1.2),
    ("capstan gear", 596, 2408, 644, 2521, 1.2),
    # On the after well: No. 6 hatch, the electric winch and No. 5 hatch, their coamings
    # and covers est. 0.8 m high; No. 5's forward coaming on the after entrance's outer
    # line, 10 px aft of the wall's middle, so the wall stands whole over it.
    ("No. 6 hatch", 1640, 2219, 1748, 2436, 0.8),
    ("electric winch", 1868, 2300, 1912, 2360, 1.0),
    ("No. 5 hatch", 1960, 2214, 2100, 2431, 0.8),
    # The electric cranes at the after entrance's after corners, on her open deck.
    ("electric crane", 2175, 2017, 2233, 2075, 2.5),
    ("electric crane", 2181, 2565, 2239, 2623, 2.5),
    # The bulkheads across the promenade between the third-class promenade aft and the
    # second-class forward (BOT: "sheltered by bulwarks and bulkheads"), each with its
    # door (BOT: "two doors at the after-end into the after-well"), widened to 0.9 m.
    ("bulkhead", 2286, 1808, 2294, 1862, None),
    ("bulkhead", 2286, 1898, 2294, 2036.75, None),
    ("bulkhead", 2292, 2606.25, 2300, 2752, None),
    ("bulkhead", 2292, 2788, 2300, 2829, None),
    # The after stairway's well: the after half of the box its flights go down into,
    # and the well between its flights.
    ("stairwell", 2110, 2212, 2198, 2324, None),
    ("stairwell", 2208, 2293, 2258, 2326, None),
    # No. 4 hatch's trunks, up through B deck's smoking room's after corners (b_aft.py).
    ("No. 4 hatch trunk", 2457, 1947, 2566, 2036.75, None),
    # The starboard one's forward side on the port one's line, 10 px aft of the plate's.
    ("No. 4 hatch trunk", 2467, 2606.25, 2566, 2706, None),
    # The ventilators along the library's forward wall, as B deck's (b_aft.py).
    ("ventilators", 2884, 2204, 2925.5, 2436, None),
    # The second-class lift.
    ("second-class lift", 3029, 2280.25, 3117, 2357.25, None),
    # The house's after end: the bathrooms' W.C.s; the lavatories' W.C.s; the space the
    # plate calls "Engr." and the tanks aft of the turbine engine casing; the light and
    # air trunks to the galley on D deck (the plate's "L & A to Gal." and "L & A"), the
    # second in the passage behind the after grand staircase's hall, 16 px shorter at each
    # end so each of the passage's doors from the hall has a body's door of wall; a
    # wardrobe.
    ("W.C.", 3659, 1781, 3683, 1880, None),
    ("W.C.", 3731, 1880, 3762, 1985.5, None),
    ("W.C.s", 3482, 2195, 3554, 2318, None),
    ("W.C.s", 3490, 2318, 3554, 2428, None),
    ("engineers' space", 3554, 2193, 3662, 2318, None),
    ("tanks", 3554, 2318, 3662, 2428, None),
    ("turbine engine casing", 3662, 2193, 3875, 2428, None),
    ("light and air trunk to the galley", 3875, 2193, 3965, 2428, None),
    ("light and air trunk", 4014, 2236, 4052, 2381, None),
    # The plate's wardrobe off the stateroom aft, 10 px shorter so the one-berth room's
    # door has a body's width beside it.
    ("wardrobe", 3968, 2041, 4009, 2067, None),
    ("W.C.", 3737, 2638, 3774, 2737, None),
    ("W.C.", 3669, 2737, 3700, 2844.5, None),
    # The ladder from the surgery down to the hospital on D deck: 74 px of treads (1.9 m)
    # for 3.2 m of rise, with no room to run on to a slope a body climbs, so its well is
    # a block.
    ("stairwell", 3340, 2641, 3414, 2692, None),
    # Forward of the after entrance: the bathrooms' W.C.s, the light and air trunk at the
    # head of its stairs, the reciprocating engine casing, and the fans and trunks forward
    # of the maids' and valets' pantry.
    ("W.C.", 4223, 1777.5, 4256, 1877, None),
    ("W.C.", 4151, 1877, 4185, 1985.5, None),
    ("W.C.", 4499, 1776, 4530, 1877, None),
    ("W.C.", 4570, 1877, 4604, 1985.5, None),
    ("light and air trunk", 4357, 2188.5, 4402, 2424.5, None),
    ("reciprocating engine casing", 4402, 2188.5, 4684, 2424.5, None),
    ("fans and trunks", 4825, 2188.5, 4880, 2424.5, None),
    ("W.C.", 4157, 2634, 4189, 2737, None),
    ("W.C.", 4238, 2737, 4266, 2841, None),
    ("W.C.", 4581, 2630, 4616, 2737, None),
    ("W.C.", 4509, 2737, 4540, 2839.5, None),
    # From funnel 3's boiler casing to funnel 2's: the W.C.s of the private lobbies;
    # funnel 3's boiler casing and the fans and trunks forward of it; the W.C.s of the
    # gentlemen's and the ladies' lavatories; and funnel 2's fans and trunks aft of its
    # casing.
    ("W.C.", 5054, 1772.5, 5097, 1876, None),
    ("W.C.", 5476, 1770, 5511, 1873, None),
    ("W.C.", 6038, 1767, 6077, 1871, None),
    ("W.C.", 5064, 2749, 5106, 2836, None),
    ("W.C.", 5487, 2745, 5523, 2833.5, None),
    ("W.C.", 6044, 2745, 6083, 2830.5, None),
    ("funnel 3's boiler casing", 4880, 2188, 5271, 2422.5, None),
    ("fans and trunks", 5271, 2188, 5357, 2421, None),
    ("W.C.s", 5357, 2188, 5430, 2325, None),
    ("W.C.s", 6091, 2253, 6171, 2418, None),
    ("fans and trunks", 6171, 2186, 6251, 2418, None),
    ("funnel 2's boiler casing", 6251, 2185.5, 6633, 2417, None),
    ("fans and trunks", 6633, 2185.5, 6700, 2417, None),
    ("W.C.", 6387, 1764.5, 6425, 1866, None),
    ("W.C.", 6393, 2741, 6431, 2828.5, None),
    # The forward entrance: the lockers at the ends of its passages out to her side and
    # of the cross passage forward of it; the three first-class lifts (BOT: "three
    # elevators communicating from E to A decks").
    ("locker", 7006, 1761, 7045, 1798, None),
    ("locker", 7013, 2792, 7050, 2824.5, None),
    ("locker", 7300, 1759, 7331, 1790, None),
    ("locker", 7300, 2800, 7331, 2823, None),
    ("first-class lifts", 7082, 2184, 7173.5, 2410, None),
    # Forward of the entrance: the short passages' lockers; the ladies' lavatory's
    # W.C.s; funnel 1's boiler casing between its fans and trunks; the gentlemen's
    # lavatory's W.C.s; two closets by its lavatory; the front cross passage's lockers.
    ("locker", 7564, 1757.5, 7602, 1793, None),
    ("locker", 7848, 1764, 7884, 1796, None),
    ("locker", 8126, 1771.5, 8168, 1815, None),
    ("locker", 7568, 2795, 7604, 2821.5, None),
    ("locker", 7849, 2790, 7885, 2819.5, None),
    ("locker", 8129, 2769, 8167, 2802, None),
    ("W.C.s", 7445, 2226, 7518, 2359, None),
    ("fans and trunks", 7518, 2171, 7604, 2403, None),
    ("funnel 1's boiler casing", 7604, 2171, 7988, 2402, None),
    ("fans and trunks", 7988, 2171, 8057, 2401, None),
    ("W.C.s", 8057, 2290, 8126, 2401, None),
    ("closet", 8162, 2405, 8193, 2423, None),
    ("closet", 8233, 2423, 8268, 2505, None),
    ("locker", 8402, 1781, 8446, 1830, None),
    ("locker", 8402, 2754, 8446, 2788.5, None),
    # The forward well (BOT: "This space contained two hatchways, the No. 2 hatch and the
    # bunker hatch"): the hatches, their covers est. 0.8 m high; the electric winches
    # and cranes. No. 2 hatch's forward coaming is under the forecastle's after edge.
    ("electric crane", 8653, 1993, 8711, 2051, 2.5),
    ("electric crane", 8659, 2523, 8717, 2581, 2.5),
    ("electric winch", 8656, 2217, 8742, 2263, 1.0),
    ("electric winch", 8652, 2306, 8740, 2350, 1.0),
    ("bunker hatch", 8760, 2168, 8902, 2405, 0.8),
    ("No. 2 hatch", 9007, 2166, 9194, 2419, 0.8),
    # The forecastle's after bulkhead across her in front of the block amidships, 30 px
    # aft of the block's own wall: a void between them narrower than a body.
    ("the forecastle's after bulkhead", 9192, 2170, 9225, 2430, None),
    # Under the forecastle: the closets in its block amidships, the fan room and No. 1
    # hatch's trunk; the chain pipes down to the cable lockers, each as a block round
    # the plate's pipe and trunk; the windlass engines and the cable lifters, and
    # forward of the wall across her the warping engine, est. 1.5 m and 1.0 m high.
    ("closet", 9383, 2191, 9415, 2270, None),
    ("closet", 9311, 2270, 9415, 2308, None),
    ("fans", 9464, 2191, 9567, 2369, None),
    ("No. 1 hatch trunk", 9655, 2191, 9790, 2369, None),
    ("chain pipe", 9822, 2091, 9845, 2132, None),
    ("chain pipe", 9845, 2091, 9875, 2250, None),
    ("chain pipe", 9845, 2314, 9875, 2464, None),
    ("locker", 9373, 2434, 9420, 2465, None),
    ("cable lifter", 9958, 2190, 10042, 2262, 1.0),
    ("cable lifter", 9958, 2300, 10042, 2372, 1.0),
    ("windlass engine", 10042, 2166, 10181, 2384, 1.5),
    ("warping engine", 10257, 2211, 10320, 2350, 1.5),
    ("warping engine", 10320, 2211, 10392, 2350, 1.5),
]

DOORS = [
    # The stores into the steering gear room; the steering gear room into the general
    # room (est.: the plate draws no way into it, and the poop deck over it no hatch).
    (936, 2005), (936, 2660), (1025, 2480),
    # The third-class entrance into the smoking room and the general room, onto the
    # promenade either side (double doors), and onto the well forward; the bar.
    (1354, 2166), (1354, 2485), (1530, 2160), (1530, 2491), (1630, 2185), (1630, 2470),
    (1478, 1972),
    # The after second-class entrance from the promenades, into its stores and the
    # library; the library into the forward entrance either side of its ventilators.
    (2327, 2036.75), (2327, 2606.25), (2198, 2186), (2198, 2460), (2461, 2327),
    (2925.5, 2180), (2925.5, 2453),
    # The forward second-class entrance from the promenades.
    (2953, 1971), (3053, 1971), (2953, 2669.75), (3053, 2669.75),
    # The house's corridors from the promenade (BOT: "access by a door from this space
    # into each of the alleyways in the first class accommodation").
    (3280, 2013), (3280, 2612),
    # Its after end, port: the staterooms off the corridor, and through to the next; the
    # bathrooms from their staterooms.
    (3360, 1985.5), (3420, 1985.5), (3645, 1985.5), (3790, 1985.5), (3910, 1985.5),
    (4110, 1985.5), (3403, 1925), (3530, 1920), (3890, 1908), (4021, 1908),
    (3762, 1855), (3659, 1920),
    # Inboard: off the cross passage, the lavatory passage and the corridor.
    (3378, 2100), (3378, 2235), (3482, 2175), (3685, 2041), (3745, 2041), (3937, 2041),
    (4032, 2041),
    (3378, 2362), (3378, 2431), (3378, 2563), (3490, 2447), (3620, 2584), (3698, 2584),
    (3892, 2584), (3952, 2584), (4052, 2210), (4052, 2410),
    # Starboard, at her side: the passage into the surgery and on into it; the
    # staterooms and their bathrooms.
    (3310, 2640), (3310, 2692), (3433, 2640), (3643, 2640), (3808, 2640), (3917, 2640),
    (4127, 2632), (3540, 2710), (3904, 2705), (4031, 2705), (3669, 2690), (3774, 2790),
    # Forward of the after entrance, port: staterooms and bathrooms; the barber's shop
    # from the hall; the pantry from its passage and into the saloon; the saloon from
    # the hall.
    (4330, 1985.5), (4470, 1985.5), (4625, 1985.5), (4762, 1985.5), (4376, 1875),
    (4736, 1869), (4863, 1872), (4151, 1830), (4256, 1935), (4604, 1840), (4499, 1930),
    (4292, 2160), (4560, 2039), (4620, 2039), (4765, 2039), (4731, 2188.5), (4760, 2424.5),
    (4292, 2461),
    # Starboard: staterooms and bathrooms.
    (4315, 2632), (4488, 2632), (4633, 2632), (4766, 2632), (4266, 2690), (4157, 2790),
    (4509, 2690), (4616, 2790),
    # From funnel 3 to funnel 2, port, at her side: the staterooms off the corridor and
    # through to the next; the private lobbies into the staterooms either side, the
    # bathrooms into them where the plate draws it; the wardrobe rooms into their lobby
    # (the plate draws them no swing).
    (4960.5, 1982.5), (5123.5, 1982.5), (5251.5, 1982), (5461, 1982), (5613, 1981.5),
    (5743, 1981.5), (5943.5, 1981.5), (6107, 1981), (6297, 1981), (6450, 1980.5),
    (6602.5, 1980.5),
    (5221, 1905), (5350, 1907), (5712, 1915), (5840, 1908), (6203, 1905), (6562, 1872),
    (4990, 1891.5), (5097, 1887.5), (5007.5, 1876), (5015, 1910), (5069, 1910),
    (5476, 1884), (5588, 1891), (5503, 1909), (5559, 1909),
    (5968, 1889), (6077, 1885.5), (5996, 1905), (6050, 1905),
    (6318, 1883), (6425, 1876), (6344, 1903), (6398, 1903),
    # Inboard: the staterooms off the corridors and the cross passages; the gentlemen's
    # lavatory and the pantry off the cross passage, the second pantry through it (est.:
    # the plate draws neither a swing); the Marconi operators' saloon into the maids' and
    # valets' saloon; the mess stewards' room and the ladies' lavatory off their cross
    # passage.
    (4955.5, 2038), (5025.5, 2037), (5203.5, 2037), (5269, 2037), (5450, 2037),
    (5478, 2290), (5482, 2509.5), (5420, 2500), (4882, 2525.5),
    (5086, 2574), (5160, 2573), (5281, 2573),
    (5587.5, 2036), (5722, 2104), (5722, 2247.5), (5722, 2359.5), (5698.5, 2572),
    (5768, 2099.5), (5894, 2035), (5768, 2246.5), (5768, 2352.5), (5895.5, 2571),
    (6011, 2078), (6130, 2034.5), (6011, 2347), (6080.5, 2569.5), (6181, 2569.5),
    # The alcove's bathroom from the stateroom beside it (est.: its side on the alcove is
    # narrower than a body's door).
    (6140, 2186),
    (6312.5, 2034), (6361.5, 2034), (6543, 2034), (6608.5, 2034),
    (6297, 2568.5), (6361, 2568), (6487.5, 2567.5), (6609.5, 2567),
    # Starboard, at her side, as to port; two lobbies (at 4999-5106 and 6328-6431) the
    # plate draws closed, their doors est. where the others' are.
    (4969.5, 2628.5), (5128.5, 2627.5), (5253.5, 2627), (5462.5, 2626.5), (5615, 2625.5),
    (5745.5, 2625), (5951.5, 2624.5), (6110.5, 2623.5), (6298, 2622.5), (6451.5, 2621),
    (6617.5, 2619.5),
    (5228, 2711), (5362, 2707), (5721, 2711), (5846, 2715), (6206, 2705.5), (6565, 2731),
    (4999, 2729), (5106, 2729), (5025.5, 2709), (5079, 2709),
    (5487, 2724), (5594, 2727.5), (5512, 2703), (5565.5, 2703),
    (5978, 2723.5), (6083, 2726), (6002, 2702), (6054.5, 2702),
    (6328, 2720), (6431, 2720), (6352.5, 2699), (6404, 2699),
    # The forward entrance. The plate draws its hall's after and forward walls whole,
    # though the corridors run up to them and BOT has the cabins forward of midships
    # reach the boat deck by its staircase: a door est. where each corridor meets them.
    (6700, 2010), (6700, 2598.5), (7300, 2047), (7300, 2532),
    # Its corner staterooms: into the passages out to her side, their baths, and the
    # inner room of each pair; the outer and the inner rooms into the cross passage; the
    # purser's office and the starboard passage from the hall.
    (7006, 1893), (7045, 1850), (7075, 1928), (7153, 1812), (7200, 1865), (7300, 1870),
    (7300, 1990), (6990, 2669), (7031.5, 2669), (7050, 2745), (7075, 2666), (7156, 2787),
    (7206, 2745), (7300, 2742), (7300, 2610), (6801.5, 1928), (6801.5, 2670.5),
    # Forward of the entrance, port: each four's stateroom into the passage aft, its
    # bath, and the pair's inner room; the bath onto the corridor; the pair's rooms into
    # the passage forward, and through the outer room's slanting end into the inner.
    (7331, 1854.5), (7348.5, 1924), (7433, 1835.5), (7354.5, 2019), (7564, 1983.5),
    (7564, 1840), (7475, 1885),
    (7602, 1861), (7621, 1922), (7708, 1820.5), (7622, 2018), (7848, 1982.5), (7848, 1879),
    (7750, 1873),
    (7884, 1858.5), (7901.5, 1920), (7991, 1819.5), (7907, 2017), (8126, 1980.5),
    (8126, 1878.5), (8033, 1840),
    (8168, 1869), (8185, 1919), (8272, 1833), (8186, 2015), (8402, 1975), (8402, 1855.5),
    (8312, 1860),
    # Starboard, the same; where the plate draws a stateroom one swing in its corner by
    # its bath, it opens into the bath and its door aft is est.
    (7362, 2558), (7352, 2662), (7331, 2700), (7436, 2737.5), (7568, 2625.5), (7568, 2745),
    (7477, 2745),
    (7634, 2558), (7624, 2660), (7604, 2719.5), (7712, 2773), (7849, 2611.5), (7849, 2716),
    (7753, 2740),
    (7912.5, 2558), (7905, 2658), (7885, 2721.5), (7990, 2774), (8129, 2611), (8129, 2731.5),
    (8031, 2735),
    (8191, 2558), (8181.5, 2657), (8167, 2700), (8271, 2754.5), (8402, 2608.5), (8402, 2720),
    (8310, 2725),
    # Between the corridors: the pantry, the purser's room, the ladies' lavatory from
    # both its passages (the starboard one est.); the one-berth staterooms; the
    # gentlemen's lavatory through the bathroom forward of it, and the lavatory (both
    # est.); the three staterooms into the cross passage forward.
    (7331, 2315.5), (7438, 2119.5), (7506, 2072), (7426.5, 2175), (7421.5, 2403),
    (7631.5, 2072), (7691.5, 2072), (7871.5, 2072), (7930.5, 2072), (8114.5, 2072),
    (8175.5, 2071), (7527.5, 2505), (7576, 2505), (7771.5, 2505), (7824, 2505), (8007, 2505),
    (8067.5, 2505), (8193, 2224), (8268, 2224), (8197.5, 2505), (8402, 2155), (8402, 2264),
    (8402, 2402),
    # The staterooms along the house's front, from the cross passage there.
    (8446, 1867.5), (8446, 1981), (8446, 2096.5), (8446, 2240.5), (8446, 2330), (8446, 2481),
    (8446, 2584), (8446, 2702.5),
    # Under the forecastle: the lamp room onto the deck (est., BOT); the third-class
    # entrances; the alleys' double doors; the hospitals (from the alleys, 35 px forward
    # of the plate's swings on the covered gaps, whose walls are narrower than a body's
    # door), the galley store, the middle ladder's lobby and the surgery; the crew's
    # galley, the port stair's lobby, the seamen's mess and the store; the carpenter's
    # shop; the deck men's berths from the mess; the firemen's mess (the starboard stair's
    # lobby open into it) and the greasers' mess, each door clear of the joint of the
    # alleys' two pieces (est.); the windlass room from the cross passage, between the
    # chain pipes; the lamp trimmer's and storekeeper's berths from it (est.).
    (9201, 1925), (9222, 2108), (9222, 2465), (9259, 2150), (9259, 2417),
    (9285, 2191), (9285, 2369), (9337, 2191), (9435, 2191), (9350, 2369),
    (9420, 2132), (9460, 2132), (9640, 2132), (9736, 2132), (9600, 2191), (9848, 1977),
    (9431, 2434), (9817, 2434), (9845, 2282), (9900, 2464), (10246, 2395),
]

OPEN = [
    # The steering gear room's steps.
    (790, 2025, 936, 2037), (790, 2621.5, 936, 2633.5), (784, 2031, 796, 2627.5),
    (579, 2098, 591, 2560),
    # The smoking room's and the general room's.
    (1154, 1913, 1166, 2326), (1294, 1894, 1306, 2326), (1348, 1877, 1360, 2160),
    (1154, 2342, 1166, 2737), (1294, 2342, 1306, 2754), (1348, 2491, 1360, 2772),
    # The after second-class entrance's four, and the library's four.
    (2258, 2160, 2270, 2485), (2418, 2207, 2430, 2441), (2192, 2324, 2204, 2436),
    (2455, 2036.75, 2467, 2207), (2455, 2441, 2467, 2606.25),
    (2560, 2036.75, 2572, 2606.25),
    # The forward second-class entrance's: its corners, its lanes and its well.
    (3023, 1971, 3035, 2202.5), (3023, 2432.5, 3035, 2669.75), (3023, 2202.5, 3035, 2280.25),
    (3023, 2357.25, 3035, 2432.5), (3111, 2202.5, 3123, 2280.25),
    # The house's after end: the cross passage and the lavatories' passages into the
    # corridors.
    (3383, 2035, 3411, 2047), (3383, 2578, 3411, 2590), (3487, 2035, 3514, 2047),
    (3495, 2578, 3520, 2590),
    # The after entrance's hall into the corridors either side, and its two pieces; the
    # passage down to the pantry.
    (4046, 1991, 4058, 2035), (4046, 2590, 4058, 2634), (4286, 1991, 4298, 2033),
    (4286, 2582, 4298, 2626), (4286, 2194, 4298, 2419), (4716, 2033, 4746, 2045),
    # The gentlemen's lavatory's two pieces; the cross
    # passages into the corridors; the alcove into its cross passage.
    (5436, 2319, 5476, 2331),
    (5487, 2031, 5511, 2043), (5487, 2567, 5511, 2579), (5727, 2030, 5763, 2042),
    (5727, 2566, 5763, 2578), (5975, 2029, 6006, 2041), (5975, 2565, 6006, 2577),
    (6005, 2160, 6017, 2181),
    # The forward entrance's hall: its two pieces; the port passage out to her side;
    # its corner staterooms'
    # two pieces each.
    (7045, 2031, 7057, 2558),
    # Forward of it: the pairs' two pieces each; the ladies' lavatory's three; the
    # gentlemen's two; the corridors into the cross passages aft and forward and into the
    # short passages; the cross passage between them into both.
    (7439, 1917, 7469, 1929), (7714, 1914, 7744, 1926), (7997, 1913, 8027, 1925),
    (8278, 1911, 8306, 1923), (7442, 2658, 7471, 2670), (7718, 2654, 7747, 2666),
    (7996, 2653, 8025, 2665), (8277, 2651, 8304, 2663),
    (7408, 2220, 7439, 2232), (7408, 2353, 7439, 2365), (8132, 2284, 8187, 2296),
    (7325, 2022, 7337, 2066), (7325, 2511, 7337, 2552), (8396, 2022, 8408, 2066),
    (8396, 2511, 8408, 2552), (7570, 2013, 7596, 2025), (7854, 2012, 7878, 2024),
    (8132, 2010, 8162, 2022), (7574, 2552, 7598, 2564), (7855, 2552, 7879, 2564),
    (8135, 2552, 8161, 2564), (8274, 2066, 8304, 2078), (8274, 2499, 8304, 2511),
    (7408, 2066, 7432, 2078), (7408, 2499, 7435, 2511),
    # Under the forecastle: the galley's pieces; the seamen's mess's; the alleys' and the
    # cross passage; the surgery's; the firemen's mess's; the windlass room's steps, and
    # past bulkhead A's ends.
    (9414, 1869, 9426, 2008), (9370, 2002, 9447, 2014), (9441, 2008, 9453, 2070),
    (9612, 1902, 9624, 2070), (9618, 2085, 9666, 2097), (9744, 1923, 9756, 2091),
    (9364, 2132, 9376, 2191), (9367, 2369, 9379, 2434), (9784, 2132, 9796, 2191),
    # The starboard crew's stair's lobby into the firemen's mess aft of it, the stair's
    # head on its after wall (est.: a body steps off it there).
    (9460, 2434, 9472, 2494),
    (9784, 2369, 9796, 2434), (9311, 2328, 9415, 2340),
    (9367, 2556, 9379, 2703), (9460, 2556, 9472, 2682), (9598, 2556, 9610, 2656),
    (9373, 2550, 9466, 2562), (9466, 2550, 9604, 2562), (9604, 2550, 9750, 2562),
    (9460, 2494, 9472, 2556), (9598, 2494, 9610, 2556),
    (9940, 2091, 9952, 2464), (10036, 2027.5, 10048, 2525.5), (10175, 2057, 10187, 2495.5),
    (10314, 2135, 10326, 2415),
    (10394, 2169, 10406, 2380.5),
    (7010, 1922, 7041, 1934), (7159, 1922, 7194, 1934), (7162, 2660, 7200, 2672),
]

STAIRS = [
    # The main third-class stairway down to D deck (BOT: "16 ft. to E deck"), rising
    # forward to its landing: the plate's middle and starboard lanes, its port lane left
    # for the poop's flight down. The plate draws 94 px of treads (2.3 m) for 10 ft 6 in
    # of rise; a body climbs no steeper than tools/gen_titanic.py's STEEPEST, so it runs on
    # 64 px forward over the landing.
    ("third-class stairway", 1358, 2272.5, 1516, 2438, "fore", "d", "c"),
    # The after second-class stairway down to D deck, its starboard flight (B deck's
    # comes down to port, b_aft.py), rising forward to the hall: the plate's 59 px of
    # treads run on aft through the wall into the box the plate draws them going down
    # into, to a slope a body climbs, its foot 10 px short of the plate's box so a body
    # steps off it clear of D deck's after entrance's after wall (d.py).
    ("second-class stairway", 2122, 2353, 2267, 2436, "fore", "d", "c"),
    # The forward second-class staircase down to D deck, starboard of the lift, rising
    # aft to the hall: its 88 px of treads run on forward into the well forward of the
    # lift, which the plate draws them going down into.
    ("second-class staircase", 3029, 2357.25, 3176, 2432.5, "aft", "d", "c"),
    # The stewards' staircase down to D deck, as the plate draws it in its round well:
    # 97 px of treads (2.5 m) for 3.2 m, run on to 145 px; rising to starboard, so its
    # foot meets the head of D deck's flight to port (d.py's, est.).
    ("stewards' staircase", 4780, 2240, 4818, 2385, "starboard", "d", "c"),
    # The grand staircase's flight down to D deck, rising forward to the lifts' landing:
    # the starboard half of the plate's flight, B deck's coming down to port of it
    # (b_fwd.py). The plate draws 129 px of treads (3.4 m) for 10 ft 6 in of rise; it
    # runs on 13 px aft into the hall, to a slope a body climbs.
    ("grand staircase", 6874, 2300, 7016, 2410, "fore", "d", "c"),
    # Under the forecastle, the flights down to D deck, each run on to the slope a body
    # climbs for C deck's 10 ft 6 in over D deck (BOT has it 9 ft at the forward end;
    # tools/gen_titanic.py lays D deck level): the third-class ladderways, two ladders
    # 4 ft wide side by side (BOT), their 85-91 px of treads run on aft over their
    # entrances' floors; the crew's stairs at the alleys' sides, their 94-104 px run on
    # over their lobbies' landings; and the middle ladder, rising to port from the
    # plate's D deck flight (d.py) to its lobby's door, its 95 px of treads run on to the
    # lobby's whole length, 143 px. The steepest of C deck's flights, the ladderways and
    # these crew's flights, climb 0.864 (STEEPEST 0.875).
    ("third-class ladderway", 9231, 2008, 9370, 2108, "aft", "d", "c"),
    ("third-class ladderway", 9234, 2465, 9373, 2556, "aft", "d", "c"),
    ("crew's stair", 9481, 2077, 9618, 2125, "aft", "d", "c"),
    ("crew's stair", 9465, 2437, 9604, 2491, "aft", "d", "c"),
    ("crew's ladder", 9421, 2191, 9454, 2334, "port", "d", "c"),
]
