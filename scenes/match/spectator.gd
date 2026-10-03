class_name Spectator
extends RefCounted
## Whom the camera follows: the local seat while it is dry; once it is out, the
## best-placed dry seat by MatchStats, until Q / E or the d-pad picks another,
## which it keeps until that one is out too. Who is dry is the snapshot's to say
## (D5).

var _local: int
var _stats: MatchStats
## The seat cycled to, or -1 to follow the best-placed.
var _picked := -1
## Who was followed last, held once nobody is dry.
var _following: int


func _init(local_seat: int, stats: MatchStats) -> void:
	_local = local_seat
	_stats = stats
	_following = local_seat


## The seat to follow in [param snapshot].
func target(snapshot: Dictionary) -> int:
	var dry := _dry(snapshot)
	if dry.has(_local):
		_following = _local
	elif dry.has(_picked):
		_following = _picked
	else:
		_picked = -1
		if not dry.is_empty():
			_following = _stats.best_of(dry)
	return _following


## Moves to the next dry seat by seat id ([param step] 1) or the previous (-1);
## nothing while the local seat is still dry.
func cycle(snapshot: Dictionary, step: int) -> void:
	var dry := _dry(snapshot)
	if dry.is_empty() or dry.has(_local):
		return
	var at := dry.find(target(snapshot))
	_picked = dry[posmod(at + step, dry.size())]


static func _dry(snapshot: Dictionary) -> Array[int]:
	var dry: Array[int] = []
	for entry: Dictionary in snapshot["seats"]:
		if not entry["out"]:
			dry.append(entry["seat"])
	return dry
