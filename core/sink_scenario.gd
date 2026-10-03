class_name SinkScenario
extends Resource
## One match's sinking, as a value the match carries (D7). Which end or side goes
## under first, and when, is whatever these numbers say — never a rule.

## The ship-local point trim and heel turn about.
@export var pivot: Vector3
## Seconds into the match before the ship starts to move; level until then.
@export var starts_at: float
## In ascending [member SinkKeyframe.at]; once the scenario starts the pose is
## linear between them, holding the first before it and the last after it.
@export var keyframes: Array[SinkKeyframe] = []


## Every reason this scenario cannot run; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if starts_at < 0.0:
		found.append("sinking: starts_at must not be negative")
	if keyframes.is_empty():
		found.append("sinking: no keyframes")
	var previous := -INF
	for keyframe: SinkKeyframe in keyframes:
		if keyframe == null:
			found.append("sinking: an empty keyframe")
			continue
		if keyframe.at < 0.0 or keyframe.at <= previous:
			found.append("sinking: keyframe times must start at 0 or later and rise")
		previous = keyframe.at
	return found
