"""E deck, the upper deck, as Plate IV draws it ("Upper Dk E"): The Shipbuilder, June
1911, leaf n318 (plates.tsv).

Read in the plate's own pixels, as deck.py says. Where the plate and a body disagree,
the comment beside the piece says what was changed and why. The plate's doors are swings
drawn over unbroken wall lines: a door stands at its swing. A room's side against her
hull is on the hull's double line's middle at the room's middle; a long room along her
curve is cut in steps to it.

The plate draws the Olympic. The Shipbuilder vol. VI (1911-12), "The White Star Liner
Titanic", p. 224, says of the Titanic only that "on the remaining decks the number of
staterooms has been increased", and draws no plan of E deck; BOT names no change on it. So
E deck stays as the plate draws it (est. for the Titanic). Its rooms come out at the
plate's own count, which is The Shipbuilder's Table VI for E deck within a room or two a
class: first class 11 one-berth, 2 two-berth and 28 three-berth rooms (Table VI: 9, 2,
28), second class 16 two-berth and 49 four-berth (15, 49), third class 27 two-berth, 40
four-berth and 8 six-berth (26, 40, 8).

Her watertight bulkheads (BOT): K to P, A and B go up to D deck through this one; C to J
stop under it, and the view does not draw them. It draws O, N, M, L and K as heavy lines
from side to side, M's leaning to px 3066 at her port side and L stepping aft to px 3748.5
to starboard of the reciprocating engine casing; and B, stepping aft from px 9340.5 to
9300 to starboard. Rooms meet on their lines. P and A it draws as no line of their own.
The watertight doors it draws, its two triangles point to point over the line: L and K,
each in the working passage and in the starboard passage. Through M it draws a door's
swing in the working passage, and to port by the potato bin its line broken (est. a door
there). The doors BOT has that it draws no mark for are est.: O and N in the working
passage, M in the starboard passage. The gangway doors in her sides at both cross
passages (BOT) are not laid.
"""
PLATE = "IV"
CROP = (560, 4230, 10500, 5420)

# Calibrated piecewise on the watertight bulkheads the view draws, O to K, each at
# tools/gen_titanic.py's BULKHEADS, its plate x its ink's middle fitted down the view where
# the centre line crosses it (the lines lean up to 1.8% on the scan); forward of K on the
# first-class lifts and the firemen's spiral staircases, at the ship x D deck's calibration
# (d.py) gives them; and on her stem at this height (X_FP raked, gen_titanic.py's stem_x).
# Aft of O the view is read on O-N's scale: P has no line of its own here, and the walls
# where it would stand (px 1042.5 and 1050.5) read 0.4-0.6 m forward of BULKHEADS' P; the
# view's after end then reads -129.8, 0.2 m aft of her rudder post (X_AP). (gen_titanic.py's
# stern_x puts her shell 7 m further aft at this height, which the plate does not draw.)
# Checks: M read on N and L falls at -66.10, so this view draws M where BULKHEADS has it
# (-66.02; the elevation's line above F deck, -65.98), not at its step to -64.87 below F
# deck (g.py). Funnel 1's boiler casing reads 47.08-61.10 where D deck draws its casing
# with its fans and trunks at 46.98-61.20; funnel 3's fans' after side and its forward fans
# read 0.4-0.5 m forward of D deck's; D deck's grand staircase's flight comes down where the
# plate draws its treads (0.01 m); the stewards' staircase's space holds D deck's flight
# within 0.5 m. The forward second-class lift reads 0.74 m forward of A and D decks'
# (-70.11), the after second-class stairway's well 1.1-1.25 m forward of D deck's, and the
# turbine engine casing's ends 0.87 m forward and 0.44 m aft of D deck's.
# B is no control: the view draws it at 100.10 to port and 99.02 to starboard, 1.75 and
# 2.83 m aft of BULKHEADS' 101.85, where the elevation's upper line of B stands (99.38) and
# Plate V draws it (99.5, g.py); calibrated on 101.85 the firemen's spirals would stand 1.7
# m forward of D deck's. Nor is A: the trimmers' forward compartment's after wall reads
# 113.56 and the store's after wall 120.03, the latter 0.46 m off the elevation's upper line
# of A (119.57; BOT: "A extended to C deck").
X = [
    (1696.7, -101.69, "bulkhead O"),
    (2336.5, -85.14, "bulkhead N"),
    (3071.4, -66.02, "bulkhead M"),
    (3745.9, -48.63, "bulkhead L"),
    (4545.2, -27.71, "bulkhead K"),
    (6977.5, 36.58, "the first-class lifts' middle; D deck's at px 7122.25"),
    (9399.5, 101.69, "the firemen's spiral staircases' middle; D deck's at px 9549"),
    (10455, 129.60, "her stem at E deck"),
]
# The centre line, the straight line nearest every dash the view draws of it from px 770 to
# 10200 (none more than 6.6 px, 0.17 m, off it); across her, her sides' double lines'
# middles 1059.5 px apart from px 3920 to 6500 for her 92 ft moulded (half breadths there
# 13.96-14.08 m against 14.02).
Z = dict(centre=((700, 4838.4), (10300, 4780.3)), scale=0.026467)

# The deck itself: her whole length and breadth, the view's after end to her stem.
DECKS = [(610, None, 10455, None)]

ROOMS = [
    # Aft: the store in her stern, in three steps to her stern post.
    ("store, E deck", 610, 4786.5, 690, 4905.5),
    ("store, E deck", 690, 4698.5, 775, 4995),
    ("store, E deck", 775, 4639, 856.5, 5056),
    # Third class aft of bulkhead O. Port, aft to forward: rooms off short passages to
    # her side, the chief third-class steward's room (the plate's CHF 3RD ST).
    ("four-berth third-class room, E deck", 856.5, 4594.5, 936.5, 4827),
    ("four-berth third-class room, E deck", 936.5, 4560, 1014, 4792),
    ("passage, E deck", 936.5, 4792, 1014, 4827),
    ("passage, E deck", 1014, 4540, 1042.5, 4827),
    ("chief third-class steward's room, E deck", 1042.5, 4525, 1112.5, 4745),
    ("passage, E deck", 1042.5, 4745, 1117, 4827),
    ("two-berth third-class room, E deck", 1112.5, 4504, 1187, 4684.5),
    ("passage, E deck", 1187, 4491, 1216, 4684.5),
    ("four-berth third-class room, E deck", 1216, 4479, 1288.5, 4684.5),
    ("six-berth third-class room, E deck", 1288.5, 4463, 1364.5, 4684.5),
    ("passage, E deck", 1364.5, 4518, 1402, 4684.5),
    ("four-berth third-class room, E deck", 1402, 4440, 1486, 4633),
    ("two-berth third-class room, E deck", 1402, 4633, 1486, 4684.5),
    ("four-berth third-class room, E deck", 1486, 4425, 1561.5, 4598),
    ("four-berth third-class room, E deck", 1486, 4598, 1561.5, 4684.5),
    ("passage, E deck", 1561.5, 4416.5, 1595, 4684.5),
    ("four-berth third-class room, E deck", 1595, 4406, 1697, 4567),
    ("two-berth third-class room, E deck", 1595, 4567, 1697, 4627),
    ("two-berth third-class room, E deck", 1595, 4627, 1697, 4684.5),
    # Starboard, aft to forward.
    ("four-berth third-class room, E deck", 856.5, 4882, 936.5, 5098),
    ("passage, E deck", 936.5, 4882, 1018.5, 4913.5),
    ("four-berth third-class room, E deck", 936.5, 4913.5, 1018.5, 5131),
    ("passage, E deck", 1018.5, 4882, 1050.5, 5150),
    ("passage, E deck", 1050.5, 4882, 1117, 4915),
    ("four-berth third-class room, E deck", 1050.5, 4915, 1117, 4999.5),
    ("two-berth third-class room, E deck", 1050.5, 4999.5, 1121, 5166),
    ("four-berth third-class room, E deck", 1121, 4999.5, 1195.5, 5185),
    ("passage, E deck", 1195.5, 4998, 1228, 5198),
    ("six-berth third-class room, E deck", 1228, 4999, 1302, 5209),
    ("two-berth third-class room, E deck", 1302, 4999, 1375, 5060),
    ("four-berth third-class room, E deck", 1302, 5060, 1375, 5223),
    ("passage, E deck", 1375, 4998, 1412, 5233),
    ("two-berth third-class room, E deck", 1412, 4998, 1495.5, 5084),
    ("four-berth third-class room, E deck", 1412, 5084, 1495.5, 5242),
    ("two-berth third-class room, E deck", 1495.5, 4998, 1570, 5054),
    ("two-berth third-class room, E deck", 1495.5, 5054, 1570, 5122.5),
    ("four-berth third-class room, E deck", 1495.5, 5122.5, 1570, 5253.5),
    ("passage, E deck", 1570, 4996.5, 1608, 5222),
    ("two-berth third-class room, E deck", 1608, 4996.5, 1697, 5050.5),
    ("two-berth third-class room, E deck", 1608, 5050.5, 1697, 5120.5),
    ("six-berth third-class room, E deck", 1608, 5120.5, 1697, 5269),
    # The middle: the passages round the main third-class stairway (BOT: "the main third
    # class entrance for the after-end of the vessel, leading directly down to G deck"),
    # its landing, and forward of it the pantry, two rooms and No. 6 hatch.
    ("passage, E deck", 1117, 4684.5, 1198.5, 4999.5),
    ("third-class entrance, E deck", 1198.5, 4742.5, 1407.5, 4947),
    ("passage, E deck", 1198.5, 4684.5, 1697, 4742.5),
    ("passage, E deck", 1198.5, 4947, 1671, 4998),
    ("pantry, E deck", 1407.5, 4742.5, 1501, 4838),
    ("four-berth third-class room, E deck", 1407.5, 4838, 1501, 4947),
    ("four-berth third-class room, E deck", 1619.5, 4742.5, 1697, 4837),
    ("four-berth third-class room, E deck", 1619.5, 4837, 1697, 4947),
    # Between bulkheads O and N. Port, third class: four groups of rooms off short
    # passages to her side, and under the fifth and sixth a ladder down to F deck.
    ("four-berth third-class room, E deck", 1697, 4395.5, 1759.5, 4565),
    ("two-berth third-class room, E deck", 1697, 4565, 1759.5, 4636),
    ("two-berth third-class room, E deck", 1697, 4636, 1759.5, 4688),
    ("passage, E deck", 1759.5, 4389.5, 1795, 4688),
    ("four-berth third-class room, E deck", 1795, 4384, 1865, 4537.5),
    ("two-berth third-class room, E deck", 1795, 4537.5, 1865, 4598),
    ("four-berth third-class room, E deck", 1795, 4598, 1865, 4688),
    ("four-berth third-class room, E deck", 1865, 4376, 1936.5, 4513.5),
    ("four-berth third-class room, E deck", 1865, 4513.5, 1936.5, 4598),
    ("four-berth third-class room, E deck", 1865, 4598, 1936.5, 4688),
    ("passage, E deck", 1936.5, 4370.5, 1972.5, 4688),
    ("four-berth third-class room, E deck", 1972.5, 4366, 2044, 4487),
    ("two-berth third-class room, E deck", 1972.5, 4487, 2044, 4548),
    ("two-berth third-class room, E deck", 1972.5, 4548, 2044, 4603),
    ("two-berth third-class room, E deck", 1972.5, 4603, 2044, 4660),
    ("passage, E deck", 2044, 4361, 2078, 4660),
    ("four-berth third-class room, E deck", 2078, 4357, 2149.5, 4483),
    ("two-berth third-class room, E deck", 2078, 4483, 2149.5, 4545.5),
    ("two-berth third-class room, E deck", 2078, 4545.5, 2149.5, 4599),
    ("four-berth third-class room, E deck", 2149.5, 4352, 2215, 4483),
    ("two-berth third-class room, E deck", 2149.5, 4483, 2215, 4545.5),
    ("two-berth third-class room, E deck", 2149.5, 4545.5, 2215, 4599),
    ("passage, E deck", 2078, 4599, 2215, 4656),
    ("passage, E deck", 2215, 4348, 2255.5, 4660),
    ("four-berth third-class room, E deck", 2255.5, 4345, 2337, 4465),
    ("two-berth third-class room, E deck", 2255.5, 4465, 2337, 4528),
    ("two-berth third-class room, E deck", 2255.5, 4528, 2337, 4588.5),
    ("two-berth third-class room, E deck", 2255.5, 4588.5, 2337, 4660),
    # The working passage, and amidships the attendant's room, the ladies' lavatory and
    # the baths, No. 5 hatch, the after second-class stairway (BOT: "another second
    # class stairway, which gave access to C, D, E, F and G decks") in its enclosure with
    # its landing forward, and the assistant purser's office and room.
    ("passage, E deck", 1697, 4688, 1977.5, 4738.5),
    ("passage, E deck", 1977.5, 4660, 2337, 4722),
    ("attendant's room, E deck", 1697, 4738.5, 1837.5, 4801.5),
    ("ladies' lavatory, E deck", 1697, 4801.5, 1765.5, 4904),
    ("ladies' lavatory, E deck", 1697, 4904, 1727.5, 4946.5),
    ("passage, E deck", 1727.5, 4904, 1765.5, 4949),
    ("bathroom, E deck", 1765.5, 4801.5, 1837.5, 4871.5),
    ("bathroom, E deck", 1765.5, 4871.5, 1837.5, 4949),
    ("second-class entrance, E deck, aft", 1977.5, 4722, 2159, 4949),
    ("second-class entrance, E deck, aft", 2159, 4722, 2245.5, 4951),
    ("assistant purser's office, E deck", 2245.5, 4722, 2337, 4861),
    ("assistant purser's room, E deck", 2245.5, 4861, 2337, 4951),
    # Starboard, second class (the plate's SECOND CLASS from O forward): the passage,
    # the linen room (the plate's L, est.), the instrument room (IN ST, est.) and the
    # musicians' room, the purser's clerks' room (3 PURSER CLERKS), then staterooms off
    # short passages to her side.
    ("passage, E deck", 1727.5, 4949, 1980.5, 4990),
    ("passage, E deck", 1980.5, 4951, 2337, 5001),
    ("linen room, E deck", 1697, 4946.5, 1727.5, 4990),
    ("linen room, E deck", 1697, 4990, 1752.5, 5095.5),
    ("instrument room, E deck", 1752.5, 4990, 1804, 5095.5),
    ("passage, E deck", 1804, 4990, 1840.5, 5095.5),
    ("musicians' room, E deck", 1697, 5095.5, 1840.5, 5281),
    ("three-berth purser's clerks' room, E deck", 1840.5, 4990, 1980.5, 5095.5),
    ("two-berth second-class stateroom, E deck", 1840.5, 5095.5, 1980.5, 5155),
    ("two-berth second-class stateroom, E deck", 1840.5, 5155, 1880, 5290),
    ("four-berth second-class stateroom, E deck", 1880, 5155, 1980.5, 5295.5),
    ("passage, E deck", 1980.5, 5001, 2017.5, 5301),
    ("two-berth second-class stateroom, E deck", 2017.5, 5001, 2088, 5091),
    ("two-berth second-class stateroom, E deck", 2088, 5001, 2155.5, 5091),
    ("four-berth second-class stateroom, E deck", 2017.5, 5091, 2155.5, 5192),
    ("four-berth second-class stateroom, E deck", 2017.5, 5192, 2155.5, 5307),
    ("passage, E deck", 2155.5, 5001, 2191.5, 5313.5),
    ("four-berth second-class stateroom, E deck", 2191.5, 5001, 2337, 5087.5),
    ("four-berth second-class stateroom, E deck", 2191.5, 5087.5, 2337, 5186.5),
    ("four-berth second-class stateroom, E deck", 2191.5, 5186.5, 2337, 5319),
    # Between N and M. Port, third class: a store entry and No. 4 hatch's trunk, the women's
    # and men's lavatories round their W.C.s, two six-berth rooms; the after cross passage
    # (BOT: "another cross passage at the end of this accommodation about 9 ft. wide,
    # terminating in gangway doors on each side of the ship", the doors not laid), its
    # third-class half to port; the potato washing room (the plate's POTATO WASHER) and
    # the passage past the potatoes' bin through M.
    ("store entry, E deck", 2337, 4339, 2444.5, 4484),
    ("four-berth third-class room, E deck", 2337, 4550, 2444.5, 4656),
    ("passage, E deck", 2444.5, 4335.5, 2480.5, 4656),
    ("women's lavatory, E deck", 2551.5, 4328, 2629.5, 4545),
    ("women's lavatory, E deck", 2480.5, 4507, 2551.5, 4545),
    ("six-berth third-class room, E deck", 2480.5, 4545, 2594, 4656),
    ("passage, E deck", 2594, 4586.5, 2629.5, 4656),
    ("men's lavatory, E deck", 2629.5, 4324.5, 2714.5, 4545),
    ("men's lavatory, E deck", 2714.5, 4516, 2783, 4545),
    ("six-berth third-class room, E deck", 2629.5, 4545, 2740, 4656),
    ("men's lavatory, E deck", 2740, 4545, 2783, 4656),
    ("passage, E deck", 2783, 4316.5, 2894, 4656),
    ("potato washing room, E deck", 2894, 4311.5, 3066, 4457),
    ("passage, E deck", 2894, 4457, 3066, 4503),
    ("passage, E deck", 2337, 4656, 3071.5, 4716),
    # Amidships: the ladies' lavatory, a store (the plate's S) and baths, the gentlemen's
    # lavatory, three more baths; the forward second-class main stairway (BOT: "both the
    # second class main stairways were also in communication with this starboard
    # passage"), round its lift and its two flights; the cross passage's second-class
    # half through its entrance to starboard, and the two stewards' room (2 STW).
    ("ladies' lavatory, E deck", 2337, 4716, 2400.5, 4885.5),
    ("ladies' lavatory, E deck", 2400.5, 4853.5, 2472.9, 4885.5),
    ("passage, E deck", 2472.9, 4841, 2506.5, 4952),
    ("store, E deck", 2337, 4885.5, 2400.5, 4952),
    ("bathroom, E deck", 2400.5, 4885.5, 2472.9, 4952),
    ("gentlemen's lavatory, E deck", 2572, 4716, 2650.5, 4882),
    ("bathroom, E deck", 2506.5, 4882, 2572, 4952),
    ("bathroom, E deck", 2572, 4882, 2650.5, 4952),
    ("passage, E deck", 2650.5, 4748, 2680, 4952),
    ("bathroom, E deck", 2680, 4716, 2757, 4794.5),
    ("bathroom, E deck", 2680, 4794.5, 2757, 4876),
    ("bathroom, E deck", 2680, 4876, 2757, 4952),
    ("passage, E deck", 2757, 4716, 2788, 4952),
    ("second-class entrance, E deck", 2788, 4716, 3074.5, 4947),
    ("second-class entrance, E deck", 2788, 4947, 2960, 5111.5),
    ("second-class entrance, E deck", 2960, 5043.5, 3074.5, 5111.5),
    ("two-berth stewards' quarters, E deck", 2960, 4947, 3074.5, 5043.5),
    ("second-class entrance, E deck", 2794, 5111.5, 2901.5, 5341),
    # Starboard, second class: the starboard passage; a steward's room, No. 4 hatch's other
    # trunk, the store entry; staterooms off short passages to her side.
    ("passage, E deck", 2337, 4952, 2788, 5001),
    ("steward's room, E deck", 2337, 5001, 2455, 5118.5),
    ("store entry, E deck", 2337, 5174.6, 2455, 5325.5),
    ("passage, E deck", 2455, 5001, 2489.5, 5328),
    ("two-berth second-class stateroom, E deck", 2489.5, 5001, 2541, 5118.5),
    ("two-berth second-class stateroom, E deck", 2541, 5001, 2610.5, 5118.5),
    ("four-berth second-class stateroom, E deck", 2489.5, 5118.5, 2610.5, 5204),
    ("four-berth second-class stateroom, E deck", 2489.5, 5204, 2610.5, 5330.5),
    ("passage, E deck", 2610.5, 5001, 2644.5, 5333),
    ("two-berth second-class stateroom, E deck", 2644.5, 5001, 2724, 5116.5),
    ("two-berth second-class stateroom, E deck", 2724, 5001, 2788, 5116.5),
    ("four-berth second-class stateroom, E deck", 2644.5, 5116.5, 2794, 5200.5),
    ("four-berth second-class stateroom, E deck", 2644.5, 5200.5, 2794, 5336),
    ("four-berth second-class stateroom, E deck", 2901.5, 5111.5, 3041, 5201.5),
    ("four-berth second-class stateroom, E deck", 2901.5, 5201.5, 3041, 5344),
    ("passage, E deck", 3041, 5111.5, 3074.5, 5347.5),
    # Between M and L. Port, the waiters' and cooks' quarters: the musicians' (5
    # MUSICIANS) over the lobby where D deck's stair from its service lobby comes down
    # (d.py); the way through M by the potato bin, a store and a corridor down to the
    # working passage; the waiters' (16 WAITERS), the chef's and head waiter's rooms, the
    # S.R. men's (the plate's SyR MEN, est.), the bar men's, a bathroom and the waiters'
    # lavatory, six cooks' and four cooks' quarters.
    ("musicians' quarters, E deck", 3066, 4307, 3210, 4416),
    ("passage, E deck", 3066, 4416, 3210, 4452),
    ("passage, E deck", 3066, 4452, 3110, 4503),
    ("store, E deck", 3110, 4452, 3173, 4503),
    ("passage, E deck", 3173, 4452, 3210, 4634),
    ("waiters' quarters, E deck", 3210, 4303, 3351.5, 4634),
    ("chef's room, E deck", 3379, 4299.5, 3459.5, 4404),
    ("head waiter's room, E deck", 3351.5, 4404, 3459.5, 4511),
    ("head waiter's room, E deck", 3351.5, 4301, 3379, 4404),
    ("S.R. men's quarters, E deck", 3351.5, 4511, 3459.5, 4634),
    ("passage, E deck", 3459.5, 4298, 3490.5, 4634),
    ("bar men's quarters, E deck", 3490.5, 4297, 3567.5, 4417.5),
    ("bathroom, E deck", 3490.5, 4417.5, 3567.5, 4483),
    ("waiters' lavatory, E deck", 3490.5, 4483, 3567.5, 4634),
    ("cooks' quarters, E deck", 3602, 4294, 3705.5, 4423),
    ("cooks' quarters, E deck", 3567.5, 4423, 3705.5, 4520),
    ("cooks' quarters, E deck", 3567.5, 4295.5, 3602, 4423),
    ("passage, E deck", 3648.5, 4520, 3743, 4634),
    ("passage, E deck", 3705.5, 4292, 3743, 4520),
    ("passage, E deck", 3071.5, 4634, 3743, 4708.5),
    # Amidships: the way along M down to the starboard passage, where the stair up to the
    # serving space stands (BOT: "they could pass by the stairway up to the serving space
    # at the forward end of the second class saloon", d.py's); baths, a store (S) and the
    # gentlemen's lavatory off their passage; the fan store, the W.C.s, the electrical
    # store, the turbine engine casing; the second-class barber shop and four rooms.
    ("passage, E deck", 3075.5, 4708.5, 3111, 4944),
    ("passage, E deck", 3075.5, 4944, 3147.5, 5078.5),
    ("passage, E deck", 3111, 4708.5, 3144, 4802),
    ("bathroom, E deck", 3144, 4708.5, 3232.5, 4802),
    ("bathroom, E deck", 3232.5, 4708.5, 3313, 4802),
    ("gentlemen's lavatory, E deck", 3313, 4708.5, 3356.5, 4802),
    ("gentlemen's lavatory, E deck", 3290.5, 4802, 3356.5, 4940.5),
    ("passage, E deck", 3111, 4802, 3290.5, 4847.5),
    ("passage, E deck", 3111, 4847.5, 3147.5, 4944),
    ("store, E deck", 3147.5, 4847.5, 3209, 4940.5),
    ("bathroom, E deck", 3209, 4847.5, 3290.5, 4940.5),
    ("fan store, E deck", 3356.5, 4708.5, 3434.5, 4754),
    ("electrical store, E deck", 3434.5, 4708.5, 3542.5, 4940.5),
    ("second-class barber shop, E deck", 3147.5, 4940.5, 3335, 5078.5),
    ("four-berth second-class stateroom, E deck", 3335, 4940.5, 3434.5, 5078.5),
    ("four-berth second-class stateroom, E deck", 3434.5, 4940.5, 3542.5, 5078.5),
    ("four-berth second-class stateroom, E deck", 3542.5, 4940.5, 3642.5, 5078.5),
    ("four-berth second-class stateroom, E deck", 3642.5, 4940.5, 3748.5, 5078.5),
    # Starboard: the starboard passage; a ladder down to F deck along M; second-class
    # rooms off short passages, a linen locker at each one's end by her side.
    ("passage, E deck", 3075.5, 5078.5, 3748.5, 5128.5),
    ("passage, E deck", 3075.5, 5128.5, 3112.5, 5348),
    ("four-berth second-class stateroom, E deck", 3112.5, 5128.5, 3222, 5229),
    ("four-berth second-class stateroom, E deck", 3112.5, 5229, 3222, 5348.5),
    ("passage, E deck", 3222, 5128.5, 3257, 5308.5),
    ("four-berth second-class stateroom, E deck", 3257, 5128.5, 3396, 5227),
    ("four-berth second-class stateroom, E deck", 3257, 5227, 3396, 5349.5),
    ("passage, E deck", 3396, 5128.5, 3428.5, 5311.5),
    ("four-berth second-class stateroom, E deck", 3428.5, 5128.5, 3566.5, 5223),
    ("four-berth second-class stateroom, E deck", 3428.5, 5223, 3566.5, 5350.5),
    ("four-berth second-class stateroom, E deck", 3566.5, 5128.5, 3705.5, 5219.5),
    ("four-berth second-class stateroom, E deck", 3566.5, 5219.5, 3705.5, 5351.5),
    ("passage, E deck", 3705.5, 5128.5, 3748.5, 5315.5),
    # Between L and K, abreast the reciprocating engine casing. Port: the engineers'
    # office and pantry (ENG OFF, PANTRY) over a ladder down to F deck, the engineers'
    # mess (BOT: "the engineers' mess room"), the stewardesses' room (2 STW ESS), the chief
    # storekeeper's (CHIEF S.K.), the sorters' (2 SORTER) and the butcher's (BUTCHER).
    ("passage, E deck", 3745, 4291.5, 3791.5, 4474),
    ("engineers' office, E deck", 3791.5, 4290.5, 3876.3, 4420),
    ("engineers' pantry, E deck", 3876.3, 4289, 3976.5, 4420),
    ("passage, E deck", 3791.5, 4420, 3976.5, 4474),
    ("engineers' mess, E deck", 3976.5, 4286, 4313.5, 4474),
    ("stewardesses' room, E deck", 4313.5, 4284.5, 4409, 4402.5),
    ("chief storekeeper's room, E deck", 4313.5, 4402.5, 4409, 4474),
    ("passage, E deck", 4409, 4284, 4437, 4474),
    ("sorters' room, E deck", 4437, 4283, 4508.5, 4399.5),
    ("butcher's room, E deck", 4437, 4399.5, 4545, 4474),
    ("butcher's room, E deck", 4508.5, 4283, 4545, 4399.5),
    ("passage, E deck", 3745, 4474, 4545, 4557),
    # Starboard, second class (BOT: "Of the second class passengers on E deck, those
    # abreast of the reciprocating engine casing ..."): the starboard passage, pairs of
    # rooms off short passages, the inner room of each pair reaching her side past the
    # outer (an L cut in two); three bathrooms and the ladies' lavatory.
    ("passage, E deck", 3748.5, 5080, 4545, 5131),
    ("four-berth second-class stateroom, E deck", 3748.5, 5131, 3849.5, 5228),
    ("four-berth second-class stateroom, E deck", 3748.5, 5228, 3849.5, 5350.5),
    ("passage, E deck", 3849.5, 5131, 3888.5, 5311.5),
    ("four-berth second-class stateroom, E deck", 3888.5, 5131, 4027, 5228.5),
    ("four-berth second-class stateroom, E deck", 3888.5, 5228.5, 3992, 5350),
    ("four-berth second-class stateroom, E deck", 3992, 5228.5, 4027, 5350),
    ("four-berth second-class stateroom, E deck", 4027, 5131, 4162.5, 5226),
    ("four-berth second-class stateroom, E deck", 4027, 5226, 4065, 5349.5),
    ("four-berth second-class stateroom, E deck", 4065, 5226, 4162.5, 5349),
    ("passage, E deck", 4162.5, 5131, 4195.6, 5316),
    ("four-berth second-class stateroom, E deck", 4195.6, 5131, 4330.5, 5225),
    ("four-berth second-class stateroom, E deck", 4195.6, 5225, 4303.5, 5348),
    ("four-berth second-class stateroom, E deck", 4303.5, 5225, 4330.5, 5347.5),
    ("bathroom, E deck", 4330.5, 5131, 4407.5, 5203),
    ("bathroom, E deck", 4330.5, 5203, 4407.5, 5268.5),
    ("bathroom, E deck", 4330.5, 5268.5, 4407.5, 5347),
    ("passage, E deck", 4407.5, 5131, 4440.5, 5347),
    ("ladies' lavatory, E deck", 4440.5, 5131, 4545, 5207.5),
    ("ladies' lavatory, E deck", 4440.5, 5207.5, 4475.5, 5347),
    # Forward of K, abreast boiler rooms 1 and 2. Port: the chef's room and the chief
    # baker's and second chef's (CHEF, BAKER + 2ND CHEF); the storekeepers' (8 STORE
    # KEEPERS) and assistant stewards' (8 ASST STEWDS) between passages from the working
    # passage, over the enclosure of a ladder down to F deck; the stewards' lavatories
    # round their W.C.s and baths, the first-class cooks' (12 1ST C COOKS).
    ("chef's room, E deck", 4571.5, 4282, 4671.5, 4372),
    ("chief baker's and second chef's room, E deck", 4548, 4372, 4671.5, 4471.5),
    ("chief baker's and second chef's room, E deck", 4548, 4282, 4571.5, 4372),
    ("passage, E deck", 4671.5, 4281.5, 4706, 4594),
    ("storekeepers' quarters, E deck", 4706, 4281, 4797.5, 4537.5),
    ("assistant stewards' quarters, E deck", 4797.5, 4281, 4883.5, 4537.5),
    ("passage, E deck", 4706, 4537.5, 4743, 4594),
    ("ladderway, E deck", 4743, 4537.5, 4883.5, 4594),
    ("passage, E deck", 4883.5, 4281, 4921, 4594),
    ("stewards' lavatory, E deck", 4921, 4428.5, 4990, 4545.5),
    ("bathroom, E deck", 4921, 4545.5, 4990, 4594),
    ("passage, E deck", 4990, 4281.5, 5021.5, 4594),
    ("bathroom, E deck", 5021.5, 4519.5, 5100, 4594),
    ("stewards' lavatory, E deck", 5100, 4282, 5230.5, 4594),
    ("first-class cooks' quarters, E deck", 5230.5, 4281, 5354, 4594),
    ("passage, E deck", 4548, 4471.5, 4671.5, 4594),
    ("passage, E deck", 4548, 4594, 4684.5, 4640.5),
    ("passage, E deck", 4684.5, 4594, 5420, 4696.5),
    ("drying room, E deck", 5256.5, 4696.5, 5380, 4753),
    # Amidships: the storekeepers' (4 STK, est.), the engineers' stewards' (4 ENG ST), a
    # pantry and a two-berth room; the stewards' stairway's foot (BOT: "a stewards'
    # stairway, which communicated with all the decks below as far as E deck"; its flight
    # is d.py's) between them and funnel 3's boiler casing, from the working passage to
    # the starboard passage; the drying room (DRY R); a row of two-berth rooms on the
    # starboard passage.
    ("storekeepers' quarters, E deck", 4548, 4640.5, 4615, 4750),
    ("engineers' stewards' quarters, E deck", 4548, 4750, 4615, 4861),
    ("pantry, E deck", 4548, 4861, 4650, 4934),
    ("two-berth second-class stateroom, E deck", 4548, 4934, 4650, 5021),
    ("passage, E deck", 4615, 4640.5, 4684.5, 4763),
    ("passage, E deck", 4615, 4763, 4650, 4861),
    ("passage, E deck", 4650, 4763, 4684.5, 5021),
    ("two-berth second-class stateroom, E deck", 4684.5, 4929.5, 4797, 5021),
    ("two-berth second-class stateroom, E deck", 4797, 4929.5, 4903.5, 5021),
    ("two-berth second-class stateroom, E deck", 4903.5, 4929.5, 5018, 5021),
    ("two-berth second-class stateroom, E deck", 5018, 4929.5, 5128, 5021),
    ("two-berth second-class stateroom, E deck", 5128, 4929.5, 5238, 5021),
    ("two-berth second-class stateroom, E deck", 5238, 4929.5, 5343, 5021),
    # Starboard: the starboard passage, wider at K's watertight door; a store (S), and
    # pairs of rooms off short passages, the inner reaching her side past the outer; the
    # ash place (ASH PLACE) over boiler room 1.
    ("passage, E deck", 4548, 5021, 5420, 5072),
    ("passage, E deck", 4551, 5072, 4657, 5128),
    ("store, E deck", 4551, 5128, 4657, 5178),
    ("four-berth second-class stateroom, E deck", 4551, 5178, 4657, 5346.5),
    ("passage, E deck", 4657, 5072, 4689.5, 5346),
    ("four-berth second-class stateroom, E deck", 4689.5, 5072, 4818, 5176),
    ("four-berth second-class stateroom, E deck", 4689.5, 5176, 4783, 5345.5),
    ("four-berth second-class stateroom, E deck", 4783, 5176, 4818, 5346),
    ("four-berth second-class stateroom, E deck", 4818, 5072, 4960, 5176),
    ("four-berth second-class stateroom, E deck", 4818, 5176, 4851.5, 5345.5),
    ("four-berth second-class stateroom, E deck", 4851.5, 5176, 4960, 5345),
    ("passage, E deck", 4960, 5072, 4997, 5301),
    ("ash place, E deck", 4997, 5072, 5103, 5345),
    ("four-berth second-class stateroom, E deck", 5103, 5072, 5206.5, 5178.5),
    ("four-berth second-class stateroom, E deck", 5103, 5178.5, 5206.5, 5344),
    ("passage, E deck", 5206.5, 5072, 5239.5, 5302),
    ("four-berth second-class stateroom, E deck", 5239.5, 5072, 5381.5, 5173.5),
    ("four-berth second-class stateroom, E deck", 5239.5, 5173.5, 5340.5, 5343),
    ("four-berth second-class stateroom, E deck", 5340.5, 5173.5, 5381.5, 5342),
    # Forward of the ash place over boiler rooms 1 and 2 to the first-class entrance,
    # abreast boiler rooms 2-5. Port, the stewards' quarters: the first-class stewards' (24
    # 1ST C STEWDS) and assistant stewards' (20 ASST STWDS), an ash place over a fan tank
    # room (FAN TANK), the saloon waiters' (28 and 38 SALOON WAITERS, twice) round a ladder
    # down to F deck, the stewards' lavatory, the assistant stewards' (20 ASST STEW), the
    # second-class stewards' (16 2ND C STEW, and 42 - 2ND C STEWARDS) round another ladder,
    # the plate washers' (20 PLATE WASHER &C), a stewards' lavatory, and an ash place by a
    # third ladder.
    ("first-class stewards' quarters, E deck", 5354, 4280.5, 5547, 4589),
    ("assistant stewards' quarters, E deck", 5547, 4280, 5679, 4589),
    ("ash place, E deck", 5679, 4279.5, 5786, 4519.5),
    ("fan tank room, E deck", 5679, 4519.5, 5786, 4589),
    ("saloon waiters' quarters, E deck", 5786, 4279, 5976.5, 4589),
    ("saloon waiters' quarters, E deck", 5976.5, 4279, 6277.5, 4532.5),
    ("saloon waiters' quarters, E deck", 5976.5, 4532.5, 6249.5, 4589),
    ("ladderway, E deck", 6249.5, 4532.5, 6377, 4589),
    ("saloon waiters' quarters, E deck", 6277.5, 4278, 6552, 4532.5),
    ("saloon waiters' quarters, E deck", 6377, 4532.5, 6552, 4589),
    ("stewards' lavatory, E deck", 6552, 4276.5, 6683, 4580.5),
    ("bathroom, E deck", 6683, 4513, 6757, 4580.5),
    ("assistant stewards' quarters, E deck", 6757, 4273.5, 6900, 4580.5),
    ("second-class stewards' quarters, E deck", 6900, 4273.5, 7039, 4531),
    ("passage, E deck", 6900, 4531, 6952.5, 4580.5),
    ("passage, E deck", 6952.5, 4531, 7039, 4580.5),
    ("second-class stewards' quarters, E deck", 7039, 4273.5, 7318, 4580.5),
    ("plate washers' quarters, E deck", 7318, 4275, 7450.5, 4580.5),
    ("stewards' lavatory, E deck", 7450.5, 4276, 7546, 4580.5),
    ("stewards' lavatory, E deck", 7546, 4278, 7577, 4505),
    ("passage, E deck", 7546, 4505, 7640, 4580.5),
    ("passage, E deck", 7640, 4505, 7679.5, 4580.5),
    ("ash place, E deck", 7655, 4281.5, 7759.5, 4505),
    ("bathroom, E deck", 7679.5, 4505, 7759.5, 4580.5),
    # The working passage on to the forward cross passage.
    ("passage, E deck", 5420, 4589, 5487, 4696.5),
    ("passage, E deck", 5487, 4585, 8424, 4688),
    # Amidships, second class: a linen room (L), the ladies' lavatory round its W.C.s and
    # its baths, the ladderway (BOT: "at the centre line in the middle of the length of the
    # ship direct access was obtained to the third class dining rooms on the deck below by
    # means of a ladderway 20 ft. wide") open into the working passage, the gentlemen's
    # lavatory and its baths off a passage from the starboard passage, two two-berth rooms.
    ("linen room, E deck", 5380, 4696.5, 5487, 4753),
    ("ladies' lavatory, E deck", 5416, 4753, 5487, 4884),
    ("bathroom, E deck", 5343, 4851, 5424.6, 4926.5),
    ("bathroom, E deck", 5343, 4926.5, 5424.6, 5017),
    ("passage, E deck", 5424.6, 4884, 5487, 4926.5),
    ("passage, E deck", 5424.6, 4926.5, 5453, 5017),
    ("two-berth second-class stateroom, E deck", 5487, 4926.5, 5574.5, 5017),
    ("two-berth second-class stateroom, E deck", 5574.5, 4926.5, 5689.5, 5017),
    ("passage, E deck", 5487, 4688, 5684.5, 4926.5),
    ("passage, E deck", 5684.5, 4688, 5769, 4802),
    ("bathroom, E deck", 5684.5, 4802, 5769, 4884.5),
    ("gentlemen's lavatory, E deck", 5769, 4688, 5864.5, 4756.5),
    ("gentlemen's lavatory, E deck", 5769, 4756.5, 5821, 4884.5),
    ("passage, E deck", 5689.5, 4884.5, 5821, 4925.5),
    ("passage, E deck", 5689.5, 4925.5, 5719, 5017),
    ("bathroom, E deck", 5719, 4925.5, 5791, 5017),
    ("bathroom, E deck", 5821, 4848, 5897.5, 4925.5),
    ("bathroom, E deck", 5821, 4925.5, 5897.5, 5017),
    # First class forward of the door across the starboard passage: five one-berth rooms, a
    # store (S) and a pantry under funnel 2's boiler casing; the first-class main stairway's
    # foot (BOT: "the forward main first class stairway and elevators extended to this
    # deck"), its hall aft of the lifts and their landing forward of them, both open onto
    # the starboard passage (the plate's dashed line), two one-berth rooms between; the
    # ladies' lavatory, a drying room (DRY RM), baths and the steward's room (STEW) under
    # funnel 1's boiler casing, and one-berth rooms on.
    ("one-berth first-class stateroom, E deck", 5897.5, 4919, 6019.5, 5011.5),
    ("one-berth first-class stateroom, E deck", 6019.5, 4919, 6142.5, 5011.5),
    ("one-berth first-class stateroom, E deck", 6142.5, 4919, 6263, 5011.5),
    ("one-berth first-class stateroom, E deck", 6263, 4919, 6384, 5011.5),
    ("one-berth first-class stateroom, E deck", 6384, 4919, 6508.5, 5011.5),
    ("store, E deck", 6508.5, 4919, 6564.5, 5011.5),
    ("pantry, E deck", 6564.5, 4919, 6657.5, 5011.5),
    ("grand staircase, E deck", 6657.5, 4688, 6756, 5009.4),
    ("grand staircase, E deck", 6756, 4688, 6933, 4913.5),
    ("one-berth first-class stateroom, E deck", 6756, 4913.5, 6890, 5009.4),
    ("one-berth first-class stateroom, E deck", 6890, 4913.5, 7022, 5009.4),
    ("grand staircase, E deck", 7022, 4688, 7135.5, 5009.4),
    ("ladies' lavatory, E deck", 7135.5, 4688, 7190, 4890.5),
    ("drying room, E deck", 7190, 4688, 7368, 4731),
    ("passage, E deck", 7135.5, 4890.5, 7230.5, 4916),
    ("bathroom, E deck", 7135.5, 4916, 7205.5, 5007),
    ("passage, E deck", 7205.5, 4916, 7230.5, 5007),
    ("bathroom, E deck", 7230.5, 4913, 7310.5, 5007),
    ("steward's room, E deck", 7310.5, 4913, 7419, 5007),
    ("one-berth first-class stateroom, E deck", 7419, 4911, 7535, 5007),
    ("one-berth first-class stateroom, E deck", 7535, 4911, 7641, 5007),
    # Starboard: the starboard passage, a door across it at each end of funnel 2's boiler
    # casing (the plate's double lines); off short passages to her side, pairs of rooms, the
    # inner of each reaching her side past the outer's slanted end (an L cut in two): four-
    # berth second-class aft of the first door, three-berth forward of it.
    ("passage, E deck", 5420, 5017, 5897.5, 5067),
    ("passage, E deck", 5897.5, 5011.5, 6657.5, 5063),
    ("passage, E deck", 6657.5, 5009.4, 8424, 5061),
    ("four-berth second-class stateroom, E deck", 5381.5, 5067, 5524, 5172),
    ("four-berth second-class stateroom, E deck", 5420.5, 5172, 5524, 5340),
    ("four-berth second-class stateroom, E deck", 5381.5, 5172, 5420.5, 5341),
    ("passage, E deck", 5524, 5067, 5554.5, 5294.5),
    ("four-berth second-class stateroom, E deck", 5554.5, 5067, 5690.5, 5176),
    ("four-berth second-class stateroom, E deck", 5554.5, 5176, 5647.5, 5339),
    ("four-berth second-class stateroom, E deck", 5647.5, 5176, 5690.5, 5338.5),
    ("four-berth second-class stateroom, E deck", 5690.5, 5067, 5829.5, 5176),
    ("four-berth second-class stateroom, E deck", 5735, 5176, 5829.5, 5337),
    ("four-berth second-class stateroom, E deck", 5690.5, 5176, 5735, 5337.5),
    ("passage, E deck", 5829.5, 5067, 5859.5, 5287),
    ("four-berth second-class stateroom, E deck", 5859.5, 5067, 5999, 5175),
    ("four-berth second-class stateroom, E deck", 5859.5, 5175, 5962.5, 5335),
    ("four-berth second-class stateroom, E deck", 5962.5, 5175, 5999, 5334),
    ("three-berth first-class stateroom, E deck", 5999, 5063, 6138.5, 5173.5),
    ("three-berth first-class stateroom, E deck", 6044.5, 5173.5, 6138.5, 5333),
    ("three-berth first-class stateroom, E deck", 5999, 5173.5, 6044.5, 5333.5),
    ("passage, E deck", 6138.5, 5063, 6171, 5289),
    ("three-berth first-class stateroom, E deck", 6171, 5063, 6309.5, 5172),
    ("three-berth first-class stateroom, E deck", 6171, 5172, 6270, 5331),
    ("three-berth first-class stateroom, E deck", 6270, 5172, 6309.5, 5331),
    ("three-berth first-class stateroom, E deck", 6309.5, 5063, 6452.5, 5172),
    ("three-berth first-class stateroom, E deck", 6352.5, 5172, 6452.5, 5330),
    ("three-berth first-class stateroom, E deck", 6309.5, 5172, 6352.5, 5331),
    ("passage, E deck", 6452.5, 5063, 6483.5, 5286),
    ("three-berth first-class stateroom, E deck", 6483.5, 5063, 6617.5, 5172),
    ("three-berth first-class stateroom, E deck", 6483.5, 5172, 6577.5, 5328),
    ("three-berth first-class stateroom, E deck", 6577.5, 5172, 6617.5, 5327),
    ("three-berth first-class stateroom, E deck", 6617.5, 5061, 6753.5, 5170.5),
    ("three-berth first-class stateroom, E deck", 6661, 5170.5, 6753.5, 5325),
    ("three-berth first-class stateroom, E deck", 6617.5, 5170.5, 6661, 5327),
    ("passage, E deck", 6753.5, 5061, 6790, 5282),
    ("store, E deck", 6818, 5061, 6888, 5171),
    ("three-berth first-class stateroom, E deck", 6888, 5061, 7036, 5169),
    ("three-berth first-class stateroom, E deck", 6938, 5169, 7036, 5319),
    ("three-berth first-class stateroom, E deck", 6888, 5169, 6938, 5321),
    ("passage, E deck", 7036, 5061, 7072.5, 5282),
    ("three-berth first-class stateroom, E deck", 7072.5, 5061, 7217, 5168),
    ("three-berth first-class stateroom, E deck", 7072.5, 5168, 7171.5, 5317),
    ("three-berth first-class stateroom, E deck", 7171.5, 5168, 7217, 5315.5),
    ("three-berth first-class stateroom, E deck", 7217, 5061, 7354.5, 5170.5),
    ("three-berth first-class stateroom, E deck", 7258.5, 5170.5, 7354.5, 5313.5),
    ("three-berth first-class stateroom, E deck", 7217, 5170.5, 7258.5, 5315),
    ("passage, E deck", 7354.5, 5061, 7386.5, 5281),
    ("three-berth first-class stateroom, E deck", 7386.5, 5061, 7524, 5170),
    ("three-berth first-class stateroom, E deck", 7386.5, 5170, 7478.5, 5312),
    ("three-berth first-class stateroom, E deck", 7478.5, 5170, 7524, 5310.5),
    # Forward of funnel 1's boiler casing to the forward cross passage. Port, along the
    # working passage: a bath and two W.C.s, the quartermasters' (6 QUARTERMASTERS), the
    # carpenter and joiner's (CARP & JOINER), the boatswain and his mate's (BOSUN & MATE),
    # the petty officers' lavatory (P.O. LAV) and a lobby to them; then third class (the
    # plate's 3RD CLASS PERMANENT): four-, six-berth rooms either side of two passages to her
    # side, and a ladder down to F deck.
    ("bathroom, E deck", 7759.5, 4532, 7830.5, 4580.5),
    ("quartermasters' quarters, E deck", 7759.5, 4284.5, 7873, 4446),
    ("quartermasters' quarters, E deck", 7759.5, 4446, 7830.5, 4467.5),
    ("carpenter and joiner's room, E deck", 7873, 4288, 7976.5, 4417.5),
    ("petty officers' lavatory, E deck", 7830.5, 4446, 7894, 4580.5),
    ("passage, E deck", 7873, 4417.5, 7928.5, 4446),
    ("passage, E deck", 7894, 4446, 7928.5, 4580.5),
    ("boatswain and mate's room, E deck", 7928.5, 4417.5, 8043.5, 4462.5),
    ("boatswain and mate's room, E deck", 7976.5, 4292, 8043.5, 4417.5),
    ("four-berth third-class room, E deck", 7928.5, 4462.5, 8006.6, 4580.5),
    ("passage, E deck", 8006.6, 4462.5, 8118, 4497),
    ("four-berth third-class room, E deck", 8006.6, 4497, 8118, 4580.5),
    ("six-berth third-class room, E deck", 8043.5, 4296, 8118, 4462.5),
    ("passage, E deck", 8118, 4299, 8144.5, 4580.5),
    ("four-berth third-class room, E deck", 8144.5, 4302, 8215, 4462.5),
    ("four-berth third-class room, E deck", 8215, 4308, 8283.5, 4462.5),
    ("four-berth third-class room, E deck", 8144.5, 4489, 8216, 4580.5),
    ("passage, E deck", 8144.5, 4462.5, 8283.5, 4489),
    ("passage, E deck", 8283.5, 4311.5, 8312, 4580.5),
    ("six-berth third-class room, E deck", 8216, 4489, 8283.5, 4580.5),
    ("six-berth third-class room, E deck", 8312, 4317, 8424, 4458.5),
    ("passage, E deck", 8312, 4458.5, 8424, 4580.5),
    # Amidships, round funnel 1's boiler casing's forward fans: the drying room, two
    # one-berth rooms and a linen room (LR) on the starboard passage, the W.C.s and baths of
    # the gentlemen's lavatory; then a block of rooms marked 3 and 4 off a passage from the
    # working passage (est. crew's: Table VI has no three-berth third-class room), two
    # baths and the foot of D deck's stair from its starboard cross passage (d.py, not laid
    # there), and a ladder down to F deck beside a store (S) and a pantry.
    ("one-berth first-class stateroom, E deck", 7641, 4911, 7761, 5007),
    ("one-berth first-class stateroom, E deck", 7761, 4913.5, 7874.5, 5007),
    ("linen room, E deck", 7874.5, 4913.5, 7967.5, 5007),
    ("bathroom, E deck", 7967.5, 4865, 8044.5, 4938.5),
    ("bathroom, E deck", 7967.5, 4938.5, 8044.5, 5007),
    ("gentlemen's lavatory, E deck", 8038, 4682, 8140, 4838),
    ("gentlemen's lavatory, E deck", 8044.5, 4838, 8073, 5007),
    ("bathroom, E deck", 8073, 4838, 8140, 4898.5),
    ("bathroom, E deck", 8073, 4898.5, 8168, 4969.5),
    ("passage, E deck", 8073, 4969.5, 8168, 5007),
    ("three-berth room, E deck", 8140, 4682, 8279, 4776),
    ("four-berth room, E deck", 8140, 4776, 8279, 4876),
    ("passage, E deck", 8279, 4682, 8313.5, 4913.5),
    ("three-berth room, E deck", 8313.5, 4682, 8424, 4790),
    ("four-berth room, E deck", 8313.5, 4790, 8424, 4913.5),
    ("passage, E deck", 8168, 4876, 8279, 4913.5),
    ("passage, E deck", 8168, 4913.5, 8238.5, 5007),
    ("passage, E deck", 8238.5, 4913.5, 8341.5, 4957),
    ("store, E deck", 8238.5, 4957, 8341.5, 5007),
    ("pantry, E deck", 8341.5, 4913.5, 8424, 5007),
    # Starboard, first class to the cross passage: pairs of three-berth rooms off short
    # passages to her side, each inner room reaching her side past its outer one's slanted
    # end (an L cut in two), and two two-berth rooms at the forward end.
    ("three-berth first-class stateroom, E deck", 7524, 5061, 7650.5, 5169),
    ("three-berth first-class stateroom, E deck", 7524, 5169, 7560, 5310),
    ("three-berth first-class stateroom, E deck", 7560, 5169, 7650.5, 5309.5),
    ("passage, E deck", 7650.5, 5061, 7690, 5280),
    ("three-berth first-class stateroom, E deck", 7690, 5061, 7826.5, 5168.5),
    ("three-berth first-class stateroom, E deck", 7690, 5168.5, 7782, 5308),
    ("three-berth first-class stateroom, E deck", 7782, 5168.5, 7826.5, 5306),
    ("three-berth first-class stateroom, E deck", 7826.5, 5061, 7968.5, 5156.5),
    ("three-berth first-class stateroom, E deck", 7826.5, 5156.5, 7867.5, 5304.5),
    ("three-berth first-class stateroom, E deck", 7867.5, 5156.5, 7968.5, 5302),
    ("passage, E deck", 7968.5, 5061, 8004, 5275),
    ("three-berth first-class stateroom, E deck", 8004, 5057.5, 8139, 5154.5),
    ("three-berth first-class stateroom, E deck", 8004, 5154.5, 8095, 5296),
    ("three-berth first-class stateroom, E deck", 8095, 5154.5, 8139, 5292),
    ("three-berth first-class stateroom, E deck", 8139, 5057.5, 8283.5, 5152),
    ("three-berth first-class stateroom, E deck", 8139, 5152, 8185.5, 5289.5),
    ("three-berth first-class stateroom, E deck", 8185.5, 5152, 8283.5, 5285),
    ("passage, E deck", 8283.5, 5057.5, 8316, 5250),
    ("two-berth first-class stateroom, E deck", 8316, 5056, 8424, 5151),
    ("two-berth first-class stateroom, E deck", 8316, 5151, 8424, 5275),
    # The forward cross passage (BOT: "a passageway right across the ship communicating
    # directly with the ladderways leading to the decks above and below and gangway doors in
    # the ship's side. This passage was 9 ft. wide at the sides and 15 ft. at the centre"),
    # the gangway doors not laid.
    ("passage, E deck", 8424, 4325, 8526.5, 4679.5),
    ("passage, E deck", 8424, 4679.5, 8596, 4966.5),
    ("passage, E deck", 8424, 4966.5, 8524, 5268),
    # Forward of the cross passage, third class and crew. Port: the masters-at-arms' room
    # (M AT ARM), a four-berth room, the ladderway where D deck's after port ladders come
    # down (d.py) and one goes on down to F deck (BOT: "The two ladder ways at the after end
    # led to E deck on both sides and to F deck on the port side"), the men's lavatory round
    # its W.C.s and its bath, and the seamen (BOT: "Abaft this, on the port side, was
    # accommodation for 44 seamen") with their W.C.s and wash place (SEAMEN W.C.S, SEAMEN
    # W.PL).
    ("masters-at-arms' room, E deck", 8526.5, 4333, 8601, 4508),
    ("four-berth third-class room, E deck", 8601, 4340, 8668, 4508),
    ("passage, E deck", 8526.5, 4508, 8668, 4628),
    ("passage, E deck", 8668, 4543, 8698, 4628),
    ("men's lavatory, E deck", 8668, 4348.5, 8769, 4543),
    ("men's lavatory, E deck", 8698, 4543, 8769, 4628),
    ("passage, E deck", 8526.5, 4628, 8769, 4679.5),
    ("bathroom, E deck", 8769, 4628, 8836.5, 4679.5),
    ("seamen's quarters, E deck", 8836.5, 4368, 8932, 4679),
    ("seamen's quarters, E deck", 8932, 4381, 9028, 4679),
    ("seamen's quarters, E deck", 9028, 4402.5, 9191, 4679),
    ("seamen's lavatory, E deck", 9191, 4430, 9313, 4583.5),
    ("seamen's wash place, E deck", 9191, 4583.5, 9313, 4673.5),
    # Amidships: the bunker hatch, a passage along it to three rooms (4, 2, 4), No. 2 hatch,
    # passages round four more rooms (4, 2, 2, 4) and a fifth (4), and the lobby aft of
    # bulkhead B where D deck's crew's ladder comes down (d.py); then the passage along the
    # hatches, and the landing round the forward starboard ladderway (BOT: "one, the
    # starboard, led to E deck and continued to F deck as a double ladder") and a four-berth
    # room.
    ("passage, E deck", 8727.5, 4679.5, 8757.5, 4914),
    ("four-berth third-class room, E deck", 8757.5, 4679.5, 8836, 4770),
    ("two-berth third-class room, E deck", 8757.5, 4770, 8836, 4833),
    ("four-berth third-class room, E deck", 8757.5, 4833, 8836, 4914),
    ("passage, E deck", 9028, 4679, 9340.5, 4709),
    ("passage, E deck", 9028, 4709, 9205.5, 4789.5),
    ("passage, E deck", 9028, 4789.5, 9061.5, 4914),
    ("four-berth third-class room, E deck", 9061.5, 4789.5, 9132, 4912.5),
    ("two-berth third-class room, E deck", 9132, 4789.5, 9205.5, 4854.5),
    ("two-berth third-class room, E deck", 9132, 4854.5, 9205.5, 4912.5),
    ("four-berth third-class room, E deck", 9205.5, 4709, 9292.5, 4798),
    ("passage, E deck", 9292.5, 4709, 9340.5, 4817),
    ("passage, E deck", 9205.5, 4798, 9243.5, 4916.5),
    ("passage, E deck", 9243.5, 4798, 9292.5, 4817),
    ("four-berth third-class room, E deck", 9243.5, 4817, 9340.5, 4916.5),
    ("passage, E deck", 8596, 4914, 9300, 4964),
    ("passage, E deck", 8996, 4964, 9300, 5064),
    ("four-berth third-class room, E deck", 9061, 5064, 9177, 5178.5),
    ("passage, E deck", 9177, 5064, 9300, 5153.5),
    # Starboard: the ladderway where D deck's after starboard ladders come down (d.py), a bar
    # (BAR), the women's lavatory round its W.C.s, the men's.
    ("passage, E deck", 8524, 4966.5, 8627, 5084),
    ("bar, E deck", 8524, 5084, 8627, 5257),
    ("women's lavatory, E deck", 8627, 4966.5, 8768.5, 5242.5),
    ("men's lavatory, E deck", 8899, 4964, 8996, 5069),
    ("men's lavatory, E deck", 8899, 5069, 9033, 5206.5),
    # Forward of bulkhead B, the firemen's (BOT: "On each side of the middle line immediately
    # abaft the firemen's quarters there was a vertical spiral staircase", on D deck; here
    # their foot): the firemen's wash place round a store (S), the landing round the two
    # spiral staircases, the firemen's W.C.s (FIREMEN'S W.C.); then the trimmers (BOT: "At
    # the forward end was provided accommodation for three watches of trimmers, in three
    # separate compartments, each holding 24 trimmers"), port and starboard either side of
    # No. 1 hatch and a passage forward to the third, and the store in her eyes.
    ("firemen's wash place, E deck", 9340.5, 4461, 9459, 4605),
    ("firemen's wash place, E deck", 9397, 4605, 9459, 4680),
    ("passage, E deck", 9459, 4478, 9486, 4680),
    ("store, E deck", 9340.5, 4605, 9397, 4680),
    ("passage, E deck", 9340.5, 4680, 9486, 4912),
    ("firemen's W.C.s, E deck", 9300, 4912, 9453, 5120),
    ("trimmers' quarters, E deck", 9486, 4498.5, 9620, 4712),
    ("trimmers' quarters, E deck", 9620, 4533.5, 9734, 4712),
    ("trimmers' quarters, E deck", 9734, 4567, 9848.5, 4712),
    ("trimmers' quarters, E deck", 9620, 4712, 9848.5, 4765),
    ("passage, E deck", 9620, 4765, 9848.5, 4794),
    ("passage, E deck", 9620, 4794, 9656, 4912),
    ("passage, E deck", 9486, 4872, 9620, 4912),
    ("trimmers' quarters, E deck", 9656, 4794, 9848.5, 4912),
    ("trimmers' quarters, E deck", 9483.5, 4912, 9656, 5068),
    ("trimmers' quarters, E deck", 9656, 4912, 9752, 5028),
    ("trimmers' quarters, E deck", 9752, 4912, 9848.5, 4999),
    ("trimmers' quarters, E deck", 9848.5, 4604.5, 9970, 4965.5),
    ("trimmers' quarters, E deck", 9970, 4644.5, 10093, 4929.5),
    ("store, E deck", 10093, 4686.5, 10215, 4890.5),
    ("store, E deck", 10215, 4728, 10335, 4851.5),
    ("store, E deck", 10335, 4761, 10455, 4813),
]
SOLIDS = [
    # Aft: a trunk along her middle line (est. the steering gear's: the plate's box of five),
    # a closet at a passage's end by her side, No. 6 hatch.
    ("trunk", 821, 4832, 856.5, 4876, None),
    ("trunk", 856.5, 4827, 1117, 4882, None),
    ("closet", 1364.5, 4456, 1402, 4518, None),
    ("closet", 1570, 5222, 1608, 5256, None),
    ("No. 6 hatch", 1501, 4742.5, 1619.5, 4947, None),
    # Between O and N: the closet aft of O by the starboard passage's end; No. 5 hatch;
    # the after second-class stairway's well between its flights, behind its balustrades
    # (est. 1 m).
    ("closet", 1671, 4947, 1697, 4996.5, None),
    ("No. 5 hatch", 1837.5, 4738.5, 1977.5, 4949, None),
    ("stairwell", 2080, 4798.5, 2152, 4875, 1.0),
    # Between N and M: No. 4 hatch's trunks; the W.C.s of the lavatories and their linen
    # lockers (the plate's L); the potatoes' bin (POTATOES), across M as the plate draws
    # it; the forward second-class lift; a closet in the steward's room.
    ("No. 4 hatch", 2337, 4484, 2444.5, 4550, None),
    ("No. 4 hatch", 2337, 5118.5, 2455, 5174.6, None),
    ("W.C.s", 2480.5, 4338, 2551.5, 4507, None),
    ("linen locker", 2594, 4545, 2629.5, 4586.5, None),
    ("W.C.s", 2714.5, 4326, 2783, 4516, None),
    ("potatoes", 2894, 4503, 3071.5, 4652, None),
    ("potatoes", 3071.5, 4503, 3137.5, 4634, None),
    ("locker", 3137.5, 4503, 3173, 4572, None),
    ("locker", 3137.5, 4572, 3173, 4634, None),
    ("W.C.s", 2400.5, 4716, 2472.9, 4853.5, None),
    ("linen locker", 2472.9, 4716, 2506.5, 4782.5, None),
    ("linen locker", 2472.9, 4782.5, 2506.5, 4841, None),
    ("W.C.s", 2506.5, 4716, 2572, 4882, None),
    ("linen locker", 2650.5, 4716, 2680, 4748, None),
    ("second-class lift", 2897, 4801.5, 2988, 4866.5, None),
    ("closet", 2428.5, 5001, 2455, 5067, None),
    # Between M and L: a closet between the waiters' and the bar men's; the waiters'
    # lavatory's W.C.s; the W.C.s by the fan store; the turbine engine casing (BOT: "the
    # turbine engine hatch"); a trunk between it and L; the linen lockers at the starboard
    # passages' ends.
    ("W.C.s", 3567.5, 4520, 3648.5, 4634, None),
    ("W.C.s", 3356.5, 4754, 3434.5, 4940.5, None),
    ("turbine engine casing", 3542.5, 4708.5, 3706, 4940.5, None),
    ("trunk", 3706, 4708.5, 3745.5, 4940.5, None),
    ("linen locker", 3222, 5308.5, 3257, 5342, None),
    ("linen locker", 3396, 5311.5, 3428.5, 5345, None),
    ("linen locker", 3705.5, 5315.5, 3748.5, 5352, None),
    # Between L and K: the reciprocating engine casing, its after wall stepping aft of L
    # where a ladder goes down into the engine room from the starboard passage (not laid);
    # the linen lockers at the short passages' ends; the ladies' lavatory's W.C.s.
    ("reciprocating engine casing", 3745, 4557, 4545, 4935, None),
    ("reciprocating engine casing", 3748.5, 4935, 4545, 5080, None),
    ("linen locker", 3849.5, 5311.5, 3888.5, 5349, None),
    ("linen locker", 4162.5, 5316, 4195.6, 5349, None),
    ("W.C.s", 4475.5, 5207.5, 4545, 5352, None),
    # Forward of K: the stewards' lavatories' W.C.s; funnel 3's boiler casing (the
    # plate's BOILER CASING) between its fans and trunks (V, FAN, TR, V); the linen
    # lockers at the short passages' ends.
    ("W.C.s", 4921, 4275, 4990, 4428.5, None),
    ("W.C.s", 5021.5, 4284, 5100, 4519.5, None),
    ("fans and trunks", 4684.5, 4696.5, 4745, 4929.5, None),
    ("boiler casing", 4745, 4696.5, 5256.5, 4929.5, None),
    ("fans and trunks", 5256.5, 4753, 5343, 4929.5, None),
    ("linen locker", 4960, 5301, 4997, 5343, None),
    ("linen locker", 5206.5, 5302, 5239.5, 5340, None),
    # Forward of K's section: the boiler rooms' escapes (BOT: "From each boiler room an
    # escape or emergency ladder was provided direct to the Boat deck by the fidleys, in the
    # boiler casings, and also into the working passage on E deck"): est., the ladders the
    # plate draws in the two ash places, in the room between the saloon waiters' and in the
    # lobby by the forward ash place, standing at bulkheads H, G and E and over no floor
    # F deck's plate draws (f.py: a boiler casing, a void), so trunks down to the stokeholds
    # no body climbs, as solids; the stewards' lavatories' W.C.s; amidships the ladies' and
    # gentlemen's W.C.s, a linen locker (L), a closet; funnel 2's boiler casing between its
    # fans and trunks; the first-class lifts; funnel 1's boiler casing's after fans and the
    # W.C.s beside them; at her side the linen lockers at the short passages' ends, and a
    # trunk with a ladder in it beside the store (est.: the plate labels neither).
    ("escape trunk", 5687, 4355, 5713.5, 4411, None),
    ("escape trunk", 7662.5, 4338, 7686, 4409, None),
    ("escape trunk", 6283, 4532.5, 6377, 4589, None),
    ("escape trunk", 7546, 4542.5, 7640, 4580.5, None),
    ("W.C.s", 6683, 4280, 6757, 4513, None),
    ("W.C.s", 7577, 4285, 7655, 4505, None),
    ("W.C.s", 5343, 4753, 5416, 4851, None),
    ("linen locker", 5453, 4926.5, 5487, 5017, None),
    ("W.C.s", 5821, 4756.5, 5897.5, 4848, None),
    ("closet", 5791, 4925.5, 5821, 5017, None),
    ("fans and trunks", 5897.5, 4735.5, 5975, 4919, None),
    ("boiler casing", 5975, 4688, 6572.5, 4919, None),
    ("fans and trunks", 6572.5, 4688, 6657.5, 4919, None),
    ("first-class lifts", 6933, 4688, 7022, 4913.5, None),
    ("W.C.s", 7190, 4731, 7266.5, 4890.5, None),
    ("fans and trunks", 7266.5, 4731, 7368, 4913, None),
    ("linen locker", 5524, 5294.5, 5554.5, 5330, None),
    ("linen locker", 5829.5, 5287, 5859.5, 5326, None),
    ("linen locker", 6138.5, 5289, 6171, 5323, None),
    ("linen locker", 6452.5, 5286, 6483.5, 5320, None),
    ("linen locker", 6753.5, 5282, 6790, 5316, None),
    ("trunk", 6790, 5061, 6818, 5171, None),
    ("trunk", 6790, 5171, 6888, 5316, None),
    ("linen locker", 7036, 5282, 7072.5, 5313, None),
    ("linen locker", 7354.5, 5281, 7386.5, 5309, None),
    # Funnel 1's boiler casing (the plate's BOILER CASING), its forward fans and trunks (FAN,
    # TR) and the drying room over them (DRY RM, 0.9 m deep at its forward end), the
    # gentlemen's lavatory's W.C.s; at her side the linen lockers at the short passages' ends.
    ("boiler casing", 7368, 4682, 7889.5, 4913, None),
    ("drying room", 7889.5, 4682, 8038, 4715, None),
    ("fans and trunks", 7889.5, 4715, 7967.5, 4913.5, None),
    ("W.C.s", 7967.5, 4715, 8038, 4865, None),
    ("W.C.s", 7759.5, 4467.5, 7830.5, 4532, None),
    ("linen locker", 7650.5, 5280, 7690, 5306, None),
    ("linen locker", 7968.5, 5275, 8004, 5296, None),
    ("linen locker", 8283.5, 5250, 8316, 5278, None),
    # Forward of the cross passage: the men's lavatory's W.C.s; the bunker hatch and No. 2
    # hatch (their covers on G deck; their trunks up through E deck to D); the women's and
    # men's W.C.s; the strip between the men's lavatory and the four-berth room, narrower
    # than a body; a trunk between the firemen's W.C.s and the trimmers; No. 1 hatch; a
    # trunk in the store.
    ("W.C.s", 8769, 4358.5, 8836.5, 4628, None),
    ("bunker hatch", 8596, 4679.5, 8727.5, 4914, None),
    ("No. 2 hatch", 8836, 4679.5, 9028, 4914, None),
    ("W.C.s", 8768.5, 4966, 8899, 5214, None),
    ("closet", 9033, 5064, 9061, 5187, None),
    ("trunk", 9453, 4912, 9483.5, 5098, None),
    ("No. 1 hatch", 9486, 4712, 9620, 4872, None),
    ("trunk", 10093, 4766, 10134.5, 4816, None),
]
DOORS = [
    # The stern store, from the room forward of it (est.: the plate draws no door into it).
    (856.5, 4760),
    # Through her bulkheads, where BOT has doors the plate draws no swing for (est.): the
    # working passage through O and N (BOT: "From the after end of this cross passage main
    # alleyways on each side of the ship ran right through to the after end of the vessel";
    # "The third class passengers at the after-end of the ship passed up their stairway to E
    # deck, and into the working passage, and through the emergency doors to the two second
    # class stairways"), and the starboard passage through M (BOT: "could pass through M
    # watertight bulkhead to the forward second class main stairway").
    (1697, 4713), (2337, 4689), (3073, 5103),
    # Aft: the third-class rooms off their passages, as their swings stand.
    (936.5, 4805), (1014, 4750), (1100, 4745), (936.5, 4895), (1018.5, 4955), (1187, 4655),
    (1216, 4650), (1364.5, 4648), (1402, 4585), (1402, 4650), (1561.5, 4545), (1561.5, 4640),
    (1195.5, 5048), (1228, 5048), (1375, 5043), (1375, 5109), (1412, 5048), (1412, 5132),
    (1570, 5028), (1570, 5097), (1570, 5178), (1608, 5043), (1608, 5109), (1608, 5178),
    # Between O and N, port: the rooms off their passages, as their swings stand.
    (1759.5, 4515), (1759.5, 4590), (1759.5, 4655), (1795, 4490), (1795, 4565), (1795, 4630),
    (1936.5, 4465), (1936.5, 4545), (1936.5, 4630), (2044, 4448), (2044, 4510), (2044, 4565),
    (2044, 4625), (2078, 4436), (2078, 4510), (2078, 4565), (2215, 4448), (2215, 4510),
    (2215, 4565), (2255.5, 4432), (2255.5, 4490), (2255.5, 4550), (2255.5, 4620),
    # The attendant's room from the working passage, the ladies' lavatory and the bathroom
    # from it, the lavatory into the passage beside it, and the linen room from that
    # passage (est.: the plate draws none of their swings); the landing from the working
    # passage, the assistant purser's
    # office from the landing.
    (1767, 4738.5), (1730, 4801.5), (1800, 4801.5), (1727.5, 4925), (1727.5, 4968),
    (2190, 4722), (2245.5, 4838),
    # Starboard: the linen room through the instrument room (est.), the instrument room,
    # the musicians' and the purser's clerks' rooms off their passage; the staterooms off
    # theirs.
    (1752.5, 5040), (1804, 5044), (1815, 5095.5), (1840.5, 5025), (1980.5, 5133),
    (1980.5, 5190), (2155.5, 5046), (2155.5, 5119), (2155.5, 5223), (2191.5, 5040),
    (2191.5, 5123), (2191.5, 5218),
    # Between N and M: the store entry, the rooms and the potato washing room off their
    # passages; the door dividing the cross passage's halves (BOT: "A door divided the
    # parts"), the plate's cross at the working passage; the stewards' room; the steward's
    # room and the staterooms to starboard.
    (2444.5, 4445), (2420, 4656), (2594, 4625), (2629.5, 4625), (2894, 4440), (2840, 4716),
    (3055, 5043.5), (2390, 5001), (2489.5, 5030), (2610.5, 5040), (2610.5, 5150),
    (2610.5, 5240), (2644.5, 5030), (2756, 5001), (2644.5, 5150), (2644.5, 5240), (3041, 5150),
    (2901.5, 5250),
    # Between M and L: the store (est.), the chef's, head waiter's and S.R. men's rooms, the
    # waiters' lavatory and the cooks' off their passages; the door through M in the
    # working passage, the plate's swing, and the one through M to port where the plate
    # breaks M's line by the potato bin (est.: it draws no swing); the barber shop and
    # the rooms off the starboard passage and their short passages.
    (3110, 4478), (3066, 4480), (3459.5, 4370), (3459.5, 4450), (3459.5, 4555), (3530, 4634),
    (3705.5, 4383), (3705.5, 4470), (3071.5, 4672), (3160, 5078.5), (3350, 5078.5),
    (3450, 5078.5), (3555, 5078.5), (3655, 5078.5), (3222, 5180), (3222, 5262), (3257, 5180),
    (3257, 5262), (3428.5, 5160), (3428.5, 5262), (3705.5, 5170), (3705.5, 5255),
    # Bulkheads L and K's watertight doors, the plate's crosses: in the working passage
    # and the starboard passage, each.
    (3745, 4540), (3748.5, 5112), (4545, 4520), (4545, 5106),
    # Between L and K: the ladder's space from the passage along L; the engineers' pantry
    # into their mess, the mess onto the working passage; the rooms off the short passage;
    # the second-class rooms off theirs.
    (3791.5, 4447), (3976.5, 4395), (3995, 4474), (4409, 4350), (4409, 4445), (4437, 4370),
    (4437, 4440), (3849.5, 5180), (3849.5, 5280), (3888.5, 5180), (3888.5, 5280),
    (4162.5, 5180), (4162.5, 5280), (4195.6, 5180), (4195.6, 5280),
    # Forward of K: the storekeepers' and the assistant stewards' from the passages either
    # side (est.: the plate draws neither swing); the ladder's enclosure from aft, its swing;
    # the two-berth rooms on the starboard passage; the starboard rooms off their passages.
    (4706, 4480), (4883.5, 4480), (4743, 4558), (4565, 5021), (4785, 5021), (4890, 5021),
    (5005, 5021), (5115, 5021), (5225, 5021), (5330, 5021), (4657, 5225), (4689.5, 5100),
    (4689.5, 5210), (4960, 5110), (4960, 5215), (5206.5, 5110), (5206.5, 5215), (5239.5, 5110),
    (5239.5, 5215),
    # Forward of K's section, port: the stewards', waiters' and lavatories' doors onto the
    # working passage, as their swings stand; the fan tank room's, and the ash place's from
    # it (est.); the second-class stewards' (16) down into the ladder's lobby; the ash place's
    # and the bath's from the lobby by the third ladder (est.).
    (6268, 4589), (5430, 4589), (5624, 4589), (5724, 4589), (5740, 4519.5), (5865, 4589),
    (6106, 4589), (6465, 4589), (6650, 4580.5), (6720, 4580.5), (6813, 4580.5), (6925, 4531),
    (7135, 4580.5), (7387, 4580.5), (7500, 4580.5), (7660, 4580.5), (7667, 4505),
    (7679.5, 4545),
    # Amidships: the lavatories into their passages; the two-berth rooms onto the starboard
    # passage; the bath and the gentlemen's lavatory into their lobby; the emergency door
    # from the working passage into the first-class stairway's hall (BOT: "through the
    # emergency door to the forward first class main stairway"), its swing; the ladies'
    # lavatory forward from the lifts' landing.
    (5452, 4884), (5498, 5017), (5590, 5017), (5729, 4884.5), (5788, 4884.5), (6693, 4688),
    (7135.5, 4743), (7170, 4916),
    # The one-berth rooms, the store and the pantry onto the starboard passage, as their
    # swings stand; the steward's room's.
    (5912, 5011.5), (6038, 5011.5), (6159, 5011.5), (6280, 5011.5), (6402, 5011.5),
    (6522, 5011.5), (6596, 5011.5), (6770, 5009.4), (6905, 5009.4), (7330, 5007), (7435, 5007),
    (7550, 5007),
    # The doors across the starboard passage (the plate's double lines).
    (5897.5, 5040), (6657.5, 5036),
    # Starboard: the rooms off their short passages; the store from the starboard passage.
    (5524, 5120), (5524, 5240), (5554.5, 5120), (5554.5, 5240), (5829.5, 5120), (5829.5, 5240),
    (5859.5, 5120), (5859.5, 5240), (6138.5, 5110), (6138.5, 5235), (6171, 5110), (6171, 5235),
    (6452.5, 5110), (6452.5, 5235), (6483.5, 5110), (6483.5, 5235), (6753.5, 5110),
    (6753.5, 5235), (6830, 5061), (7036, 5110), (7036, 5230), (7072.5, 5110), (7072.5, 5230),
    (7354.5, 5110), (7354.5, 5230), (7386.5, 5110), (7386.5, 5230),
    # Forward of funnel 1's casing, port: the bath and the petty officers' lavatory onto the
    # working passage, the quartermasters' and carpenter's into the lobby, the boatswain's
    # from it, the lobby onto the working passage; the third-class rooms off their passages;
    # the ladderway's head from the cross passage.
    (7795, 4580.5), (7860, 4580.5), (7873, 4432), (7915, 4417.5), (7928.5, 4440),
    (7910, 4580.5), (8006.6, 4480), (8118, 4540), (8118, 4410), (8144.5, 4410), (8144.5, 4520),
    (8283.5, 4410), (8312, 4410), (8283.5, 4530), (8240, 4462.5),
    # Amidships: the one-berth rooms and the linen room onto the starboard passage, the baths
    # into the lavatory's passage, the bath forward of it into the lavatory; the rooms marked
    # 3 and 4 off their passage; the store and the pantry onto the starboard passage.
    (7650, 5007), (7775, 5007), (7955, 5007), (8044.5, 4900), (8044.5, 4975), (8073, 4870),
    (8073, 4935), (8279, 4740), (8279, 4850), (8313.5, 4700), (8313.5, 4880), (8300, 5007),
    (8395, 5007),
    # Starboard: the pairs' rooms off their short passages, and the two-berth rooms off the
    # last one.
    (7650.5, 5115), (7650.5, 5240), (7690, 5115), (7690, 5240), (7968.5, 5115), (7968.5, 5235),
    (8004, 5100), (8004, 5240), (8283.5, 5110), (8283.5, 5230), (8316, 5100), (8316, 5215),
    # Forward of the cross passage, port: the masters-at-arms' room from the cross passage,
    # the four-berth room into the ladderway (est.); the men's lavatory and its bath onto the
    # passage under them; the seamen's (est.: the plate's swing stands over No. 2 hatch's
    # coaming), their W.C.s from their wash place and the wash place onto the passage along
    # them.
    (8526.5, 4466), (8640, 4508), (8735, 4628), (8769, 4662), (9110, 4679), (9250, 4583.5),
    (9205, 4673.5),
    # Amidships: the three rooms off their passage by the bunker hatch, the four rooms off
    # theirs, the room by bulkhead B, the four-berth room by the starboard ladderway (est.:
    # its swing stands at its corner).
    (8757.5, 4705), (8757.5, 4805), (8757.5, 4880), (9061.5, 4850), (9205.5, 4822),
    (9205.5, 4885), (9205.5, 4750), (9243.5, 4865), (9177, 5085),
    # Starboard: the women's lavatory from the ladderway, the bar from the cross passage, the
    # men's lavatory onto the landing.
    (8627, 5050), (8524, 5110), (8996, 5030),
    # Forward of bulkhead B: the wash place and the W.C.s onto the landing, the store from the
    # wash place (est.); the trimmers' doors, aft to forward; the store in her eyes (est.).
    (9436, 4672), (9436, 4912), (9397, 4640), (9486, 4653), (9656, 4900), (9848.5, 4779),
    (10093, 4740),
]
OPEN = [
    # The stern store's steps.
    (684, 4786.5, 696, 4905.5), (769, 4698.5, 781, 4995),
    # Aft: the passages round the stern rooms into each other and into the stairway's.
    (1002, 4792, 1014, 4827), (1036.5, 4745, 1048.5, 4827), (1111, 4745, 1123, 4827),
    (1012.5, 4882, 1024.5, 4913.5), (1044.5, 4882, 1056.5, 4915), (1111, 4882, 1123, 4915),
    (1183.5, 4742.5, 1195.5, 4947), (1183.5, 4684.5, 1195.5, 4742.5),
    (1183.5, 4955, 1195.5, 4990), (1200, 4678.5, 1214, 4690.5), (1188, 4681, 1197, 4688),
    (1364.5, 4678.5, 1402, 4690.5), (1561.5, 4678.5, 1595, 4690.5), (1195.5, 4992, 1228, 5004),
    (1375, 4992, 1412, 5004), (1570, 4992, 1608, 5004), (1198.5, 4736.5, 1407.5, 4748.5),
    (1198.5, 4941, 1407.5, 4953),
    # Between O and N: the short passages into the working passage, and the ladder's
    # space into its passage; the working passage's two pieces; the ladies' lavatory's
    # two; the stairway's enclosure into its landing, and the landing into the starboard
    # passage; the starboard passage's two pieces and its stub; the linen room's two and
    # the stateroom's two.
    (1759.5, 4682, 1795, 4694), (1936.5, 4682, 1972.5, 4694), (2044, 4654, 2078, 4666),
    (2215, 4654, 2255.5, 4666), (2209, 4599, 2221, 4656), (1971.5, 4688, 1983.5, 4722),
    (1703, 4899, 1722, 4911), (2153, 4722, 2165, 4949), (2159, 4945, 2245.5, 4957),
    (1974.5, 4951, 1986.5, 4990), (1804, 4984, 1840.5, 4996), (1980.5, 4995, 2017.5, 5007),
    (2155.5, 4995, 2191.5, 5007), (1703, 4984, 1722, 4996), (1846, 5149, 1874, 5161),
    (1727.5, 4943, 1765.5, 4955),
    # Between N and M: the passages into the working passage, the cross passage's third-
    # class half into it and the passage past the potatoes; the lavatories' pieces; the
    # ladies' lavatory into its passage and the passages into the starboard passage; the
    # second-class entrance's pieces, into the starboard passage and the way to her side.
    (2444.5, 4650, 2480.5, 4662), (2594, 4650, 2629.5, 4662), (2783, 4650, 2894, 4662),
    (2888, 4457, 2900, 4503), (2545.5, 4507, 2557.5, 4545), (2708.5, 4516, 2720.5, 4545),
    (2740, 4539, 2783, 4551), (2394.5, 4853.5, 2406.5, 4885.5),
    (2466.9, 4853.5, 2478.9, 4885.5), (2472.9, 4946, 2506.5, 4958), (2650.5, 4939, 2680, 4951),
    (2790, 4716, 2802, 4952), (2800, 4941, 2948, 4953), (2954, 5043.5, 2966, 5111.5),
    (2794, 5105.5, 2901.5, 5117.5), (2790, 4952, 2802, 5001), (3041, 5105.5, 3074.5, 5117.5),
    (2455, 4995, 2489.5, 5007), (2610.5, 4995, 2644.5, 5007),
    # Between M and L: the stair's lobby into the band through M and the corridor, the
    # corridor into the working passage; the head waiter's
    # and cooks' pieces; the passages into the working passage; the way along M and the
    # baths' passage; the gentlemen's lavatory's pieces; the starboard passages.
    (3072, 4446, 3104, 4458), (3173, 4446, 3210, 4458), (3173, 4628, 3210, 4640),
    (3357.5, 4404, 3373.5, 4416), (3567.5, 4417, 3602, 4429), (3459.5, 4628, 3490.5, 4640),
    (3648.5, 4628, 3743, 4640), (3705.5, 4514, 3743, 4526), (3075.5, 4938, 3111, 4950),
    (3111, 4841.5, 3143, 4853.5), (3111, 4938, 3147.5, 4950), (3105, 4708.5, 3117, 4802),
    (3105, 4802, 3117, 4847.5), (3111, 4796, 3144, 4808), (3313, 4796, 3356.5, 4808),
    (3075.5, 5072.5, 3147.5, 5084.5), (3075.5, 5122.5, 3112.5, 5134.5),
    (3222, 5122.5, 3257, 5134.5), (3396, 5122.5, 3428.5, 5134.5),
    (3705.5, 5122.5, 3748.5, 5134.5),
    # Between L and K: the passages into the working passage; the butcher's pieces; the
    # inner rooms' reaches; the short passages into the starboard passage.
    (3745, 4468, 3791.5, 4480), (3791.5, 4468, 3976.5, 4480), (4409, 4468, 4437, 4480),
    (4508.5, 4393.5, 4545, 4405.5), (3998, 5222.5, 4021, 5234.5), (4033, 5220, 4059, 5232),
    (4309.5, 5219, 4324.5, 5231), (4446.5, 5201.5, 4469.5, 5213.5),
    (3849.5, 5125, 3888.5, 5137), (4162.5, 5125, 4195.6, 5137), (4407.5, 5125, 4440.5, 5137),
    # Forward of K: the chief baker's two pieces; the passages into the working passage;
    # the working passage's two pieces and the stewards' stairway's foot into both and
    # into the starboard passage; the starboard passage's pieces; the inner rooms' reaches.
    (4552, 4366, 4568, 4378), (4661, 4471.5, 4673, 4594), (4560, 4588, 4660, 4600),
    (4710, 4588, 4739, 4600), (4887, 4588, 4917, 4600), (4990, 4588, 5021.5, 4600),
    (4687, 4594, 4699, 4640.5), (4687, 4648, 4699, 4690), (4615, 4634.5, 4684.5, 4646.5),
    (4650, 4757, 4684.5, 4769), (4615, 4757, 4650, 4769), (4644, 4763, 4656, 4861),
    (4650, 5023, 4684.5, 5035), (4551, 5066, 4657, 5078), (4657, 5066, 4689.5, 5078),
    (4960, 5066, 4997, 5078), (5206.5, 5066, 5239.5, 5078), (4789, 5170, 4812, 5182),
    (4824, 5170, 4845.5, 5182), (5346.5, 5167.5, 5375.5, 5179.5),
    # Forward of K's section: the waiters' rooms' two pieces round the ladder; the second-
    # class stewards' ladder and lobby into the working passage; the third ladder's space
    # into its lobby and the working passage; the
    # stewards' lavatory's strip; the working passage's two pieces at 5420.
    (5976.5, 4526.5, 6249.5, 4538.5), (6377, 4526.5, 6552, 4538.5),
    (6905, 4574.5, 6948, 4586.5), (6957, 4574.5, 7034, 4586.5), (6946.5, 4531, 6958.5, 4580.5),
    (7634, 4505, 7646, 4580.5), (7546, 4574.5, 7640, 4586.5), (7540, 4280, 7552, 4505),
    (5414, 4600, 5426, 4680), (5481, 4600, 5493, 4680),
    # Amidships: the ladderway's landing into the working passage and its two pieces; the
    # lavatories' passages into the starboard passage; the gentlemen's lavatory's two pieces.
    (5487, 4689.5, 5769, 4701.5), (5678.5, 4688, 5690.5, 4802), (5424.6, 4920.5, 5453, 4932.5),
    (5424.6, 5019, 5453, 5031), (5689.5, 4919.5, 5719, 4931.5), (5689.5, 5011, 5719, 5023),
    (5769, 4750.5, 5821, 4762.5),
    # The first-class stairway's hall, its landing and the lifts' landing onto the starboard
    # passage; the ladies' lavatory's passage into it.
    (6750, 4688, 6762, 4913.5), (6657.5, 5011, 6756, 5023), (7022, 5003.4, 7135.5, 5015.4),
    (7205.5, 4918, 7230.5, 4930), (7205.5, 5001, 7230.5, 5013),
    # Starboard: the passage's pieces at 5420; the short passages into the starboard passage;
    # each inner room's two pieces.
    (5414, 5021, 5426, 5067), (5524, 5061, 5554.5, 5073), (5829.5, 5061, 5859.5, 5073),
    (6138.5, 5057, 6171, 5069), (6452.5, 5057, 6483.5, 5069), (6753.5, 5055, 6790, 5067),
    (7036, 5055, 7072.5, 5067), (7354.5, 5055, 7386.5, 5067), (5381.5, 5166, 5420.5, 5178),
    (5647.5, 5170, 5690.5, 5182), (5690.5, 5170, 5735, 5182), (5962.5, 5169, 5999, 5181),
    (5999, 5167.5, 6044.5, 5179.5), (6270, 5166, 6309.5, 5178), (6309.5, 5166, 6352.5, 5178),
    (6577.5, 5166, 6617.5, 5178), (6617.5, 5164.5, 6661, 5176.5), (6888, 5163, 6938, 5175),
    (7171.5, 5162, 7217, 5174), (7217, 5164.5, 7258.5, 5176.5), (7478.5, 5164, 7524, 5176),
    # Forward of funnel 1's casing: the quartermasters' and the boatswain's two pieces; the
    # passages' mouths onto the working passage; the third-class lobby into its passage; the
    # ladderway onto the working passage and the cross passage.
    (7759.5, 4440, 7830.5, 4452), (7900, 4440, 7922, 4452), (7980, 4404, 8040, 4416),
    (8118, 4574.5, 8144.5, 4586.5), (8283.5, 4574.5, 8312, 4586.5), (8103, 4462.5, 8115, 4497),
    (8320, 4574.5, 8416, 4586.5), (8418, 4470, 8430, 4570), (8144.5, 4491, 8283.5, 4503),
    (8277.5, 4462.5, 8289.5, 4489),
    # Amidships: the gentlemen's lavatory's two pieces and its passage onto the starboard
    # passage; the rooms' passage onto the working passage; the ladderway's landing onto the
    # starboard passage and into the ladderway; D deck's stair's alcove onto it.
    (8044.5, 4832, 8073, 4844), (8044.5, 5001, 8073, 5013), (8279, 4668, 8313.5, 4680),
    (8168, 5001, 8238.5, 5013), (8175, 4907.5, 8232, 4919.5), (8273, 4882, 8285, 4908),
    (8232.5, 4913.5, 8244.5, 4957), (8073, 5001, 8168, 5013),
    # Starboard: the inner rooms' two pieces each; the short passages onto the starboard
    # passage; the starboard and working passages and the middle into the cross passage.
    (7524, 5163, 7560, 5175), (7782, 5162.5, 7826.5, 5174.5), (7826.5, 5150.5, 7867.5, 5162.5),
    (8095, 5148.5, 8139, 5160.5), (8139, 5146, 8185.5, 5158), (7650.5, 5055, 7690, 5067),
    (7968.5, 5055, 8004, 5067), (8283.5, 5051.5, 8316, 5063.5), (8418, 5009.4, 8430, 5061),
    (8418, 4585, 8430, 4688),
    # Forward of the cross passage: the cross passage's three pieces; the port ladderway into
    # the cross passage and onto the passage under it, its two pieces, that passage into the
    # cross passage and the passage by the bunker hatch; the passages round the rooms ahead
    # of No. 2 hatch, the ladderway by bulkhead B onto them; the passage along the hatches
    # into the cross passage and the passages off it; the starboard landing's pieces; the
    # starboard ladderway into the cross passage and onto the passage along the hatches.
    (8424, 4673.5, 8526.5, 4685.5), (8424, 4960.5, 8524, 4972.5), (8520.5, 4515, 8532.5, 4620),
    (8520.5, 4635, 8532.5, 4672), (8526.5, 4622, 8698, 4634), (8654, 4543, 8666, 4628),
    (8526.5, 4673.5, 8596, 4685.5), (8727.5, 4666, 8757.5, 4678), (9028, 4703, 9205.5, 4715),
    (9028, 4783.5, 9061.5, 4795.5), (9292.5, 4703, 9340.5, 4715), (9237.5, 4798, 9249.5, 4817),
    (9286.5, 4798, 9298.5, 4817), (8590, 4914, 8602, 4964), (8727.5, 4908, 8757.5, 4920),
    (9028, 4908, 9061.5, 4920), (9205.5, 4910.5, 9243.5, 4922.5), (8996, 4958, 9300, 4970),
    (9177, 5058, 9300, 5070), (8518, 4966.5, 8530, 5084), (8524, 4960.5, 8596, 4972.5),
    # Forward of bulkhead B: the landing into the passages round No. 1 hatch, those
    # passages into each other; the trimmers' rooms' two pieces each.
    (9488, 4872, 9500, 4912), (9614, 4872, 9626, 4912), (9620, 4788, 9656, 4800),
    (9626, 4706, 9728, 4718), (9740, 4706, 9842, 4718), (9662, 4906, 9746, 4918),
    (9758, 4906, 9842, 4918), (9614, 4540, 9626, 4705), (9728, 4572, 9740, 4705),
    (9650, 4918, 9662, 5022), (9746, 4918, 9758, 4993), (8926, 4386, 8938, 4673),
    (9022, 4408, 9034, 4673), (9459, 4661, 9486, 4673),
    # The wash place's two pieces; the third trimmers' room's two; the store's steps.
    (9397, 4599, 9459, 4611), (9964, 4650, 9976, 4925), (10209, 4732, 10221, 4847),
    (10329, 4765, 10341, 4809),
]
STAIRS = [
    # Every flight E deck's plate draws down to F deck, stern to stem. A flight the plate
    # draws steeper than a body climbs runs on at one end to STEEPEST's slope with a margin
    # (118-120 px, 3.1 m, for F to E's 2.6 m); which way each rises is est. but where said.
    # The flights the plate draws coming down from D deck are d.py's: its main third-class,
    # second-class and grand staircases, its stairs from the service lobby, the serving
    # space, the port entrance (the plate's ladder by the second-class stewards' rooms) and
    # the starboard cross passage's bay, the stewards' staircase, the firemen's spirals, its
    # crew's ladder and the open space's after ladderways.
    #
    # The main third-class stairway (BOT: "The effective width of this stairway was 16 ft.
    # to E deck. From E to F it was 8 ft. wide"): the plate draws four lanes of treads, 120
    # px (3.1 m). D deck's flight comes down the port lane (d.py), so this one takes the two
    # starboard lanes, 2.3 m clear of F deck's flight down to G (f.py), rising aft as D's
    # does.
    ("third-class stairway", 1195.5, 4857, 1318.5, 4943.5, "aft", "f", "e"),
    # A ladder under the fifth and sixth groups of rooms between O and N: its 85 px of treads
    # (2.2 m) run on 35 px forward, its head at the passage's mouth.
    ("ladder", 2078, 4602, 2201, 4656, "fore", "f", "e"),
    # The after second-class stairway's flight down to F deck: the starboard one of the
    # plate's two, D deck's coming down the port one (d.py), rising aft as the flights above
    # do; its 72 px of treads (1.9 m) run on 48 px aft over the landing.
    ("second-class stairway", 2029, 4877, 2152, 4949, "aft", "f", "e"),
    # The forward second-class staircase's flight down to F deck: the starboard one, D deck's
    # coming down to port of the lift (d.py); its 55 px of treads run on 65 px aft into the
    # entrance, rising aft.
    ("second-class staircase", 2840, 4875, 2960, 4947, "aft", "f", "e"),
    # A ladder in the potato washing room's corner, 60 px of treads run on 58 px aft to its
    # head by the room's door (est.: down to F deck).
    ("ladder", 2945, 4420, 3066, 4457, "aft", "f", "e"),
    # A ladder athwart her in the passage along M to starboard, as the plate draws it: 85 px
    # run on 35 px inboard to its head at the starboard passage.
    ("ladder", 3075.5, 5128.5, 3112.5, 5248.5, "port", "f", "e"),
    # The ladder under the engineers' office and pantry down to their accommodation on F
    # deck alongside the reciprocating engine casing (BOT): 94 px run on 26 px aft.
    ("ladder", 3806, 4428, 3926, 4464, "aft", "f", "e"),
    # The ladder in its enclosure under the storekeepers' and assistant stewards' rooms
    # forward of K, its head aft by the enclosure's door: 95 px run on 23 px aft over the
    # landing the plate draws.
    ("ladder", 4765.5, 4537.5, 4883.5, 4578, "aft", "f", "e"),
    # The ladderway 20 ft wide down to the third-class dining rooms on F deck (BOT: "In this
    # passage at the centre line in the middle of the length of the ship direct access was
    # obtained to the third class dining rooms on the deck below by means of a ladderway 20
    # ft. wide"): the plate's four ladders side by side, 233.5 px (6.2 m) across, rising aft
    # to their landing; their 115 px of rungs run on 3 px aft.
    ("third-class ladderway", 5560.5, 4693, 5681.5, 4926.5, "aft", "f", "e"),
    # The ladders the plate draws between the saloon waiters' rooms and in the lobby by the
    # forward ash place are the boiler rooms' escapes (SOLIDS); the second-class stewards'
    # lobby's is D deck's stair from its port entrance (d.py).
    # Two ladders among the rooms forward of funnel 1's casing: to port, 106 px (2.8 m) run on
    # 12 px forward to its head at the cross passage; to starboard beside the store, 103 px
    # run on 15 px aft to its head at the landing.
    ("ladder", 8312, 4513.5, 8430, 4580.5, "fore", "f", "e"),
    ("ladder", 8223.5, 4913.5, 8341.5, 4957, "aft", "f", "e"),
    # The port after ladderway's ladder on down to F deck (BOT: "The two ladder ways at the
    # after end led to E deck on both sides and to F deck on the port side"): the one the plate
    # draws over D deck's two (d.py), 4 ft, its 65 px run on 53 px aft, rising fore.
    ("third-class ladder", 8526.5, 4555, 8644.5, 4625, "fore", "f", "e"),
    # The forward starboard ladderway's double ladder (BOT: "one, the starboard, led to E deck
    # and continued to F deck as a double ladder"), as the plate draws it, its 96 px run on
    # 22 px, rising fore.
    ("third-class ladder", 9090, 4986, 9208, 5060, "fore", "f", "e"),
    # The firemen's spiral staircases on down toward their tunnel (BOT: "a vertical spiral
    # staircase leading to the forward end of a tunnel"): a spiral has no run a body climbs,
    # and D deck's straight flights come down over the plate's two spirals (d.py), so the way
    # on down is one straight flight between them, 47 px (1.25 m) wide, its head aft by their
    # feet.
    ("firemen's spiral staircase", 9351, 4757, 9469, 4804, "aft", "f", "e"),
]
