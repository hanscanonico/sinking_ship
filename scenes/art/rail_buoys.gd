class_name RailBuoys
extends RefCounted
## Lifebuoys hung on her side railings (ShipArt), placed by rules on the layout: along each
## side, fore to aft, one on each railing span facing the sea that stands at least
## BUOY_EVERY aft of the last, long enough to hang one between two of its posts and clear of
## a boarding ladder. The ring hangs on the span's outboard face between the two posts
## nearest its middle, its top under the cap rail, and is drawn into the span's own piece:
## a railing that breaks takes its buoy with it, and the opening it leaves stands open. Out
## past the deck's edge it stands no further than its grab line, short of where art-lint
## looks for a false floor.

## How far apart along a side, at least, two buoys hang; the shortest span one hangs on.
const BUOY_EVERY := 9.0
const SPAN_LEAST := 1.6
## How far under the cap rail's underside the ring's top hangs, and how far out of the
## railing's line its back stands, clear of the posts and the middle rail.
const UNDER_CAP := 0.03
const OUT := 0.035
## How near a boarding ladder's rungs, along the deck's edge, no buoy hangs.
const CLEAR_OF_LADDER := 1.5


## Per railing of [param space]'s ship, by index, that carries a buoy: [its ring's middle,
## the normal out of her side it faces], the railings [param railing_height] tall.
static func of(space: ShipSpace, railing_height: float) -> Dictionary:
	var layout := space.layout
	var found := {}
	for side: float in [-1.0, 1.0]:
		var spans: Array[Vector2] = []
		for index in layout.railings.size():
			var at := _sea_facing(space, index, side)
			if not is_nan(at):
				spans.append(Vector2(at, index))
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x > b.x)
		var last := INF
		for span: Vector2 in spans:
			var index := int(span.y)
			var hung := _hung(layout, index, railing_height, side)
			var along: float = (hung[0] as Vector3).x
			if last - along < BUOY_EVERY:
				continue
			found[index] = hung
			last = along
	return found


## The middle along her of railing [param index] of [param space]'s ship when it runs fore
## and aft on her [param side] (1 starboard, -1 port) along the outermost of her decks
## there, open to the sky, long enough for a buoy and clear of every ladder; NAN when not.
static func _sea_facing(space: ShipSpace, index: int, side: float) -> float:
	var layout := space.layout
	var railing := layout.railings[index]
	var z := railing.from.y
	if not is_equal_approx(z, railing.to.y) or signf(z) != side:
		return NAN
	if absf(railing.to.x - railing.from.x) < SPAN_LEAST:
		return NAN
	var middle := (railing.from.x + railing.to.x) * 0.5
	var outline := space.envelope(middle)
	if outline.x == INF or not is_equal_approx(outline.y if side > 0.0 else outline.x, z):
		return NAN
	var deck := layout.platforms[railing.platform].height
	if not space.outdoors(Vector3(middle, deck + 0.5, z - side * 0.5)):
		return NAN
	for ladder: ShipLadder in layout.ladders:
		if not is_equal_approx(ladder.from.y, z):
			continue
		var low := minf(ladder.from.x, ladder.to.x) - CLEAR_OF_LADDER
		var high := maxf(ladder.from.x, ladder.to.x) + CLEAR_OF_LADDER
		if minf(railing.from.x, railing.to.x) < high and maxf(railing.from.x, railing.to.x) > low:
			return NAN
	return middle


## Where railing [param index]'s buoy hangs: [its ring's middle, its normal], between the
## two posts nearest the span's middle (ShipArt draws one every POST_SPACING), its top
## UNDER_CAP under the cap rail of a railing [param railing_height] tall.
static func _hung(layout: ShipLayout, index: int, railing_height: float, side: float) -> Array:
	var railing := layout.railings[index]
	var deck := layout.platforms[railing.platform].height
	var span := railing.to - railing.from
	var posts := maxi(1, ceili(span.length() / ShipArt.POST_SPACING))
	var between := (floorf((posts - 1) * 0.5) + 0.5) / posts
	var along := railing.from + span * between
	var height := (
		deck + railing_height - ShipArt.RAIL_DEPTH - UNDER_CAP - RoomDressing.LIFEBELT_RADIUS
	)
	var normal := Vector3(0.0, 0.0, side)
	return [Vector3(along.x, height, along.y + side * OUT), normal]
