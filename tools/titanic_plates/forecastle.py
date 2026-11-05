"""The forecastle deck as Plate IV draws it ("Forecastle Deck", at the forward end of B
deck's row): The Shipbuilder, June 1911, leaf n318 (plates.tsv). Her gear on it (#381);
the deck itself is laid from her hull (tools/gen_titanic.py's FC2).

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

# Her gear on the forecastle head, each where the plate draws it, to the ink's outer edge:
# the generator lays its kind's size (DeckFurniture.GEAR) on the middle of it.
GEAR = [
    # The two cable holders, each its drum's ring on its bedplate, the bedplate's box (the
    # special number: "The windlass drums, or cable holders, for winding the cables are
    # placed on the forecastle deck, as shown in Plate IV ... Each drum is mounted upon a
    # vertical spindle, which is carried down to the shelter deck"). Each side's cable leads
    # from its holder forward along the trough the plate draws to its hawse pipe, whose
    # mouth it draws at px 10336-10457 on the holder's line (ShipFittings).
    ("cable holder", 10006, 863, 10108, 948),
    ("cable holder", 10007, 971, 10109, 1058),
]
