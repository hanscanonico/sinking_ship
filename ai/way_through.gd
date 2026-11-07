class_name WayThrough
extends RefCounted
## Where the walk graph's portals stand, so that a route goes where a body could get through
## (§7, #501). Along a flight, no other flight over it takes a body off it. Through a
## doorway one way, somewhere across its width a body BotFloorWay.SNUG of its radius round
## stands on its floor a body's depth inside, clear of everything the sim holds a body back
## by, and walks straight out as deep past its line with nothing pushing it back the way it
## came.
##
## Where neither is true, a route through walks a bot into it for good: there is no way round
## to find. Two flights stacked in one well, the lower one under the upper's wedge: a body
## walking down the upper one walks on along the lower one's head (the layout lint holds
## every ship's flights clear of it since #514). A railing holds a body only from its own
## deck's side, so a doorway onto a railed hole's edge lets a body out onto her open deck,
## pushed on its way, and never back in, as the Titanic's do. Neither is a way for the graph.
## Where something else holds a body back — a stair's high end in a doorway, machinery or
## furniture against it, a railing in a doorway between two rooms — the layout is at fault
## (#514), and the portal stays where it always stood, so that no room is sealed off the
## graph (test_no_sealed_room). Asked of Surfaces once, as the graph is built, before any
## crate or broken railing is honoured.

## How far apart along a flight's middle, and across a doorway, a body is tried, in metres.
const STRIDE := 0.125
## How much higher than the flight another flight must stand over a point of it to take a
## body off it there: two flights meeting end to end at one height do not.
const OVER := 0.01
## How far a contact's normal may turn against a body's way through a doorway, as a cosine,
## before it pushes the body back: a jamb's, square across the way, does not.
const BACK := 0.5


## Whether a body could walk [param layout]'s ramp [param index] from end to end along its
## middle, never taken off it onto a higher flight between its ends (Surfaces.under).
static func flight(surfaces: Surfaces, rules: BrawlRules, layout: ShipLayout, index: int) -> bool:
	var ramp := layout.ramps[index]
	var surface := surfaces.ramp_surface(index)
	var along_x := ramp.axis == ShipRamp.Axis.X
	var length := ramp.area.size.x if along_x else ramp.area.size.y
	var middle := ramp.area.get_center()
	var steps := ceili(length / STRIDE)
	for step in range(1, steps):
		var share := float(step) / steps
		var x := ramp.area.position.x + ramp.area.size.x * share if along_x else middle.x
		var z := middle.y if along_x else ramp.area.position.y + ramp.area.size.y * share
		var feet := Vector3(x, ramp.height_at(x, z), z)
		var on := surfaces.under(feet, rules.step_height)
		if (
			on != surface
			and on != Surfaces.NONE
			and surfaces.is_ramp(on)
			and surfaces.height_at(on, feet) > feet.y + OVER
		):
			return false
	return true


## Where the walk graph's portals through [param door], out of its room's floor at
## [param floor_height] and back in, stand: as offsets from its middle toward its
## [code]to[/code] end (doorway). NAN for a way a railing holds a body back from, and none
## else does, through a doorway onto her open deck ([param deck]); the middle for any other
## way a body is held back from.
static func crossings(
	surfaces: Surfaces, rules: BrawlRules, door: ShipRoom.Door, floor_height: float, deck: bool
) -> PackedFloat64Array:
	var offs := PackedFloat64Array()
	for out: Vector2 in [door.outward, -door.outward]:
		var off := doorway(surfaces, rules, door, floor_height, out)
		if (
			is_nan(off)
			and (not deck or is_nan(doorway(surfaces, rules, door, floor_height, out, false)))
		):
			off = 0.0
		offs.append(off)
	return offs


## Where along [param door] a body could go out through it from its room's floor at
## [param floor_height] the way [param out] (its outward, or back in): how far from its
## middle toward its [code]to[/code] end, tried at the middle, then every STRIDE out from it
## either way, as far as a body's radius in from each jamb (_crosses), held back by railings
## too unless [param rails] is false; NAN where nowhere.
static func doorway(
	surfaces: Surfaces,
	rules: BrawlRules,
	door: ShipRoom.Door,
	floor_height: float,
	out: Vector2,
	rails := true
) -> float:
	var room := maxf(door.width() * 0.5 - rules.body_radius, 0.0)
	var steps := floori(room / STRIDE)
	for index in range(0, steps * 2 + 1):
		var off := STRIDE * ceili(index * 0.5) * (1.0 if index % 2 == 1 else -1.0)
		var at := across(door, off, floor_height)
		if _crosses(surfaces, rules, Vector2(at.x, at.z), out, floor_height, rails):
			return off
	return NAN


## The point on [param door]'s line [param off] from its middle toward its
## [code]to[/code] end, at [param floor_height].
static func across(door: ShipRoom.Door, off: float, floor_height: float) -> Vector3:
	var at := door.middle() + (door.to - door.from).normalized() * off
	return Vector3(at.x, floor_height, at.y)


## Whether a body could walk straight through [param at] on a doorway's line the way
## [param out]: from where it first stands clear on the room's side — a body's radius before
## the line at most, every STRIDE nearer — on until it stands clear past it, its feet on a
## floor or a stair all the way and nothing pushing it back (BACK); railings among what
## holds it unless [param rails] is false.
static func _crosses(
	surfaces: Surfaces,
	rules: BrawlRules,
	at: Vector2,
	out: Vector2,
	floor_height: float,
	rails: bool
) -> bool:
	var radius := rules.body_radius * BotFloorWay.SNUG
	var depth := ceili(rules.body_radius / STRIDE)
	var feet := floor_height
	var stood := false
	for step in range(-depth, depth + 1):
		var flat := at + out * (STRIDE * step)
		var point := Vector3(flat.x, feet, flat.y)
		var surface := surfaces.under(point, rules.step_height)
		if surface == Surfaces.NONE:
			if stood:
				return false
			continue
		point.y = surfaces.height_at(surface, point)
		var held := surfaces.obstacle_contacts(
			point, radius, rules.body_height, rules.step_height, Surfaces.NONE, rules.crawl_height
		)
		if rails:
			held.append_array(surfaces.rail_contacts(point, radius, surface))
		if stood and step > 0 and held.is_empty():
			return true
		if not stood:
			stood = held.is_empty()
			if not stood and step == 0:
				return false
			feet = point.y if stood else feet
			continue
		feet = point.y
		for contact: Surfaces.Contact in held:
			if contact.normal.dot(out) < -BACK:
				return false
	return false
