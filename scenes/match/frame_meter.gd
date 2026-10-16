class_name FrameMeter
extends RefCounted
## The timers of make fps SPLIT=1 (FrameProbe): the match's own pieces, subclassed so
## each call they make is timed into a FrameSplit — the bots' decisions, the host's
## sim step, snapshot and digest, the wire's encode and decode, the client's
## prediction and reconcile, and every sinking pose built — and they count every fresh
## route search a bot takes. They wrap core/, ai/ and net/ from outside, so neither
## core/ nor ai/ ever reads a clock (D2), and they are built only when the split is
## asked for: normal play builds none and pays nothing.
##
## A timed piece is the one it stands in for, or a continuation of it — the schedule
## SinkSchedule.for_match builds, as a Schedule (MatchConfig.schedule_as); the codec
## both ends are handed; sims and a digest carried on from the same snapshot and hash —
## so the match plays as it would untimed.
##
## Where the client's own work is booked: a beat's prediction steps, and the steps that
## re-run it after a reset, as client prediction (Sim.step); the reset itself as client
## reconcile (Sim.restore); the snapshot _trusted takes of the prediction as snapshot
## and digest (Sim.snapshot); the rest of a reconcile — the checks, the bookkeeping — as
## the step's rest.


## Times every sinking pose [param config]'s match builds into [param split]: its
## schedule built as a Schedule, before anything of the match has asked for it. Whether
## it could — once something has, the schedule is left as it is, its poses untimed.
static func time_schedule(config: MatchConfig, split: FrameSplit) -> bool:
	var schedule := config.schedule_as(Schedule) as Schedule
	if schedule == null:
		return false
	schedule.split = split
	return true


## [param sources], each one that is there timed as the bots' decisions.
static func time_sources(sources: Array[InputSource], split: FrameSplit) -> Array[InputSource]:
	var timed: Array[InputSource] = []
	for source: InputSource in sources:
		timed.append(Source.new(source, split) if source != null else null)
	return timed


static func _now() -> int:
	return Time.get_ticks_usec()


## Books the time since [param start] (_now) to [param part] of [param split].
static func _book(split: FrameSplit, part: StringName, start: int) -> void:
	split.add(part, _now() - start)


## The schedule, every pose it builds counted and timed — not those it hands out again.
class Schedule:
	extends SinkSchedule
	var split: FrameSplit

	func _posed(tick: int) -> ShipPose:
		var start := FrameMeter._now()
		var pose := super(tick)
		FrameMeter._book(split, &"pose_time", start)
		split.add(&"poses", 1)
		return pose


## A seat's source — a bot — what it decides and what it takes in timed as the bots',
## and every fresh route search its brain takes off the route it had counted.
class Source:
	extends InputSource
	var _inner: InputSource
	var _split: FrameSplit

	func _init(inner: InputSource, split: FrameSplit) -> void:
		_inner = inner
		_split = split

	func next_frame(tick: int) -> InputFrame:
		var bot := _inner as BotInputSource
		var searched := bot.replans() if bot != null else 0
		var start := FrameMeter._now()
		var frame := _inner.next_frame(tick)
		FrameMeter._book(_split, &"bots", start)
		if bot != null:
			_split.add(&"replans", bot.replans() - searched)
		return frame

	func observe(snapshot: Dictionary, pose: ShipPose) -> void:
		var start := FrameMeter._now()
		_inner.observe(snapshot, pose)
		FrameMeter._book(_split, &"bots", start)


## A sim: its step timed as [member stepping] says — the host's or the client's
## prediction — its snapshots as snapshot and digest, its resets as the client's
## reconcile.
class Sim:
	extends MatchSim
	var split: FrameSplit
	var stepping: StringName

	## [param sim] continued from its snapshot (D5), timed.
	static func continuing(sim: MatchSim, into: FrameSplit, part: StringName) -> Sim:
		var timed := Sim.new(sim.config)
		timed.restore(sim.snapshot())
		timed.split = into
		timed.stepping = part
		return timed

	func step(frames: Array[InputFrame]) -> Array[SimEvent]:
		var start := FrameMeter._now()
		var events := super(frames)
		FrameMeter._book(split, stepping, start)
		return events

	func snapshot() -> Dictionary:
		var start := FrameMeter._now()
		var taken := super()
		if split != null:
			FrameMeter._book(split, &"snapshot", start)
		return taken

	func restore(from: Dictionary) -> void:
		var start := FrameMeter._now()
		super(from)
		if split != null:
			FrameMeter._book(split, &"reconcile", start)


## The host's digest, folding in timed as snapshot and digest.
class Digest:
	extends SnapshotDigest
	var _split: FrameSplit

	## [param digest] carried on, timed.
	func _init(digest: SnapshotDigest, split: FrameSplit) -> void:
		_hash = digest.hex()
		_split = split

	func add(snapshot: Dictionary, final: bool = false) -> void:
		var start := FrameMeter._now()
		super(snapshot, final)
		FrameMeter._book(_split, &"snapshot", start)


## A wire codec, everything it encodes and decodes timed as the wire's.
class Codec:
	extends WireCodec
	var _split: FrameSplit

	func _init(data_hash: String, split: FrameSplit) -> void:
		super(data_hash)
		_split = split

	func encode_inputs(frames: Array[InputFrame]) -> PackedByteArray:
		var start := FrameMeter._now()
		var bytes := super(frames)
		FrameMeter._book(_split, &"wire", start)
		return bytes

	func decode_inputs(bytes: PackedByteArray, seat: int) -> Array[InputFrame]:
		var start := FrameMeter._now()
		var frames := super(bytes, seat)
		FrameMeter._book(_split, &"wire", start)
		return frames

	func encode_snapshot(snapshot: Dictionary, ack: int, heard: int, early: int) -> PackedByteArray:
		var start := FrameMeter._now()
		var bytes := super(snapshot, ack, heard, early)
		FrameMeter._book(_split, &"wire", start)
		return bytes

	func decode_snapshot(bytes: PackedByteArray) -> SnapshotPacket:
		var start := FrameMeter._now()
		var packet := super(bytes)
		FrameMeter._book(_split, &"wire", start)
		return packet


## The offline match, its host and its client timed piece by piece and each beat
## timed whole as the match's step.
class Loopback:
	extends LoopbackMatch
	var _split: FrameSplit

	func _init(
		config: MatchConfig,
		net_rules: NetRules,
		conditions: NetConditions,
		seat: int,
		source: InputSource,
		sources: Array[InputSource],
		from: Dictionary,
		split: FrameSplit
	) -> void:
		var codec := Codec.new(WireCodec.match_hash(config, net_rules), split)
		super(config, net_rules, conditions, seat, source, sources, from, codec)
		_split = split
		host.runner.sim = Sim.continuing(host.runner.sim, split, &"host_sim")
		host.runner.digest = Digest.new(host.runner.digest, split)
		client.sim = Sim.continuing(client.sim, split, &"prediction")

	func step() -> Array[SimEvent]:
		var start := FrameMeter._now()
		var events := super()
		FrameMeter._book(_split, &"match", start)
		_split.add(&"steps", 1)
		return events
