class_name GirderStrength
extends Resource
## How much bending her hull carries along her length (§5b.2): the moment, in N·m, at
## which a station gives way hogging — the middle up, the ends down — and sagging — the
## middle down. The bending her flooding loads put on her is measured against it every
## step (HullGirder); from SH33 a station past it starts a hinge. Est. for every ship
## (5b.1: a 30 m trawler holds about 66 MN·m).

@export var hog: float
@export var sag: float


## Every reason this strength cannot be read; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if hog <= 0.0 or sag <= 0.0:
		found.append("structure: her strength must be positive hogging and sagging")
	return found
