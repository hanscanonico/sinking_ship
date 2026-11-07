class_name WalkDoors
extends RefCounted
## The walk graph's doorways (§7): per room the gaps in its walls a body fits through, the
## half nearer each room of a door's depth into another where that is in neither — a door
## through a bulkhead — and the portals through them, each where a body could go through
## (WayThrough.crossings). WalkGraph asks it for both as it is built, and of the depths as
## it puts a point in a zone (WalkGraph._zone_on).

const NONE := -1
## What _onto says of a point on a ramp.
const ON_A_RAMP := -2

var _layout: ShipLayout
var _surfaces: Surfaces
## A body's width: how far out through a doorway the zone it gives onto is read.
var _lead: float
var _radius: float
var _step: float
## Per room, the gaps in its walls wide enough for a body — crawling, crawl_height tall, if
## it must.
var _doors: Array[Array] = []
## Per door between two rooms whose depth is in neither — a door through a bulkhead, each
## room stopping at its own wall — the half of that depth nearer the room it leads out
## of, held as that room's: its floor's area, and the room.
var _depth_areas: Array[Rect2] = []
var _depth_rooms := PackedInt32Array()
## The pieces the graph reads its rooms' floors in: a doorway leads into the one a body's
## width inside it stands in.
var pieces: WalkPieces


func _init(layout: ShipLayout, surfaces: Surfaces, rules: BrawlRules) -> void:
	_layout = layout
	_surfaces = surfaces
	_lead = rules.body_radius * 2.0
	_radius = rules.body_radius
	_step = rules.step_height
	for room in layout.rooms.size():
		var wide: Array[ShipRoom.Door] = []
		for door: ShipRoom.Door in layout.rooms[room].doors(
			surfaces, rules.crawl_height, rules.step_height
		):
			if door.width() >= rules.body_radius * 2.0:
				wide.append(door)
		_doors.append(wide)


## The half nearer each room of the depth of every one of its doors onto another room —
## the floor between their walls, in neither: a door through a bulkhead — held as that
## room's (depth_room) before any portal is found, so a body standing in it has a way on;
## none where the two rooms meet. Each door is read against [param graph]'s zones with the
## depths found before it.
func find_depths(graph: WalkGraph) -> void:
	for room in _doors.size():
		for door: ShipRoom.Door in _doors[room]:
			var other := _gives_onto(graph, room, door)
			if other == NONE or graph.room_of(other) == NONE:
				continue
			var axis := 0 if door.outward.y == 0.0 else 1
			var past := _layout.rooms[graph.room_of(other)].area
			var edge := past.position[axis] if door.outward[axis] > 0.0 else past.end[axis]
			var depth := (edge - door.middle()[axis]) * door.outward[axis]
			if depth <= WalkGraph.EDGE:
				continue
			var half := door.from + door.outward * depth * 0.5
			_depth_areas.append(Rect2(door.from, Vector2.ZERO).expand(door.to).expand(half))
			_depth_rooms.append(room)


## The room whose half of a door's depth (find_depths) holds [param point] (x/z) on a floor
## at [param height], or NONE.
func depth_room(point: Vector2, height: float) -> int:
	for index in _depth_areas.size():
		var room := _depth_rooms[index]
		var level := absf(height - _layout.rooms[room].floor_height) <= _step
		if level and _depth_areas[index].has_point(point):
			return room
	return NONE


## A portal out through each of a room's doors for each zone of [param graph] it gives onto
## (_lanes), and back in from an open deck — a room's own scan adds the way back from a room
## —, each where a body could go through it that way within that zone's lane, nearest the
## door's middle (WayThrough.crossings), as wide as the lane; in the order they are found.
func portals(graph: WalkGraph, rules: BrawlRules) -> Array[WalkGraph.Portal]:
	var found: Array[WalkGraph.Portal] = []
	for room in _doors.size():
		var floor_height := _layout.rooms[room].floor_height
		for door: ShipRoom.Door in _doors[room]:
			var lanes := _lanes(graph, room, door)
			for lane in range(0, lanes.size(), 3):
				var other := int(lanes[lane])
				var low := lanes[lane + 1]
				var high := lanes[lane + 2]
				var deck := graph.room_of(other) == NONE
				var ways := 2 if deck else 1
				var offs := WayThrough.crossings(
					_surfaces, rules, door, floor_height, low, high, ways
				)
				for way in ways:
					if not is_nan(offs[way]):
						var at := WayThrough.across(door, offs[way], floor_height)
						var inside := Vector2(at.x, at.z) - door.outward * _lead
						var mine := pieces.zone(room, inside)
						var ends := Vector2i(mine, other) if way == 0 else Vector2i(other, mine)
						var out := door.outward if way == 0 else -door.outward
						var wide := 2.0 * minf(offs[way] - low, high - offs[way])
						found.append(WalkGraph.Portal.new(ends, at, at, out, wide, NONE))
	return found


## The zone of [param graph] that [param door] out of [param room] gives onto, a body's
## width out through it: read at its middle, then every WayThrough.STRIDE out from it either
## way as far as a body's radius in from each jamb, past where that is on nothing or on a
## ramp — a wide doorway's middle can give onto a stair beside the floor it opens onto. NONE
## where it is on nothing or a ramp all across, or is the room again.
func _gives_onto(graph: WalkGraph, room: int, door: ShipRoom.Door) -> int:
	var floor_height := _layout.rooms[room].floor_height
	var steps := floori(maxf(door.width() * 0.5 - _radius, 0.0) / WayThrough.STRIDE)
	for index in range(0, steps * 2 + 1):
		var off := WayThrough.STRIDE * ceili(index * 0.5) * (1.0 if index % 2 == 1 else -1.0)
		var other := _onto(graph, door, off, floor_height)
		if other != NONE and other != ON_A_RAMP:
			return NONE if graph.room_of(other) == room else other
	return NONE


## The lanes of [param door] out of [param room]: what a body's width out through it stands
## on, read every WayThrough.STRIDE across it as far as a body's radius in from each jamb, in
## runs of one zone of [param graph] each — a point on a ramp or on nothing (over a stair's
## hole) no zone's, so that a stair beside the floor a wide doorway opens onto splits it.
## Per run whose zone is not the room again, from the [code]from[/code] end: the zone, and
## the offsets from the door's middle its lane spans — to a jamb where the run reaches it,
## else half a STRIDE past its last point.
func _lanes(graph: WalkGraph, room: int, door: ShipRoom.Door) -> PackedFloat64Array:
	var floor_height := _layout.rooms[room].floor_height
	var steps := floori(maxf(door.width() * 0.5 - _radius, 0.0) / WayThrough.STRIDE)
	var onto := PackedInt32Array()
	for index in range(-steps, steps + 1):
		onto.append(_onto(graph, door, index * WayThrough.STRIDE, floor_height))
	var lanes := PackedFloat64Array()
	var half := door.width() * 0.5
	var gap := WayThrough.STRIDE * 0.5
	var first := 0
	for index in range(1, onto.size() + 1):
		if index < onto.size() and onto[index] == onto[first]:
			continue
		var zone := onto[first]
		if zone != ON_A_RAMP and zone != NONE and graph.room_of(zone) != room:
			var low := -half if first == 0 else (first - steps) * WayThrough.STRIDE - gap
			var last := index - 1
			var high := half if index == onto.size() else (last - steps) * WayThrough.STRIDE + gap
			lanes.append_array([zone, low, high])
		first = index
	return lanes


## The zone a body's width out through [param door] at [param off] from its middle stands
## in, else a body's radius out where that is on nothing (a floor turning a corner close
## past the door): NONE where both are on nothing, ON_A_RAMP on a ramp. Its feet are walked
## out from the door's line a step at a time: through a doorway onto a stair's foot a body
## walks up the stair, never onto the deck under it, inside the stair's solid.
func _onto(graph: WalkGraph, door: ShipRoom.Door, off: float, floor_height: float) -> int:
	var at := WayThrough.across(door, off, floor_height)
	var outside := Vector3.ZERO
	var surface := Surfaces.NONE
	for lead: float in [_lead, _radius]:
		var beyond := Vector2(at.x, at.z) + door.outward * lead
		outside = Vector3(beyond.x, _feet(at, beyond), beyond.y)
		surface = _surfaces.under(outside, _step)
		if surface != Surfaces.NONE:
			break
	if surface == Surfaces.NONE:
		return NONE
	if _surfaces.is_ramp(surface):
		return ON_A_RAMP
	return graph.zone_at(outside, surface)


## How high the feet of a walk from [param from] straight to [param to] (x/z) come, a step at
## a time, as BotFooting.feet_at walks them: up a stair from its foot, onto it. Where the
## walk leaves every surface, the height they had there.
func _feet(from: Vector3, to: Vector2) -> float:
	var start := Vector2(from.x, from.z)
	var samples := maxi(1, ceili(start.distance_to(to) / _step))
	var feet := from.y
	for index in range(1, samples + 1):
		var at := start.lerp(to, float(index) / samples)
		var point := Vector3(at.x, feet, at.y)
		var surface := _surfaces.under(point, _step)
		if surface == Surfaces.NONE:
			break
		feet = _surfaces.height_at(surface, point)
	return feet
