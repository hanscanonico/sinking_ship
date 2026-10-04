class_name WalkGraph
extends RefCounted
## The ship as a bot finds its way round it (§7). The nodes are zones: the layout's
## rooms, then its open decks — the platforms of one height that touch, outside every
## room. The edges are portals: the doorways in the rooms' walls and the ramps, so a
## path crosses a wall only through a doorway. A bot routes to a zone, then steers
## locally. What stands where, what a ramp joins and which points are wet it asks
## Surfaces; it never routes into a flooded zone or one giving way, nor through a
## portal with an end under water — but for a swimmer's way ashore, which swims them.

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


## Every dry zone reachable from one place, and the cheapest way to each: what one
## search finds, for route_in and highest_in to read as often as they like.
class Search:
	## Per zone, the distance walked to reach it, or INF.
	var cost := PackedFloat64Array()
	## Per zone, the portal it was reached through, or NONE where the search started.
	var came_by := PackedInt32Array()
	## Per zone, the zone that portal was entered from, or NONE.
	var came_from := PackedInt32Array()


## The zones a search has still to settle, cheapest first, ties to the lower zone: a
## binary heap of (cost, zone).
class OpenSet:
	var _costs := PackedFloat64Array()
	var _zones := PackedInt32Array()

	func is_empty() -> bool:
		return _zones.is_empty()

	func push(cost: float, zone: int) -> void:
		var at := _zones.size()
		_costs.append(cost)
		_zones.append(zone)
		while at > 0:
			var parent := (at - 1) >> 1
			var above := _costs[parent]
			if above < cost or above == cost and _zones[parent] < zone:
				break
			_costs[at] = above
			_zones[at] = _zones[parent]
			at = parent
		_costs[at] = cost
		_zones[at] = zone

	func pop() -> int:
		var top := _zones[0]
		var last := _zones.size() - 1
		var cost := _costs[last]
		var zone := _zones[last]
		_costs.resize(last)
		_zones.resize(last)
		if last == 0:
			return top
		var at := 0
		while true:
			var child := at * 2 + 1
			if child >= last:
				break
			var right := child + 1
			if (
				right < last
				and (
					_costs[right] < _costs[child]
					or _costs[right] == _costs[child] and _zones[right] < _zones[child]
				)
			):
				child = right
			if cost < _costs[child] or cost == _costs[child] and zone < _zones[child]:
				break
			_costs[at] = _costs[child]
			_zones[at] = _zones[child]
			at = child
		_costs[at] = cost
		_zones[at] = zone
		return top


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
## Per open deck, its platforms; empty for a room.
var _zone_platforms: Array[PackedInt32Array] = []
## Per platform, the rooms standing on it, in layout order: the only ones a body on it
## can be in.
var _platform_rooms: Array[PackedInt32Array] = []
## What the last pose asked about says of each zone and portal, worked out the first
## time it is asked — 0 not yet, 1 no, 2 yes — so a tick pays for each answer once,
## however many bots share the graph.
## A pose is a value: one handed in is never changed afterwards.
var _pose_known: ShipPose
var _flooded := PackedByteArray()
var _doomed := PackedByteArray()
var _portal_wet := PackedByteArray()
## Per zone under that pose: how high it stands, and its floor's lowest corner; NAN
## until asked.
var _heights := PackedFloat64Array()
var _lowest := PackedFloat64Array()
## Per portal, what a search reads of it, laid out flat.
var _portal_to := PackedInt32Array()
var _portal_entry := PackedVector3Array()
var _portal_exit := PackedVector3Array()
var _portal_length := PackedFloat64Array()


func _init(layout: ShipLayout, surfaces: Surfaces, rules: BrawlRules) -> void:
	_surfaces = surfaces
	_layout = layout
	_ramps = layout.ramps.duplicate()
	_body_radius = rules.body_radius
	_step = rules.step_height
	_lead = rules.body_radius * 2.0
	for platform: ShipPlatform in layout.platforms:
		var rooms := PackedInt32Array()
		for room in layout.rooms.size():
			if (
				absf(layout.rooms[room].floor_height - platform.height) <= _step
				and layout.rooms[room].area.intersects(platform.area, true)
			):
				rooms.append(room)
		_platform_rooms.append(rooms)
	_link_decks()
	_out.resize(_zone_count)
	_zone_platforms.resize(_zone_count)
	for zone in _zone_count:
		_out[zone] = PackedInt32Array()
		_zone_platforms[zone] = PackedInt32Array()
	for platform in _decks.size():
		_zone_platforms[_decks[platform]].append(platform)
	_add_ramps()
	_add_doors(rules.body_height)
	_flooded.resize(_zone_count)
	_doomed.resize(_zone_count)
	_heights.resize(_zone_count)
	_lowest.resize(_zone_count)
	_portal_wet.resize(_portals.size())
	for portal: Portal in _portals:
		_portal_to.append(portal.to_zone)
		_portal_entry.append(portal.entry)
		_portal_exit.append(portal.exit)
		_portal_length.append(portal.entry.distance_to(portal.exit))


## The Surfaces it asks.
func surfaces() -> Surfaces:
	return _surfaces


func zone_count() -> int:
	return _zone_count


## Whether [param zone] is a room — walled, so it floods from its lowest corner up —
## rather than an open deck.
func is_room(zone: int) -> bool:
	return zone >= 0 and zone < _layout.rooms.size()


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
	_know(pose)
	if _flooded[zone] == 0:
		_flooded[zone] = 2 if _is_flooded(zone, pose) else 1
	return _flooded[zone] == 2


## Whether [param zone] is giving way or gone under [param pose]: an open deck every
## platform of which the pose has collapsing or collapsed. A room never is — its
## floor stays when the deck over it goes.
func doomed(zone: int, pose: ShipPose) -> bool:
	if zone < _layout.rooms.size() or pose.collapsing.is_empty() and pose.collapsed.is_empty():
		return false
	_know(pose)
	if _doomed[zone] == 0:
		_doomed[zone] = 2
		for platform: int in _zone_platforms[zone]:
			var deck_name := _layout.platforms[platform].name
			if not (deck_name in pose.collapsing or deck_name in pose.collapsed):
				_doomed[zone] = 1
				break
	return _doomed[zone] == 2


## How high [param zone] stands in the world under [param pose]: a room by the
## middle of its floor, an open deck by the highest middle of its platforms.
func world_height(zone: int, pose: ShipPose) -> float:
	_know(pose)
	if is_nan(_heights[zone]):
		if zone < _layout.rooms.size():
			_heights[zone] = pose.world_height(_room_middle(zone))
		else:
			_heights[zone] = -INF
			for platform: int in _zone_platforms[zone]:
				_heights[zone] = maxf(_heights[zone], _surfaces.world_height(platform, pose))
	return _heights[zone]


## How high the lowest corner of [param zone]'s floor stands in the world under
## [param pose] — of a room's area, or of every platform of an open deck.
func lowest_world_height(zone: int, pose: ShipPose) -> float:
	_know(pose)
	if is_nan(_lowest[zone]):
		_lowest[zone] = _floor_lowest(zone, pose)
	return _lowest[zone]


## How high above the sea the floor under a body at [param at] in [param zone] stands
## under [param pose], as the sea comes for it: a room floods from its lowest corner up,
## an open deck where the body stands.
func floor_height(zone: int, at: Vector3, pose: ShipPose) -> float:
	if is_room(zone):
		return lowest_world_height(zone, pose)
	return pose.world_height(at)


## How high [param zone] would stand were the deck tilted further by [param lean]: the
## rise per metre of the ship plane, uphill. A room by the middle of its floor, an open
## deck by the highest middle of its platforms, as world_height has them.
func _leaned(zone: int, pose: ShipPose, lean: Vector2) -> float:
	if is_room(zone):
		var middle := _room_middle(zone)
		return pose.world_height(middle) + lean.dot(Vector2(middle.x, middle.z))
	var height := -INF
	for platform: int in _zone_platforms[zone]:
		var centre := _layout.platforms[platform].area.get_center()
		height = maxf(height, _surfaces.world_height(platform, pose) + lean.dot(centre))
	return height


func _floor_lowest(zone: int, pose: ShipPose) -> float:
	var areas: Array[Rect2] = []
	var heights := PackedFloat64Array()
	if zone < _layout.rooms.size():
		areas.append(_layout.rooms[zone].area)
		heights.append(_layout.rooms[zone].floor_height)
	else:
		for platform: int in _zone_platforms[zone]:
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
	return route_in(search(from_pos, from_surface, pose), goal)


## The portals to [param goal] in what [param found] found, in order: as route().
func route_in(found: Search, goal: int) -> Array[Portal]:
	var legs: Array[Portal] = []
	if goal == NONE or found.cost.is_empty() or found.cost[goal] == INF:
		return legs
	var zone := goal
	while found.came_by[zone] != NONE:
		legs.push_front(_portals[found.came_by[zone]])
		zone = found.came_from[zone]
		if zone == NONE:
			break
	return legs


## The portals of the shortest way from a body on [param from_surface] at
## [param from_pos] on an open deck out of it into the rooms beside it, through their
## doorways only, and back out onto that deck by another doorway — scored to
## [param to_point] on it: round what stands between the two on the deck, a wall or a
## stair's side. Empty when the body is in a room or on nothing, or no room joins its
## deck twice.
func detour(
	from_pos: Vector3, from_surface: int, to_point: Vector3, pose: ShipPose
) -> Array[Portal]:
	var legs: Array[Portal] = []
	var start := zone_at(from_pos, from_surface)
	if start == NONE or start < _layout.rooms.size():
		return legs
	_know(pose)
	var cost := PackedFloat64Array()
	cost.resize(_zone_count)
	cost.fill(INF)
	var came_by := PackedInt32Array()
	came_by.resize(_zone_count)
	came_by.fill(NONE)
	var arrived := PackedVector3Array()
	arrived.resize(_zone_count)
	# Per room, the doorway the way to it left the deck by: it never comes back by it.
	var left_by := PackedVector3Array()
	left_by.resize(_zone_count)
	var done := PackedByteArray()
	done.resize(_zone_count)
	var open := OpenSet.new()
	cost[start] = 0.0
	arrived[start] = from_pos
	open.push(0.0, start)
	var best := INF
	var best_portal := NONE
	while not open.is_empty():
		var zone := open.pop()
		if done[zone] == 1:
			continue
		done[zone] = 1
		for index: int in _out[zone]:
			var other := _portal_to[index]
			if _portals[index].ramp != NONE or _wet(index, pose):
				continue
			var through := (
				cost[zone] + arrived[zone].distance_to(_portal_entry[index]) + _portal_length[index]
			)
			if other == start:
				var total := through + _portal_exit[index].distance_to(to_point)
				if (
					zone != start
					and total < best
					and _portal_exit[index].distance_to(left_by[zone]) > _lead
				):
					best = total
					best_portal = index
				continue
			if other >= _layout.rooms.size() or done[other] == 1 or _closed(other, pose):
				continue
			if through < cost[other]:
				cost[other] = through
				came_by[other] = index
				arrived[other] = _portal_exit[index]
				left_by[other] = _portal_entry[index] if zone == start else left_by[zone]
				open.push(through, other)
	if best_portal == NONE:
		return legs
	legs.append(_portals[best_portal])
	var zone := _portals[best_portal].from_zone
	while zone != start:
		legs.push_front(_portals[came_by[zone]])
		zone = _portals[came_by[zone]].from_zone
	return legs


## The zone standing highest in the world (world_height) of those a body on
## [param from_surface] at [param from_pos] can reach without crossing a flooded one
## — its own included, unless it is giving way; NONE when it stands on nothing.
func highest_reachable(from_pos: Vector3, from_surface: int, pose: ShipPose) -> int:
	return highest_in(search(from_pos, from_surface, pose), pose)


## The highest zone of those [param found] reaches, as highest_reachable() — or, by
## [param more_deg], the highest were the deck tilted that many degrees further the way
## [param pose] tilts it: the end a ship rises by as it founders by the other. While
## [param found] reaches it, [param kept] stays the answer unless another would stand
## more than [param keep_m] higher — and whatever would while a lurch swings the deck:
## a lurch is a swing, not the way she founders.
func highest_in(found: Search, pose: ShipPose, more_deg := 0.0, kept := NONE, keep_m := 0.0) -> int:
	var gravity := pose.ship_gravity(1.0)
	var lean := -Vector2(gravity.x, gravity.z).normalized() * tan(deg_to_rad(more_deg))
	var best := NONE
	var best_height := -INF
	var kept_height := -INF
	for zone in found.cost.size():
		if found.cost[zone] == INF or doomed(zone, pose):
			continue
		var height := world_height(zone, pose) if more_deg == 0.0 else _leaned(zone, pose, lean)
		if zone == kept:
			kept_height = height
		if height > best_height:
			best = zone
			best_height = height
	if kept_height > -INF and (pose.lurch != 0.0 or best_height <= kept_height + keep_m):
		return kept
	return best


## The portal along the stair [param ramp_surface] out by its end in [param zone], or
## null when neither of its ends is in that zone: the way off it there.
func way_off(ramp_surface: int, zone: int) -> Portal:
	var ramp := ramp_surface - _surfaces.platform_count()
	for end in 2:
		if _ramp_zones[ramp][end] == zone and _ramp_portals[ramp][end] != NONE:
			return _portals[_ramp_portals[ramp][end]]
	return null


## The portals of the shortest swim from a swimmer at [param from_pos] over
## [param bottom] — through flooded zones and portals under water, never a zone giving
## way — to the nearest zone not flooded: out of a flooded room by its doorways and
## stairs. Empty when it swims over nothing, or over a zone not flooded itself, or no
## such zone is reached.
func way_ashore(from_pos: Vector3, bottom: int, pose: ShipPose) -> Array[Portal]:
	var found := search(from_pos, bottom, pose, true)
	var nearest := NONE
	for zone in found.cost.size():
		if found.cost[zone] == INF or flooded(zone, pose) or doomed(zone, pose):
			continue
		if nearest == NONE or found.cost[zone] < found.cost[nearest]:
			nearest = zone
	return route_in(found, nearest)


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
## closes on the axis rather than circling a point; just past it within its width, the
## point past it too, never back to it; beside it, the middle of its near edge, so the
## body turns in rather than doubling back. On the leg's ramp, the point
## past its far end; under it or behind its high end, out to its nearer side first, so
## the walk to its foot runs along the stair rather than into it.
func toward(leg: Portal, from_pos: Vector3, from_surface: int) -> Vector3:
	var along := Vector3(leg.along.x, 0.0, leg.along.y)
	var past := leg.exit + along * _lead
	if leg.ramp != NONE and from_surface == _surfaces.ramp_surface(leg.ramp):
		return past
	var offset := Vector2(from_pos.x - leg.entry.x, from_pos.z - leg.entry.z)
	var ahead := offset.dot(leg.along)
	var aside := offset.cross(leg.along)
	var lined_up := absf(aside) <= maxf(leg.half_width - _body_radius, 0.0)
	var through := ahead > 0.0 and absf(aside) < leg.half_width
	if (lined_up or through) and absf(ahead) <= _lead:
		return past
	if ahead < 0.0:
		return leg.entry + along * minf(ahead + _lead, 0.0)
	if leg.ramp != NONE and ahead > _lead and absf(aside) < leg.half_width:
		var side := leg.along.orthogonal() * (1.0 if aside >= 0.0 else -1.0)
		var out := leg.entry + along * ahead
		return out + Vector3(side.x, 0.0, side.y) * (leg.half_width + _lead)
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
	for room: int in _platform_rooms[platform]:
		if _layout.rooms[room].holds(feet, _step):
			return room
	return _decks[platform]


func _room_middle(room: int) -> Vector3:
	var middle := _layout.rooms[room].area.get_center()
	return Vector3(middle.x, _layout.rooms[room].floor_height, middle.y)


## Dijkstra over the zones from where a body on [param from_surface] at
## [param from_pos] stands — a zone, or both ends of the ramp it is on — never entering
## a doomed zone, nor, unless it may [param swim], a flooded one or going through a
## portal with an end under water; ties go to the lower zone number. Empty when it
## stands on nothing.
func search(from_pos: Vector3, from_surface: int, pose: ShipPose, swim := false) -> Search:
	var found := Search.new()
	var footing := _surfaces.footing(from_surface) if from_surface != Surfaces.NONE else NONE
	if footing == Surfaces.NONE:
		return found
	_know(pose)
	var cost := PackedFloat64Array()
	cost.resize(_zone_count)
	cost.fill(INF)
	var came_by := PackedInt32Array()
	came_by.resize(_zone_count)
	came_by.fill(NONE)
	var came_from := PackedInt32Array()
	came_from.resize(_zone_count)
	came_from.fill(NONE)
	var arrived := PackedVector3Array()
	arrived.resize(_zone_count)
	var done := PackedByteArray()
	done.resize(_zone_count)
	var open := OpenSet.new()
	if _surfaces.is_ramp(footing):
		var ramp := footing - _surfaces.platform_count()
		for end in 2:
			var zone := _ramp_zones[ramp][end]
			var portal := _ramp_portals[ramp][end]
			var exit := _ramps[ramp].end_point(end)
			if portal == NONE or doomed(zone, pose):
				continue
			if not swim and (flooded(zone, pose) or _surfaces.wet(exit, pose)):
				continue
			var reached := from_pos.distance_to(exit)
			if reached < cost[zone]:
				cost[zone] = reached
				came_by[zone] = portal
				arrived[zone] = exit
				open.push(reached, zone)
	else:
		var start := zone_at(from_pos, footing)
		cost[start] = 0.0
		arrived[start] = from_pos
		open.push(0.0, start)
	while not open.is_empty():
		var zone := open.pop()
		if done[zone] == 1:
			continue
		done[zone] = 1
		for index: int in _out[zone]:
			var other := _portal_to[index]
			if done[other] == 1 or doomed(other, pose):
				continue
			if not swim and (flooded(other, pose) or _wet(index, pose)):
				continue
			var through := (
				cost[zone] + arrived[zone].distance_to(_portal_entry[index]) + _portal_length[index]
			)
			if through < cost[other]:
				cost[other] = through
				came_by[other] = index
				came_from[other] = zone
				arrived[other] = _portal_exit[index]
				open.push(through, other)
	found.cost = cost
	found.came_by = came_by
	found.came_from = came_from
	return found


## Whether [param zone] is flooded or giving way under [param pose]: never entered.
func _closed(zone: int, pose: ShipPose) -> bool:
	return flooded(zone, pose) or doomed(zone, pose)


## Whether either end of the portal at [param index] is under water.
func _wet(index: int, pose: ShipPose) -> bool:
	_know(pose)
	if _portal_wet[index] == 0:
		var portal := _portals[index]
		var wet := _surfaces.wet(portal.entry, pose) or _surfaces.wet(portal.exit, pose)
		_portal_wet[index] = 2 if wet else 1
	return _portal_wet[index] == 2


## Forgets what an earlier pose said, when [param pose] is another.
func _know(pose: ShipPose) -> void:
	if pose == _pose_known:
		return
	_pose_known = pose
	_flooded.fill(0)
	_doomed.fill(0)
	_portal_wet.fill(0)
	_heights.fill(NAN)
	_lowest.fill(NAN)


func _is_flooded(zone: int, pose: ShipPose) -> bool:
	if zone < _layout.rooms.size():
		return _surfaces.wet(_room_middle(zone), pose)
	for platform: int in _zone_platforms[zone]:
		if not _surfaces.flooded(platform, pose):
			return false
	return true


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
