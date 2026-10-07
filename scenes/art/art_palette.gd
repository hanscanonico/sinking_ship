class_name ArtPalette
extends RefCounted
## The colours code-built art draws with. The sky and the light keep theirs in
## scenes/art/sea_and_sky.tscn and the sea in water.gdshader, tuned there by eye.

## One per seat, worn as its coat, from Okabe & Ito's colour-blind-safe set with its
## black traded for white, which a dark-trousered body cannot wear, and its orange
## for Tol's wine, which stays apart from vermillion and yellow at a distance. The
## first six differ in hue family as well, and every seat wears its own hat.
const SEAT_COLOURS: Array[Color] = [
	Color("d55e00"),
	Color("f0e442"),
	Color("009e73"),
	Color("f2f2f2"),
	Color("56b4e9"),
	Color("cc79a7"),
	Color("0072b2"),
	Color("6f1d46"),
]
## Eyes, hat bands and outlines: one dark for every seat, so the crew reads as a
## set.
const INK := Color("23262e")
## The disc at a brawler's feet while a shove winds up and lands.
const SHOVE_FLASH := Color(1.0, 1.0, 1.0)
const MARKER := Color(1.0, 1.0, 1.0)
## The crew's clothes (Brawler): the seat's colour is the coat, and everything else
## a quiet neutral under it, so the seat still reads first at any range.
const SKIN := Color("e2ae8a")
const SHIRT := Color("ece6d6")
const LEATHER := Color("4d3424")
const STRAW := Color("dcc68e")
const HAIR: Array[Color] = [Color("33241a"), Color("1c1b1f"), Color("9a4c25"), Color("8f8a82")]
const TROUSERS: Array[Color] = [Color("3a3d46"), Color("564539"), Color("2c3447"), Color("6c6a64")]
## A shove's hands as it winds up and lands.
const HAND_FLASH := Color("ffd36e")
## A shove coming: the body's edge, its outline and a charge's sparks, ember at a
## wind-up and toward white-hot at a full charge.
const CHARGE := Color("ff6a14")
const CHARGE_CORE := Color("fff0c2")
## A brace's scuffs on the deck at the feet: dark wood dust, and the pale grain the
## boots tear up.
const SCUFF := Color("2b1d14")
const SCUFF_DUST := Color("e9d3a8")

## The ship (ShipArt): a dark hull, red oxide below the boot line, so the foam line
## pops; warm deck planks lighter than most seat colours; white houses with teak
## trim outside, cream cabins over a dark panelled dado inside; a buff funnel with a
## black top.
const HULL := Color("22252b")
const HULL_BOTTOM := Color("8e2b22")
const RIBAND := Color("e8e2d2")
const DECK := Color("b98b5e")
const DECK_SEAM := Color("3e2b1e")
const HOUSE := Color("e8e2d2")
const HOUSE_FOOT := Color("4a4038")
const TEAK := Color("8a5a35")
## Fresh wood where a rail has splintered, paler than any weathered teak.
const SPLINTER := Color("e0c08e")
const CABIN := Color("e6dcc2")
const DADO := Color("6e4a30")
const CEILING := Color("d9d2c0")
const BEAM := Color("6b4a30")
const TREAD := Color("9f7853")
const FRAME := Color("6b4426")
const FUNNEL := Color("d9a44a")
const FUNNEL_TOP := Color("1d1d20")
const MAST := Color("c8ad7f")
const CANVAS := Color("6b7458")
## Manila rope: a lifeboat's falls.
const ROPE := Color("c9b07a")
const MACHINE := Color("3b4a3f")
const STEEL := Color("70757c")
const BRASS := Color("b8913a")
const UPHOLSTERY := Color("7a2e2a")
const BLANKET := Color("41557a")
const LINEN := Color("e9e4d6")
const CRATE := Color("9c7a4c")
const SMOKE := Color(0.29, 0.28, 0.28, 0.55)
## A room lamp's glass and its light; on her emergency power (SH31), a dim red.
const LAMP_GLASS := Color("ffe2a8")
const LAMP_LIGHT := Color("ffc47a")
const EMERGENCY_GLASS := Color("ff6a4a")
const EMERGENCY_LIGHT := Color("e2492e")
## A deck about to give way blinks toward this (the greybox's flash).
const COLLAPSE_FLASH := Color(1.0, 0.2, 0.1)
## The rooms below the passenger decks and the wheelhouse (RoomDressing). An engine
## room of grey-green riveted steel over a black kick, checker plate underfoot, its
## engine a lighter green than its walls, picked out in bright steel and brass, and
## black boilers whose fires glow orange; a hold of rough, unpainted timber and
## stowed cargo paler than the deck crates; lower-deck cabins in their own
## blankets and curtains; a wheelhouse panelled in varnished teak.
const BULKHEAD := Color("74826f")
const BULKHEAD_FOOT := Color("2b2f2d")
const BULKHEAD_OVERHEAD := Color("7f8a7c")
const CHECKER_PLATE := Color("6a6e70")
const ENGINE := Color("557563")
const BRIGHT_STEEL := Color("b5bcc0")
const BOILER := Color("34383a")
const GAUGE_FACE := Color("efe8d6")
const FIRE_GLOW := Color("ff7a1e")
const EMBERS := Color("2a1410")
const FIRE_LIGHT := Color("ff8c3c")
const HOLD_WALL := Color("ad8f68")
const HOLD_FLOOR := Color("957756")
const HOLD_OVERHEAD := Color("9c8061")
const HOLD_FRAME := Color("6e5236")
const STOWED_CRATE := Color("ab8656")
const STENCIL := Color("3b2d22")
const SACKING := Color("bda478")
const LAMP_SHADE := Color("3f4a45")
const PANELLING := Color("7d5232")
const ENAMEL := Color("f0ebdd")
const LIFEBELT := Color("cf3b2b")
const FIRE_BUCKET := Color("b5302a")
const MIRROR := Color("a7b8bf")
const CHART := Color("e3d8b8")
## The forecastle's steel deck plating, outboard of its planking.
const BOW_PLATE := Color("6b4a3d")
## The jack flown at the bow and the ensign at the stern.
const JACK := Color("2c3e78")
const ENSIGN := Color("b8322a")
## A funnel's steel casing where it passes through a cabin; a saloon's curtains.
const CASING := Color("bdb6a4")
const SALOON_CURTAIN := Color("a8823f")
## Per lower-deck cabin, in turn: its blanket and its porthole curtains.
const CABIN_BLANKETS: Array[Color] = [
	Color("41557a"),
	Color("7a2e2a"),
	Color("4f6a45"),
	Color("8a6838"),
	Color("5b4a6e"),
	Color("2f5c5c")
]
const CABIN_CURTAINS: Array[Color] = [
	Color("9c3d33"),
	Color("3f5b7d"),
	Color("a8874a"),
	Color("5c7350"),
	Color("8a4a6a"),
	Color("b07a4a")
]

## The sinking's effects (SinkingFx): white water, a little cooler than the sea's
## foam so it reads against it; steam whiter and thinner; the funnel's smoke as the
## fires are drowned; dust off old timber; the cloud of a deck giving way, lit warm
## by the low sun; dust sifting down indoors; bubbles.
const SPRAY := Color(0.9, 0.95, 0.96, 0.9)
const STEAM := Color(0.96, 0.96, 0.95, 0.6)
const SMOKE_HEAVY := Color(0.17, 0.16, 0.16, 0.75)
const DUST := Color(0.72, 0.66, 0.57, 0.85)
const DUST_CLOUD := Color(0.74, 0.57, 0.42, 0.9)
const SIFTING_DUST := Color(0.6, 0.53, 0.44, 0.8)
const BUBBLE := Color(0.88, 0.96, 0.97, 0.85)
## The toon billows' shade sides: steam's turned from the low sun takes the dusk
## sky's lilac, never a grey; the funnel's smoke is warm where the sun catches it and
## near black in its shade.
const STEAM_SHADE := Color(0.66, 0.66, 0.84)
## Spray mist's billows turned from the sun: the sea's cool blue-grey, so it reads as
## white water, not as steam.
const SPRAY_SHADE := Color(0.72, 0.82, 0.88)
const SMOKE_LIT := Color(0.32, 0.25, 0.23)
const SMOKE_SHADE := Color(0.13, 0.12, 0.14)
## Floating wreckage: a lifebelt's bands, a deck chair's canvas.
const FLOTSAM_LIFEBELT := Color("efe9dc")
const LIFEBELT_BAND := Color("c1372b")
const CHAIR_CANVAS := Color("3f6f8f")


static func seat_colour(seat: int) -> Color:
	return SEAT_COLOURS[seat % SEAT_COLOURS.size()]
