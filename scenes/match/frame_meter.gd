class_name FrameMeter
extends RefCounted
## The timers of make fps SPLIT=1 (FrameProbe): the match's own pieces, subclassed so
## each call they make is timed into a FrameSplit — the bots' decisions, the host's
## sim step, snapshot and digest, the wire's encode and decode, the client's
## prediction and reconcile, and every sinking pose built. They wrap core/, ai/ and
## net/ from outside, so neither core/ nor ai/ ever reads a clock (D2), and they are
## built only when the split is asked for: normal play builds none and pays nothing.
##
## A timed piece is a continuation of the one it stands in for — the same snapshot,
## the same hash, the same baked sinking — so the match plays as it would untimed. Two
## of them go in where nothing public lets them: the config's schedule and the codecs
## of the host and the client, set by name; this file is instrumentation, not play.


## Times every sinking pose [param config]'s match builds into [param split], before
## anything of the match has asked for its schedule: the one SinkSchedule.for_match
## builds, timed.
static func time_schedule(config: MatchConfig, split: FrameSplit) -> void:
	var schedule := Schedule.new(
		config.scenario,
		config.ship.freeboard,
		SeedStreams.derive(config.match_seed, "sink"),
		config.ship.structure,
		null,
		config.sinking()
	)
	schedule.place_falls(config.ship, config.rules.railing_height)
	schedule.split = split
	config._schedule = schedule


## [param sources], each one that is there timed as the bots' decisions.
static func time_sources(sources: Array[InputSource], split: FrameSplit) -> Array[InputSource]:
	var timed: Array[InputSource] = []
	for source: InputSource in sources:
		timed.append(Source.new(source, split) if source != null else null)
	return timed


static func _now() -> int:
	return Time.get_ticks_usec()


## The schedule, every pose it builds counted and timed.
class Schedule:
	extends SinkSchedule
	var split: FrameSplit

	func pose_at(tick: int) -> ShipPose:
		var start := FrameMeter._now()
		var pose := super(tick)
		split.add(&"poses", 1)
		split.add(&"pose_time", FrameMeter._now() - start)
		return pose


## A seat's source — a bot — what it decides and what it takes in timed as the bots'.
class Source:
	extends InputSource
	var _inner: InputSource
	var _split: FrameSplit

	func _init(inner: InputSource, split: FrameSplit) -> void:
		_inner = inner
		_split = split

	func next_frame(tick: int) -> InputFrame:
		var start := FrameMeter._now()
		var frame := _inner.next_frame(tick)
		_split.add(&"bots", FrameMeter._now() - start)
		return frame

	func observe(snapshot: Dictionary, pose: ShipPose) -> void:
		var start := FrameMeter._now()
		_inner.observe(snapshot, pose)
		_split.add(&"bots", FrameMeter._now() - start)


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
		split.add(stepping, FrameMeter._now() - start)
		return events

	func snapshot() -> Dictionary:
		var start := FrameMeter._now()
		var taken := super()
		if split != null:
			split.add(&"snapshot", FrameMeter._now() - start)
		return taken

	func restore(from: Dictionary) -> void:
		var start := FrameMeter._now()
		super(from)
		if split != null:
			split.add(&"reconcile", FrameMeter._now() - start)


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
		_split.add(&"snapshot", FrameMeter._now() - start)


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
		_split.add(&"wire", FrameMeter._now() - start)
		return bytes

	func decode_inputs(bytes: PackedByteArray, seat: int) -> Array[InputFrame]:
		var start := FrameMeter._now()
		var frames := super(bytes, seat)
		_split.add(&"wire", FrameMeter._now() - start)
		return frames

	func encode_snapshot(snapshot: Dictionary, ack: int, heard: int, early: int) -> PackedByteArray:
		var start := FrameMeter._now()
		var bytes := super(snapshot, ack, heard, early)
		_split.add(&"wire", FrameMeter._now() - start)
		return bytes

	func decode_snapshot(bytes: PackedByteArray) -> SnapshotPacket:
		var start := FrameMeter._now()
		var packet := super(bytes)
		_split.add(&"wire", FrameMeter._now() - start)
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
		super(config, net_rules, conditions, seat, source, sources, from)
		_split = split
		var data_hash := WireCodec.match_hash(config, net_rules)
		host.runner.sim = Sim.continuing(host.runner.sim, split, &"host_sim")
		host.runner.digest = Digest.new(host.runner.digest, split)
		host._codec = Codec.new(data_hash, split)
		client.sim = Sim.continuing(client.sim, split, &"prediction")
		client._codec = Codec.new(data_hash, split)

	func step() -> Array[SimEvent]:
		var start := FrameMeter._now()
		var events := super()
		_split.add(&"match", FrameMeter._now() - start)
		_split.add(&"steps", 1)
		return events
