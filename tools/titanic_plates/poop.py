"""The poop deck as Plate IV draws it ("Poop Deck", at the after end of B deck's row): The
Shipbuilder, June 1911, leaf n318 (plates.tsv). Her gear on it and the docking bridge over
it (#381); the deck itself is laid from her hull (tools/gen_titanic.py's POOP_STRIPS).

Read in the plate's own pixels, as deck.py says. Plate IV draws the Olympic's poop; no
public-domain 1912 source draws the Titanic's apart from it.
"""
PLATE = "IV"
CROP = (360, 560, 1660, 1500)

# Calibrated on her ends, as C deck's view is on her stern (c.py): her stern on her centre
# line, its shell's outer line, at the generator's X_AFT; and the poop's front where C
# deck's view draws it (POOP_TO, its third-class entrance's forward wall). The view is
# drawn at B deck's scale aft (b_aft.py) within 0.4%, not longer than her poop: on b_aft.py's
# calibration carried aft, her stern reads -138.59 and the front -106.82.
X = [
    (370, -138.26, "her stern on her centre line: X_AFT"),
    (1628, -106.625, "the poop's front: POOP_TO, C deck's view's (c.py)"),
]
# The centre line as drawn, from the stern to the front (it falls 11 px over the view);
# across her, B deck's view's scale (b_aft.py).
Z = dict(centre=((520, 1048), (1350, 1037)), scale=0.025773)

# Her gear on the poop, each where the plate draws it, to the ink's outer edge: the
# generator lays its kind's size (DeckFurniture.GEAR) on the middle of it.
GEAR = [
    # The four warping capstans (the special number: "Similar warping capstans are
    # installed at the after end of the ship"), each drawn a ring 1.6 m across.
    ("capstan", 622, 849, 686, 912),
    ("capstan", 616, 1176, 680, 1239),
    ("capstan", 938, 757, 1003, 821),
    ("capstan", 930, 1259, 995, 1323),
    # The two electric cranes by her front, each drawn as its slewing ring round its
    # pedestal (B deck's view draws the after well's alike, and C deck's view and A deck's
    # plan square, 1.5 m across): the ring's box, its middle the crane's.
    ("electric crane", 1411, 679, 1560, 826),
    ("electric crane", 1419, 1249, 1571, 1396),
    # The electric winch on her centre line at her front, over its drums.
    ("electric winch", 1528, 1000, 1614, 1059),
]

# The docking bridge, dashed over her across px 808-860 (the special number: "a docking
# bridge provided right aft, for use when the vessel is docking or turning in a confined
# space"; BOT: "a light docking bridge, with telephone, telegraphs, etc."), out to her sides
# and widened forward to px 917 about her centre line. Its deck 2.625 m over the poop's (est.,
# Plate III's elevation: 100 px at 37.96 px a metre between the poop's deck line, px 1958,
# and the bridge's, px 1858, over its trestle at px 930-1037).
BRIDGES = [
    ("docking bridge", 808, None, 860, None, 2.625),
    ("docking bridge", 860, 951, 917, 1139, 2.625),
]

# Up from the poop to the docking bridge: the plate's one ladder, to starboard of her centre
# line, px 765-859 at 1195-1224 (0.75 m wide), drawn up through the bridge to its forward
# line. A body climbs no steeper than tools/gen_titanic.py's STEEPEST, so it runs on aft to
# a slope of 0.857, as steep as C deck's steepest flights (c.py), to the bridge's after edge,
# its head there, and 1.0 m wide (est.). Run on to the plate's forward line its foot would
# stand in the after starboard capstan.
STAIRS = [
    ("docking bridge ladder", 686, 1190.5, 808, 1229.3, "fore", "poop", "docking bridge"),
]
