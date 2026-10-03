class_name BotView
extends RefCounted
## What a bot perceives (D10): the snapshot from reaction_ticks ago, and the ship's
## current pose — what a player sees on screen, never the schedule's future.

var _delay: int
var _snapshots: Array[Dictionary] = []
var _pose: ShipPose


func _init(reaction_ticks: int) -> void:
	_delay = reaction_ticks


func push(latest: Dictionary, pose_at_latest: ShipPose) -> void:
	_snapshots.append(latest)
	if _snapshots.size() > _delay + 1:
		_snapshots.pop_front()
	_pose = pose_at_latest


func is_empty() -> bool:
	return _snapshots.is_empty()


## The delayed snapshot, or the oldest one held while the ring is still filling.
func snapshot() -> Dictionary:
	return _snapshots[0]


func pose() -> ShipPose:
	return _pose
