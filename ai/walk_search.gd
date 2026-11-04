class_name WalkSearch
extends RefCounted
## Every dry zone reachable from one place, and the cheapest way to each: what one
## WalkGraph.search finds, for route_in and highest_in to read as often as they like.
## Lazy: which zones it reaches is a walk over the open portals, done once asked; the
## cheapest ways a Dijkstra that settles zones only until the one asked for is — in the
## same order, ties to the lower zone, as one run to its end — so a zone's cost and way
## are the same whenever they are asked.

const NONE := -1

## Per zone, the distance walked to reach it, or INF; final once the zone is settled.
var _cost := PackedFloat64Array()
## Per zone, the portal it was reached through, or NONE where the search started.
var _came_by := PackedInt32Array()
## Per zone, the zone that portal was entered from, or NONE.
var _came_from := PackedInt32Array()
var _arrived := PackedVector3Array()
## Per zone, 1 once settled.
var _done := PackedByteArray()
## The zones still to settle, a binary heap of (cost, zone): cheapest first, ties to the
## lower zone.
var _heap_costs := PackedFloat64Array()
var _heap_zones := PackedInt32Array()
## The zones the search starts from; per zone, 1 where it reaches, once asked (reached).
var _seeds := PackedInt32Array()
var _reach := PackedByteArray()
var _asked := false
## Per portal, 1 where this search may not go through it.
var _closed := PackedByteArray()
var _out: Array[PackedInt32Array] = []
var _portal_to := PackedInt32Array()
var _portal_entry := PackedVector3Array()
var _portal_exit := PackedVector3Array()
var _portal_length := PackedFloat64Array()
var _pace := PackedFloat64Array()


## A search over [param zones] zones with nothing reached: one standing on nothing,
## until start() and reach() give it where it starts.
func _init(zones := 0) -> void:
	_cost.resize(zones)
	_cost.fill(INF)
	_came_by.resize(zones)
	_came_by.fill(NONE)
	_came_from.resize(zones)
	_came_from.fill(NONE)
	_arrived.resize(zones)
	_done.resize(zones)


## Gives it the graph it walks: per zone its portals out ([param out]) and its pace, per
## portal where it leads, is entered and left, its length, and whether it is [param closed].
func walk(
	out: Array[PackedInt32Array],
	portal_to: PackedInt32Array,
	portal_entry: PackedVector3Array,
	portal_exit: PackedVector3Array,
	portal_length: PackedFloat64Array,
	pace: PackedFloat64Array,
	closed: PackedByteArray
) -> void:
	_out = out
	_portal_to = portal_to
	_portal_entry = portal_entry
	_portal_exit = portal_exit
	_portal_length = portal_length
	_pace = pace
	_closed = closed


## Starts it in [param zone], [param cost] walked to [param at] — through [param portal]
## or NONE — unless it starts there cheaper already.
func reach(zone: int, cost: float, at: Vector3, portal := NONE) -> void:
	if cost >= _cost[zone]:
		return
	_cost[zone] = cost
	_came_by[zone] = portal
	_arrived[zone] = at
	_seeds.append(zone)
	_push(cost, zone)


## Whether it stands on nothing: it reaches no zone.
func is_empty() -> bool:
	return _cost.is_empty()


## Whether it reaches [param zone].
func reaches(zone: int) -> bool:
	return zone >= 0 and zone < _cost.size() and reached()[zone] == 1


## Per zone, 1 where it reaches: every zone a portal not closed leads on to from where it
## starts — those a search run to its end gives a cost.
func reached() -> PackedByteArray:
	if _asked:
		return _reach
	_asked = true
	_reach.resize(_cost.size())
	var queue := _seeds.duplicate()
	for zone in queue:
		_reach[zone] = 1
	var next := 0
	while next < queue.size():
		var zone := queue[next]
		next += 1
		for index: int in _out[zone]:
			var other := _portal_to[index]
			if _closed[index] == 1 or _reach[other] == 1:
				continue
			_reach[other] = 1
			queue.append(other)
	return _reach


## The distance walked to [param zone] — INF where it does not reach it, or where that
## is more than [param within]: its settling stops there.
func cost_to(zone: int, within := INF) -> float:
	if not reaches(zone):
		return INF
	_settle(zone, within)
	return _cost[zone] if _done[zone] == 1 and _cost[zone] <= within else INF


## Per zone, the distance walked to it, or INF: every zone settled.
func costs() -> PackedFloat64Array:
	_settle(NONE, INF)
	return _cost


## The portals, by index, of the cheapest way to [param zone], in order; empty where it
## does not reach it or starts there.
func way_to(zone: int) -> PackedInt32Array:
	var legs := PackedInt32Array()
	if cost_to(zone) == INF:
		return legs
	while _came_by[zone] != NONE:
		legs.append(_came_by[zone])
		zone = _came_from[zone]
		if zone == NONE:
			break
	legs.reverse()
	return legs


func _push(cost: float, zone: int) -> void:
	var up := _heap_zones.size()
	_heap_costs.append(cost)
	_heap_zones.append(zone)
	while up > 0:
		var parent := (up - 1) >> 1
		var above := _heap_costs[parent]
		if above < cost or above == cost and _heap_zones[parent] < zone:
			break
		_heap_costs[up] = above
		_heap_zones[up] = _heap_zones[parent]
		up = parent
	_heap_costs[up] = cost
	_heap_zones[up] = zone


## Settles zones, cheapest first, until [param goal] is — every zone for NONE — or the
## cheapest left costs more than [param within]. The arrays are taken out of the members
## while it works, so writing them never copies them.
func _settle(goal: int, within: float) -> void:
	var heap_costs := _heap_costs
	var heap_zones := _heap_zones
	var cost := _cost
	var came_by := _came_by
	var came_from := _came_from
	var arrived := _arrived
	var done := _done
	_heap_costs = PackedFloat64Array()
	_heap_zones = PackedInt32Array()
	_cost = PackedFloat64Array()
	_came_by = PackedInt32Array()
	_came_from = PackedInt32Array()
	_arrived = PackedVector3Array()
	_done = PackedByteArray()
	var closed := _closed
	var portal_to := _portal_to
	var portal_entry := _portal_entry
	var portal_exit := _portal_exit
	var portal_length := _portal_length
	while not heap_zones.is_empty() and heap_costs[0] <= within:
		if goal != NONE and done[goal] == 1:
			break
		var zone := heap_zones[0]
		var last := heap_zones.size() - 1
		var sift_cost := heap_costs[last]
		var sift_zone := heap_zones[last]
		heap_costs.resize(last)
		heap_zones.resize(last)
		if last > 0:
			var down := 0
			while true:
				var child := down * 2 + 1
				if child >= last:
					break
				var right := child + 1
				if (
					right < last
					and (
						heap_costs[right] < heap_costs[child]
						or (
							heap_costs[right] == heap_costs[child]
							and heap_zones[right] < heap_zones[child]
						)
					)
				):
					child = right
				if (
					sift_cost < heap_costs[child]
					or sift_cost == heap_costs[child] and sift_zone < heap_zones[child]
				):
					break
				heap_costs[down] = heap_costs[child]
				heap_zones[down] = heap_zones[child]
				down = child
			heap_costs[down] = sift_cost
			heap_zones[down] = sift_zone
		if done[zone] == 1:
			continue
		done[zone] = 1
		var so_far := cost[zone]
		var at := arrived[zone]
		var pace := _pace[zone]
		for index: int in _out[zone]:
			var other := portal_to[index]
			if done[other] == 1 or closed[index] == 1:
				continue
			var through := (
				so_far + at.distance_to(portal_entry[index]) * pace + portal_length[index]
			)
			if through < cost[other]:
				cost[other] = through
				came_by[other] = index
				came_from[other] = zone
				arrived[other] = portal_exit[index]
				var up := heap_zones.size()
				heap_costs.append(through)
				heap_zones.append(other)
				while up > 0:
					var parent := (up - 1) >> 1
					var above := heap_costs[parent]
					if above < through or above == through and heap_zones[parent] < other:
						break
					heap_costs[up] = above
					heap_zones[up] = heap_zones[parent]
					up = parent
				heap_costs[up] = through
				heap_zones[up] = other
	_heap_costs = heap_costs
	_heap_zones = heap_zones
	_cost = cost
	_came_by = came_by
	_came_from = came_from
	_arrived = arrived
	_done = done
