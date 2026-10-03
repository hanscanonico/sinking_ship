class_name WalkGraph
extends RefCounted
## The ship as a bot finds its way round it (§7). The nodes are zones: the layout's
## rooms, then its open decks — the platforms of one height that touch, outside every
## room. The edges are portals: the doorways in the rooms' walls and the ramps, so a
## path crosses a wall only through a doorway. A bot routes to a zone, then steers
## locally. What stands where, what a ramp joins and which points are wet it asks
## Surfaces; it never routes into a flooded zone, nor through a portal with an end
## under water.

const NONE := -1
## How far apart two platforms' edges may be and still meet: the data's rectangles
## are single precision.
const EDGE := 0.001


## One way from a zone into the next: through a doorway, or along a ramp.
class Portal:
	var from_zone: int
	var to_zone: int
	## Where it is entered and where it is left: a doorway's middle twice, a ramp's
	## two end points.
	var entry: Vector3
	var exit: Vector3
	## Unit vector in the ship plane, the way through.
	var along: Vector2
	var half_width: float
	## The layout's ramp it runs along, or NONE for a doorway.
	var ramp: int

	func _init(
		zones: Vector2i,
		entered_at: Vector3,
		left_at: Vector3,
		way: Vector2,
		width: float,
		ramp_index: int
	) -> void:
		from_zone = zones.x
		to_zone = zones.y
		entry = entered_at
		exit = left_at
		along = way
		half_width = width * 0.5
		ramp = ramp_index


## Every dry zone reachable from one place, and the cheapest way to each.
class Search:
	## Per zone, the distance walked to reach it, or INF.
	var cost := PackedFloat64Array()
	## Per zone, the portal it was reached through, or NONE where the search started.
	var came_by := PackedInt32Array()
	## Per zone, the zone that portal was entered from, or NONE.
	var came_from := PackedInt32Array()


var _surfaces: Surfaces
var _layout: ShipLayout
var _ramps: Array[ShipRamp] = []
## Per platform, the zone of the open deck it belongs to.
var _decks := PackedInt32Array()
var _zone_count := 0
var _portals: Array[Portal] = []
## Per zone, the portals leading out of it, in the order they were found.
var _out: Array[PackedInt32Array] = []
## Per ramp, the zones at its start and end ends, NONE where it joins nothing.
var _ramp_zones: Array[PackedInt32Array] = []
## Per ramp, its portals toward its start end and toward its end end, or NONE.
var _ramp_portals: Array[PackedInt32Array] = []
## A body's width: how far before a portal a bot lines up, and past it it aims.
var _lead: float
var _body_radius: float
var _step: float


func _init(layout: ShipLayout, surfaces: Surfaces, rules: BrawlRules) -> void:
	_surfaces = surfaces
	_layout = layout
	_ramps = layout.ramps.duplicate()
	_body_radius = rules.body_radius
	_step = rules.step_height
	_lead = rules.body_radius * 2.0
	_link_decks()
	_out.resize(_zone_count)
	for zone in _zone_count:
		_out[zone] = PackedInt32Array()
	_add_ramps()
	_add_doors(rules.body_height)


func zone_count() -> int:
	return _zone_count


## The zone of the open deck [param platform] belongs to.
func deck_of(platform: int) -> int:
	return _decks[platform]


## Every portal, in the order they were found.
func portals() -> Array[Portal]:
	return _portals


## The zone a body with its feet at [param ship_point] on [param surface] is in: the
## room holding it, else the open deck it stands on — a blocker top's footing for
## the top — and on a ramp, the zone at the end its feet are nearer in height. NONE
## when it stands on nothing.
func zone_at(ship_point: Vector3, surface: int) -> int:
	if surface == Surfaces.NONE:
		return NONE
	var footing := _surfaces.footing(surface)
	if footing == Surfaces.NONE:
		return NONE
	if _surfaces.is_ramp(footing):
		var ramp := _ramps[footing - _surfaces.platform_count()]
		var to_start := absf(ship_point.y - ramp.start_height)
		var nearer := 0 if to_start <= absf(ship_point.y - ramp.end_height) else 1
		return _ramp_zones[footing - _surfaces.platform_count()][nearer]
	return _zone_on(footing, Vector2(ship_point.x, ship_point.z))


## Whether [param zone] is under the water: a room when the middle of its floor is,
## an open deck when the middle of every platform of it is.
func flooded(zone: int, pose: ShipPose) -> bool:
	if zone < _layout.rooms.size():
		return _surfaces.wet(_room_middle(zone), pose)
	for platform in _decks.size():
		if _decks[platform] == zone and not _surfaces.flooded(platform, pose):
			return false
	return true


## How high [param zone] stands in the world under [param pose]: a room by the
## middle of its floor, an open deck by the highest middle of its platforms.
func world_height(zone: int, pose: ShipPose) -> float:
	if zone < _layout.rooms.size():
		return pose.world_height(_room_middle(zone))
	var highest := -INF
	for platform in _decks.size():
		if _decks[platform] == zone:
			highest = maxf(highest, _surfaces.world_height(platform, pose))
	return highest


## How high the lowest corner of [param zone]'s floor stands in the world under
## [param pose] — of a room's area, or of every platform of an open deck.
func lowest_world_height(zone: int, pose: ShipPose) -> float:
	var areas: Array[Rect2] = []
	var heights := PackedFloat64Array()
	if zone < _layout.rooms.size():
		areas.append(_layout.rooms[zone].area)
		heights.append(_layout.rooms[zone].floor_height)
	else:
		for platform in _decks.size():
			if _decks[platform] == zone:
				areas.append(_layout.platforms[platform].area)
				heights.append(_layout.platforms[platform].height)
	var lowest := INF
	for index in areas.size():
		var area := areas[index]
		for corner: Vector2 in [
			area.position,
			Vector2(area.end.x, area.position.y),
			area.end,
			Vector2(area.position.x, area.end.y)
		]:
			lowest = minf(lowest, pose.world_height(Vector3(corner.x, heights[index], corner.y)))
	return lowest


## The portals from a body on [param from_surface] at [param from_pos] to the zone
## [param goal], in order. Shortest by the distance walked; empty when already there,
## when either end is nowhere, or when every way ends in or crosses a flooded zone or
## a portal with an end under water.
func route(from_pos: Vector3, from_surface: int, goal: int, pose: ShipPose) -> Array[Portal]:
	var legs: Array[Portal] = []
	if goal == NONE or from_surface == Surfaces.NONE:
		return legs
	var search := _search(from_pos, from_surface, pose)
	if search.cost.is_empty() or search.cost[goal] == INF:
		return legs
	var zone := goal
	while search.came_by[zone] != NONE:
		legs.push_front(_portals[search.came_by[zone]])
		zone = search.came_from[zone]
		if zone == NONE:
			break
	return legs


## The zone standing highest in the world (world_height) of those a body on
## [param from_surface] at [param from_pos] can reach without crossing a flooded one
## — its own included; NONE when it stands on nothing.
func highest_reachable(from_pos: Vector3, from_surface: int, pose: ShipPose) -> int:
	var search := _search(from_pos, from_surface, pose)
	var best := NONE
	var best_height := -INF
	for zone in search.cost.size():
		if search.cost[zone] == INF:
			continue
		var height := world_height(zone, pose)
		if height > best_height:
			best = zone
			best_height = height
	return best


## Where a body on [param from_surface] at [param from_pos] walks next toward the
## zone [param goal]: one point, or none when there is no portal to go through.
func steer(from_pos: Vector3, from_surface: int, goal: int, pose: ShipPose) -> PackedVector3Array:
	var legs := route(from_pos, from_surface, goal, pose)
	if legs.is_empty():
		return PackedVector3Array()
	return PackedVector3Array([toward(legs[0], from_pos, from_surface)])


## Where a body on [param from_surface] at [param from_pos] walks next to go through
## [param leg]. Lined up in front of it, a point just past it; further out in front,
## a point a body's width further along its axis than the body is, so the walk
## closes on the axis rather than circling a point; beside it, the middle of its near
## edge, so the body turns in rather than doubling back. On the leg's ramp, the point
## past its far end.
func toward(leg: Portal, from_pos: Vector3, from_surface: int) -> Vector3:
	var along := Vector3(leg.along.x, 0.0, leg.along.y)
	var past := leg.exit + along * _lead
	if leg.ramp != NONE and from_surface == _surfaces.ramp_surface(leg.ramp):
		return past
	var offset := Vector2(from_pos.x - leg.entry.x, from_pos.z - leg.entry.z)
	var ahead := offset.dot(leg.along)
	var lined_up := absf(offset.cross(leg.along)) <= maxf(leg.half_width - _body_radius, 0.0)
	if lined_up and absf(ahead) <= _lead:
		return past
	if ahead < 0.0:
		return leg.entry + along * minf(ahead + _lead, 0.0)
	return leg.entry


## The open decks: platforms of one height whose areas meet along an edge share
## one zone, numbered after the rooms in the order of their first platform.
func _link_decks() -> void:
	var platforms := _layout.platforms
	var parent := PackedInt32Array()
	for index in platforms.size():
		parent.append(index)
	for first in platforms.size():
		for second in range(first + 1, platforms.size()):
			if _touch(platforms[first], platforms[second]):
				var a := _root(parent, first)
				var b := _root(parent, second)
				parent[maxi(a, b)] = mini(a, b)
	_zone_count = _layout.rooms.size()
	var zone_of_root := PackedInt32Array()
	zone_of_root.resize(platforms.size())
	zone_of_root.fill(NONE)
	for index in platforms.size():
		var root := _root(parent, index)
		if zone_of_root[root] == NONE:
			zone_of_root[root] = _zone_count
			_zone_count += 1
		_decks.append(zone_of_root[root])


## A portal each way along every ramp whose two ends join platforms.
func _add_ramps() -> void:
	for ramp in _ramps.size():
		var joined := _surfaces.joins(_surfaces.ramp_surface(ramp))
		var ends: Array[Vector3] = [_ramps[ramp].end_point(0), _ramps[ramp].end_point(1)]
		var zones := PackedInt32Array()
		for end in 2:
			if joined[end] == Surfaces.NONE:
				zones.append(NONE)
				continue
			var other := ends[1 - end]
			var outward := Vector2(ends[end].x - other.x, ends[end].z - other.z).normalized()
			zones.append(_zone_on(joined[end], Vector2(ends[end].x, ends[end].z) + outward * _lead))
		_ramp_zones.append(zones)
		var toward := PackedInt32Array([NONE, NONE])
		if zones[0] != NONE and zones[1] != NONE:
			var area := _ramps[ramp].area
			var width := area.size.y if _ramps[ramp].axis == ShipRamp.Axis.X else area.size.x
			for end in 2:
				var from := ends[1 - end]
				var way := Vector2(ends[end].x - from.x, ends[end].z - from.z).normalized()
				toward[end] = _add(
					Portal.new(
						Vector2i(zones[1 - end], zones[end]), from, ends[end], way, width, ramp
					)
				)
		_ramp_portals.append(toward)


## A portal out through every gap in a room's walls wide enough for a body that
## gives onto another zone, and back in from an open deck — a room's own scan adds
## the way back from a room.
func _add_doors(body_height: float) -> void:
	for room in _layout.rooms.size():
		var floor_height := _layout.rooms[room].floor_height
		for door: ShipRoom.Door in _layout.rooms[room].doors(_surfaces, body_height, _step):
			if door.width() < _body_radius * 2.0:
				continue
			var middle := door.middle()
			var beyond := middle + door.outward * _lead
			var outside := Vector3(beyond.x, floor_height, beyond.y)
			var surface := _surfaces.under(outside, _step)
			if surface == Surfaces.NONE or _surfaces.is_ramp(surface):
				continue
			var other := zone_at(outside, surface)
			if other == NONE or other == room:
				continue
			var at := Vector3(middle.x, floor_height, middle.y)
			_add(Portal.new(Vector2i(room, other), at, at, door.outward, door.width(), NONE))
			if other >= _layout.rooms.size():
				_add(Portal.new(Vector2i(other, room), at, at, -door.outward, door.width(), NONE))


func _add(portal: Portal) -> int:
	_portals.append(portal)
	_out[portal.from_zone].append(_portals.size() - 1)
	return _portals.size() - 1


## The zone at [param point] (x/z) on [param platform]: the room holding it there,
## else the platform's open deck.
func _zone_on(platform: int, point: Vector2) -> int:
	var feet := Vector3(point.x, _layout.platforms[platform].height, point.y)
	var room := _layout.room_at(feet, _step)
	return room if room != -1 else _decks[platform]


func _room_middle(room: int) -> Vector3:
	var middle := _layout.rooms[room].area.get_center()
	return Vector3(middle.x, _layout.rooms[room].floor_height, middle.y)


## Dijkstra over the zones from where a body stands — a zone, or both ends of the
## ramp it is on — never entering a flooded zone or going through a portal with an
## end under water; ties go to the lower zone number.
func _search(from_pos: Vector3, from_surface: int, pose: ShipPose) -> Search:
	var search := Search.new()
	search.cost.resize(_zone_count)
	search.cost.fill(INF)
	search.came_by.resize(_zone_count)
	search.came_by.fill(NONE)
	search.came_from.resize(_zone_count)
	search.came_from.fill(NONE)
	var arrived := PackedVector3Array()
	arrived.resize(_zone_count)
	var done := PackedByteArray()
	done.resize(_zone_count)
	var footing := _surfaces.footing(from_surface) if from_surface != Surfaces.NONE else NONE
	if footing == Surfaces.NONE:
		return search
	if _surfaces.is_ramp(footing):
		var ramp := footing - _surfaces.platform_count()
		for end in 2:
			var zone := _ramp_zones[ramp][end]
			var portal := _ramp_portals[ramp][end]
			var exit := _ramps[ramp].end_point(end)
			if portal == NONE or flooded(zone, pose) or _surfaces.wet(exit, pose):
				continue
			var cost := from_pos.distance_to(exit)
			if cost < search.cost[zone]:
				search.cost[zone] = cost
				search.came_by[zone] = portal
				arrived[zone] = exit
	else:
		var start := zone_at(from_pos, footing)
		search.cost[start] = 0.0
		arrived[start] = from_pos
	while true:
		var zone := NONE
		for index in _zone_count:
			if done[index] == 1 or search.cost[index] == INF:
				continue
			if zone == NONE or search.cost[index] < search.cost[zone]:
				zone = index
		if zone == NONE:
			break
		done[zone] = 1
		for index: int in _out[zone]:
			var portal := _portals[index]
			var other := portal.to_zone
			if done[other] == 1 or flooded(other, pose):
				continue
			if _surfaces.wet(portal.entry, pose) or _surfaces.wet(portal.exit, pose):
				continue
			var through := (
				search.cost[zone]
				+ arrived[zone].distance_to(portal.entry)
				+ portal.entry.distance_to(portal.exit)
			)
			if through < search.cost[other]:
				search.cost[other] = through
				search.came_by[other] = index
				search.came_from[other] = zone
				arrived[other] = portal.exit
	return search


## Whether two platforms stand at one height and their areas meet along an edge.
static func _touch(a: ShipPlatform, b: ShipPlatform) -> bool:
	if not is_equal_approx(a.height, b.height):
		return false
	var overlap_x := minf(a.area.end.x, b.area.end.x) - maxf(a.area.position.x, b.area.position.x)
	var overlap_z := minf(a.area.end.y, b.area.end.y) - maxf(a.area.position.y, b.area.position.y)
	return overlap_x >= -EDGE and overlap_z >= -EDGE and maxf(overlap_x, overlap_z) > EDGE


static func _root(parent: PackedInt32Array, index: int) -> int:
	while parent[index] != index:
		index = parent[index]
	return index
