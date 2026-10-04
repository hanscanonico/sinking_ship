extends GutTest
## The fake wire (SH11): a loopback that loses and delays packets as NetConditions
## say, from its own seeded stream, and the --net-sim flag that names them.

const LAG := "latency:120,jitter:20,loss:5"
## How finely a run moves the clock, so an arrival time is measured to the millisecond.
const CLOCK_STEP := 0.001
## A packet every this many clock steps: one a tick.
const SEND_EVERY := 33
const PACKETS := 2000


## Sends PACKETS packets one way across a pair seeded from [param seed_value] under
## [param conditions]; returns, per packet by its number, how long it took, or -1
## when it never came.
func _run(seed_value: int, conditions: NetConditions) -> PackedFloat64Array:
	var clock := NetClock.new()
	var sender := LoopbackTransport.new(0, clock, conditions, SeedStreams.derive(seed_value, 0))
	var receiver := LoopbackTransport.new(1, clock, conditions, SeedStreams.derive(seed_value, 1))
	LoopbackTransport.link(sender, receiver)
	var took := PackedFloat64Array()
	took.resize(PACKETS)
	took.fill(-1.0)
	var sent_at := PackedFloat64Array()
	var step := 0
	while sent_at.size() < PACKETS or step < (PACKETS + 10) * SEND_EVERY:
		if step % SEND_EVERY == 0 and sent_at.size() < PACKETS:
			sender.send(1, PackedByteArray([sent_at.size() & 0xFF, sent_at.size() >> 8]))
			sent_at.append(clock.now)
		clock.advance(CLOCK_STEP)
		step += 1
		for packet: Transport.Packet in receiver.receive():
			assert_eq(packet.peer, 0, "it says who sent it")
			var number := packet.bytes[0] | packet.bytes[1] << 8
			took[number] = clock.now - sent_at[number]
	return took


func test_latency_jitter_and_loss_are_seeded() -> void:
	var lag := NetConditions.parse(LAG)
	var first := _run(7, lag)
	assert_eq(_run(7, lag), first, "the same seed loses and delays the same packets")
	assert_ne(_run(8, lag), first, "another seed, others")
	var lost := 0
	var earliest := INF
	var latest := 0.0
	for took: float in first:
		if took < 0.0:
			lost += 1
			continue
		earliest = minf(earliest, took)
		latest = maxf(latest, took)
	var rate := float(lost) / PACKETS
	assert_between(rate, 0.03, 0.07, "about 5% lost")
	assert_between(earliest, 0.1, 0.11, "120 ms less 20 at the quickest")
	assert_between(latest, 0.13, 0.141 + CLOCK_STEP, "120 ms and 20 at the slowest")


func test_no_conditions_deliver_at_once() -> void:
	for took: float in _run(7, NetConditions.new()):
		assert_almost_eq(took, CLOCK_STEP, 1e-9, "every packet, on the next look")


func test_net_sim_flag_parses() -> void:
	var lag := NetConditions.parse(LAG)
	assert_almost_eq(lag.latency, 0.12, 1e-9)
	assert_almost_eq(lag.jitter, 0.02, 1e-9)
	assert_almost_eq(lag.loss, 0.05, 1e-9)
	var none := NetConditions.parse("")
	assert_eq([none.latency, none.jitter, none.loss], [0.0, 0.0, 0.0], "nothing lies")
	for bad: String in ["latency", "latency:fast", "speed:3", "loss:120", "jitter:-5"]:
		assert_null(NetConditions.parse(bad), "%s is refused" % bad)


## Every event the host raises reaches a watching client's view, in order, over the
## lying wire: each snapshot repeats the last few snapshots' events.
func test_every_event_crosses_a_lossy_wire() -> void:
	var config := MatchConfig.from_rules(load("res://data/match/default.tres"), 1701)
	var profile := BotProfile.for_tier(config.bot_tier)
	var bots := BotInputSource.fill(config, profile)
	var lag := NetConditions.parse(LAG)
	var played := LoopbackMatch.new(config, NetRules.load_default(), lag, -1, null, bots)
	var raised: Array[String] = []
	var reached: Array[String] = []
	var until := 20 * Ticks.RATE
	while played.host.tick() < until + Ticks.RATE:
		played.clock.advance(Ticks.SECONDS_PER_TICK)
		played.client.sample()
		for event: SimEvent in played.host.step():
			if event.tick < until:
				raised.append(_told(event))
		for event: SimEvent in played.client.step():
			if event.tick < until:
				reached.append(_told(event))
	assert_gt(raised.size(), 10, "the bots made things happen")
	assert_eq(reached, raised)


func _told(event: SimEvent) -> String:
	return "%d %d %d %d %d" % [event.tick, event.kind, event.seat, event.target, event.prop]
