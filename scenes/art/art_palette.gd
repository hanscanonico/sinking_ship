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


static func seat_colour(seat: int) -> Color:
	return SEAT_COLOURS[seat % SEAT_COLOURS.size()]
