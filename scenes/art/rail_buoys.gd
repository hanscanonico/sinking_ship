class_name RailBuoys
extends RefCounted
## Lifebuoys on her side railings (#273): which spans one may hang on, and how it hangs.
## Where each hangs is her layout's — a lifebuoy prop on a span its generator names — and
## the layout lint holds every station to the rule here: a span facing the sea, running
## fore and aft along her outermost deck there, open to the sky, long enough to hang one
## between two of its posts and clear of a boarding ladder. The ring hangs on the span's
## outboard face, its top under the cap rail (PropPlacing), as a prop the match moves:
## gone into the sea with its span. Out past the deck's edge it stands no further than its
## grab line, short of where art-lint looks for a false floor.

## The shortest span a ring hangs on.
const SPAN_LEAST := 1.6
## How far under the cap rail's underside the ring's top hangs, and how far out of the
## railing's line its back stands, clear of the posts and the middle rail.
const UNDER_CAP := 0.03
const OUT := 0.035
## How near a boarding ladder's rungs, along the deck's edge, no ring hangs.
const CLEAR_OF_LADDER := 1.5


## Whether railing [param index] of [param space]'s ship faces the sea: it runs fore and
## aft along the outermost of her decks there, open to the sky, long enough for a ring,
## and clear of every ladder.
static func sea_facing(space: ShipSpace, index: int) -> bool:
	var layout := space.layout
	var railing := layout.railings[index]
	var z := railing.from.y
	if not is_equal_approx(z, railing.to.y) or z == 0.0:
		return false
	if absf(railing.to.x - railing.from.x) < SPAN_LEAST:
		return false
	var side := signf(z)
	var middle := (railing.from.x + railing.to.x) * 0.5
	var outline := space.envelope(middle)
	if outline.x == INF or not is_equal_approx(outline.y if side > 0.0 else outline.x, z):
		return false
	var deck := layout.platforms[railing.platform].height
	if not space.outdoors(Vector3(middle, deck + 0.5, z - side * 0.5)):
		return false
	for ladder: ShipLadder in layout.ladders:
		if not is_equal_approx(ladder.from.y, z):
			continue
		var low := minf(ladder.from.x, ladder.to.x) - CLEAR_OF_LADDER
		var high := maxf(ladder.from.x, ladder.to.x) + CLEAR_OF_LADDER
		if minf(railing.from.x, railing.to.x) < high and maxf(railing.from.x, railing.to.x) > low:
			return false
	return true
