extends GutTest
## The handshake (SH12): a client's first packet is a HELLO, opened with its protocol
## version and its match's hash (WireCodec.match_hash). Another version or another
## hash is refused — the refusal names which — and the connection closed once the
## client has had refusal_linger to read why. The hash covers the match's data, its
## NetRules and WireCodec.SIM_BUILD: two builds that would play a match differently are
## told apart only as far as those say so — a code change that plays differently and
## leaves SIM_BUILD as it was goes unseen.


func test_version_mismatch_is_refused() -> void:
	var fixture := RoomFixtures.new()
	var end := fixture.raw_end()
	var hello := fixture.codec.encode_hello("Old")
	hello[0] = WireCodec.PROTOCOL_VERSION - 1
	end.send(RoomFixtures.SERVER_PEER, hello)
	fixture.beat()
	assert_eq(fixture.refusal(end), RoomCodec.Refusal.VERSION, "refused, and told why")
	assert_false(fixture.logged("said hello"), "never welcomed")
	fixture.beat(ServerRules.beats(fixture.rules.refusal_linger))
	assert_eq(Array(end.closed()), [RoomFixtures.SERVER_PEER], "then let go")
	assert_eq(fixture.server.connection_count(), 0)


func test_data_hash_mismatch_is_refused() -> void:
	var fixture := RoomFixtures.new()
	var changed: MatchRules = fixture.match_rules.duplicate()
	changed.countdown += 1.0
	var client := fixture.connect_client("Changed", changed)
	var reasons: Array[int] = []
	client.closed.connect(func(reason: int) -> void: reasons.append(reason))
	fixture.beat()
	assert_eq(reasons, [RoomCodec.Refusal.DATA] as Array[int], "refused for its data")
	assert_eq(client.state, RoomClient.State.CLOSED)
	assert_true(fixture.logged("turned away: DATA"))
	assert_false(fixture.logged("said hello"), "never welcomed")
	fixture.beat(ServerRules.beats(fixture.rules.refusal_linger))
	assert_eq(fixture.server.connection_count(), 0, "and let go")


## Two ends whose NetRules differ would not play a match alike: other data.
func test_net_rules_mismatch_is_refused() -> void:
	var fixture := RoomFixtures.new()
	var changed: NetRules = NetRules.load_default().duplicate()
	changed.input_redundancy += 1
	var client := fixture.connect_client("Changed", null, changed)
	fixture.beat()
	assert_eq(client.state, RoomClient.State.CLOSED)
	assert_eq(client.close_reason, RoomCodec.Refusal.DATA, "refused for its net rules")
	assert_true(fixture.logged("turned away: DATA"))
	assert_false(fixture.logged("said hello"), "never welcomed")


## A packet of the server's own, read by a client of another version, is the
## server's refusal too: either end can tell.
func test_a_client_reads_another_version_as_a_refusal() -> void:
	var server_end := LoopbackTransport.new(
		RoomFixtures.SERVER_PEER, NetClock.new(), NetConditions.new(), SeedStreams.derive(1, 0)
	)
	var client_end := LoopbackTransport.new(
		2, NetClock.new(), NetConditions.new(), SeedStreams.derive(1, 1)
	)
	LoopbackTransport.link(server_end, client_end)
	var rules: MatchRules = load(RoomFixtures.MATCH_DATA)
	var client := RoomClient.new(client_end, rules, NetRules.load_default(), "New")
	client.poll()
	var codec := RoomCodec.new(RoomServer.data_hash(rules, NetRules.load_default()))
	var welcome := codec.encode_bare(WireCodec.Kind.WELCOME)
	welcome[0] = WireCodec.PROTOCOL_VERSION + 1
	server_end.send(2, welcome)
	client.poll()
	assert_eq(client.state, RoomClient.State.CLOSED)
	assert_eq(client.close_reason, RoomCodec.Refusal.VERSION)


func test_a_matching_hello_is_welcomed() -> void:
	var fixture := RoomFixtures.new()
	var client := fixture.connect_client("  Ada  ")
	var welcomed := [false]
	client.welcomed.connect(func() -> void: welcomed[0] = true)
	fixture.beat()
	assert_true(welcomed[0])
	assert_eq(client.state, RoomClient.State.LOBBY)
	assert_true(fixture.logged("Ada (peer"), "known by the name, trimmed")
