class_name WayThrough
extends RefCounted
## Where the walk graph's portals stand, so that a route goes where a body could get through
## (§7, #501). Along a flight, no other flight over it takes a body off it, no solid stands in
## its run, and it has the headroom to crawl at least. Through a
## doorway one way, somewhere across its width a body BotFloorWay.SNUG of its radius round
## stands on its floor a body's depth inside, clear of everything the sim holds a body back
## by, and walks straight out as deep past its line with nothing pushing it back the way it
## came. It stands on the side it comes from, not first past the line: a stair run on under
## a doorway, down in its well under the floor, is no way out of the room whose floor its
## railings fence off (#551). WalkDoors asks too that it stands in the zone the way leads out
## of, and comes to stand in the one it leads into: on a stair a body is in the zone of the
## end it is nearer, so a stair run on through a doorway is no way into the room past it
## either (#575). Standing on the line it stands a hair on the room's side: a stair's head or
## another room's floor that begins there is not the room's (#561). The sim holds a body on a
## stair by the railings along its sides by its head (#552), and so is it held here.
##
## Where neither is true, a route through walks a bot into it for good: there is no way round
## to find, so the graph leaves it out. Two flights stacked in one well, the lower one under
## the upper's wedge: a body walking down the upper one walks on along the lower one's head.
## A flight under a deck too low to crawl under, or with a solid standing in its run (the
## layout lint holds every ship to none of either, test_every_flight_is_walked_end_to_end,
## #541). A railing holds a body only from its own
## deck's side, so a doorway onto a railed hole's edge lets a body out onto her open deck,
## pushed on its way, and never back in. A stair's high end in a doorway, machinery or
## furniture against it, a railing in a doorway between two rooms. The layout lint holds
## every ship's rooms to a way out and back in that a body takes (#514), so none is sealed
## off the graph by what it leaves out (test_no_sealed_room). Asked of Surfaces once, as the
## graph is built, before any crate or broken railing is honoured.

## How far apart along a flight's middle, and across a doorway, a body is tried, in metres.
const STRIDE := 0.125
## How far apart across a doorway a body is tried again where no body got through it every
## STRIDE: a way through can lie between them (No. 1 hold's join on the orlop, #514).
const FINE := 0.03125
## How much higher than the flight another flight must stand over a point of it to take a
## body off it there: two flights meeting end to end at one height do not.
const OVER := 0.01
## How far a contact's normal may turn against a body's way through a doorway, as a cosine,
## before it pushes the body back: a jamb's, square across the way, does not.
const BACK := 0.5
## How much of a body's radius round its feet a flight's middle is looked at by for a solid
## standing in its run (solid_in), as BotFooting.walled looks: the sides of a ladder's well a
## body's width wide stand clear of it.
const INSIDE := 0.1
## How far on the room's side of a doorway's line a body standing on it is read: the floor
## there is the room's, not one that begins at the line.
const HAIR := 0.001


## Whether a body could walk [param layout]'s ramp [param index] from end to end along its
## middle (flight_fault), its feet standing in nothing anywhere along it (solid_in).
static func flight(surfaces: Surfaces, rules: BrawlRules, layout: ShipLayout, index: int) -> bool:
	return (
		flight_fault(surfaces, rules, layout, index) == ""
		and solid_in(surfaces, rules, layout, index) == Vector3.INF
	)


## The first point along [param layout]'s ramp [param index]'s middle, every STRIDE, where a
## body's feet would stand inside something that holds it back (Surfaces.obstacle_contacts,
## as BotFooting.walled asks it): a solid standing in the flight's run, its top more than a
## step over the flight there — a body walking down it walks into its face, and up it into
## its other one; Vector3.INF where nothing does.
static func solid_in(
	surfaces: Surfaces, rules: BrawlRules, layout: ShipLayout, index: int
) -> Vector3:
	for feet: Vector3 in _along(layout.ramps[index]):
		var contacts := surfaces.obstacle_contacts(
			feet,
			rules.body_radius * INSIDE,
			rules.body_height,
			rules.step_height,
			Surfaces.NONE,
			rules.crawl_height,
			rules.body_radius
		)
		if not contacts.is_empty():
			return feet
	return Vector3.INF


## Why no body could walk [param layout]'s ramp [param index] from end to end along its
## middle, or "" when one could: taken off it onto a higher flight between its ends
## (Surfaces.under), else, somewhere along it, too little headroom over it even to crawl.
static func flight_fault(
	surfaces: Surfaces, rules: BrawlRules, layout: ShipLayout, index: int
) -> String:
	var surface := surfaces.ramp_surface(index)
	var points := _along(layout.ramps[index])
	for feet: Vector3 in points:
		var on := surfaces.under(feet, rules.step_height)
		if (
			on != surface
			and on != Surfaces.NONE
			and surfaces.is_ramp(on)
			and surfaces.height_at(on, feet) > feet.y + OVER
		):
			return "stacked under another flight"
	for feet: Vector3 in points:
		var over := surfaces.ceiling(feet, rules.step_height) - feet.y
		if over < rules.crawl_height:
			return "%.2f m over %s, too low to crawl" % [over, feet]
	return ""


## The points along [param ramp]'s middle a body is tried at, every STRIDE between its ends.
static func _along(ramp: ShipRamp) -> PackedVector3Array:
	var along_x := ramp.axis == ShipRamp.Axis.X
	var length := ramp.area.size.x if along_x else ramp.area.size.y
	var middle := ramp.area.get_center()
	var steps := ceili(length / STRIDE)
	var points := PackedVector3Array()
	for step in range(1, steps):
		var share := float(step) / steps
		var x := ramp.area.position.x + ramp.area.size.x * share if along_x else middle.x
		var z := middle.y if along_x else ramp.area.position.y + ramp.area.size.y * share
		points.append(Vector3(x, ramp.height_at(x, z), z))
	return points


## Where the walk graph's portals through [param door], out of its room's floor at
## [param floor_height] and back in, stand: as offsets from its middle toward its
## [code]to[/code] end (doorway), tried every STRIDE across it, then, where no body got
## through, every FINE; only offsets from [param low] to [param high] — the lane of a wide
## doorway that gives onto the floor past it, not onto a stair beside it (WalkDoors); NAN
## for a way no body goes, which the graph leaves out. Only the way out where [param ways]
## is 1. Each way begins only where [param begins] lets it (_crosses).
static func crossings(
	surfaces: Surfaces,
	rules: BrawlRules,
	door: ShipRoom.Door,
	floor_height: float,
	low := -INF,
	high := INF,
	ways := 2,
	begins := Callable()
) -> PackedFloat64Array:
	var offs := PackedFloat64Array()
	for out: Vector2 in [door.outward, -door.outward].slice(0, ways):
		var off := doorway(
			surfaces, rules, door, floor_height, out, true, STRIDE, low, high, begins
		)
		if is_nan(off):
			off = doorway(surfaces, rules, door, floor_height, out, true, FINE, low, high, begins)
		offs.append(off)
	return offs


## Where along [param door] a body could go out through it from its room's floor at
## [param floor_height] the way [param out] (its outward, or back in): how far from its
## middle toward its [code]to[/code] end, tried at the middle, then every [param stride] out
## from it either way, as far as a body's radius in from each jamb (_crosses), and only from
## [param low] to [param high], held back by railings too unless [param rails] is false, and
## beginning only where [param begins] lets it (_crosses); NAN where nowhere. A
## [param stride] finer than STRIDE skips the points STRIDE apart, which crossings has tried
## already.
static func doorway(
	surfaces: Surfaces,
	rules: BrawlRules,
	door: ShipRoom.Door,
	floor_height: float,
	out: Vector2,
	rails := true,
	stride := STRIDE,
	low := -INF,
	high := INF,
	begins := Callable()
) -> float:
	var room := maxf(door.width() * 0.5 - rules.body_radius, 0.0)
	var steps := floori(room / stride)
	for index in range(0, steps * 2 + 1):
		var off := stride * ceili(index * 0.5) * (1.0 if index % 2 == 1 else -1.0)
		if off < low or off > high or (stride < STRIDE and is_zero_approx(fmod(off, STRIDE))):
			continue
		var at := across(door, off, floor_height)
		if _crosses(surfaces, rules, Vector2(at.x, at.z), out, floor_height, rails, begins):
			return off
	return NAN


## The point on [param door]'s line [param off] from its middle toward its
## [code]to[/code] end, at [param floor_height].
static func across(door: ShipRoom.Door, off: float, floor_height: float) -> Vector3:
	var at := door.middle() + (door.to - door.from).normalized() * off
	return Vector3(at.x, floor_height, at.y)


## Whether a body could walk straight through [param at] on a doorway's line the way
## [param out]: from where it first stands clear on the room's side — a body's radius before
## the line at most, every STRIDE nearer, on the line at the last, a HAIR on the room's side
## of it, never first past it — on until it stands clear past it, its feet on a floor or a
## stair all the way and nothing pushing it back (BACK); the railings the sim holds it by
## among what holds it unless [param rails] is false: a floor's own, and on a stair those
## along its sides by its head (Surfaces.rail_contacts, #552, #561). Where [param begins] is
## a callable, it stands there only where begins(feet, surface, out) is true — in the zone
## the way leads out of (WalkDoors._begins) — and clear past the line only where
## begins(feet, surface, -out) is: where the way back would begin, in the zone it leads into.
static func _crosses(
	surfaces: Surfaces,
	rules: BrawlRules,
	at: Vector2,
	out: Vector2,
	floor_height: float,
	rails: bool,
	begins: Callable
) -> bool:
	var radius := rules.body_radius * BotFloorWay.SNUG
	var depth := ceili(rules.body_radius / STRIDE)
	var feet := floor_height
	var stood := false
	for step in range(-depth, depth + 1):
		var flat := at + out * (STRIDE * step)
		if step == 0 and not stood:
			flat -= out * HAIR
		var point := Vector3(flat.x, feet, flat.y)
		var surface := surfaces.under(point, rules.step_height)
		if surface == Surfaces.NONE:
			if stood or step >= 0:
				return false
			continue
		point.y = surfaces.height_at(surface, point)
		var held := surfaces.obstacle_contacts(
			point, radius, rules.body_height, rules.step_height, Surfaces.NONE, rules.crawl_height
		)
		if rails:
			held.append_array(
				surfaces.rail_contacts(
					point, radius, surface, rules.step_height, rules.railing_height
				)
			)
		if (
			stood
			and step > 0
			and held.is_empty()
			and (not begins.is_valid() or begins.call(point, surface, -out))
		):
			return true
		if not stood:
			stood = held.is_empty() and (not begins.is_valid() or begins.call(point, surface, out))
			if not stood and step == 0:
				return false
			feet = point.y if stood else feet
			continue
		feet = point.y
		for contact: Surfaces.Contact in held:
			if contact.normal.dot(out) < -BACK:
				return false
	return false
