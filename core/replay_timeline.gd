class_name ReplayTimeline
extends RefCounted
## A replay played back a tick at a time, and sought to any tick of it (R2, #210):
## the match's sim run again from its ReplayFile's log through the one loop
## (MatchRunner, D13). A position is the sim's tick — the next to be stepped — from the
## log's first tick to one past its last, the state after the last frame.
##
## Stepping forward keeps a keyframe — the sim's snapshot — every keyframe_every ticks
## of ReplayRules, the first tick included. seek() restores the latest keyframe at or
## before its target (MatchSim.restore, D5) and steps on to it, keeping keyframes as it
## goes past the furthest kept; the events of those steps are dropped, since
## presentation resyncs from the snapshot. Keyframes are bounded by the log: at 60
## ticks between them an 8-seat steamer match keeps one snapshot of about 20 kB every
## two seconds, some 600 kB a minute of match, however often it is sought.

var file: ReplayFile

var _config: MatchConfig
var _sim: MatchSim
var _sources: Array[InputSource]
var _runner: MatchRunner
var _every: int
## Keyframes by the tick they are the state at.
var _keyframes: Dictionary[int, Dictionary] = {}


## [param replay] played under [param rules], on [param config] — the match its
## choices make (ReplayFile.config), handed in so the caller can have its sinking baked
## ahead (Game's hold) rather than here. A config the log was not played under is an
## error: the replay would not be the match (playable()).
func _init(replay: ReplayFile, rules: ReplayRules, config: MatchConfig) -> void:
	file = replay
	_every = maxi(1, rules.keyframe_every)
	_config = config
	assert(
		config != null and replay.log.first_tick == 0 and replay.log.matches(config),
		"a timeline of a playable replay, on its own match"
	)
	_sim = MatchSim.create(_config)
	_sources = replay.replay_sources()
	_runner = MatchRunner.new(_sim, _sources)
	_keep()


## The sim's tick: the next to be stepped.
func tick() -> int:
	return _runner.tick()


func first_tick() -> int:
	return file.log.first_tick


## The position after the last frame of the log: the end of the replay.
func last_tick() -> int:
	return file.log.last_tick() + 1


## Whether there is nothing more to step: the log is used up, or the match ended before
## it was (the sim steps no further once over, whatever frames remain).
func at_end() -> bool:
	return tick() >= last_tick() or _sim.is_over()


func snapshot() -> Dictionary:
	return _runner.snapshot


## The sim as it stands at tick(), for what presentation reads of a match beyond its
## snapshot (the schedule, the ship).
func sim() -> MatchSim:
	return _sim


## One tick on, from the log's frames; nothing, at the end.
func step() -> Array[SimEvent]:
	if at_end():
		return []
	var events := _runner.step()
	_keep()
	return events


## To [param target], clamped to the replay: back through the latest keyframe at or
## before it, or on from here — whichever is nearer — then step by step, those steps'
## events dropped.
func seek(target: int) -> void:
	var to := clampi(target, first_tick(), last_tick())
	var from := _keyframe_before(to)
	if to < tick() or from > tick():
		_sim.restore(_keyframes[from])
		_runner = MatchRunner.new(_sim, _sources)
	while tick() < to and not _sim.is_over():
		_runner.step()
		_keep()


## The latest keyframe's tick at or before [param at]; there is always the first.
func _keyframe_before(at: int) -> int:
	var found := first_tick()
	for kept: int in _keyframes:
		if kept <= at and kept > found:
			found = kept
	return found


## Keeps the snapshot of the tick now when it is on the keyframe beat and not kept yet.
func _keep() -> void:
	var at := tick()
	if (at - first_tick()) % _every != 0 or _keyframes.has(at):
		return
	_keyframes[at] = _runner.snapshot.duplicate(true)
