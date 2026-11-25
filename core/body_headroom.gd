class_name BodyHeadroom
extends RefCounted
## The room a swimmer has under what is over its head (Surfaces.ceiling, D6), asked the one
## way by all of Movement that floats one: where it rests, and what stops it rising.

## How far apart a swimmer looks for a ceiling along the way it swims, out to where its
## circle reaches next (swimming): half the thinnest lintel, so none slips between.
const DUCK_LOOK := 0.1


## The highest a swimmer of [param rules] with its feet at [param from] — where they are
## in x/z, at the height they came from — may be, as [param surfaces] has her: its
## [param height] under the lowest deck over its head (Surfaces.ceiling) — and, swimming
## [param heading], under the lowest along the way to where its circle reaches next, so it
## ducks under a lintel or a deck's edge it swims into: through a flooded doorway into the
## next cell, to surface there. Not under one it floats over — stand_depth under its water
## at [param sea] — nor one too low for a body over [param bottom]. Under a deck the sea is
## filling, it stays under that deck as the water closes over its head; a head pressed
## into the deck — by as little as its feet's height rounds up, CLEARANCE_SLACK under it —
## would be pushed out sideways by it, through a wall or the hull. Its bottom is under it:
## come from deeper water over the edge of a flooded deck, more than a step under that
## deck's top, it is on that deck (Movement.come_to_rest lifts it there) and looks for what
## is over its head from there — that deck is its floor, never a ceiling to be put under.
static func swimming(
	surfaces: Surfaces,
	rules: BrawlRules,
	from: Vector3,
	heading: Vector2,
	sea: float,
	bottom: float,
	height: float
) -> float:
	var body := height + Surfaces.CLEARANCE_SLACK
	var feet := Vector3(from.x, maxf(from.y, bottom), from.z)
	var room := surfaces.ceiling(feet, rules.step_height) - body
	if heading == Vector2.ZERO:
		return room
	var reach := rules.body_radius + rules.swim_speed * Ticks.SECONDS_PER_TICK
	var looks := ceili(reach / DUCK_LOOK)
	for look in range(1, looks + 1):
		var ahead := feet + Vector3(heading.x, 0.0, heading.y) * (reach * look / looks)
		var over := surfaces.ceiling(ahead, rules.step_height)
		if over > sea - rules.stand_depth and over - body >= bottom:
			room = minf(room, over - body)
	return room
