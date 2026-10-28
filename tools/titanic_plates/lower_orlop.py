"""The lower orlop deck, as Plate V draws it ("Lower Orlop Dk."): The Shipbuilder, June
1911, leaf n320 (plates.tsv).

Read in the plate's own pixels, as deck.py says, as the orlop's (orlop.py). The lower
orlop is a partial deck "extending only through the forepeak and No. 1 hold" (BOT,
"Decks and Accommodation", Below G deck), and the plate draws it so: from bulkhead B to
her stem, No. 1 hold's cargo round No. 1 hatch, the peak tank forward of A. Aft of B the
view draws only her sides, running on aft a little way, and the firemen's spiral trunk
between them, the spirals passing down through it to their tunnel (orlop.py's flights).
The plate draws the Olympic; nothing in 1912 text sets the Titanic's apart here.

Its height is the lay's: Plate III's elevation draws it 84 px (2.2 m) under No. 1 hold's
orlop and 4.8 m over her tank top, No. 1 hold's orlop standing 33 px over No. 2 hold's;
her generator's orlop stands 4.75 m over her tank top, all along her.
"""
PLATE = "V"
CROP = (9060, 3990, 10300, 4530)

# Calibrated on the two bulkheads the view draws, each at tools/gen_titanic.py's
# BULKHEADS, and on her stem at this height (X_FP raked, gen_titanic.py's stem_x, for the
# 2.2 m under the orlop est. above). The view sits 28 px aft of the orlop's, at its scale
# between them (38.77 px a metre against the orlop's 38.80), so B is at BULKHEADS' 101.85
# here too: at F's and G's 99.5, B-A would be drawn 14% short. Her stem sits 90 px short
# of A's scale (forward of A the view is 17% short).
X = [
    (9261.3, 101.85, "bulkhead B"),
    (9802.5, 115.81, "bulkhead A"),
    (10236, 129.31, "her stem at the lower orlop (X_FP raked)"),
]
# The centre line, fitted to its dashes as drawn from px 9100 to 10200 (117 columns, 0.35
# px rms); across her, the orlop's scale (orlop.py): the view draws no parallel body to
# read her breadth off. Her sides' middle stands within 2 px of the drawn line.
Z = dict(centre=((9100, 4258.7), (10200, 4253.4)), scale=0.02631)

# The deck itself: B to her stem.
DECKS = [(9261.3, None, 10236, None)]

ROOMS = [
    # No. 1 hold's lower 'tween deck (the plate's "CARGO") round No. 1 hatch, in steps to
    # her narrowing sides. The orlop's hold ladder comes down into its forward part
    # (orlop.py).
    ("cargo hold", 9261.3, 4079, 9470, 4185),
    ("cargo hold", 9261.3, 4185, 9314, 4344),
    ("cargo hold", 9261.3, 4344, 9470, 4440.5),
    ("cargo hold", 9470, 4121.5, 9636, 4396.5),
    ("cargo hold", 9636, 4152.5, 9802.5, 4364),
]

SOLIDS = [
    # The firemen's spiral trunk aft of B, its spirals passing (orlop.py's flights): nobody's
    # floor at this height; No. 1 hatch, open down to the hold under it.
    ("firemen's spiral trunk", 9196.1, 4158, 9261.3, 4372, None),
    ("No. 1 hatch", 9314, 4185, 9470, 4344, None),
    # Forward of A, the forepeak tank (the plate's "PEAK TANK"), in two steps to her stem.
    ("peak tank", 9802.5, 4187, 10000, 4325, None),
    ("peak tank", 10000, 4229, 10236, 4280, None),
]

OPEN = [
    # The hold's five pieces.
    (9264, 4182, 9311, 4188), (9264, 4341, 9311, 4347), (9467, 4124, 9473, 4182), (9467, 4347, 9473, 4393),
    (9633, 4155, 9639, 4361),
]

STAIRS = [
    # The hold ladder down to the tank top, est. (orlop.py's notes): starboard of the
    # orlop's coming down, its head aft by that one's foot, 3.1 m for the 2.55 m left on
    # her generator's heights between the 2.2 m est. above and her tank top.
    ("hold ladder", 9635.5, 4301, 9756.5, 4339, "aft", "tanktop", "lower_orlop"),
]
