class_name BotSearch
extends RefCounted
## Where a bot looks for seats it cannot see (#737). Down to the last seats (BotPacing)
## with none of them in sight or memory, it goes to the highest ground first, as any bot
## with nobody to go at does; stood there, it does not wait on its perch: it walks to the
## zone it can reach that it has stood in least lately — never one giving way, nor
## one whose lowest corner stands within climb_margin_m of the water, as the CLIMB_OUT
## that would bring it straight back out of it reads a floor —
## the nearest of those it has not stood in for search_forget_s, else the one it stood in
## longest ago, and keeps that goal until it stands there. Standing in a zone is looking
## into it: a seat hiding there is seen (BotView) and becomes its target.

const NONE := WalkGraph.NONE

var _graph: WalkGraph
var _forget_ticks: int
var _margin: float
## Per zone, the snapshot tick the bot last stood in it, or -1 for never.
var _stood := PackedInt32Array()
## The zone it is making for, or NONE.
var _goal := NONE


func _init(graph: WalkGraph, profile: BotProfile) -> void:
	_graph = graph
	_forget_ticks = Ticks.from_seconds(profile.search_forget_s)
	_margin = profile.climb_margin_m


## The bot stands in [param zone] on snapshot [param tick]: looked into.
func stood_in(zone: int, tick: int) -> void:
	if zone == NONE:
		return
	if zone >= _stood.size():
		var was := _stood.size()
		_stood.resize(zone + 1)
		for index in range(was, zone + 1):
			_stood[index] = -1
	_stood[zone] = tick
	if zone == _goal:
		_goal = NONE


## The zone to look in next on snapshot [param tick], of those [param found] reaches
## under [param pose]: [param highest] until it has stood there lately, and again when it
## reaches no other zone worth walking to.
func goal(found: WalkSearch, pose: ShipPose, tick: int, highest: int) -> int:
	if highest != NONE and not _lately(highest, tick):
		return highest
	if _goal != NONE and found.reaches(_goal) and _safe(_goal, pose):
		return _goal
	_goal = NONE
	var costs := found.costs()
	var nearest := INF
	var oldest := tick + 1
	var oldest_zone := NONE
	for zone in costs.size():
		if costs[zone] == INF or costs[zone] == 0.0 or not _safe(zone, pose):
			continue
		if not _lately(zone, tick):
			if costs[zone] < nearest:
				nearest = costs[zone]
				_goal = zone
		elif _stood[zone] < oldest:
			oldest = _stood[zone]
			oldest_zone = zone
	if _goal == NONE:
		_goal = oldest_zone
	return _goal if _goal != NONE else highest


## Whether [param zone] is worth walking to under [param pose]: neither giving way nor
## its lowest corner within the climb margin of the water.
func _safe(zone: int, pose: ShipPose) -> bool:
	return not _graph.doomed(zone, pose) and _graph.lowest_above_water(zone, pose) >= _margin


## Whether the bot stood in [param zone] within search_forget_s of snapshot [param tick].
func _lately(zone: int, tick: int) -> bool:
	return zone < _stood.size() and _stood[zone] >= 0 and tick - _stood[zone] < _forget_ticks
