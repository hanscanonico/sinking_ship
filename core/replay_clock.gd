class_name ReplayClock
extends RefCounted
## The pace a replay is watched at (R4, #212): an accumulator of match time, as the
## scene's driver keeps for a live match, run at a speed off the replay data's ladder
## (ReplayRules.speeds), paused, or stepped a tick at a time while paused. Node-free:
## the driver feeds it each frame's seconds and steps the timeline as many ticks as it
## answers, and reads alpha() to draw between two ticks.

## The most ticks one frame may step: the top of the ladder at 30 frames a second holds,
## while a stall never fast-forwards past it.
const MAX_STEPS_PER_FRAME := 8

var paused := false

var _speeds: PackedFloat32Array
var _at: int
var _accumulator := 0.0


## A clock over [param speeds], slowest first; it starts at 1×, or the middle of the
## ladder when 1× is not on it.
func _init(speeds: PackedFloat32Array) -> void:
	_speeds = speeds if not speeds.is_empty() else PackedFloat32Array([1.0])
	_at = _speeds.find(1.0)
	if _at < 0:
		_at = _speeds.size() / 2


func speed() -> float:
	return _speeds[_at]


func speed_up() -> void:
	_at = mini(_at + 1, _speeds.size() - 1)


func speed_down() -> void:
	_at = maxi(_at - 1, 0)


## How many ticks to step this frame, [param delta] seconds on at the speed: none while
## paused or once [param at_end], when what was accumulated is dropped too.
func advance(delta: float, at_end: bool) -> int:
	if paused or at_end:
		_accumulator = 0.0
		return 0
	_accumulator += delta * speed()
	var steps := 0
	while _accumulator >= Ticks.SECONDS_PER_TICK and steps < MAX_STEPS_PER_FRAME:
		_accumulator -= Ticks.SECONDS_PER_TICK
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_accumulator = minf(_accumulator, Ticks.SECONDS_PER_TICK)
	return steps


## How far the display is into the next tick, 0…1.
func alpha() -> float:
	return clampf(_accumulator / Ticks.SECONDS_PER_TICK, 0.0, 1.0)


## Drops what is accumulated — after a seek, so play goes on from the tick sought.
func reset() -> void:
	_accumulator = 0.0
