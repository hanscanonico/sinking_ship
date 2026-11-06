"""The forecastle deck as Plate IV draws it ("Forecastle Deck", at the forward end of B
deck's row): The Shipbuilder, June 1911, leaf n318 (plates.tsv). Her gear on it, No. 1
hatch and her foremast (#381); the deck itself is laid from her hull (tools/gen_titanic.py's
FC1 and FC2).

Read in the plate's own pixels, as deck.py says. Plate IV draws the Olympic's forecastle;
no public-domain 1912 source draws the Titanic's apart from it.
"""
PLATE = "IV"
CROP = (9200, 740, 10700, 1180)

# Calibrated on its ends: its after face, the bulkhead's after line, at the generator's
# FCSL_FROM, and her stem's head on her centre line at X_FORE. Drawn 3.7% larger along her
# than B deck's view aft (b_aft.py), whose calibration carried forward stands the after
# face 0.7 m aft of FCSL_FROM and the stem 1.4 m short of X_FORE.
X = [
    (9222, 91.7856, "the after face: FCSL_FROM"),
    (10682, 130.80, "her stem's head on her centre line: X_FORE"),
]
# Her centre line through the stem's point and the middle of each pair of pieces drawn
# either side of it (the capstans, the cable holders, the hawse pipes: px 956-961); the
# dashed line the plate draws for it runs 5 px to starboard of that. Across her, B deck's
# view's scale (b_aft.py).
Z = dict(centre=((9222, 960), (10682, 960)), scale=0.025773)

# Her gear on the forecastle and its head, each where the plate draws it, to the ink's outer
# edge: the generator lays its kind's size (DeckFurniture.GEAR) on the middle of it, on the
# deck it stands on either side of the step (tools/gen_titanic.py's FC_RAMP).
GEAR = [
    # The plate's "Steam windlass" across her at the forecastle's after face, its box from
    # the face's line forward to the foremast's ring, which the plate draws hard on its
    # forward face (px 9346-9374; tools/gen_titanic.py stands her foremast's after face
    # there).
    ("steam windlass", 9222, 849, 9346, 1068),
    # Its "Steam winch" forward of the mast, its box up to No. 1 hatch's after coaming.
    ("steam winch", 9537, 913, 9680, 1019),
    # The four capstans (the special number: "The forward gear for this purpose consists of
    # four capstan drums placed on the forecastle"), each its drum's outer ring: the after
    # pair 1.4 m across, the forward pair, on the forecastle head, 1.15 m.
    ("capstan", 9862, 786, 9914, 839),
    ("capstan", 9861, 1080, 9914, 1131),
    ("capstan", 10188, 841, 10231, 885),
    ("capstan", 10183, 1031, 10226, 1076),
    # The two cable holders, each its drum's ring on its bedplate, the bedplate's box (the
    # special number: "The windlass drums, or cable holders, for winding the cables are
    # placed on the forecastle deck, as shown in Plate IV ... Each drum is mounted upon a
    # vertical spindle, which is carried down to the shelter deck"). Each side's cable leads
    # from its holder forward along the trough the plate draws to its hawse pipe, whose
    # mouth it draws at px 10336-10457 on the holder's line (ShipFittings).
    ("cable holder", 10006, 863, 10108, 948),
    ("cable holder", 10007, 971, 10109, 1058),
]

# The plate's "No 1 hatch", its coaming, over the trunk C deck's plan draws under it (c.py's
# "No. 1 hatch trunk"), its height est. as her wells' are.
SOLIDS = [
    ("No. 1 hatch", 9680, 878, 9824, 1046, 0.8),
]
