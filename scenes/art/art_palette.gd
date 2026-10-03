class_name ArtPalette
extends RefCounted
## The colours code-built art draws with. The sky and the light keep theirs in
## scenes/art/sea_and_sky.tscn and the sea in water.gdshader, tuned there by eye.

## One per seat, from Okabe & Ito's colour-blind-safe set with its black traded for
## white, which a dark-jointed body cannot wear, and its orange for Tol's wine,
## which stays apart from vermillion and yellow at a distance. The first six differ
## in hue family as well; seats four apart share a hat shape, and each such pair
## stays apart under every common colour blindness.
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
## Joints, hat bands and outlines: one dark for every seat, so the crew reads as a
## set and the seat colour is the only thing that differs.
const INK := Color("23262e")
## The facing chevron while a shove winds up and lands.
const SHOVE_FLASH := Color(1.0, 1.0, 1.0)
const MARKER := Color(1.0, 1.0, 1.0)

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
const MACHINE := Color("3b4a3f")
const STEEL := Color("70757c")
const BRASS := Color("b8913a")
const UPHOLSTERY := Color("7a2e2a")
const BLANKET := Color("41557a")
const LINEN := Color("e9e4d6")
const CRATE := Color("9c7a4c")
const SMOKE := Color(0.29, 0.28, 0.28, 0.55)
## A room lamp's glass and its light.
const LAMP_GLASS := Color("ffe2a8")
const LAMP_LIGHT := Color("ffc47a")
## A deck about to give way blinks toward this (the greybox's flash).
const COLLAPSE_FLASH := Color(1.0, 0.2, 0.1)


static func seat_colour(seat: int) -> Color:
	return SEAT_COLOURS[seat % SEAT_COLOURS.size()]
