class_name WalkDoors
extends RefCounted
## The walk graph's doorways (§7): per room the gaps in its walls a body fits through, the
## half nearer each room of a door's depth into another where that is in neither — a door
## through a bulkhead — and the portals through them, each where a body could go through
## (WayThrough.crossings). WalkGraph asks it for both as it is built, and of the depths as
## it puts a point in a zone (WalkGraph._zone_on).

const NONE := -1

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
			if other == NONE or other >= _layout.rooms.size():
				continue
			var axis := 0 if door.outward.y == 0.0 else 1
			var past := _layout.rooms[other].area
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


## A portal out through each of a room's doors that gives onto another of [param graph]'s
## zones, and back in from an open deck — a room's own scan adds the way back from a room —,
## each where a body could go through it that way, nearest its middle
## (WayThrough.crossings); in the order they are found.
func portals(graph: WalkGraph, rules: BrawlRules) -> Array[WalkGraph.Portal]:
	var found: Array[WalkGraph.Portal] = []
	for room in _doors.size():
		var floor_height := _layout.rooms[room].floor_height
		for door: ShipRoom.Door in _doors[room]:
			var other := _gives_onto(graph, room, door)
			if other == NONE:
				continue
			var deck := other >= _layout.rooms.size()
			var offs := WayThrough.crossings(_surfaces, rules, door, floor_height)
			for way in 2 if deck else 1:
				if not is_nan(offs[way]):
					var at := WayThrough.across(door, offs[way], floor_height)
					var ends := Vector2i(room, other) if way == 0 else Vector2i(other, room)
					var out := door.outward if way == 0 else -door.outward
					var wide := door.width() - absf(offs[way]) * 2.0
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
		var at := WayThrough.across(door, off, floor_height)
		var beyond := Vector2(at.x, at.z) + door.outward * _lead
		var outside := Vector3(beyond.x, floor_height, beyond.y)
		var surface := _surfaces.under(outside, _step)
		if surface == Surfaces.NONE or _surfaces.is_ramp(surface):
			continue
		var other := graph.zone_at(outside, surface)
		return NONE if other == room else other
	return NONE
