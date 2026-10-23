class_name BotRefuge
extends RefCounted
## A bot's refuge once the ship founders (§5b.3, D10): of the zones it can reach, the one
## standing highest now, marked down by how fast the water under it has come up toward
## it over the bot's own view window — its floor over its water then against now, as the
## bot saw both — times refuge_rise_s: seen, never foreseen. Nothing is extrapolated
## from her lean. A refuge once made for is kept through a lurch — a swing, not the way
## she founders — and else unless another would stand refuge_keep_m higher. And where a
## bot below deck wades to when every dry way it has leads only to floors going under.

var _graph: WalkGraph
var _window: int
var _rise_seconds: float
var _keep: float
var _clear_by: float
## Each zone's floor over its water as the bot saw it a window ago and at its latest
## look, and the ticks it saw them on; -1 for not yet.
var _then := PackedFloat64Array()
var _then_tick := -1
var _now := PackedFloat64Array()
var _now_tick := -1


func _init(graph: WalkGraph, profile: BotProfile) -> void:
	_graph = graph
	_window = Ticks.from_seconds(profile.refuge_window_s)
	_rise_seconds = profile.refuge_rise_s
	_keep = profile.refuge_keep_m
	_clear_by = profile.climb_margin_m


## The refuge for a bot whose search is [param found], seeing [param pose] as it stood
## on [param tick], its refuge till now [param kept] (WalkGraph.NONE for none).
func choose(found: WalkGraph.Search, pose: ShipPose, tick: int, kept: int) -> int:
	_look(pose, tick)
	var best := WalkGraph.NONE
	var best_height := -INF
	var kept_height := -INF
	for zone in found.cost.size():
		if found.cost[zone] == INF or _graph.doomed(zone, pose):
			continue
		var height := _graph.world_height(zone, pose) - _rise(zone) * _rise_seconds
		if zone == kept:
			kept_height = height
		if height > best_height:
			best = zone
			best_height = height
	if kept_height > -INF and (pose.lurch != 0.0 or best_height <= kept_height + _keep):
		return kept
	return best


## The wade out (WalkGraph.wade_out) for a bot standing in [param zone] at [param at] on
## [param surface] under [param pose], to the nearest floor climb_margin_m out of its
## water: its own floor not, and [param refuge] — the best its dry ways reach — a room
## whose floor is not either; or, [param wading] for [param goal] and not there yet, on
## through whatever water lies on the way. Empty when it need not, or has no way.
func wade_out(
	zone: int, at: Vector3, surface: int, pose: ShipPose, refuge: int, goal: int, wading: bool
) -> Array[WalkGraph.Portal]:
	var none: Array[WalkGraph.Portal] = []
	if zone == WalkGraph.NONE or _graph.floor_height(zone, at, pose) >= _clear_by:
		return none
	var trapped := (
		refuge != WalkGraph.NONE
		and _graph.is_room(refuge)
		and _graph.lowest_above_water(refuge, pose) < _clear_by
	)
	if not trapped and not (wading and goal != zone):
		return none
	return _graph.wade_out(at, surface, pose, _clear_by)


## How fast the water under [param zone] has come up toward its floor over the window,
## in m/s; 0 before the bot has seen it twice, and for water falling away.
func _rise(zone: int) -> float:
	if _then_tick < 0 or _now_tick <= _then_tick:
		return 0.0
	var seconds := Ticks.to_seconds(_now_tick - _then_tick)
	return maxf((_then[zone] - _now[zone]) / seconds, 0.0)


## Keeps what [param pose], seen on [param tick], shows of each zone's floor over its
## water; what it kept last becomes the window's start once that is a window old.
func _look(pose: ShipPose, tick: int) -> void:
	if tick == _now_tick:
		return
	if _now_tick >= 0 and (_then_tick < 0 or tick - _then_tick >= _window):
		_then = _now.duplicate()
		_then_tick = _now_tick
	_now.resize(_graph.zone_count())
	for zone in _graph.zone_count():
		_now[zone] = _graph.lowest_above_water(zone, pose)
	_now_tick = tick
