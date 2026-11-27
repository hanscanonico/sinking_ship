class_name BotHeadway
extends RefCounted
## Whether a bot walking gets anywhere (D10), as its thinks see it. It makes headway each
## time it stands a body's radius from every one of the last BEEN places it made headway
## at; standing, it is where it would walk from. Jiggling against a wall is no headway —
## nor is walking to and fro between two places a body's radius apart, as a bot does that
## turns off the wall at the end of a pocket of the floor and back into it: on the
## Titanic's boat deck one did so for six minutes between her officers' house and the
## winch beside it, each of the two places headway from the other. Stalled so for long
## enough, its brain goes round (BotBrain): by the floor (BotFloorWay.round_about) and,
## still stalled after that, through the rooms beside its deck, turn about — the floor
## first, as rooms that lead round a wall lead back to it as well.

## The places of its last headway it must be clear of to make more.
const BEEN := 2

var _radius: float
var _been_at := PackedVector3Array()
var _since := 0
## How many times it has gone round since it last made headway.
var _rounds := 0


func _init(rules: BrawlRules) -> void:
	_radius = rules.body_radius


## One think: the bot stands at [param at] as its view of [param tick] shows it,
## [param walking] when it has meant to walk since its view could show it.
func saw(at: Vector3, walking: bool, tick: int) -> void:
	if not walking:
		_been_at.clear()
	elif not _comes_on(at):
		return
	if _been_at.size() == BEEN:
		_been_at.remove_at(0)
	_been_at.append(at)
	_since = tick
	_rounds = 0


## How many ticks, at [param tick], it has walked without headway.
func stalled_for(tick: int) -> int:
	return tick - _since


## It goes round from [param tick], with time for that to get it somewhere: whether
## through the rooms beside its deck this time, having gone by the floor the last.
func goes_round(tick: int) -> bool:
	_since = tick
	_rounds += 1
	return _rounds % 2 == 0


func _comes_on(at: Vector3) -> bool:
	for place: Vector3 in _been_at:
		if Vector2(at.x - place.x, at.z - place.z).length() < _radius:
			return false
	return true
