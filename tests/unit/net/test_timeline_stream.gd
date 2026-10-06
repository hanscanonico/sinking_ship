extends GutTest
## The sinking reaches a client as data, never as a computation (D11, §5b.4): the server
## bakes the match's timeline, BEGIN carries its digest, and the server streams it —
## header first, each page ahead of the tick that reads it — to a client that checks
## every byte against that digest, plays it as the server has it, refuses one that does
## not check out, and never bakes. Over loopbacks, as RoomClients a menu would drive.

## Beats enough for a timeline's first sections to cross a loopback.
const ARRIVING := 4
## How far the stream is walked, in ticks at a time, from the hit to the end.
const STRIDE := 30


## A server end that spoils one section of every timeline it sends: a byte of it
## flipped on the way.
class Spoiling:
	extends LoopbackTransport
	static var section := 1

	func send(to_peer: int, bytes: PackedByteArray) -> void:
		var opening := 1 + WireCodec.HASH_BYTES
		var spoilt := bytes
		if bytes.size() > opening + 5 and bytes[opening] == WireCodec.Kind.TIMELINE:
			if bytes.decode_u32(opening + 1) == section:
				spoilt = bytes.duplicate()
				spoilt[spoilt.size() - 7] ^= 0x20
		super.send(to_peer, spoilt)


## [param fixture]'s one-player room's match, started: the config its client began, or
## null when it never did within ARRIVING beats.
func _begun(fixture: RoomFixtures, player: RoomClient) -> MatchConfig:
	var begun: Array[MatchConfig] = []
	player.began.connect(func(config: MatchConfig, _seat: int) -> void: begun.append(config))
	player.start_match()
	for _beat in ARRIVING:
		fixture.beat()
	return begun[0] if not begun.is_empty() else null


func test_client_plays_the_hosts_timeline() -> void:
	var fixture := RoomFixtures.new()
	var player := fixture.room_of(1)[0]
	var config := _begun(fixture, player)
	assert_not_null(config, "the match began")
	var host := fixture.room(player).host.runner.sim.schedule
	var choice := config.sinking()
	assert_true(choice.received, "the client's sinking came from the server")
	assert_eq(config.bake_steps(), 0, "and no step of it was baked here")
	var timeline := choice.timeline
	assert_true(timeline.is_whole(), "every page came")
	assert_eq(timeline.digest(), host.timeline().digest(), "the server's timeline, to the byte")
	var schedule := config.schedule()
	assert_eq(schedule.hit_tick(), host.hit_tick(), "struck when the server strikes her")
	assert_eq(schedule.hit().start_x, host.hit().start_x, "where it strikes her")
	assert_eq(schedule.damage().area(), host.damage().area(), "and as hard")
	assert_eq(
		[schedule.gone_tick(), schedule.unsupported_tick(), schedule.end_tick()],
		[host.gone_tick(), host.unsupported_tick(), host.end_tick()]
	)
	var tick := 0
	while tick <= host.end_tick():
		var mine := schedule.pose_at(tick)
		var theirs := host.pose_at(tick)
		assert_eq(mine.transform, theirs.transform, "tick %d: her pose" % tick)
		assert_eq(mine.levels, theirs.levels, "tick %d: her water" % tick)
		assert_eq(schedule.events_at(tick).size(), host.events_at(tick).size())
		tick += maxi((host.end_tick() - host.hit_tick()) / 97, 1)
	# And plays it: the client's prediction runs on the timeline it was sent.
	var played := player.play(InputSource.new())
	for _beat in Ticks.RATE:
		played.step()
		fixture.beat()
	assert_same(played.client.sim.schedule, schedule, "the prediction reads it")
	assert_gte(played.client.view()["tick"], Ticks.RATE, "and the match plays on")


func test_timeline_streams_ahead_of_the_tick() -> void:
	# Nothing sent past what is due: each page only as the match comes within the lead.
	var rules := RoomFixtures.rules_with({"timeline_bytes_per_beat": 1})
	var fixture := RoomFixtures.new(rules)
	var player := fixture.room_of(1)[0]
	var config := _begun(fixture, player)
	assert_not_null(config, "the match began on its first page")
	var room := fixture.room(player)
	var host := room.host.runner.sim.schedule
	var lead := Ticks.from_seconds(rules.timeline_lead)
	var timeline := config.sinking().timeline
	assert_gt(room.stream.size(), 2, "a timeline of more than one page")
	assert_false(room.stream.is_done(), "the later pages held back")
	# Its first minutes before the countdown ends, and a page ahead of every tick played.
	while room.host.tick() <= config.countdown_ticks + Ticks.RATE:
		var held := host.physics_tick(timeline.times[timeline.count() - 1])
		assert_true(
			timeline.is_whole() or held >= room.host.tick() + lead,
			"tick %d: the states up to %d held" % [room.host.tick(), held]
		)
		fixture.beat()
	var seconds := Ticks.to_seconds(config.countdown_ticks + lead - host.hit_tick())
	assert_true(
		timeline.is_whole() or timeline.times[timeline.count() - 1] >= seconds,
		"%.0f s of her sinking held before the countdown ends" % seconds
	)
	# On to her end, the stream alone: every page out the lead before the tick needing it.
	var stream := TimelineStream.new(host, rules)
	var sent := {}
	var tick := 0
	while not stream.is_done():
		for section: int in stream.due(tick):
			sent[section] = tick
		tick += STRIDE
	for section in stream.size():
		assert_lte(sent[section], maxi(stream.needed_by(section) - lead, 0) + STRIDE)


func test_mismatched_timeline_is_refused() -> void:
	for spoilt: int in [0, 1]:
		Spoiling.section = spoilt
		var fixture := RoomFixtures.new(null, null, Spoiling)
		var player := fixture.room_of(1)[0]
		var config := _begun(fixture, player)
		assert_null(config, "section %d spoilt: the match never begins" % spoilt)
		assert_eq(player.state, RoomClient.State.CLOSED, "the client hangs up")
		assert_eq(player.close_reason, RoomCodec.Refusal.TIMELINE, "refusing the timeline")
	Spoiling.section = -1
	var fixture := RoomFixtures.new(null, null, Spoiling)
	var player := fixture.room_of(1)[0]
	assert_not_null(_begun(fixture, player), "untouched, the same timeline is played")
