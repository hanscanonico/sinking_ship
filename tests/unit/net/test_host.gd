extends GutTest
## The authority (D11): a client's seat on the host is a buffer of its frames by
## tick; a missing frame repeats the seat's last, a late one is dropped and never
## rewound, and each snapshot acks the last frame applied.

const HOST_PEER := 0
const CLIENT_PEER := 1

var _clock: NetClock
var _client_end: LoopbackTransport
var _codec: WireCodec
var _rules: NetRules


## A host of [param seats] on the flat deck, seat 0 the client's and the rest
## standing still, over a wire that does not lie; [param rules] or the shipped ones.
func _host(seats: int = 2, rules: NetRules = null) -> MatchHost:
	var config := SimFixtures.config(seats)
	_rules = rules if rules != null else NetRules.load_default()
	_clock = NetClock.new()
	var honest := NetConditions.new()
	var host_end := LoopbackTransport.new(HOST_PEER, _clock, honest, SeedStreams.derive(1, 0))
	_client_end = LoopbackTransport.new(CLIENT_PEER, _clock, honest, SeedStreams.derive(1, 1))
	LoopbackTransport.link(host_end, _client_end)
	var buffer := SeatBuffer.new(0)
	var sources: Array[InputSource] = [buffer]
	for seat in range(1, seats):
		sources.append(InputSource.new())
	var runner := MatchRunner.new(MatchSim.create(config), sources)
	var host := MatchHost.new(runner, host_end, _rules)
	host.admit(CLIENT_PEER, buffer)
	_codec = WireCodec.new(WireCodec.match_hash(config, _rules))
	return host


func _walk(tick: int, direction: Vector2, buttons: int = 0) -> InputFrame:
	return InputFrame.new(0, tick, InputFrame.quantize(direction), buttons, 1234)


func _send(frames: Array[InputFrame]) -> void:
	_client_end.send(HOST_PEER, _codec.encode_inputs(frames))


## Every snapshot the client has been sent since the last call, decoded.
func _received() -> Array[SnapshotPacket]:
	var packets: Array[SnapshotPacket] = []
	for packet: Transport.Packet in _client_end.receive():
		packets.append(_codec.decode_snapshot(packet.bytes))
	return packets


func _seat(host: MatchHost, seat: int = 0) -> Dictionary:
	return host.runner.snapshot["seats"][seat]


func test_missing_frame_repeats_last() -> void:
	var host := _host()
	var walk := _walk(0, Vector2.RIGHT)
	_send([walk])
	host.step()
	var walked: Vector3 = _seat(host)["vel"]
	host.step()
	assert_null(host.runner.input_log.frame(1, 0), "no frame came for tick 1")
	assert_eq(
		_seat(host)["last_input"],
		[walk.move.x, walk.move.y, walk.look_yaw, walk.buttons],
		"so tick 1 applied tick 0's again"
	)
	var after: Vector3 = _seat(host)["vel"]
	assert_gt(after.x, walked.x, "and the seat kept walking")
	_send([_walk(2, Vector2.ZERO)])
	host.step()
	assert_eq(_seat(host)["last_input"], [0, 0, 1234, 0], "until a frame came")


func test_late_frame_is_dropped_not_rewound() -> void:
	var host := _host()
	var still := MatchSim.create(host.runner.sim.config)
	for tick in 5:
		host.step()
		still.step([])
	_send([_walk(3, Vector2.RIGHT, InputFrame.SHOVE)])
	host.step()
	still.step([])
	assert_eq(host.tick(), 6, "the host stepped on, not back")
	assert_null(host.runner.input_log.frame(5, 0), "the frame for tick 3 was not applied")
	assert_eq(
		host.runner.snapshot["seats"],
		still.snapshot()["seats"],
		"nor taken for a later tick: nothing moved for it"
	)
	var last: SnapshotPacket = _received()[-1]
	assert_eq(last.ack, -1, "nothing of the client's was applied")
	assert_eq([last.heard, last.early], [3, -2], "it came two ticks late, and the client is told")


func test_ack_tracks_last_applied_input() -> void:
	var host := _host()
	_send([_walk(0, Vector2.UP), _walk(1, Vector2.UP), _walk(2, Vector2.UP)])
	var acks: Array[int] = []
	for tick in 5:
		host.step()
		acks.append(_received()[-1].ack)
	assert_eq(acks, [0, 1, 2, 2, 2] as Array[int], "each tick applied, then none")
	_send([_walk(5, Vector2.DOWN)])
	host.step()
	assert_eq(_received()[-1].ack, 5, "a frame that comes in time is applied and acked")


func test_snapshots_every_interval_repeat_recent_events() -> void:
	var rules: NetRules = NetRules.load_default().duplicate()
	rules.snapshot_interval = 3
	var host := _host(2, rules)
	_send([_walk(0, Vector2.ZERO, InputFrame.JUMP)])
	var landed := -1
	var sent_at: Array[int] = []
	for tick in 2 * Ticks.RATE:
		for event: SimEvent in host.step():
			if event.kind == SimEvent.Kind.LANDED:
				landed = event.tick
		for packet: SnapshotPacket in _received():
			var snapshot := packet.snapshot
			sent_at.append(snapshot["tick"])
			var events: Array = snapshot["events"]
			var carries := events.any(
				func(event: Dictionary) -> bool: return event["tick"] == landed
			)
			var window := rules.input_redundancy * rules.snapshot_interval
			if landed >= 0 and snapshot["tick"] <= landed + window:
				assert_true(
					carries, "the snapshot of tick %d repeats the landing" % snapshot["tick"]
				)
			elif landed >= 0:
				assert_false(carries, "and later ones let it go")
	assert_gt(landed, 0, "the jump came down")
	for tick: int in sent_at:
		assert_eq(tick % 3, 0, "a snapshot every third tick")
	assert_eq(sent_at.size() * 3, 2 * Ticks.RATE)


func test_a_frame_beyond_the_prediction_cap_is_dropped() -> void:
	var host := _host()
	var beyond := host.tick() + _rules.prediction_cap_ticks() + 1
	_send([_walk(beyond, Vector2.RIGHT)])
	host.step()
	var told: SnapshotPacket = _received()[-1]
	assert_eq(told.heard, -1, "a frame that far ahead is not heard of")
	_send([_walk(host.tick(), Vector2.RIGHT)])
	host.step()
	told = _received()[-1]
	assert_eq([told.heard, told.early], [1, 0], "so the next one in time is the newest heard")
	for _tick in beyond:
		host.step()
	assert_null(host.runner.input_log.frame(beyond, 0), "nor is it kept for its tick")


func test_a_packet_counts_for_input_redundancy_frames_at_most() -> void:
	var host := _host()
	var frames: Array[InputFrame] = []
	for tick in 2 * _rules.input_redundancy:
		frames.append(_walk(tick, Vector2.UP))
	_send(frames)
	for _tick in frames.size():
		host.step()
	var kept := frames.size() - _rules.input_redundancy
	for tick in frames.size():
		var applied := host.runner.input_log.frame(tick, 0) != null
		assert_eq(applied, tick >= kept, "tick %d: only the packet's newest are taken" % tick)
