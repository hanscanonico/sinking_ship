"""The tank top, her inner bottom, as Plate V draws it ("Tank Top"): The Shipbuilder, June
1911, leaf n320 (plates.tsv). Her machinery is sized off Plates VI-VIII, the same number's
boiler rooms 1 and 2 (VI, leaf n322) and engine rooms (VII and VIII, leaves n324 and n326).

Read in the plate's own pixels, as deck.py says. Where the plate and a body disagree,
the comment beside the piece says what was changed and why. The plate's doors are marks
on unbroken bulkhead lines ("W.T.D") or gaps in them: a door stands at its mark.

BOT, "Decks and Accommodation": "Below these decks again came the inner bottom, extending
fore and aft through about nine-tenths of the vessel's length, and on this were placed the
boilers, main and auxiliary machinery and the electric light machines. In the remaining
spaces below G deck were cargo holds or 'tween decks ... The firemen's passage, giving
direct access from their accommodation to the forward boiler room by stairs at the
forward end ... was made thoroughly watertight throughout its length, and at its after-end
was closed by a watertight vertical sliding door". The plate draws, from aft: the shaft
tunnels, the electric engine room with its fresh water tanks, the turbine and the
reciprocating engine rooms, boiler rooms 1-6 with the coal in their cross bunkers, Nos.
3, 2 and 1 holds, and through Nos. 3 and 2 the firemen's passage and pipe tunnel to the
firemen's spiral stairs. Aft of bulkhead P and forward of A are her peak tanks: the double
bottom, and the peaks, are not traced here.

The deck is her tank top, the generator's TANK_TOP; under the reciprocating engines the
double bottom is a foot deeper (ENGINE_TANK_TOP), so that room's floor stands 0.3 m higher.
A solid's height is metres over the tank top. The 1912 Titanic is the plate here: BOT and
The Shipbuilder vol. VI give no difference below G deck.

The plate draws no flight on the tank top, and the tank top has none down: STAIRS is empty.
Every ladder and stair up from it belongs to the deck at its top (see STAIRS).
"""
PLATE = "V"
CROP = (430, 4330, 10260, 5500)

# Calibrated piecewise on the watertight bulkheads the view draws, each at
# tools/gen_titanic.py's BULKHEADS, each bulkhead's plate x its ink's middle down the view.
# M is not at BULKHEADS' -66.02: this view draws it 55% of the way from N to L, -64.90 read
# between them, which is where Plate III's elevation steps M between the orlop and F deck
# (-64.87, as G deck's and the orlop's views draw it too); so M is calibrated on the step.
# Plate VIII agrees: on one scale its turbine room and reciprocating engine room hold M at
# -64.72, and The Shipbuilder's text gives the turbine room as "54ft. long" (16.46 m: M at
# -65.09). B is drawn where BULKHEADS has it: read between C and A it is at 101.77, 0.08 m
# off, as the orlop's view draws it too (G and F decks' views draw it at 99.5). The
# firemen's passage's forward end round the spiral stairs starts at 100.19, abaft B, as the
# orlop's spiral trunk does (orlop.py: the elevation's second B line, at 100.10, is the
# trunk's after wall).
# A straight line through the others (38.05 px a metre) leaves them +0.53 m (P), +0.10 (O),
# +0.05 (N), -0.62 (L), -0.43 (K), -0.29 (J), -0.05 (H), +0.11 (G), +0.08 (F), +0.21 (E),
# +0.28 (D), +0.23 (C) and -0.20 (A) off, B +0.09, M's step -0.29 (BULKHEADS' M -1.44).
# Piecewise every control reads exactly, each compartment at 37.5-39.0 px a metre.
X = [
    (795.5, -118.97, "bulkhead P"),
    (1469.5, -101.69, "bulkhead O"),
    (2101.0, -85.14, "bulkhead N"),
    (2885.2, -64.87, "bulkhead M, as Plate III's elevation steps it between the orlop and F deck"),
    (3515.5, -48.63, "bulkhead L"),
    (4304.5, -27.71, "bulkhead K"),
    (4716.0, -16.75, "bulkhead J"),
    (5408.4, 1.69, "bulkhead H"),
    (6067.9, 19.18, "bulkhead G"),
    (6726.5, 36.46, "bulkhead F"),
    (7389.2, 54.01, "bulkhead E"),
    (8024.0, 70.76, "bulkhead D"),
    (8617.0, 86.30, "bulkhead C"),
    (9214.0, 101.85, "bulkhead B"),
    (9756.0, 115.81, "bulkhead A"),
]
# The centre line, fitted to its dashes as drawn from px 600 to 10300 (2.4 px rms; it bows
# up to 6 px off a straight line over the scan, aft of O and abreast boiler room 3); across
# her, her sides' double lines' middles 1084.5 px apart from px 4700 to 6000, abreast
# boiler rooms 2-4, for her 92 ft moulded.
Z = dict(centre=((600, 4954.3), (10100, 4899.3)), scale=0.02585)

# The deck itself: her inner bottom from bulkhead P to bulkhead A, her whole breadth.
DECKS = [(795.5, None, 9756.0, None)]

ROOMS = [
    # Aft of N, the shaft tunnels ("TUNNEL"): the wing shafts' between O and N, the shafts'
    # between P and O. Each room runs between the T-marked side lines the plate draws for
    # her sides at the tank top, in steps as her run narrows aft. The solid lines along them
    # that close to a point aft are the flat of her inner bottom's edges: drawn the same
    # across the electric engine room's floor and under its engines, they are no walls.
    ("shaft tunnel", 795.5, 4891.4, 1020.2, 5027.8),
    ("shaft tunnel", 1020.2, 4851.7, 1244.8, 5074.5),
    ("shaft tunnel", 1244.8, 4803.2, 1469.5, 5123.7),
    ("shaft tunnel", 1469.5, 4745.5, 1680, 5175.1),
    ("shaft tunnel", 1680, 4688.3, 1890.5, 5216.3),
    ("shaft tunnel", 1890.5, 4631.9, 2101, 5243.0),
    # N to M: the electric engine room (BOT: "the electric light machines"), between its
    # fresh water tanks.
    ("electric engine room", 2101, 4705, 2885.2, 5203),
    # M to L: the turbine engine room; L to K, the reciprocating engine room. Each one
    # rectangle, its sides on her double line's middle at its middle: its machinery stands
    # in it from end to end, so it takes no steps.
    ("turbine engine room", 2885.2, 4480.0, 3515.5, 5400.0),
    ("reciprocating engine room", 3515.5, 4416.4, 4304.5, 5449.4),
    # The boiler rooms, each from its after bulkhead or bunker's face to its forward bunker's
    # face, her side to her side, its boilers standing in it. Boiler rooms 5 and 6, where her
    # sides close in, in three pieces each: the after stokehold, the boilers', the forward
    # stokehold.
    ("boiler room 1", 4304.5, 4392.7, 4570, 5465.0),
    ("boiler room 2", 4818.5, 4383.8, 5257, 5466.9),
    ("boiler room 3", 5514.5, 4378.3, 5961, 5464.3),
    ("boiler room 4", 6175.5, 4378.0, 6612, 5455.1),
    ("boiler room 5", 6858.5, 4394.4, 6958, 5437.0),
    ("boiler room 5", 6958, 4404.1, 7188.5, 5427.3),
    ("boiler room 5", 7188.5, 4413.8, 7292.5, 5413.8),
    ("boiler room 6", 7487.5, 4439.4, 7581.5, 5385.0),
    ("boiler room 6", 7581.5, 4459.8, 7815, 5365.2),
    ("boiler room 6", 7815, 4486.1, 7916, 5343.5),
    # The passage through each cross bunker, from boiler room to boiler room through the
    # bulkhead in the bunker's middle: a door from the stokehold aft of it, the watertight
    # door in the bulkhead, and on through the bunker's forward half, which the plate leaves
    # open to the stokehold forward of it: that half is the forward boiler room's.
    ("passage, tank top", 4570, 5009, 4716, 5080),
    ("boiler room 2", 4716, 5009, 4818.5, 5080),
    ("passage, tank top", 5257, 4996, 5408.4, 5074.5),
    ("boiler room 3", 5408.4, 4996, 5514.5, 5074.5),
    ("passage, tank top", 5961, 4995, 6067.9, 5066),
    ("boiler room 4", 6067.9, 4995, 6175.5, 5066),
    ("passage, tank top", 6612, 4988.5, 6726.5, 5065.5),
    ("boiler room 5", 6726.5, 4988.5, 6858.5, 5065.5),
    ("passage, tank top", 7292.5, 4989.5, 7389.2, 5064),
    ("boiler room 6", 7389.2, 4989.5, 7487.5, 5064),
    # The firemen's passage ("FIREMEN'S PASSAGE & PIPE TUNNEL"): its after end through the
    # forward cross bunker of boiler room 6, from its watertight door in the bunker's after
    # face (BOT: "at its after-end was closed by a watertight vertical sliding door"); then
    # through D, Nos. 3 and 2 holds, to its forward end abaft B, where it widens round the
    # feet of the two spiral stairs (BOT: "a vertical spiral staircase leading to the forward
    # end of a tunnel, immediately above the tank top").
    ("firemen's passage", 7916, 4822, 8024, 5017),
    ("firemen's passage", 8024, 4865, 9150, 4969),
    ("firemen's passage", 9150, 4822, 9214, 5020),
    # The holds' tank top either side of it (No. 3: "CARGO OR RESERVE COAL"; Nos. 2 and 1:
    # "CARGO HOLD"), out to her side lines, in steps. The plate draws no way into them on
    # the tank top: they are reached from the decks over them.
    ("No. 3 hold, tank top", 8024, 4486.7, 8285, 4865),
    ("No. 3 hold, tank top", 8285, 4528.9, 8546, 4865),
    ("No. 3 hold, tank top", 8024, 4969, 8285, 5345.2),
    ("No. 3 hold, tank top", 8285, 4969, 8546, 5296.6),
    ("No. 2 hold, tank top", 8617, 4597.7, 8883.5, 4865),
    ("No. 2 hold, tank top", 8883.5, 4651.6, 9150, 4865),
    ("No. 2 hold, tank top", 9150, 4687.8, 9214, 4822),
    ("No. 2 hold, tank top", 8617, 4969, 8883.5, 5220.8),
    ("No. 2 hold, tank top", 8883.5, 4969, 9150, 5164.7),
    ("No. 2 hold, tank top", 9150, 5020, 9214, 5131.1),
    ("No. 1 hold, tank top", 9214, 4722.0, 9394.7, 5088.2),
    ("No. 1 hold, tank top", 9394.7, 4761.7, 9575.3, 5053.4),
    ("No. 1 hold, tank top", 9575.3, 4798.1, 9756, 5016.7),
]

SOLIDS = [
    # The electric engine room: its four engines and dynamos (est. 3.5 m high: no plate of
    # these draws them in elevation), the fresh water tanks along her sides ("F.W. TANK"),
    # and M's step aft round the turbine's shaft between z -2.6 and +2.7, 1.2 m deep, a
    # block in the room's forward wall (the lay keeps M one line, at -64.87).
    ("electric engine and dynamo", 2207.5, 4791, 2445, 4888, 3.5),
    ("electric engine and dynamo", 2538, 4782.5, 2766.5, 4882.5, 3.5),
    ("electric engine and dynamo", 2212, 5010, 2446, 5108, 3.5),
    ("electric engine and dynamo", 2540, 5003, 2771, 5106, 3.5),
    ("fresh water tank", 2101, 4590.3, 2350.5, 4705, None),
    ("fresh water tank", 2350.5, 4545.7, 2628, 4705, None),
    ("fresh water tank", 2628, 4508.7, 2885.2, 4705, None),
    ("fresh water tank", 2101, 5203, 2357.5, 5293.0, None),
    ("fresh water tank", 2357.5, 5203, 2637.5, 5331.7, None),
    ("fresh water tank", 2637.5, 5203, 2885.2, 5366.3, None),
    ("recess in bulkhead M", 2840, 4842, 2885.2, 5046, None),
    # The turbine engine room, as Plate VIII draws it in plan (calibrated on M at its step,
    # L and K; its centre line; across her at its length's scale less 1.2%, as its circles
    # draw), carried here through ship metres. Heights off Plate VII's elevation where it
    # draws them: the starboard condenser's top 6.7 m over the tank top, the turbine's 6.6 m
    # where it shows past the condenser's end, the thrust blocks' 3.4 m; the rest est.
    # Plate V's own sketch of the condensers stands up to 1 m aft of Plate VIII's. The
    # circulating pumps and their engines are drawn out to Plate VIII's sides, 1-2 m wider
    # there than this view's: they stop at the room's side.
    ("main condenser", 2988.8, 4580.3, 3176.9, 4753.4, 6.7),
    ("main condenser", 2987.0, 5130.4, 3173.2, 5296.8, 6.7),
    ("low-pressure turbine and its exhausts", 3011.4, 4796.6, 3228.0, 5084.7, 6.6),
    ("turbine bearing", 2976.9, 4884.5, 3011.4, 4999.1, 2.5),
    ("turbine bearings and coupling", 3228.0, 4891.4, 3315.6, 4990.8, 2.5),
    ("change valve", 3337.2, 4799.8, 3451.5, 4899.2, 3.5),
    ("change valve", 3337.2, 4987.8, 3451.5, 5087.2, 3.5),
    ("thrust block", 3225.0, 4704.9, 3501.2, 4752.4, 3.4),
    ("thrust block", 3225.0, 5132.8, 3501.2, 5178.2, 3.4),
    ("feed tank", 3393.3, 4607.2, 3451.5, 4674.2, 2.5),
    ("feed tank", 3393.3, 5201.6, 3451.5, 5268.6, 2.5),
    ("air pump", 2987.7, 4754.8, 3033.0, 4794.8, 3.0),
    ("air pump", 3165.7, 4753.6, 3209.9, 4793.6, 3.0),
    ("air pump", 2987.7, 5088.7, 3033.0, 5128.7, 3.0),
    ("air pump", 3165.7, 5087.5, 3209.9, 5127.5, 3.0),
    ("circulating pumps", 3024.4, 4487.8, 3332.9, 4563.5, 3.0),
    ("circulating pumps", 3332.9, 4480.0, 3410.5, 4525.5, 3.0),
    ("circulating pumps", 3024.4, 5315.6, 3332.9, 5391.2, 3.0),
    ("circulating pumps", 3332.9, 5348.9, 3410.5, 5400.0, 3.0),
    ("evaporator", 2885.2, 5184.4, 2935.9, 5227.6, 3.0),
    ("evaporator", 2885.2, 5253.6, 2935.9, 5304.4, 3.0),
    ("evaporator", 2885.2, 5327.1, 2935.9, 5380.0, 3.0),
    # The reciprocating engine room, off Plate VIII the same way: the two four-cylinder
    # engines (BOT: "two sets of four-cylinder reciprocating engines"), their cylinder covers
    # 11.2 m over the tank top on Plate VII (Plate V's sketch of them within 0.2 m of these,
    # but 0.7-1 m wider inboard); in the wings the refrigerating engines (port), the
    # auxiliary pumps and the auxiliary condenser (starboard), the hotwell and main feed
    # pumps and the feed filters either side (est. heights).
    ("reciprocating engine", 3555.7, 4624.7, 4267.9, 4829.8, 11.2),
    ("reciprocating engine", 3553.0, 5048.8, 4259.5, 5250.2, 11.2),
    ("refrigerating engine", 3570.2, 4495.5, 3723.9, 4585.2, 2.5),
    ("refrigerating engine", 3738.4, 4494.3, 3917.0, 4584.0, 2.5),
    ("hotwell pumps and tank", 3941.9, 4441.3, 4066.5, 4529.9, 2.5),
    ("main feed pumps", 4070.6, 4440.1, 4294.8, 4513.6, 2.5),
    ("feed filters", 4224.3, 4532.5, 4294.8, 4599.5, 2.0),
    ("pump", 3941.9, 4564.7, 3995.9, 4601.5, 2.5),
    ("pump", 4101.7, 4565.8, 4153.7, 4600.4, 2.5),
    ("auxiliary pump", 3568.1, 5284.7, 3611.7, 5323.6, 2.5),
    ("auxiliary pump", 3661.6, 5284.1, 3705.2, 5323.0, 2.5),
    ("auxiliary pump", 3755.0, 5279.2, 3798.6, 5318.1, 2.5),
    ("auxiliary pump", 3568.1, 5386.3, 3611.7, 5423.1, 2.5),
    ("auxiliary pump", 3661.6, 5385.7, 3705.2, 5422.4, 2.5),
    ("auxiliary condenser and its pumps", 3792.4, 5343.4, 3931.5, 5449.4, 2.5),
    ("hotwell pumps and tank", 3933.6, 5342.6, 4049.8, 5439.8, 2.5),
    ("main feed pumps", 4066.5, 5363.1, 4257.5, 5438.7, 2.5),
    ("feed filters", 4222.2, 5284.6, 4294.8, 5336.5, 2.0),
    ("pump", 3910.7, 5282.5, 3946.0, 5321.4, 2.5),
    ("pump", 4035.3, 5305.3, 4118.4, 5326.9, 2.5),
    # The boilers, where this view draws them (SB-text: "twenty-four double-ended and five
    # single-ended boilers ... 15ft. 9in. diameter and 20ft. long ... 11ft. 9in. long": these
    # read 4.85 m across and 6.25 m long, the single-ended 3.5 m), five abreast but in boiler
    # room 6, four. Their shells' tops 5.6 m over the tank top, on saddles, off Plate VI's
    # elevation of boiler rooms 1 and 2 (5.6 m both); est. the same in 3-6.
    ("single-ended boiler", 4342, 4432.5, 4474, 4620, 5.6),
    ("single-ended boiler", 4342, 4644.5, 4474, 4826.5, 5.6),
    ("single-ended boiler", 4342, 4848, 4474, 5022, 5.6),
    ("single-ended boiler", 4342, 5045.5, 4474, 5230, 5.6),
    ("single-ended boiler", 4342, 5252.5, 4474, 5422, 5.6),
    ("double-ended boiler", 4920, 4430, 5155, 4617.5, 5.6),
    ("double-ended boiler", 4920, 4638.5, 5155, 4821.5, 5.6),
    ("double-ended boiler", 4920, 4843, 5155, 5014.5, 5.6),
    ("double-ended boiler", 4920, 5042, 5155, 5224.5, 5.6),
    ("double-ended boiler", 4920, 5245, 5155, 5414.5, 5.6),
    ("double-ended boiler", 5634.5, 4426.5, 5864.5, 4613.5, 5.6),
    ("double-ended boiler", 5634.5, 4634, 5864.5, 4817.5, 5.6),
    ("double-ended boiler", 5634.5, 4843.5, 5864.5, 5015, 5.6),
    ("double-ended boiler", 5634.5, 5041.5, 5864.5, 5220.5, 5.6),
    ("double-ended boiler", 5634.5, 5244, 5864.5, 5413, 5.6),
    ("double-ended boiler", 6282.5, 4420, 6511.5, 4608.5, 5.6),
    ("double-ended boiler", 6282.5, 4632, 6511.5, 4812.5, 5.6),
    ("double-ended boiler", 6282.5, 4836, 6511.5, 5010.5, 5.6),
    ("double-ended boiler", 6282.5, 5038.5, 6511.5, 5216, 5.6),
    ("double-ended boiler", 6282.5, 5238.5, 6511.5, 5410, 5.6),
    ("double-ended boiler", 6958, 4426, 7188.5, 4609, 5.6),
    ("double-ended boiler", 6958, 4631.5, 7188.5, 4811, 5.6),
    ("double-ended boiler", 6958, 4837.5, 7188.5, 5011.5, 5.6),
    ("double-ended boiler", 6958, 5040, 7188.5, 5216.5, 5.6),
    ("double-ended boiler", 6958, 5235.5, 7188.5, 5412, 5.6),
    ("double-ended boiler", 7581.5, 4517, 7815, 4699, 5.6),
    ("double-ended boiler", 7581.5, 4726.5, 7815, 4910, 5.6),
    ("double-ended boiler", 7581.5, 4931.5, 7815, 5110, 5.6),
    ("double-ended boiler", 7581.5, 5137.5, 7815, 5320, 5.6),
    # The cross bunkers' coal ("COAL"), either side of each bulkhead from J to E: nobody's
    # room. In the forward half of each, beside its passage, the ash ejectors' pump room
    # ("ASH EJ.", Plate VI's "PUMP ROOM": SB-text, "the large duplex feed pumps, placed in a
    # separate room adjoining each boiler room"), which the plate draws no way into.
    ("coal bunker", 4570, 4386.1, 4716, 5009, None),
    ("coal bunker", 4570, 5080, 4716, 5466.9, None),
    ("coal bunker", 4716, 4386.1, 4818.5, 4910, None),
    ("ash ejector pump room", 4716, 4910, 4818.5, 5009, None),
    ("coal bunker", 4716, 5080, 4818.5, 5466.9, None),
    ("coal bunker", 5257, 4381.1, 5408.4, 4996, None),
    ("coal bunker", 5257, 5074.5, 5408.4, 5466.0, None),
    ("coal bunker", 5408.4, 4381.1, 5514.5, 4902, None),
    ("ash ejector pump room", 5408.4, 4902, 5514.5, 4996, None),
    ("coal bunker", 5408.4, 5074.5, 5514.5, 5466.0, None),
    ("coal bunker", 5961, 4378.0, 6067.9, 4995, None),
    ("coal bunker", 5961, 5066, 6067.9, 5461.6, None),
    ("coal bunker", 6067.9, 4378.0, 6175.5, 4897.5, None),
    ("ash ejector pump room", 6067.9, 4897.5, 6175.5, 4995, None),
    ("coal bunker", 6067.9, 5066, 6175.5, 5461.6, None),
    ("coal bunker", 6612, 4383.7, 6726.5, 4988.5, None),
    ("coal bunker", 6612, 5065.5, 6726.5, 5442.2, None),
    ("coal bunker", 6726.5, 4383.7, 6858.5, 4896.5, None),
    ("ash ejector pump room", 6726.5, 4896.5, 6858.5, 4988.5, None),
    ("coal bunker", 6726.5, 5065.5, 6858.5, 5442.2, None),
    ("coal bunker", 7292.5, 4426.1, 7389.2, 4989.5, None),
    ("coal bunker", 7292.5, 5064, 7389.2, 5400.0, None),
    ("coal bunker", 7389.2, 4426.1, 7487.5, 4926.5, None),
    ("ash ejector pump room", 7389.2, 4926.5, 7487.5, 4989.5, None),
    ("coal bunker", 7389.2, 5064, 7487.5, 5400.0, None),
    # Boiler room 6's forward cross bunker, abaft D, either side of the firemen's passage.
    ("coal bunker", 7916, 4503.6, 8024, 4822, None),
    ("coal bunker", 7916, 5017, 8024, 5327.1, None),
    # The fresh water tank across No. 3 hold forward ("F.W. TANK"), either side of the
    # passage.
    ("fresh water tank", 8546, 4556.9, 8617, 4865, None),
    ("fresh water tank", 8546, 4969, 8617, 5264.1, None),
    # The firemen's passage's watertight sides where a hold's tank top meets it, 0.2 m of
    # steel standing in the hold, to the passage's height (est. 8 ft, as the generator has
    # it): the plate draws no door through them, and they keep deck.py from giving the holds
    # one into the passage; B the same along the passage's forward end.
    ("firemen's passage's side", 8285, 4857, 8546, 4865, 2.44),
    ("firemen's passage's side", 8285, 4969, 8546, 4977, 2.44),
    ("firemen's passage's side", 8617, 4857, 8883.5, 4865, 2.44),
    ("firemen's passage's side", 8617, 4969, 8883.5, 4977, 2.44),
    ("firemen's passage's side", 8883.5, 4857, 9150, 4865, 2.44),
    ("firemen's passage's side", 9142, 4822, 9150, 4857, 2.44),
    ("firemen's passage's side", 8883.5, 4969, 9150, 4977, 2.44),
    ("firemen's passage's side", 9142, 4977, 9150, 5020, 2.44),
    ("firemen's passage's side", 9150, 4814, 9214, 4822, 2.44),
    ("firemen's passage's side", 9150, 5020, 9214, 5028, 2.44),
    ("bulkhead B by the spiral stairs", 9214, 4822, 9222, 5020, None),
]

DOORS = [
    # The watertight doors the plate marks ("W.T.D") in O, N, M, L and K, and the gaps it
    # leaves in J, H, G, F and E where the bunkers' passages go through.
    (1469.5, 5012), (2101, 5005), (2885.2, 5104), (3515.5, 5000), (4304.5, 5040),
    (4716, 5044.5), (5408.4, 5035.25), (6067.9, 5030.5), (6726.5, 5027), (7389.2, 5026.75),
    # The bunkers' passages from the stokeholds abaft them, where the plate marks a door in
    # the bunker's face.
    (4570, 5044.5), (5257, 5035.25), (5961, 5030.5), (6612, 5027), (7292.5, 5026.75),
    # The firemen's passage: its watertight door into boiler room 6's forward stokehold, and
    # the two doors whose swings the plate draws from its after end through D into No. 3
    # hold, port and starboard (the hold's "reserve coal").
    (7916, 4935), (8024, 4843.5), (8024, 4993),
]

OPEN = [
    # The shaft tunnels' steps.
    (1017, 4892, 1023, 5027), (1242, 4852, 1248, 5074), (1677, 4746, 1683, 5175), (1887, 4689, 1893, 5216),
    # Boiler rooms 5 and 6's pieces.
    (6955, 4405, 6961, 5427), (7185, 4414, 7191, 5413), (7578, 4460, 7584, 5365), (7812, 4487, 7818, 5343),
    # Each bunker's passage into the stokehold forward of it.
    (4815.5, 5009, 4821.5, 5080), (5511.5, 4996, 5517.5, 5074.5), (6172.5, 4995, 6178.5, 5066),
    (6855.5, 4988.5, 6861.5, 5065.5), (7484.5, 4989.5, 7490.5, 5064),
    # The firemen's passage through D, as through C: the plate draws each bulkhead's line
    # across it, and the passage is one watertight tunnel to its door at its after end
    # (BOT). Then into its forward end round the spiral stairs.
    (8021, 4865, 8027, 4969), (9147, 4865, 9153, 4969),
    # The holds' steps.
    (8282, 4529, 8288, 4857), (8282, 4977, 8288, 5296), (8880, 4652, 8886, 4857), (8880, 4977, 8886, 5164),
    (9147, 4688, 9153, 4822), (9147, 5020, 9153, 5131), (9391.7, 4762, 9397.7, 5053), (9572.3, 4798, 9578.3, 5017),
]

# Her tank top has no flights down. The ladders and stairs up from it belong to the decks
# at their tops (the plate draws none of them on the tank top):
# - the firemen's spiral stairs, from the firemen's passage's forward end abaft B, their
#   feet at px 9152-9198 by 4825-4872 (port) and 4967-5014 (starboard): x 100.2-101.4,
#   z -2.1 to -0.8 and +1.6 to +2.8, up to the orlop and on to the firemen's quarters;
# - each boiler room's ladders up from its stokeholds by its bunkers' faces (Plate VI's
#   elevation: in boiler room 1 by its forward bunker, x -20.9 to -20.5; in boiler room 2
#   by its after bunker, x -14.9 to -13.5, and by its forward one, x -3.6 to -3.2), and the
#   escape ladders up the fiddleys (BOT: "direct to the Boat deck");
# - the engine rooms' ladders and gratings (BOT: "direct access to the Boat deck");
# - the escapes from the electric engine room and the after tunnels to E deck's working
#   passage (BOT), where the plate draws a small trunk on N's and O's forward faces to
#   port, px 2100-2125 by 4826-4865 (x -85.2 to -84.5, z -3.1 to -2.1) and 1462-1490 by
#   4850-4885 (x -101.9 to -101.2, z -2.6 to -1.7).
STAIRS = []
