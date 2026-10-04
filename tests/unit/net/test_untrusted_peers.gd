extends GutTest
## Every byte a client sends is hostile input (SH12, R9). Garbage, a packet cut short,
## one too big, one of a kind only the server sends, a flood, a bad name, a guessed
## code too many, a silence, a client that stops reading: each is refused without a
## script error, and the connection closed. Rooms and connections are capped — a client
## past the cap told so — the matches built are budgeted, and a client's input reaches
## its own seat and no other. The client reads its server as warily.


## A server end whose clients in [member stalled] have stopped reading: their bytes
## pile up unsent.
class Stalled:
	extends LoopbackTransport
	var stalled := {}

	func backlog(to_peer: int) -> int:
		return 1 << 30 if stalled.has(to_peer) else 0


## A walk to starboard on [param tick], claiming to be [param seat]'s.
static func _walk(seat: int, tick: int) -> InputFrame:
	return InputFrame.new(seat, tick, Vector2i(0, InputFrame.AXIS_MAX))


## Sends [param bytes] as a fresh end's first words — after a HELLO, when
## [param hello] — and returns the end once the server has had them.
static func _send_raw(
	fixture: RoomFixtures, bytes: PackedByteArray, hello: bool = true
) -> LoopbackTransport:
	var end := fixture.raw_end()
	if hello:
		fixture.hello(end)
	end.send(RoomFixtures.SERVER_PEER, bytes)
	fixture.beat()
	return end


## Asserts the server refused [param end] for [param reason] and then let it go.
func _assert_turned_away(fixture: RoomFixtures, end: LoopbackTransport, reason: int) -> void:
	assert_eq(fixture.refusal(end), reason, "refused for %s" % RoomCodec.Refusal.keys()[reason])
	fixture.beat(ServerRules.beats(fixture.rules.refusal_linger))
	assert_eq(Array(end.closed()), [RoomFixtures.SERVER_PEER], "and let go")


func test_garbage_before_a_hello_is_turned_away() -> void:
	var fixture := RoomFixtures.new()
	var noise := RandomNumberGenerator.new()
	noise.seed = 7
	var random := PackedByteArray()
	for index in 40:
		random.append(noise.randi_range(0, 255))
	random[0] = 0xFF
	var other_data := random.duplicate()
	other_data[0] = WireCodec.PROTOCOL_VERSION
	var join := fixture.codec.encode_join("ABCD")
	var input := fixture.codec.wire.encode_inputs([_walk(0, 0)] as Array[InputFrame])
	var cases := [
		[PackedByteArray(), RoomCodec.Refusal.MALFORMED],
		[PackedByteArray([WireCodec.PROTOCOL_VERSION]), RoomCodec.Refusal.MALFORMED],
		[random, RoomCodec.Refusal.VERSION],
		[other_data, RoomCodec.Refusal.DATA],
		[join, RoomCodec.Refusal.MALFORMED],
		[input, RoomCodec.Refusal.MALFORMED],
	]
	for case: Array in cases:
		_assert_turned_away(fixture, _send_raw(fixture, case[0], false), case[1])
	assert_eq(fixture.server.connection_count(), 0)


func test_short_unknown_and_server_only_packets_are_turned_away() -> void:
	var fixture := RoomFixtures.new()
	var cut_short := fixture.codec.encode_join("ABCD")
	cut_short.resize(cut_short.size() - 2)
	var too_long := fixture.codec.encode_bare(WireCodec.Kind.CREATE)
	too_long.append(0)
	var no_kind := fixture.codec.encode_bare(WireCodec.Kind.CREATE)
	no_kind[1 + WireCodec.HASH_BYTES] = WireCodec.Kind.size()
	var not_ascii := fixture.codec.encode_join("ABCD")
	not_ascii[-1] = 0xC3
	var packets := [
		cut_short,
		too_long,
		no_kind,
		not_ascii,
		fixture.codec.encode_bare(WireCodec.Kind.WELCOME),
		fixture.codec.encode_begin(1, 8, 0),
		fixture.codec.encode_hello("Twice"),
	]
	for bytes: PackedByteArray in packets:
		_assert_turned_away(fixture, _send_raw(fixture, bytes), RoomCodec.Refusal.MALFORMED)


func test_an_oversized_packet_is_turned_away() -> void:
	var fixture := RoomFixtures.new()
	var big := fixture.codec.encode_join("ABCD")
	big.resize(fixture.rules.packet_bytes + 1)
	_assert_turned_away(fixture, _send_raw(fixture, big), RoomCodec.Refusal.MALFORMED)


## Seeded noise behind a header of this protocol and match, of every kind: each is a
## message or nothing, and nothing raises an error.
func test_random_packets_never_break_the_codecs() -> void:
	var codec := RoomCodec.new(
		RoomServer.data_hash(load(RoomFixtures.MATCH_DATA), NetRules.load_default())
	)
	var noise := RandomNumberGenerator.new()
	noise.seed = 1701
	var read := 0
	for index in 3000:
		var bytes := codec.encode_bare(noise.randi_range(0, WireCodec.Kind.size() - 1))
		for _byte in noise.randi_range(0, 40):
			bytes.append(noise.randi_range(0, 255))
		var message := codec.decode(bytes)
		if message != null:
			read += 1
		codec.wire.decode_inputs(bytes, 0)
		codec.wire.decode_snapshot(bytes)
	assert_gt(read, 0, "some noise happens to read")


func test_names_are_bounded() -> void:
	var fixture := RoomFixtures.new()
	var longest := "N".repeat(fixture.rules.name_length)
	var refused := ["", "   ", longest + "N", "Zoë", "<b>", "Ada\n"]
	var clients: Array[RoomClient] = []
	for typed: String in refused + [longest, "Mary-Jo O'Neil"]:
		clients.append(fixture.connect_client(typed))
	fixture.beat()
	for index in refused.size():
		assert_eq(clients[index].state, RoomClient.State.CLOSED, "%s is refused" % refused[index])
		assert_true(
			clients[index].close_reason in [RoomCodec.Refusal.NAME, RoomCodec.Refusal.MALFORMED]
		)
	assert_eq(clients[-2].state, RoomClient.State.LOBBY, "the longest name is welcome")
	assert_eq(clients[-1].state, RoomClient.State.LOBBY)


func test_room_attempts_are_capped() -> void:
	var fixture := RoomFixtures.new()
	var guesser := fixture.connect_client("Guesser")
	var reasons := RoomFixtures.refusals(guesser)
	fixture.beat()
	for guess in fixture.rules.room_attempts + 1:
		guesser.join_room("ZZZZ")
		fixture.beat()
	assert_eq(reasons.size(), fixture.rules.room_attempts, "every guess refused")
	assert_true(reasons.all(func(reason: int) -> bool: return reason == RoomCodec.Refusal.NO_ROOM))
	assert_eq(guesser.state, RoomClient.State.CLOSED, "one too many ends the connection")
	assert_eq(guesser.close_reason, RoomCodec.Refusal.ATTEMPTS)


## Attempts come back one an attempt_refill, so a player going from room to room is
## not cut off; a burst past room_attempts still is.
func test_room_attempts_come_back_with_time() -> void:
	var fixture := RoomFixtures.new(RoomFixtures.rules_with({"attempt_refill": 1.0}))
	var guesser := fixture.connect_client("Guesser")
	var reasons := RoomFixtures.refusals(guesser)
	fixture.beat()
	for guess in fixture.rules.room_attempts:
		guesser.join_room("ZZZZ")
		fixture.beat()
	fixture.beat(Ticks.RATE)
	guesser.join_room("ZZZZ")
	fixture.beat()
	assert_eq(guesser.state, RoomClient.State.LOBBY, "one more, a refill later")
	assert_eq(reasons.size(), fixture.rules.room_attempts + 1)
	guesser.join_room("ZZZZ")
	fixture.beat()
	assert_eq(guesser.state, RoomClient.State.CLOSED, "but not two")
	assert_eq(guesser.close_reason, RoomCodec.Refusal.ATTEMPTS)


## Building a match stalls every room: the server builds starts_per_second at most,
## one connection waits start_cooldown between two, and a START past either is refused
## BUSY before anything is built.
func test_match_builds_are_budgeted() -> void:
	var fixture := RoomFixtures.new(
		RoomFixtures.rules_with({"starts_per_second": 1, "start_cooldown": 5.0}),
		RoomFixtures.flat_rules()
	)
	var first := fixture.room_of(1)[0]
	var second := fixture.room_of(1)[0]
	var busy := RoomFixtures.refusals(second)
	first.start_match()
	second.start_match()
	fixture.beat()
	assert_eq(first.state, RoomClient.State.PLAYING)
	assert_eq(busy, [RoomCodec.Refusal.BUSY] as Array[int], "one build a second")
	assert_eq(fixture.room(second).phase, Room.Phase.WAITING, "nothing was built for it")
	assert_null(fixture.room(second).host)
	fixture.beat(Ticks.RATE)
	second.start_match()
	fixture.beat()
	assert_eq(second.state, RoomClient.State.PLAYING, "a second later, one more")
	var again := RoomFixtures.refusals(first)
	first.leave_room()
	first.create_room()
	fixture.beat(Ticks.RATE)
	first.start_match()
	fixture.beat()
	assert_eq(again, [RoomCodec.Refusal.BUSY] as Array[int], "too soon after its last")
	assert_eq(first.state, RoomClient.State.ROOM)
	fixture.beat(ServerRules.beats(fixture.rules.start_cooldown))
	first.start_match()
	fixture.beat()
	assert_eq(first.state, RoomClient.State.PLAYING, "its cooldown over")


func test_a_flood_is_cut_off() -> void:
	var fixture := RoomFixtures.new()
	var end := fixture.raw_end()
	fixture.hello(end)
	for packet in fixture.rules.packets_per_second + 1:
		end.send(RoomFixtures.SERVER_PEER, fixture.codec.encode_stamp(WireCodec.Kind.PONG, packet))
	fixture.beat()
	_assert_turned_away(fixture, end, RoomCodec.Refusal.FLOOD)


func test_a_silent_connection_times_out() -> void:
	var fixture := RoomFixtures.new()
	var end := fixture.raw_end()
	fixture.beat(ServerRules.beats(fixture.rules.hello_timeout) + 1)
	_assert_turned_away(fixture, end, RoomCodec.Refusal.TIMEOUT)


## A client gone without closing its socket — a machine switched off, a cable pulled —
## sends neither inputs nor pongs: past silence_timeout its seat is a bot's and its
## connection is closed. A player who only answers pings is still there.
func test_a_silent_player_is_given_up() -> void:
	var fixture := RoomFixtures.new(
		RoomFixtures.rules_with({"silence_timeout": 2.0}), RoomFixtures.flat_rules()
	)
	var players := fixture.room_of(2)
	players[0].start_match()
	fixture.beat()
	var room := fixture.room(players[0])
	fixture.hush(players[1])
	fixture.beat(ServerRules.beats(fixture.rules.silence_timeout))
	assert_true(room.is_bot(1), "its seat is a bot's")
	assert_true(fixture.logged("went silent"))
	assert_eq(players[0].roster.players.size(), 2)
	assert_true(players[0].roster.players[1].bot, "the others are told")
	assert_eq(players[0].state, RoomClient.State.PLAYING, "the one answering pings plays on")
	fixture.beat(ServerRules.beats(fixture.rules.refusal_linger))
	assert_eq(Array(fixture.end_of(players[1]).closed()), [RoomFixtures.SERVER_PEER])
	assert_eq(fixture.server.connection_count(), 1)


func test_a_client_that_stops_reading_is_dropped() -> void:
	var fixture := RoomFixtures.new(null, null, Stalled)
	var players := fixture.room_of(2)
	var stalled_peer := fixture.end_of(players[1]).peer
	(fixture.server_end as Stalled).stalled[stalled_peer] = true
	fixture.beat()
	assert_eq(players[1].state, RoomClient.State.CLOSED, "its connection is closed")
	assert_true(fixture.logged("(peer %d) stopped reading" % stalled_peer))
	assert_eq(fixture.room(players[0]).members.size(), 1, "and it is out of the room")
	assert_eq(players[0].state, RoomClient.State.ROOM, "the others play on")


func test_rooms_and_connections_are_capped() -> void:
	var fixture := RoomFixtures.new(RoomFixtures.rules_with({"max_rooms": 1, "max_connections": 2}))
	var first := fixture.connect_client("First")
	var second := fixture.connect_client("Second")
	var reasons := RoomFixtures.refusals(second)
	fixture.beat()
	first.create_room()
	second.create_room()
	fixture.beat()
	assert_eq(fixture.server.room_count(), 1)
	assert_eq(reasons, [RoomCodec.Refusal.SERVER_FULL] as Array[int], "no room for a room")
	var third := fixture.connect_client("Third")
	fixture.beat()
	assert_eq(third.state, RoomClient.State.CLOSED, "no room for a connection")
	assert_eq(third.close_reason, RoomCodec.Refusal.SERVER_FULL, "and told so")
	assert_eq(fixture.server.connection_count(), 2)


## A peer past max_connections is told the server is full and let go once it has read
## it, nothing of it kept after; past as many again waiting to be, it is let go at
## once, untold.
func test_a_full_server_says_so() -> void:
	var fixture := RoomFixtures.new(RoomFixtures.rules_with({"max_connections": 1}))
	fixture.hello(fixture.raw_end())
	var told := fixture.raw_end()
	var untold := fixture.raw_end()
	fixture.beat()
	assert_eq(fixture.refusal(told), RoomCodec.Refusal.SERVER_FULL)
	assert_eq(Array(told.closed()), [], "given time to read it")
	assert_eq(fixture.refusal(untold), -1)
	assert_eq(Array(untold.closed()), [RoomFixtures.SERVER_PEER], "one too many, gone at once")
	fixture.beat(ServerRules.beats(fixture.rules.refusal_linger))
	assert_eq(Array(told.closed()), [RoomFixtures.SERVER_PEER], "then let go")
	var later := fixture.raw_end()
	fixture.beat()
	assert_eq(fixture.refusal(later), RoomCodec.Refusal.SERVER_FULL, "nothing held for the last")
	assert_eq(fixture.server.connection_count(), 1)


## A peer that opens and closes before the server looks is never a connection, and
## holds no place.
func test_a_peer_gone_before_it_is_seen_is_no_connection() -> void:
	var fixture := RoomFixtures.new()
	LoopbackTransport.unlink(fixture.server_end, fixture.raw_end())
	fixture.beat()
	assert_eq(fixture.server.connection_count(), 0)


## A client's frames reach its own seat whatever seat they claim; frames from a client
## in no match reach none.
func test_inputs_reach_only_their_own_seat() -> void:
	var fixture := RoomFixtures.new(null, RoomFixtures.flat_rules())
	var players := fixture.room_of(2)
	var outsider := fixture.raw_end()
	fixture.hello(outsider)
	players[0].start_match()
	fixture.beat()
	var room := fixture.room(players[0])
	var wire := fixture.codec.wire
	for _beat in Ticks.RATE:
		var claiming := [_walk(0, room.host.tick())] as Array[InputFrame]
		fixture.end_of(players[1]).send(RoomFixtures.SERVER_PEER, wire.encode_inputs(claiming))
		outsider.send(RoomFixtures.SERVER_PEER, wire.encode_inputs(claiming))
		fixture.beat()
	var seats: Array = room.host.runner.snapshot["seats"]
	assert_eq(seats[1]["last_input"][1], InputFrame.AXIS_MAX, "the sender's own seat walks")
	assert_eq(seats[0]["last_input"][1], 0, "the seat it claimed does not")
	assert_eq(fixture.server.connection_count(), 3, "nobody was cut off for it")


## A server's packets are read as warily as a client's: a roster naming a player it
## does not list or holding no room's code, and a BEGIN giving a seat past its seats,
## are nothing, and a client is left as it was.
func test_a_client_reads_impossible_server_packets_as_nothing() -> void:
	var codec := RoomCodec.new(
		RoomServer.data_hash(load(RoomFixtures.MATCH_DATA), NetRules.load_default())
	)
	var roster := RoomRoster.new()
	roster.code = "ABCD"
	roster.you = 0
	roster.players.append(RoomRoster.Player.new("Ada", true, false))
	assert_not_null(codec.decode(codec.encode_roster(roster)), "a roster as a server sends it")
	assert_not_null(codec.decode(codec.encode_begin(1, 8, 7)), "and a BEGIN")
	roster.you = 1
	var past_you := codec.encode_roster(roster)
	roster.you = 0
	roster.code = "AB1D"
	var bad_code := codec.encode_roster(roster)
	var past_seats := codec.encode_begin(1, 8, 8)
	for bytes: PackedByteArray in [past_you, bad_code, past_seats]:
		assert_null(codec.decode(bytes))
	var server_end := LoopbackTransport.new(
		RoomFixtures.SERVER_PEER, NetClock.new(), NetConditions.new(), SeedStreams.derive(1, 0)
	)
	var client_end := LoopbackTransport.new(
		2, NetClock.new(), NetConditions.new(), SeedStreams.derive(1, 1)
	)
	LoopbackTransport.link(server_end, client_end)
	var client := RoomClient.new(
		client_end, load(RoomFixtures.MATCH_DATA), NetRules.load_default(), "Ada"
	)
	client.poll()
	server_end.send(2, codec.encode_bare(WireCodec.Kind.WELCOME))
	for bytes: PackedByteArray in [past_you, bad_code, past_seats]:
		server_end.send(2, bytes)
	client.poll()
	assert_eq(client.state, RoomClient.State.LOBBY, "welcomed, and nothing more")
	assert_null(client.roster)
