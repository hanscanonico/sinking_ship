class_name MatchRunner
extends RefCounted
## The one loop (D13). The scene, the headless tool, the tests and later the server
## all step a match through here: one frame per seat in seat order, the sim steps,
## the frames go to the log, the snapshot goes to the digest and to every source.

var sim: MatchSim
var input_log: InputLog
var digest: SnapshotDigest = SnapshotDigest.new()
## The latest snapshot — what presentation and bots read.
var snapshot: Dictionary

var _sources: Array[InputSource] = []


## [param sources] holds one source per seat, indexed by seat id.
func _init(match_sim: MatchSim, sources: Array[InputSource]) -> void:
	assert(sources.size() == match_sim.config.seats, "one input source per seat")
	sim = match_sim
	_sources = sources
	input_log = InputLog.new(sim.config, sim.state.tick)
	snapshot = sim.snapshot()
	digest.add(snapshot, sim.is_over())
	_show(snapshot)


func is_over() -> bool:
	return sim.is_over()


func tick() -> int:
	return sim.state.tick


func step() -> Array[SimEvent]:
	if sim.is_over():
		return []
	var tick_now := sim.state.tick
	var frames: Array[InputFrame] = []
	for source: InputSource in _sources:
		frames.append(source.next_frame(tick_now))
	input_log.record(tick_now, frames)
	var events := sim.step(frames)
	snapshot = sim.snapshot()
	digest.add(snapshot, sim.is_over())
	_show(snapshot)
	return events


## Steps until the match ends or [param max_ticks] more ticks have run; returns
## every event, in order.
func run(max_ticks: int) -> Array[SimEvent]:
	var events: Array[SimEvent] = []
	var stop := sim.state.tick + max_ticks
	while not sim.is_over() and sim.state.tick < stop:
		events.append_array(step())
	return events


func _show(latest: Dictionary) -> void:
	var pose := sim.pose()
	for source: InputSource in _sources:
		source.observe(latest, pose)
