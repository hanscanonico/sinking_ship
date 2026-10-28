"""D deck, the saloon deck, as Plate IV draws it ("Saloon Dk D"): The Shipbuilder, June
1911, leaf n318 (plates.tsv).

Read in the plate's own pixels, as deck.py says. Where the plate and a body disagree,
the comment beside the piece says what was changed and why.

The plate draws the Olympic. The Titanic's D deck differed little (The Shipbuilder, vol.
VI, 1912, "The White Star Liner Titanic", p. 224: "on the saloon deck D the reception room
has been enlarged, while additional seating accommodation has been provided in the
first-class dining saloon, so that over 550 passengers can dine at the same time"): the
article draws neither, so both rooms stay as the plate draws them, and the larger
reception room is not laid (est.).

The plate's doors are swings drawn over unbroken wall lines: a door stands at its swing.
A room's side against her hull is on the hull's double line's middle at the room's middle.
"""
PLATE = "IV"
CROP = (430, 2935, 10625, 4095)

# Calibrated piecewise on what stacks deck to deck, at the ship x A deck's calibration
# (a.py) gives it — the two lift wells and the reciprocating engine casing, which A, C and
# D decks draw alike (C deck at the same px as this view) — and on her ends: the view's
# after end on her stern (tools/gen_titanic.py's X_AFT), its forward end on her stem at
# this height (X_FP raked, gen_titanic.py's stem_x). The view's scale grows forward, 3%
# from aft of the casing to forward of the lifts, as E deck's bow is short of its
# bulkheads' scale (#360). So the turbine engine casing, the stewards' staircase and
# funnel 3's casing's after end stack with C deck's (c.py) within 0.1 m. The walls over
# watertight bulkheads P, O and M (BULKHEADS) come out within 0.25 m: the third-class
# entrance's after wall, the second-class cross passage's middle, the second-class dining
# saloon's forward wall. BOT's lengths come out to a foot or so (the galley 45 ft for 45,
# the pantry 57 for 56, the dining saloon 115 for The Shipbuilder's 114, the reception
# room 54 for its 54). Her funnel casings forward are drawn larger here than on A and C
# decks, their middles up to 0.75 m off A deck's (funnel 2's after end 1.2 m aft, funnel
# 3's forward end 1 m forward), as the plate draws them: they are no control. Aft of the
# lift the view is read on her stern, as C deck's is (c.py) and B deck's after end on the
# elevation (b_aft.py), never on the mainmast's ring, which this view does not draw.
# Unlike theirs, this view is not drawn larger aft of the lift than forward of it: its
# stern stands 84 px forward of C deck's view's. So the after second-class stairway's
# well reads 0.5 m aft of B deck's (b_aft.py); calibrated to stack with it, her stern
# would stand 1.4 m short of X_AFT and the wall over bulkhead P 1.2 m off it.
X = [
    (464, -138.26, "her stern, the hull's double line's middle"),
    (3074, -70.11, "the second-class lift's middle; A deck's at px 3087.5 on Plate III"),
    (4543.5, -31.93, "the reciprocating engine casing's middle; A deck's at 4536.5, C deck's at 4543.5"),
    (7122.25, 36.58, "the first-class lifts' middle; A deck's at px 7125"),
    (10592, 129.68, "her stem at D deck, the double line's middle"),
]
# The centre line, fitted to it as drawn from px 500 to 10500 (2.5 px rms); across her,
# her sides' double lines' middles 1072.9 px apart from px 4000 to 6700 for her 92 ft
# moulded.
Z = dict(centre=((600, 3556.0), (10400, 3468.3)), scale=0.026136)

# The deck itself: her whole length and breadth, stern to stem.
DECKS = [(464, None, 10592, None)]

ROOMS = [
    # Aft: a store in her stern, unlabelled on the plate (E deck's under it is the plate's
    # STORE), in three steps to her counter, entered from the six-berth room forward of it.
    ("store, D deck", 480, 3318, 600, 3769),
    ("store, D deck", 600, 3253, 680, 3840),
    ("store, D deck", 680, 3222, 745.5, 3874),
    # Third class (BOT: "From here to the stern was accommodation for third class
    # passengers and the main third class lavatories"): seven six-berth and four two-berth
    # rooms (The Shipbuilder's Table VI: 4 two-berth, 7 six-berth, 50 passengers), off a
    # centre passage and the narrow passages either side of the forward ones.
    ("six-berth third-class room, D deck", 745.5, 3194, 880, 3502.5),
    ("six-berth third-class room, D deck", 745.5, 3502.5, 880, 3596.5),
    ("six-berth third-class room, D deck", 745.5, 3596.5, 880, 3903.5),
    ("passage, D deck", 880, 3175, 905.5, 3495),
    ("passage, D deck", 880, 3611, 914.5, 3923),
    ("six-berth third-class room, D deck", 905.5, 3165, 986, 3436),
    ("six-berth third-class room, D deck", 986, 3152, 1062, 3436),
    ("two-berth third-class room, D deck", 905.5, 3436, 986, 3495),
    ("two-berth third-class room, D deck", 986, 3436, 1062, 3495),
    ("two-berth third-class room, D deck", 914.5, 3611, 993.5, 3673),
    ("two-berth third-class room, D deck", 993.5, 3611, 1068, 3673),
    ("six-berth third-class room, D deck", 914.5, 3673, 993.5, 3935.5),
    ("six-berth third-class room, D deck", 993.5, 3673, 1068, 3948),
    ("passage, D deck", 1062, 3143.5, 1093, 3495),
    ("passage, D deck", 1068, 3611, 1098, 3957),
    ("passage, D deck", 880, 3495, 1093, 3611),
    ("passage, D deck", 1093, 3528, 1207.5, 3569),
    ("bathroom, D deck", 1093, 3459, 1207.5, 3528),
    ("bathroom, D deck", 1098, 3569, 1207.5, 3646.5),
    # The main third-class lavatories either side of the third-class entrance, each round
    # its W.C.s; outboard of them forward the second-class gentlemen's and ladies'
    # lavatories and baths, entered from the second-class passages.
    ("third-class men's lavatory", 1093, 3127.5, 1286, 3355),
    ("third-class men's lavatory", 1093, 3355, 1207.5, 3459),
    ("third-class women's lavatory", 1098, 3747, 1295, 3972),
    ("third-class women's lavatory", 1098, 3646.5, 1207.5, 3747),
    ("gentlemen's lavatory, D deck", 1420.5, 3099.5, 1488, 3305),
    ("gentlemen's lavatory, D deck", 1420.5, 3305, 1562.5, 3355),
    ("bathroom, D deck", 1488, 3093, 1562.5, 3219),
    ("bathroom, D deck", 1488, 3219, 1562.5, 3305),
    ("ladies' lavatory, D deck", 1430, 3778, 1499.5, 3935),
    ("ladies' lavatory, D deck", 1430, 3747, 1575.5, 3778),
    ("bathroom, D deck", 1499.5, 3778, 1575.5, 3857),
    ("bathroom, D deck", 1499.5, 3857, 1575.5, 4002.5),
    # The main third-class entrance (BOT: "the main third class entrance for the
    # after-end of the vessel, leading directly down to G deck ... The effective width of
    # this stairway was 16 ft. to E deck"), and forward of it the third-class matron's room
    # (the plate's "3rd C. MAT^S RM", est. matron's) and surgery, entered from it.
    ("third-class entrance", 1207.5, 3355, 1540, 3747),
    ("third-class matron's room", 1540, 3441, 1637.5, 3546.5),
    ("third-class surgery", 1540, 3546.5, 1637.5, 3661.5),
    # Second class (BOT: "In the next 88 ft. of length there were 38 second class rooms
    # and the necessary baths and lavatories"): the plate draws 39, as The Shipbuilder's
    # Table VI counts them (19 two-berth, 20 four-berth, 118 passengers). Along each side,
    # short passages off the corridor to her hull with rooms either side, an outer room at
    # her hull and an inner one reaching her hull past its end (an L cut in two), a row of
    # small rooms on the corridor; four rooms either side of a cross passage between the
    # corridors, over bulkhead O. Port, aft to forward:
    ("passage, D deck", 1562.5, 3088.5, 1594, 3391),
    ("four-berth second-class stateroom, D deck", 1594, 3084.5, 1693.5, 3241.5),
    ("bathroom, D deck", 1594, 3241.5, 1693.5, 3315),
    ("bathroom, D deck", 1594, 3315, 1693.5, 3391),
    ("passage, D deck", 1693.5, 3080.5, 1729.5, 3391),
    ("two-berth second-class stateroom, D deck", 1729.5, 3077, 1823.5, 3198.5),
    ("four-berth second-class stateroom, D deck", 1729.5, 3198.5, 1862.5, 3292),
    ("four-berth second-class stateroom, D deck", 1823.5, 3071, 1862.5, 3198.5),
    ("four-berth second-class stateroom, D deck", 1899, 3064.5, 1996.5, 3191.5),
    ("four-berth second-class stateroom, D deck", 1862.5, 3191.5, 1996.5, 3292),
    ("four-berth second-class stateroom, D deck", 1862.5, 3068, 1899, 3191.5),
    ("two-berth second-class stateroom, D deck", 1729.5, 3292, 1822.5, 3391),
    ("two-berth second-class stateroom, D deck", 1822.5, 3292, 1910.5, 3391),
    ("two-berth second-class stateroom, D deck", 1910.5, 3292, 1996.5, 3391),
    ("passage, D deck", 1996.5, 3060, 2032.5, 3391),
    ("four-berth second-class stateroom, D deck", 2032.5, 3056.5, 2135.5, 3185.5),
    ("four-berth second-class stateroom, D deck", 2032.5, 3185.5, 2173.5, 3278.5),
    ("four-berth second-class stateroom, D deck", 2135.5, 3053, 2173.5, 3185.5),
    ("four-berth second-class stateroom, D deck", 2208.5, 3048.5, 2315, 3178.5),
    ("four-berth second-class stateroom, D deck", 2173.5, 3178.5, 2315, 3278.5),
    ("four-berth second-class stateroom, D deck", 2173.5, 3051, 2208.5, 3178.5),
    ("two-berth second-class stateroom, D deck", 2032.5, 3278.5, 2129.5, 3375.5),
    ("two-berth second-class stateroom, D deck", 2129.5, 3278.5, 2222.5, 3375.5),
    ("two-berth second-class stateroom, D deck", 2222.5, 3278.5, 2315, 3375.5),
    ("passage, D deck", 2315, 3088.5, 2350, 3375.5),
    ("four-berth second-class stateroom, D deck", 2350, 3039.5, 2457.5, 3174),
    ("two-berth second-class stateroom, D deck", 2350, 3174, 2457.5, 3254),
    # A room 1.2 m wide marked L (est. linen) by the saloon's after wall, each side.
    ("room marked L", 2350, 3290, 2398.5, 3375.5),
    # Starboard, aft to forward.
    ("passage, D deck", 1575.5, 3716, 1607, 4006),
    ("two-berth second-class stateroom, D deck", 1607, 3716, 1707.5, 3786.5),
    ("bathroom, D deck", 1607, 3786.5, 1707.5, 3861),
    ("four-berth second-class stateroom, D deck", 1607, 3861, 1707.5, 4010.5),
    ("passage, D deck", 1707.5, 3716, 1743, 4014),
    ("two-berth second-class stateroom, D deck", 1743, 3716, 1831.5, 3813),
    ("two-berth second-class stateroom, D deck", 1831.5, 3716, 1920.5, 3813),
    ("two-berth second-class stateroom, D deck", 1920.5, 3716, 2010, 3813),
    ("four-berth second-class stateroom, D deck", 1743, 3813, 1879.5, 3903.5),
    ("four-berth second-class stateroom, D deck", 1844, 3903.5, 1879.5, 4021),
    ("two-berth second-class stateroom, D deck", 1743, 3903.5, 1844, 4017.5),
    ("four-berth second-class stateroom, D deck", 1879.5, 3813, 2010, 3903.5),
    ("four-berth second-class stateroom, D deck", 1879.5, 3903.5, 1913.5, 4022.5),
    ("four-berth second-class stateroom, D deck", 1913.5, 3903.5, 2010, 4025),
    ("passage, D deck", 2010, 3716, 2049.5, 4028),
    ("two-berth second-class stateroom, D deck", 2049.5, 3716, 2131.5, 3811),
    ("two-berth second-class stateroom, D deck", 2131.5, 3716, 2232, 3811),
    ("two-berth second-class stateroom, D deck", 2232, 3716, 2324, 3811),
    ("four-berth second-class stateroom, D deck", 2049.5, 3811, 2183, 3908),
    ("four-berth second-class stateroom, D deck", 2153.5, 3908, 2183, 4034.5),
    ("four-berth second-class stateroom, D deck", 2049.5, 3908, 2153.5, 4031),
    ("four-berth second-class stateroom, D deck", 2183, 3811, 2324, 3908),
    ("four-berth second-class stateroom, D deck", 2183, 3908, 2229.5, 4036),
    ("four-berth second-class stateroom, D deck", 2229.5, 3908, 2324, 4038.5),
    ("passage, D deck", 2324, 3716, 2357.5, 4002),
    ("room marked L", 2357.5, 3716, 2398.5, 3832.5),
    ("two-berth second-class stateroom, D deck", 2357.5, 3832.5, 2469.5, 3908),
    ("four-berth second-class stateroom, D deck", 2357.5, 3908, 2469.5, 4044),
    # Amidships, either side of the cross passage over bulkhead O; No. 6 and No. 5
    # hatches' trunks aft and forward of them.
    ("four-berth second-class stateroom, D deck", 1750.5, 3441, 1846, 3543),
    ("two-berth second-class stateroom, D deck", 1750.5, 3569, 1846, 3661.5),
    ("passage, D deck", 1846, 3441, 1875, 3661.5),
    ("four-berth second-class stateroom, D deck", 1875, 3441, 1970, 3541),
    ("two-berth second-class stateroom, D deck", 1875, 3566, 1970, 3661.5),
    # The corridors, port (its outer wall stepping in forward of the third passage) and
    # starboard.
    ("corridor, D deck", 1540, 3391, 2032.5, 3441),
    ("corridor, D deck", 2032.5, 3375.5, 2290, 3430),
    ("corridor, D deck", 1540, 3661.5, 2290, 3716),
    # The after second-class stairway (BOT: "another second class stairway, which gave
    # access to C, D, E, F and G decks"): its enclosure round the flights and their well,
    # and forward of it a landing from corridor to corridor before the saloon's doors.
    ("second-class entrance, D deck, aft", 2110, 3430, 2290, 3661.5),
    ("second-class entrance, D deck, aft", 2290, 3375.5, 2398.5, 3716),
    # The second-class dining saloon (BOT: "the second class saloon occupying 70 ft. of
    # the length"), round the forward second-class entrance: five rectangles that are one
    # room, No. 4 hatch's trunks in its after corners.
    ("second-class dining saloon", 2398.5, 3254, 2885, 3835),
    ("second-class dining saloon", 2457.5, 3027.5, 2885, 3254),
    ("second-class dining saloon", 2885, 3015.5, 3240, 3421.5),
    ("second-class dining saloon", 2469.5, 3835, 2885, 4053.5),
    ("second-class dining saloon", 2885, 3658, 3240, 4060.5),
    # The forward second-class entrance, round its lift and its staircase's two flights,
    # its ventilators along its after wall; forward of it the serving space a stair comes
    # up into from E deck (BOT: "they could pass by the stairway up to the serving space
    # at the forward end of the second class saloon"), open into the servery.
    ("second-class entrance, D deck", 2920.5, 3421.5, 3201, 3658),
    ("servery", 3201, 3421.5, 3240, 3658),
    ("servery", 3240, 3271, 3342.5, 3756),
    # The saloon service (BOT: "Abaft of and on the port side of this hatch were the
    # second class pantry and other spaces used for the saloon service of the
    # passengers"). Port: a lobby off the saloon (a stair down, a W.C. and the plate's H),
    # the butcher's and baker's shops along her side, and a passage forward between them
    # and the second-class pantry, its bar, the bread room and the bake house.
    ("passage, D deck", 3240, 3008, 3406, 3202.5),
    ("passage, D deck", 3240, 3202.5, 3878, 3271),
    ("butcher's shop", 3406, 3003, 3575, 3202.5),
    ("baker's shop", 3575, 2998, 3878, 3202.5),
    ("bar", 3342.5, 3271, 3443, 3336),
    ("second-class pantry", 3443, 3271, 3556.5, 3336),
    ("second-class pantry", 3342.5, 3336, 3556.5, 3756),
    ("second-class pantry", 3556.5, 3271, 3625.5, 3407),
    ("bread room", 3625.5, 3271, 3693, 3407),
    ("bake house", 3693, 3271, 3878, 3407),
    # Amidships the emergency dynamos (BOT: "Aft of this were the turbine engine hatch
    # and the emergency dynamos") beside the turbine engine casing, and the china, glass
    # and plate pantries (the plate's CHINA, GLASS, PL) along a corridor from the saloon
    # to the galley.
    ("emergency dynamos", 3556.5, 3407, 3665.5, 3645.5),
    ("china pantry", 3556.5, 3645.5, 3632.5, 3756),
    ("china pantry", 3632.5, 3645.5, 3717.5, 3756),
    ("glass pantry", 3717.5, 3645.5, 3815, 3756),
    ("plate pantry", 3815, 3645.5, 3878, 3756),
    ("corridor, D deck", 3240, 3756, 3878, 3809),
    # Starboard, the hospitals (BOT: "On the starboard side abreast of these there was a
    # series of rooms used for hospitals and their attendants"): a bath and W.C., the two
    # infectious hospitals, the attendants' room and three hospitals, off passages from
    # the corridor; the second infectious hospital's top 20 px up to the passage (est.).
    ("bathroom, D deck", 3240, 3809, 3332, 3889),
    ("passage, D deck", 3332, 3809, 3470.5, 3921.5),
    ("infectious hospital", 3240, 3921.5, 3364.5, 4062.5),
    ("infectious hospital", 3364.5, 3921.5, 3470.5, 4062.5),
    ("passage, D deck", 3470.5, 3809, 3817, 3853.5),
    ("passage, D deck", 3470.5, 3853.5, 3509.5, 4062.5),
    ("hospital attendants' room", 3509.5, 3853.5, 3636, 3944),
    ("hospital", 3509.5, 3944, 3604.5, 4063),
    ("passage, D deck", 3636, 3853.5, 3669.5, 4063),
    ("hospital", 3669.5, 3853.5, 3817, 3944),
    ("hospital", 3669.5, 3944, 3782, 4063.5),
    ("passage, D deck", 3817, 3809, 3845, 3915.5),
    ("bathroom, D deck", 3845, 3809, 3927.5, 3879),
    ("hospital", 3817, 3915.5, 3927.5, 4064),
    # The galley for first and second class (BOT: "the galley, which provides for both
    # first and second class passengers, occupied 45 ft."): four rectangles that are one
    # room, round its coal and coke rooms aft, the chef's office, the first-class pantry's
    # scullery and the knife room forward; to starboard the vegetable preparing room, the
    # first-class galley scullery, a coal room and the larder.
    ("galley", 3878, 3271, 4406, 3809),
    ("galley", 3927.5, 3809, 4406, 3852.5),
    ("galley", 3878, 3202.5, 4273.5, 3271),
    ("galley", 3981.5, 2988.5, 4197.5, 3202.5),
    ("galley", 4197.5, 3087, 4273.5, 3202.5),
    ("coal", 3878, 2992.5, 3981.5, 3136),
    ("coke", 3878, 3136, 3941, 3202.5),
    ("chef's office", 4197.5, 2986, 4273.5, 3087),
    ("first-class pantry scullery", 4273.5, 2984.5, 4406, 3201),
    ("knives", 4273.5, 3201, 4406, 3271),
    ("vegetable preparing room", 3927.5, 3852.5, 4024.5, 4064),
    ("first-class galley scullery", 4024.5, 3852.5, 4199, 4062.5),
    ("coal", 4199, 3852.5, 4302.5, 4061.5),
    ("larder", 4302.5, 3852.5, 4406, 4061),
    # The first-class pantry (BOT: "the first class pantry, which occupied 56 ft. of the
    # length of the ship. The reciprocating engine hatch came up through this pantry"),
    # round its casing and funnel 3's, the stewards' staircase between them; in its
    # corners the salad, silver, china and glass pantries, a pantry with a sink, the cold
    # store, the printer's room, the stewards' office and the saloon bar.
    ("salad pantry", 4406, 2983.5, 4475, 3164.5),
    ("first-class pantry", 4475, 2983.5, 4813.5, 3123),
    ("printer's room", 4813.5, 2983.5, 4882.5, 3123),
    ("stewards' office", 4882.5, 2983.5, 4989.5, 3087.5),
    ("first-class pantry", 4882.5, 3087.5, 4989.5, 3123),
    ("first-class pantry", 4989.5, 2983.5, 5064, 3123),
    ("first-class pantry", 4475, 3123, 5064, 3324),
    ("first-class pantry", 4406, 3164.5, 4475, 3324),
    ("silver pantry", 4406, 3324, 4516.5, 3403),
    ("first-class pantry", 4516.5, 3324, 5064, 3401),
    ("first-class pantry", 4681, 3401, 4783, 3637),
    ("passage, D deck", 4783, 3401, 4822, 3637),
    ("china pantry", 4406, 3641, 4518.5, 3711.5),
    ("pantry, D deck", 4406, 3711.5, 4518.5, 3780.5),
    ("first-class pantry", 4518.5, 3637, 5064, 3752.5),
    ("first-class pantry", 4406, 3780.5, 4523.5, 3849),
    ("first-class pantry", 4523.5, 3752.5, 5064, 3935.5),
    ("cold store", 4406, 3849, 4523.5, 3946.5),
    ("glass pantry", 4406, 3946.5, 4523.5, 4061),
    ("first-class pantry", 4523.5, 3935.5, 4862.5, 4053.5),
    ("saloon bar", 4862.5, 3935.5, 4997, 4053.5),
    ("first-class pantry", 4997, 3935.5, 5064, 4053.5),
    # The first-class dining saloon (BOT: "The dining saloon occupied 112 ft., and was
    # between the second and third funnels"; The Shipbuilder: "114ft. in length"), one
    # room: the screens that make its bays are solids.
    ("first-class dining saloon", 5064, 2975.5, 6385, 4047),
    # The reception room round funnel 2's casing (The Shipbuilder: "has a length of
    # 54ft."), the grand staircase's hall forward to its lifts (BOT: "The reception room
    # and staircase occupied 83 ft."): open into each other.
    ("reception room", 6385, 2968.5, 7002, 3286.5),
    ("reception room", 6385, 3286.5, 6893, 3734.5),
    ("reception room", 6385, 3734.5, 7010, 4036.5),
    ("grand staircase, D deck", 6893, 3286.5, 7289, 3734.5),
    # The first-class entrances either side, from the reception room's double doors to
    # the corridors forward (each with doors in her side, not laid), and the cross
    # passage between them abaft the stateroom block.
    ("first-class entrance, D deck", 7002, 2965.5, 7355, 3286.5),
    ("first-class entrance, D deck", 7010, 3734.5, 7363, 4026),
    ("passage, D deck", 7289, 3286.5, 7358.5, 3734.5),
    # The block of first-class staterooms round funnel 1's casing (BOT: "a block of 50
    # first class staterooms. This surrounded the forward funnel"). Along each side,
    # seven pairs of three-berth rooms: an outer room at her side, and an inner one by the
    # corridor that reaches her side past the outer one's slanted end — an L cut in two —
    # each pair's doors in a short passage off the corridor that two pairs share. Port,
    # aft to forward:
    # The first pair's outer room takes the strip by her side the plate gives the inner
    # one (est.), so that strip, which meets the entrance, gets no door into it (deck.py's
    # rule for a room given none); the same to starboard.
    ("three-berth first-class stateroom, D deck", 7355, 2966, 7491.5, 3138.5),
    ("three-berth first-class stateroom, D deck", 7355, 3138.5, 7491.5, 3231),
    ("passage, D deck", 7491.5, 2966, 7523.5, 3231),
    ("three-berth first-class stateroom, D deck", 7523.5, 2966, 7623.5, 3136.5),
    ("three-berth first-class stateroom, D deck", 7523.5, 3136.5, 7654.5, 3231),
    ("three-berth first-class stateroom, D deck", 7623.5, 2966, 7654.5, 3136.5),
    ("three-berth first-class stateroom, D deck", 7695, 2969, 7798.5, 3136.5),
    ("three-berth first-class stateroom, D deck", 7654.5, 3136.5, 7798.5, 3231),
    ("three-berth first-class stateroom, D deck", 7654.5, 2969, 7695, 3136.5),
    ("passage, D deck", 7798.5, 2973, 7832, 3231),
    ("three-berth first-class stateroom, D deck", 7832, 2973, 7931.5, 3135.5),
    ("three-berth first-class stateroom, D deck", 7832, 3135.5, 7964, 3231),
    ("three-berth first-class stateroom, D deck", 7931.5, 2973, 7964, 3135.5),
    ("three-berth first-class stateroom, D deck", 8009, 2976.5, 8111, 3133.5),
    ("three-berth first-class stateroom, D deck", 7964, 3133.5, 8111, 3231),
    ("three-berth first-class stateroom, D deck", 7964, 2976.5, 8009, 3133.5),
    ("passage, D deck", 8111, 2982.5, 8149, 3231),
    ("three-berth first-class stateroom, D deck", 8149, 2982.5, 8249.5, 3133),
    ("three-berth first-class stateroom, D deck", 8149, 3133, 8290, 3231),
    ("three-berth first-class stateroom, D deck", 8249.5, 2982.5, 8290, 3133),
    ("three-berth first-class stateroom, D deck", 8330.5, 2988.5, 8430, 3131.5),
    ("three-berth first-class stateroom, D deck", 8290, 3131.5, 8430, 3231),
    ("three-berth first-class stateroom, D deck", 8290, 2988.5, 8330.5, 3131.5),
    ("passage, D deck", 8430, 2988.5, 8465.5, 3231),
    # Starboard, aft to forward; its passages end at a closet by her side.
    ("three-berth first-class stateroom, D deck", 7363, 3755, 7494, 3857),
    ("three-berth first-class stateroom, D deck", 7363, 3857, 7494, 4022),
    ("passage, D deck", 7494, 3755, 7527.5, 3978.5),
    ("three-berth first-class stateroom, D deck", 7527.5, 3755, 7661, 3855.5),
    ("three-berth first-class stateroom, D deck", 7527.5, 3855.5, 7630, 4018.5),
    ("three-berth first-class stateroom, D deck", 7630, 3855.5, 7661, 4018.5),
    ("three-berth first-class stateroom, D deck", 7661, 3755, 7804.5, 3855),
    ("three-berth first-class stateroom, D deck", 7661, 3855, 7700, 4015),
    ("three-berth first-class stateroom, D deck", 7700, 3855, 7804.5, 4015),
    ("passage, D deck", 7804.5, 3755, 7838, 4010),
    ("three-berth first-class stateroom, D deck", 7838, 3755, 7970.5, 3854),
    ("three-berth first-class stateroom, D deck", 7838, 3854, 7945.5, 4010),
    ("three-berth first-class stateroom, D deck", 7970.5, 3755, 8114, 3852.5),
    ("three-berth first-class stateroom, D deck", 7970.5, 3852.5, 8014, 4004.5),
    ("three-berth first-class stateroom, D deck", 8014, 3852.5, 8114, 4004.5),
    ("passage, D deck", 8114, 3755, 8154.5, 3958.5),
    ("three-berth first-class stateroom, D deck", 8154.5, 3755, 8296, 3851),
    ("three-berth first-class stateroom, D deck", 8154.5, 3851, 8252.5, 3996),
    ("three-berth first-class stateroom, D deck", 8252.5, 3851, 8296, 3996),
    ("three-berth first-class stateroom, D deck", 8296, 3755, 8433.5, 3850),
    ("three-berth first-class stateroom, D deck", 8296, 3850, 8328, 3988.5),
    ("three-berth first-class stateroom, D deck", 8328, 3850, 8433.5, 3988.5),
    ("passage, D deck", 8433.5, 3755, 8467, 3948.5),
    # Across her forward end, eight staterooms side by side.
    ("three-berth first-class stateroom, D deck", 8465.5, 2996.5, 8573, 3131.5),
    ("two-berth first-class stateroom, D deck", 8465.5, 3131.5, 8573, 3260),
    ("two-berth first-class stateroom, D deck", 8465.5, 3260, 8573, 3370),
    ("two-berth first-class stateroom, D deck", 8465.5, 3370, 8573, 3483.5),
    ("two-berth first-class stateroom, D deck", 8465.5, 3483.5, 8573, 3603.5),
    ("two-berth first-class stateroom, D deck", 8465.5, 3603.5, 8573, 3723.5),
    ("two-berth first-class stateroom, D deck", 8465.5, 3723.5, 8573, 3845.5),
    ("three-berth first-class stateroom, D deck", 8465.5, 3845.5, 8573, 3978.5),
    # The corridors either side, and the cross passages between them: forward of the
    # casing's block and through it.
    ("D deck corridor", 7355, 3231, 8465.5, 3281),
    ("D deck corridor", 7360, 3700, 8467, 3755),
    ("passage, D deck", 8408.5, 3281, 8465.5, 3700),
    ("passage, D deck", 8186, 3281, 8218.5, 3700),
    # The block round the casing. Port, aft to forward: two bathrooms either side of a
    # passage into the ladies' lavatory, the chief steward's and the second steward's
    # rooms, four one-berth staterooms; forward of the cross passage a bathroom and a
    # one-berth stateroom.
    ("bathroom, D deck", 7357, 3281, 7436, 3374.5),
    ("passage, D deck", 7436, 3281, 7460.5, 3374.5),
    ("bathroom, D deck", 7460.5, 3281, 7544, 3374.5),
    ("chief steward's room", 7544, 3281, 7630, 3374.5),
    ("second steward's room", 7630, 3281, 7703, 3374.5),
    ("one-berth first-class stateroom, D deck", 7703, 3281, 7825, 3374.5),
    ("one-berth first-class stateroom, D deck", 7825, 3281, 7937, 3374.5),
    ("one-berth first-class stateroom, D deck", 7937, 3281, 8061, 3374.5),
    ("one-berth first-class stateroom, D deck", 8061, 3281, 8186, 3374.5),
    ("bathroom, D deck", 8218.5, 3281, 8299, 3368.8),
    ("one-berth first-class stateroom, D deck", 8299, 3281, 8408.5, 3368.8),
    # Amidships: the ladies' lavatory round its W.C.s abaft the casing's shafts, the
    # gentlemen's lavatory forward of its W.C.s, three bathrooms, two two-berth rooms.
    ("ladies' lavatory, D deck", 7357, 3374.5, 7510, 3606.4),
    ("gentlemen's lavatory, D deck", 8121, 3374.5, 8186, 3606.4),
    ("bathroom, D deck", 8218.5, 3368.8, 8299, 3450.5),
    ("bathroom, D deck", 8218.5, 3450.5, 8299, 3532.5),
    ("bathroom, D deck", 8218.5, 3532.5, 8299, 3602.5),
    ("two-berth first-class stateroom, D deck", 8299, 3368.8, 8408.5, 3484),
    ("two-berth first-class stateroom, D deck", 8299, 3484, 8408.5, 3602.5),
    # Starboard: two bathrooms either side of the ladies' lavatory's other passage, the
    # stewardess's room, four one-berth staterooms, a pantry; forward of the cross
    # passage the plate's S (est. a store) over the bay at a stair's head, and a one-berth
    # stateroom.
    ("bathroom, D deck", 7357, 3606.4, 7437.5, 3700),
    ("passage, D deck", 7437.5, 3606.4, 7465, 3700),
    ("bathroom, D deck", 7465, 3606.4, 7550, 3700),
    ("stewardesses' room, D deck", 7550, 3606.4, 7627, 3700),
    ("one-berth first-class stateroom, D deck", 7627, 3606.4, 7742, 3700),
    ("one-berth first-class stateroom, D deck", 7742, 3606.4, 7862.5, 3700),
    ("one-berth first-class stateroom, D deck", 7862.5, 3606.4, 7974, 3700),
    ("one-berth first-class stateroom, D deck", 7974, 3606.4, 8098, 3700),
    ("pantry, D deck", 8098, 3606.4, 8186, 3700),
    ("store, D deck", 8218.5, 3602.5, 8299, 3649.5),
    ("passage, D deck", 8218.5, 3649.5, 8299, 3700),
    ("one-berth first-class stateroom, D deck", 8299, 3602.5, 8408.5, 3700),
    # The third-class open space under the forward well (BOT: "the third class promenade
    # space which was covered in by C deck"), in four steps to her sides, and forward of
    # them the strips beside the firemen's wash place and W.C.s and the bay at the middle
    # line, where two ladders go up to C deck and down to E (the crew's: BOT's four
    # ladderways are the open space's own).
    ("third-class open space", 8572.5, 3005, 8747.5, 3967),
    ("third-class open space", 8747.5, 3022, 8987, 3943.5),
    ("third-class open space", 8987, 3045, 9183.5, 3916.5),
    ("third-class open space", 9183.5, 3072, 9400, 3887),
    ("third-class open space", 9400, 3097, 9429.5, 3360.5),
    # The bay's landing, and the lanes of its two ladders: C deck's comes down the after one
    # into the T.R.S., which the plate draws at the ladders' feet (c.py), so that lane opens
    # into it; the one down to E deck goes from the landing down the forward one.
    ("passage, D deck", 9400, 3360.5, 9490, 3422),
    ("passage, D deck", 9400, 3422, 9445, 3528),
    ("passage, D deck", 9445, 3422, 9490, 3528),
    ("third-class open space", 9400, 3587, 9431, 3861),
    ("T.R.S.", 9400, 3528, 9490, 3587),
    # Abaft the firemen's quarters, the landing at the heads of the two spiral staircases
    # down to their tunnel (BOT: "On each side of the middle line immediately abaft the
    # firemen's quarters there was a vertical spiral staircase"); their wash place to port
    # and their W.C.s to starboard (BOT: "the necessary lavatory accommodation, abaft the
    # firemen's quarters at the sides of the ship"), each in two steps to her side and an L
    # round the landing's corner. None of it opens onto the passengers' decks.
    ("passage, D deck", 9490, 3281.5, 9633.5, 3683),
    ("firemen's wash place", 9429.5, 3101, 9518, 3281.5),
    ("firemen's wash place", 9518, 3119, 9606, 3281.5),
    ("firemen's wash place", 9429.5, 3281.5, 9490, 3360.5),
    ("firemen's W.C.s", 9431, 3683, 9520, 3855.5),
    ("firemen's W.C.s", 9520, 3683, 9610.5, 3837.5),
    ("firemen's W.C.s", 9431, 3587, 9490, 3683),
    # The firemen's quarters (BOT: "accommodation for 108 firemen, who were in two
    # separate watches"): a watch each side of a wall on her centre line, No. 1 hatch
    # between them aft, each in five steps to her side, cut where the plate draws short
    # webs out from her side.
    ("firemen's quarters", 9633.5, 3152.5, 9776, 3472),
    ("firemen's quarters", 9776, 3182, 9870, 3472),
    ("firemen's quarters", 9870, 3211.5, 9990, 3472),
    ("firemen's quarters", 9990, 3245.5, 10103.5, 3472),
    ("firemen's quarters", 10103.5, 3284.5, 10246, 3472),
    ("firemen's quarters", 9633.5, 3472, 9776, 3803.5),
    ("firemen's quarters", 9776, 3472, 9870, 3772),
    ("firemen's quarters", 9870, 3472, 9990, 3740),
    ("firemen's quarters", 9990, 3472, 10103.5, 3702.5),
    ("firemen's quarters", 10103.5, 3472, 10246, 3657),
    # The store in her eyes, in three steps to her stem.
    ("store, D deck", 10246, 3324, 10350, 3611.5),
    ("store, D deck", 10350, 3360, 10450, 3572),
    ("store, D deck", 10450, 3394, 10530, 3535.5),
]

SOLIDS = [
    # Aft: a trunk in the third-class centre passage (est. a ventilator's: the plate's box
    # of three, 0.8 m from the passage's sides); the third-class W.C.s, the main
    # lavatories' rows of them between the third-class and second-class lavatories, and a
    # W.C. off the ladies' lavatory.
    ("trunk", 948, 3525, 1068, 3578, None),
    ("W.C.s", 1174, 3131, 1256, 3311, None),
    ("W.C.s", 1184.5, 3796.5, 1266.5, 3968, None),
    ("W.C.s", 1286, 3113, 1350, 3355, None),
    ("W.C.s", 1350, 3106, 1420.5, 3355, None),
    ("W.C.s", 1295, 3747, 1360, 3986.5, None),
    ("W.C.s", 1360, 3747, 1430, 3992.5, None),
    ("W.C.", 1430, 3935, 1499.5, 3997.5, None),
    # The cargo hatches' trunks up through the second-class rooms (No. 6 and No. 5, the
    # after well's) and the saloon's after corners (No. 4's, as B deck's, b_aft.py).
    ("No. 6 hatch", 1637.5, 3441, 1750.5, 3661.5, None),
    ("No. 5 hatch", 1970, 3441, 2110, 3661.5, None),
    ("No. 4 hatch", 2457.5, 3179.5, 2568.5, 3254, None),
    ("No. 4 hatch", 2469.5, 3835, 2574.5, 3908, None),
    # Closets narrower than a body: between the middle rooms, at the passages' ends by
    # her hull, by the saloon's after wall, in an inner stateroom's corner.
    ("closet", 1750.5, 3543, 1846, 3569, None),
    ("closet", 1875, 3541, 1970, 3566, None),
    ("closet", 2315, 3043, 2350, 3088.5, None),
    ("closet", 2350, 3254, 2398.5, 3290, None),
    ("closet", 2324, 4002, 2357.5, 4041.5, None),
    ("closet", 2183, 3811, 2212.5, 3855.5, None),
    # The after second-class stairway's well between its flights, its starboard side 10 px
    # inboard of the plate's, so C deck's flight down to starboard of it (c.py) clears it.
    ("stairwell", 2201.5, 3507, 2268, 3570, None),
    # The forward second-class entrance's ventilators and its lift.
    ("ventilator", 2885, 3421.5, 2920.5, 3482, None),
    ("ventilator", 2885, 3482, 2920.5, 3596.5, None),
    ("ventilator", 2885, 3596.5, 2920.5, 3658, None),
    # The lift's starboard side 10 px inboard of the plate's line, on C deck's lift's
    # (c.py), so the shaft stacks and C deck's flight down to starboard of it clears it.
    ("second-class lift", 3029.5, 3496.5, 3118.5, 3572, None),
    # In the service lobby: a W.C. and the plate's H (est. a hydrant's box, 1.2 m high).
    ("W.C.", 3361, 3008, 3406, 3088, None),
    ("H", 3240, 3160, 3302, 3202.5, 1.2),
    # The turbine engine casing (BOT: "the turbine engine hatch"), its fan in its corner.
    ("turbine engine casing", 3665.5, 3407, 3878, 3645.5, None),
    # The hospitals' W.C.s and closets, 0.8-0.9 m wide.
    ("W.C.", 3240, 3889, 3332, 3921.5, None),
    ("closet", 3604.5, 3944, 3636, 4063, None),
    ("closet", 3782, 3944, 3817, 4063.5, None),
    ("W.C.", 3845, 3879, 3927.5, 3915.5, None),
    # In the galley's corner, the plate's H (est. a hot press, to the deck above).
    ("H", 3941, 3136, 3981.5, 3202.5, None),
    # The first-class pantry's casings: the reciprocating engine's, and funnel 3's between
    # its fans and trunks, across the saloon's after wall; its two long counters (est.
    # 1 m, as the generator's), and the sink in its pantry.
    ("reciprocating engine casing", 4406, 3403, 4681, 3641, None),
    ("fans and trunks", 4822, 3398.5, 4886.5, 3633.5, None),
    ("funnel 3's casing", 4886.5, 3398.5, 5064, 3633.5, None),
    ("funnel 3's casing", 5064, 3398.5, 5294.5, 3633.5, None),
    ("fans and trunks", 5294.5, 3398.5, 5394.5, 3633.5, None),
    ("counter", 4576, 3123, 4952.5, 3282, 1.0),
    ("counter", 4642.5, 3752.5, 4959, 3901.5, 1.0),
    ("sink", 4418, 3719.5, 4507, 3770, 1.0),
    # The saloon's screens, each a stem from her side and a cross-piece at its end; and
    # funnel 2's casing across its forward wall.
    ("screen", 5509.5, 2975.5, 5517.5, 3172, None),
    ("screen", 5401, 3172, 5620, 3181, None),
    ("screen", 5922.5, 2975.5, 5930.5, 3172, None),
    ("screen", 5818, 3172, 6031, 3181, None),
    ("screen", 5417, 3849, 5628, 3858, None),
    ("screen", 5519.5, 3858, 5527.5, 4047, None),
    ("screen", 5836, 3846, 6042, 3855, None),
    ("screen", 5931.5, 3855, 5939.5, 4047, None),
    ("fans and trunks", 6124.5, 3388, 6226, 3623.5, None),
    ("funnel 2's casing", 6226, 3388, 6385, 3623.5, None),
    ("funnel 2's casing", 6385, 3388, 6625.5, 3623.5, None),
    ("fans and trunks", 6625.5, 3388, 6694, 3623.5, None),
    # The grand staircase's three lifts. The plate's WELLs either side of the foot of C
    # deck's flight are the openings down to E deck beside it: here the flights down to D
    # and to E deck take their halves, and no block stands in them.
    ("first-class lifts", 7078.5, 3380.5, 7166, 3614.5, None),
    # The stateroom block: the closets at the starboard passages' ends and the one too
    # narrow for a body at a stateroom's side; the ladies' W.C.s, funnel 1's casing
    # between its shafts, the gentlemen's W.C.s.
    ("closet", 7494, 3978.5, 7527.5, 4020, None),
    ("closet", 7945.5, 3854, 7970.5, 4007, None),
    ("closet", 8114, 3958.5, 8154.5, 3998, None),
    ("closet", 8433.5, 3948.5, 8467, 3986, None),
    ("W.C.s", 7419, 3415.5, 7510, 3572.5, None),
    ("fans and trunks", 7510, 3374.5, 7579.5, 3606.4, None),
    ("funnel 1's casing", 7579.5, 3374.5, 7974, 3606.4, None),
    ("fans and trunks", 7974, 3374.5, 8040, 3606.4, None),
    ("W.C.s", 8040, 3374.5, 8121, 3606.4, None),
    # A trunk against the block's forward end, in the open space.
    ("trunk", 8573, 3452, 8598, 3514, None),
    # The trunks either side between the firemen's lavatories and their quarters, and one
    # in the store, narrower than a body.
    ("trunk", 9606, 3129, 9633.5, 3281.5, None),
    ("trunk", 9610.5, 3683, 9633.5, 3821, None),
    ("trunk", 10246, 3447.5, 10292.5, 3493, None),
    # The cargo hatches forward, their covers a hop up (est., as tools/gen_titanic.py's
    # well hatch): No. 1 in two halves either side of the firemen's centre wall, set 7 px
    # clear of their after wall, which the plate draws over its coaming; the bunker hatch
    # and No. 2 in the open space.
    ("No. 1 hatch", 9641, 3391.5, 9776, 3472, 0.8),
    ("No. 1 hatch", 9641, 3472, 9776, 3557, 0.8),
    ("bunker hatch", 8747.5, 3375, 8882.5, 3596, 0.8),
    ("No. 2 hatch", 8987, 3374, 9183.5, 3594, 0.8),
]

DOORS = [
    # Aft: the store from the middle six-berth room; the third-class rooms off their
    # passages, as their swings stand; the baths, the lavatories off the passages.
    (745.5, 3550), (880, 3550), (880, 3462), (880, 3650),
    (905.5, 3400), (1062, 3400), (905.5, 3465), (1062, 3465),
    (914.5, 3640), (1068, 3640), (914.5, 3700), (1068, 3700),
    (1150, 3528), (1150, 3569), (1102, 3358), (1102, 3750),
    (1562.5, 3330), (1562.5, 3190), (1562.5, 3280),
    (1575.5, 3762), (1575.5, 3815), (1575.5, 3900),
    # The third-class entrance from the stern rooms' passage; its matron's room and
    # surgery.
    (1207.5, 3549), (1540, 3490), (1540, 3600),
    # The second-class rooms, port: off the first passage, the second, the third, the
    # corridor and the fourth.
    (1594, 3290), (1594, 3365), (1693.5, 3200),
    (1729.5, 3170), (1729.5, 3255), (1729.5, 3330),
    (1866, 3391), (1996.5, 3175), (1996.5, 3245), (1996.5, 3330),
    (2032.5, 3165), (2032.5, 3225), (2032.5, 3335), (2160, 3375.5),
    (2315, 3145), (2315, 3225), (2315, 3345),
    (2350, 3145), (2350, 3215), (2350, 3355),
    # Starboard.
    (1607, 3825), (1707.5, 3760), (1707.5, 3905),
    (1743, 3745), (1743, 3865), (1743, 3935), (1876, 3716),
    (2010, 3745), (2010, 3860), (2010, 3935),
    (2049.5, 3760), (2049.5, 3860), (2049.5, 3945), (2182, 3716),
    (2324, 3790), (2324, 3860), (2324, 3950),
    (2357.5, 3760), (2357.5, 3870), (2357.5, 3950),
    # Amidships, off the cross passage.
    (1846, 3490), (1846, 3615), (1875, 3490), (1875, 3615),
    # The saloon's double doors from the after landing, the forward entrance's from the
    # saloon either side; the servery's from the saloon and into the pantry.
    (2398.5, 3545), (2945, 3421.5), (2945, 3658), (3240, 3330), (3240, 3707), (3342.5, 3500),
    # The saloon into the service lobby and its passage; the shops, the bread room and the
    # bake house from the passage; the bar and the pantry; the dynamos; the china, glass and
    # plate pantries and the pantry from the corridor; the corridor and the passage into
    # the galley.
    (3240, 3100), (3240, 3237), (3490, 3202.5), (3720, 3202.5), (3660, 3271), (3780, 3271),
    (3443, 3300), (3500, 3271), (3556.5, 3600), (3450, 3756),
    (3594, 3756), (3675, 3756), (3766, 3756), (3846, 3756), (3878, 3782), (3878, 3237),
    # The saloon into the hospitals' corridor; the hospitals' rooms off their passages.
    (3240, 3782), (3288, 3809), (3400, 3809), (3490, 3809), (3652, 3809), (3831, 3809),
    (3340, 3921.5), (3420, 3921.5), (3509.5, 3895), (3509.5, 3990), (3669.5, 3895),
    (3669.5, 3990), (3870, 3809), (3831, 3915.5),
    # The galley's rooms: coal and coke, the chef's office, the scullery and the knife
    # room; to starboard its four rooms; into the pantry.
    (3981.5, 3100), (3910, 3202.5), (4235, 3087), (4273.5, 3145), (4340, 3271),
    (3976, 3852.5), (4111, 3852.5), (4250, 3852.5), (4354, 3852.5),
    (4406, 3236), (4406, 3298), (4406, 3829),
    # The first-class pantry: into its small rooms, the stewards' staircase at each end;
    # into the saloon (its swinging doors and double doors), and the saloon into the
    # reception room.
    (4475, 3145), (4813.5, 3090), (4950, 3087.5), (4516.5, 3380), (4518.5, 3690), (4518.5, 3730),
    (4523.5, 3915), (4523.5, 4010), (4945, 3935.5), (4802, 3401), (4802, 3637), (4783, 3414),
    (5064, 3170), (5064, 3365), (5064, 3670), (5064, 3858), (6385, 3355), (6385, 3665),
    # The entrances' double doors from the reception room.
    (7002, 3255), (7010, 3770),
    # The staterooms along her sides, each pair's two from its passage: port, then
    # starboard, aft to forward; then across her forward end.
    (7491.5, 3057), (7491.5, 3187), (7523.5, 3045), (7523.5, 3184), (7798.5, 3061), (7798.5, 3180),
    (7832, 3061), (7832, 3180), (8111, 3061), (8111, 3185), (8149, 3045), (8149, 3180),
    (8430, 3070), (8430, 3185),
    (7494, 3815), (7494, 3936), (7527.5, 3807), (7527.5, 3941), (7804.5, 3807), (7804.5, 3939),
    (7838, 3808), (7838, 3937), (8114, 3804), (8114, 3932), (8154.5, 3804), (8154.5, 3927),
    (8433.5, 3810), (8433.5, 3918),
    (8465.5, 3075), (8465.5, 3215), (8465.5, 3320), (8465.5, 3420), (8465.5, 3545), (8465.5, 3660),
    (8465.5, 3790), (8465.5, 3900),
    # The block round the casing: the bathrooms from their passages, the ladies'
    # lavatory from both; the stewards' rooms and staterooms from the corridors; the
    # forward staterooms; the gentlemen's lavatory from the cross passage; the store.
    (7436, 3355), (7460.5, 3355), (7437.5, 3650), (7465, 3650), (7448, 3374.5), (7451, 3606.4),
    (7600, 3281), (7665, 3281), (7725, 3281), (7845, 3281), (7955, 3281), (8080, 3281), (8315, 3281),
    (7590, 3700), (7650, 3700), (7765, 3700), (7885, 3700), (7995, 3700), (8320, 3700),
    (8408.5, 3420), (8408.5, 3560), (8186, 3460), (8218.5, 3625),
    # The T.R.S. from the open space; the store forward; the landing into each watch's
    # quarters, and the wash place and the W.C.s off it.
    (9400, 3550), (10246, 3415), (9633.5, 3330), (9633.5, 3640), (9585, 3281.5), (9585, 3683),
]

OPEN = [
    # The stern store's steps; the third-class passages into the centre passage and its
    # stub between the baths.
    (594, 3259, 606, 3763), (674, 3228, 686, 3834),
    (886, 3489, 899.5, 3501), (886, 3605, 908.5, 3617), (1068, 3489, 1087, 3501), (1074, 3605, 1092, 3617),
    (1095, 3536, 1107, 3561),
    # The lavatories' two rectangles each.
    (1099, 3349, 1201.5, 3361), (1104, 3741, 1201.5, 3753), (1426.5, 3299, 1482, 3311), (1436, 3772, 1493.5, 3784),
    # The second-class passages into the corridors, port and starboard.
    (1568.5, 3385, 1588, 3397), (1699.5, 3385, 1723.5, 3397), (2002.5, 3385, 2026.5, 3397),
    (2321, 3369.5, 2344, 3381.5),
    (1581.5, 3710, 1601, 3722), (1713.5, 3710, 1737, 3722), (2016, 3710, 2043.5, 3722),
    (2330, 3710, 2351.5, 3722),
    # The inner rooms' two pieces each.
    (1829.5, 3192.5, 1856.5, 3204.5), (1868.5, 3185.5, 1893, 3197.5),
    (2141.5, 3179.5, 2167.5, 3191.5), (2179.5, 3172.5, 2202.5, 3184.5),
    (1850, 3897.5, 1873.5, 3909.5), (1885.5, 3897.5, 1907.5, 3909.5),
    (2159.5, 3902, 2177, 3914), (2189, 3902, 2223.5, 3914),
    # The corridors: port's two pieces; the cross passage into both; the after landing
    # into both and into the stairway's enclosure.
    (2026.5, 3397, 2038.5, 3424), (1852, 3435, 1869, 3447), (1852, 3655.5, 1869, 3667.5),
    (2284, 3381.5, 2296, 3424), (2284, 3667.5, 2296, 3710), (2284, 3436, 2296, 3655.5),
    # The second-class saloon's five rectangles; the servery's two.
    (2463.5, 3248, 2879, 3260), (2475.5, 3829, 2879, 3841), (2879, 3260, 2891, 3415.5),
    (2879, 3664, 2891, 3829), (2879, 3033.5, 2891, 3248), (2879, 3841, 2891, 4047.5), (3234, 3446, 3246, 3634),
    # The service lobby into its passage; the second-class pantry's three rectangles.
    (3246, 3196.5, 3400, 3208.5), (3449, 3330, 3550.5, 3342), (3550.5, 3277, 3562.5, 3401),
    # The hospitals' passages.
    (3476.5, 3847.5, 3503.5, 3859.5), (3642, 3847.5, 3663.5, 3859.5),
    # The galley's four rectangles.
    (3933.5, 3803, 4400, 3815), (3884, 3265, 4267.5, 3277), (3987.5, 3196.5, 4191.5, 3208.5),
    (4203.5, 3196.5, 4267.5, 3208.5), (4191.5, 3093, 4203.5, 3196.5),
    # The first-class pantry's pieces.
    (4481, 3117, 4807.5, 3129), (4888.5, 3117, 4983.5, 3129), (4995.5, 3117, 5058, 3129),
    (4469, 3170.5, 4481, 3318), (4522.5, 3318, 5058, 3330), (4687, 3395, 4777, 3407),
    (4687, 3631, 4777, 3643), (4529.5, 3746.5, 5058, 3758.5), (4517.5, 3786.5, 4529.5, 3843),
    (4529.5, 3929.5, 4856.5, 3941.5), (5003, 3929.5, 5058, 3941.5),
    # The reception room's three pieces and the staircase's hall.
    (6391, 3280.5, 6887, 3292.5), (6899, 3280.5, 6996, 3292.5), (6887, 3292.5, 6899, 3728.5),
    (6391, 3728.5, 6887, 3740.5), (6899, 3728.5, 7004, 3740.5),
    # The entrances into the corridors and the cross passage, and the cross passage into
    # the starboard corridor.
    (7349, 3237, 7361, 3275), (7295, 3280.5, 7349, 3292.5), (7352.5, 3706, 7364.5, 3728.5),
    (7359, 3738, 7365, 3752), (7295, 3728.5, 7352.5, 3740.5),
    # Each inner stateroom's two pieces, port and starboard.
    (7629.5, 3130.5, 7648.5, 3142.5), (7660.5, 3130.5, 7689, 3142.5),
    (7937.5, 3129.5, 7958, 3141.5), (7970, 3127.5, 8003, 3139.5), (8255.5, 3127, 8284, 3139),
    (8296, 3125.5, 8324.5, 3137.5),
    (7636, 3849.5, 7655, 3861.5), (7667, 3849, 7694, 3861),
    (7976.5, 3846.5, 8008, 3858.5), (8258.5, 3845, 8290, 3857), (8302, 3844, 8322, 3856),
    # The passages off the corridors, and the cross passages into them.
    (7497.5, 3225, 7517.5, 3237), (7804.5, 3225, 7826, 3237), (8117, 3225, 8143, 3237), (8436, 3225, 8459.5, 3237),
    (7500, 3749, 7521.5, 3761), (7810.5, 3749, 7832, 3761), (8120, 3749, 8148.5, 3761), (8439.5, 3749, 8461, 3761),
    (7442, 3275, 7454.5, 3287), (7443.5, 3694, 7459, 3706),
    (8192, 3275, 8212.5, 3287), (8192, 3694, 8212.5, 3706), (8414.5, 3267, 8459.5, 3279), (8414.5, 3694, 8459.5, 3706),
    (8212.5, 3655.5, 8224.5, 3694), (8224.5, 3694, 8293, 3706),
    # The open space's steps, its strips forward, and the bay's mouth.
    (8741.5, 3028, 8753.5, 3937.5), (8981, 3051, 8993, 3910.5), (9177.5, 3078, 9189.5, 3881),
    (9394, 3103, 9406, 3354.5), (9394, 3366.5, 9406, 3415), (9394, 3593, 9406, 3855),
    (9406, 3354.5, 9423.5, 3366.5), (9406, 3416, 9439, 3428), (9451, 3416, 9484, 3428), (9406, 3522, 9439, 3534),
    # The wash place's and the W.C.s' pieces.
    (9435.5, 3275.5, 9484, 3287.5), (9512, 3125, 9524, 3275.5),
    (9514, 3689, 9526, 3831.5), (9437, 3677, 9484, 3689),
    # The firemen's quarters' steps, port and starboard, and the store's.
    (9770, 3188, 9782, 3458), (9864, 3217.5, 9876, 3458), (9984, 3251.5, 9996, 3458), (10097.5, 3290.5, 10109.5, 3458),
    (9770, 3486, 9782, 3766), (9864, 3486, 9876, 3734), (9984, 3486, 9996, 3696.5), (10097.5, 3486, 10109.5, 3651),
    (10344, 3366, 10356, 3566), (10444, 3400, 10456, 3529.5),
]

STAIRS = [
    # The main third-class stairway down to E deck, as the plate draws it: 125 px of
    # treads (3.3 m) for 2.75 m, rising aft (est.) to where C deck's flight down lands.
    # The plate draws the 16 ft (BOT) in three lanes; C deck's flight down comes down the
    # middle and starboard ones (c.py), so this one takes the port lane, 1.35 m wide.
    ("third-class stairway", 1313, 3441.5, 1438, 3493, "aft", "e", "d"),
    # The after second-class stairway's flight down to E deck: the port flight, as the
    # stairways above alternate (B deck's port, b_aft.py), rising aft as B deck's does. The
    # plate draws 66.5 px of treads (1.7 m) for 2.75 m: it runs on 58.5 px aft over the
    # landing to a slope a body climbs, 125 px (3.25 m) in all, as the flights below.
    ("second-class stairway", 2143, 3430, 2268, 3507, "aft", "e", "d"),
    # The forward second-class staircase's flight down to E deck: the port one, as the boat
    # deck's, B deck's and (est.) D deck's alternate (boat.py, a.py, b_aft.py), rising aft.
    # The plate draws 89 px of treads (2.3 m): it runs on 36 px aft over the landing.
    ("second-class staircase", 2993.5, 3421.5, 3118.5, 3496.5, "aft", "e", "d"),
    # The stair from E deck up into the serving space (BOT), as the plate draws it, 127 px
    # (3.3 m) athwart her; its head to port est.
    ("stair", 3205, 3531, 3245.5, 3658, "port", "e", "d"),
    # A stair down from the service lobby by the shops, over the one the plate's E deck
    # draws: its 75 px of treads (2 m) run on 50 px forward; its head forward est.
    ("stair", 3246, 3116, 3371, 3160, "fore", "e", "d"),
    # The stewards' staircase down to E deck (BOT: "between the reciprocating engine
    # casing and the third funnel casing there was a stewards' stairway, which
    # communicated with all the decks below as far as E deck"), as the plate draws it:
    # 160 px of treads (4.2 m) for 2.75 m. Its head to port: E deck draws its foot at the
    # starboard end, a passage going on to starboard from it. C deck draws its flight down
    # to D in the same 1 m well (c.py), rising to starboard: the plates stack the two in
    # one footprint, a switchback no body walks (see the PR's notes for the lay).
    ("stewards' staircase", 4783, 3434, 4822, 3594, "port", "e", "d"),
    # The grand staircase's flight down to E deck, rising forward to the lifts' landing as
    # the flights above do (a.py, b_fwd.py, c.py): the port half of the plate's flight, C
    # deck's coming down the starboard half (c.py), as the decks above alternate halves.
    # The plate's WELLs either side of the fan are the openings the flights go down
    # through, not blocks. Its 127 px (3.35 m) run aft from where C deck's flight's head
    # stands, 1.8 m short of the lifts, so a landing stays in front of them, as on C deck.
    ("grand staircase", 6883, 3384, 7010, 3496, "fore", "e", "d"),
    # A stair down from the port entrance, over the one the plate's E deck draws under it:
    # its 86 px of treads run on forward to 127 px. Its head aft est.
    ("stair", 7080, 3238, 7207, 3279, "aft", "e", "d"),
    # Not laid: the stair the plate draws down to E deck from the bay at 8218-8299 by the
    # starboard cross passage, 81 px of treads (2.1 m) with no room in the block to run on
    # to a slope a body climbs (the cross passage aft, a stateroom forward).
    #
    # The firemen's spiral staircases down to E deck and on to their tunnel: a spiral has
    # no run a body climbs, so each is a straight flight as wide as the plate's spiral
    # (66 px), from its place forward over the landing to the run STEEPEST allows (127 px,
    # 3.4 m, for 2.75 m), its head by the doors into the quarters.
    ("firemen's spiral staircase", 9500, 3379, 9627, 3445, "fore", "e", "d"),
    ("firemen's spiral staircase", 9500, 3495, 9627, 3561, "fore", "e", "d"),
    # The open space's ladderways down to E deck (BOT: "four separate ladderways with two
    # ladders, 4 ft. wide to each ... one, the starboard, led to E deck ... The two ladder
    # ways at the after end led to E deck on both sides"): both after ones whole, run on
    # from the plate's 107-115 px to 125 px (3.35 m for 2.75 m), the way each rises est.
    # The forward starboard one's two ladders the plate draws once for the ladderway up to
    # C deck and down to E: C deck's flight down comes down both (c.py), its foot at px
    # ~9365, so the outboard ladder down to E deck runs from 56 px aft of the plate's, its
    # head aft under C deck's flight, both rising aft, and its foot 0.35 m short of where
    # that one lands.
    ("third-class ladder", 8665, 3186, 8790, 3296, "aft", "e", "d"),
    ("third-class ladder", 8668.5, 3676, 8790, 3791, "aft", "e", "d"),
    ("third-class ladder", 9215, 3704, 9340, 3755, "aft", "e", "d"),
    # The crew's ladder down to E deck in the bay at the middle line, starboard of the one
    # up to C deck: run on from the plate's 106 px to 125 px, its head to port est.
    ("ladder", 9448.5, 3403, 9483.5, 3528, "port", "e", "d"),
]
