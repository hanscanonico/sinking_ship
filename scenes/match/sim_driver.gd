class_name SimDriver
extends Node
## The only thing in a scene that steps the sim (D2): an accumulator that runs the
## MatchRunner at 30 Hz however fast frames come, and keeps the last two snapshots
## for the view to interpolate between.

signal stepped(events: Array[SimEvent])

## A long hitch is dropped rather than caught up, so a stall never fast-forwards.
const MAX_STEPS_PER_FRAME := 5

var runner: MatchRunner
var previous: Dictionary
var current: Dictionary
## How far the display is from [member previous] to [member current], 0…1.
var alpha: float

var _accumulator := 0.0


func start(match_runner: MatchRunner) -> void:
	runner = match_runner
	previous = runner.snapshot
	current = runner.snapshot
	alpha = 0.0
	_accumulator = 0.0


func _process(delta: float) -> void:
	if runner == null:
		return
	if runner.is_over():
		previous = current
		alpha = 0.0
		return
	_accumulator += delta
	var steps := 0
	while _accumulator >= Ticks.SECONDS_PER_TICK and steps < MAX_STEPS_PER_FRAME:
		_accumulator -= Ticks.SECONDS_PER_TICK
		steps += 1
		previous = current
		var events := runner.step()
		current = runner.snapshot
		stepped.emit(events)
		if runner.is_over():
			break
	if steps == MAX_STEPS_PER_FRAME:
		_accumulator = minf(_accumulator, Ticks.SECONDS_PER_TICK)
	alpha = clampf(_accumulator / Ticks.SECONDS_PER_TICK, 0.0, 1.0)
