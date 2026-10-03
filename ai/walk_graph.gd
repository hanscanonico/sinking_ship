class_name WalkGraph
extends RefCounted
## The ship as a bot finds its way round it (§7): platforms are the nodes and ramps
## the edges. A bot routes to a platform, then steers locally. Which platforms a
## ramp joins, which are flooded and how high they stand, it asks Surfaces; it
## never routes through, or to, a flooded platform, nor over a ramp with an end
## under water.


## Every dry platform reachable from one place, and the cheapest way to each.
class Search:
	## Per platform, the distance walked to reach it, or INF.
	var cost := PackedFloat64Array()
	## Per platform, the leg it was reached by: (ramp, the end left by), or (-1, -1)
	## for where the search started.
	var came_by: Array[Vector2i] = []
	## Per platform, the platform that leg started from, or Surfaces.NONE.
	var came_from := PackedInt32Array()


var _surfaces: Surfaces
var _ramps: Array[ShipRamp] = []
## Per ramp, the platforms at its start and end ends (Surfaces.joins).
var _joins: Array[PackedInt32Array] = []
## A body's width: how far before a ramp's foot a bot lines up, and past its head
## it aims.
var _lead: float
var _body_radius: float


func _init(layout: ShipLayout, surfaces: Surfaces, body_radius: float) -> void:
	_surfaces = surfaces
	_ramps = layout.ramps.duplicate()
	_body_radius = body_radius
	_lead = body_radius * 2.0
	for ramp in _ramps.size():
		_joins.append(surfaces.joins(surfaces.ramp_surface(ramp)))


## The legs from [param from_surface] (a body there at [param from_pos]) to the
## surface [param goal] — a ramp's goal is either platform it joins: each leg a
## Vector2i of (ramp, the end it is left by), in order. A blocker top counts as
## its footing (Surfaces.footing). Shortest by the distance walked; empty when
## already there, when either end is nowhere, or when every way ends on or crosses
## a flooded platform.
func route(from_pos: Vector3, from_surface: int, goal: int, pose: ShipPose) -> Array[Vector2i]:
	var legs: Array[Vector2i] = []
	from_surface = _surfaces.footing(from_surface)
	goal = _surfaces.footing(goal)
	if from_surface == Surfaces.NONE or goal == Surfaces.NONE or goal == from_surface:
		return legs
	var nodes := _surfaces.platform_count()
	var goals := _joins[goal - nodes] if _surfaces.is_ramp(goal) else PackedInt32Array([goal])
	if from_surface in goals:
		return legs
	var search := _search(from_pos, from_surface, pose)
	var reached := Surfaces.NONE
	for candidate in goals:
		if candidate == Surfaces.NONE or search.cost[candidate] == INF:
			continue
		if reached == Surfaces.NONE or search.cost[candidate] < search.cost[reached]:
			reached = candidate
	var node := reached
	while node != Surfaces.NONE and search.came_by[node].x != -1:
		legs.push_front(search.came_by[node])
		node = search.came_from[node]
	return legs


## The platform standing highest in the world, by its middle, of those a body on
## [param from_surface] at [param from_pos] can reach without crossing a flooded
## one — its own included, a blocker top's footing for the top; Surfaces.NONE when
## it stands on nothing.
func highest_reachable(from_pos: Vector3, from_surface: int, pose: ShipPose) -> int:
	from_surface = _surfaces.footing(from_surface)
	if from_surface == Surfaces.NONE:
		return Surfaces.NONE
	var search := _search(from_pos, from_surface, pose)
	var best := Surfaces.NONE
	var best_height := -INF
	for platform in search.cost.size():
		if search.cost[platform] == INF:
			continue
		var height := _surfaces.world_height(platform, pose)
		if height > best_height:
			best = platform
			best_height = height
	return best


## Where a body on [param from_surface] at [param from_pos] walks next toward
## [param goal]: one point, or none when there is no leg to follow. Off a ramp it
## first lines up in front of the ramp's foot, then heads for a point just past its
## head.
func steer(from_pos: Vector3, from_surface: int, goal: int, pose: ShipPose) -> PackedVector3Array:
	var legs := route(from_pos, from_surface, goal, pose)
	if legs.is_empty():
		return PackedVector3Array()
	var ramp := _ramps[legs[0].x]
	var exit_end := legs[0].y
	var foot := ramp.end_point(1 - exit_end)
	var head := ramp.end_point(exit_end)
	var along := Vector2(head.x - foot.x, head.z - foot.z).normalized()
	var past_head := head + Vector3(along.x, 0.0, along.y) * _lead
	if from_surface == _surfaces.ramp_surface(legs[0].x):
		return PackedVector3Array([past_head])
	var offset := Vector2(from_pos.x - foot.x, from_pos.z - foot.z)
	var half_width := (ramp.area.size.y if ramp.axis == ShipRamp.Axis.X else ramp.area.size.x) * 0.5
	var lined_up := absf(offset.cross(along)) <= maxf(half_width - _body_radius, 0.0)
	if lined_up and absf(offset.dot(along)) <= _lead:
		return PackedVector3Array([past_head])
	return PackedVector3Array([foot - Vector3(along.x, 0.0, along.y) * _lead])


## Dijkstra over the platforms from where a body stands — a platform, or both ends
## of the ramp it is on — never entering a flooded platform or crossing a ramp with
## an end under water; ties go to the lower platform number.
func _search(from_pos: Vector3, from_surface: int, pose: ShipPose) -> Search:
	var nodes := _surfaces.platform_count()
	var search := Search.new()
	search.cost.resize(nodes)
	search.cost.fill(INF)
	search.came_by.resize(nodes)
	search.came_from.resize(nodes)
	search.came_from.fill(Surfaces.NONE)
	var arrived := PackedVector3Array()
	arrived.resize(nodes)
	var done := PackedByteArray()
	done.resize(nodes)
	if _surfaces.is_ramp(from_surface):
		var on_ramp := from_surface - nodes
		for end in 2:
			var node := _joins[on_ramp][end]
			var exit := _ramps[on_ramp].end_point(end)
			if node == Surfaces.NONE or _surfaces.flooded(node, pose) or _surfaces.wet(exit, pose):
				continue
			search.cost[node] = from_pos.distance_to(exit)
			search.came_by[node] = Vector2i(on_ramp, end)
			arrived[node] = exit
	else:
		search.cost[from_surface] = 0.0
		search.came_by[from_surface] = Vector2i(-1, -1)
		arrived[from_surface] = from_pos
	while true:
		var node := Surfaces.NONE
		for index in nodes:
			if done[index] == 1 or search.cost[index] == INF:
				continue
			if node == Surfaces.NONE or search.cost[index] < search.cost[node]:
				node = index
		if node == Surfaces.NONE:
			break
		done[node] = 1
		for ramp in _ramps.size():
			for end in 2:
				var other := _joins[ramp][1 - end]
				if _joins[ramp][end] != node or other == Surfaces.NONE or done[other] == 1:
					continue
				if _surfaces.flooded(other, pose):
					continue
				var foot := _ramps[ramp].end_point(end)
				var head := _ramps[ramp].end_point(1 - end)
				if _surfaces.wet(foot, pose) or _surfaces.wet(head, pose):
					continue
				var through := (
					search.cost[node] + arrived[node].distance_to(foot) + foot.distance_to(head)
				)
				if through < search.cost[other]:
					search.cost[other] = through
					search.came_by[other] = Vector2i(ramp, 1 - end)
					search.came_from[other] = node
					arrived[other] = head
	return search
