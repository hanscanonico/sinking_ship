class_name GirderStrength
extends Resource
## How much bending her hull carries along her length (§5b.2): the moment, in N·m, at
## which a station gives way hogging — the middle up, the ends down — and sagging — the
## middle down. The bending her flooding loads put on her is measured against it every
## step (HullGirder); from SH33 a weak spot past its share of it starts a hinge
## (HullBreak). Est. for every ship (5b.1: a 30 m trawler holds about 66 MN·m).

@export var hog: float
@export var sag: float
## Where along her she can break (WeakSpot), aft to fore: none for a hull that cannot.
@export var weak: Array[WeakSpot] = []


## Every reason this strength cannot be read; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if hog <= 0.0 or sag <= 0.0:
		found.append("structure: her strength must be positive hogging and sagging")
	var aft := -INF
	for spot: WeakSpot in weak:
		if spot == null or spot.name.is_empty() or spot.share <= 0.0 or spot.share > 1.0:
			found.append(
				"structure: a weak spot needs a name and a share of her strength within 0…1"
			)
		elif spot.x <= aft:
			found.append("structure: her weak spots must run aft to fore")
		else:
			aft = spot.x
	return found
